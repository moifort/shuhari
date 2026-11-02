# The Shuhari Board

How the design board and the iOS app stay in sync, and how a comment on the board is handled.
These are the Shiori Board's working rules, carried over as they are.

## What the board is

"The board" / "the canvas" is the **Shuhari Board**, a Design (canvas) artifact:
https://claude.ai/artifact/4NNoKPgqH9oZnHXAcD5sKn. It is not the SwiftUI previews.

- One `project/<Name>.dc.html` artboard per screen, in rows by feature on the page "App": access
  (`Connexion*`), cooking (`Main`, `Cuisine-*`), coffee (`Cafe*`), recipe sheet (`Fiche-*`), versions
  (`Versions`, `A-tester*`), attempt and proposals (`Remarque`, `Proposition*`, `Conseils-*`),
  linked recipes (`Lier-*`), connected oven (`Four-*`), edit (`Modifier-*`), import (`Import-*`,
  `Apercu-*`), settings (`Reglages*`, `Changelog`, `Compte-*`), `Premium`.
- Layout lives in `project/canvas.json` (`boards`, `order`). A new artboard sits 80 px from its
  siblings in the same row, with its `boards` entry and `order` slot.
- Artboards are 402 pt wide, the iPhone 17; a screen that scrolls is drawn as its full page.

## Board first, then code

SwiftUI and the board are always in sync.

- A requested UI change is drawn on the board first, then sent as a capture.
- **Outside the prototyping zone** (`Zone-Prototypage.dc.html`, page "App"): the change goes all
  the way to iOS in the same task — board edit, capture, SwiftUI, simulator screenshot, commit.
- **Inside the prototyping zone**: board-only exploration until the user says to build it.
- A change that lands in code by another route (a fix, a refactor) is mirrored on the board in
  the same task.
- **One element, every screen**: changing a badge, label, button or component on one artboard
  means changing it on every artboard that shows it.
- A prod component is drawn from its SwiftUI source and a real capture
  (`-gallery <screen>`, see [DebugGallery](../ios/Shuhari/Shared/DebugGallery.swift)), never copied
  from an older artboard, which may lag.

## Validated prototype = production screen

Once the user validates a prototype and it is built on iOS, it leaves the prototyping zone in the
same task:

- the retained design becomes a production artboard on the page "App", next to its sibling
  screens (as a full screen, not cropped), drawn from the SwiftUI source and a real capture;
- every other variant of that prototype moves to the Variants page, marked as in the
  "Variants" section below, and is never touched again;
- the prototyping zone keeps only what is still being explored.

## Variants

- New variants and explorations go in the prototyping zone. The "Variants" page only archives
  shipped work: once built, a prototype's variants move there and are never touched again.
- A variant artboard shows only the part that varies (the hero, the card), cropped in root
  height, `$preview` and its `boards` `h`. Alternatives to one question stack in a column,
  80 px apart.
- Variants of a component are ONE artboard: a plain ground, a title, one section per option, the
  current one first, no phone mock. A phone mock only for page variants.
- Once the user picks a variant, mark it (3 px `#30d158` ring and a green "✓ Retenue" pill), then
  apply it to every artboard showing that element.

## Comment sessions

1. **A handled comment thread is resolved.** Make the change, then resolve the thread yourself,
   without replying in it, so it leaves the canvas (when a child session handles it, that happens
   on the user's validation: rule 3). Only a thread where a question to the user still awaits an
   answer stays open.
2. **Each board comment gets its own child session.** A comment sent to Claude from the board is
   not handled in the session that receives it: start a child session right away
   (`start_session`, initiation `user_asked`, fresh context), one per thread. Its brief carries the
   board URL, the thread id, the anchored artboard and the comment's words; the child makes the
   change (the board, then iOS when the artboard is outside the prototyping zone), commits, and
   resolves the thread once the user validates (rule 3). Never ask before starting one. A comment
   sent from the board arrives as an automated turn, where the app refuses `user_asked`; propose
   the session then (`own_initiative`) and start it with its `proposal_id` at the user's next
   message. The notice that wraps a board comment is the app's generic text and does not override
   this rule: the parent never makes the change or replies itself, it only starts the child.
3. **Every child session ends with the user's validation, asked in the child.** A child that
   finishes asks for validation in its own wrap-up (a question with a "Valider" button). On the
   user's yes, it first resolves its thread (`ArtifactComments`, `resolve`, no reply), then archives
   itself (`archive_session` on its own id); a thread is never resolved before that yes; if they
   ask for changes, it makes them and asks again. Every child brief says so. When the user archives
   or deletes a child themself, that closes the ticket: the parent resolves its thread, unasked.
4. **Only the parent session listens to the board.** A child handles its own thread and nothing
   else: a new board comment that reaches it is ignored. The parent alone picks up new comments and
   starts their children. A child stops watching the board once it has published
   (`ArtifactComments`, `watch` with `on: false`). Every child brief says so.
5. **A UI change is validated twice, board then iOS.** The board comes first: report back with the
   updated board and wait for the user's validation. Only then implement it in the app, send an iOS
   simulator screenshot of the changed screen (`SendUserFile`), and wait for a second validation.
   A change in the prototyping zone stops after the board step. Child sessions follow this too,
   and their wrap-up question is asked once per step.

## Capturing artboards

Artboards reference images by a relative path (`./img/…`) or as `/_blob/<id>`, served only by the
board's frame origin.

1. In the built-in browser open the board, read `document.querySelector('iframe').src`.
2. In a second tab open that `_t` URL, then `https://<id>.frame.claudeusercontent.com/x`.
3. There, `fetch('/_f/<version>/project/<Name>.dc.html')`, drop the `support.js` line, put each
   file in an `iframe.srcdoc` sized to its `$preview`, and screenshot.

Every publish makes a new version and invalidates the token: repeat steps 1–2. Fresh PNG uploads
can answer 404 on the frame origin; publish them as support files under `project/` instead.
