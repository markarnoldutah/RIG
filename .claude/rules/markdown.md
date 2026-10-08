---
description: 'Markdown documentation standards for this repository'
# Claude Code reads `paths`; GitHub Copilot reads `applyTo` (via the symlink in .github/instructions/).
paths:
  - "**/*.md"
applyTo: '**/*.md'
---

## Markdown Content Rules

1. **Headings**: Use `##` for top-level sections and `###` for subsections. Reserve `#` for the document title only.
2. **Lists**: Use `-` for unordered lists and `1.` for ordered lists. Indent nested lists with two spaces.
3. **Code Blocks**: Use fenced code blocks with a language specifier (e.g., ```csharp, ```json).
4. **Links**: Use descriptive link text — avoid bare URLs or "click here".
5. **Tables**: Use markdown tables for structured data. Align columns and include headers.
6. **Whitespace**: Use blank lines to separate sections. Avoid excessive blank lines.

## Formatting Guidelines

- Keep lines under 400 characters.
- Use **bold** for emphasis on key terms in lists and tables.
- Use backticks for inline code, file names, class names, and CLI commands.
- No YAML front matter except where a tool requires it: Claude Code rules (`.claude/rules/*.md`: `paths`, plus `description`/`applyTo` for Copilot), skills (`SKILL.md`: `name`, `description`), Copilot agents (`.agent.md`), and ADRs (`Docs/ADR/adr-*.md`, front matter per the `create-architectural-decision-record` skill).