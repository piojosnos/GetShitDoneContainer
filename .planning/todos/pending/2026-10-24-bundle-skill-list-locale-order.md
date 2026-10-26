---
created: 2026-10-24
title: Bash glob order differs between the container and the Mac in the skill list check
area: tests
source: .planning/phases/02.2-best-practices-from-git-editable-from-any-sandbox/02.2-REVIEW.md (IN-05)
---

File: `tests/host/lib-bundle.sh:83-87`.

`.best-practices-skills` is written in the container's glob order (C/POSIX locale), while `clone_skill_names` globs on the Mac (usually `en_US.UTF-8`). The orders differ for names that mix case or punctuation (for example `a-b` and `ab`). The comparison is a plain string match, so it fails for such a skill set although the links are right. The fixture names and the current real skills sort the same in both locales, so nothing fails today.

Suggested fix: sort both sides with `LC_ALL=C sort` before comparing.
