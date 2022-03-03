template := ./demo
git_stat = $(shell git status -uno --porcelain || echo "'git status' error")
test := $(shell mktemp -d)
ifneq ($(template),./demo)
template=$(template)/rnaseq/babs
endif

.PHONY: deploy
deploy:
	[[ -z "$(git_stat)" ]] || { printf 'Repository not in clean state: %s\n' "${gitstat} "  ; exit 1 ; }
	git clone . $(test) || { echo "Can't clone to $(test) - perhaps 'rm' it?" ; exit 1 ; }
	echo "Created intermediate deployment: $(test)"
	rm -rf $(test)/.git
	mkdir -p $(template) ;\
	rsync -avzp $(test)/babs/ $(template)
	rm -rf $(test)

demo: 
	rsync -avzp -exclude '.~' babs/ demo


$(V).SILENT:
