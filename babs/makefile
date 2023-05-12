.DEFAULT_GOAL:=all
all: differential
.PHONY: all clean
include secrets

stages := ingress nfcore differential biologic 
.PHONY: $(stages)
$(stages): % : %.log

differential.log: nfcore.log
nfcore.log: ingress.log
ingress.log: docs.log
biologic.log: differential.log

simulate: simulation.log

%.log : 
	$(MAKE) -C $* build > $*.err 2>&1
	$(MAKE) -C $* run  >> $*.err 2>&1
	mv $*.err $@



cleaners := $(stages:%=clean-%)
clean: $(cleaners)
.PHONY: $(cleaners)

$(cleaners) : clean-% :
	cd $* && $(MAKE) clean
