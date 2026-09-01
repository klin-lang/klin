# Waveshare ESP32-S3-RLCD-4.2 (`klin init`): Klin --emit-c → ESP-IDF.
#
#   . $IDF_PATH/export.sh
#   make get KLIN=/path/to/klin/bin/klin.dart
#   make emit KLIN=/path/to/klin/bin/klin.dart
#   make build
#   make flash

KLIN ?= klin
IDF_PY ?= idf.py

.PHONY: all get emit build flash monitor clean

all: build

get:
	@case "$(KLIN)" in \
	  *.dart) dart run "$(KLIN)" get ;; \
	  *) "$(KLIN)" get ;; \
	esac

emit: out/main.c

out/main.c out/main.link: main.kl klin.mod
	@mkdir -p out
	@case "$(KLIN)" in \
	  *.dart) dart run "$(KLIN)" --emit-c main.kl ;; \
	  *) "$(KLIN)" --emit-c main.kl ;; \
	esac
	@sed -i 's/^int main(void)/static int klin_unused_main(void)/' out/main.c

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
