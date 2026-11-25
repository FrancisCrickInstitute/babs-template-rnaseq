#!/usr/bin/env bash
# Phase 8, step 1 of 2: prepare one eval case from
# skills/babs-rnaseq-downstream/evals/ for an agent trial in the Claude Code
# VS Code extension (Remote-SSH on NEMO). You then open the printed folder in
# VS Code, start a new Claude session there and paste the prompt;
# finish-trial.sh collects the result. See tests/RUNBOOK.md, "Phase 8".
#
# Usage: prepare-trial.sh CASE [--iteration N]
#
# What it does:
#   - refreshes the trial plugin: $BABS_TRIAL_ROOT/trial-plugin/ is a local
#     plugin marketplace holding a copy of this plugin without evals/ and
#     tests/, so the agent cannot read the expected outcomes. It is installed
#     once in the extension (RUNBOOK) and re-read at every session start.
#   - creates $BABS_TRIAL_ROOT/trials/iteration-N/CASE/ in the layout
#     skill-creator's viewer reads, with eval_metadata.json (prompt, graders)
#   - puts the case's inputs in with_skill/outputs/ (the folder you open)
#   - writes with_skill/outputs/.claude/settings.local.json: lets the agent
#     use Bash/Read/Edit/Write/Glob/Grep without asking, and a Stop hook that
#     copies the session transcript to with_skill/transcript.jsonl after
#     every reply
#   - writes with_skill/PROMPT.txt, the text to paste
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN="$(cd "$HERE/.." && pwd)"
REPO="$(cd "$PLUGIN/.." && pwd)"
EVALS="$PLUGIN/skills/babs-rnaseq-downstream/evals"
die() { echo "prepare-trial.sh: $*" >&2; exit 1; }

case_="" it=1
while [[ $# -gt 0 ]]; do
  case "$1" in
    --iteration) it="$2"; shift 2 ;;
    -h|--help) sed -n '2,24p' "$0"; exit 0 ;;
    -*) die "unknown option $1" ;;
    *) case_="$1"; shift ;;
  esac
done
[[ -n "$case_" ]] || die "usage: prepare-trial.sh CASE [--iteration N] (cases: $(ls "$EVALS" | tr '\n' ' '))"
cdir="$EVALS/$case_"
[[ -f "$cdir/prompt.md" ]] || die "no eval case $case_ in $EVALS"
command -v python3 >/dev/null || die "python3 is needed"
command -v rsync >/dev/null || die "rsync is needed"

T="${BABS_TRIAL_ROOT:-/flask/scratch/babs/$USER/skills-test}"
export BABS_TRIAL_ROOT="$T"
export BABS_TRIAL_NFCORE="${BABS_TRIAL_NFCORE:-$T/nfcore}"
export BABS_TRIAL_BASE="${BABS_TRIAL_BASE:-$T/airway}"
[[ -f "$T/.env.local" ]] || echo "prepare-trial.sh: warning: no $T/.env.local; the drivers will not find the image and renv cache settings" >&2

# ---- the trial plugin (a local marketplace). sync-check.sh, run by
# init-workdir.sh, finds the template as ../../babs/differential from shared/,
# so babs/ and pkgdown/ are linked in next to the copy.
mp="$T/trial-plugin"
mkdir -p "$mp/.claude-plugin"
rsync -a --delete --exclude '/skills/babs-rnaseq-downstream/evals/' --exclude '/tests/' "$PLUGIN/" "$mp/babs-rnaseq-skills/"
ln -sfn "$REPO/babs" "$mp/babs"
ln -sfn "$REPO/pkgdown" "$mp/pkgdown"
cat > "$mp/.claude-plugin/marketplace.json" <<'EOF'
{
  "name": "babs-trials",
  "owner": { "name": "BABS" },
  "description": "Phase 8 trial copy of babs-rnaseq-skills (no evals or tests)",
  "plugins": [
    { "name": "babs-rnaseq-skills", "source": "./babs-rnaseq-skills",
      "description": "BABS bulk RNA-seq downstream analysis skills" }
  ]
}
EOF
bash "$mp/babs-rnaseq-skills/shared/sync-check.sh" >/dev/null || die "the trial plugin copy fails sync-check.sh"

# ---- the trial folder
caseroot="$T/trials/iteration-$it/$case_"
run="$caseroot/with_skill"
[[ -e "$run" ]] && die "$run already exists; use another --iteration or remove it"
mkdir -p "$run/outputs/.claude"

# prompt.md: a settings block between --- lines, then the prompt
awk 'c>=2 { print; next } /^---$/ { c++ }' "$cdir/prompt.md" | sed '/./,$!d' > "$run/PROMPT.txt"

python3 - "$cdir" "$caseroot/eval_metadata.json" "$case_" "$run/PROMPT.txt" <<'PY'
import json, pathlib, sys
cdir, out, name, prompt = sys.argv[1:5]
assertions = []
for g in sorted(pathlib.Path(cdir, "graders").glob("*.md")):
    parts = g.read_text().split("---", 2)
    assertions.append(parts[2].strip() if len(parts) == 3 else g.read_text().strip())
json.dump({"eval_name": name, "prompt": open(prompt).read().strip(), "assertions": assertions},
          open(out, "w"), indent=2)
PY

# Stop hook: copy the transcript after every reply (its path is in the hook input)
cat > "$run/save-transcript.sh" <<EOF
#!/usr/bin/env bash
python3 -c 'import json, shutil, sys; shutil.copyfile(json.load(sys.stdin)["transcript_path"], sys.argv[1])' "$run/transcript.jsonl"
EOF
chmod +x "$run/save-transcript.sh"
python3 - "$run" <<'PY'
import json, sys
run = sys.argv[1]
settings = {
    "permissions": {"allow": ["Bash", "Read", "Edit", "Write", "Glob", "Grep"]},
    "hooks": {"Stop": [{"hooks": [{"type": "command", "command": f"bash {run}/save-transcript.sh"}]}]},
}
json.dump(settings, open(f"{run}/outputs/.claude/settings.local.json", "w"), indent=2)
PY

cd "$run/outputs"
bash "$cdir/place-files.sh"
date +%s > "$run/started"

cat <<EOF

Prepared $case_ (iteration $it).

1. In VS Code: File > Open Folder... and open
     $run/outputs
   Accept the "Trust this folder" prompt if it appears.
2. Open Claude Code there and start a NEW session. Check that /plugins shows
   babs-rnaseq-skills from babs-trials enabled.
3. Paste this prompt exactly, and nothing else:
-----------------------------------------------------------------------------
$(cat "$run/PROMPT.txt")
-----------------------------------------------------------------------------
4. Don't help it. If it asks a question, answer only "Please carry on with
   what you have." (for unknown-covariate-stops-before-render, a question is
   the expected end: stop there). Keep the window open until it finishes.
5. Then run:
     bash $HERE/finish-trial.sh $case_ --iteration $it
EOF
