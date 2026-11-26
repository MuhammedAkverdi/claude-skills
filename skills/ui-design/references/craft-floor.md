# Craft Floor & Anti-Slop Rules

Read this before writing any HTML, CSS, or component code. A pinned user brief always wins over defaults; when an axis is free, enforce every rule below.

---

## 1. Absolute Bans (Never Ship These)

1. **No caption or description beneath hero visuals.** Photo/licence credits belong in a single clean footer line if needed.
2. **No ALL-CAPS eyebrow / kicker above every heading.** Let the heading carry its own weight; delete decorative mini-labels above section titles.
3. **No gradient text.** Emphasis comes from size, weight, spacing, or contrast — never `background-clip: text` gradients.
4. **No nested cards.** Never put rounded bordered cards inside other rounded bordered cards. Use flat typography, hairline rules, or whitespace grouping.
5. **No `01 / 02 / 03` numbering on non-sequential content.** Numbers are only for real ordered steps, timelines, or ranked lists.
6. **No `→` appended to every button and link.** Use plain action verbs; reserve arrows only for external links or explicit directional navigation.
7. **No broken or empty visual slots.** Every `<img>` must have `naturalWidth > 0` and clean `aspect-ratio` / `object-fit`; never ship blank gray boxes.
8. **No `Lorem ipsum` or generic cliché names** (*Acme, John Doe, Sarah Jenkins, Nexus, Aura, Zenith, Apex*).

---

## 2. 2026 AI-Slop Tells (Reject in the Swap Test)

If your Pass 1 design plan resembles any of these unprompted clichés, redesign that axis before coding:

- **Warm cream (`#F4F1EA`) + high-contrast serif + terracotta (`#D97757`)** when the brief didn't ask for editorial/ceramic warmth.
- **Near-black (`#0B0B0B`) + violet/purple gradient glow or acid-green blobs** as a generic "AI/SaaS" skin.
- **The 3-card SaaS row:** identical rounded boxes, each with a small colored icon badge, bold title, and 2-line muted text.
- **Hero-metric cliché:** huge centered number + tiny muted label + glowing accent pill.
- **Middot meta strings everywhere** (`Fast · Secure · Scalable`) and spaced em-dash fragments (`FEATURE — Built for speed`).
- **Single italicized or accent-colored word** inside an otherwise plain `<h1>`.
- **Same fade-and-slide-up entrance** copied onto every section on scroll.

---

## 3. Quality Floor Checklist

### Color & Contrast
- Body and placeholder text contrast **≥ 4.5:1**; large display text and UI borders/controls **≥ 3:1**.
- On tinted or colored surfaces, derive secondary text from that surface's hue or ink at controlled opacity — never muddy neutral gray.
- Shadows use subtle real-world offset + soft blur (`0 1px 2px rgba(...)`, `0 12px 32px -12px rgba(...)`). Zero-offset colored neon halos are decoration — avoid on non-tech surfaces.

### Layout & Spacing Rhythm
- **Equal left and right container edges** across header, main sections, and footer.
- **Tight within groups, generous between groups:** always more vertical space *above* a section heading than *below* it (`margin-top > margin-bottom`).
- **One primary focus per screen:** avoid cramming multiple competing hero widgets or headers peeking at the bottom edge of `1440×900`.
- **Responsive down to `390px`:** zero horizontal overflow (`scrollWidth <= innerWidth`), stacked single-column fallbacks on mobile without clipped tables or code blocks.

### Typography
- Body line length between **55–75ch** (`max-width: 65ch`).
- Clear scale jump between display `h1`, section `h2`, card/block `h3`, and body (`16px` minimum for readable lists/prose).
- `font-variant-numeric: tabular-nums` on all prices, timestamps, latencies, counters, and table columns.
- `text-wrap: balance` on headings, `text-wrap: pretty` on paragraphs.

### Motion & Interaction States
- **One authored focal moment** (e.g., an interactive live preview or crisp initial hero load) — not scattered gimmicks.
- Interactive elements lift or step subtly on `:hover` (`translateY(-1px)` / border contrast) and compress cleanly on `:active`.
- Always define `:hover`, `:focus-visible`, `:active`, `:disabled`, plus empty/error/loading states when applicable.
- Always wrap animations in `@media (prefers-reduced-motion: reduce)`.

### Browser Surfaces (Always Theme These)
- `::selection` (brand accent tint + high-contrast text)
- `:focus-visible` (`2px solid` accent ring with `2px` offset)
- `caret-color` on inputs
- `text-underline-offset: 0.2em` on text links
- Subtle styled scrollbars (`scrollbar-width: thin; scrollbar-color: ...`)
