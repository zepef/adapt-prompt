---
name: adapt-prompt
description: "Rewrite a raw draft prompt into a token-efficient, best-practices-compliant prompt tailored to whichever Claude model is CURRENTLY ACTIVE in this session — for reuse as a subagent system prompt, an API call, another skill's instructions, or a Task/Workflow prompt. Use whenever the user asks to adapt, tighten, optimize, or prompt-engineer a piece of prompt text; wants a system prompt for a subagent/skill/API call reviewed before reuse; asks 'is this prompt good', 'reduce token usage of this', 'optimize this for Sonnet/Opus/Fable'; or types /adapt-prompt. Also trigger on French equivalents: 'améliore ce prompt', 'optimise ce prompt', 'adapte ce prompt pour...', 'rends ce prompt plus efficace'."
argument-hint: "<raw prompt text> [--benchmark] [--run]"
allowed-tools: Read, Bash(bash /home/zepef/.claude/skills/adapt-prompt/scripts/count_tokens.sh:*), Bash(bash /home/zepef/.claude/skills/adapt-prompt/scripts/benchmark.sh:*), Bash(printenv ANTHROPIC_API_KEY), Bash(printenv CLAUDE_EFFORT), Bash(cat > /tmp/adapt-prompt-*)
---

# Adapt Prompt

This is a cost/token-efficiency tool first, a style tool second. An underspecified prompt costs more than a well-specified one — not because the well-specified one is shorter (it's usually longer), but because underspecification burns tokens on multi-turn clarification, on adaptive thinking triggering unnecessarily on ambiguous asks, and on mismatched effort defaults. Claude Fable 5 / Mythos 5 costs roughly 2x Claude Opus 4.8, so this waste compounds fastest there. Your job is to turn a rough draft into a prompt that gets it right the first time, for whichever model is actually running right now.

## 0. Parse the invocation

Take `$ARGUMENTS` verbatim. Strip recognized trailing control tokens from the end of the string, in either order, repeating until none remain:
- if the string ends with `--run` (surrounding whitespace trimmed), remove it and set `run_now = true`
- if the string (now) ends with `--benchmark`, remove it and set `benchmark_mode = true`

Whatever remains, trimmed, is `RAW_PROMPT`. If `RAW_PROMPT` is empty, say so and stop — don't guess what to adapt.

## 1. Determine the active model and current effort level

Read your OWN system prompt's `# Environment` block for the line of the form: "You are powered by the model named `<Display Name>`. The exact model ID is `<exact-id>`." This is the only trustworthy signal for the model.

Do **not**:
- read `settings.json`'s `model` field (it's a short alias like `"sonnet"`, can be stale, and ignores `/model` switches, Fast Mode, and per-skill model overrides)
- shell out to check an environment variable for the model (none reliably reflects the live model)
- infer the model from its own behavior

Resolve `<family>` via substring match on the display name/ID:
- contains "sonnet" → `sonnet`
- contains "opus" → `opus`
- contains "fable" or "mythos" → `fable`
- contains "haiku" → `haiku`
- none of the above → `unknown`

If you want to double-check currency or deprecation status, you may optionally invoke `Skill(claude-api)` or read its bundled model reference — this is enrichment only, never required for the core family match. Never hardcode model IDs into this skill; they go stale.

Then run `printenv CLAUDE_EFFORT` to read the effort level actually in play for this session — this env var, unlike the model identifier, is reliably exposed to the Bash tool:
- If it returns a value (`low`/`medium`/`high`/`xhigh`/`max`), record it as `CURRENT_EFFORT`.
- If unset or empty, record `CURRENT_EFFORT = unknown` — no explicit override is active, so the platform/model default applies; don't guess a specific level.

`CURRENT_EFFORT` feeds two later steps: the gap diagnosis in §4 (a low/medium effort on a complex task becomes a checkable risk, not a hypothetical one) and the effort recommendation in §8 (which becomes an actual comparison, not a suggestion made in a vacuum).

## 2. Load reference material

Always read `references/general.md`.

Attempt to read `references/<family>.md`. If it doesn't exist (currently true for `haiku`, and for any future/unrecognized family), note this plainly — it will surface in the final output header (see §9) — and proceed on `general.md` alone. Do not pretend a family-specific file was consulted when it wasn't.

## 3. Understand what the prompt is for

Infer the reuse target from content and phrasing: a subagent system prompt, an API call, another skill's instructions, a Task/Workflow prompt, or unstated/ambiguous. If ambiguous, make the most reasonable inference and state it in the rationale rather than spending a clarifying turn on it — asking here would itself be the token-inefficiency this skill exists to prevent.

