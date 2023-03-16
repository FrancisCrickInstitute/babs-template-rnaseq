import { parse, stringify } from "https://deno.land/std/encoding/yaml.ts";
import { parse as flag} from "https://deno.land/std/flags/mod.ts";

const flags = flag(Deno.args, {
    string: ["template", "staging", "tag"]
});

const quarto = parse(Deno.readTextFileSync(flags.template));
const qmdre = new RegExp(flags.tag.concat(".qmd$"));
const qmds = Array.from(Deno.readDirSync(flags.staging))
    .filter( f => qmdre.test(f.name))
    .map(f => ({qmd: f.name, yml: f.name.replace(qmdre,".yml")}))
    .sort((a,b) => a.qmd.localeCompare(b.qmd));

const contents= quarto.website.sidebar.contents;
for (const q in qmds) {
    const yml = parse(Deno.readTextFileSync(flags.staging.concat("/",qmds[q].yml)))[0];
    if (! ('alignment' in yml.params) ) { continue; }
    let align_i: bigint = contents.findIndex(s => s.section==yml.params.alignment);
    if (align_i == -1) {
	contents.push({section: yml.params.alignment, contents:[]});
	align_i=contents.length-1;
    }
    if ('spec' in yml.params) {
	const spec_i: bigint = contents[align_i].contents.findIndex(s => s.section==yml.params.spec);
	if (spec_i == -1) {
	    contents[align_i].contents.push({section: yml.params.spec, contents:[qmds[q].qmd]});
	} else {
	    contents[align_i].contents[spec_i].contents.push(qmds[q].qmd)
	}
    } else {
	contents[align_i].contents.push(qmds[q].qmd);
    }

}
console.log(stringify(quarto));
