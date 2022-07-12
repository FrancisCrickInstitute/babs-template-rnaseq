.PHONY: all
all: differential

stages := ingress nfcore differential biologic simulation

nfcore: ingress
differential: nfcore
biologic: differential

.PHONY: $(stages)
$(stages) : % : %.log


$(stages:%=%.log) : %.log :
	cd $* && $(MAKE) build > ../$*.err 2>&1 && $(MAKE) run >> ../$*.err 2>&1
	mv $*.err $*.log


cleaners := $(stages:%=clean-%)
.PHONY: $(cleaners) clean
clean: $(cleaners)
	rm -f $(logs)

$(cleaners) : clean-% :
	cd $* && $(MAKE) clean
