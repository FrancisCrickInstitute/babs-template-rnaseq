.PHONY: all
all: differential.log

stages := ingress nfcore differential biologic 
logs = $(stages:%=%.log)


nfcore.log: ingress.log
differential.log: nfcore.log
biologic.log: differential.log


$(logs) : %.log :
	cd $* && $(MAKE) build > ../$*.err 2>&1 && $(MAKE) run >> ../$*.err 2>&1
	mv $*.err $*.log

.PHONY: simulation
simulation: simulation.log

cleaners := $(stages:%=clean-%)
.PHONY: $(cleaners) clean
clean: $(cleaners)
	rm -f $(logs)

$(cleaners) : clean-% :
	cd $* && $(MAKE) clean
