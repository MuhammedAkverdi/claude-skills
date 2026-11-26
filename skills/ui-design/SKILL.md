---
name: ui-design
description: >-
  Hybrid anti-slop frontend & UI design skill combining art direction, a two-pass design thesis
  (swap test), craft floor rules, real-browser visual verification and cognitive-load critique/polish.
  Use whenever building, designing, redesigning, auditing, critiquing or polishing a web page,
  landing page, SaaS UI, dashboard, component, form or app interface — or when the user says
  "UI tasarla", "arayüz yap", "landing page", "dashboard", "tasarımı güzelleştir", "redesign",
  "polish", "critique", "audit", "AI gibi görünüyor", "make it look professional".
---

# UI Design — Hybrid Anti-Slop & Visual Gate Skill

Build interfaces that look authored for one specific product and audience — never generic AI templates. Combines art-direction discipline, a two-pass design thesis, and craft floor + critique/polish rigor.

## Claude Code tool mapping

- **Pre-brief & decisions:** `AskUserQuestion` (recommended option first, marked "(Recommended)").
- **Real-browser verification** — either browser works:
  - **Built-in browser pane** (`mcp__Claude_Browser__*`): `preview_start` (dev server from `.claude/launch.json`, or `url` for a `file:///` page), `resize_window` (`width`/`height`, or `preset: "mobile"` = 375×812 / `"desktop"` to reset), `computer` `screenshot`, `javascript_tool`, `read_console_messages`, `computer` `left_click`.
  - **Claude in Chrome** (`mcp__claude-in-chrome__*`, load them in one ToolSearch call): `tabs_create_mcp` + `navigate`, `resize_window`, `computer` `screenshot`, `javascript_tool`, `read_console_messages`, `tabs_close_mcp`.
- **Visual inspection:** look at the screenshots (or save them and `Read` the PNG). Always inspect desktop **1440×900** and mobile **390×844**.
- **Audit script:** the function in [references/critique-and-polish.md](references/critique-and-polish.md) is written as `() => {...}`; in `javascript_tool` run it as `(() => {...})()`.
- **Bespoke imagery:** invoke the **`gemini-image`** skill (Google Flow, Nano Banana Pro, 0 credits) when the design needs real photography or custom brand artwork the user didn't provide.

---

## 0. Classify Surface Mode & Business Kind (first step)

Declare both on line 1 of your design plan before writing any code:

| Surface Mode | Visitor's goal | Design commitment |
|---|---|---|
| **Persuade** | Decide and act (landing pages, marketing, pricing, launches) | Bold POV, strong visual anchor, clear primary CTA |
| **Operate** | Complete tasks reliably (dashboards, SaaS apps, editors, admin, settings) | Scanability, legibility, consistent controls, restraint |
| **Read** | Understand content (docs, articles, guides, changelogs) | Clean reading measure (`65–75ch`), typographic calm |
| **Experience** | Immerse in the work (portfolios, galleries, showcases) | Artifact leads from the first viewport; chrome recedes |

And classify the **Business Kind** to enforce the **tech-only effects rule**:
- **Tech (`software`, `gaming`, `hardware`):** live HTML product UI (real interactive screens/diffs/tables, never fake gray boxes), pulsing diagrams, dark modes and subtle WebGL/CSS atmospheres are allowed where justified.
- **Non-tech (`place`, `product`, `service`):** cafes, restaurants, hotels, shops, clinics, agencies, physical goods. **No dark-neon tech effects, no shaders, no pulsing network diagrams.** Lead with real photography (`gemini-image` or user photos), flat tactile surfaces and disciplined typography.

---

## 1. Sub-commands (routing)

- **Default (new build / redesign):** full 5-stage pipeline (`Brief → Two-Pass Thesis → Build → Browser Gate → Critique & Polish`).
- **`critique [target]`:** load [references/critique-and-polish.md](references/critique-and-polish.md), run the browser DOM & screenshot inspection, deliver a P0–P3 + cognitive-load review without rewriting the visual world.
- **`polish [target]`:** load both references; fix functional, spacing, contrast, responsive and state defects while preserving the incumbent identity.
- **`bolder` / `quieter`:** shift visual intensity (type contrast, surface tension, color weight, motion) up or down intentionally.
- **`audit [target]`:** run the browser DOM, accessibility, console and responsive audit only.

