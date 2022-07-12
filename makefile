.PHONY: help
help:
	echo "'update' is an experimental way of refreshing contents - probably wise to avoid currently"

.PHONY: update
	rsync -avzp {{source_dir}}/ .

$(V).SILENT:
