# AI Study Buddy preliminary brand-mark review

Date: 2026-07-11

This document records design exploration and a preliminary similarity-review
process. It is not legal trademark clearance and does not establish that the
mark or name is unique, trademark-safe, or non-infringing. Professional
trademark clearance may be required before a commercial launch.

## Concepts considered

### 1. Guided S Path — selected

Two broad opposing page/ribbon forms create an S-shaped negative channel, with
one offset guide dot. The ribbons suggest a study path and the front/back
relationship of flashcards without forming a literal open book. Its asymmetric
outer silhouette and open channel remain readable at 16 and 24 px; larger sizes
show the smooth page-like turns. Monochrome relies on the negative channel, not
internal strokes. It works on light and dark hosts through caller-selected
colors. Abstract ribbon/S marks exist, so its exact silhouette has a medium-low
genericity risk that still requires comparison.

### 2. Offset Card Turn

Two offset rounded card forms bend toward a diagonal gap and a transition dot.
It communicates question-to-answer movement and has a stepped silhouette. It is
strong from 24 through 512 px but reads as two blocks at 16 px. Separation makes
it viable in monochrome and on either host tone. Overlapping-card symbols are
common in productivity and payment products, giving it medium genericity risk.

### 3. Waypoint Fold

Two angular ribbon segments create an upward route with a dot at its endpoint.
It communicates guided progress and has a bold silhouette from 16 through 512
px. A negative notch preserves its monochrome form, and foreground inversion
supports light or dark backgrounds. It risks resembling navigation, analytics,
or logistics branding, so its genericity risk is medium.

### 4. Paired Page Portal

Two curved vertical panels face one another around a narrowing passage, with an
asymmetric guide dot. It suggests moving between knowledge states and paired
cards. It remains clear from 24 through 512 px, but loses study meaning at 16
px. The central negative space works in monochrome and on light or dark hosts.
Paired leaf and portal marks are widespread, giving it medium-high genericity
risk.

Guided S Path was selected because it best balances small-size recognition,
study/path meaning, and distance from literal education-symbol conventions.
Features from the other concepts were not combined into the selected mark.

## Construction and variants

The Flutter `CustomPainter` uses one normalized 100 × 100 coordinate system.
Both ribbons are filled shapes with broad masses and restrained page-like
terminal cuts; there are no thin strokes or small internal details. A 4.8-unit
guide dot sits inward at the path exit. The 16 and 24 px renderings use a tuned
compact form with a five-unit dot, slightly broader channel, and closer ribbons.
Geometry is deterministic and clips neither the ribbons nor the dot.

- Full color: primary blue `#315EA8`, secondary teal `#317C78`, restrained
  amber dot `#C98735`.
- Flat: one high-contrast fill, with no gradient, glass, blur, or shadow.
- Monochrome: one caller-provided color on a transparent background; the
  central channel remains negative space.

The source of truth is Flutter-native vector geometry. No SVG package, raster
source asset, external asset, or network request is used.

## Rendering and manual review

Run `flutter test test/brand_mark_widget_test.dart --update-goldens` to render
the focused preview. Review `test/goldens/study_buddy_mark_preview.png` at 100%
scale. It contains all variants, icon and horizontal lockup treatments, light
and dark host surfaces, and the required sizes. Launcher/platform assets must
not be generated from it until the mark receives manual approval.

## Preliminary similarity-search record

Only genuine searches belong in this table. No external database searches were
performed as part of the local implementation session.

| Target | Icon/silhouette check | Name queries | Result / next action |
|---|---|---|---|
| Reverse-image search | Not checked — manual review required. | N/A | Export the rendered icon and search both color and monochrome silhouettes. |
| Apple App Store | Not checked — manual review required. | AI Study Buddy; Study Buddy AI; Study Path; close variants | Review app icons and names manually. |
| Google Play | Not checked — manual review required. | AI Study Buddy; Study Buddy AI; Study Path; close variants | Review app icons and names manually. |
| WIPO Global Brand Database image search | Not checked — manual review required. | Same names and word-order variants | Search image classifications and word marks. |
| EUIPO / TMview | Not checked — manual review required. | Same names and word-order variants | Search relevant goods/services and image elements. |
| DPMAregister (Germany) | Not checked — manual review required. | Same names and word-order variants | Search word and figurative marks. |
| USPTO | Not checked — manual review required. | Same names and word-order variants | Required if a US launch is planned. |

For each future search, record the search date, database, exact query or image,
links/identifiers where available, visually similar findings, and the resulting
keep/revise/escalate decision. CAPTCHA, access failures, or incomplete searches
must be recorded as “Not checked — manual review required,” never as clearance.
