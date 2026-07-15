# AGENTS.md — Apex

Operational contract for any agent working in this repo. Read this first, then
`docs/DESIGN_PRINCIPLES.md` before touching any UI. This file says **how to work**;
the docs say **what to build and why**.

Apex is a motorcycle riding companion (iOS). It records rides and renders them
back as beautiful keepsakes. The UI bar is **Transit-level** — see the design docs.

---

## 0. Prime directives

1. **Design docs are law.** `docs/DESIGN_PRINCIPLES.md`, `docs/DESIGN_SYSTEM.md`,
   `docs/ARCHITECTURE.md` are binding. If code conflicts with them, the code is
   wrong. Never ship a screen you haven't reviewed against DESIGN_PRINCIPLES §4
   (anti-patterns) and §0 (the Transit bar).
2. **You must SEE every UI change.** This project is built on Linux with **no Mac**.
   "It compiles" ≠ "it looks right." Every UI-bearing change is rendered to a PNG
   on macOS CI and visually inspected before it's called done. (How: §3.)
3. **Tokens only.** No color/size/padding/font literals inside views. Everything
   comes from `DesignSystem/Theme.swift`. (Enforced: `Tools/lint-tokens.sh`.)
4. **Correct numbers are sacred.** Ride stats are the rider's trophies. Stat math
   lives in `RideMetrics` and is unit-tested. Never fudge a number for layout.
5. **Measure, don't guess.** Perf/behavior claims must be backed by a real run,
   not asserted. (This repo exists because a plausible-but-wrong optimization was
   only caught by measuring — see §3 CI lessons.)

---

## 1. Environment

- Host: Linux (`obelisk-quebec.exe.xyz`), persistent disk, sudo, Docker available.
- Toolchain: Swift 6.3.0 (`swift-6.3-RELEASE`) default via swiftly; **xtool 1.17+**;
  iOS SDK installed at `~/.swiftpm/swift-sdks/darwin.artifactbundle`.
- GitHub auth: `~/.hermes/.env` provides `GITHUB_TOKEN`. Export as `GH_TOKEN` for
  `gh`. Operate as bot `clambake8233`.
- Repo remote: created on GitHub as a **public** repo (public = free macOS CI).

### PAT limitations (known, don't rediscover)
- Bot fine-grained PAT **cannot** `workflow_dispatch` (no Actions:write) → trigger
  CI with an empty-commit push instead.
- Bot PAT **cannot** create repos → repo creation is a one-time browser action.
- Bot PAT **has** Contents:write + all-repo access → push works.

---

## 2. Build & run

```bash
# Build for the iOS Simulator (what CI screenshots)
xtool dev build --triple arm64-apple-ios-simulator

# Build an installable .ipa (device / free Apple ID)
xtool dev build --ipa --configuration release   # default triple arm64-apple-ios
# -> xtool/Apex.ipa (unsigned; Payload/Apex.app/). Then: xtool devices ; xtool install <ipa>
# NOTE: it's `xtool dev build --ipa`, NOT `xtool build` (that's not a subcommand).
# To ship an AltStore UPDATE you MUST bump CFBundleShortVersionString + CFBundleVersion
# in Info.plist BEFORE building (xtool bakes them in), then match them in altstore.json.

# Unit tests (pure logic: RideMetrics, route color)
swift test
```

xtool project config: `xtool.yml` (bundleID) + `Package.swift` (one library
product = the app, per xtool convention).

---

## 3. How to SEE the UI (verification — the core loop)

Two tiers (full rationale in `docs/ARCHITECTURE.md` §4). **Use Tier 1 for
iteration, Tier 2 for final truth.**

### Tier 1 — Snapshot harness (FAST, seconds, primary)
`Tools/SnapshotHarness` renders a screen from `SampleData` via SwiftUI
`ImageRenderer` — **no simulator**. CI job `snapshot` runs it and uploads PNGs.
```bash
# locally (on a Mac) or in CI:
swift run SnapshotHarness --screen ride-library --size iphone16pro --out out/
```
This is the fast design loop. Prefer it.

