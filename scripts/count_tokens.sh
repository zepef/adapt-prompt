#!/usr/bin/env bash
# Best-effort exact input-token count via the Anthropic count_tokens API.
# Usage: count_tokens.sh <model_id> <prompt_file>
# On success: prints the input_tokens integer to stdout, exit 0.
# No API key:  prints NO_API_KEY to stderr, exit 2 (caller should fall back silently).
# Other failure: prints an error to stderr, exit 1 or 3.
set -euo pipefail

if [ $# -ne 2 ]; then
  echo "Usage: $0 <model_id> <prompt_file>" >&2
  exit 1
fi

MODEL_ID="$1"
PROMPT_FILE="$2"

if [ ! -f "$PROMPT_FILE" ]; then
  echo "File not found: $PROMPT_FILE" >&2
  exit 1
fi

if [ -z "${ANTHROPIC_API_KEY:-}" ]; then
  echo "NO_API_KEY" >&2
  exit 2
fi

RESPONSE=$(python3 -c '
import json, sys
model = sys.argv[1]
with open(sys.argv[2], "r") as f:
    text = f.read()
sys.stdout.write(json.dumps({"model": model, "messages": [{"role": "user", "content": text}]}))
' "$MODEL_ID" "$PROMPT_FILE" | curl -sS --max-time 15 -X POST https://api.anthropic.com/v1/messages/count_tokens \
  -H "x-api-key: $ANTHROPIC_API_KEY" \
  -H "anthropic-version: 2023-06-01" \
  -H "content-type: application/json" \
  -d @-) || { echo "curl request failed" >&2; exit 3; }

printf '%s' "$RESPONSE" | python3 -c '
import json, sys
raw = sys.stdin.read()
try:
    data = json.loads(raw)
except Exception:
    print(f"Could not parse API response: {raw}", file=sys.stderr)
    sys.exit(1)
if "input_tokens" in data:
    print(data["input_tokens"])
else:
    print(f"API error: {raw}", file=sys.stderr)
    sys.exit(1)
'
