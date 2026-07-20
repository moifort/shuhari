# Changelog — Best Practices

Portable rules for writing release notes. Project wiring — which files, which languages, when they
are written — lives in the project's release guide.

## The reader is a user, not a developer

Release notes are read by whoever taps "What's New" in a store listing: someone who wants to know
what the product does now that it did not do before. They are not a development log, not a summary
of the sprint, and not a list of merged branches.

Everything follows from that single test: **would someone who has never seen the code notice this
change?**

## Only what changes what the product does

Two things earn a line:

- a **capability** that did not exist;
- a **defect that was visible** — something that failed, lost data, or displayed the wrong thing.

Everything else is invisible and belongs in the git history, where it already is: refactors,
renames, dependency bumps, test coverage, internal architecture, and every kind of visual polish —
redesigned screens, new icons, smoother animations, adjusted spacing. A redesign is not a feature;
it is what the product looks like.

```markdown
<!-- Bad — four lines nobody outside the team can act on -->
- Refonte de la fiche produit façon visionneuse Photos, avec pastille de titre et badges.
- Nouveaux symboles dédiés : tasse, verre, bécher, variantes contour/rempli.
- L'animation de chargement est plus fluide et se fond en douceur dans l'aperçu.
- Migration du client réseau vers la nouvelle API.

<!-- Good — one line that says what became possible -->
- Import d'un document depuis une photo, un lien ou un texte.
```

## No names, no internals

Never name a person: a changelog credits the product, not its authors. Never name an internal
component, screen class, module, endpoint or flag either — those names mean nothing to the reader
and leak the shape of the code.

## Impersonal

Describe what the product does, not what the reader does. No "you", no imperative aimed at the
reader, no first person. This keeps the notes short and stops them ageing into a tone the product
no longer has.

```markdown
<!-- Bad -->
- Tu peux maintenant noter tes essais et ajouter tes photos.
<!-- Good -->
- Notation des essais, avec remarque et photos.
```

## Succinct, and unemphasised

One line per item, one idea per line. No sub-bullets, no paragraphs.

Resist emphasis: when every third word is bold, nothing stands out and the list becomes harder to
read than plain text. Reserve emphasis for the rare line that genuinely warns about something.

## A first release describes the product, not its history

The first public version has no "before". It does not announce that a feature was reworked,
that a section was removed, that data written by earlier builds is incompatible, or that something
temporarily regressed — none of those readers exist. It lists what the product does, and nothing
else. The pre-release iterations stay in the git history.

For the same reason, a first release usually has no fixes section: it fixed nothing anyone ever
ran.

## No empty sections

A heading with nothing under it is noise. Drop the section rather than write "nothing this time".
