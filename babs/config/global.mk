label_column := sample # which column from the ASF csv to use in nf-core.  Maybe sample_name
SQLITE=ml SQLite/3.36-GCCcore-11.2.0; sqlite3
babsid=$(shell sed -n  "s/ *Hash: *//p" ../../.babs)

#Debugging tool - `make print-varname` will show variable's value
print-%: ; @echo $*=$($*)
