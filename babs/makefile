all: differential

ingress: 
	cd $< && $(MAKE) build && $(MAKE) run

nfcore: 
	cd $< && $(MAKE) build && $(MAKE) run

differential: nfcore
	cd $< && $(MAKE) build && $(MAKE) run

biologic: differential
	cd $< && $(MAKE) build && $(MAKE) run



build-%:
	cd % && $(MAKE) build




clean:
	cd nfcore && rm -rf work	
