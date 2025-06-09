.PHONY: makefile
#Custom settings so that shared.mk thinks that this folder is a subdirectory of '../babs'
staging_dir=.

include ../babs/docs/shared.mk
include ../babs/docs/secret.mk

.PHONY: site

wrapped-targets=site renv.lock

ifeq ($(SUBMIT),false)
    ifeq ($(CONTAIN),false)
##    To be executed directly - no need for (further) wrapping in queue/container functionality

site: renv.lock ## Create pkgdown site in ./docs
	rm -rf R
	cp -lr ../babs/differential/R .
	rm R/example-spec.r
	mkdir -p pkgdown/assets
	if [ -d ../test/babs/differential/results/latest ]; then \
	  cp -lr ../test/babs/differential/results/latest pkgdown/assets/test ;\
	fi
	sed -i 's,/blob/[^/]*/babs/,/blob/$(shell git rev-parse --abbrev-ref HEAD)/babs/,' _pkgdown.yml
	rm -rf docs
	$(R) -e 'roxygen2::roxygenise(); pkgdown::build_site()'
	rm -rf pkgdown R

renv.lock: .Rprofile
	  $(R) -e 'library(renv); init(); renv::install(c("roxygen2", "pkgdown")); renv::snapshot(type="all")'
    else
##   To be executed by container without slurm, so prefix the original call to make with the container
$(wrapped-targets): $(optionalRenviron)
	$(containerPrefix) make $@ EXECUTOR=make
    endif
else
## To be submitted.  The 'slurm' variable (in 'shared.mk') has the sbatch options, and a possibly
## containerised call to make

$(wrapped-targets): $(optionalContainer)
	echo "$$slurm" | sbatch 
endif

publish:
	rsync -a --delete docs/ /nemo/stp/babs/www/html/internal/resources/info/babs-rnaseq 
	tmpdir=$$(mktemp -d) ;\
	git worktree add $$tmpdir gh-pages ;\
	rsync -a --delete docs/ $$tmpdir/docs/ ;\
	(cd $$tmpdir ;\
	git commit -a -m "Updating docs to those of $(VERSION)" ;\
	git push origin gh-pages) ;\
	git worktree remove $$tmpdir


################################################################
#### Helper goals
################################################################


clean: ## Remove the staging folder and the log directory - these should never contain anything of lasting interest that can't be recreated
	rm -rf R docs man NAMESPACE Renviron.site renv renv.lock .Rprofile pkgdown


MAKEFLAGS += --no-builtin-rules
