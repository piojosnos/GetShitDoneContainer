---
paths:
  - "**/*.java"
---
<!-- Source: best-practices/ in the GetShitDoneContainer repo. Each sandbox gets a fresh copy of this file at every container start, so edits to a copy are lost; change the source, then rebuild the image and restart. -->

# Java and Lombok

## Prefer Lombok over hand-written boilerplate

- If a class needs getters, equals/hashCode, a logger, or an all-args constructor, use the annotation (`@Getter`, `@EqualsAndHashCode`, `@Slf4j`, `@AllArgsConstructor`) rather than hand-writing it. Never hand-write a getter that `@Getter` on the field would emit.
- Exception: when a method must return a specific value verbatim (for example a `toString()` consumed by string interpolation), hand-write it, because the codegen form (`ClassName(field=value)`) breaks the consumer.
