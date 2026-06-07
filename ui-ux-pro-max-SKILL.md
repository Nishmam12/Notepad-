---
name: ui-ux-pro-max
description: >
  UI/UX design intelligence for web and mobile. Includes 50+ styles, 161 color
  palettes, 57 font pairings, 161 product types, 99 UX guidelines, and 25 chart
  types across 10 stacks (React, Next.js, Vue, Svelte, SwiftUI, React Native,
  Flutter, Tailwind, shadcn/ui, and HTML/CSS). Actions: plan, build, create,
  design, implement, review, fix, improve, optimize, enhance, refactor, and
  check UI/UX code. Projects: website, landing page, dashboard, admin panel,
  e-commerce, SaaS, portfolio, blog, and mobile app. Elements: button, modal,
  navbar, sidebar, card, table, form, and chart. Styles: glassmorphism,
  claymorphism, minimalism, brutalism, neumorphism, bento grid, dark mode,
  responsive, skeuomorphism, and flat design. Topics: color systems,
  accessibility, animation, layout, typography, font pairing, spacing,
  interaction states, shadow, and gradient.
---

# UI/UX Pro Max — Design Intelligence

Comprehensive design guide for web and mobile applications. Contains 50+ styles, 161 color palettes, 57 font pairings, 161 product types with reasoning rules, 99 UX guidelines, and 25 chart types across 10 technology stacks. Searchable database with priority-based recommendations.

Source: https://github.com/nextlevelbuilder/ui-ux-pro-max-skill (v2.5.0)

## When to Apply

This Skill should be used when the task involves **UI structure, visual design decisions, interaction patterns, or user experience quality control**.

### Must Use

- Designing new pages (Landing Page, Dashboard, Admin, SaaS, Mobile App)
- Creating or refactoring UI components (buttons, modals, forms, tables, charts, etc.)
- Choosing color schemes, typography systems, spacing standards, or layout systems
- Reviewing UI code for user experience, accessibility, or visual consistency
- Implementing navigation structures, animations, or responsive behavior
- Making product-level design decisions (style, information hierarchy, brand expression)
- Improving perceived quality, clarity, or usability of interfaces

### Recommended

- UI looks "not professional enough" but the reason is unclear
- Receiving feedback on usability or experience
- Pre-launch UI quality optimization
- Aligning cross-platform design (Web / iOS / Android)
- Building design systems or reusable component libraries

### Skip

- Pure backend logic development
- Only involving API or database design
- Performance optimization unrelated to the interface
- Infrastructure or DevOps work
- Non-visual scripts or automation tasks

**Decision criteria**: If the task will change how a feature **looks, feels, moves, or is interacted with**, this Skill should be used.

---

## Rule Categories by Priority

| Priority | Category | Impact | Key Checks (Must Have) | Anti-Patterns (Avoid) |
|---|---|---|---|---|
| 1 | Accessibility | CRITICAL | Contrast 4.5:1, Alt text, Keyboard nav, Aria-labels | Removing focus rings, Icon-only buttons without labels |
| 2 | Touch & Interaction | CRITICAL | Min size 44×44px, 8px+ spacing, Loading feedback | Reliance on hover only, Instant state changes (0ms) |
| 3 | Performance | HIGH | WebP/AVIF, Lazy loading, Reserve space (CLS < 0.1) | Layout thrashing, Cumulative Layout Shift |
| 4 | Style Selection | HIGH | Match product type, Consistency, SVG icons (no emoji) | Mixing flat & skeuomorphic randomly, Emoji as icons |
| 5 | Layout & Responsive | HIGH | Mobile-first breakpoints, Viewport meta, No horizontal scroll | Horizontal scroll, Fixed px container widths, Disable zoom |
| 6 | Typography & Color | MEDIUM | Base 16px, Line-height 1.5, Semantic color tokens | Text < 12px body, Gray-on-gray, Raw hex in components |
| 7 | Animation | MEDIUM | Duration 150–300ms, Motion conveys meaning, Spatial continuity | Decorative-only animation, Animating width/height, No reduced-motion |
| 8 | Forms & Feedback | MEDIUM | Visible labels, Error near field, Helper text, Progressive disclosure | Placeholder-only label, Errors only at top, Overwhelm upfront |
| 9 | Navigation Patterns | HIGH | Predictable back, Bottom nav ≤5, Deep linking | Overloaded nav, Broken back behavior, No deep links |
| 10 | Charts & Data | LOW | Legends, Tooltips, Accessible colors | Relying on color alone to convey meaning |

