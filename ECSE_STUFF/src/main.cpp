#include <Arduino.h>
#include <driver/i2s.h>

//------------------------------Pin Definitions--------------------------------//
#define I2S_BCK_PIN   26    //Bit clock pin
#define I2S_LRCK_PIN  25    //Left/right clock pin
#define I2S_DOUT_PIN  23    //Data out pin

//Piezo input pins (input only on 34/35, input/output on 32/33)
#define PIEZO_1  34
#define PIEZO_2  35
#define PIEZO_3  32
#define PIEZO_4  33

//------------------------------Audio Config-----------------------------------//
#define SAMPLE_RATE   22050     //Sample rate (Hz)
#define I2S_PORT      I2S_NUM_0 //I2S peripheral port
#define DMA_BUF_COUNT 16        //Direct memory access buffer count
#define DMA_BUF_LEN   128       //Direct memory access buffer length

//------------------------------Serial Config-----------------------------------//
#define SERIAL_BAUD    921600
//Default HardwareSerial RX buffer is only 256B. PC sends ~1KB audio chunks
//every ~11ms, so without a bigger buffer bytes get dropped between loop()
//passes long before we ever get a chance to read them.
#define SERIAL_RX_BUF  4096
#define AUDIO_CHUNK    512      //Max bytes pulled from Serial per loop pass

//------------------------------Piezo Config-----------------------------------//
#define STRIKE_THRESHOLD    500  //ADC value to trigger a hit (0-4095)
#define DEBOUNCE_MS         50   //Per-channel: minimum time between strikes on the same pad (ms)
#define HOLD_MS             20   //Per-channel: how long to hold triggered state (ms)
//A real strike's vibration reaches neighbouring piezos within ~1ms and can
//cross their threshold too. Once any channel fires, ignore ALL channels for
//this long so one physical hit can't be reported as hits on multiple pads.
#define CROSSTALK_MASK_MS   15

//Struct to track state of each piezo channel
struct PiezoChannel {
    uint8_t pin;                //GPIO pin number
    unsigned long last_strike;  //Timestamp of last strike (ms)
    bool triggered;             //Currently in triggered state
};

//Initialise all four channels
PiezoChannel channels[] = {
    { PIEZO_1, 0, false },
    { PIEZO_2, 0, false },
    { PIEZO_3, 0, false },
    { PIEZO_4, 0, false }
};

const int NUM_CHANNELS = 4;
static unsigned long last_hit_ms = 0;  //Across all channels, for the crosstalk mask

//------------------------------I2S Configuration---------------------------------//
void i2s_init() {
    i2s_config_t cfg = {
        .mode                 = (i2s_mode_t)(I2S_MODE_MASTER | I2S_MODE_TX), //Master transmit only
        .sample_rate          = SAMPLE_RATE,
        .bits_per_sample      = I2S_BITS_PER_SAMPLE_16BIT,                   //16 bit stereo
        .channel_format       = I2S_CHANNEL_FMT_RIGHT_LEFT,                  //Stereo L+R
        .communication_format = I2S_COMM_FORMAT_STAND_I2S,                   //Standard I2S framing
        .intr_alloc_flags     = ESP_INTR_FLAG_LEVEL1,                        //Interrupt priority
        .dma_buf_count        = DMA_BUF_COUNT,
        .dma_buf_len          = DMA_BUF_LEN,
        .use_apll             = true,           //Use audio PLL for lower jitter
        .tx_desc_auto_clear   = true             //Clear DMA on underrun
    };

    i2s_pin_config_t pins = {
        .bck_io_num   = I2S_BCK_PIN,
        .ws_io_num    = I2S_LRCK_PIN,
        .data_out_num = I2S_DOUT_PIN,
        .data_in_num  = I2S_PIN_NO_CHANGE      //No input needed
    };

    //Install driver, configure pins and clear DMA buffer
    i2s_driver_install(I2S_PORT, &cfg, 0, NULL);
    i2s_set_pin(I2S_PORT, &pins);
    i2s_zero_dma_buffer(I2S_PORT);
}

