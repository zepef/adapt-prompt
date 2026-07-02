# Sonnet family deltas (Claude Sonnet 5, vs. Sonnet 4.6)

Source: Anthropic, "Prompting Claude Sonnet 5". Apply on top of `references/general.md`.

## Response length

Auto-calibrated to task complexity — short for simple lookups, long for open-ended analysis. If the adapted prompt's context implies a fixed-verbosity product need, add an explicit conciseness instruction: "Provide concise, focused responses. Skip non-essential context, keep examples minimal." Prefer positive framing (show the right level of concision) over "don't over-explain."

## Effort and thinking depth

- Default effort is `high`. Use `xhigh` for the hardest coding/agentic tasks.
- Effort is respected strictly, especially at the low end — at `low`/`medium` the model scopes to exactly what was asked (good for cost/latency, but risks under-thinking on moderately complex tasks). If the task is complex, recommend raising effort rather than prompting around a low setting.
- Adaptive thinking is **ON by default** on Sonnet 5 (new — was off by default on 4.6). If thinking triggers more than wanted, add: "Thinking adds latency and should only be used when it will meaningfully improve answer quality — typically for problems that require multi-step reasoning. When in doubt, respond directly."
- `temperature`/`top_p`/`top_k` are rejected (400 error) if the adapted prompt is destined for a raw API call — note this if relevant; use system-prompt instructions for tone/variety instead.

## Tool use triggering

More agentic than 4.6 by default; reaches for tools and self-verification loops more readily. With thinking explicitly disabled, it's less likely to reach for tools — if the target use case relies on tool calls with thinking off, add an explicit nudge describing when/how to use the relevant tools.

## Literal instruction following

Sonnet 5 does **not** silently generalize an instruction from one item to another and does not infer unstated requests. If the adapted prompt needs a rule applied broadly, state the scope explicitly (e.g. "apply this formatting to every section, not just the first one") rather than relying on the model to infer it.

## Design / frontend defaults

Can settle into a consistent default visual style on open-ended briefs. To get variety: either specify a fully concrete visual spec (colors, type, layout, motion — the model follows explicit specs precisely), or ask it to propose 3-4 distinct visual directions before building and let the user pick. A short `<frontend_aesthetics>` directive against generic fonts (Inter/Roboto/Arial)/purple gradients/predictable layouts reinforces this.

## Interactive coding products — the core token-efficiency data point

Specify task, intent, and constraints fully in the **first turn**. Ambiguous or progressively-clarified prompts measurably reduce both token efficiency and sometimes performance compared to a well-specified single-turn ask. This is the strongest concrete justification for this skill's existence — cite it when the raw draft looks like it expects a back-and-forth.

## Code review / audit harnesses

If the prompt says "only report high-severity issues" / "be conservative" / "don't nitpick," Sonnet 5 follows this more literally than earlier models — it still investigates thoroughly but converts fewer findings into reported output, which can look like a recall drop. If the adapted prompt is a review/audit harness, consider: "Report every issue you find, including ones you're uncertain about or consider low-severity. Do not filter for importance or confidence at this stage — a separate verification step will do that." Push confidence/severity filtering to a later stage rather than the finding stage.
