# Extern SN Reusable Workflows

Workflows GitHub Actions réutilisables pour tous les services Extern SN.

## Workflows disponibles

| Fichier | Description |
|---------|-------------|
| `docker-build.yml` | Build Docker + Trivy + push avec attestations |
| `php-tests.yml` | Tests PHPUnit (sans base de données) |
| `php-tests-db.yml` | Tests PHPUnit avec service de base de données |
| `js-tests.yml` | Tests JavaScript/TypeScript avec couverture |
| `python-tests.yml` | Lint + tests Python (pytest) avec cache pip |
| `release-tag.yml` | Tag SemVer au merge sur `main`, changelog et GitHub Release |
| `validate-pr.yml` | Contrôle du nommage de branche et du label de release |
| `auto-label.yml` | Pose du label de release depuis le préfixe de branche |
| `php-lint.yml` | Analyse statique PHP (phpstan) |
| `ci-security.yml` | Audit des workflows GitHub Actions (actionlint + zizmor) |
| `debt-report.yml` | Rapport récurrent de dette technique pour les stacks LEGACY ou EOL |

## Scripts d'entretien

Outils de parc, exécutés à la main, hors CI.

| Dossier | Description |
|---------|-------------|
| `scripts/registre/` | Inventaire et purge des tags d'un dépôt Docker Hub, liste de conservation construite sur le cluster |

---

## docker-build.yml

```yaml
jobs:
  docker:
    uses: Extern-SN/github-workflows/.github/workflows/docker-build.yml@v1
    with:
      registry: docker.io                      # ou ghcr.io
      image-name: myorg/myapp
      build-args: |
        APP_ENV=prod
        API_BASE_URL=https://api.example.com
      push: ${{ github.ref == 'refs/heads/main' }}
      with-trivy: true
      notify-on-failure: true
      smoke-test-script: scripts/ci-smoke-test.sh
    secrets:
      registry-username: ${{ secrets.DOCKERHUB_USERNAME }}
      registry-token: ${{ secrets.DOCKERHUB_TOKEN }}
      failure-notification-webhook: ${{ secrets.FAILURE_NOTIFICATION_WEBHOOK }}
```

**Inputs**

| Nom | Type | Défaut | Description |
|-----|------|--------|-------------|
| `registry` | string | — | Registre cible |
| `image-name` | string | — | Nom image sans registre |
| `dockerfile` | string | `Dockerfile` | Chemin du Dockerfile |
| `context` | string | `.` | Contexte de build |
| `build-args` | string | `` | Arguments passés à `docker buildx` via `build-args` |
| `push` | bool | `true` | Pousser après les tests |
| `with-trivy` | bool | `true` | Scan CVE Trivy |
| `notify-on-failure` | bool | `false` | Envoie une notification webhook générique si le workflow échoue |
| `trivy-ignore-file` | string | `.trivyignore` | Fichier d'exceptions Trivy, passé à Trivy seulement s'il existe |
| `free-disk-space` | bool | `false` | Libère l'espace du runner avant le build. À activer pour une image volumineuse : Trivy exporte l'image dans `/tmp` avant de l'analyser, et le cumul image de base + image construite + cache de build + export remplit un runner standard |
| `with-sha-tag` | bool | `false` | Pousse en plus un tag portant le SHA court du commit. Désactivé par défaut : encombre le registre sans usage identifié |
| `smoke-test-script` | string | `scripts/ci-smoke-test.sh` | Script de smoke test exécuté si présent |

**Secrets**

| Nom | Requis | Description |
|-----|--------|-------------|
| `registry-username` | oui | Identifiant du registre |
| `registry-token` | oui | Token du registre |
| `failure-notification-webhook` | non | Webhook HTTP POST appelé à la fin du workflow si une étape a échoué et que `notify-on-failure` vaut `true` |

**Payload de notification**

Le webhook reçoit un JSON simple, volontairement agnostique du provider:

```json
{
  "status": "failure",
  "repository": "owner/repo",
  "ref": "dev",
  "workflow": "Docker Build & Push",
  "run_url": "https://github.com/owner/repo/actions/runs/123456789",
  "message": "Docker build workflow failed for owner/repo on dev"
}
```

