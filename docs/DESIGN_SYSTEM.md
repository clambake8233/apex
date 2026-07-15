# Apex — Design System (Tokens)

Concrete, buildable values that implement `DESIGN_PRINCIPLES.md`. Every token
here maps 1:1 to a constant in `Sources/Apex/DesignSystem/Theme.swift`. **Views
must consume tokens, never hardcode literals.** A raw `Color(hex: ...)`,
`.padding(17)`, or `.font(.system(size: 22))` inside a view is a bug — add or use
a token instead.

This single-source-of-truth rule is what lets us evolve the whole look by editing
one file, and what keeps the app coherent as it grows.

---

## 1. Color

Dark canvas, glowing content (Principle §3). All colors are defined for **dark
mode first** (our default and primary target). Values are sRGB hex.

### Canvas (backgrounds — deep, never flat)
| Token | Hex | Use |
|---|---|---|
| `canvasTop` | `#0E1014` | Top of the app background gradient |
| `canvasBottom` | `#16181D` | Bottom of the app background gradient |
| `surface` | `#1C1F26` | Card / elevated surface base |
| `surfaceRaised` | `#242832` | Higher elevation (sheets, active card) |
| `surfaceStroke` | `#FFFFFF @ 8%` | Hairline on cards (subtle, 1px, low alpha) |

> Background is ALWAYS the `canvasTop → canvasBottom` vertical gradient, never a
> flat fill. This is the "garage at night" depth (U3).

### Ink (text/icons)
| Token | Hex | Use |
|---|---|---|
| `inkPrimary` | `#F5F7FA` | Primary text, hero stats (near-white, not pure) |
| `inkSecondary` | `#AEB4C0` | Secondary text, labels |
| `inkTertiary` | `#6E7480` | Captions, disabled, timestamps |
| `inkInverse` | `#0E1014` | Text on top of the accent color |

### Accent — "Ignition" (the signature, scarce color)
| Token | Hex | Use |
|---|---|---|
| `accent` | `#FF6B2C` | Primary action, live state, hero stat ONLY |
| `accentHi` | `#FF8A4F` | Gradient top / pressed-bright |
| `accentGlow` | `#FF6B2C @ 35%` | Shadow/glow beneath accent elements |

> Accent covers ≤10% of any screen (anti-pattern list). Its job is to say "this,
> here, now." Two accented things competing on one screen = redesign.

### Semantic
| Token | Hex | Use |
|---|---|---|
| `speed` | `#38D6B0` | Speed-related stats / fast segments |
| `elevation` | `#C08CFF` | Elevation-related stats / climbs |
| `danger` | `#FF4D4D` | Destructive (delete), errors |
| `success` | `#3DDC84` | Save confirmation, milestones |

### Route color (per-ride identity — our "Transit line color")
Each ride gets a deterministic hue so riders recognize rides by color (P3/§3).
Algorithm (implemented in `Theme.routeColor(for:)`):
```
hue   = (stableHash(ride.id) % 360) / 360      // deterministic per ride
sat   = 0.72                                    // rich, Transit-like saturation
bri   = 0.95                                    // glows on dark canvas
// Reject a small "mud" band (hue 40–70 desaturated) so no ride looks dull.
```
The route line is drawn in this color with a soft outer glow of the same hue at
30% alpha. On the card, a 4pt spine of this color anchors the ride's identity.

---

## 2. Typography

SF Pro (system). Hierarchy is created by **weight + size contrast**, aggressively
— Transit-level hierarchy means big things are BIG and small things are small,
with little in between (avoid a soup of near-equal sizes).

| Token | Size / Weight / Tracking | Use |
|---|---|---|
| `displayXL` | 48 / Bold / -1.0 | The one hero number on a screen (e.g. live distance) |
| `display` | 34 / Bold / -0.5 | Screen hero stat, big totals |
| `titleL` | 28 / Bold / -0.4 | Large nav titles ("Rides") |
| `title` | 22 / Semibold / -0.2 | Card ride title, section headers |
| `body` | 17 / Regular / 0 | Body text |
| `bodyEmphasis` | 17 / Semibold / 0 | Emphasized inline values |
| `stat` | 20 / Semibold / -0.2 | Stat values on cards |
| `label` | 13 / Medium / +0.3 | Stat labels, ALL-CAPS metadata (uppercased) |
| `caption` | 12 / Regular / +0.2 | Timestamps, captions |
| `mono` | 15 / Medium (SF Mono) | Numeric readouts that tick (live timer) |

