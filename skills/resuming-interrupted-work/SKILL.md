---
name: resuming-interrupted-work
description: Recover a Superpowers plan execution that stopped mid-task — credit exhaustion, a crash, a killed subagent, or a closed terminal. Use when the user says they ran out of credits, asks to pick up where you left off, or when a session opens onto an active plan in docs/plans/ with an uncommitted work tree.
---

# Resuming interrupted work

The uncommitted diff is the interrupted task. It is the least reproducible
state in the repository. Do not reset, stash, clean, or discard anything
without first telling the user exactly what would be lost and getting a yes.

Under `subagent-driven-development` each task commits on completion, so at most
one task's work is ever uncommitted. Scope the recovery to that one task. Do
not re-derive the whole plan.

## Step 0 — Snapshot, if not already done

If invoked via `/resume-plan`, the snapshot already ran; skip this.

Otherwise run `scripts/snapshot-worktree.sh` from this plugin.

## Step 1 — Locate the workspace

Run `git worktree list`. Superpowers plans execute in an isolated worktree.

- A worktree for the plan's branch exists → `cd` into it. Do **not** create another.
- On main/master with no worktree → the interrupted run may have been on a
  branch that was never checked out here. Stop and ask before creating one.

## Step 2 — Locate the plan

Use the user's hint if given. Otherwise glob `docs/plans/*.md` and
`docs/superpowers/plans/*.md`, take the most recently modified with unchecked
boxes. If more than one is plausible, ask — do not guess.

If a `<plan-path>.tasks.json` or sibling `*.tasks.json` exists, prefer it over
the checkboxes. It is written on every status change and is authoritative.

## Step 3 — Classify the uncommitted state

Read `git diff` and `git diff --cached` before concluding anything.

| What you see | Where execution stopped | What to do |
|---|---|---|
| New/modified test only, test fails | RED complete, GREEN not started | Write the implementation |
| Test + partial implementation | Mid-GREEN | Run the test first, then finish |
| Test + implementation, test passes | GREEN complete, commit missing | Verify, then commit |
| Changes unrelated to any plan task | Unknown | **Stop.** Report and ask |
| Clean tree | Stopped between tasks | Resume at next unchecked task |

Run the plan's verification command for the task in question before trusting
any of the above. A test that fails for an unrelated reason will send you down
the wrong branch of this table.

## Step 4 — Reconcile the plan

Compare the plan's checkboxes against `git log --oneline` and the
classification above. Correct the checkboxes to match reality and **state
explicitly which ones were wrong and in which direction**. A checkbox marked
done with no commit behind it is the important case — that task did not happen.

## Step 5 — Report, then hand off

Report before executing:

- Which plan, which worktree
- Which task was in flight and what phase it stopped in
- Which checkboxes you corrected
- The snapshot ref, if one was written

Then hand off to `superpowers:executing-plans` (or
`superpowers:subagent-driven-development` if subagents are available),
resuming at the first genuinely incomplete task. Do not restart completed tasks.

## Convention that makes the next recovery trivial

Include the plan file in each task's commit, with that task's checkbox ticked
as part of the same commit. The plan then becomes durable, always-consistent
state that `git log` can reconstruct exactly — no separate task file to drift,
no session-scoped todo list to lose. If the user is not already doing this,
suggest it once at the end of the recovery.
