# GD32VW553 HTTP GET sketch — needs official SDK to link an ELF.
#
#   make emit KLIN=/path/to/klin/bin/klin.dart

KLIN ?= klin

.PHONY: all emit clean

all: emit

emit: out/http_get.c

out/http_get.c out/http_get.link: http_get.kl $(wildcard ../../gd32v_http/*.kl) $(wildcard ../../gd32v_http/*.[ch])
	@mkdir -p out
	@case "$(KLIN)" in \
	  *.dart) dart run "$(KLIN)" --emit-c http_get.kl ;; \
	  *) "$(KLIN)" --emit-c http_get.kl ;; \
	esac

clean:
	rm -rf out
