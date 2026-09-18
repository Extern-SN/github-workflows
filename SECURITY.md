# Politique de sécurité

Ce dépôt porte les workflows GitHub Actions appelés par l'ensemble des dépôts du
Groupe Extern. Une vulnérabilité ici se propage à tout le parc : elle se traite
avec la même urgence qu'une vulnérabilité en production.

## Signaler une vulnérabilité

Écrire à **David GRÉGOIRE (RSSI)**, sans ouvrir d'issue publique et sans publier
de démonstration. Une issue décrivant une faille d'un workflow réutilisable
indique à un attaquant quoi viser sur les dépôts qui l'appellent.

Indiquer le workflow concerné, la version (tag) observée, et le chemin
d'exploitation. Une réponse est apportée sous deux jours ouvrés.

## Versions suivies

Seule la série `v1` reçoit des correctifs. Les dépôts consommateurs appellent
`Extern-SN/github-workflows/.github/workflows/<workflow>.yml@v1` : le tag `v1`
suit la dernière version `v1.x.y` publiée.

Un appel en `@main` n'est pas supporté : il expose le dépôt appelant à un
changement non publié, et il est signalé comme non conforme par l'audit SDU.

## Ce que la chaîne garantit, et ce qu'elle ne garantit pas

`ci-security.yml` fait tourner actionlint et zizmor sur les workflows du dépôt
appelant. Il contrôle l'écriture des workflows, pas le code applicatif.

`docker-build.yml` construit l'image et la scanne avec Trivy. Le scan ne
s'exécute réellement que si le dépôt fournit les entrées attendues : un job vert
sur un dépôt mal configuré ne vaut pas attestation d'absence de vulnérabilité.

Le contrôle des secrets commités relève de l'audit SDU (`sdu-audit`), pas de
cette chaîne.