---

## Quick Reference

### 1. Accessibility (CRITICAL)

- `color-contrast` — Minimum 4.5:1 ratio for normal text (large text 3:1)
- `focus-states` — Visible focus rings on interactive elements (2–4px)
- `alt-text` — Descriptive alt text for meaningful images
- `aria-labels` — aria-label for icon-only buttons
- `keyboard-nav` — Tab order matches visual order; full keyboard support
- `form-labels` — Use label with for attribute
- `skip-links` — Skip to main content for keyboard users
- `heading-hierarchy` — Sequential h1→h6, no level skip
- `color-not-only` — Don't convey info by color alone (add icon/text)
- `dynamic-type` — Support system text scaling; avoid truncation as text grows
- `reduced-motion` — Respect prefers-reduced-motion; reduce/disable animations when requested
- `voiceover-sr` — Meaningful accessibilityLabel/accessibilityHint; logical reading order
- `escape-routes` — Provide cancel/back in modals and multi-step flows
- `keyboard-shortcuts` — Preserve system and a11y shortcuts; offer keyboard alternatives for drag-and-drop
- `touch-target-size` — Min 44×44pt (Apple) / 48×48dp (Material); extend hit area beyond visual bounds if needed

### 2. Touch & Interaction (CRITICAL)

- `touch-target-size` — Min 44×44pt (Apple) / 48×48dp (Material)
- `touch-spacing` — Minimum 8px/8dp gap between touch targets
- `hover-vs-tap` — Use click/tap for primary interactions; don't rely on hover alone
- `loading-buttons` — Disable button during async operations; show spinner or progress
- `error-feedback` — Clear error messages near problem
- `cursor-pointer` — Add cursor-pointer to clickable elements (Web)
- `gesture-conflicts` — Avoid horizontal swipe on main content; prefer vertical scroll
- `tap-delay` — Use touch-action: manipulation to reduce 300ms delay (Web)
- `standard-gestures` — Use platform standard gestures consistently
- `press-feedback` — Visual feedback on press (ripple/highlight)
- `haptic-feedback` — Use haptic for confirmations and important actions; avoid overuse
- `gesture-alternative` — Don't rely on gesture-only interactions; always provide visible controls
- `safe-area-awareness` — Keep primary touch targets away from notch, Dynamic Island, gesture bar and screen edges
- `no-precision-required` — Avoid requiring pixel-perfect taps on small icons or thin edges
- `swipe-clarity` — Swipe actions must show clear affordance or hint
- `drag-threshold` — Use a movement threshold before starting drag to avoid accidental drags

### 3. Performance (HIGH)

- `image-optimization` — Use WebP/AVIF, responsive images (srcset/sizes), lazy load non-critical assets
- `image-dimension` — Declare width/height or use aspect-ratio to prevent layout shift (CLS)
- `font-loading` — Use font-display: swap/optional to avoid invisible text (FOIT)
- `font-preload` — Preload only critical fonts; avoid overusing preload on every variant
- `critical-css` — Prioritize above-the-fold CSS
- `lazy-loading` — Lazy load non-hero components via dynamic import / route-level splitting
- `bundle-splitting` — Split code by route/feature to reduce initial load and TTI
- `third-party-scripts` — Load third-party scripts async/defer; audit and remove unnecessary ones
- `reduce-reflows` — Avoid frequent layout reads/writes; batch DOM reads then writes
- `content-jumping` — Reserve space for async content to avoid layout jumps
- `virtualize-lists` — Virtualize lists with 50+ items to improve memory efficiency and scroll performance
- `main-thread-budget` — Keep per-frame work under ~16ms for 60fps
- `progressive-loading` — Use skeleton screens / shimmer instead of long blocking spinners for >1s operations
- `input-latency` — Keep input latency under ~100ms for taps/scrolls
- `tap-feedback-speed` — Provide visual feedback within 100ms of tap
- `debounce-throttle` — Use debounce/throttle for high-frequency events (scroll, resize, input)
- `offline-support` — Provide offline state messaging and basic fallback (PWA / mobile)
- `network-fallback` — Offer degraded modes for slow networks

