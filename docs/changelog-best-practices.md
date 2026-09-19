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

Three things earn a line:

- a **capability** that did not exist;
- a **behaviour that changed** — something that works differently, or is gone;
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
- Ajout de l'import d'un document depuis une photo, un lien ou un texte.
```

## Three sections, always in the same order

A version's notes fall under at most three headings, in this order: **New** (a capability that
did not exist), **Improved** (something that existed and now behaves differently — including a
removal), **Fixed** (a visible defect that no longer happens). In French: **Nouveau**,
**Amélioré**, **Corrigé**.

Stores and in-app lists often flatten the headings away, so a line must carry its own section:
it opens on a verb that says what kind of change it is.

| Section  | English opening                          | French opening                                 |
|----------|------------------------------------------|------------------------------------------------|
| New      | Added …                                  | Ajout de …                                     |
| Improved | Changed … / Improved … / Removed … / Updated … | Modification de … / Amélioration de … / Suppression de … |
| Fixed    | Fixed …                                  | Correction de …                                |

## A line says what, where, and what it changes

A **new** line names the thing, where it lives — the tab, the button, the settings path — and,
when it is not obvious, what it makes possible, joined with "so" / "pour que". A **changed** line
says the old behaviour and the new one. A **fixed** line describes the symptom exactly as the
reader saw it — what failed, and when — never its cause; when the behaviour after the fix is
not simply "it works", it follows after a semicolon.

```markdown
<!-- Bad — vague, abstract, and the fix names the cause instead of the symptom -->
- Les recettes peuvent être faites d'autres recettes.
- Meilleure gestion des dates.
- Correction d'un bug de tri dans le cache du carnet.

<!-- Good -->
- Ajout des liens entre recettes : une recette de ravioles aux champignons renvoie à la recette
  de pâte fraîche, qui s'ouvre sans quitter la fiche.
- Modification des boutons de quantité : changer une quantité adapte désormais toutes les autres
  en proportion, au lieu de ne modifier qu'elle.
- Correction des dates du carnet, qui dataient une version de sa création au lieu de sa dernière
  modification ; une recette porte désormais la date de la version qu'elle ouvre.
```

Precision beats brevity: one bullet is one sentence, but that sentence may be long if it is
what it takes to name the symptom and the new behaviour. Several defects in the same area go in
one bullet, announced and then listed after a colon ("Correction de plusieurs problèmes
d'import : …"), rather than as five bullets the reader has to reassemble.

## Plain words, and a concrete example

The reader is a cook, a driver, a photographer — not someone who knows the product's vocabulary.
A line is written the way one would say it out loud to a friend who owns the app. An example is
worth more than a definition, and naming the field or the button is worth more than describing
its behaviour.

Nothing is left implicit or elegant at the cost of being understood: an image ("une version qui
s'est éloignée de sa recette"), an abstraction ("les astuces se corrigent sur place") or a clever
turn reads well and says nothing.

## No names, no internals

Never name a person: a changelog credits the product, not its authors. Never name an internal
component, screen class, module, endpoint or flag either — those names mean nothing to the reader
and leak the shape of the code.

## Factual, not promotional

Describe what the product now does, in a neutral, matter-of-fact tone: no enthusiasm, no
exclamation marks, no "enjoy", no first person. The reader may be addressed only to situate a
symptom or a condition ("quand l'app était relancée pendant un import"), never with an imperative
or a sales pitch.

```markdown
<!-- Bad -->
- Tu peux maintenant noter tes essais et ajouter tes photos, profites-en !
<!-- Good -->
- Ajout de la notation des essais, de 1 à 5 étoiles, avec une remarque et des photos.
```

## Unemphasised

No sub-bullets, no paragraphs, no bold inside a line: when every third word is emphasised,
nothing stands out. Reserve emphasis for the rare line that genuinely warns about something.

## A first release describes the product, not its history

The first public version has no "before". It does not announce that a feature was reworked,
that a section was removed, that data written by earlier builds is incompatible, or that something
temporarily regressed — none of those readers exist. It lists what the product does, and nothing
else. The pre-release iterations stay in the git history.

For the same reason, a first release usually has no fixes section: it fixed nothing anyone ever
ran.

## No empty sections

A heading with nothing under it is noise. Drop the section rather than write "nothing this time".