---

## 2. Pre-brief (skip if detailed or the user says "hızlıca" / "direkt" / "test")

For a short 1–2 sentence request, ask **at most 3 short questions** in ONE `AskUserQuestion` call, in the user's language:
1. **Hedef & yüzey:** Landing page (`Persuade`) / Uygulama & dashboard (`Operate`) / Portföy (`Experience`)
2. **Görsel dünya & ton:** Açık editoryal & teknik / Koyu yüksek kontrast / Sıcak doğal & fotoğraf odaklı / Marka renklerine göre
3. **Görsel kaynağı:** `gemini-image` ile özel görseller üret / Mevcut görselleri kullan / Canlı interaktif HTML arayüzü

---

## 3. Two-Pass Design Thesis (anti-slop swap test)

Never jump straight into HTML/CSS. Write a compact plan first:

1. **Pass 1 — Design plan:**
   - **Mode & kind:** e.g. `Persuade / software`
   - **Palette (4–6 named hex tokens):** background, surface, primary ink, muted ink, primary accent, semantic status.
   - **Typography (1–2 intentional families):** display/body + monospace (if data/code), explicit scale & `tabular-nums` for numbers.
   - **Layout wireframe (ASCII):** clear grid, alignment rule, **one primary action** per viewport.
   - **ONE authored focal moment:** a live interactive product widget, a commanding typographic/photographic hero, or one orchestrated entrance/interaction — never scattered animations everywhere.
2. **Pass 2 — Anti-slop swap test (mandatory):** check Pass 1 against the **2026 AI-slop tells** in [references/craft-floor.md](references/craft-floor.md) (warm cream + terracotta default, near-black + neon/purple glow, 3 identical icon cards, ALL-CAPS eyebrows over every heading, `01/02/03` on non-sequences, gradient text, single italic/colored word in h1, `→` on every button). If any free axis fell back to a cliché, **revise it explicitly before coding**.

---

## 4. Build rules

**ALWAYS read [references/craft-floor.md](references/craft-floor.md) before writing UI code.**
- **Real content & active UX copy:** no Lorem Ipsum. Domain-authentic copy in the user's language. CTAs name verb + object (*"Kayıtları filtrele"*, *"Projeyi başlat"* — not *"Submit"*). Error/empty states say what happened and how to recover.
- **Responsive & accessible floor:** fluid down to `390px` (no horizontal overflow), visible `:focus-visible` rings, `44×44px` tap targets on mobile, semantic landmarks, `prefers-reduced-motion` support.
- **Browser surfaces:** theme `::selection`, `caret-color`, `:focus-visible`, scrollbars, `text-underline-offset`, `font-variant-numeric: tabular-nums`.
- **Project-native:** match the repo's stack (React/Next/Tailwind/Svelte or standalone semantic HTML/CSS/JS). Keep CSS specificity clean.

---

## 5. Mandatory real-browser gate & polish loop

Every UI deliverable MUST be verified in a real browser before presenting it:

1. **Open it:** dev server URL (`http://localhost:...`) or the static `file:///...` page.
2. **Desktop gate (1440×900):** `resize_window` to 1440×900 → run the DOM & style audit script with `javascript_tool` → click the interactive controls (tabs, filters, drawers, forms) and confirm real state changes → `read_console_messages` must show zero errors → screenshot and inspect it.
3. **Mobile gate (390×844):** `resize_window` to 390×844 (or the mobile preset) → re-run the audit (`scrollWidth <= innerWidth`, tap targets, readable font sizes) → screenshot and inspect it.
4. **Critique & polish:** review both screenshots against [references/critique-and-polish.md](references/critique-and-polish.md) (P0–P3 + cognitive load). Fix every P0/P1, re-verify the affected view, reset the window size (`preset: "desktop"`), close tabs you opened.

## Rules

- Never claim a UI looks good without inspecting the rendered desktop and mobile screenshots.
- Never invent broken external image URLs (random Unsplash links that 404); verify `naturalWidth > 0` in the browser or generate real assets with `gemini-image`.
- Report honestly what the browser gate checked and what the polish pass fixed.
