# Host emit-c smoke (stubs, no IDF).

KLIN ?= klin

.PHONY: emit
emit:
	@mkdir -p out
	@case "$(KLIN)" in \
	  *.dart) dart run "$(KLIN)" --emit-c -I../../ -Istubs smoke.kl ;; \
	  *) "$(KLIN)" --emit-c -I../../ -Istubs smoke.kl ;; \
	esac
