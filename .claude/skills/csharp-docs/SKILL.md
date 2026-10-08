---
name: csharp-docs
description: Write or review C# XML documentation comments (summary, param, returns, exception, value, inheritdoc wording conventions). Use when adding XML docs to public C# APIs, reviewing doc comments, or when the user asks to document C# code.
---

# C# Documentation Best Practices

Apply to the files or scope the user names; otherwise to public types changed in the current git diff.

- Public members get XML comments. Interfaces in `BigRig.Domain` / `BigRig.Contracts` and DTOs always do — DTO comments flow into the OpenAPI description.
- Document internal members when they are complex or not self-explanatory. Don't add boilerplate comments to obvious private code.
- Explain **why** in `<remarks>` when a design decision isn't obvious (e.g. why a query stays in PostGIS, why a write is idempotent).

## Guidance for all APIs

- `<summary>`: one sentence, starting with a present-tense, third-person verb.
- `<remarks>`: implementation details, usage notes, other context.
- `<see langword="..."/>` for keywords like `null`, `true`, `false`, `int`.
- `<c>` for inline code.
- `<example>` with `<code language="csharp">` for usage examples.
- `<see cref="..."/>` for inline references; `<seealso cref="..."/>` for standalone "See also" references.
- `<inheritdoc/>` to inherit from base classes or interfaces, unless behavior changes materially — then document the difference.

## Methods

- `<param>`: a noun phrase that doesn't state the data type, beginning with an article.
  - Flag enum: "A bitwise combination of the enumeration values that specifies…".
  - Non-flag enum: "One of the enumeration values that specifies…".
  - Boolean: "`<see langword="true"/>` to …; otherwise, `<see langword="false"/>`."
  - `out` parameter: "When this method returns, contains …. This parameter is treated as uninitialized."
- `<paramref>` to reference parameters; `<typeparam>` / `<typeparamref>` for generics.
- `<returns>`: a noun phrase beginning with an article, without the data type. Boolean: "`<see langword="true"/>` if …; otherwise, `<see langword="false"/>`."

## Constructors

- Summary: "Initializes a new instance of the `<see cref="ClassName"/>` class." (or struct/record).

## Properties

- Summary starts with "Gets or sets…" (read-write), "Gets…" (read-only, including `init`-only), or "Gets [or sets] a value that indicates whether…" (Boolean).
- `<value>`: a noun phrase without the data type; state any default in a separate sentence ("The default is `<see langword="false"/>`.").

## Exceptions

- `<exception cref="...">` for every exception thrown directly by the member — including guard clauses (`ArgumentNullException`, `ArgumentException`) and `KeyNotFoundException` from services.
- For exceptions from nested calls, document only the ones callers are likely to hit.
- State the condition directly, without "Thrown if…": "`<paramref name="rigId"/>` is empty."
