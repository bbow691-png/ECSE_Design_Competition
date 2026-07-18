#include <Arduino.h>
#include <driver/i2s.h>
#include <WiFi.h>
#include <WiFiAP.h>
#include <WiFiUdp.h>

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

//------------------------------WiFi Access Point Config-----------------------//
#define AP_SSID      "DrumCabinet"  //Hotspot name
#define AP_PASS      "ecse2026"     //Hotspot password
#define UDP_PORT     4210           //UDP port for audio streaming
#define UDP_BUF_SIZE 1024           //UDP receive buffer size (bytes)

//------------------------------Piezo Config-----------------------------------//
#define STRIKE_THRESHOLD  500   //ADC value to trigger a hit (0-4095)
#define DEBOUNCE_MS       50    //Minimum time between strikes (ms)
#define HOLD_MS           20    //How long to hold triggered state (ms)

//------------------------------Global Objects---------------------------------//
WiFiUDP udp;
uint8_t udp_buf[UDP_BUF_SIZE];

//Struct to track state of each piezo channel
struct PiezoChannel {
    uint8_t pin;                //GPIO pin number
    const char* name;           //Human readable name for serial debug
    unsigned long last_strike;  //Timestamp of last strike (ms)
    bool triggered;             //Currently in triggered state
    int peak;                   //Peak ADC value since last strike
};

//Initialise all four channels
PiezoChannel channels[] = {
    { PIEZO_1, "Piezo 1", 0, false, 0 },
    { PIEZO_2, "Piezo 2", 0, false, 0 },
    { PIEZO_3, "Piezo 3", 0, false, 0 },
    { PIEZO_4, "Piezo 4", 0, false, 0 }
};

const int NUM_CHANNELS = 4;







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
        .tx_desc_auto_clear   = true            //Clear DMA on underrun
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
    Serial.println("I2S ready");
}

//------------------------------WiFi Access Point Setup------------------------------//
//------------------------------hang time check for ESP network----------------------//
void ap_init() {
    WiFi.mode(WIFI_AP);  // Explicitly set AP mode first
    delay(100);
    bool result = WiFi.softAP(AP_SSID, AP_PASS);
    if (!result) {
        Serial.println("AP failed to start!");
        return;
    }
    Serial.printf("Access Point: %s\n", AP_SSID);
    Serial.printf("AP IP: %s\n", WiFi.softAPIP().toString().c_str());
    udp.begin(UDP_PORT);
    Serial.printf("Listening on UDP port %d\n", UDP_PORT);
}
//--------------------------------------------------------------------------------//





//------------------------------Piezo Strike Detection-------------------------//
void check_piezos() {
    unsigned long now = millis();

    for (int i = 0; i < NUM_CHANNELS; i++) {
        PiezoChannel& ch = channels[i];

        //Read ADC value (0-4095 for 12-bit)
        int raw = analogRead(ch.pin);

        //Track peak value within the hold window
        if (raw > ch.peak) ch.peak = raw;

        //Detect new strike above threshold with debounce
        if (raw > STRIKE_THRESHOLD && !ch.triggered &&
            (now - ch.last_strike) > DEBOUNCE_MS) {

            ch.triggered = true;
            ch.last_strike = now;

            //Map peak ADC to MIDI-style velocity (1-127)
            int velocity = map(ch.peak, STRIKE_THRESHOLD, 4095, 1, 127);
            velocity = constrain(velocity, 1, 127);

            //Send hit event over serial to Python bridge
            //Format: HIT:channel:velocity e.g. HIT:1:87
            Serial.printf("HIT:%d:%d\n", i + 1, velocity);

            ch.peak = 0;
        }

        //Reset triggered state after hold period
        if (ch.triggered && (now - ch.last_strike) > HOLD_MS) {
            ch.triggered = false;
            ch.peak = 0;
        }
    }
}

//------------------------------Setup and Main Loop----------------------------//
void setup() {
    Serial.begin(115200);
    Serial.println("Drum Cabinet starting...");

    //GPIO 32/33 need explicit pinMode, 34/35 are input only by default
    pinMode(PIEZO_3, INPUT);
    pinMode(PIEZO_4, INPUT);

    i2s_init();
    ap_init();

    Serial.println("Ready");
}

void loop() {
    // Only parse if a packet is actually available
    if (udp.available()) {
        int packet_size = udp.parsePacket();
        if (packet_size > 0) {
            int len = udp.read(udp_buf, UDP_BUF_SIZE);
            if (len > 0) {
                size_t bytes_written = 0;
                i2s_write(I2S_PORT, udp_buf, len, &bytes_written, portMAX_DELAY);
            }
        }
    }
    check_piezos();
}

//-----------------------------------------------------------------------------//