.PHONY: all simulate clean update-pipeline

all: differential.log

differential.log: nfcore.log
nfcore.log: ingress.log
ingress.log: docs.log
biologic.log: differential.log

simulate: simulation.log


%.log : %
	$(MAKE) -C $* build > $*.err 2>&1
	$(MAKE) -C $* run  >> $*.err 2>&1
	mv $*.err $@


cleaners := $(patsubst %/,clean-%,$(wildcard */))
.PHONY: $(cleaners)
clean: $(cleaners)
	rm -f *.log
$(cleaners): clean-%:
	$(MAKE) -C $* clean || echo "Couldn't clean $*"

.PHONY: update-pipeline
        rsync -avzp {{source_dir}}/ .
