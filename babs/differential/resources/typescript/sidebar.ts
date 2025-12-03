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
quarto.project.render = ["index.qmd", ...flatList];

const gh=quarto.website.navbar.right.findIndex(s => s.text=="Github repository");
if (gh != -1) {
    quarto.website.navbar.right[gh].href = args.repo;
}
console.log(stringify(quarto, {lineWidth: -1}));


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
function expandAxesForNav(axes, staging, prefix = {}) {
    const flatList = [];

    function recurse(keys, prefix) {
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
		    let label = capitalizeFirstLetter(children[0].params?.[currentKey] || val);
		    const filteredParams = Object.fromEntries(
			Object.keys(prefix)
			    .filter(k => k in (children[0].params || {}))
			    .map(k => [k, children[0].params[k]])
		    );
		    children.forEach(child => {
			delete child.params;
		    });
		    if (children.length == 1) {
			results.push({...children[0], params:filteredParams});
		    } else {
			results.push({
			    section: label + ":",
			    contents: children,
			    params: filteredParams
			});
		    }
		}
	    }
	}
	const sectionNodes = results.filter(item => "section" in item);
	
	if (sectionNodes.length === 1 && results.length > 1) {
	    // mixed case: keep non-section items and flatten the single section
	    const flattened = [];
	    for (const item of results) {
		if (item.section && Array.isArray(item.contents)) {
		    flattened.push(...item.contents);
		} else {
		    flattened.push(item);
		}
	    }
	    results = flattened;
	} else if (sectionNodes.length === 1 && results.length === 1) {
	    // single section only: flatten entirely
	    results = sectionNodes[0].contents;
	}
	results.forEach(child => {
	    delete child.params;
	});
	return results;
    }

    const navTree = recurse(Object.keys(axes), prefix);
    return { navTree, flatList };

}

function qmd2nav(fname, staging, param_keys={}) {
    const fpath = `${staging}/${fname}`;
    try {
	const params = extractYaml(Deno.readTextFileSync(fpath)).attrs?.params || {};
	const sectionName = params.section || fname.replace(/\.qmd$/, "");
	const filteredParams = Object.fromEntries(
	    param_keys
		.filter(k => k in params)
		.map(k => [k, params[k]])
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

