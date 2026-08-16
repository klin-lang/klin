# GD32VW553 TCP client — Klin emit-c (needs sibling gd32v_wifi path).
#
#   make emit KLIN=/path/to/klin/bin/klin.dart

KLIN ?= klin

.PHONY: all emit clean

all: emit

emit: out/tcp_client.c

out/tcp_client.c out/tcp_client.link: tcp_client.kl $(wildcard ../../gd32v_sockets/*.kl) $(wildcard ../../gd32v_sockets/*.[ch])
	@mkdir -p out
	@case "$(KLIN)" in \
	  *.dart) dart run "$(KLIN)" --emit-c tcp_client.kl ;; \
	  *) "$(KLIN)" --emit-c tcp_client.kl ;; \
	esac

clean:
	rm -rf out
