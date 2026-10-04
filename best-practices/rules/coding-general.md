<!-- Source: best-practices/ in the GetShitDoneContainer repo. Each sandbox gets a fresh copy of this file at every container start, so edits to a copy are lost; change the source, then rebuild the image and restart. -->

# General coding

Language-agnostic conventions for new application code.

## Control flow: prefer imperative over functional-chain style

- Default to `if` / `for` / `while` over lambdas and stream or pipeline chains. Reach for a lambda or chain only when there is no clean imperative equivalent.
- Avoid: a `filter().map().collect()` chain where a `for` loop accumulating into a local list would read more plainly; a deferred-callback form of a plain null-check.
- Framework callbacks the framework demands (event handlers, visitor dispatch, template directives) are fine; this rule targets new application code.

## Braces always

- Every `if` / `else` / `for` / `while` / `do` body uses braces, even a one-statement body. No brace-less `if (x) foo();`.
- Opening brace on the same line as the keyword; body multi-line. This removes a class of dangling-else and merge-conflict bugs.

## Variable naming: full names by default

- Use full descriptive names (`macroContribution`, not `m`; `resourcePath`, not `p`). The cost of typing is trivial; ambiguous one-letter names compound across grep, review, and refactor.
- Sanctioned short forms (the only ones): loop counters `i` / `j` / `k`; caught exceptions `e`; `StringBuilder` -> `strbld`, `StringBuffer` -> `strbuf`.

## Collection naming: type suffix

- Suffix every collection-typed variable, field, and parameter with its shape: `List<X> xList`, `Set<X> xSet`, `X[] xArray`, `Map<X,Y> xByYMap` (read "x by y").
- Disambiguate collisions with a prefix (`fooXList` / `barXList`). The suffix tells a reader it is iterable, sized and indexable without chasing the declaration.

## Blank lines around control flow

- Blank line before every `for` / `while` / `if` / `do`, and after its closing brace, so control-flow boundaries are scannable.
- Exceptions (cuddle, no blank line): `} else if {` / `} else {` chains stay attached to the prior brace (treat the whole chain as one construct; blank line only after the final outer brace); stacked closing braces `} } }` stay together, with the blank line after the outermost one.

## Comments

- No "rationale of past changes" comments (`// was X`, `// pre-N this did Y`). They rot and add nothing over `git log` and `git blame`.
- No planning-document or internal-ID references in code (for example a comment citing a planning file and a decision number, or a phase ID). External readers do not have those docs. State the reasoning self-contained if a design choice is non-obvious.
- Forward-looking design context IS fine when it answers "why not the obvious thing?" Keep it short and self-contained.
- `TODO:` is fine for tracked work; prefer `// TODO(<phase/ticket>): <action>` so it has an owner and a deadline.
- ASCII only inside source files: no smart quotes, arrows, ellipses, em or en dashes. Use `->`, `...`, plain quotes.

## Documentation comments only when asked

- Do not add doc-comments (Javadoc, docstrings) unless asked or unless they were already there. Names carry the meaning; review threads document the non-obvious. Pre-existing doc-comments stay.

## No duplicated utility code

- Extract to a helper at three or more duplicates. Two hand-rolled copies is tolerable; the third should consolidate.
- Prefer a library already on the classpath over a hand-rolled wrapper (recursive copy, deep-equals, string-join, etc.). If the hand-roll is more than a ~3-line loop, there is probably a library helper; search first. The library version handles the edge cases the hand-roll silently ignores.

## Symmetry

When two things can be implemented the same way, implement them the same way, as long as it makes sense and is not a hack. Symmetry lets a maintainer reason about one thing and apply that to its sibling.

- Prefer the symmetric design when offering options.
- Flag honest asymmetries explicitly and justify them by a genuine difference between the two things (a bounded card needs a layout wrapper that an unbounded page does not). Do not force symmetry onto things that only look similar.
- Align names with what they represent: context-prefixed class names should match their token context (for example `card-*` classes with `--card-*` tokens), so a name strongly reflects its target.
- When symmetry fixes keep surfacing inconsistent names, propose a wider naming audit.

## First-party tooling

Use the project's own scripts and tools for a task the project already solves; never reach for an ad-hoc substitute.

- If the project ships a script that serves its generated output, use it, not a generic static server. Generate fixtures with the project's own generator.
- Before substituting an external tool, search for a project one (script folders, tool modules, module READMEs). Fall back only when the search genuinely comes up empty, and say so.

Why: first-party tools encode project-specific behavior (for example serving each site at the base path it was generated for, or wiping a stale work dir) that a generic tool silently gets wrong.
