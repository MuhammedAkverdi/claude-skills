# Browser Gate, Critique & Polish Reference

Use this during **Stage 5 (Real-Browser Gate)** and whenever invoked with **`critique`**, **`polish`**, or **`audit`**.

---

## 1. Automated browser DOM & Style Audit (`javascript_tool`)

Run this at both **`1440×900` (desktop)** and **`390×844` (mobile)** with `javascript_tool` (built-in browser or Claude in Chrome) — wrap it as `(() => { ... })()`:

```js
() => {
  const vw = window.innerWidth;
  const vh = window.innerHeight;
  const sw = document.documentElement.scrollWidth;
  const sh = document.documentElement.scrollHeight;

  const imgs = [...document.querySelectorAll('img')];
  const brokenImages = imgs.filter(i => !i.complete || i.naturalWidth === 0).map(i => i.src || i.alt);
  const missingAlt = imgs.filter(i => !i.hasAttribute('alt')).length;

  const overflowEls = [...document.querySelectorAll('body *')]
    .filter(el => {
      const r = el.getBoundingClientRect();
      const cs = getComputedStyle(el);
      return cs.display !== 'none' && cs.visibility !== 'hidden' && r.width > 0 && r.right > vw + 2;
    })
    .slice(0, 8)
    .map(el => `${el.tagName.toLowerCase()}${el.className ? '.' + String(el.className).trim().split(/\s+/).join('.') : ''} (right=${Math.round(el.getBoundingClientRect().right)} > ${vw})`);

  const interactive = [...document.querySelectorAll('a, button, input, select, textarea, [role="button"], [role="tab"]')];
  const smallTargets = vw <= 480
    ? interactive.filter(el => {
        const r = el.getBoundingClientRect();
        const cs = getComputedStyle(el);
        return cs.display !== 'none' && r.width > 0 && r.height > 0 && (r.height < 40 || r.width < 40);
      }).slice(0, 8).map(el => `${el.tagName.toLowerCase()}:${(el.innerText || el.getAttribute('aria-label') || '').trim().slice(0, 24)} (${Math.round(el.getBoundingClientRect().width)}x${Math.round(el.getBoundingClientRect().height)})`)
    : [];

  const h1 = document.querySelector('h1');
  const h1Style = h1 ? getComputedStyle(h1) : null;
  const bodyStyle = getComputedStyle(document.body);
  const loadedFonts = [...document.fonts].filter(f => f.status === 'loaded').map(f => `${f.family}:${f.weight}`);

  return {
    viewport: `${vw}x${vh}`,
    scrollSize: `${sw}x${sh}`,
    horizontalOverflow: sw > vw + 1,
    overflowEls,
    imageCount: imgs.length,
    brokenImages,
    missingAlt,
    smallMobileTapTargets: smallTargets,
    h1Font: h1Style ? `${h1Style.fontFamily} @ ${h1Style.fontSize}` : 'none',
    bodyFont: `${bodyStyle.fontFamily} @ ${bodyStyle.fontSize}`,
    loadedFonts: [...new Set(loadedFonts)]
  };
}
```

---

## 2. Cognitive Load Checklist (Target: ≤ 1 Failure)

Evaluate the rendered screenshots against Cowan's `≤ 4` working-memory rule:

- [ ] **Single focus:** Is the primary purpose and action unmistakable in the first 3 seconds?
- [ ] **Chunking (≤ 4 items):** Are nav items, feature groups, and action clusters kept concise (`≤ 4–5` per group)?
- [ ] **Visual grouping:** Are related controls tightly grouped and distinct zones separated cleanly?
- [ ] **Visual hierarchy:** Do size, weight, and contrast clearly separate primary, secondary, and metadata levels?
- [ ] **One decision at a time:** Does the user avoid facing competing CTAs or dense control walls simultaneously?
- [ ] **Minimal choices:** Are filter/tab/action bars limited without redundant duplicates?
- [ ] **Zero cross-screen memory:** Are active states, selected filters, and feedback visible right where the user looks?
- [ ] **Progressive disclosure:** Are secondary details revealed on selection/hover/expand instead of dumped upfront?

---

## 3. P0–P3 Triage Order (Polish Pass)

Always fix defects in strict priority order:

- **P0 — Critical / Broken:** Horizontal overflow (`scrollWidth > innerWidth`), clipped text, overlapping elements, broken images, unreadable contrast, dead/non-responsive interactive buttons, console errors.
- **P1 — Hierarchy & Responsive Drift:** Mobile tap targets `< 40–44px`, uneven left/right container edges, cramped heading margins, poor above-the-fold framing on `1440×900`, missing active/focus states.
- **P2 — Visual & Copy Polish:** Excess decorative badges/eyebrows, weak hover micro-interactions, non-tabular numbers jumping width, vague CTA labels, inconsistent border radii.
- **P3 — Cleanup:** Dead CSS rules, redundant wrapper elements, unused scripts.

**Rule:** `polish` preserves the committed visual world and fixes defects; if the visual concept itself is generic or wrong for the brief, recommend a `redesign` instead.
