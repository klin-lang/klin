# Emit-c against package Klin surface (no IDF link).
KLIN ?= klin

.PHONY: emit clean

emit: out/smoke.c

out/smoke.c: smoke.kl $(wildcard ../../waveshare_esp32_s3_rlcd_42/*.kl)
	@mkdir -p out
	@case "$(KLIN)" in \
	  *.dart) dart run "$(KLIN)" --emit-c smoke.kl ;; \
	  *) "$(KLIN)" --emit-c smoke.kl ;; \
	esac

clean:
	rm -rf out