### Tier 2 — Full simulator screenshot (SLOWER, truth)
`.github/workflows/screenshot.yml` on `macos-15`: brew install xtool → build sim
triple → boot sim → install → launch → `simctl io screenshot` → upload artifact.
Then download the artifact and **view the PNG with vision**.

Trigger CI (PAT can't workflow_dispatch): `git commit --allow-empty && git push`.

### ⚠️ CI lessons already paid for — DO NOT relearn
These are measured, expensive lessons baked into `screenshot.yml`. Changing them
will regress the loop:
- ❌ **Never boot a simulator concurrently with `brew install`.** They contend for
  CPU/IO; brew goes 22s → 200s+ (measured across 3 runs). Boot the sim
  **serially, after** install+build.
- ❌ **Never cache the Homebrew cask** (`~/Library/Caches/Homebrew`, Caskroom).
  On a warm cache brew sees "artifact has not changed" and **skips linking** →
  `xtool: command not found` (exit 127). Cold brew is only ~11s; just run it.
- ✅ **Poll for a rendered frame** (screenshot byte-size threshold) instead of a
  fixed `sleep` — sim readiness is variable.
- ℹ️ Simulator lifecycle (create/boot/install/launch) is the dominant,
  high-variance cost (measured 152s AND 276s on identical runs). There is no
  single "optimized wall-clock" for Tier 2. This variance is exactly why Tier 1
  (the harness) exists.

### The review gate (before any UI change is "done")
1. Render it (Tier 1, escalate to Tier 2 for map/blur fidelity).
2. View the PNG. Actually look at the pixels.
3. Walk `DESIGN_PRINCIPLES.md` §4 anti-patterns — zero hits allowed.
4. Ask the bar question: *"Would this look out of place next to Transit?"* If yes,
   iterate. If you'd screenshot it and text it to a friend, it's done.

### ⚠️ Vision review is coarse-only — MEASURE precise claims
The vision pass is reliable for COARSE issues (colors distinct? glow smudgy? hard
cutoff vs smooth fade? content clipped?). It is NOT reliable on sub-pixel
symmetry, alignment, or spacing — it has hallucinated a "lopsided, right-arm-
higher" brand mark and "off-center dot" on a mark that PIL measurement proved
pixel-perfect (centroid at exact center, both arms ending at identical y). When a
subjective vision review conflicts with deterministic geometry, MEASURE the PNG
before "fixing" — load it with PIL, compute centroids/extents/positions. Chasing
the model's wording risks breaking something already correct.
```python
from PIL import Image
im = Image.open("out/ride-library-empty.png").convert("RGB"); W,H = im.size
# scan for accent-colored / bright pixels, compute centroid x vs W/2, left/right extent
```

---

## 4. Conventions

- **Commits:** conventional (`feat:`, `fix:`, `perf:`, `docs:`, `refactor:`).
  Small, focused. UI commits reference what was visually verified.
- **Swift:** strict concurrency; `@Observable` stores for state; pure views.
  Side effects (location, persistence) never in view bodies.
- **New visual value?** Add a named token to `Theme.swift` FIRST, then use it.
- **New screen?** It must render from `SampleData` headless (no live deps) or it
  can't be verified — that's a blocker, not a nice-to-have.
- **Tests:** stat math and route-color determinism are unit-tested. Run
  `swift test` before pushing logic changes.

---

## 5. Repo map

```
AGENTS.md                    ← you are here
docs/
  DESIGN_PRINCIPLES.md       ← product + UX law (read before any UI)
  DESIGN_SYSTEM.md           ← concrete tokens (→ Theme.swift)
  ARCHITECTURE.md            ← technical structure + verification tiers
Sources/Apex/                ← app (layout in ARCHITECTURE §3)
Tools/SnapshotHarness/       ← fast headless render (Tier 1)
Tests/ApexTests/             ← stat/color correctness
.github/workflows/           ← screenshot.yml (Tier 2), snapshot.yml (Tier 1)
```

---

## 6. Current status

Bootstrapping. Foundation docs written. First screen to build: **Ride Library**
(the saved-rides list) — the hero screen. Build it from `SampleData`, render it,
review it against the design docs, iterate until it clears the Transit bar.