## 4. Diagnose gaps

Walk `RAW_PROMPT` against the general techniques in `references/general.md` and every applicable bullet in the loaded `references/<family>.md`. In particular check:
- the golden rule: would a colleague with zero context on the task execute this correctly?
- context/motivation behind instructions
- few-shot example opportunity
- structuring need (XML tags — only if complexity actually warrants it)
- role assignment
- long-context document placement, if documents are involved
- output-format specification
- prefill patterns (flag as deprecated if family ∈ {sonnet, opus, fable} — prefill on the last assistant turn returns a 400 error on these)
- explicit tool-triggering language, if the prompt is agentic
- thinking-steering needs
- autonomy/reversibility framing, if the prompt describes an unattended or pipeline-shaped task
- anti-overengineering / anti-hardcoding / anti-hallucination guardrails, if the prompt is a coding/agentic task
- **effort/thinking mismatch:** if `CURRENT_EFFORT` (from §1) is `low` or `medium` and the task reads as complex or multi-step per the loaded family file's complexity signals, this is a real, checkable risk, not a hypothetical one. Consider adding an explicit thinking-steering instruction to the rewritten prompt to compensate (e.g. "This task involves multi-step reasoning. Think carefully through the problem before responding.") — both `sonnet.md` and `opus.md` document under-thinking risk at low/medium effort.

**Family = `fable`, non-negotiable check:** scan for and remove or rephrase any instruction resembling "explain your reasoning" / "show your thinking" / "reproduce your internal reasoning as response text". These risk tripping the `reasoning_extraction` safety classifier and triggering a refusal-driven fallback to Opus 4.8 — at cost, which directly undermines the point of this skill. Replace with outcome-oriented phrasing instead (e.g. "summarize your conclusions and the key evidence").

## 5. Two exits before rewriting

**Already well-optimized:** if `RAW_PROMPT` already satisfies the great majority of applicable techniques, say so explicitly and stop short of a full rewrite. At most surface 1-2 genuinely high-value tweaks if truly present. Never manufacture cosmetic diffs to look like work was done. Use the short output format in §9.

**Too trivial to bother:** if `RAW_PROMPT` is short, unambiguous, and has no real reuse-adaptation surface (e.g. "list the files in this repo"), say adaptation isn't worth the overhead and stop. Don't pad it. Use the short output format in §9.

If neither exit applies, continue to §6.

## 6. Rewrite

Apply the golden rule plus the relevant general techniques and family deltas identified in §4.

- Preserve the user's original intent and content faithfully — clarify and structure, never invent new requirements.
- Scale structure to complexity: don't wrap a 2-line prompt in heavy XML scaffolding.
- Never trim content just to make the "after" token count look smaller than "before." An adapted prompt is often *longer* — more context, explicit success criteria, examples — and that's fine.
- If family ∈ {sonnet, opus} and the prompt is a code-review/audit harness, consider explicitly adding the "report every issue, don't self-filter at the finding stage" note from the family file — both models now follow conservative-sounding instructions ("only report high-severity issues") more literally than before, which silently lowers measured recall.

## 7. Token diagnostics

Always produce your own estimate for both `RAW_PROMPT` and the adapted prompt (rule of thumb: ~4 characters per token for English prose, denser for code; cross-check against word count). Label this clearly: "estimated — Claude's own tokenizer-aware estimate, not exact."

**If `benchmark_mode`:**
1. Check for `ANTHROPIC_API_KEY` via `printenv ANTHROPIC_API_KEY`.
2. If present: write `RAW_PROMPT` and the adapted prompt each to a temp file using a **quoted heredoc** — `cat > /tmp/adapt-prompt-orig.$$.txt <<'PROMPT_EOF'` ... `PROMPT_EOF` — the quoted delimiter is mandatory so arbitrary quotes, backticks, or `$` in the prompt text survive untouched. Never interpolate prompt text directly into a command line.
3. Run `bash /home/zepef/.claude/skills/adapt-prompt/scripts/benchmark.sh <live-model-id> <orig-file> <adapted-file>`.
4. This supersedes the plain estimate. Label the method as "benchmark (real generations, ~2x cost)".
5. If the key is absent: say benchmark mode needs `ANTHROPIC_API_KEY`, skip it, and fall back to the estimate. Never fail the whole skill over this.

**Else (normal mode):**
1. Check for `ANTHROPIC_API_KEY`.
2. If present, best-effort call `bash /home/zepef/.claude/skills/adapt-prompt/scripts/count_tokens.sh <live-model-id> <file>` for both variants (same quoted-heredoc temp-file pattern as above). On any failure (network, auth, rate-limit), silently fall back to the estimate and note the fallback.
3. Label method as "count_tokens API (exact input tokens)" on success, "estimated" otherwise.

