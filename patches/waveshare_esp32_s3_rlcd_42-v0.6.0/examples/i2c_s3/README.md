# i2c_s3

ESP-IDF demo: `i2c_init` → probe 0x70 / 0x51 → optional `i2c_write_read` → `i2c_deinit`.

Pins: SDA=13, SCL=14 at 100 kHz. No sensor driver — bus helper only.
