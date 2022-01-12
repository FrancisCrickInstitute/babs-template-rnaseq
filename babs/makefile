all: differential

ingress: 
	cd $< && $(MAKE) bootstrap && $(MAKE) all

nfcore: 
	cd $< && $(MAKE) bootstrap && $(MAKE) all

differential: nfcore
	cd $< && $(MAKE) bootstrap && $(MAKE)





clean:
	cd nfcore && rm -rf work	