> Numbers that change live (timer, live distance) use **monospaced digits**
> (`.monospacedDigit()`) so they don't jitter as digits change width (U4 polish).

---

## 3. Spacing & layout

8pt grid. Tokens are multiples; never use off-grid values.

| Token | Value | Use |
|---|---|---|
| `space1` | 4 | Tight, icon-to-label |
| `space2` | 8 | Related elements |
| `space3` | 12 | Intra-card |
| `space4` | 16 | Standard content inset / gutter |
| `space5` | 20 | Card internal padding |
| `space6` | 24 | Between cards |
| `space8` | 32 | Section separation |
| `space10` | 40 | Screen top breathing room |

| Token | Value | Use |
|---|---|---|
| `screenInset` | 16 | Left/right screen margin (content) |
| `cardRadius` | 20 | Card corner radius (generous, premium) |
| `cardRadiusSm` | 14 | Inner elements, chips |
| `buttonRadius` | 16 | Primary buttons |
| `pillRadius` | 999 | Fully-rounded pills/chips |
| `hairline` | 1 | Stroke width |
| `touchMin` | 44 | Minimum touch target (Apple HIG floor; we prefer 56 for gloves) |
| `primaryButtonHeight` | 58 | Big, gloved-thumb-friendly (P3) |

---

## 4. Elevation (shadows)

Depth via shadow, not lines (U3). Three levels only.

| Token | Shadow | Use |
|---|---|---|
| `elev1` | y2, blur8, black @ 20% | Resting card |
| `elev2` | y6, blur18, black @ 30% | Raised / active card, sheets |
| `elevAccent` | y4, blur24, `accentGlow` | Under the primary action (colored glow) |

---

## 5. Motion

Physics, not animation (U4). Two spring presets cover almost everything.

| Token | Spec | Use |
|---|---|---|
| `springSnappy` | `.spring(response: 0.34, dampingFraction: 0.82)` | Taps, toggles, most transitions |
| `springSmooth` | `.spring(response: 0.55, dampingFraction: 0.9)` | Card entrances, larger moves |
| `routeDraw` | 0.9s ease-out, path-length keyframe | Route line "drawing itself" in |
| `numberRoll` | `.snappy` content transition | A changed number rolling over |

Rules:
- No `.linear`, no `.easeInOut` for interactive elements. Springs only.
- List cards enter with a subtle **staggered** `springSmooth` (each card +0.03s)
  so the list "assembles" rather than pops. (U4 / Transit-style life.)
- Route lines always draw along their own length; never fade in.

---

## 6. Iconography

- SF Symbols, weight matched to adjacent text (usually `.semibold`).
- The brand/tab motif is the **apex-of-a-corner** curve — a racing line, not a
  generic map pin. Custom-drawn where SF Symbols can't express it.
- Never a lone stock symbol in a stock circle as a card's only visual interest
  (anti-pattern). Icons support content; the route/photo is the interest.

---

## 7. Map styling

- Map uses a **dark** style (MapKit `.dark`/`.hybridFlyover`-off, standard dark).
- Route polyline: per-ride route color, **6pt** width, rounded caps/joins, with a
  same-hue outer glow (`elevAccent`-style) so it reads as neon on the dark map.
- Start point: filled dot in `success`; end point: filled dot in `accent`. No
  default pins.
- On cards, the map is a **static rounded thumbnail** (snapshot), route drawn,
  no interactive controls — it's a picture of the ride, framed like a photo.

---

## 8. Token discipline (enforcement)

- CI greps `Sources/Apex` for raw color/size/padding literals inside `View`
  files and warns. (See `Tools/lint-tokens.sh`.)
- A new visual value ALWAYS lands in `Theme.swift` first, with a name, then gets
  used. This is how the app stays coherent while growing.
