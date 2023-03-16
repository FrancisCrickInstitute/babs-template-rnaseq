all: differential
.PHONY: all clean

stages := ingress nfcore differential biologic 
.PHONY: $(stages)

ingress: 
nfcore: ingress
differential: nfcore
biologic: differential

$(stages):
	cd $@ && $(MAKE) build && $(MAKE) run



cleaners := $(stages:%=clean-%)
clean: $(cleaners)
.PHONY: $(cleaners)

$(cleaners) : clean-% :
	cd $* && $(MAKE) clean