### 4. Style Selection (HIGH)

- `style-match` — Match style to product type
- `consistency` — Use same style across all pages
- `no-emoji-icons` — Use SVG icons (Heroicons, Lucide), not emojis
- `color-palette-from-product` — Choose palette from product/industry
- `effects-match-style` — Shadows, blur, radius aligned with chosen style
- `platform-adaptive` — Respect platform idioms (iOS HIG vs Material)
- `state-clarity` — Make hover/pressed/disabled states visually distinct
- `elevation-consistent` — Use a consistent elevation/shadow scale
- `dark-mode-pairing` — Design light/dark variants together
- `icon-style-consistent` — Use one icon set/visual language across the product
- `system-controls` — Prefer native/system controls over fully custom ones
- `blur-purpose` — Use blur to indicate background dismissal, not as decoration
- `primary-action` — Each screen should have only one primary CTA

### 5. Layout & Responsive (HIGH)

- `viewport-meta` — width=device-width initial-scale=1 (never disable zoom)
- `mobile-first` — Design mobile-first, then scale up to tablet and desktop
- `breakpoint-consistency` — Use systematic breakpoints (375 / 768 / 1024 / 1440)
- `readable-font-size` — Minimum 16px body text on mobile (avoids iOS auto-zoom)
- `line-length-control` — Mobile 35–60 chars per line; desktop 60–75 chars
- `horizontal-scroll` — No horizontal scroll on mobile
- `spacing-scale` — Use 4pt/8dp incremental spacing system
- `touch-density` — Keep component spacing comfortable for touch
- `container-width` — Consistent max-width on desktop (max-w-6xl / 7xl)
- `z-index-management` — Define layered z-index scale (0 / 10 / 20 / 40 / 100 / 1000)
- `fixed-element-offset` — Fixed navbar/bottom bar must reserve safe padding for underlying content
- `scroll-behavior` — Avoid nested scroll regions that interfere with the main scroll experience
- `viewport-units` — Prefer min-h-dvh over 100vh on mobile
- `orientation-support` — Keep layout readable and operable in landscape mode
- `content-priority` — Show core content first on mobile; fold or hide secondary content
- `visual-hierarchy` — Establish hierarchy via size, spacing, contrast — not color alone

### 6. Typography & Color (MEDIUM)

- `line-height` — Use 1.5-1.75 for body text
- `line-length` — Limit to 65-75 characters per line
- `font-pairing` — Match heading/body font personalities
- `font-scale` — Consistent type scale (e.g. 12 14 16 18 24 32)
- `contrast-readability` — Darker text on light backgrounds (e.g. slate-900 on white)
- `text-styles-system` — Use platform type system (iOS Dynamic Type / Material type roles)
- `weight-hierarchy` — Bold headings (600–700), Regular body (400), Medium labels (500)
- `color-semantic` — Define semantic color tokens (primary, secondary, error, surface, on-surface)
- `color-dark-mode` — Dark mode uses desaturated / lighter tonal variants, not inverted colors
- `color-accessible-pairs` — Foreground/background pairs must meet 4.5:1 (AA) or 7:1 (AAA)
- `color-not-decorative-only` — Functional color (error red, success green) must include icon/text
- `truncation-strategy` — Prefer wrapping over truncation; when truncating use ellipsis and provide full text via tooltip
- `letter-spacing` — Respect default letter-spacing per platform; avoid tight tracking on body text
- `number-tabular` — Use tabular/monospaced figures for data columns, prices, and timers
- `whitespace-balance` — Use whitespace intentionally to group related items and separate sections