---

## php-tests.yml

```yaml
jobs:
  tests:
    uses: Extern-SN/github-workflows/.github/workflows/php-tests.yml@v1
    with:
      php-version: '8.2'
      test-command: 'composer test:coverage'
      coverage-type: badge        # badge | none
```

**Inputs**

| Nom | Type | Défaut | Description |
|-----|------|--------|-------------|
| `php-version` | string | — | Version PHP |
| `extensions` | string | `mbstring, intl, xml, dom, curl, zip` | Extensions PHP installées, séparées par des virgules |
| `install-command` | string | `composer install --prefer-dist ...` | Installation des dépendances |
| `test-command` | string | — | Commande de test |
| `coverage-type` | string | `none` | `badge` ou `none` |
| `coverage-xml-path` | string | `coverage.xml` | Rapport de couverture au format clover |
| `badge-output` | string | `badges/php-coverage.svg` | Chemin du badge généré |
| `badge-branch` | string | `main` | Branche sur laquelle le badge est commité |

---

## php-tests-db.yml

```yaml
jobs:
  tests:
    uses: Extern-SN/github-workflows/.github/workflows/php-tests-db.yml@v1
    with:
      php-version: '8.4'
      test-command: 'composer test-with-coverage'
      bootstrap-command: 'composer bootstrap-test-environment'
      db-image: 'mysql:8.4'
      db-name: 'myapp_test'
      database-url: 'mysql://root:test@127.0.0.1:3306/myapp_test?serverVersion=8.4'
      coverage-type: badge
```

**Inputs**

| Nom | Type | Défaut | Description |
|-----|------|--------|-------------|
| `php-version` | string | — | Version PHP |
| `extensions` | string | `mbstring, intl, xml, dom, curl, zip` | Extensions PHP installées |
| `install-command` | string | `composer install --prefer-dist ...` | Installation des dépendances |
| `bootstrap-command` | string | `` | Commande jouée avant les tests (migrations, fixtures) |
| `test-command` | string | — | Commande de test |
| `db-image` | string | — | Image du service de base (`mysql:8.4`, `postgres:16`) |
| `db-name` | string | `test_db` | Base créée pour les tests |
| `db-root-password` | string | `test` | Mot de passe root du service de test. **Valeur de test, jamais un secret de production** : elle vit le temps du job, dans un service qui n'est joignable que depuis le runner |
| `database-url` | string | — | `DATABASE_URL` passée aux commandes de bootstrap et de test |
| `coverage-type` | string | `none` | `badge` ou `none` |
| `coverage-xml-path` | string | `coverage.xml` | Rapport de couverture au format clover |
| `badge-output` | string | `badges/php-coverage.svg` | Chemin du badge généré |
| `badge-branch` | string | `main` | Branche sur laquelle le badge est commité |

---

## php-lint.yml

```yaml
jobs:
  lint:
    uses: Extern-SN/github-workflows/.github/workflows/php-lint.yml@v1
    with:
      php-version: '8.2'
      lint-command: 'vendor/bin/phpstan analyse --no-progress'
```

**Inputs**

| Nom | Type | Défaut | Description |
|-----|------|--------|-------------|
| `php-version` | string | — | Version PHP |
| `extensions` | string | `mbstring, intl, xml, dom, curl, zip` | Extensions PHP installées |
| `install-command` | string | `composer install --prefer-dist ...` | Installation des dépendances |
| `lint-command` | string | `vendor/bin/phpstan analyse --no-progress` | Commande d'analyse statique. Le périmètre analysé se règle dans la configuration du projet (`phpstan.neon`), pas ici |

---

## js-tests.yml

```yaml
jobs:
  tests:
    uses: Extern-SN/github-workflows/.github/workflows/js-tests.yml@v1
    with:
      node-version: '22'
      test-command: 'npm run test:coverage'
      coverage-type: badge
```

**Inputs**

| Nom | Type | Défaut | Description |
|-----|------|--------|-------------|
| `node-version` | string | `22` | Version Node |
| `install-command` | string | `npm ci` | Installation des dépendances |
| `test-command` | string | `npm run test:coverage` | Commande de test |
| `coverage-type` | string | `none` | `badge`, `codecov` ou `none` |
| `coverage-summary-path` | string | `coverage/coverage-summary.json` | Résumé de couverture au format Istanbul/V8 |
| `badge-output` | string | `badges/js-coverage.svg` | Chemin du badge généré |
| `badge-branch` | string | `main` | Branche sur laquelle le badge est commité |

