# ESP32-S3 ESP-NOW: Klin --emit-c → ESP-IDF build/flash.
#
#   make emit KLIN=/path/to/klin/bin/klin.dart
#   make build
#   make flash

KLIN ?= klin
IDF_PY ?= idf.py

.PHONY: all emit build flash monitor clean

all: build

emit: out/peer.c

out/peer.c out/peer.link: peer.kl $(wildcard ../../espnow/*)
	@mkdir -p out
	@case "$(KLIN)" in \
	  *.dart) dart run "$(KLIN)" --emit-c peer.kl ;; \
	  *) "$(KLIN)" --emit-c peer.kl ;; \
	esac
	@sed -i 's/^int main(void)/static int klin_unused_main(void)/' out/peer.c

build: emit
	@test -n "$$IDF_PATH" || (echo "IDF_PATH not set — source ESP-IDF export.sh" >&2; exit 1)
	$(IDF_PY) set-target esp32s3
	$(IDF_PY) build

flash: build
	$(IDF_PY) flash

monitor:
	$(IDF_PY) monitor

clean:
	rm -rf out build
	-$(IDF_PY) fullclean 2>/dev/null || true
