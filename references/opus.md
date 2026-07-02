# Opus family deltas (Claude Opus 4.8, vs. Opus 4.7)

Source: Anthropic, "Prompting Claude Opus 4.8". Apply on top of `references/general.md`.

## Response length

Same auto-calibration behavior as Sonnet — see `references/general.md` / `sonnet.md` conciseness instruction if a fixed verbosity is needed.

## Effort and thinking depth

- Start at `xhigh` for coding/agentic use cases; use a minimum of `high` for other intelligence-sensitive use cases. Opus 4.8 has a **higher effort floor** than Sonnet 5 for equivalent tasks.
- Effort is respected strictly at the low end, same risk of under-thinking on complex tasks at `low`/`medium` — recommend raising effort rather than prompting around it.
- Thinking is **OFF by default** unless `thinking: {type: "adaptive"}` is explicitly set (opposite of Sonnet 5's new default). If the adapted prompt targets a raw API call and needs reasoning, this must be set explicitly.
- `max` effort can show diminishing returns and is prone to overthinking on some tasks — worth testing rather than assuming it's always best.

## Tool use triggering

Opus 4.8 favors reasoning over tool calls by default (usually produces better results). If more tool use is wanted, raising effort is the main lever (`high`/`xhigh` show substantially more tool usage in agentic search/coding); otherwise add an explicit instruction describing when/how to use the relevant tools.

## Literal instruction following

Same as Sonnet 5 — does not silently generalize instructions across items, does not infer unstated requests. State scope explicitly when a rule should apply broadly.

## Subagent spawning

Opus 4.8 spawns **fewer** subagents by default than one might expect. If more parallelism is wanted, add explicit guidance, e.g.: "Do not spawn a subagent for work you can complete directly in a single response. Spawn multiple subagents in the same turn when fanning out across items or reading multiple files."

## Design / frontend defaults

Opus 4.8 has a strong, persistent default house style: warm cream/off-white backgrounds (~#F4F1EA), serif display type (Georgia, Fraunces, Playfair), italic accents, terracotta/amber accent color. Reads well for editorial/hospitality/portfolio briefs, wrong for dashboards/fintech/healthcare/enterprise. Generic "don't use cream, make it clean" instructions just shift to a different fixed palette rather than producing real variety. Two reliable fixes: specify a fully concrete visual spec, or ask the model to propose 3-4 distinct visual directions before building. Opus 4.8 needs comparatively less anti-"AI slop" boilerplate than prior models to already avoid generic patterns.

## Interactive coding products — the core token-efficiency data point

Same as Sonnet 5: specify task, intent, and constraints fully in the first turn to maximize autonomy and token efficiency. Opus 4.8 tends to use *more* tokens in interactive (multi-turn) settings specifically because it reasons more after each user turn — so minimizing the number of required back-and-forth turns matters even more here than on Sonnet 5.

## Code review / audit harnesses

Same literal-instruction-following effect as Sonnet 5: "only report high-severity" / "be conservative" language can silently suppress reported findings even though investigation depth is unchanged. Use the same fix: ask for full coverage at the finding stage, push filtering to a separate step.