**Secrets**

| Nom | Requis | Description |
|-----|--------|-------------|
| `codecov-token` | non | Jeton Codecov, nécessaire seulement si `coverage-type: codecov` |

---

## python-tests.yml

```yaml
jobs:
  tests:
    uses: Extern-SN/github-workflows/.github/workflows/python-tests.yml@v1
    with:
      python-version: '3.12'
      install-command: 'pip install -e .[dev]'
      lint-command: 'ruff check src tests'
      test-command: 'pytest -q'
```

**Inputs**

| Nom | Type | Défaut | Description |
|-----|------|--------|-------------|
| `python-version` | string | `3.12` | Version Python |
| `install-command` | string | `pip install -e .[dev]` | Installation des dépendances |
| `lint-command` | string | `` | Lint (ignoré si vide) |
| `test-command` | string | `pytest -q` | Commande de test |
| `cache-dependency-path` | string | `**/pyproject.toml` | Fichier(s) dont le hash invalide le cache pip ; doit matcher au moins un fichier |

---

## release-tag.yml

```yaml
on:
  push:
    branches: [main]
    paths-ignore: ['CHANGELOG.md', 'badges/**']

jobs:
  release:
    permissions:
      contents: write
      pull-requests: read
      actions: write
    uses: Extern-SN/github-workflows/.github/workflows/release-tag.yml@v1
    with:
      changelog-file: CHANGELOG.md
      create-release: true
```

**Inputs**

| Nom | Type | Défaut | Description |
|-----|------|--------|-------------|
| `docker-workflow-file` | string | `docker-build.yml` | Workflow déclenché en `workflow_dispatch` après la création du tag. **Chaîne vide pour un dépôt qui ne construit pas d'image** : l'étape est sautée au lieu d'échouer sur un workflow absent |
| `changelog-file` | string | `` | Changelog Keep a Changelog. Sa section `## [Non publié]` est promue en version datée avant le tag. Vide pour désactiver |
| `create-release` | boolean | `false` | Publie une GitHub Release, corps repris de la section promue |
| `sync-branch` | string | `` | Branche de développement vers laquelle reporter le commit de promotion du changelog. Sans ce report, la branche de développement garde en « Non publié » des entrées déjà publiées, et la release suivante les republie sous un nouveau numéro |
| `major-alias` | boolean | `false` | Repositionne le tag majeur mobile (`v1` pour `v1.4.2`) sur la version publiée. À n'activer que sur un dépôt dont les consommateurs appellent ce tag mobile : le déplacement les met à jour immédiatement, sans revue de leur côté |

Si `changelog-file` est renseigné, le workflow pousse un commit de publication sur
`main`. **Le dépôt appelant doit exclure ce fichier de son propre déclencheur**
(`paths-ignore`), sans quoi ce push relance un run qui échouera faute de PR
mergée associée.

---

## validate-pr.yml

```yaml
on:
  pull_request:
    branches: [dev, main]
    types: [opened, edited, synchronize, labeled, unlabeled]

jobs:
  validate:
    uses: Extern-SN/github-workflows/.github/workflows/validate-pr.yml@v1
```

**Inputs**

| Nom | Type | Défaut | Description |
|-----|------|--------|-------------|
| `enforce-naming-on-base` | string | `dev` | Branche de base sur laquelle la règle de nommage s'applique. `*` pour toutes |
| `branch-pattern` | string | `^(feature\|fix\|hotfix)/.+$` | Motif que doit respecter la branche source |
| `labels` | string | les 5 labels du Groupe | Labels de release acceptés, un par ligne |

---

## auto-label.yml

```yaml
on:
  pull_request:
    types: [opened]

jobs:
  label:
    permissions:
      pull-requests: write
    uses: Extern-SN/github-workflows/.github/workflows/auto-label.yml@v1
```

**Inputs**

