# General prompting techniques (all current Claude models)

Source: Anthropic, "Prompting best practices" (platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices). Condensed for use by the `adapt-prompt` skill — apply these before layering on family-specific deltas from `references/<family>.md`.

## Clarity and directness

- **Golden rule:** show the prompt to a colleague with zero context on the task and ask them to follow it. If they'd be confused, the model will be too.
- Be specific about desired output format and constraints. Don't rely on the model to infer "above and beyond" behavior from a vague ask — say it explicitly if wanted.
- Use numbered lists or bullet points for sequential steps when order or completeness matters.

## Add context, not just instructions

Explaining *why* an instruction matters (not just what it is) helps the model generalize correctly. "Never use ellipses" is weaker than "your response will be read by a TTS engine that can't pronounce ellipses, so never use them."

## Examples (few-shot / multishot)

- 3-5 examples is the sweet spot.
- Make them relevant (mirror the real use case), diverse (cover edge cases, vary enough to avoid an unintended pattern), and structured (wrapped in `<example>` tags, multiple in `<examples>`).

## XML structuring

- Use XML tags to separate instructions, context, examples, and variable input when a prompt mixes several of these — reduces misinterpretation.
- Use consistent, descriptive tag names. Nest tags when content has a natural hierarchy (e.g. `<documents><document index="n">`).
- Don't over-apply this to short, simple prompts — scale structure to complexity.

## Role assignment

A one-sentence role in the system prompt measurably shifts tone and focus (e.g. "You are a helpful coding assistant specializing in Python").

## Long-context prompting (20k+ tokens / multi-document inputs)

- Put long documents/inputs near the **top** of the prompt; put the query/instructions at the **end**. This alone can improve response quality up to ~30% on complex multi-document inputs.
- Wrap each document in `<document index="n"><source>...</source><document_content>...</document_content></document>`.
- For long-document tasks, ask the model to quote relevant passages first (in `<quotes>` tags) before answering — this anchors it and cuts through noise.

## Model self-knowledge

If the app needs the model to self-report its identity or an exact API model string, state it explicitly in the prompt — the model does not reliably know this on its own without being told.

## Output and formatting control

1. **Say what TO do, not what NOT to do.** "Write in flowing prose paragraphs" beats "don't use markdown."
2. **Use XML format indicators** for structural requirements (e.g. "write prose sections in `<prose>` tags").
3. **Match prompt style to desired output style.** A markdown-heavy prompt nudges toward a markdown-heavy answer; strip markdown from the prompt to reduce markdown in the output.
4. For strong formatting control (e.g. minimizing markdown/bullet-point sprawl in long-form writing), use an explicit, detailed instruction block rather than a single line.
5. LaTeX is the default for math/technical notation on current models — state plain-text preference explicitly if that's wanted instead.

## Prefill is deprecated (Claude 4.6+ / Mythos models)

Prefilling the last assistant turn returns a 400 error on Claude 4.6+ and Mythos models (older models still accept it). Migration paths by old use case:
- **Forcing output format (JSON/YAML/classification):** use Structured Outputs, or a tool with an enum field for classification, instead of a prefill.
- **Eliminating preambles:** direct instruction in the system prompt ("respond directly, no preamble, don't start with 'Here is...'"). Strip in post-processing if needed as a backstop.
- **Avoiding bad refusals:** generally unnecessary now — current models refuse more appropriately by default.
- **Continuations of interrupted output:** move to the user turn instead ("your previous response was interrupted and ended with `[text]`. Continue from where you left off.").
- **Periodic context refresh:** inject into the user turn, via tools, or during context compaction — not via assistant prefill.

## Explicit tool-triggering language

Models will often only *suggest* changes ("can you suggest some changes...") rather than *make* them, unless told to act ("change this function", "make these edits"). If the prompt needs the model to actually take action rather than just discuss it, say so directly.

## Parallel tool calls

Current models run independent tool calls in parallel with a high success rate by default; this is steerable up (near-100%, via an explicit "parallelize independent calls, never guess missing parameters" instruction) or down (explicit "run sequentially" instruction) if the default behavior doesn't match the need.

## Thinking / reasoning

- Prefer general instructions ("think carefully before responding") over a hand-written step-by-step plan — model reasoning frequently exceeds what a human would prescribe.
- Multishot examples with `<thinking>` tags inside them teach the model a reasoning style it will generalize.
- A self-check instruction ("before you finish, verify your answer against [criteria]") reliably catches errors, especially in coding and math.
- If thinking triggers more than wanted (common with large/complex system prompts), add an explicit "thinking adds latency; use it only when it will meaningfully improve answer quality; when in doubt, respond directly" instruction.
- If thinking under-triggers on a task that needs it, raise `effort` first rather than prompting around it.

## Agentic systems

- **State tracking across long/multi-window tasks:** use structured formats (JSON) for status/test data, free text for progress notes, and git as the ground-truth log/checkpoint mechanism. Explicitly ask for incremental progress over "do everything at once."
- **Balancing autonomy and safety:** without guidance, agentic models may take hard-to-reverse actions (deleting files, force-pushing, posting externally). If the prompt describes an agentic/pipeline task, consider adding explicit reversibility framing: local/reversible actions (edit files, run tests) proceed freely; destructive or externally-visible actions (rm -rf, force-push, sending messages, modifying shared infra) require confirmation first.
- **Research tasks:** define clear success criteria, ask for source verification across multiple sources, and for complex research, ask the model to track competing hypotheses and confidence levels in a persisted notes file rather than holding it all in-context.
- **Subagent orchestration:** current models delegate to subagents proactively once subagent tools are well-described — no need to over-instruct this. If overused (spawning subagents for work a direct tool call would handle faster), add explicit scoping: "use subagents for parallelizable or context-isolated work; work directly for simple/sequential/single-file tasks."
- **Prompt chaining:** less necessary now that adaptive thinking + subagent orchestration handle most multi-step reasoning internally, but still useful when intermediate outputs need inspection or a pipeline structure must be enforced (e.g. draft → review against criteria → refine, as separate calls).
- **Minimizing unwanted file creation:** models may use scratch files (esp. Python scripts) during iteration; if that's undesirable, add an explicit "clean up any temporary files at the end" instruction.
- **Anti-overengineering:** if the task is a bug fix or small change, an explicit scope-limiting instruction helps — don't add unrequested refactors, don't add defensive code for scenarios that can't happen, don't build abstractions for one-time operations.
- **Anti-hardcoding / anti-test-gaming (coding tasks):** ask explicitly for a general-purpose solution that works for all valid inputs, not one tuned to pass specific visible tests; ask the model to flag if the task or a test itself looks wrong rather than silently working around it.
- **Anti-hallucination (codebase tasks):** ask the model to read/investigate referenced files before making claims about them, rather than speculating.

## Vision

For image-heavy tasks (data extraction, UI screenshots, dense technical images), a crop/zoom tool measurably improves accuracy — worth mentioning if the adapted prompt is for an agent that will process images.

## Frontend / design work

Left unguided, models converge on generic "AI slop" patterns (overused fonts like Inter/Roboto/Arial, purple gradients, predictable layouts). If the adapted prompt is a design/frontend brief, either (a) specify a concrete, opinionated visual direction, or (b) ask the model to propose 2-4 distinct visual directions before building and let the user pick one — both break the default-convergence problem more reliably than a vague "make it not generic" instruction.
