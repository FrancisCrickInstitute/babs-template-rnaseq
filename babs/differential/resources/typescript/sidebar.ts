import { parse, stringify } from "stdlib/yaml";
import { parse as get_args} from "stdlib/flags";
import { extractYaml }  from "stdlib/front_matter";

const args = get_args(Deno.args, {
    string: ["template", "staging", "repo", "sections", "alignments", "specfiles", "multiqc"]
});

const quarto = parse(Deno.readTextFileSync(args.template));
const qmdre = new RegExp(".qmd$");
const qmds = Array.from(Deno.readDirSync(args.staging))
    .filter( f => qmdre.test(f.name))
    .sort((a,b) => a.name.localeCompare(b.name));
quarto.project.render = ["index.qmd"].concat(qmds.map(q => q.name));

const sections=args.sections.split(",");
const alignments=args.alignments.split(",");
const specfiles=args.specfiles.split(",");

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
    const short_align=(alignments.length==1)?"":(" " + alignments[a]);
    const mqc=args.multiqc.split(",").includes(alignments[a])?(
	[{
	    href: "../multiqc-" + alignments[a] + "/multiqc_report.html",
	    text: counter() + " MultiQC Report" + short_align,
	    target: "_blank"}]
    ):(
	[]);
    const thisalign={
	section: capitalizeFirstLetter(alignments[a]) + ":",
	contents:mqc
    };
    
    for (const nospec in nospecs) {
        const navItem=qmd2nav(nospecs[nospec]+"_"+alignments[a] + ".qmd", args, short_align);
	if (navItem) {
          thisalign.contents.push(navItem);
	}
    }
    const spec_sections=specfiles.map(
	s => hasspecs.map(
	    sec => qmd2nav(sec + "_" + s + "_"+alignments[a] + ".qmd", args, short_align))
	    .filter(item => item !== null)
    ).filter(x => x.length != 0);
    if (spec_sections.length==1) {
	thisalign.contents = thisalign.contents.concat(spec_sections[0]);
    } else {
	for (const spec in specfiles) {
	    const spec_sections = hasspecs.map(
		sec => qmd2nav(sec + "_" + specfiles[spec] + "_"+alignments[a] +  ".qmd",
			    args,
			    short_align +" " + specfiles[spec]))
		  .filter(item => item !== null);
	    if (spec_sections.length > 0) {
	    	    thisalign.contents.push({
		    	section: capitalizeFirstLetter(specfiles[spec]) + ":",
			contents: spec_sections
		    });	
	    }	
	}
    }
    contents.push(thisalign);
}
if (alignments.length==1) {
    quarto.website.sidebar.contents=contents[0].contents;
}


function qmd2nav(fname, args, suffix) {
    try {
    let { attrs } = extractYaml(Deno.readTextFileSync(args.staging + "/" + fname));
    return({href: fname, text: counter() + " " + attrs.params.section + suffix});
    } catch (err) {
      if (err instanceof Deno.errors.NotFound) {
        return null;
      } else {
        throw err;
     }
   }
}

function capitalizeFirstLetter(str) {
  if (typeof str !== 'string' || str.length === 0) {
    return str; // Handle empty or non-string inputs gracefully
  }
  return str.charAt(0).toUpperCase() + str.slice(1);
}
 
const gh=quarto.website.navbar.right.findIndex(s => s.text=="Github repository");
if (gh != -1) {
    quarto.website.navbar.right[gh].href = args.repo;
}
console.log(stringify(quarto, {lineWidth: -1}));

