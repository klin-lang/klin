# Emit-c against package Klin surface (no IDF link). For CI / syntax check.
KLIN ?= klin

.PHONY: emit clean

emit: out/smoke.c

out/smoke.c: smoke.kl $(wildcard ../../espnow/*.kl)
	@mkdir -p out
	@case "$(KLIN)" in \
	  *.dart) dart run "$(KLIN)" --emit-c smoke.kl ;; \
	  *) "$(KLIN)" --emit-c smoke.kl ;; \
	esac

clean:
	rm -rf out
