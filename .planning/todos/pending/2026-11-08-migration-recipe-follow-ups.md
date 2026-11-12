---
created: 2026-11-08
title: MIGRATION.md follow-ups from the EmailIntel move
area: docs
source: Phase 5 migrations (conversation)
audit_acknowledged:
  milestone: v1.0
  at: 2026-11-12
---

Two cases seen while moving the third old sandbox, handled by hand then:

- A project with files next to the code folder that the code uses through relative paths (EmailIntel: `docs/`, `emails/`, `storage/` and Word files beside `project/`, used by the project's own containers). The whole old home became the project folder: copy `"$OLD/."` into `$NEW/$NAME/`, then remove the old home's settings and caches from it (`.claude .claude.json .config .bashrc .cache .local .npm .initialized`). Session folders map `-home-sandbox` to `-home-sandbox-workspace-$NAME` and `-home-sandbox-project` to `-home-sandbox-workspace-$NAME-project`. `sbx-fix-modes` refuses there (git is one level down). Stop the project's own containers before copying; a `chown` over the whole folder can break database folders owned by another uid (EmailIntel's `storage/` was empty).
- An old home without `.gitconfig` brings no git name or email: set them in the new sandbox (`sbx-gh-login` asks; Enter skips).

Document the first as a case in MIGRATION.md, the second as one line.
