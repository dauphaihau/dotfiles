# Agent Delegation

When delegating work, choose the appropriate execution level.

## OMP native task subagent

Use the native `task` tool for small, focused delegation such as:

- codebase exploration
- finding files, symbols, and references
- understanding existing implementation
- research
- code review
- focused debugging
- checking tests
- comparing implementation approaches

Prefer native OMP subagents when the worker mainly needs to return
information or a focused result to the parent agent.

Do not open a separate Orca terminal for lightweight research.

## Orca terminal worker

Use an independent Orca terminal worker when a task requires substantial
independent implementation, such as:

- implementing a feature
- modifying several related files
- substantial refactoring
- writing a significant test suite
- migration work
- an independent debug/fix/test cycle

A terminal worker should own a meaningful piece of work rather than
a small research question.

The worker may use OMP native task subagents internally.

## Orca orchestration

Use Orca orchestration when the overall request contains multiple
substantial workstreams that can run independently or in parallel.

Examples:

- backend + frontend + tests
- multiple independent features
- large migrations
- repository-wide changes
- several substantial bugs
- implementation + independent verification

Use Orca to coordinate these high-level workers.

## General rule

Use this hierarchy:

small research/helper task
→ OMP native task

substantial independent implementation
→ Orca terminal worker

multiple substantial coordinated implementations
→ Orca orchestration

Avoid creating unnecessary Orca terminals when an OMP native task
would be sufficient.