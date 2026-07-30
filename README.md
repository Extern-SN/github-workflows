# ExternIT Reusable Workflows

Workflows GitHub Actions réutilisables pour tous les services ExternIT.

## Workflows disponibles

| Fichier | Description |
|---------|-------------|
| `docker-build.yml` | Build Docker + Trivy + push avec attestations |
| `php-tests.yml` | Tests PHPUnit (sans base de données) |
| `php-tests-db.yml` | Tests PHPUnit avec service de base de données |
| `js-tests.yml` | Tests JavaScript/TypeScript avec couverture |
| `python-tests.yml` | Lint + tests Python (pytest) avec cache pip |

---

## docker-build.yml

```yaml
jobs:
  docker:
    uses: ExternIT-repo/github-workflows/.github/workflows/docker-build.yml@main
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
    uses: ExternIT-repo/github-workflows/.github/workflows/php-tests.yml@main
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
    uses: ExternIT-repo/github-workflows/.github/workflows/php-tests-db.yml@main
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
    uses: ExternIT-repo/github-workflows/.github/workflows/js-tests.yml@main
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
    uses: ExternIT-repo/github-workflows/.github/workflows/python-tests.yml@main
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
