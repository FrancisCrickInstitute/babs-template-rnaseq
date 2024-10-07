import { parse, stringify } from "https://deno.land/std/encoding/yaml.ts";
import { parse as flag} from "https://deno.land/std/flags/mod.ts";
import { createExtractor, Format, Parser } from "https://deno.land/std/encoding/front_matter/mod.ts";

const flags = flag(Deno.args, {
    string: ["template", "staging", "repo", "sections", "alignments", "specfiles"]
});

const quarto = parse(Deno.readTextFileSync(flags.template));
const qmdre = new RegExp(".qmd$");
const extractYAML = createExtractor({ [Format.YAML]: parse as Parser });
const qmds = Array.from(Deno.readDirSync(flags.staging))
    .filter( f => qmdre.test(f.name))
    .sort((a,b) => a.name.localeCompare(b.name));
quarto.project.render = ["index.qmd"].concat(qmds.map(q => q.name));

const sections=flags.sections.split(",");
const alignments=flags.alignments.split(",");
const specfiles=flags.specfiles.split(",");

const nospecs = sections.filter(x => /^00_/.test(x));
const hasspecs = sections.filter(x => !/^00_/.test(x));
const counter = (function () {
    let num = 1;
    return function() {
	return((num++).toString());
    }
})()
    

const contents= quarto.website.sidebar.contents;
for (const a in alignments) {
    var short_align=(alignments.length==1)?"":(" " + alignments[a]);
    var thisalign={
	section: alignments[a],
	contents:[{
	    href: "../multiqc-" + alignments[a] + "/multiqc_report.html",
	    text: counter() + " MultiQC Report" + short_align,
	    target: "_blank"
	}]};
    
    for (const nospec in nospecs) {
	thisalign.contents.push(qmd2nav(nospecs[nospec]+"_"+alignments[a] + ".qmd", flags, short_align));
    }
    if (specfiles.length==1) {
	thisalign.contents = thisalign.contents.concat(hasspecs.map(x => qmd2nav(x + "_" + specfiles[0] + "_"+alignments[a] + ".qmd", flags, short_align)));
    } else {
	for (const spec in specfiles) {
	    thisalign.contents.push({
		section: specfiles[spec],
		contents: hasspecs.map(x => qmd2nav(x + "_" + specfiles[spec] + "_"+alignments[a] +  ".qmd", flags, short_align +" " + specfiles[spec]))
	    });
	}
    }
    contents.push(thisalign);
}
if (alignments.length==1) {
    quarto.website.sidebar.contents=contents[0].contents;
}


function qmd2nav(fname, flags, suffix) {
    let { attrs, body, frontMatter } = extractYAML(Deno.readTextFileSync(flags.staging + "/" + fname));
    return({href: fname, text: counter() + " " + attrs.params.section + suffix});
}

 
const gh=quarto.website.navbar.right.findIndex(s => s.text=="Github repository");
if (gh != -1) {
    quarto.website.navbar.right[gh].href = flags.repo;
}
console.log(stringify(quarto, {lineWidth: -1}));
