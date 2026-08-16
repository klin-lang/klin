# GD32VW553 sockets smoke — Klin emit-c / test.
#
#   make emit KLIN=/path/to/klin/bin/klin.dart

KLIN ?= klin

.PHONY: all emit clean

all: emit

emit: out/smoke.c

out/smoke.c out/smoke.link: smoke.kl $(wildcard ../../gd32v_sockets/*.kl) $(wildcard ../../gd32v_sockets/*.[ch])
	@mkdir -p out
	@case "$(KLIN)" in \
	  *.dart) dart run "$(KLIN)" --emit-c smoke.kl ;; \
	  *) "$(KLIN)" --emit-c smoke.kl ;; \
	esac

clean:
	rm -rf out
