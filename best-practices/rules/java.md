---
paths:
  - "**/*.java"
  - "**/*.ftl"
  - "**/pom.xml"
---
<!-- Source: best-practices/ in the GetShitDoneContainer repo. Each sandbox gets a fresh copy of this file at every container start, so edits to a copy are lost; change the source, then rebuild the image and restart. -->

# Java, Lombok and FreeMarker

These assume Java + Lombok + FreeMarker. Keep the instinct, translate it to your stack.

## Prefer the framework's codegen over hand-written boilerplate (Lombok first)

- If a class needs getters, equals/hashCode, a logger, or an all-args constructor, use the annotation (`@Getter`, `@EqualsAndHashCode`, `@Slf4j`, `@AllArgsConstructor`) rather than hand-writing it. Never hand-write a getter that `@Getter` on the field would emit.
- Exception: when a method must return a specific value verbatim (for example a `toString()` consumed by string interpolation), hand-write it, because the codegen form (`ClassName(field=value)`) breaks the consumer.
- Generalization for other stacks: lean on the language or framework's standard codegen or idiom instead of re-implementing boilerplate by hand; keep it consistent across the codebase.

## Typed wrappers over raw strings for paths and URLs

- When a value semantically IS a filesystem path or a URL, use the typed wrapper rather than raw `String`. The wrappers give segment-aware operations (`startsWith`, `stripPrefix`, `join`) that avoid byte-prefix bugs (matching `/foobar` against `/foo`).
- Generalization: wrap domain values that have their own equality, ordering or parsing rules in a type; do not pass them around as bare strings.

## Templates are side-effect-free

- A template computes and emits; it must not mutate program state. Route state changes through the framework's directive or helper contract, not through method calls interpolated into the template.
- Generalization: keep the view layer pure; side effects belong in code the engine invokes through an explicit contract.

## Template structure: legible, semantic wrappers

- Wrap each logical region of a page in its own identifiable container, so a reader can map emitted markup back to the template that produced it.
- Prefer a semantic element (`header`, `nav`, `main`, `footer`, `article`, `section`, `figure`) when one fits; fall back to a descriptively-classed `div` only when none applies. Every wrapper must earn its place (group, style hook, or structural clarity); do not nest for nesting's sake.
- Readability for a non-expert maintainer outranks markup minimalism.
