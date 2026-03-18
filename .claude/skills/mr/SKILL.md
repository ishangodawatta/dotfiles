---
name: mr
description: Create or update a GitLab merge request using glab, following project conventions for title, description, and branch naming
argument-hint: "[create | update <mr-number>]"
---

# GitLab Merge Requests

The remote uses an SSH alias (`gitresearch-ishan`), so always specify `--repo`.

## Creating MRs
```bash
glab mr create --repo "uxperf/projects/pyfetto-mono" --title "UXPERF-XXXX: description" --description "description" --target-branch main --no-editor --remove-source-branch
```

## MR title format
Derive from branch name. Branch `UXPERF-1234/fix-whatever-feature` becomes title `UXPERF-1234: fix whatever feature`.

## MR description format
Start the description with a Jira link: `https://jira.arm.com/browse/UXPERF-XXXX` (derived from the branch ticket tag), followed by a blank line, then plain bullet points with `-`. No markdown headers. Each bullet describes one logical change.

## Commit tagging
All commits on a feature branch must be prefixed with the ticket tag: `UXPERF-XXXX: fix/refactor/feat/chore: message`.

## Updating an existing MR
When pushing new commits to an existing MR, regenerate the description from scratch using `git log main..HEAD` and update with:
```bash
glab mr update <mr-number> --repo "uxperf/projects/pyfetto-mono" --description "new description"
```
Do not attempt to incrementally append -- always rebuild the full description from the current branch state.

## Options
Always enable `--remove-source-branch` so the source branch is deleted after merge.