| Nom | Type | Défaut | Description |
|-----|------|--------|-------------|
| `prefix-map` | string | `{"feature/": "feature", "fix/": "fix", "hotfix/": "hotfix"}` | Correspondance préfixe de branche vers label, en JSON |
| `integration-branch` | string | `dev` | Branche dont le label se déduit des PR transportées. Vide pour désactiver |
| `label-ranking` | string | `["breaking", "feature", "fix", "hotfix", "chore"]` | Labels de version du plus fort au plus faible |

`chore` et `breaking` ne se déduisent pas d'un nom de branche et restent à poser
à la main sur une PR ordinaire.

**Les PR d'intégration**

Une branche d'intégration s'appelle `dev` et ne dit donc **rien de son contenu**.
Le préfixe ne peut rien en déduire, et une PR `dev` vers `main` échouait de ce
fait **systématiquement** au contrôle des conventions. Pire, `release-tag.yml`
se rabattait alors sur un incrément de correctif : une fonctionnalité sortait
sous un numéro de patch.

Les PR que l'intégration transporte, elles, sont toutes labellisées, c'est la
règle du dépôt. L'information existe déjà, ce workflow la lit : il relève les
numéros de PR dans les messages de commit (commit de fusion ou titre suffixé
après un squash), récupère leurs labels, et retient **le plus fort** selon
`label-ranking`.

Une seule `feature` parmi dix `fix` impose donc un incrément mineur, ce qui est
le comportement attendu : la fonctionnalité ne doit pas sortir sous un numéro de
correctif.

Si aucune PR transportée ne porte de label, le job **n'échoue pas**, il émet un
avertissement. C'est `validate-pr.yml` qui bloque la fusion, avec son message à
lui. Deux checks rouges pour une même cause n'aident personne.

> [!note]
> Le job ne pose jamais un second label sur une PR qui en porte déjà un de
> version : `validate-pr.yml` en exige **exactement un**, et un second ferait
> échouer le contrôle au lieu de le satisfaire.

---

## debt-report.yml

```yaml
on:
  schedule:
    - cron: '0 8 1 * *'   # le 1er de chaque mois, 08:00 UTC
  workflow_dispatch:

jobs:
  dette:
    permissions:
      issues: write
    uses: Extern-SN/github-workflows/.github/workflows/debt-report.yml@v1
    with:
      stack: PHP 7.2-apache
      motif: >
        Debian buster est EOL, ses dépôts APT sont servis depuis l'archive.
        Le scan Trivy est désactivé dans docker-build.yml, il échouerait
        quasi systématiquement sur cette base.
      echeance: Montée en PHP 8.3 à planifier, non arbitrée à ce jour.
```

Le SDU rend ce workflow **obligatoire dès qu'une stack est LEGACY ou EOL**. La
logique du référentiel mérite d'être comprise avant d'être appliquée : un projet
EOL n'est pas pénalisé parce qu'il est vieux, il l'est parce qu'il est vieux
**sans être traité comme tel**. Le traitement attendu tient en deux choses,
l'image applicative gelée sur un tag `legacy-frozen-<version>`, et la dette
suivie par ce rapport. Sans elles, la note du projet est plafonnée au grade C
quel que soit le reste de la chaîne.

Le workflow crée une issue de suivi, puis la met à jour à chaque exécution en y
ajoutant un rappel numéroté. **C'est le compteur qui fait la valeur du ticket** :
une issue portant 14 rappels dit en un coup d'oeil que la dette a 14 mois, ce
qu'aucun ticket ouvert une seule fois ne dira jamais.

Le job ne fait **aucun checkout** : il ne lit pas le dépôt, il n'écrit qu'une
issue. Ne pas cloner évite de laisser un jeton dans le répertoire de travail.

**Inputs**

| Nom | Type | Défaut | Description |
|-----|------|--------|-------------|
| `stack` | string | — | Stack concernée, nommée comme au référentiel SDU |
| `statut` | string | `EOL` | Statut SDU de la stack : `EOL` ou `LEGACY` |
| `motif` | string | `` | Ce qui bloque ou ce que la situation impose |
| `echeance` | string | `` | Échéance de sortie de dette, si elle est arbitrée |
| `label` | string | `dette-technique` | Label posé sur l'issue, créé s'il manque. Vide pour aucun label |
| `titre` | string | `` | Titre de l'issue. Par défaut construit depuis la stack |

