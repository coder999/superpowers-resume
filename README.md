# superpowers-resume

Non-destructive recovery for a [Superpowers](https://github.com/obra/superpowers)
plan execution that was interrupted mid-task: credit exhaustion, a crash, a
killed subagent, a closed terminal.

Recovery is **manual and post-session-start**. Nothing fires automatically,
and nothing in the work tree is ever reset, stashed, cleaned, or discarded.
The uncommitted diff *is* the interrupted task, and this plugin treats it as
the thing to protect.

## What `/resume-plan` does

1. **Snapshot.** Runs `scripts/snapshot-worktree.sh`, which writes a commit of
   the current work tree (tracked modifications, deletions, and untracked
   files) to `refs/snapshots/resume/<timestamp>-<pid>`. It builds the commit
   through a throwaway index, so neither the working tree nor the real index
   is touched. It always exits 0 so it can never block a resume.
2. **Inject git context.** Expands `git worktree list`, `git status --short`,
   `git diff --stat`, `git log --oneline -20`, and a listing of candidate plan
   files under `docs/plans/` and `docs/superpowers/plans/` into the prompt.
3. **Hand to the skill.** Invokes `resuming-interrupted-work`, which locates
   the worktree and the plan, classifies the uncommitted state (RED done,
   mid-GREEN, GREEN done but uncommitted, or unrelated), reconciles the plan's
   checkboxes against `git log`, reports, and then hands off to whatever
   `superpowers:executing-plans` / `superpowers:subagent-driven-development`
   is installed. It does not fork or override those skills.

The snapshot and the git context are `!` command lines in the command file.
They run at command-expansion time, before the model acts, which is what
guarantees the snapshot lands before anything can touch the tree.

Usage:

```
/resume-plan
/resume-plan docs/plans/2026-09-12-feature.md
```

The optional argument is a hint about which plan to resume. Plugin commands
are also reachable under their namespaced name, `/superpowers-resume:resume-plan`.
In print mode (`claude -p`) only the namespaced form resolved (verified
2026-09-12 on Claude Code 2.1.268); use it if the short form is not found.

## Install

**Local testing** (no install, picked up for this session only):

```bash
claude --plugin-dir /path/to/superpowers-resume
```

**Persistent** (from a marketplace that lists this plugin):

```
/plugin marketplace add <marketplace>
/plugin install superpowers-resume@<marketplace>
```

**Without the plugin system.** Dropping `commands/`, `skills/`, and `scripts/`
directly into `~/.claude/` also works, but the command file references
`${CLAUDE_PLUGIN_ROOT}`, which is only set for plugins. Edit the snapshot line
in `commands/resume-plan.md` to point at `~/.claude/scripts` instead:

```
!`bash ~/.claude/scripts/snapshot-worktree.sh`
```

## Editing the plugin

Skill edits are live: the next invocation reads the current `SKILL.md`. Hook
and command changes need `/reload-plugins` (or a restart) before they take
effect.

## Snapshot management

Snapshots live under `refs/snapshots/resume/`, not in the stash list, so
`git stash` stays free for real work. They are ordinary commits with `HEAD` as
parent (or no parent in a repo with no commits yet).

```bash
git for-each-ref --sort=-refname refs/snapshots/resume   # list
git diff refs/snapshots/resume/<ts>                      # inspect
git checkout refs/snapshots/resume/<ts> -- <path>        # restore one file
git for-each-ref --format='%(refname)' refs/snapshots/resume \
  | head -n -10 | xargs -r -n1 git update-ref -d         # prune to last 10
```

Deleting a ref leaves the commit as a dangling object until `git gc` reaps it.

## Caveats

- **`.gitignore` is honoured.** The snapshot uses `git add -A`, so ignored
  files (`.env`, build output, editor state) stay out of snapshots, the same
  as they stay out of commits. If the interrupted task touched an ignored
  file, the snapshot will not have it.
- **`allowed-tools` constrains the model, not the `!` lines.** The fixed
  command lines in `resume-plan.md` run regardless of the allowlist. The
  allowlist only governs what the model may run afterwards, and `Bash(bash:*)`
  is broad: it permits any `bash ...` invocation. Narrow it if that matters in
  your environment.
- **`disable-model-invocation: true`** keeps the command strictly manual. The
  model cannot decide to run `/resume-plan` on its own; only you can. The
  `resuming-interrupted-work` skill, by contrast, can be invoked by the model
  when the situation matches its description, but the skill itself never
  discards work.
- **Two snapshots in the same second get distinct refs** because the ref name
  carries the script's PID. They are otherwise identical commits.
- The snapshot script deliberately does not use `git stash create`. That
  command silently returns nothing once untracked files have been registered
  with `git add -N`, and the surrounding pipeline still exits 0, so it fails
  without saving anything.

## License

MIT. See `LICENSE`.
