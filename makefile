.PHONY: update
	rsync -avzp {{source_dir}}/ .

$(V).SILENT:
