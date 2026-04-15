# dotfiles

Agent-facing guidance. This file extends `README.md` — see it for setup, vault layout, symlink wiring, failure modes, and related references.

## Canonical sources

- [`README.md`](README.md) — prerequisites, bootstrap command, [vault layout](README.md#vault-layout), [symlink wiring](README.md#how-the-symlinks-are-wired), [adding a new project](README.md#adding-a-new-project), [failure modes](README.md#failure-modes), cross-machine sync.
- [`setup-macos.sh`](setup-macos.sh) / [`setup-debian.sh`](setup-debian.sh) — the wiring is the code. Consult these before adding new linking logic.

## Invariants

- Setup scripts are idempotent. Re-run freely; never add state that breaks on re-run.
- The auto-discovery loop walks `agents/*/` and treats any subdir with a `memory/` child as a Claude project. It skips `skills/`, `src/`, and dotdirs — do not place project dirs with those names.
- Never create `~/src/obsidian/projects/agents/` if it is missing. A missing vault root means the vault isn't mounted; creating it writes data to the wrong place.
- Never `mv` across the local→vault boundary in scripts or skills. The vault may live on a synced filesystem (iCloud, Syncthing) where `mv` is a non-atomic copy-then-delete. Always `cp -a`, verify, then `rm`.
- The vault subdir name must match the on-disk project basename. For git repos, the project must live at `~/src/<name>/`; the `vault-claude-memory` skill enforces this and the auto-discovery loop assumes it. For non-git projects (e.g. Drive folders), the skill writes a `.project-root` file alongside `memory/` so the auto-discovery loop can derive the correct destination key from its content.

## When modifying setup scripts

- Preserve the broken-symlink check at the top of the linking phase.
- Preserve the post-wiring diff that catches newly-introduced dead links.
- Keep `setup-macos.sh` and `setup-debian.sh` in step — same linking logic, POSIX-compatible `find` syntax on Linux.