//------------------------------Piezo Strike Detection (Core 0 task)-----------//
//Runs as its own FreeRTOS task pinned to Core 0, entirely separate from the
//Core 1 loop() that pumps audio - so piezo polling and HIT reporting can
//never stall audio playback, and vice versa. WiFi is gone (audio moved to
//serial), so Core 0 has nothing else meaningful running on it.
void piezo_task(void* pvParameters) {
    for (;;) {
        unsigned long now = millis();
        bool masked = (now - last_hit_ms) < CROSSTALK_MASK_MS;

        for (int i = 0; i < NUM_CHANNELS; i++) {
            PiezoChannel& ch = channels[i];

            //Read ADC value (0-4095 for 12-bit)
            int raw = analogRead(ch.pin);

            //Detect new strike: above threshold, this channel isn't already
            //mid-strike, its own debounce has elapsed, and no other channel
            //has claimed this hit already (crosstalk mask).
            if (!masked && raw > STRIKE_THRESHOLD && !ch.triggered &&
                (now - ch.last_strike) > DEBOUNCE_MS) {

                ch.triggered = true;
                ch.last_strike = now;
                last_hit_ms = now;
                masked = true;  //claim this hit for the rest of this pass too

                //Hit event over serial to the PC bridge. Format: HIT:channel
                Serial.print("HIT:");
                Serial.println(i + 1);
            }

            //Reset triggered state after hold period
            if (ch.triggered && (now - ch.last_strike) > HOLD_MS) {
                ch.triggered = false;
            }
        }

        vTaskDelay(1);  //~1kHz sampling per channel; yields so Core 0's idle task/watchdog stays happy
    }
}

//------------------------------Serial Audio Ingestion--------------------------//
//Pulls whatever bytes are already sitting in the RX buffer without blocking,
//so loop() stays responsive even when the link is idle. Only whole 16-bit
//stereo frames (4 bytes: L16+R16) are handed to I2S so a read landing
//mid-frame doesn't leave the L/R channels permanently swapped.
static uint8_t audio_buf[AUDIO_CHUNK];
static size_t audio_buf_len = 0;

void pump_audio() {
    int avail = Serial.available();
    if (avail <= 0) return;

    size_t space = sizeof(audio_buf) - audio_buf_len;
    size_t to_read = min((size_t)avail, space);
    if (to_read > 0) {
        audio_buf_len += Serial.readBytes(audio_buf + audio_buf_len, to_read);
    }

    size_t frame_bytes = audio_buf_len - (audio_buf_len % 4);
    if (frame_bytes == 0) return;

    size_t written = 0;
    //ticks_to_wait = 0: never block the loop waiting on the DMA queue.
    //The DMA buffer holds ~90ms of audio so this only matters if playback
    //is already badly behind, in which case a momentary channel swap is an
    //acceptable trade-off against freezing piezo detection.
    i2s_write(I2S_PORT, audio_buf, frame_bytes, &written, 0);

    size_t remainder = audio_buf_len - written;
    if (remainder > 0) memmove(audio_buf, audio_buf + written, remainder);
    audio_buf_len = remainder;
}

//------------------------------Setup and Main Loop----------------------------//
void setup() {
    Serial.setRxBufferSize(SERIAL_RX_BUF);
    Serial.begin(SERIAL_BAUD);
    Serial.println("Drum Cabinet starting...");

    //GPIO 32/33 need explicit pinMode, 34/35 are input only by default
    pinMode(PIEZO_3, INPUT);
    pinMode(PIEZO_4, INPUT);

    i2s_init();

    //Pin piezo polling to Core 0 so it runs fully in parallel with the audio
    //pump on Core 1 (loop()) instead of competing with it for loop time.
    xTaskCreatePinnedToCore(piezo_task, "piezo_task", 4096, NULL, 1, NULL, 0);

    Serial.println("Ready");
}

void loop() {
    pump_audio();
}

//-----------------------------------------------------------------------------//