### 7. Animation (MEDIUM)

- `duration-timing` — Use 150–300ms for micro-interactions; complex transitions ≤400ms
- `transform-performance` — Use transform/opacity only; avoid animating width/height/top/left
- `loading-states` — Show skeleton or progress indicator when loading exceeds 300ms
- `excessive-motion` — Animate 1-2 key elements per view max
- `easing` — Use ease-out for entering, ease-in for exiting; avoid linear for UI transitions
- `motion-meaning` — Every animation must express a cause-effect relationship, not just be decorative
- `state-transition` — State changes should animate smoothly, not snap
- `continuity` — Page/screen transitions should maintain spatial continuity
- `parallax-subtle` — Use parallax sparingly; must respect reduced-motion
- `spring-physics` — Prefer spring/physics-based curves over linear or cubic-bezier for natural feel
- `exit-faster-than-enter` — Exit animations shorter than enter (~60–70% of enter duration)
- `stagger-sequence` — Stagger list/grid item entrance by 30–50ms per item
- `shared-element-transition` — Use shared element / hero transitions for visual continuity between screens
- `interruptible` — Animations must be interruptible; user tap/gesture cancels in-progress animation immediately
- `no-blocking-animation` — Never block user input during an animation
- `fade-crossfade` — Use crossfade for content replacement within the same container
- `scale-feedback` — Subtle scale (0.95–1.05) on press for tappable cards/buttons
- `gesture-feedback` — Drag, swipe, and pinch must provide real-time visual response tracking the finger
- `hierarchy-motion` — Use translate/scale direction to express hierarchy
- `motion-consistency` — Unify duration/easing tokens globally
- `opacity-threshold` — Fading elements should not linger below opacity 0.2
- `modal-motion` — Modals/sheets should animate from their trigger source for spatial context
- `navigation-direction` — Forward navigation animates left/up; backward animates right/down
- `layout-shift-avoid` — Animations must not cause layout reflow or CLS

### 8. Forms & Feedback (MEDIUM)

- `input-labels` — Visible label per input (not placeholder-only)
- `error-placement` — Show error below the related field
- `submit-feedback` — Loading then success/error state on submit
- `required-indicators` — Mark required fields (e.g. asterisk)
- `empty-states` — Helpful message and action when no content
- `toast-dismiss` — Auto-dismiss toasts in 3-5s
- `confirmation-dialogs` — Confirm before destructive actions
- `input-helper-text` — Provide persistent helper text below complex inputs
- `disabled-states` — Disabled elements use reduced opacity (0.38–0.5) + cursor change + semantic attribute
- `progressive-disclosure` — Reveal complex options progressively; don't overwhelm users upfront
- `inline-validation` — Validate on blur (not keystroke); show error only after user finishes input
- `input-type-keyboard` — Use semantic input types (email, tel, number) to trigger the correct mobile keyboard
- `password-toggle` — Provide show/hide toggle for password fields
- `autofill-support` — Use autocomplete / textContentType attributes
- `undo-support` — Allow undo for destructive or bulk actions
- `success-feedback` — Confirm completed actions with brief visual feedback
- `error-recovery` — Error messages must include a clear recovery path (retry, edit, help link)
- `multi-step-progress` — Multi-step flows show step indicator or progress bar; allow back navigation
- `form-autosave` — Long forms should auto-save drafts to prevent data loss
- `sheet-dismiss-confirm` — Confirm before dismissing a sheet/modal with unsaved changes
- `error-clarity` — Error messages must state cause + how to fix (not just "Invalid input")
- `field-grouping` — Group related fields logically
- `focus-management` — After submit error, auto-focus the first invalid field
- `error-summary` — For multiple errors, show summary at top with anchor links to each field
- `touch-friendly-input` — Mobile input height ≥44px
- `destructive-emphasis` — Destructive actions use semantic danger color (red) and are visually separated
- `toast-accessibility` — Toasts must not steal focus; use aria-live="polite" for screen reader announcement
- `aria-live-errors` — Form errors use aria-live region or role="alert"
- `contrast-feedback` — Error and success state colors must meet 4.5:1 contrast ratio
- `timeout-feedback` — Request timeout must show clear feedback with retry option

