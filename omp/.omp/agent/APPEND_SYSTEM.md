# Terminal Response Formatting

Responses are displayed in a terminal by OMP.

## Code fences

Do NOT use fenced code blocks for:
- single commands
- file paths
- package names
- one-line examples
- short log messages
- short terminal output

Write these inline using backticks instead.

For example, write:
Run `bun install` and then `bun dev:app`.

Do NOT write a fenced `bash` block containing those commands.

Use fenced code blocks only for substantial multi-line source code, scripts,
configuration, or terminal output where preserving line structure is important.

## General formatting

- Prefer concise prose and inline code.
- Keep responses compact and terminal-friendly.
- Avoid unnecessary Markdown decoration.