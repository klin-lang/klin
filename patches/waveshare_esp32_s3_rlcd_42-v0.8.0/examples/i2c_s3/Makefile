# ESP32-S3-RLCD-4.2 i2c_demo: Klin --emit-c → ESP-IDF.
KLIN ?= klin
IDF_PY ?= idf.py

.PHONY: all emit build flash monitor clean

all: build

emit: out/i2c_demo.c

out/i2c_demo.c out/i2c_demo.link: i2c_demo.kl $(wildcard ../../waveshare_esp32_s3_rlcd_42/*)
	@mkdir -p out
	@case "$(KLIN)" in \
	  *.dart) dart run "$(KLIN)" --emit-c i2c_demo.kl ;; \
	  *) "$(KLIN)" --emit-c i2c_demo.kl ;; \
	esac
	@sed -i 's/^int main(void)/static int klin_unused_main(void)/' out/i2c_demo.c

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
