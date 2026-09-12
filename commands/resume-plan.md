---
description: Resume a Superpowers plan interrupted mid-task
argument-hint: [plan file or name]
allowed-tools: Bash(bash:*), Bash(git:*), Bash(ls:*), Read, Edit, Glob, Grep
disable-model-invocation: true
---

## Snapshot

!`bash ${CLAUDE_PLUGIN_ROOT}/scripts/snapshot-worktree.sh`

## Worktrees

!`git worktree list`

## Work tree state

!`git status --short`

!`git diff --stat`

## Recent history

!`git log --oneline -20`

## Candidate plans

!`ls -t docs/plans/*.md docs/superpowers/plans/*.md 2>/dev/null | head -10`

---

Use the `resuming-interrupted-work` skill to recover from this interruption.

Plan hint from the user (may be empty): $ARGUMENTS