### 9. Navigation Patterns (HIGH)

- `bottom-nav-limit` — Bottom navigation max 5 items; use labels with icons
- `drawer-usage` — Use drawer/sidebar for secondary navigation, not primary actions
- `back-behavior` — Back navigation must be predictable and consistent; preserve scroll/state
- `deep-linking` — All key screens must be reachable via deep link / URL
- `tab-bar-ios` — iOS: use bottom Tab Bar for top-level navigation
- `top-app-bar-android` — Android: use Top App Bar with navigation icon for primary structure
- `nav-label-icon` — Navigation items must have both icon and text label
- `nav-state-active` — Current location must be visually highlighted in navigation
- `nav-hierarchy` — Primary nav vs secondary nav must be clearly separated
- `modal-escape` — Modals and sheets must offer a clear close/dismiss affordance
- `search-accessible` — Search must be easily reachable; provide recent/suggested queries
- `breadcrumb-web` — Web: use breadcrumbs for 3+ level deep hierarchies
- `state-preservation` — Navigating back must restore previous scroll position, filter state, and input
- `gesture-nav-support` — Support system gesture navigation (iOS swipe-back, Android predictive back)
- `tab-badge` — Use badges on nav items sparingly to indicate unread/pending
- `overflow-menu` — When actions exceed available space, use overflow/more menu
- `bottom-nav-top-level` — Bottom nav is for top-level screens only; never nest sub-navigation
- `adaptive-navigation` — Large screens (≥1024px) prefer sidebar; small screens use bottom/top nav
- `back-stack-integrity` — Never silently reset the navigation stack
- `navigation-consistency` — Navigation placement must stay the same across all pages
- `avoid-mixed-patterns` — Don't mix Tab + Sidebar + Bottom Nav at the same hierarchy level
- `modal-vs-navigation` — Modals must not be used for primary navigation flows
- `focus-on-route-change` — After page transition, move focus to main content region for screen reader users
- `persistent-nav` — Core navigation must remain reachable from deep pages
- `destructive-nav-separation` — Dangerous actions (delete account, logout) must be visually and spatially separated from normal nav items
- `empty-nav-state` — When a nav destination is unavailable, explain why instead of silently hiding it

### 10. Charts & Data (LOW)

- `chart-type` — Match chart type to data type (trend → line, comparison → bar, proportion → pie/donut)
- `color-guidance` — Use accessible color palettes; avoid red/green only pairs for colorblind users
- `data-table` — Provide table alternative for accessibility; charts alone are not screen-reader friendly
- `pattern-texture` — Supplement color with patterns, textures, or shapes so data is distinguishable without color
- `legend-visible` — Always show legend; position near the chart
- `tooltip-on-interact` — Provide tooltips/data labels on hover (Web) or tap (mobile) showing exact values
- `axis-labels` — Label axes with units and readable scale
- `responsive-chart` — Charts must reflow or simplify on small screens
- `empty-data-state` — Show meaningful empty state when no data exists
- `loading-chart` — Use skeleton or shimmer placeholder while chart data loads
- `animation-optional` — Chart entrance animations must respect prefers-reduced-motion
- `large-dataset` — For 1000+ data points, aggregate or sample; provide drill-down for detail
- `number-formatting` — Use locale-aware formatting for numbers, dates, currencies on axes and labels
- `touch-target-chart` — Interactive chart elements must have ≥44pt tap area or expand on touch
- `no-pie-overuse` — Avoid pie/donut for >5 categories; switch to bar chart for clarity
- `contrast-data` — Data lines/bars vs background ≥3:1; data text labels ≥4.5:1
- `legend-interactive` — Legends should be clickable to toggle series visibility
- `direct-labeling` — For small datasets, label values directly on the chart
- `tooltip-keyboard` — Tooltip content must be keyboard-reachable
- `sortable-table` — Data tables must support sorting with aria-sort
- `axis-readability` — Axis ticks must not be cramped; maintain readable spacing
- `data-density` — Limit information density per chart; split into multiple charts if needed
- `trend-emphasis` — Emphasize data trends over decoration
- `gridline-subtle` — Grid lines should be low-contrast (e.g. gray-200)
- `focusable-elements` — Interactive chart elements must be keyboard-navigable
- `screen-reader-summary` — Provide a text summary or aria-label describing the chart's key insight
- `error-state-chart` — Data load failure must show error message with retry action
- `export-option` — For data-heavy products, offer CSV/image export of chart data
- `drill-down-consistency` — Drill-down interactions must maintain a clear back-path
- `time-scale-clarity` — Time series charts must clearly label time granularity and allow switching