Always include, in words, the qualitative savings this skill cannot literally measure outside `--benchmark` mode: fewer clarifying turns, less unwanted adaptive-thinking overhead on ambiguous asks, correctly calibrated effort. The single strongest concrete data point behind this thesis: for interactive coding/agentic products, specifying task, intent, and constraints fully in the first turn measurably improves both token efficiency and performance on Sonnet 5 and Opus 4.8 — cite this explicitly whenever the raw draft reads like it was designed to be filled in progressively across turns (missing success criteria, missing explicit scope, "I'll clarify as we go"-shaped language).

## 8. Effort recommendation vs. current setting

Infer task complexity (trivial lookup → low/medium; well-specified single-file task → medium/high; complex/ambiguous/multi-file/agentic → high/xhigh; long-horizon unattended pipeline → the family file's recommended floor). Cross-check against the loaded family file's effort-calibration notes to produce `RECOMMENDED_EFFORT`.

Compare against `CURRENT_EFFORT` from §1:
- If they match, say so plainly — no change needed.
- If `CURRENT_EFFORT` is `unknown`, give `RECOMMENDED_EFFORT` alone, noting no explicit override is currently active.
- If they differ, state both explicitly and say which direction and why — e.g. "currently `xhigh`, `medium` would likely suffice for this well-scoped single-file task — lower for latency/cost" or "currently `low`, this task's ambiguity risks under-thinking at that level — raise to `high`".

This is advisory only. Never modify `CLAUDE_EFFORT`, settings, or any session config. You may mention where the user could apply a change (the `CLAUDE_EFFORT` env var, the `/model`/effort UI, or a per-call `effort` API parameter), but take no action.

## 9. Present output

Default: present only, never auto-execute. Use this exact shape for a full adaptation:

```
**Adapted prompt** — tailored for *<Display Name>* (<family> family)
[if no dedicated reference existed: "No dedicated prompting reference yet for <family/model> — applied general best practices only."]

```
<adapted prompt text, fenced>
```

**Changes**
- <technique> → <one-line concrete change>
[3-6 bullets max]

**Tokens** (method: estimate | count_tokens API | benchmark)
Original ~N → Adapted ~M (Δ ±X%)
[one-line honesty note if adapted grew]
[one-line qualitative savings note]
[if benchmark: output_tokens + latency rows for both variants]

**Effort:** current `<CURRENT_EFFORT or "not set">` → recommended `<level>` — <one-line why> (advisory; not applied)

Reuse as-is elsewhere. Say "run it" or add `--run` to execute this now. Add `--benchmark` for a real before/after (costs ~2x, rarely needed).
```

For the "already well-optimized" exit:

```
**Already well-adapted for *<Display Name>*.** No rewrite needed — <1-2 line why, referencing the specific techniques it already satisfies>.

**Tokens:** ~N (estimate)
**Effort:** current `<CURRENT_EFFORT or "not set">` → recommended `<level>` — <why>
```

For the "too trivial" exit:

```
This prompt is short and unambiguous enough that adaptation wouldn't meaningfully help — send it as-is.
[optional] **Effort:** current `<CURRENT_EFFORT or "not set">` → recommended `<level>`
```

Keep it tight and scannable. Don't restate the entire original prompt back. No long preambles.

## 10. Optional immediate-run path (secondary, opt-in only)

If `run_now` was set in §0 (the `--run` suffix), or the user's *next* message says something like "run it" / "go ahead, run that" referring to the block you just produced, then and only then treat the adapted prompt as the next instruction to execute in the current conversation.

Never do this by default. The primary use case is authoring a prompt for reuse elsewhere (subagent, API call, another skill, a Task/Workflow prompt); auto-executing by default would usually mismatch intent, waste an unwanted generation, and blur "draft" vs "final."

## Example

<example>
Draft: "Make the error handling in this file better."

Adapted (for a Sonnet-family model, coding-fix intent inferred): "Improve the error handling in `payments/charge.py`. Specifically: replace the bare `except:` blocks with specific exception types, add a one-line log message on each caught error including the transaction id, and let unexpected exceptions propagate rather than being silently swallowed. Don't add retry logic or new abstractions — this is a targeted fix, not a redesign."

Rationale: the draft doesn't name a file, doesn't define what "better" means (the model would have to guess or ask), and doesn't scope out likely-unwanted scope creep (retries, abstractions) that Sonnet/Opus-family models tend toward by default at higher effort. The adapted version is longer but removes the need for a clarifying turn.
</example>
