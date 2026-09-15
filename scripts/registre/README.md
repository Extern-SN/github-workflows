# Entretien des registres d'images

Trois scripts de parc pour tenir un dépôt Docker Hub. Ils s'utilisent **dans cet
ordre**, et l'ordre est le fond du sujet.

| Script | Rôle | Écrit ? |
|---|---|---|
| `registre-inventaire.sh` | volume stocké, tags, statut actif/inactif | non |
| `registre-references.sh` | tags réellement déployés, lus sur le cluster | non |
| `registre-purge.sh` | retrait de tags, simulation par défaut | oui, avec `--execute` |

## L'ordre

```bash
# 1. lire le registre
./registre-inventaire.sh monorg/monapp

# 2. lire le cluster, et en faire la liste de conservation
./registre-references.sh monorg/monapp > /tmp/deployes.txt

# 3. simuler
./registre-purge.sh monorg/monapp --garder-fichier /tmp/deployes.txt

# 4. agir, seulement après avoir relu la sortie de l'étape 3
./registre-purge.sh monorg/monapp --garder-fichier /tmp/deployes.txt --execute
```

L'étape 2 n'est pas une commodité. Elle existe parce qu'elle a manqué.

> Le 2026-09-15, une purge a été préparée sur la foi d'une seule réponse humaine,
> « la production est en 2.1.1 ». Elle était exacte, et incomplète : le cluster
> portait **quatre** références à cette image, dont un `:latest` en production.
> Rien de supprimé n'était référencé, par chance et non par méthode.
>
> Une question posée à quelqu'un rend **une** réponse. Un cluster en porte autant
> qu'il a d'objets.

## Les deux règles de la purge

**On déclare ce qu'on garde, jamais ce qu'on retire.** Une liste de retrait ignore
les tags apparus depuis sa rédaction ; une liste de conservation, non. Le tag
inconnu survit par défaut.

**Un tag qui n'est pas un numéro SemVer est un pointeur.** Il désigne un
environnement ou une branche, pas un artefact. Protégé d'office, il ne part qu'en
étant nommé dans `--retirer-pointeurs`.

Cette seconde règle remplace un garde-fou en pourcentage qui refusait d'agir
au-delà de 80% des tags visés. Il n'a rien vu : `prod` et `recette` figuraient
dans les visés, et 12 sur 17 fait 70%.

> Un compte ne dit rien d'un rôle. Un garde-fou volumétrique protège de la
> maladresse, pas de l'erreur de raisonnement, et c'est la seconde qui coûte cher.

## Ce que ces scripts ne font pas

**Ils ne touchent pas aux manifestes sans tag.** Retirer un tag retire le nom, pas
le manifeste : l'image reste, orpheline, et c'est elle qui remplit la page
*Image Management* de Docker Hub. L'API d'inventaire des manifestes répond `404`
sur une offre non éligible, ce volet reste donc manuel.

> [!warning] Ne jamais vider la page « sans tag » sans regarder
> `docker-build.yml` pousse avec `provenance: true` et `sbom: true`. Ces
> attestations **sont** des manifestes sans tag, rattachés à l'index d'images qui,
> elles, sont bien taguées. Les retirer détruit la provenance et le SBOM de tags
> en service, sans que ces tags disparaissent. Le dégât reste invisible jusqu'au
> jour où il faut prouver d'où vient une image en production.

**Ils ne remplacent pas une déclaration du tag déployé.** Si rien dans git ne dit
quelle version tourne, `registre-references.sh` est le seul recours, et il suppose
un accès au cluster. Déclarer le tag dans les manifestes reste la vraie réponse.

## Ce qu'une purge de tags ne règle pas

Relevé sur `ndiasexternit/wordpress-direxi` après un passage complet de ces
scripts, 17 tags ramenés à 7 :

| Mesure | Valeur |
|---|---|
| somme brute des 7 tags restants | 3,6 Go, couches largement partagées |
| `storage_size` réel du dépôt | **62,41 Go** |

**Environ 95% du volume est dans des manifestes sans tag.** Une purge de tags est
donc un travail d'hygiène et de lisibilité, pas une opération de stockage. Le
mesurer avant de s'y lancer évite de chercher des gigaoctets là où il n'y en a pas :
`registre-inventaire.sh` affiche `storage_size` en premier pour cette raison.

L'origine est structurelle. Un pointeur mutable comme `dev` désigne une nouvelle
image à chaque build et abandonne la précédente, qui perd son seul nom. Soixante
builds font soixante orphelins.

## Tags immuables

`registre-inventaire.sh` rend aussi `immutable_tags_settings`. Activés, les tags
immuables interdisent d'écraser un tag existant, ce qui est la garantie qui manque
quand un déploiement affirme tourner sur `2.1.1` sans que rien ne prouve que le
`2.1.1` d'aujourd'hui soit celui d'hier.

> [!warning] Ne jamais activer la règle par défaut `.*`
> Elle couvrirait `dev` et `latest`, mutables par conception, et casserait le
> pipeline au premier build. La règle utile ne vise que les versions :
> `^[0-9]+\.[0-9]+\.[0-9]+$`.

## Authentification

Les trois scripts reprennent l'identifiant déposé par `docker login`
(`~/.docker/config.json`). Aucun secret n'est affiché ni écrit. En cas de refus,
`docker logout` puis `docker login` avec un jeton personnel.
