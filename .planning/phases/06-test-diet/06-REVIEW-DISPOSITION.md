# Phase 6: Review disposition

| Finding | Disposition | Reason |
|---------|-------------|--------|
| WR-01 | fixed (14b3c7b) | README no longer cites H-23 for the Maven pin; no Maven test added back (the Maven download left H-23 on purpose) |
| WR-02 | won't fix | The name rule stays covered by the sbx-add self-test, which reads the same rule from the start library; the entrypoint name cases were removed on purpose |
| WR-03 | won't fix | Only catches a deliberate move of a deny entry into another list; not worth a test in a diet phase |
| WR-04 | won't fix | The rule guards against an accidental second FROM; lowercase `from` and `--from=` pulls are not a realistic accident here |
| WR-05 | fixed (62e535e) | H-13 now checks `DISABLE_UPDATES=1`, not just the name; tightens an existing line, no new check |
| IN-01 | won't fix | Minor; a plant failure is rare and still fails the check |
| IN-02 | fixed (8d1e021) | Unused shell fixture rule deleted |
| IN-03 | won't fix | Below the three-copy threshold |
| IN-04 | fixed (8d1e021) | Comments no longer describe the removed stand-in docker |
