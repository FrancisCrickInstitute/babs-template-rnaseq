#! /usr/bin/env bash

#tar -xzf /nemo/stp/babs/working/bioinformatics/templates/rnaseq.tar.gz --strip=2 babs/differential

# `label can be anything, but ideally reflects/distinguishes the way
# the counts were arrived at (e.g. we typically use something like
# label=GRCh38)
label=preprocessed

if [ -d ../docs ] || [ -d ../ingress ] || [ -d ../nfcore ]; then
    echo -e "\x1B[31mThis directory has siblings that will confuse the 'isolation'\x1B[0m"
    exit -1
fi

if [ ! -d .git ]; then 
    git init
    git commit --allow-empty -m "Create empty repository"
    echo "Created an empty git repo just for this directory"
    git tag bootstrap-isolated-analysis
else
    if [ "$(git describe --tags --abbrev=0)" != "bootstrap-isolated-analysis" ]; then
	echo -e "\x1B[31mThere's an existing git repo. There's a possibility that the pipeline will add commits to it, so maybe starting in a fresh subdirectory if that worries you.\x1B[0m"
    fi
fi



mkdir -p extdata

if ! compgen -G "extdata/*.spec" > /dev/null; then
    cp R/example-spec.r extdata/example.spec
    echo -e "\x1B[31mPlease check the spec-file in the extdata/ folder\x1B[0m"
    exit -1
fi

# the config file is the sentinel that informs the analysis of the
# label, so there must be one *.config file:
if [ ! -f extdata/${label}.config ]; then
    echo "org.db=org.Hs.eg.db" > extdata/${label}.config
    echo -e "\x1B[31mPlease check the extdata/${label}.config file, particularly the org.db setting.\x1B[0m"
    exit -1
fi


# Now we need to make up for the lack of counts in ../nfcore, which is the usual way of receiving the quantified results.
# Instead, one of the following should be true
found=false
[ -d extdata/genes.results/${label}/ ] && [ "$(find extdata/genes.results/${label} -type f | head -n 1)" ] && found="You have chosed to supply the genes.results files in the appropriate directory"
[ -f extdata/${label}.csv ] && found="You have chosen to supply a csv containing the experiment table, which will have random counts assigned to 1000 arbitrary genes for simulation purposes"
[ -f extdata/${label}.rds ] && found="You have chosen to supply a DESeqDataSet in the form of an rds file"
[ -f extdata/${label}.rda ] && found="You have chosen to supply an rda file that contains at least one DESeqDataSet object (we'll use the 'first')"

if [ ${found} = false ]; then
    echo -e "\x1B[31mYou haven't supplied any of extdata/${label}.{rda,rds,csv} or extdata/genes.results/${label}/\x1B[0m"
    exit -1
else
    echo $found
fi



