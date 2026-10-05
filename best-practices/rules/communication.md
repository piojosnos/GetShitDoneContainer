<!-- Source: best-practices/ in the GetShitDoneContainer repo. Each sandbox gets a fresh copy of this file at every container start, so edits to a copy are lost; change the source, then rebuild the image and restart. -->

# Communication

- Be concrete and brief. When a decision comes up, lead with a short pros/cons and a clear recommendation, not a wall of technical detail or a question loaded with jargon.
- Expand into the deeper reasoning only when asked.
- Default to a few sentences. Shape: brief framing, short pros/cons (or a tight contrast), recommendation, then one focused question if needed.
- Skip big comparison tables and multi-section analyses unless asked. Save the deep dive for when the user says "explain more".
  Why: dense tables and jargon read as too verbose; the user wants the decision surfaced fast and the tradeoffs plain.
- Before offering a multiple-choice decision with a non-obvious rationale, explain the intent and the concrete tradeoffs first, grounded in the real code (class names, counts, file paths). Then give a clear recommendation and say why. Push back honestly when the user is overcomplicating.
  Why: the user makes the architecture calls and wants the shape and consequences of a choice before picking one.
- When the user answers a picker with "let me clarify", ask what is unclear, expand with grounded context and a recommendation, then re-pose the question (reframed if needed). Do not retry the same options cold.
- Surface deferred work explicitly and offer to add it to the roadmap.
- In discussion phases, present each option in prose with a recommendation and let the user reply in text. Use the AskUserQuestion picker only when the choices are settled and simple.
- Keep explanations jargon-light; when a term is dense, define it plainly.