---

## Design System Workflow

### Step 1: Analyze User Requirements

Extract from the user's request:
- **Product type**: Entertainment, Tool, Productivity, E-commerce, SaaS, etc.
- **Target audience**: Consumer vs enterprise, age group, usage context
- **Style keywords**: playful, minimal, dark mode, content-first, immersive, etc.
- **Stack**: React, Next.js, Vue, Svelte, HTML+Tailwind, SwiftUI, React Native, Flutter, etc.

### Step 2: Generate Design System

Based on the product type and keywords, synthesize a complete design system with these components:

**Pattern** — Landing page or app layout structure (e.g. Hero-Centric + Social Proof)
- Conversion approach
- Section sequence (Hero → Features → Testimonials → CTA)

**Style** — Primary UI style from the 67 available (e.g. Soft UI Evolution, Glassmorphism)
- Visual keywords
- Best-fit industries
- Performance and accessibility ratings

**Colors** — Industry-appropriate palette
- Primary, Secondary, CTA, Background, Text values
- Mood and rationale notes

**Typography** — Font pairing
- Heading font + body font
- Mood descriptor
- Google Fonts import URL

**Key Effects** — Animations and interactions
- Shadow approach
- Transition timing
- Hover/press states

**Anti-Patterns to Avoid** — What NOT to do for this industry/style

**Pre-Delivery Checklist** — Quick final-check items

### Step 3: Apply Rules by Priority

Work through rule categories 1→10. Always address CRITICAL rules before HIGH, HIGH before MEDIUM.

### Step 4: Stack-Specific Implementation

Apply the correct conventions for the user's chosen stack:

| Stack | Key Conventions |
|---|---|
| HTML + Tailwind | Utility classes, mobile-first breakpoints, semantic HTML |
| React / Next.js | Component isolation, Server Components, React Suspense |
| shadcn/ui | Radix primitives, Tailwind variants, CVA for component variants |
| Vue / Nuxt.js | Composition API, Pinia state, auto-imports |
| Nuxt UI | Pre-built component library on top of Nuxt |
| Svelte / Astro | Island architecture, minimal JS, scoped styles |
| SwiftUI | iOS HIG, Dynamic Type, SF Symbols, safe areas |
| React Native | Platform-adaptive, StyleSheet, safe area insets |
| Flutter | Material 3 / Cupertino, adaptive widgets |
| Jetpack Compose | Material Design 3, state hoisting, accessibility semantics |
| Angular | Angular Material, OnPush change detection, reactive forms |
| Laravel | Blade/Livewire, Alpine.js, Tailwind |

---

## 67 UI Styles — Reference

