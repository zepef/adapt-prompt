#!/usr/bin/env bash
# Explicit opt-in real before/after comparison: runs one real generation per
# prompt variant and reports actual input/output tokens and latency.
# Usage: benchmark.sh <model_id> <original_file> <adapted_file> [max_tokens]
# Costs a real generation for each file (~2x a single call) - only invoke
# when the SKILL.md instructions say --benchmark mode was explicitly requested.
set -euo pipefail

if [ $# -lt 3 ] || [ $# -gt 4 ]; then
  echo "Usage: $0 <model_id> <original_file> <adapted_file> [max_tokens=512]" >&2
  exit 1
fi

MODEL_ID="$1"
ORIG_FILE="$2"
ADAPTED_FILE="$3"
MAX_TOKENS="${4:-512}"

for f in "$ORIG_FILE" "$ADAPTED_FILE"; do
  if [ ! -f "$f" ]; then
    echo "File not found: $f" >&2
    exit 1
  fi
done

if [ -z "${ANTHROPIC_API_KEY:-}" ]; then
  echo "NO_API_KEY" >&2
  exit 2
fi

run_one() {
  local label="$1"
  local file="$2"

  local start end elapsed response
  start=$(date +%s.%N)

  response=$(python3 -c '
import json, sys
model = sys.argv[1]
max_tokens = int(sys.argv[2])
with open(sys.argv[3], "r") as f:
    text = f.read()
sys.stdout.write(json.dumps({"model": model, "max_tokens": max_tokens, "messages": [{"role": "user", "content": text}]}))
' "$MODEL_ID" "$MAX_TOKENS" "$file" | curl -sS --max-time 120 -X POST https://api.anthropic.com/v1/messages \
    -H "x-api-key: $ANTHROPIC_API_KEY" \
    -H "anthropic-version: 2023-06-01" \
    -H "content-type: application/json" \
    -d @-) || { echo "curl request failed for $label" >&2; return 3; }

  end=$(date +%s.%N)
  elapsed=$(python3 -c "print(f'{$end - $start:.2f}')")

  printf '%s' "$response" | python3 -c '
import json, sys
label = sys.argv[1]
elapsed = sys.argv[2]
raw = sys.stdin.read()
try:
    data = json.loads(raw)
except Exception:
    print(f"{label}\tPARSE_ERROR\tPARSE_ERROR\t{elapsed}")
    sys.exit(0)
usage = data.get("usage", {})
inp = usage.get("input_tokens", "?")
out = usage.get("output_tokens", "?")
if "usage" not in data:
    print(f"API error for {label}: {raw}", file=sys.stderr)
print(f"{label}\t{inp}\t{out}\t{elapsed}")
' "$label" "$elapsed"
}

echo -e "prompt\tinput_tokens\toutput_tokens\tlatency_s"
run_one "original" "$ORIG_FILE"
run_one "adapted" "$ADAPTED_FILE"
