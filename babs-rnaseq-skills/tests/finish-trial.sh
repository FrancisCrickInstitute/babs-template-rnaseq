#!/usr/bin/env bash
# Phase 8, step 2 of 2: after the agent session for a case prepared by
# prepare-trial.sh has finished, collect its transcript, final message and
# timing, and run check-trial.sh. See tests/RUNBOOK.md, "Phase 8".
#
# Usage: finish-trial.sh CASE [--iteration N] [--transcript FILE]
#
# The transcript normally comes from the Stop hook prepare-trial.sh set up
# (with_skill/transcript.jsonl). If the hook did not run, the newest session
# file for the trial folder under ~/.claude/projects/ is used instead, or the
# file given with --transcript. The transcript format is internal to Claude
# Code, so final.md and timing.json are best effort: if final.md says it
# found nothing, paste the agent's last reply into it by hand.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
die() { echo "finish-trial.sh: $*" >&2; exit 1; }

case_="" it=1 tfile=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --iteration) it="$2"; shift 2 ;;
    --transcript) tfile="$2"; shift 2 ;;
    -h|--help) sed -n '2,14p' "$0"; exit 0 ;;
    -*) die "unknown option $1" ;;
    *) case_="$1"; shift ;;
  esac
done
[[ -n "$case_" ]] || die "usage: finish-trial.sh CASE [--iteration N] [--transcript FILE]"
T="${BABS_TRIAL_ROOT:-/flask/scratch/babs/$USER/skills-test}"
export BABS_TRIAL_ROOT="$T"
run="$T/trials/iteration-$it/$case_/with_skill"
[[ -d "$run/outputs" ]] || die "$run not found: run prepare-trial.sh first"

# ---- transcript
if [[ -n "$tfile" ]]; then
  cp "$tfile" "$run/transcript.jsonl"
elif [[ ! -s "$run/transcript.jsonl" ]]; then
  # Claude Code keeps sessions in ~/.claude/projects/<cwd with every
  # non-alphanumeric character replaced by '-'>/<session>.jsonl
  enc="$(printf '%s' "$run/outputs" | sed 's/[^A-Za-z0-9]/-/g')"
  pdir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects/$enc"
  [[ -d "$pdir" ]] || pdir="$(ls -d "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects/${enc:0:200}"* 2>/dev/null | head -n1)"
  newest="$( [[ -n "$pdir" && -d "$pdir" ]] && ls -t "$pdir"/*.jsonl 2>/dev/null | head -n1 || true)"
  [[ -n "$newest" ]] || die "no transcript: the Stop hook did not run and nothing was found under ~/.claude/projects for $run/outputs; pass --transcript FILE"
  echo "Stop hook transcript missing; using $newest"
  cp "$newest" "$run/transcript.jsonl"
fi

# ---- final message and timing (best effort: the format is internal)
python3 - "$run" <<'PY'
import json, os, sys, datetime
run = sys.argv[1]
started = None
try:
    started = int(open(f"{run}/started").read().strip())
except Exception:
    pass

def text_of(content):
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        return "\n".join(c.get("text", "") for c in content if isinstance(c, dict) and c.get("type") == "text")
    return ""

last_text, times, model = "", [], None
tokens = {"input_tokens": 0, "output_tokens": 0, "cache_creation_input_tokens": 0, "cache_read_input_tokens": 0}
seen_ids, turns = set(), 0
for line in open(f"{run}/transcript.jsonl"):
    try:
        m = json.loads(line)
    except ValueError:
        continue
    ts = m.get("timestamp")
    if isinstance(ts, str):
        try:
            times.append(datetime.datetime.fromisoformat(ts.replace("Z", "+00:00")).timestamp())
        except ValueError:
            pass
    msg = m.get("message") if isinstance(m.get("message"), dict) else m
    if m.get("type") == "assistant" or msg.get("role") == "assistant":
        model = msg.get("model") or model
        t = text_of(msg.get("content"))
        if t.strip():
            last_text = t
        mid = msg.get("id")
        u = msg.get("usage") or {}
        if u and mid not in seen_ids:      # one API response can span several lines
            seen_ids.add(mid)
            turns += 1
            for k in tokens:
                tokens[k] += u.get(k, 0) or 0

open(f"{run}/final.md", "w").write((last_text.strip() or
    "(no assistant text found in transcript.jsonl: paste the agent's last reply here)") + "\n")
first = min(times) if times else started
last = max(times) if times else os.path.getmtime(f"{run}/transcript.jsonl")
dur = round(last - first, 1) if first else None
json.dump({"total_tokens": sum(tokens.values()), "tokens": tokens, "api_calls": turns, "model": model,
           "duration_ms": int(dur * 1000) if dur is not None else None, "total_duration_seconds": dur},
          open(f"{run}/timing.json", "w"), indent=2)
print(f"final.md: {len(last_text)} characters; timing: {dur}s, {sum(tokens.values())} tokens, model {model}")
PY

echo "Checking ..."
bash "$HERE/check-trial.sh" --case "$case_" --run "$run" 2>&1 | tee "$run/check.txt" || true
echo
echo "Send back: $run/{final.md,check.txt,timing.json,transcript.jsonl} (and compare.txt / results-match.txt if present)"
