# Apex — Design Principles

> The north star: a rider finishes a great road, pulls over, opens Apex, and
> *feels* something. The ride they just did is rendered back to them as an
> object worth keeping. This is a garage for rides, not a spreadsheet of them.

These principles are binding. When a design decision is ambiguous, resolve it by
re-reading this document, not by reaching for the nearest SwiftUI default. If a
choice violates a principle here, the choice is wrong — change the choice.

---

## 0. The bar: "Transit-level"

The reference is the **Transit** app (transitapp.com). What we are stealing from
it — explicitly:

1. **Confident color as identity, on a dark canvas.** Transit gives every line a
   bold, saturated color and lets it glow against near-black. Content is the only
   thing that's bright. Chrome recedes. We do the same: the **route** and its
   **stats** are the only loud things on screen.
2. **Glanceable in one second.** Transit is designed to be read while walking to a
   bus. Apex is designed to be read with a helmet still on, gloves still on,
   standing next to a running bike. Every primary screen must answer its core
   question in a single glance, no scrolling, no squinting.
3. **Information density without clutter.** Transit shows a *lot* — but it earns
   every pixel with ruthless hierarchy. Dense is fine. Busy is not. The
   difference is hierarchy.
4. **Motion that means something.** Transit's departure times tick live. Nothing
   moves for decoration. In Apex, motion communicates state: a route draws itself
   in, live stats count during recording, a card settles when saved.
5. **Native, not "cross-platform mush."** It feels like it belongs on iOS —
   SF Pro, SF Symbols, real haptics, real depth. It does not look like a website
   in a wrapper.

If a screen we build would look out of place sitting next to Transit in a
screenshot, it is not done.

---

## 1. Product principles (what Apex *is*)

**P1 — The ride is the hero.** The map route line is the single most important
visual element in the entire app. Everything else — chrome, labels, buttons —
exists to frame it. Never let UI compete with the route for attention.

**P2 — A garage, not a database.** Saved rides are keepsakes, not rows. The
saved-rides list should feel like flipping through a collection of beautiful
objects. If it ever feels like a settings screen or a bank statement, we failed.

**P3 — Rider-first ergonomics.** The user is often gloved, sometimes in bright
sun, sometimes about to ride. Primary actions are big, bottom-anchored (thumb
reach), high-contrast, and forgiving. No tiny targets. No critical action buried
in a nav bar corner.

**P4 — Honest, earned numbers.** Distance, duration, top speed, elevation — these
are the rider's trophies. Show them boldly and get them *right*. Never fudge a
stat for layout convenience. A wrong number destroys trust faster than an ugly
screen.

**P5 — Quiet until it matters.** No notification spam, no gamification badges, no
nagging. Apex is calm. It speaks when the rider is looking, and shuts up
otherwise. (This principle also governs the CarPlay-autoplay behavior: the app
never grabs audio or interrupts unless the rider explicitly asked it to.)

---

## 2. UX principles (how it should feel)

**U1 — One primary action per screen.** Each screen has exactly one obvious next
thing to do, expressed as the largest, most colorful control on screen. Secondary
actions are visibly secondary. If a user has to hunt, the screen has too many
peers.

**U2 — Content-first entrances.** Screens reveal content, not chrome. When a
screen appears, the eye should land on a ride/route/number, never on a toolbar.
Prefer large-title-collapsing-to-inline over static bars.

**U3 — Depth through elevation, not lines.** Separate content with shadow,
translucency (material blur), and spacing — not hairline dividers everywhere.
Cards float above the canvas. The canvas is deep, dark, and slightly textured by
gradient, never flat gray.

**U4 — Motion is physics, not animation.** Transitions use spring curves that
feel like real objects with mass. Nothing linear-eases. Nothing teleports. A card
that appears springs in; a route that loads draws along its own path; a number
that changes rolls.

**U5 — Haptics punctuate, don't decorate.** A crisp haptic on start/stop
recording, on save, on a milestone (first 100 km). Never on scroll, never on
every tap. Haptics are exclamation points; use them sparingly.

**U6 — Readable in sunlight.** Minimum contrast targets exceed WCAG AA for all
primary text and stats. Test the "helmet still on, sun overhead" case: could you
read the distance from arm's length? If not, it's too small or too low-contrast.

**U7 — Empty states are invitations, not apologies.** The first-run, no-rides-yet
screen is a *designed* moment that makes the rider want to go ride — not a gray
"No data" label. First impressions set the emotional tone.

---

## 3. Visual identity (the feeling in three words)

**Dark. Kinetic. Premium.**

- **Dark** — a deep, near-black canvas with a subtle vertical gradient (never
  pure #000, never flat gray). Rich, like a garage at night. Makes route colors
  and stats glow.
- **Kinetic** — everything has a sense of motion and speed baked into its
  geometry: dynamic route lines, angled accents, momentum in transitions. This is
  an app about *moving fast on two wheels*; the UI should have velocity in its
  bones without being a boy-racer cliché.
- **Premium** — restrained palette, generous whitespace, precise alignment,
  real typography hierarchy. Expensive-feeling, like a good motorcycle: nothing
  extra, everything considered.

**The signature color** is a warm, high-energy accent (an ignition-orange /
amber, see DESIGN_SYSTEM). Used sparingly and only for: the primary action, live
state, and the "hero" stat. Its scarcity is what gives it power. If everything is
accented, nothing is.

**Per-ride color** — each ride carries an identity color derived deterministically
from the ride itself (see DESIGN_SYSTEM §route-color). This is our "Transit line
color": it colors the route line and the card accent, so a rider learns to
recognize their rides by hue, not just by reading text.

---

## 4. Anti-patterns (instant rejections)

These are automatic "no." If a design includes one, it is wrong regardless of
anything else:

- ❌ System-default gray grouped `List` used as the saved-rides UI. (Looks like
  Settings. See P2.)
- ❌ Flat pure-black or flat pure-gray backgrounds. (No depth. See U3.)
- ❌ Hairline dividers between every row. (Use spacing/elevation. See U3.)
- ❌ Tiny stat text you can't read at arm's length. (See U6.)
- ❌ The accent color used on more than ~10% of a screen. (Scarcity = power.)
- ❌ Linear ease / instant transitions. (See U4.)
- ❌ A generic map pin dropped on a default Apple Maps style. (The map is styled;
  the route is the hero, see P1.)
- ❌ An empty state that just says "No rides." (See U7.)
- ❌ Stock SF Symbol in a stock circle as the only visual interest on a card.

---

## 5. How we verify we hit the bar

Apex is built on Linux with **no Mac in the loop**. We cannot "just run it in the
simulator and look." So verification is a first-class, automated discipline:

1. Every UI-bearing change is rendered to a real PNG on macOS CI (see
   `AGENTS.md`) and **viewed** — the agent inspects the pixels, not just the
   build log. "It compiles" is not "it looks right."
2. Screens are reviewed against **this document**, point by point, before they're
   called done. The review question is literally: *"Would this look out of place
   next to Transit?"*
3. Design is checked with **seeded demo data** (a real-looking route, realistic
   stats) so the rendered screenshot shows the app as a rider would actually see
   it — never with `Text("Placeholder")`.

Good enough is not the standard. *Would a rider screenshot this and text it to a
friend?* is the standard.
