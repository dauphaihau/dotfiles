---
allowed-tools: Bash(git diff:*), Bash(git status:*), Bash(git log:*)
description: Analyze current git changes and suggest logical commit groupings with messages
---

Analyze the current git working tree and suggest how to group changes into focused, atomic commits.

## Step 1 — Gather context
!`git status --short`
!`git diff --stat HEAD`
!`git diff HEAD`

## Step 2 — Analyze and suggest groups

Based on the diff above, identify logical groupings by:
- **Purpose**: features, bug fixes, refactors, config changes, tests, docs
- **Module/domain**: changes that belong to the same feature area or layer
- **Dependency order**: if commits must land in a specific sequence, say so

## Step 3 — Output format

For each suggested commit group, provide:

### Group N: `<conventional-commit message>`
**Files to stage:**

git add <file1> <file2> ...

**Why together:** One sentence explaining the cohesion.

---

Rules to follow:
- Use [Conventional Commits](https://www.conventionalcommits.org/) format: `type(scope): description`
- Each commit should be independently deployable and reviewable
- Unrelated changes must never share a commit
- If a file spans multiple concerns, call it out and suggest splitting it
- End with the exact `git add` + `git commit -m` commands ready to copy-paste