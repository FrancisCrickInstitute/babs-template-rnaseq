import { parse, stringify } from "jsr:@std/yaml";
import { parseArgs } from "jsr:@std/cli/parse-args";

const args = parseArgs(Deno.args, {
    string: [
	"script", "fixed", "generated", "subsection"
    ],
    default: {subsection: ""}
});




// Helper to detect plain objects
function isPlainObject(obj) {
  return obj && typeof obj === "object" && !Array.isArray(obj);
}

function mergeWithTemplates(target, source, context = null) {
  // Context is always the source (the overriding layer)
  context = context || source;
  // --- Case 1: Arrays → concatenate ---
  if (Array.isArray(target) && Array.isArray(source)) {
      return [...source, ...target];
  }
  // --- Case 2: Objects → deep merge ---
  if (isPlainObject(target) && isPlainObject(source)) {
    const result = { ...target };
    for (const key of Object.keys(source)) {
      if (key in result) {
        result[key] = mergeWithTemplates(result[key], source[key], context);
      } else {
        result[key] = source[key];
      }
    }
    return result;
  }
  // --- Case 3: Atomic values ---
  // If the target is a template, expand it using the new (source) context
    if (typeof target === "string" && target.includes("${")) {
	return target.replace(/\$\{([^}]+)\}/g, (_, key) => { return context[key.trim()];});
  }
  // Otherwise replace
  return source;
}

//// Gather the constituent parameters

// From the source yaml
const perPage = (args.subsection === "")? {} : parse(Deno.readTextFileSync(args.subsection));

// From the script
const script = Deno.readTextFileSync(args.script);
const yamlRegEx = /^---\s*$/gm;
var match = yamlRegEx.exec(script);
const start = match.index;
match = yamlRegEx.exec(script);
const end = match.index;
var fromScript=parse(script.substring(start,end).replace(yamlRegEx,""));

// From the project-wide params in the resource folder
const fixed = parse(Deno.readTextFileSync(args.fixed));

// From the make-generated project-wide file
const generated = parse(Deno.readTextFileSync(args.generated));

// Put them all together

const meta = [fromScript, generated, perPage]
  .reduce((acc, obj) => mergeWithTemplates(acc, obj), fixed);

//And write new header followed by the script
console.log("---");
console.log(stringify(meta, {lineWidth: -1}));
console.log(script.substring(end));
