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
| `ci-security.yml` | Audit des workflows GitHub Actions (actionlint + zizmor) |

---

## docker-build.yml

```yaml
jobs:
  docker:
    uses: Extern-SN/github-workflows/.github/workflows/docker-build.yml@main
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
| `trivy-ignore-file` | string | `.trivyignore` | Fichier d'exceptions Trivy |
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
    uses: Extern-SN/github-workflows/.github/workflows/php-tests.yml@main
    with:
      php-version: '8.2'
      test-command: 'composer test:coverage'
      coverage-type: badge        # badge | none
```

---

## php-tests-db.yml

```yaml
jobs:
  tests:
    uses: Extern-SN/github-workflows/.github/workflows/php-tests-db.yml@main
    with:
      php-version: '8.4'
      test-command: 'composer test-with-coverage'
      bootstrap-command: 'composer bootstrap-test-environment'
      db-image: 'mysql:8.4'
      db-name: 'myapp_test'
      database-url: 'mysql://root:test@127.0.0.1:3306/myapp_test?serverVersion=8.4'
      coverage-type: badge
```

---

## js-tests.yml

```yaml
jobs:
  tests:
    uses: Extern-SN/github-workflows/.github/workflows/js-tests.yml@main
    with:
      node-version: '22'
      test-command: 'npm run test:coverage'
      coverage-type: badge
```

---

## python-tests.yml

```yaml
jobs:
  tests:
    uses: Extern-SN/github-workflows/.github/workflows/python-tests.yml@main
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
| `docker-workflow-file` | string | `docker-build.yml` | Workflow déclenché en `workflow_dispatch` après la création du tag |
| `changelog-file` | string | `` | Changelog Keep a Changelog. Sa section `## [Non publié]` est promue en version datée avant le tag. Vide pour désactiver |
| `create-release` | boolean | `false` | Publie une GitHub Release, corps repris de la section promue |

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

`chore` et `breaking` ne se déduisent pas d'un nom de branche et restent à poser
à la main.

---

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

Les exemples plus anciens de ce README sont encore en `@main`, le temps que les
dépôts consommateurs migrent.

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
