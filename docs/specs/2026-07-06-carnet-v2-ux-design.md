# Spec — Carnet v2 : design UX — 2026-07-06

## Problème & objectif

Carnet est un carnet d'expérimentation culinaire personnel couvrant **quatre types** dès le
départ : café, cocktails, plats, Thermomix. Le cœur du produit est une **boucle
d'auto-amélioration scientifique** : importer une recette, l'exécuter, la noter, laisser l'IA
proposer l'itération suivante, et converger vers une recette reproductible à l'identique.

La v1 (`~/Code/carnet`) a été codée avant de valider l'expérience ; la v2 valide d'abord le
flow via une **maquette interactive iPhone** (HTML, publiée en Artifact). Aucun code d'app
n'est écrit dans cette phase.

## Décisions produit

- **Périmètre** : les 4 types dès la conception ; le flow doit fonctionner pour les quatre.
- **Exécution** : une **fiche unique ultra-lisible** (paramètres clés en gros, étapes
  courtes), identique pour tous les types. Pas de mode pas-à-pas guidé.
- **Boucle IA — « elle propose, je valide »** : l'IA analyse les remarques d'un essai et
  propose une nouvelle version avec les changements surlignés ; rien n'est créé sans
  validation explicite de l'utilisateur.
- **Approche scientifique** :
  - Chaque essai trace les **paramètres réellement utilisés** (distincts des cibles) pour
    pouvoir rejouer exactement un essai réussi (« refaire exactement cet essai »).
  - **Café/cocktail : une seule variable changée par itération.** Si les remarques impliquent
    plusieurs changements, l'IA les ordonne en plusieurs itérations successives.
  - **Plats/Thermomix : plusieurs variables acceptées** par itération.
- **Itération vs variation** :
  - *Itération* = nouvelle version dans la lignée linéaire de la même recette (v1 → v2 → …).
  - *Variation* = **nouvelle recette liée** (lien « dérivée de… ») avec sa propre lignée —
    ex. Negroni → Negroni blanc.
- **Capture d'essai** : note globale + remarques en texte libre + photo du résultat.
  Pas de dictée vocale, pas de curseurs par critère.
- **Import** : photos (page de livre, capture d'écran), URL ou texte → l'IA structure la
  recette au format fiche → preview éditable → confirmation par l'utilisateur.

## Modèle mental

- **Recette** : appartient à un type ; porte une lignée de **versions**.
  - *Version courante* : la meilleure validée à ce jour — celle qu'on refait.
  - *Version à tester* : proposition IA validée, en attente d'un essai (badge distinct).
- **Essai** : exécution d'une version → paramètres réels + note + remarques + photo.
  Plusieurs essais possibles par version.
- **Variation** : recette séparée, liée par « dérivée de », navigable dans les deux sens
  (mère ↔ dérivée).
- **Promotion** : après un essai concluant, la version « à tester » devient la version
  courante.

## La boucle (parcours central)

1. **Importer** (photo/URL/texte) → preview structurée par l'IA → ajuster → enregistrer (v1).
2. **Exécuter** : fiche d'un coup d'œil, posée à côté de soi ; zéro navigation pendant
   l'exécution.
3. **Noter** : paramètres réels (pré-remplis avec les cibles), note, remarques, photo.
4. **Itérer** : l'IA propose v(n+1) (diff surligné ; 1 variable pour café/cocktail) **ou**
   une variation → valider / modifier / refuser.
5. La version validée devient « à tester » ; essai concluant → **promotion** en version
   courante.

## Écrans (7)

1. **Accueil** : « À tester » en tête, bibliothèque par type, activité récente.
2. **Fiche recette** : version courante lisible ; badge « v(n+1) à tester » ; accès timeline
   des versions et variations liées ; journal d'essais avec photos.
3. **Import** : photo/URL/texte → preview éditable → enregistrer.
4. **Mode exécution** : fiche épurée plein écran → « Terminé → noter ».
5. **Capture d'essai** : paramètres réels, note, texte, photo.
6. **Proposition IA** : diff v(n) → v(n+1) surligné, choix itération vs variation,
   valider/modifier/refuser.
7. **Historique** : timeline des versions (note moyenne, ce qui a changé), liens variations.

## Critères de validation de la maquette

- Chaque parcours de la boucle se déroule de bout en bout sans cul-de-sac.
- La contrainte « 1 variable » est visible et compréhensible sur le parcours café.
- La variation est navigable dans les deux sens.
- La fiche d'exécution est lisible posée sur un plan de travail (gros corps, fort contraste).

## Hors périmètre (cette phase)

Code iOS, backend, choix de stack, comptes/synchro, offline, multi-utilisateur/partage.
