# Changelog

Every notable change to Shuhari, most recent first. This English file is the source of truth;
`CHANGELOG.fr.md` is the French copy served to the app.

## Unreleased

### New

- Shuhari refocuses on **cooking**: two recipe types, **Plat** (dish) and **Thermomix** (coffee and cocktails will come back later). The tabs narrow down to **Carnet** (notebook) and **Import**.
- Every recipe now carries a **dish category** (starter, main, dessert, soup, sauce, baking), **detected automatically at import**, editable in the preview and shown on the recipe sheet.
- Trials are now rated **from 1 to 5 stars**: a version becomes the reference **as soon as a trial reaches 4 stars**.
- Reworked iteration proposals: the AI provides a **complete draft of the next version** — change summary, rationale, ingredients and steps — that can be **edited before accepting it**.
- The recipe sheet and its run now build on **ingredients and steps**: the tunable parameters give way to a recipe that is simpler to read and to reproduce.
- Carnet: the library now **loads continuously** (paginated loading) and offers a **sort** — **Dish type** or **Last modified** — next to the Plat / Thermomix filter.
- **Heads-up**: as a result of these changes, **backups exported before this version can no longer be restored**.
- Recipe sheet: a Photos-viewer-style layout — a **title pill** with the creation date, **type / version / trials** badges with the average rating in **stars**, **ingredients embedded** in the page then the **best version** as the description; at the bottom, a beaker for the "to test" version, a **round button to log a trial** and the **history in a panel**.
- Log a trial: a new "Remark" half-sheet screen — a **5-star** rating, a roomier remarks field, and support for **several photos**; confirmed with a checkmark at the top.
- Carnet: every recipe shows its **number of versions** and its **best rating**.
- Icons: new dedicated symbols — an **espresso cup** for coffee, a martini glass for cocktails, a chef's toque for cooking, a **beaker** for trials, and outline/filled Thermomix variants.
- Import: **ingredients** are now extracted with their quantities, separately from the parameters — editable at import and shown on the recipe sheet.
- Import: recipe analysis now shows in a dedicated sheet with Siri's "listening" animation, and the preview adopts a native style (Close and checkmark confirmation at the top, type with an icon, editable steps, the title back in normal case, empty sections hidden).
- Import: the analysis animation is smoother and blends gently into the preview once the recipe is ready.
- Recipe: deleting a recipe now asks for confirmation and the list updates immediately.
- The import shortcut (camera) now appears in its own separate button, to the right of the tab bar, apart from the categories.
- Photo import: a recipe photo can now be taken directly with the camera, in addition to picking it from the library, a link, or text.
- Thermomix recipes: import now extracts each step's settings (time, temperature, speed, reverse direction), shown as badges on the recipe sheet and the import preview.
- First version: AI-assisted recipe import, an experimentation loop (run, rate, iterate), AI iteration proposals, version promotion and variations.

### Fixes

- Recipes whose ingredient carries a descriptive (long) name now import without an error.
- Import: picking or taking a photo closes the camera before opening the preview.
- Closing the import returns to the original category (the tab no longer stays stuck on an empty page).
