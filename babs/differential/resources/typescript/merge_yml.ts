import { parse, stringify } from "https://deno.land/std/encoding/yaml.ts";
import { parse as flag} from "https://deno.land/std/flags/mod.ts";

const flags = flag(Deno.args, {string: [
    "script", "fixed", "generated", "alignment", "spec", "author"
]});

//// Gather the constituent parameters

// From the source yaml
var perPage
if ((flags.spec)=="") {
    perPage = {
	title: " " + flags.alignment,
	description: " of " + flags.alignment + "-aligned data",
	categories: [flags.alignment],
	params: {
	    alignment: flags.alignment,
	}
    }
} else {
    perPage = {
	title: " " + flags.alignment + " " + flags.spec,
	description: " of " + flags.alignment + "-aligned data according to plan '" + flags.spec + "'",
	categories: [flags.alignment, flags.spec],
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
