#include <Arduino.h>
#include <driver/i2s.h>

#define I2S_BCK_PIN   26
#define I2S_LRCK_PIN  25
#define I2S_DOUT_PIN  23

#define SAMPLE_RATE   22050
#define I2S_PORT      I2S_NUM_0
#define DMA_BUF_COUNT 8
#define DMA_BUF_LEN   64
#define SERIAL_BAUD   921600
#define BUF_SIZE      256

void i2s_init() {
    i2s_config_t cfg = {
        .mode                 = (i2s_mode_t)(I2S_MODE_MASTER | I2S_MODE_TX),
        .sample_rate          = SAMPLE_RATE,
        .bits_per_sample      = I2S_BITS_PER_SAMPLE_16BIT,
        .channel_format       = I2S_CHANNEL_FMT_RIGHT_LEFT,
        .communication_format = I2S_COMM_FORMAT_STAND_I2S,
        .intr_alloc_flags     = ESP_INTR_FLAG_LEVEL1,
        .dma_buf_count        = DMA_BUF_COUNT,
        .dma_buf_len          = DMA_BUF_LEN,
        .use_apll             = true,
        .tx_desc_auto_clear   = true
    };
    i2s_pin_config_t pins = {
        .bck_io_num   = I2S_BCK_PIN,
        .ws_io_num    = I2S_LRCK_PIN,
        .data_out_num = I2S_DOUT_PIN,
        .data_in_num  = I2S_PIN_NO_CHANGE
    };
    i2s_driver_install(I2S_PORT, &cfg, 0, NULL);
    i2s_set_pin(I2S_PORT, &pins);
    i2s_zero_dma_buffer(I2S_PORT);
    Serial.println("I2S ready");
}

void setup() {
    Serial.begin(SERIAL_BAUD);
    Serial.println("Serial streaming test...");
    i2s_init();
}

void loop() {
    uint8_t buf[BUF_SIZE];
    int bytes_read = Serial.readBytes(buf, BUF_SIZE);
    if (bytes_read > 0) {
        size_t bytes_written = 0;
        i2s_write(I2S_PORT, buf, bytes_read, &bytes_written, portMAX_DELAY);
    }
}