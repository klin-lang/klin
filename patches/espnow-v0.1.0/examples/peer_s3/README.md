# ESP-NOW peer / broadcast (ESP32-S3)

Hardware demo for [`espnow`](../../README.md). Flash two boards on the same
channel (default demo uses channel **6**).

```sh
. $IDF_PATH/export.sh
make emit KLIN=/path/to/klin/bin/klin.dart
make build
make flash
```

Target: **esp32s3**.
