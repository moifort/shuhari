# Changelog — Best Practices

Portable rules for writing release notes. Project wiring — which files, which languages, when they
are written — lives in the project's release guide.

## Sections

A version holds up to three sections, always in this order, and a section with nothing in it is
left out — a version can be a single "Fixed" line:

| English    | French      | Holds                                                           |
|------------|-------------|-----------------------------------------------------------------|
| `New`      | `Nouveau`   | a capability that did not exist                                 |
| `Improved` | `Amélioré`  | an existing behaviour that changed, was removed, or was updated |
| `Fixed`    | `Corrigé`   | a problem that no longer happens                                |

## One bullet, one sentence, opened by a verb

Every bullet is a single sentence — long if it needs to be — and opens on a past-tense verb that
says what kind of change it is, so the line still reads right once a store has flattened the
headings away:

| Section    | English                                        | French                                                   |
|------------|------------------------------------------------|----------------------------------------------------------|
| `New`      | Added …                                        | Ajout de …                                               |
| `Improved` | Changed … / Improved … / Removed … / Updated … | Modification de … / Amélioration de … / Suppression de … / Mise à jour de … |
| `Fixed`    | Fixed …                                        | Correction de …                                          |

No sub-bullets, no bold. A code or configuration name the reader types goes in backticks.

## Added — what, where, and what it is for

Name the feature, say where it lives — the menu, the button, the settings path — and, joined with
"so", what it makes possible. The parts of a feature are listed in the same sentence.

```markdown
- Added a default view setting: choose whether new projects open in the List or Board view from
  Settings > Display, or make the current view the default from a project's View menu.
- Added a queue for messages sent while offline: they wait above the composer instead of
  failing, and you can edit, cancel, or send them when the connection is back.
```

## Changed, Removed, Updated — the new behaviour, and what it replaces

Say what happens now; say what it replaces with "instead of" when the difference is not obvious.
A removal says what takes its place. An update is worth a line when the reader feels it — a new
minimum system version, a component they see the version of.

```markdown
- Changed the sidebar's Pinned list to show its first 20 items, with a Show more link for the rest.
- Removed the calendar view from the Planning page; tasks now always show as cards.
- Updated the app runtime to version 44; macOS 13 or later is now required.
```

## Fixed — the symptom, as the reader lived it

Describe what went wrong the way the reader saw it — what failed, froze, disappeared, or showed
the wrong thing — and when: the action, the platform, the condition ("after an update", "on
Windows", "when the disk was full"). Never the cause. When the behaviour after the fix is more
than "it works", it follows after a semicolon or "now".

```markdown
- Fixed the app window resetting to its default size and position after an update.
- Fixed text typed in the search box sometimes disappearing while a list was loading.
- Fixed the app freezing on launch when a very large draft had been saved; it now comes back as
  an editable "Saved draft" attachment.
```

Several problems in the same area make one bullet, announced then listed after a colon:

```markdown
- Fixed several sync issues: changes made offline were sometimes lost, a second device could
  overwrite a newer edit, and the history missed its newest entries right after launch.
```

## Addressing the reader

The reader is "you" when the sentence is about what they did or can do ("when you switched
models", "you can still edit, cancel, or send them"). The product is never "we", and the tone
stays factual: no exclamation marks, no enthusiasm.

## French

The French notes follow the same rules with a nominal opening, and address the reader the way
the product's own interface does (here, "tu"):

```markdown
- Ajout d'une file d'attente pour les messages envoyés hors connexion : ils attendent au-dessus
  du champ de saisie au lieu d'échouer, et tu peux les modifier, les annuler ou les envoyer
  quand la connexion revient.
- Correction de la fenêtre qui reprenait sa taille et sa position par défaut après une mise à jour.
```
