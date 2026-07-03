# Fable / Mythos family deltas (Claude Fable 5, Claude Mythos 5, vs. Opus 4.8)

Source: Anthropic, "Prompting Claude Fable 5", plus the 4-component structure from Anthropic's Fable 5 prompting playbook (as condensed in the ai.edge cheat sheet, `prompt.jpg` at repo root). Apply on top of `references/general.md`. This family diverges the most from prior models — read this file fully before adapting a prompt for it.

## Safety classifiers — check this first, every time

Fable 5 runs safety classifiers targeting offensive-cybersecurity content, biology/life-sciences content, and **extraction of its own summarized thinking** (`reasoning_extraction`). Benign work in the first two domains can still trigger false positives; the third is fully avoidable by never asking the model to reproduce, transcribe, or explain its internal reasoning as response text. **When adapting any prompt for this family: scan for and remove/rephrase "explain your reasoning" / "show your thinking" / "walk me through your thought process" style instructions.** A tripped refusal falls back to Opus 4.8 at cost — the opposite of what this skill is for. If reasoning visibility is genuinely needed, point at reading the structured `thinking` blocks via the API instead of asking the model to narrate them in response text.

## The 4-component skeleton — check every Fable prompt against it

Every high-quality Fable 5 prompt carries four components. When adapting, verify each is present (or consciously unnecessary), and prefer this order:

1. **Context** — files, data, and background: the larger task this serves, who it's for, what the output enables. Fable 5 needs the *why*, not just the what — context lets it connect the task to intent instead of guessing, and guessing is exactly what burns tokens (clarifying turns, adaptive thinking firing on ambiguity).
2. **Request** — the specific ask, in one clear sentence.
3. **Output format** — exactly how the result should be structured and delivered.
4. **Constraints** — what must *not* happen on the way to the result / what the model must not assume on its own.

Canonical template (adapt, don't cargo-cult):

```
I'm working on [the larger task] for [who it's for].
They need [what the output enables].

Request: [your specific ask in one clear sentence]

Output format: [exactly how you want the result structured and delivered]

Constraints: [what must not happen on the way to the result]
```

Supply the why and the what — **not the how**. Prescribing the approach (step-by-step plans, mandated intermediate steps, hand-picked techniques) is over-engineering that measurably degrades Fable 5's output: it would have figured the approach out itself, often better. If a draft dictates method rather than outcome, strip the method and strengthen the outcome definition instead.

## Effort — the primary lever, and unusually strong at every level

`effort` is the main intelligence/cost/latency control. `high` is the recommended default for most tasks — it often exceeds `xhigh` performance on prior models, so resist reflexively reaching for `xhigh`/`max`. Use `xhigh` only for the most capability-sensitive workloads, `medium`/`low` for routine work. If a task completes correctly but slower than needed, that's a signal to lower effort, not raise it.

At higher effort on routine work, Fable 5 can over-gather context or over-deliberate, and can tidy/refactor beyond what was asked. If the adapted prompt is a bug fix or narrow task, include explicit scope discipline: "Don't add features, refactor, or introduce abstractions beyond what the task requires. Don't add error handling or validation for scenarios that can't happen."

## Longer turns by default — plan around this, don't fight it

Individual requests can legitimately run minutes to hours, especially at higher effort on hard tasks. If the adapted prompt targets an unattended/pipeline context, this is normal and expected — don't add artificial pacing instructions. If the task is ambiguous and risks overplanning, add: "When you have enough information to act, act. Do not re-derive facts already established, re-litigate a decision already made, or narrate options you won't pursue in user-facing messages."

## Strong instruction following — brief beats exhaustive

Fable 5 follows short instructions reliably; there's no need to enumerate every behavior by name. A brief brevity instruction ("lead with the outcome; your first sentence should answer 'what happened'") outperforms a long list of "don't do X, don't do Y" rules. The same applies to defining when the model should pause for user input — state the *category* of situation (irreversible action, real scope change, input only the user can provide), not an exhaustive list of cases. A canonical checkpoint block that does this well, for autonomous/unattended prompts:

> Pause for me only when the work genuinely requires my input: a destructive or irreversible action, a real scope change, or something only I can provide. Otherwise, keep going and report back when done.

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

If a draft is polling-shaped ("keep checking X and tell me when Y") and targets a Claude Code session, don't leave the recurrence inside the prompt text — recommend expressing it as `/loop <time interval> + goal` instead (e.g. `/loop 15 minutes, check if my build is passing, and notify me if it fails`). The harness handles the scheduling; the prompt then only needs the per-iteration goal.
