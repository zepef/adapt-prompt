# adapt-prompt

**A Claude Code skill that rewrites a draft prompt for whichever Claude model is currently active in the session.**

> Prompt engineering advice for Claude changed shape with the Sonnet 5 / Opus 4.8 / Fable 5 / Mythos 5 generation: each family now has genuinely different defaults — thinking-on-by-default vs. off, effort floors, literal instruction-following, subagent-spawning behavior, even safety classifiers that can be tripped by innocuous-looking instructions. A prompt tuned for one model is not automatically well-tuned for another, and Anthropic ships the differences as prose documentation, not as an API you can query. This skill turns that documentation into something a prompt gets checked against automatically, every time.

## Why this exists

Anthropic's own guidance states it plainly for interactive coding/agentic products: an ambiguous or underspecified prompt, clarified progressively across multiple turns, is *less* token-efficient — and sometimes less capable — than a fully-specified prompt given upfront. That waste compounds with every wasted round trip: a clarifying question the model has to ask, adaptive thinking triggering on an ambiguous ask that a clearer prompt wouldn't have triggered, an effort level mismatched to the task.

That waste is not evenly priced across models. Claude Fable 5 / Mythos 5 costs roughly **2x** Claude Opus 4.8. A habit of writing loose, conversational prompts and letting the model figure out the rest is a rounding error on cheaper models and a real line item on the expensive ones.

`adapt-prompt` exists to make "write a well-specified prompt" a five-second action instead of a skill you have to remember to apply, and to keep that advice current as Anthropic's own per-model guidance evolves — without you having to re-read four documentation pages every time a new model ships.

## What it does

Given a raw draft prompt, the skill:

1. **Detects the model actually running the session** — not a fixed target, not a guess. It reads the self-report line Claude Code injects into every system prompt ("You are powered by the model named X. The exact model ID is Y.") and resolves it to a model family (`sonnet`, `opus`, `fable`, `haiku`).
2. **Reads the current effort level** (`CLAUDE_EFFORT`) actually in play for the session.
3. **Loads the matching prompting-technique reference** for that family, plus a set of techniques that apply to every current model, and diagnoses the draft prompt against both.
4. **Rewrites the prompt** — clarifying scope, adding missing success criteria, adding family-specific guardrails (e.g. never asking a Fable-family model to narrate its own reasoning, which can trip a safety classifier and trigger a costly fallback to Opus 4.8) — while preserving the original intent.
5. **Reports a token diagnostic**, before vs. after, honestly framed: the adapted prompt is usually *longer*, not shorter, because it's more complete. The real savings are downstream (fewer clarifying turns, less unwanted deliberation), which the default mode describes qualitatively; an explicit `--benchmark` flag can run both versions for real and report actual input/output tokens and latency.
6. **Recommends an effort level**, compared against what's actually configured for the session, purely as advice — it never modifies session settings.
7. **Stops short of rewriting** when the draft is already well-optimized or too trivial to bother with, rather than manufacturing busywork.

By default, the adapted prompt is presented as an artifact to reuse elsewhere — as a subagent system prompt, an API call, another skill's instructions, a Task/Workflow prompt — not auto-executed. Saying "run it" or adding `--run` opts into running it immediately in the current conversation instead.

## Usage

```
/adapt-prompt <raw prompt text> [--benchmark] [--run]
```

- `--run` — after presenting the adapted prompt, treat it as the next instruction and execute it in the current conversation.
- `--benchmark` — run both the original and adapted prompt as real generations (requires `ANTHROPIC_API_KEY`), and report actual input/output tokens and latency instead of an estimate. Costs roughly 2x a normal call — meant for occasionally validating the thesis on a real case, not routine use.

## Structure

```
adapt-prompt/
├── SKILL.md              # the procedure Claude follows when the skill is invoked
├── references/
│   ├── general.md         # techniques that apply across all current Claude models
│   ├── sonnet.md           # Sonnet-family deltas
│   ├── opus.md             # Opus-family deltas
│   └── fable.md             # Fable/Mythos-family deltas (no haiku.md — no dedicated
│                             # upstream guidance exists yet; the skill falls back to
│                             # general.md and says so explicitly)
└── scripts/
    ├── count_tokens.sh    # best-effort exact input-token count via the Anthropic API
    └── benchmark.sh        # --benchmark mode: real before/after generation comparison
```

Everything that requires judgment (resolving the model family, diagnosing what a prompt is missing, rewriting it, estimating tokens, recommending an effort level) is plain instructions in `SKILL.md`, followed by whichever model is running the skill. The only things implemented as scripts are the two genuinely deterministic operations — safely JSON-encoding arbitrary prompt text for an HTTP call and measuring latency — since that's exactly the kind of fiddly, error-prone work (shell-escaping quotes, backticks, `$` in user text) that's more reliable as code than as a hand-built `curl` command.

## Design notes

- **No hardcoded model registry.** Model IDs and family mappings age fast; this skill deliberately reads the model identity live from the running session instead of maintaining its own table, and defers to Anthropic's own model-facts source (Claude Code's built-in `claude-api` skill, if present) for anything beyond the family match.
- **Graceful without an API key.** `ANTHROPIC_API_KEY` isn't required for normal use — token counts fall back to the model's own estimate, clearly labeled as such, and `--benchmark` mode explains what's missing rather than failing outright.
- **Reference material is distilled, not copied.** `references/*.md` condense Anthropic's published prompting guidance into actionable checklist items; they're not a verbatim mirror and should be refreshed by hand as that guidance evolves.

## Installing

This is a [Claude Code](https://claude.com/claude-code) skill. Clone this repo and symlink it into your global skills directory:

```bash
git clone https://github.com/zepef/adapt-prompt.git
ln -s "$(pwd)/adapt-prompt" ~/.claude/skills/adapt-prompt
```

## License

MIT — see [LICENSE](LICENSE).
