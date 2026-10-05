---
paths:
  - "**/*.ftl"
---
<!-- Source: best-practices/ in the GetShitDoneContainer repo. Each sandbox gets a fresh copy of this file at every container start, so edits to a copy are lost; change the source, then rebuild the image and restart. -->

# FreeMarker templates

## Templates are side-effect-free

- A template computes and emits; it must not mutate program state. Route state changes through the framework's directive or helper contract, not through method calls interpolated into the template.
- Keep the view layer pure; side effects belong in code the engine invokes through an explicit contract.

## Template structure: legible, semantic wrappers

- Wrap each logical region of a page in its own identifiable container, so a reader can map emitted markup back to the template that produced it.
- Prefer a semantic element (`header`, `nav`, `main`, `footer`, `article`, `section`, `figure`) when one fits; fall back to a descriptively-classed `div` only when none applies. Every wrapper must earn its place (group, style hook, or structural clarity); do not nest for nesting's sake.
- Readability for a non-expert maintainer outranks markup minimalism.
