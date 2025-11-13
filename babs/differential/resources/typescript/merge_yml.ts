import { parse, stringify } from "stdlib/yaml";
import { parse as flag} from "stdlib/flags";

const flags = flag(Deno.args, {string: [
    "script", "target", "fixed", "generated", "alignment", "spec", "author"
]});

//// Gather the constituent parameters

// From the source yaml
var perPage
const align_text=Deno.readTextFileSync(`extdata/${flags.alignment}.config`, "utf-8");
const amatch = align_text.match(new RegExp(`${flags.alignment}\\.categories\\s*=\\s*(.*)`));
const align_categories = amatch ? amatch[1].split(" ") : [flags.alignment];
if ((flags.spec)=="") {
    perPage = {
	title: " " + flags.alignment,
	description: " of " + flags.alignment + "-aligned data",
	categories: align_categories,
	params: {
	    alignment: flags.alignment,
	}
    }
} else {
    const text = Deno.readTextFileSync(`extdata/${flags.spec}.spec`, "utf-8");
    const categoryPattern = /^#'\s*@categories\s+(.+)$/gm;
    let match;
    const spec_categories: string[] = [];
    while ((match = categoryPattern.exec(text)) !== null) {
	const raw = match[1].trim();
	spec_categories.push(...raw.split(",").map(c => c.trim()));
    }
    if (spec_categories.length==0) {
	spec_categories.push(flags.spec);
    }
    perPage = {
	title: " " + flags.alignment + " " + flags.spec,
	description: " of " + flags.alignment + "-aligned data according to plan '" + flags.spec + "'",
	categories: align_categories.concat(spec_categories),
	params: {
	    alignment: flags.alignment,
	    spec: flags.spec
	}
    }
}


// From the script
const script = Deno.readTextFileSync(flags.script);
const yamlRegEx = /^---\s*$/gm;
var match = yamlRegEx.exec(script);
const start = match.index;
match = yamlRegEx.exec(script);
const end = match.index;
var fromScript=parse(script.substring(start,end).replace(yamlRegEx,""));

// From the project-wide params in the resource folder
const fixed = parse(Deno.readTextFileSync(flags.fixed));

// From the make-generated project-wide file
const generated = parse(Deno.readTextFileSync(flags.generated));

// Put them all together
const params = {...fixed, ...fromScript.params, ...generated, ...perPage.params};
params.script = flags.target;
delete fromScript.params;
delete perPage.params;

perPage.title = ((fromScript.title || "") +  (perPage.title || "")).replace(/\s+/g, ' ').trim() ;
perPage.description = ((fromScript.description || "" ) +   (perPage.description || "")).replace(/\s+/g, ' ').trim();
perPage.categories = [...new Set((perPage.categories || []).concat((fromScript.categories || [])))];
perPage.author=fromScript.author;
perPage.author[0].name = flags.author;
var meta = {...fromScript, ...perPage};
meta.params=params;

//And write new header followed by the script
console.log("---");
console.log(stringify(meta, {lineWidth: -1}));
console.log(script.substring(end));
