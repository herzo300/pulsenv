---
design-system:
  name: "City Pulse Design Tokens"
  version: "1.0.0"
  description: "Единая дизайн-система для City Pulse (Soobshio) — Нижневартовск"
tokens:
  colors:
    background:
      default: "#020617"
      raised: "#08111F"
      light: "#F5FAFF"
      lightRaised: "#E8F2FB"
    surface:
      default: "#0C1628"
      soft: "#112036"
      elevated: "#16263D"
      glass: "#CC111C31"
      light: "#FFFFFF"
      lightSoft: "#F0F6FC"
      lightGlass: "#CCFFFFFF"
    text:
      primary: "#E6FAFF"
      secondary: "#8EAFC2"
      tertiary: "#66849A"
      lightPrimary: "#0A2540"
      lightSecondary: "#4A6B8A"
      lightTertiary: "#7A96B2"
    primary:
      default: "#00E5FF"
      soft: "#7DF2FF"
      deep: "#0EA5C7"
    accent:
      violet: "#7C4DFF"
      gold: "#FFC857"
    semantic:
      success: "#00E676"
      warning: "#FFC857"
      negative: "#FF3D00"
      neutral: "#90A4AE"
    border:
      default: "#223FD8F8"
      strong: "#443FD8F8"
      light: "#330EA5C7"
      lightStrong: "#660EA5C7"
  spacing:
    xs: 4
    sm: 8
    md: 12
    lg: 16
    xl: 24
    xxl: 32
  typography:
    fontFamily: "Outfit, Inter, sans-serif"
    sizes:
      xs: 10
      sm: 12
      md: 14
      lg: 16
      xl: 18
      xxl: 24
---

# City Pulse (Soobshio) Design Specification

Living source of truth for the City Pulse application's visual identity.

## Visual & Theme Rules

1. **Contrast & Themes**: 
   - All colors are mapped to dark and light modes.
   - Text elements must utilize `textPrimary` or `lightTextPrimary` respectively to guarantee WCAG AA visibility.
   - Accents must use our signature Cyber Cyan (`#00E5FF`) on dark backgrounds and Deep Cyan (`#0EA5C7`) on light backgrounds.

2. **Structure & Grid**:
   - Layout grids and spacing metrics must be multiples of 4px. Use token values `xs` (4px), `sm` (8px), `md` (12px), `lg` (16px), `xl` (24px), `xxl` (32px).
   - Component surfaces should use smooth circular radius of 8px, 12px, or 16px.

3. **Motion**:
   - UI animations (e.g. atmospheric effects) should be subtle, running at 300ms durations using standard Ease-In-Out timing.
