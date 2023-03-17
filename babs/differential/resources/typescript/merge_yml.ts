import { parse, stringify } from "https://deno.land/std/encoding/yaml.ts";
import { parse as flag} from "https://deno.land/std/flags/mod.ts";

var yamlRegEx = /^---\s*$/gm;

const flags = flag(Deno.args, {
    string: ["script", "yml"]
});

const script = Deno.readTextFileSync(flags.script);
var match = yamlRegEx.exec(script);
const start = match.index;
match = yamlRegEx.exec(script);
const end = match.index;

var frontmatter=parse(script.substring(start,end).replace(yamlRegEx,""));
var yml = parse(Deno.readTextFileSync(flags.yml))[0];


const params = {...frontmatter.params, ...yml.params};
delete frontmatter.params;
delete yml.params;

yml.title = frontmatter.title + " " + yml.title;
yml.description = frontmatter.description + " " + yml.description
yml.categories = yml.categories.concat(frontmatter.categories);
var meta = {...frontmatter, ...yml};
meta.params=params;

console.log("---");
console.log(stringify(meta));
console.log(script.substring(end));
