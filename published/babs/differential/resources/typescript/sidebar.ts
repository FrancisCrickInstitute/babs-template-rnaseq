import { parse, stringify } from "stdlib/yaml";
import { parse as get_args} from "stdlib/flags";
import { extractYaml }  from "stdlib/front_matter";

////////////////////////////////////////////////////////////////
// Logic
////////////////////////////////////////////////////////////////
const counter = (function () {
    let num = 1;
    return function() {
	return((num++).toString());
    }
})()

const args = get_args(Deno.args, {
    string: ["template", "staging", "repo"]
});

const quarto = parse(Deno.readTextFileSync(args.template));
const axes = parse(Deno.readTextFileSync(args.staging + "/_sidebar.yml"));

const { navTree, flatList } = expandAxesForNav(axes, args.staging);
quarto.website.sidebar.contents = navTree;
quarto.project.render = ["index.qmd", "notes.md", ...flatList];

const gh=quarto.website.navbar.right.findIndex(s => s.text=="Github repository");
if (gh != -1) {
    quarto.website.navbar.right[gh].href = args.repo;
}
console.log(stringify(quarto, {lineWidth: -1}).replace(/\n$/, ''));


////////////////////////////////////////////////////////////////
// Function Definitions
////////////////////////////////////////////////////////////////


/**
 * Recursively expand axes into a nested nav tree,
 * passing params from qmd2nav and collecting a flat list of hrefs.
 *
 * axes: object with arrays for each axis (e.g., { align, spec, script })
 * args: arguments including `staging` path
 *
 * Returns: { navTree, flatList }
 */
function expandAxesForNav(axes, staging) {
    const flatList = [];

    function recurse(keys, prefix={}) {
	if (keys.length === 0) {
	    const fname =
		  Object.keys(prefix).reverse().map(k => prefix[k]).filter(v => v != null && v !== "").join("_") + ".qmd";
	    
	    const nav = qmd2nav(fname, staging, Object.keys(prefix));
	    if (nav) {
		flatList.push(nav.href);
		return [nav];
	    }
	    return [];
	}

	const [currentKey, ...restKeys] = keys;
	const values = axes[currentKey];
	var results = [];

	for (const val of values) {
	    const nodePrefix = { ...prefix, [currentKey]: val };
	    const children = recurse(restKeys, nodePrefix);

	    if (children.length > 0) {
		if (val === null) {
		    // Flatten null branch
		    results.push(...children);
		} else {
		    // Use params from first child for section label
		    const nameVal = children.reduce((found, child) =>
			found || child.params?.[currentKey + "name"] || null, null
		    );
		    // capture specname (non-empty) before params are deleted
		    const nonEmptyNameVal = nameVal || null;
		    
		    let label = capitalizeFirstLetter(
			nonEmptyNameVal ||
			    children[0].params?.[currentKey] ||
			    val
		    );
		    
		    const filteredParams = Object.fromEntries(
			[currentKey, ...Object.keys(prefix)]
			    .flatMap(k => {
				const sourceForK     = children.find(c => k in (c.params || {}) && c.params[k] !== '');
				const sourceForKName = children.find(c => (k+"name") in (c.params || {}) && c.params[k+"name"] !== '');
				const entries = [];
				if (sourceForK)     entries.push([k, sourceForK.params[k]]);
				if (sourceForKName) entries.push([k+"name", sourceForKName.params[k+"name"]]);
				return entries;
			    })
		    );
		    
		    // only delete params AFTER filteredParams is built
		    children.forEach(child => {
    delete child.params;
		    });
		    if (
		        children.length === 1 &&
			    children[0] &&
			    typeof children[0].href === "string" &&
			    typeof children[0].text === "string" &&
			    !("section" in children[0])
		    ) {
			results.push({
			    ...children[0],
			    params: filteredParams
			});
		    } else {
			
			results.push({
			    section: (quarto?._prefixes?.[currentKey] ?? "") + label + ":",
			    contents: children,
			    params: filteredParams
			});
		    }
		}
	    }
	}
	const sectionNodes = results.filter(item => "section" in item);
	// Only collapse structural wrapper if it is a pure passthrough
	if (sectionNodes.length === 1 && results.length === 1) {
	    const only = sectionNodes[0];
	    
	    // Collapse only if the section adds no real grouping value
	    if (Array.isArray(only.contents)) {
		results = only.contents;
	    }
	}
	// If this axis has only one non-null value,
	// promote its section contents upward
	if (
	    values.filter(v => v !== null).length === 1
	) {
	    const promoted = [];
	    for (const item of results) {
		if (item.section && Array.isArray(item.contents)) {
		    promoted.push(...item.contents);
		} else {
		    promoted.push(item);
		}
	    }
	    results = promoted;
	}
	// results.forEach(child => {
	//     delete child.params;
	// });
	return results;
    }

    const navTree = recurse(Object.keys(axes).filter(k => k !=="_prefixes"));
    return { navTree, flatList };

}

function qmd2nav(fname, staging, param_keys={}) {
    const fpath = `${staging}/${fname}`;
    try {
	const params = extractYaml(Deno.readTextFileSync(fpath)).attrs?.params || {};
	const sectionName = params.section || fname.replace(/\.qmd$/, "");
	const filteredParams = Object.fromEntries(
	    param_keys
		.flatMap(k => {
		    const entries = [];
		    if (k in params)             entries.push([k, params[k]]);
		    if ((k + "name") in params)  entries.push([k + "name", params[k + "name"]]);
		    return entries;
		})
	);
	return {
	    href: fname,
	    text: counter() + " " + sectionName,
	    params: filteredParams
	};
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

