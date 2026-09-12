#!/usr/bin/env bash
# Write a recoverable snapshot of the current work tree without modifying it.
#
# Builds the snapshot commit through a throwaway index, so neither the working
# tree nor the real index is touched, and untracked files are included.
# (`git stash create` is not usable here: it refuses to run once untracked
# files have been registered with `git add -N`.)
#
# Snapshots land under refs/snapshots/resume/ rather than the stash list, so
# `git stash` stays usable for real work. Always exits 0 — this must never
# block a resume.
set -uo pipefail

git rev-parse --show-toplevel >/dev/null 2>&1 || {
  echo "not inside a git work tree — no snapshot taken"
  exit 0
}

if [ -z "$(git status --porcelain)" ]; then
  echo "work tree clean — no snapshot needed"
  exit 0
fi

tmpidx=$(mktemp -t resume-index.XXXXXX) || { echo "snapshot failed: mktemp"; exit 0; }
trap 'rm -f "$tmpidx"' EXIT
# git rejects a zero-byte index file; we want the unique path, not the file.
rm -f "$tmpidx"

parent=$(git rev-parse --verify --quiet HEAD)

if [ -n "$parent" ]; then
  GIT_INDEX_FILE="$tmpidx" git read-tree HEAD || { echo "snapshot failed: read-tree"; exit 0; }
fi

# -A stages tracked modifications, deletions, and untracked files, while
# still honouring .gitignore. The real index is unaffected.
GIT_INDEX_FILE="$tmpidx" git add -A || { echo "snapshot failed: add"; exit 0; }

tree=$(GIT_INDEX_FILE="$tmpidx" git write-tree) || { echo "snapshot failed: write-tree"; exit 0; }

if [ -n "$parent" ]; then
  snap=$(git commit-tree "$tree" -p "$parent" -m "resume snapshot")
else
  snap=$(git commit-tree "$tree" -m "resume snapshot")
fi
[ -n "$snap" ] || { echo "snapshot failed: commit-tree"; exit 0; }

ref="refs/snapshots/resume/$(date +%Y%m%d-%H%M%S)-$$"
if git update-ref "$ref" "$snap"; then
  echo "snapshot written: $ref"
  echo "inspect:  git diff $ref"
  echo "restore:  git checkout $ref -- <path>"
else
  echo "snapshot commit $snap created but ref write failed; inspect with: git diff $snap"
fi

exit 0
