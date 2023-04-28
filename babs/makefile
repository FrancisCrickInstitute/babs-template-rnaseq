include secrets
all: differential
.PHONY: all clean

stages := ingress nfcore differential biologic 
.PHONY: $(stages)
$(stages): % : %.log

differential: nfcore
nfcore: ingress
ingress: docs
biologic: differential

simulate: simulation.log

%.log : %
	$(MAKE) -C $* build > $*.err 2>&1
	$(MAKE) -C $* run  >> $*.err 2>&1
	mv $*.err $@



cleaners := $(stages:%=clean-%)
clean: $(cleaners)
.PHONY: $(cleaners)

$(cleaners) : clean-% :
	cd $* && $(MAKE) clean
