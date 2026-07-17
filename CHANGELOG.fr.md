# Journal des modifications

Toutes les évolutions notables de Shuhari, la plus récente en premier.

## Unreleased

### New

- Shuhari se recentre sur la **cuisine** : deux types de recettes, **Plat** et **Thermomix** (le café et le cocktail reviendront plus tard). Les onglets se réduisent à **Carnet** et **Importer**.
- Chaque recette porte désormais une **catégorie de plat** (entrée, plat, dessert, soupe, sauce, boulangerie), **détectée automatiquement à l'import**, modifiable dans l'aperçu et affichée sur la fiche.
- Notation des essais **de 1 à 5 étoiles** : une version devient la référence **dès qu'un essai atteint 4 étoiles**.
- Propositions d'itération repensées : l'IA fournit un **brouillon complet de la version suivante** — résumé du changement, justification, ingrédients et étapes — que l'on peut **modifier avant de l'accepter**.
- Fiche et exécution s'appuient désormais sur les **ingrédients et les étapes** : les paramètres réglables disparaissent au profit d'une recette plus simple à lire et à refaire.
- Carnet : la bibliothèque se **charge en continu** (chargement paginé) et propose un **tri** — **Type de plat** ou **Dernière modification** — à côté du filtre Plat / Thermomix.
- **Attention** : à la suite de ces changements, les **sauvegardes exportées avant cette version ne peuvent plus être restaurées**.
- Fiche recette : affichage façon visionneuse Photos — **pastille de titre** avec la date de création, badges **type / version / essais** avec la note moyenne en **étoiles**, **ingrédients intégrés** à la page puis la **meilleure version** en description ; en bas, un bécher pour la version « à tester », un **bouton rond pour noter un essai** et l'**historique en panneau**.
- Noter un essai : nouvel écran « Remarque » en demi-écran — note en **5 étoiles**, champ de remarques plus spacieux, ajout de **plusieurs photos** ; validation par une coche en haut.
- Carnet : chaque recette affiche son **nombre de versions** et sa **meilleure note**.
- Icônes : nouveaux symboles dédiés — **tasse espresso** pour le café, verre à martini pour les cocktails, toque pour la cuisine, **bécher** pour les essais, variantes contour/rempli du Thermomix.
- Import : les **ingrédients** sont désormais extraits avec leurs quantités, séparément des paramètres — modifiables à l'import et affichés sur la fiche recette.
- Import : l'analyse de la recette s'affiche dans une feuille dédiée avec l'animation « écoute » de Siri, et l'aperçu adopte un style natif (Fermer et validation par une coche en haut, type avec icône, étapes modifiables, titre remis en casse normale, sections vides masquées).
- Import : l'animation d'analyse est plus fluide et se fond en douceur dans l'aperçu une fois la recette prête.
- Recette : supprimer une recette demande une confirmation et la liste se met à jour aussitôt.
- Le raccourci d'import (appareil photo) apparaît désormais dans son propre bouton distinct, à droite de la barre d'onglets, séparé des catégories.
- Import par photo : on peut désormais prendre une photo d'une recette directement avec l'appareil photo, en plus de la choisir dans la bibliothèque, d'un lien ou d'un texte.
- Recettes Thermomix : l'import extrait désormais les réglages de chaque étape (temps, température, vitesse, sens inverse), affichés en badges sur la fiche recette et l'aperçu d'import.
- Première version : import de recettes assisté par IA, boucle d'expérimentation (exécuter, noter, itérer), propositions d'itération par l'IA, promotion de version et variations.

### Fixes

- Les recettes dont un ingrédient porte un nom descriptif (long) s'importent désormais sans erreur.
- Import : choisir ou prendre une photo ferme l'appareil photo avant d'ouvrir l'aperçu.
- Fermer l'import ramène à la catégorie d'origine (l'onglet ne reste plus bloqué sur une page vide).
