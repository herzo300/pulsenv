---
name: kill-ai-slop
description: >-
  Find and remove AI slop — the generic, machine-default visual and copy tics of
  vibe-coded products — from a web project. Use when the user asks to "kill AI
  slop", "de-slop", "remove the AI look", "make this not look AI-generated", or
  clean up a landing page / UI / docs that feels templated. Detects and fixes
  the catalogue of tells: indigo→violet gradients, gradient-clip headlines, the
  default semantic palette, one-hue status boxes, atmospheric gradients,
  serif-italic emphasis, highlighted keywords, AI copywriting voice ("not just
  X — it's Y"), emoji everywhere, glowing status dots, colored-left-border
  callouts, pastel icon tiles, glassmorphism, over-rounding, oversized shadows,
  borders that die at corners, badge & pill spam, AI-drawn SVG icons, kickers
  over every heading, flat type
  hierarchies, invented stat rows (10k+ / 99.9% / 24/7), 01/02/03 section
  markers, cards nested in cards, the default Inter/Space Grotesk look, and
  more. Works on HTML/CSS, React/Vue/Svelte/Astro, Tailwind, and Markdown copy.
---

# Kill AI Slop

AI slop is **ugly** in a specific way: it piles on every possible style and
detail without settling on a focus. A gradient, a glow, a mascot, emoji, a wall
of glowing cards, every default switched on at once, until every product looks
like the same garish template. It reads as "designed" in a thumbnail and falls
apart the moment anyone looks. Your job is to strip it back to something a
person would actually choose.

The principles, held on every fix you make:

1. **Decide before you decorate.** Every visual choice must be explainable.
2. **One accent, one voice.**
3. **Hierarchy from scale and space.** Coloring words or swapping fonts is a shortcut.
4. **Subtract first.** The first move toward not-ugly is removing things.
5. **Specific beats punchy** in copy.
6. **Decoration must mean something** — icons, badges, callouts are signals.

## Workflow

Follow these steps in order. Do not mass-edit before the user has seen the report.

### 1. Scope
Confirm what to scan. Default to the app/site source (skip `node_modules`,
`dist`, `build`, `.git`, `vendor`, lockfiles, minified files). Ask if the
project mixes several apps.

### 2. Scan
Run the bundled scanner, which greps the codebase for the code-level signals of
each tell and prints grouped `file:line` hits:

```
node scripts/scan.mjs <root>          # human-readable report
node scripts/scan.mjs <root> --json   # machine-readable, for triage
```

It is pure Node (no dependencies) and never edits files. Use its output.
