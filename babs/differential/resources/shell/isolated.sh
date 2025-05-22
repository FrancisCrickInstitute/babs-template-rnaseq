#! /usr/bin/env bash

# tar -xzf /nemo/stp/babs/working/bioinformatics/templates/rnaseq.tar.gz --strip=2 babs/differential
# make check-isolated
if [[ -z "$1" ]]; then
    if [[ -d ../docs ]] || [[ -d ../ingress ]] || [[ -d ../nfcore ]]; then
	echo -e "  \x1B[31mThis directory has siblings that will confuse the 'isolation'\x1B[0m"
	exit -1
    fi

    if [[ ! -d .git ]]; then 
	git init
	git commit --allow-empty -m "Create empty repository"
	echo "  Created an empty git repo just for this directory"
	git tag bootstrap-isolated-analysis
    else
	if [[ "$(git describe --tags --abbrev=0)" != "bootstrap-isolated-analysis" ]]; then
	    echo -e "  \x1B[31mThere's an existing git repo. There's a possibility that the pipeline will add commits to it, so maybe starting in a fresh subdirectory if that worries you.\x1B[0m"
	fi
    fi
    
    mkdir -p extdata
    
    if ! compgen -G "extdata/*.spec" > /dev/null; then
	cp R/example-spec.r extdata/example.spec
	echo "  No spec-file found"
	echo -e "  \x1B[31mPlease check the spec-file in the extdata/example.spec\x1B[0m"
	exit -1
    fi
    exit 0
fi



# the config file is the sentinel that informs the analysis of the
# real label, so there must be one *.config file:
if [[ ! -f extdata/$1.config ]]; then
    sed -e "s/example/$1/" resources/shell/example.config > extdata/$1.config
    echo -e "  \x1B[31mGenerated an example config in extdata/$1.config file, please check it carefully.\x1B[0m"
    exit -1
fi


# Now we need to make up for the lack of counts in ../nfcore, which is the usual way of receiving the quantified results.
# Instead, one of the following should be true
found=false
need_metadata=false
[[ -d extdata/genes.results/$1/ ]] && [[ "$(find extdata/genes.results/$1 -type f | head -n 1)" ]] && found="You have chosed to supply the genes.results files in the appropriate directory" && need_metadata=true
[[ -f extdata/$1.csv ]] && found="You have chosen to supply a csv containing the assay data." && need_metadata=true
[[ -f extdata/$1.rds ]] && found="You have chosen to supply a DESeqDataSet in the form of an rds file"
[[ -f extdata/$1.rda ]] && found="You have chosen to supply an rda file that contains at least one DESeqDataSet object (we'll use the 'first')"

if [[ ${need_metadata} = true ]] && [[ ! -f extdata/metadata.csv ]]; then
    echo -e "  \x1B[31mFor this way of providing data, you also need to supply extdata/metadata.csv, which is missing in this case. \x1B[0m"
    exit -1
fi


if [[ ${found} = false ]] && [[ ! -f extdata/metadata.csv ]]; then
    echo -e "  \x1B[31mYou haven't supplied any of extdata/$1.{rda,rds,csv} or extdata/genes.results/$1/. Nor have you provided extdata/metadata.csv\x1B[0m"
    exit -1
fi

if [[ ${found} = false ]] ; then
    if awk 'NR > 1 && $0 !~ /^,/' extdata/metadata.csv | grep -q .; then
	echo -e "  You provided extdata/metadata.csv, but \x1B[31mnot any of extdata/$1.{rda,rds,csv} or extdata/genes.results/$1/.\x1B[0m"
	exit -1
    else
	echo "  You have supplied extdata/metadata.csv. The first column appears blank, so random counts will be assigned to 1000 arbitrary genes for simulation purposes. " 
    fi
else
    echo "  $found"
    echo "  Everything appears to be in place for $1"
fi