Laisser `echeance` vide n'est pas un oubli, c'est une information : le ticket
écrit alors noir sur blanc qu'aucune échéance n'est arbitrée.

Le titre est la **clé de rapprochement** entre deux exécutions. Le changer après
coup fait repartir le compteur de rappels à zéro et perd l'historique de la
dette.

**Dependabot et les stacks EOL**

Sur un dépôt en stack EOL, ne pas activer les écosystèmes `composer` et `docker`
de Dependabot : le premier proposera des paquets exigeant un runtime plus récent,
le second proposera de sortir de l'image gelée, ce qui **contredit le traitement
EOL**. Seul l'écosystème `github-actions` est utilisable tel quel, et il suffit à
satisfaire le contrôle OpenSSF `Dependency-Update-Tool`, qui est un contrôle de
présence.


## ci-security.yml

```yaml
on:
  pull_request:
    paths: ['.github/workflows/**']
  push:
    branches: [main, dev]
    paths: ['.github/workflows/**']

jobs:
  security:
    uses: Extern-SN/github-workflows/.github/workflows/ci-security.yml@v1
```

Audite les workflows du dépôt appelant avec **actionlint** (validité, expressions,
shellcheck sur les blocs `run`) et **zizmor** (injection de template, déclencheurs
dangereux, permissions trop larges, actions non épinglées).

Aucun SAST applicatif ne couvre ce périmètre : PHPStan analyse du PHP, pas le YAML
de `.github/workflows`. C'est pourtant là que se logent les injections de script,
qui s'exécutent dans le runner avec le jeton du dépôt.

**Inputs**

| Nom | Type | Défaut | Description |
|-----|------|--------|-------------|
| `min-severity` | string | `high` | Sévérité zizmor à partir de laquelle le job échoue |
| `zizmor-config` | string | `zizmor.yml` | Configuration zizmor du dépôt appelant, ignorée si absente |
| `actionlint-version` | string | `1.7.7` | Version d'actionlint installée |
| `shellcheck-min-severity` | string | `warning` | Sévérité shellcheck à partir de laquelle actionlint remonte un constat sur les blocs `run` : `style`, `info`, `warning` ou `error`. Le défaut écarte les constats de style, souvent faux sur du php, du awk ou du python passé en ligne de commande. Les erreurs propres à actionlint ne sont pas concernées |

Une configuration `zizmor.yml` à la racine permet d'assouplir la politique
d'épinglage. Celle de ce dépôt accepte les tags pour `actions/*` et `Extern-SN/*`,
et exige un SHA pour toute action tierce :

```yaml
rules:
  unpinned-uses:
    config:
      policies:
        "actions/*": ref-pin
        "Extern-SN/*": ref-pin
        "*": hash-pin
```

---

## Épinglage de version

Les nouveaux exemples pointent sur `@v1`, pas sur `@main`. Ces workflows
s'exécutent avec `contents: write` sur la branche de production des dépôts
appelants : un commit sur `main` de ce dépôt se propagerait autrement à tout le
parc sans revue côté consommateur.

- `@v1` est un tag mobile, avancé délibérément après relecture.
- `@vX.Y.Z` épingle une version précise.
- `@main` ne devrait plus être utilisé par un nouveau dépôt.

Depuis la version `v1.3.0`, le tag `v1` est déplacé par la chaîne elle-même à
chaque publication (entrée `major-alias` de `release-tag.yml`). Il pointe donc
toujours sur la dernière version `v1.x.y` relue et taguée, sans manœuvre
manuelle : le 2026-09-18, `v1` était resté six commits en arrière, et les
correctifs publiés la veille n'atteignaient aucun dépôt du parc.

Tous les exemples de ce README sont en `@v1`. Un dépôt encore en `@main` est à
migrer.

---

## Triggers recommandés (éviter les doublons)

```yaml
on:
  pull_request:
    paths-ignore: ['badges/**']
  push:
    branches: [main, dev]
    paths-ignore: ['badges/**']
```

Les badges ne sont commités que sur `push` (jamais sur `pull_request`).
