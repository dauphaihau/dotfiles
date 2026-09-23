# Process cleanup

- Never leave temporary development processes running after completing a task.
- Never use `nohup`, `disown`, or shell `&` for temporary development servers, watchers, or workers.
- Prefer OMP `hub` for long-running development processes.
- Track every temporary process started during the task.
- Before finishing a task, stop all temporary processes started by the agent.
- Never kill processes that were not started by the current task unless explicitly asked.


## Rule loading test

When the user says exactly `RULES_TEST_9274`, respond with
`RULES_LOADED_9274` before doing anything else.