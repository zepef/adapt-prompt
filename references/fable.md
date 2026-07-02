# Fable / Mythos family deltas (Claude Fable 5, Claude Mythos 5, vs. Opus 4.8)

Source: Anthropic, "Prompting Claude Fable 5". Apply on top of `references/general.md`. This family diverges the most from prior models — read this file fully before adapting a prompt for it.

## Safety classifiers — check this first, every time

Fable 5 runs safety classifiers targeting offensive-cybersecurity content, biology/life-sciences content, and **extraction of its own summarized thinking** (`reasoning_extraction`). Benign work in the first two domains can still trigger false positives; the third is fully avoidable by never asking the model to reproduce, transcribe, or explain its internal reasoning as response text. **When adapting any prompt for this family: scan for and remove/rephrase "explain your reasoning" / "show your thinking" / "walk me through your thought process" style instructions.** A tripped refusal falls back to Opus 4.8 at cost — the opposite of what this skill is for. If reasoning visibility is genuinely needed, point at reading the structured `thinking` blocks via the API instead of asking the model to narrate them in response text.

## Effort — the primary lever, and unusually strong at every level

`effort` is the main intelligence/cost/latency control. `high` is the recommended default for most tasks — it often exceeds `xhigh` performance on prior models, so resist reflexively reaching for `xhigh`/`max`. Use `xhigh` only for the most capability-sensitive workloads, `medium`/`low` for routine work. If a task completes correctly but slower than needed, that's a signal to lower effort, not raise it.

At higher effort on routine work, Fable 5 can over-gather context or over-deliberate, and can tidy/refactor beyond what was asked. If the adapted prompt is a bug fix or narrow task, include explicit scope discipline: "Don't add features, refactor, or introduce abstractions beyond what the task requires. Don't add error handling or validation for scenarios that can't happen."

## Longer turns by default — plan around this, don't fight it

Individual requests can legitimately run minutes to hours, especially at higher effort on hard tasks. If the adapted prompt targets an unattended/pipeline context, this is normal and expected — don't add artificial pacing instructions. If the task is ambiguous and risks overplanning, add: "When you have enough information to act, act. Do not re-derive facts already established, re-litigate a decision already made, or narrate options you won't pursue in user-facing messages."

## Strong instruction following — brief beats exhaustive

Fable 5 follows short instructions reliably; there's no need to enumerate every behavior by name. A brief brevity instruction ("lead with the outcome; your first sentence should answer 'what happened'") outperforms a long list of "don't do X, don't do Y" rules. The same applies to defining when the model should pause for user input — state the *category* of situation (irreversible action, real scope change, input only the user can provide), not an exhaustive list of cases.

## Ground progress claims in long/unattended runs

If the adapted prompt describes a long autonomous run, add: "Before reporting progress, audit each claim against a tool result from this session. Only report work you can point to evidence for; if something is not yet verified, say so explicitly." This measurably reduces fabricated status reports.

## State explicit boundaries

Fable 5 can occasionally take unrequested side-actions (drafting an unrequested email, creating defensive git backups). If the adapted prompt is for an agent that should stay strictly reactive, state the boundary explicitly: e.g. "when the user is asking a question or thinking out loud rather than requesting a change, the deliverable is your assessment — report and stop, don't apply a fix until asked."

## Parallel subagents and delegation

Fable 5 dispatches subagents more readily than prior models and manages long-running peer/subagent communication well. If the adapted prompt is an orchestrator-style task, prefer asynchronous framing over blocking: "Delegate independent subtasks to subagents and keep working while they run; intervene only if a subagent goes off track."

## Memory for multi-session work

If the adapted prompt is for a task spanning multiple sessions, Fable 5 benefits from an explicit place to write lessons learned (a simple markdown file), with instructions to update existing notes rather than duplicate, and to delete notes that turn out wrong.

## Autonomous-pipeline reminders (only if genuinely unattended)

For prompts that will run with no human watching in real time, two reminders reduce known failure modes:
- Early stopping: "Before ending your turn, check your last paragraph. If it's a plan, a question, or a promise about work not yet done, do that work now instead of ending the turn. End only when the task is complete or you're blocked on input only the user can provide."
- Context-budget anxiety: only relevant if the harness surfaces a token countdown to the model — if so, add: "You have ample context remaining. Do not stop, summarize, or suggest a new session on account of context limits."

Don't add these two reminders to prompts for short, interactive, single-turn tasks — they're solving a long-run-specific failure mode and are unnecessary weight otherwise.
