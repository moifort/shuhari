# Tâche : configurer « Sign in with Apple » pour Shuhari

Objectif : activer la connexion Sign in with Apple de l'app iOS **Shuhari** (auth Firebase / Identity Platform). Toute l'infra est déjà prête et **conditionnée** pour s'activer dès que les valeurs ci-dessous sont fournies. Cette tâche = le travail à faire dans le **portail Apple Developer**, puis remonter 3 valeurs + 1 fichier.

## Contexte (constantes déjà fixées, ne pas changer)

| Élément | Valeur |
|---|---|
| Apple Team ID | `46C337T7YN` |
| Bundle ID de l'app (App ID) | `com.polyforms.shuhari.app` |
| Services ID attendu | `com.polyforms.shuhari.signin` |
| Projet Firebase / GCP | `shuhari-polyforms` |
| Domaine d'auth Firebase | `shuhari-polyforms.firebaseapp.com` |
| URL de retour (OAuth) | `https://shuhari-polyforms.firebaseapp.com/__/auth/handler` |

## À faire dans https://developer.apple.com/account (Team 46C337T7YN)

1. **App ID** — Certificates, Identifiers & Profiles → Identifiers → App IDs.
   - Vérifier que l'App ID `com.polyforms.shuhari.app` existe (le créer sinon, type *App*).
   - Cocher la capability **Sign In with Apple** (mode *Enable as a primary App ID*). Sauvegarder.

2. **Services ID** — Identifiers → (filtre *Services IDs*) → +.
   - Identifier : `com.polyforms.shuhari.signin` — Description : `Shuhari Sign In`.
   - Cocher **Sign In with Apple**, puis *Configure* :
     - **Primary App ID** : `com.polyforms.shuhari.app`
     - **Domains and Subdomains** : `shuhari-polyforms.firebaseapp.com`
     - **Return URLs** : `https://shuhari-polyforms.firebaseapp.com/__/auth/handler`
   - Sauvegarder / continuer / enregistrer.

3. **Clé Sign in with Apple** — Keys → +.
   - Nom : `Shuhari Sign In Key`.
   - Cocher **Sign In with Apple**, *Configure* → Primary App ID : `com.polyforms.shuhari.app`.
   - *Continue* → *Register* → **télécharger le fichier `.p8`** (⚠️ téléchargeable **une seule fois**).
   - Noter le **Key ID** (10 caractères) affiché sur la page de la clé.

## À remonter (livrables de la tâche)

1. **Services ID** : `com.polyforms.shuhari.signin` (confirmer qu'il est bien créé + configuré).
2. **Key ID** : `__________` (10 caractères).
3. **Fichier `.p8`** : le fichier `AuthKey_XXXXXXXXXX.p8` téléchargé.
4. (Team ID déjà connu : `46C337T7YN`.)

## Câblage repo (fait ensuite avec ces valeurs — pas par dispatch)

Une fois les 3 livrables en main :

1. Déposer le `.p8` en `infra/apple.p8`.
2. Dans `infra/terraform.tfvars` : `apple_key_id = "<KEY_ID>"` (les autres champs Apple sont déjà bons).
3. Secrets GitHub (repo `moifort/shuhari`) :
   - `APPLE_TEAM_ID` = `46C337T7YN`
   - `APPLE_SERVICES_ID` = `com.polyforms.shuhari.signin`
   - `APPLE_KEY_ID` = `<KEY_ID>`
   - `APPLE_PRIVATE_KEY_P8` = contenu texte intégral du `.p8`
4. `terraform apply` (ou un push sur `main`) → active le provider Apple dans Identity Platform (`auth.tf` le crée automatiquement dès que `apple_key_id` est renseigné).

Côté app iOS, rien à faire : l'entitlement `com.apple.developer.applesignin` et le flux `SignInWithAppleButton → OAuthProvider.appleCredential` sont déjà en place.
