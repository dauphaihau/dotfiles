# Agent Delegation

Choose the lightest execution level appropriate for the task.

## Inline work

Do it yourself when the task is one or two tool calls, or when you already know the
location: single edits, one-file fixes, reading a known path, quick shell checks. Do not
spawn a subagent to avoid a single `read` or `grep`.

## OMP native task

Use the native `task` tool for focused work that mainly returns information, and for
self-contained slices of implementation:

* codebase exploration and research
* finding files, symbols, and references
* code review and debugging (`reviewer`, `security-reviewer`)
* checking tests
* comparing approaches
* features spanning related files, refactors, migrations, independent fix/test cycles

Pick the narrowest agent: `scout` for read-only exploration and unknown code shape,
`sonic` for mechanical edits and data collection, `task` when the slice needs edits plus
verification, `seance` to consult a past session.

Rules:

* One subagent owns a slice end to end; never split a single fix across siblings. Siblings
  coordinate only through `write agent://<id>`.
* Put shared contracts — interfaces, file ownership, non-goals — in `context`; put
  per-slice detail in each `task`.
* Fan out genuine independent slices in one `tasks[]` batch. Do not serialize independent
  work, and do not spawn then idle.
* Subagents never run build/lint/tests mid-flight; run those once after integration.
* Subagents get no conversation history: pass every requirement they need.

## Parallel / programmatic fan-out

When the fan-out is generated rather than hand-listed (N files, N issues, a matrix of
cases), drive it from `eval` with `workpool()` or `agent()` instead of writing N literal
`tasks[]` entries. Results auto-deliver; wait only when blocked.

## Long-running processes

Use OMP `hub` for dev servers, watchers, and workers that outlive one call. Never use
`nohup`, `disown`, or shell `&` as a substitute, and stop every temporary process before
finishing.

# Shell Execution

For independent read-only/inspection commands likely to be auto-approved, prefer separate Bash calls rather than combining them with `&&`, `||`, `;`, pipes, or multiple commands.

Examples: `git status`, `git diff`, `git log`, `git show`, `ls`, `pwd`.

Prefer:

* `git -C apps/web status --short`
* `git status --short`

over:

`git -C apps/web status --short && git status --short`

Compound commands are fine when chaining is meaningful, such as build/test/setup workflows. Do not split commands unnecessarily.