### General Styles (49)
Minimalism & Swiss Style, Neumorphism, Glassmorphism, Brutalism, 3D & Hyperrealism, Vibrant & Block-based, Dark Mode (OLED), Accessible & Ethical, Claymorphism, Aurora UI, Retro-Futurism, Flat Design, Skeuomorphism, Liquid Glass, Motion-Driven, Micro-interactions, Inclusive Design, Zero Interface, Soft UI Evolution, Neubrutalism, Bento Box Grid, Y2K Aesthetic, Cyberpunk UI, Organic Biophilic, AI-Native UI, Memphis Design, Vaporwave, Dimensional Layering, Exaggerated Minimalism, Kinetic Typography, Parallax Storytelling, Swiss Modernism 2.0, HUD / Sci-Fi FUI, Pixel Art, Bento Grids, Spatial UI (VisionOS), E-Ink / Paper, Gen Z Chaos / Maximalism, Biomimetic / Organic 2.0, Anti-Polish / Raw Aesthetic, Tactile Digital / Deformable UI, Nature Distilled, Interactive Cursor Design, Voice-First Multimodal, 3D Product Preview, Gradient Mesh / Aurora Evolved, Editorial Grid / Magazine, Chromatic Aberration / RGB Split, Vintage Analog / Retro Film

### Landing Page Styles (8)
Hero-Centric Design, Conversion-Optimized, Feature-Rich Showcase, Minimal & Direct, Social Proof-Focused, Interactive Product Demo, Trust & Authority, Storytelling-Driven

### BI/Analytics Dashboard Styles (10)
Data-Dense Dashboard, Heat Map & Heatmap Style, Executive Dashboard, Real-Time Monitoring, Drill-Down Analytics, Comparative Analysis Dashboard, Predictive Analytics, User Behavior Analytics, Financial Dashboard, Sales Intelligence Dashboard

---

## Pre-Delivery Checklist

### Visual Quality
- [ ] No emojis used as icons (use SVG: Heroicons, Lucide)
- [ ] All icons come from a consistent icon family and style
- [ ] Official brand assets used with correct proportions
- [ ] Pressed-state visuals do not shift layout bounds
- [ ] Semantic theme tokens used consistently (no ad-hoc hardcoded colors)

### Interaction
- [ ] All tappable elements provide clear pressed feedback
- [ ] Touch targets meet minimum size (≥44×44pt iOS, ≥48×48dp Android)
- [ ] Micro-interaction timing stays in the 150–300ms range
- [ ] Disabled states are visually clear and non-interactive
- [ ] Screen reader focus order matches visual order

### Light/Dark Mode
- [ ] Primary text contrast ≥4.5:1 in both light and dark mode
- [ ] Secondary text contrast ≥3:1 in both light and dark mode
- [ ] Dividers/borders and interaction states are distinguishable in both modes
- [ ] Both themes are tested before delivery

### Layout
- [ ] Safe areas respected for headers, tab bars, and bottom CTA bars
- [ ] Scroll content not hidden behind fixed/sticky bars
- [ ] Verified on 375px, 768px, 1024px, 1440px + landscape
- [ ] 4/8dp spacing rhythm maintained across component, section, and page levels
- [ ] `cursor-pointer` on all clickable elements

### Accessibility
- [ ] All meaningful images/icons have accessibility labels
- [ ] Form fields have labels, hints, and clear error messages
- [ ] Color is not the only indicator
- [ ] Reduced motion and dynamic text size supported
- [ ] Accessibility traits/roles/states announced correctly

---

## Common Anti-Patterns

| Anti-Pattern | Fix |
|---|---|
| Emoji as structural icons | Use SVG icon sets (Heroicons, Lucide, Phosphor) |
| Placeholder-only labels | Always add a visible `<label>` element |
| Hover-only interactions | Provide tap/click fallback for all hover behaviors |
| Inconsistent spacing | Enforce 4/8dp scale via design tokens |
| Raw hex colors in components | Use semantic tokens (--color-primary, --surface-bg) |
| AI purple/pink gradients on serious products | Match color mood to industry (finance → navy/teal, healthcare → soft blue/white) |
| Animations on every element | Max 1–2 animated elements per view; use reduced-motion |
| No loading/empty states | Always design skeleton, loading spinner, and empty state for every data view |
| Color-only error indicators | Pair with icon + text description |
| Mixing icon styles | Stick to one icon set and stroke weight throughout |
