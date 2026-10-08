---
name: frontend-design
description: Design and build distinctive, production-grade UI for the RigRoom Blazor WASM web app (admin queue, trip planner), MAUI screens, or standalone HTML pages, avoiding generic AI aesthetics. Use when the user asks to build, style, redesign, or beautify a page, component, screen, or layout.
---

Adapted from the `frontend-design` skill in Anthropic's public skills repository, tuned for RigRoom's stack and users.

This skill guides creation of distinctive, production-grade interfaces that avoid generic "AI slop" aesthetics. Implement real working code with careful attention to aesthetic detail and deliberate creative choices.

## Know the context first

- **Blazor WASM (`RigRoom.Web`)**: Razor components with scoped `.razor.css`; maps via the MapLibre JS-interop wrapper. Follow `.github/instructions/blazor.instructions.md`.
- **MAUI (`RigRoom.Mobile`)**: XAML + CommunityToolkit.Mvvm, Mapsui map. Styles live in shared resource dictionaries, not inline.
- **Users**: RVers driving large rigs. Drive mode is read **at a glance, in a moving vehicle, often in bright sun** — large type, very high contrast, big touch targets (≥ 48 dp), minimal text, nothing that demands precise taps. The admin queue is a desk tool used for long sessions — dense but calm.
- If a design system or brand tokens exist in the repo, use them. Otherwise define tokens (CSS custom properties / XAML resources) once and reference them everywhere — never inline ad-hoc colors.

## Design Thinking

Before coding, commit to a clear aesthetic direction:

- **Purpose**: What problem does this interface solve? Who uses it, and where (cab of a truck vs. a desk)?
- **Tone**: Pick a distinct direction — e.g. industrial/utilitarian, rugged outdoors, road-atlas editorial, refined minimal. Bold maximalism and refined minimalism both work; intentionality matters more than intensity.
- **Constraints**: framework, offline use, performance on mid-range phones, accessibility.
- **Differentiation**: What is the one thing someone will remember?

Then implement working code that is production-grade, cohesive, and refined in every detail.

## Aesthetics Guidelines

- **Typography**: Choose characterful fonts rather than defaults like Arial, Inter, or Roboto; pair a distinctive display face with a highly legible body face. Self-host fonts (offline-first app; no font CDNs at runtime). Legibility beats personality in drive mode.
- **Color & Theme**: A cohesive palette with dominant colors and sharp accents, defined as tokens. Support light and dark (night driving). Status — fits / doesn't fit / unverified / contested — is never conveyed by color alone; pair with icon or text. Check WCAG AA contrast (aim higher for drive mode).
- **Motion**: Purposeful, CSS-first in Blazor. One well-orchestrated reveal beats scattered micro-interactions. **No distracting motion in drive mode**; respect `prefers-reduced-motion`.
- **Spatial Composition**: Unexpected layouts, asymmetry, and grid-breaking elements are welcome on planning and marketing surfaces. Generous negative space or controlled density — chosen deliberately.
- **Backgrounds & Details**: Create atmosphere and depth (textures, patterns, layered transparencies, considered shadows) where it fits the direction — not on maps, where clarity of the basemap wins.

Avoid generic AI aesthetics: overused font families, clichéd palettes (purple gradients on white), predictable cookie-cutter layouts. Vary choices to fit the context instead of converging on the same look every time.

Match implementation complexity to the vision: maximalist designs need elaborate code; minimal designs need restraint and precision in spacing and typography.

## Before handing off

- Works at phone width (and tablet landscape for MAUI); no horizontal scroll.
- Keyboard and screen-reader basics: labelled controls, `aria-label` on icon-only buttons, visible focus.
- Loads and renders with no network where the feature is meant to work offline.
