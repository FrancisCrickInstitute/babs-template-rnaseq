import { parse, stringify } from "https://deno.land/std/encoding/yaml.ts";
import { parse as flag} from "https://deno.land/std/flags/mod.ts";

const flags = flag(Deno.args, {
    string: ["template", "staging", "tag", "repo", "sections", "alignments", "specfiles"]
});

const quarto = parse(Deno.readTextFileSync(flags.template));
const qmdre = new RegExp(flags.tag.concat(".qmd$"));
const qmds = Array.from(Deno.readDirSync(flags.staging))
    .filter( f => qmdre.test(f.name))
    .sort((a,b) => a.name.localeCompare(b.name));
quarto.project.render = ["index.qmd"].concat(qmds.map(q => q.qmd));

const sections=flags.sections.split(",");
const alignments=flags.alignments.split(",");
const specfiles=flags.specfiles.split(",");

const nospecs = sections.filter(x => /^00_/.test(x));
const hasspecs = sections.filter(x => !/^00_/.test(x));

const contents= quarto.website.sidebar.contents;
for (const a in alignments) {
    var thisalign={
	section: alignments[a],
	contents:[{
	    href: "../multiqc-" + alignments[a] + "/multiqc_report.html",
	    text: "MultiQC Report",
	    target: "_blank"
	}]};
    
    for (const nospec in nospecs) {
	thisalign.contents.push(nospecs[nospec]+"_"+alignments[a]+flags.tag + ".qmd");
    }
    for (const spec in specfiles) {
	thisalign.contents.push({
	    section: specfiles[spec],
	    contents: hasspecs.map(x => x + "_" + specfiles[spec] + "_"+alignments[a] + flags.tag + ".qmd")
	})
    }
    contents.push(thisalign);
}

 
const gh=quarto.website.navbar.right.findIndex(s => s.text=="Github repository");
if (gh != -1) {
    quarto.website.navbar.right[gh].href = flags.repo;
}
console.log(stringify(quarto, {lineWidth: -1}));
