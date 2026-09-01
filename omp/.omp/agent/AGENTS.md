# Agent Delegation

Choose the lightest execution level appropriate for the task.

## OMP native task

Use the native `task` tool for focused work that mainly returns information:

* codebase exploration and research
* finding files, symbols, and references
* code review and debugging
* checking tests
* comparing approaches

Do not create an Orca terminal for lightweight research.

## Orca terminal worker

Use an independent Orca terminal for substantial implementation:

* features spanning related files
* significant refactoring or tests
* migrations
* independent fix/test cycles

Workers may use OMP native subagents internally.

## Orca orchestration

Use Orca orchestration when multiple substantial workstreams can proceed independently or in parallel, such as frontend + backend + tests, large migrations, or multiple features/bugs.

Hierarchy:

OMP native task → focused research/helper work
Orca worker → substantial implementation
Orca orchestration → multiple substantial workstreams

# Shell Execution

For independent read-only/inspection commands likely to be auto-approved, prefer separate Bash calls rather than combining them with `&&`, `||`, `;`, pipes, or multiple commands.

Examples: `git status`, `git diff`, `git log`, `git show`, `ls`, `pwd`.

Prefer:

`git -C apps/web status --short`
`git status --short`

over:

`git -C apps/web status --short && git status --short`

Compound commands are fine when chaining is meaningful, such as build/test/setup workflows. Do not split commands unnecessarily.
