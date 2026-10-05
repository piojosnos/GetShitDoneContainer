<!-- Source: best-practices/ in the GetShitDoneContainer repo. Each sandbox gets a fresh copy of this file at every container start, so edits to a copy are lost; change the source, then rebuild the image and restart. -->

# Prose style

Applies to every artifact you write: source comments, Markdown docs, READMEs, PR text.

- **No dashes as punctuation.** This covers the em dash (`—`), the en dash (`–`), the ASCII double hyphen (`--`) used as a stand-in for one, and a spaced single hyphen (` - `) used as an aside.
- Never swap an em dash for `--`. Restructure the sentence instead:
  - Join two independent clauses with `;`.
  - Put a label before its explanation with `:` (for example `FRAME: the persistent shell`).
  - Set off an aside with parentheses or commas, never a pair of dashes.
- The only `--` allowed is literal code: CSS custom properties like `--frame-*`, CLI flags like `--no-verify`. Those are syntax, not punctuation.
- **Punctuation goes outside closing quotes.** Write `"what", not "where".` with the comma or period after the closing quote.
  - Exception: punctuation stays inside when it is part of a verbatim quoted string or message.

Why: dashes standing in for punctuation are a persistent tic in generated prose that the user dislikes, and non-ASCII characters are fragile in source files.
