.PHONY: makefile
#Custom settings so that shared.mk thinks that this folder is a subdirectory of '../babs'
staging_dir=.

include shared.mk

shared.mk: ../babs/docs/shared.mk
	cp $< $@


ifeq ($(WRAP),none)
##     To be executed directly, so can expose targets without need for wrapping (in sbatch/container)
.PHONY: site

site: renv.lock | ../test/babs/differential/results/latest ## Create pkgdown site in ./docs
	rsync -ar ../babs/differential/R/ R/
	rsync -ar ../babs/differential/resources/ resources/
	rm R/example-spec.r || true
	mkdir -p pkgdown/assets
	if [ -d ../test/babs/differential/results/latest ]; then \
	  cp -lr ../test/babs/differential/results/latest pkgdown/assets/test ;\
	fi
	sed -i 's,/blob/[^/]*/babs/,/blob/$(shell git rev-parse --abbrev-ref HEAD)/babs/,' _pkgdown.yml
	rm -rf docs
	$(R) -e 'library(renv); restore(); roxygen2::roxygenise(); pkgdown::build_site(examples=FALSE)'
	rm -rf pkgdown

../test/babs/differential/results/latest:
	cd .. && make test-differential

renv.lock:
	mv DESCRIPTION no-DESCRIPTION
	$(R) -e 'library(renv); init()'
	mv no-DESCRIPTION DESCRIPTION
endif

ifeq ($(WRAP),container)
##   To be executed by container so prefix the original call to make with the container
%: $(optionalContainer)
	$(containerPrefix) make $@ EXECUTOR=make
endif

ifeq ($(WRAP),sbatch)
## To be submitted. slurm_wrap contains an instruction to do the 'make' on a node.
%: $(optionalContainer)
	sbatch $(default_sbatch_args) $(sbatch_args) --wrap='$(slurm_wrap)'
endif

publish:
	rsync -a --delete docs/ /nemo/stp/babs/www/html/internal/resources/info/babs-rnaseq 
	tmpdir=$$(mktemp -d) ;\
	git worktree add $$tmpdir gh-pages ;\
	rsync -a --delete docs/ $$tmpdir/docs/ ;\
	(cd $$tmpdir ;\
	git commit -a -m "Updating docs to those of $(VERSION)" ;\
	git push origin gh-pages) ;\
	git worktree remove --force $$tmpdir


################################################################
#### Helper goals
################################################################


clean: ## Remove the staging folder and the log directory - these should never contain anything of lasting interest that can't be recreated
	rm -rf R docs man NAMESPACE renv renv.lock pkgdown .Rprofile


MAKEFLAGS += --no-builtin-rules
