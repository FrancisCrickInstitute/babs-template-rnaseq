alignments=$(firstword $(patsubst ../%.config,%,$(wildcard ../*.config)))
configs = $(patsubst %,%.config,$(alignments))
experiment_table=experiment_table
include $(configs)
samples=$(shell  seq -f "S%g" -s ' ' `tail -n +2 ../$(experiment_table).csv |wc -l`)
genes.results=$(patsubst %,$(differential)/extdata/genes.results/$(alignments)/%.genes.results,$(samples))
examplar=SRR1039508.genes.results

gtf=$($(alignments).gtf)
differential=differential
targz=/nemo/stp/babs/working/bioinformatics/templates/rnaseq.tar.gz

r_offset=txi$counts <- txi$counts+rnbinom(prod(dim(txi$counts)), size=100, prob=0.5)
r_tx=txi <- tximport(tx_path, type="rsem")

run: $(genes.results)
	cp  $(differential)/extdata/metadata.csv $(differential)/extdata/metadata_$(alignments).csv
	cp ../*.spec $(differential)
	cp $(configs) $(differential)/
	rm -f proto.genes.results
	rm $(exemplar)

$(configs): %.config: ../%.config
	tr -d '\r' < $< | sed  's/^$*\.//' > $@
	grep -q "^genome_fasta" $@ || echo "WARNING: No genom_fasta set in $*.config"
	grep -q "^gtf" $@ || echo "WARNING: No gtf set in $*.config"
	grep -q "^universal" $@ || sed -i -e '$$auniversal=yes' $@
	grep -q "^strandedness" $@ || sed -i -e '$$astrandedness=auto' $@
	sed -i 's/^/$*./' $@

gr: $(genes.results)

$(genes.results): proto.genes.results $(differential)/extdata/metadata.csv | $(dir $(firstword $(genes.results)))
	cp $< $@

$(dir $(firstword $(genes.results))):
	mkdir -p $@

proto.genes.results: $(exemplar) $(gtf)
	head -n 1 $< | cut -f1,2 --complement > counts.txt
	tail -n +2 $< | sort -k 5 -r | head -n 5000 | shuf -n 1000 | cut -f1,2 --complement | sed 's/NA/0/' >> counts.txt
	echo "gene_id" > geneid.txt
	sed -E -n '/gene_id/s/.*gene_id "([[:alnum:]]+)".*/\1/p' $(gtf) | uniq | head -n 1000 >> geneid.txt
	echo "transcript_id(s)" > transid.txt
	sed -E -n '/gene_id/s/.*gene_id "([[:alnum:]]+)".*/\1_T/p' $(gtf) | uniq | head -n 1000 >> transid.txt
	paste geneid.txt transid.txt counts.txt > $@
	rm -rf geneid.txt transid.txt counts.txt

$(differential)/extdata/metadata.csv: ../$(experiment_table).csv | $(differential)
	mkdir -p $(differential)/extdata
	tr -d '\r' < $< |  awk 'NR==1 {print}; NR>1 {print "S" (NR-1) $$s}' > $@

$(differential):
	tar -xzf $(targz) babs/differential --strip-components=1
	tar -xzf $(targz) babs/shared.mk babs/secret.mk babs/.pipeline-version -C .. --strip-components=1
	sed -i '/$(r_tx)/a $(r_offset)' $(differential)/resources/00_init.qmd
	rm -rf .git
	git init
	git add makefile
	git commit -m "Running simulation"

SRR1039508.genes.results:
	tar -xzf SRR1039508.tar.gz
