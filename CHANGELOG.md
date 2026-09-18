# Changelog

Toutes les évolutions notables de ce dépôt sont consignées ici, au format
[Keep a Changelog](https://keepachangelog.com/fr/1.1.0/), versionné selon
[SemVer](https://semver.org/lang/fr/).

Les dépôts consommateurs appellent ces workflows par le tag mobile `v1`, qui
suit la dernière version `v1.x.y` publiée. Lire une entrée ci-dessous, c'est
donc lire un changement qui s'applique à tout le parc.

Ce changelog a été reconstitué le 2026-09-18 à partir des tags et des PR
mergées. Les versions antérieures à `v1.0.0` n'ont jamais été taguées : la
mutualisation des workflows a commencé en juillet 2026 et la série git démarre
au 2026-09-14.

## [Non publié]

## [v1.3.0] - 2026-09-18

### Ajouté

- Le dépôt applique désormais à lui-même la chaîne qu'il fournit au parc :
  `ci.yml` (audit des workflows, contrôle des scripts et du contrat de
  documentation), `validate-pr.yml` et `release-tag.yml` en appelants.
- `release-tag.yml` : entrée `major-alias`, qui repositionne le tag majeur
  mobile (`v1`) sur la version qui vient d'être publiée. Sans elle, ce
  déplacement est une manœuvre manuelle, et une manœuvre manuelle finit par ne
  pas être faite : le 2026-09-18, `v1` pointait encore six commits en arrière,
  et aucun dépôt du parc ne recevait les correctifs publiés la veille.
- `CHANGELOG.md`, `SECURITY.md`, `.gitignore` et `dependabot.yml`, ce dernier
  parce qu'une action épinglée par SHA ne reçoit plus ses correctifs de sécurité
  sans mise à jour explicite.

### Corrigé

- L'exemple d'appel d'`auto-label.yml`, dans le README comme dans l'en-tête du
  workflow, n'accordait que `pull-requests: write`. Un bloc `permissions` sur un
  job met à `none` tout ce qu'il ne nomme pas, et le workflow appelé exige
  `contents: read` : tout consommateur suivant l'exemple échouait **au
  démarrage**, sans job créé et sans log exploitable.
- `persist-credentials: false` sur les `actions/checkout` qui n'ont pas besoin
  d'écrire (zizmor `artipacked`, 7 occurrences).
- `php-tests-db.yml` : image de service de base de données épinglée (zizmor
  `unpinned-images`).
- `self-security.yml` : syntaxe d'appel interne `$/...` (zizmor
  `self-repository`).

## [v1.2.0] - 2026-09-15

### Ajouté

- `release-tag.yml` : deux garde-fous après deux releases erronées. Une PR sans
  label de version fait échouer le workflow au lieu d'être traitée comme un
  correctif ; une section de changelog promue sans contenu le fait échouer avant
  tout commit, tag ou release (#13).

### Corrigé

- `ci-security.yml` : zizmor tourne même quand actionlint relève un constat, les
  deux outils étant indépendants (#14).

## [v1.1.0] - 2026-09-15

### Ajouté

- `ci-security.yml` : audit des workflows GitHub Actions par actionlint et
  zizmor, et épinglage de l'action de pose de labels (#12).

## [v1.0.0] - 2026-09-14

Première version taguée de la chaîne mutualisée.

### Ajouté

- `validate-pr.yml` et `auto-label.yml` mutualisés : contrôle du nommage de
  branche et du label de release, pose du label depuis le préfixe de branche.
- `release-tag.yml` : promotion de la section « Non publié » du changelog et
  publication d'une GitHub Release en plus du tag (#11).
- `release-tag.yml` mutualisé en workflow réutilisable, corrigeant le bug du
  premier tag (#10).
- `php-lint.yml` (phpstan) et `python-tests.yml` (lint + pytest avec cache pip)
  (#5, #7).
- `docker-build.yml`, `php-tests.yml`, `php-tests-db.yml` et `js-tests.yml`,
  socle initial de la chaîne.

### Corrigé

- Cache Composer inopérant, couverture pcov conditionnelle, épinglage de
  `trivy-action` (#4, #6).
- Tag SHA désactivé par défaut, qui encombrait le registre (#1).
