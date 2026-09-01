# audio_s3

Hardware smoke for onboard **ES8311** (speaker) + **ES7210** (mics) on
Waveshare ESP32-S3-RLCD-4.2.

```sh
. $IDF_PATH/export.sh
make emit KLIN=/path/to/klin/bin/klin.dart
make build
make flash
```

`audio_init(16000)` brings up I2S duplex + codecs + PA; writes a short zero
PCM burst then reads mic samples into a caller buffer.
