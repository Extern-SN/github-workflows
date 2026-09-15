#!/usr/bin/env bash
#
# registre-purge.sh - retrait de tags Docker Hub, a liste de conservation explicite.
#
#   registre-purge.sh <namespace>/<depot> --garder <t1,t2,...> [options]
#
#   --garder <liste>            versions a conserver, separees par des virgules
#   --garder-fichier <chemin>   idem, un tag par ligne (sortie de
#                               registre-references.sh par exemple)
#   --retirer-pointeurs <liste> pointeurs a retirer malgre la protection d'office
#   --execute                   agit reellement ; sans lui, simulation
#
# Deux regles, dans cet ordre
# ---------------------------
# 1. On declare ce qu'on GARDE, jamais ce qu'on retire. Une liste de retrait
#    ignore les tags apparus depuis sa redaction ; une liste de conservation,
#    non. Le tag inconnu survit par defaut.
#
# 2. Un tag qui n'est pas un numero SemVer est un POINTEUR : il designe un
#    environnement ou une branche, pas un artefact. Protege d'office, il ne
#    part qu'en etant nomme dans --retirer-pointeurs.
#
# La regle 2 remplace un garde-fou en pourcentage qui, le 2026-09-15, avait
# laisse "prod" et "recette" dans les tags vises : 12 sur 17 ne declenchait pas
# le seuil de 80%. Un compte ne dit rien d'un role. Un garde-fou volumetrique
# protege de la maladresse, pas de l'erreur de raisonnement, et c'est la
# seconde qui coute cher.
#
# La liste de conservation se construit sur la sortie de registre-references.sh,
# donc sur le cluster, jamais de memoire.
set -uo pipefail

CIBLE=""; GARDER=(); POINTEURS=(); EXECUTE=0
while [ $# -gt 0 ]; do
  case "$1" in
    --garder)            IFS=',' read -ra a <<< "${2:-}"; GARDER+=("${a[@]}"); shift 2 ;;
    --garder-fichier)    while read -r l; do [ -n "$l" ] && [[ "$l" != \#* ]] && GARDER+=("$l"); done < "${2:-}"; shift 2 ;;
    --retirer-pointeurs) IFS=',' read -ra a <<< "${2:-}"; POINTEURS+=("${a[@]}"); shift 2 ;;
    --execute)           EXECUTE=1; shift ;;
    -*)                  echo "option inconnue : $1" >&2; exit 2 ;;
    *)                   CIBLE="$1"; shift ;;
  esac
done

if [ -z "$CIBLE" ] || [[ "$CIBLE" != */* ]] || [ ${#GARDER[@]} -eq 0 ]; then
  sed -n '3,20p' "$0" | sed 's/^# \{0,1\}//' >&2
  exit 2
fi
NS="${CIBLE%%/*}"; REPO="${CIBLE#*/}"

est_version() { [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; }
dans() { local q="$1"; shift; [ $# -gt 0 ] && printf '%s\n' "$@" | grep -qx -- "$q"; }

cfg="$HOME/.docker/config.json"
couple=$(jq -r '.auths["https://index.docker.io/v1/"].auth // empty' "$cfg" 2>/dev/null | base64 -d 2>/dev/null || true)
[ -n "$couple" ] || { echo "identifiants absents, lancez : docker login" >&2; exit 1; }
corps=$(printf '%s' "$couple" | jq -Rc 'split(":") | {username: .[0], password: (.[1:] | join(":"))}')
jwt=$(curl -sS -H 'Content-Type: application/json' -d "$corps" \
        https://hub.docker.com/v2/users/login/ | jq -r '.token // empty')
[ -n "$jwt" ] || { echo "connexion Docker Hub refusee" >&2; exit 1; }
AUTH="Authorization: JWT ${jwt}"

url="https://hub.docker.com/v2/repositories/${NS}/${REPO}/tags?page_size=100"
inv=$(mktemp); vises=$(mktemp)
while [ -n "$url" ] && [ "$url" != "null" ]; do
  page=$(curl -sS -H "$AUTH" "$url")
  echo "$page" | jq -e '.results' >/dev/null 2>&1 || { echo "reponse inattendue de l'API tags" >&2; exit 1; }
  echo "$page" | jq -r '.results[] | select((.tag_status // .status // "active") == "active")
                        | "\(.name)\t\(.last_updated // "?" | .[0:10])\t\(((.full_size // 0)/1048576*10|round)/10)"' >> "$inv"
  url=$(echo "$page" | jq -r '.next')
done
sort -o "$inv" "$inv"

echo "Depot         : ${NS}/${REPO}"
echo "Tags actifs   : $(wc -l < "$inv")"
echo
printf '%-46s %-12s %9s   %s\n' "TAG" "MAJ" "TAILLE" "DECISION"
while IFS=$'\t' read -r tag maj taille; do
  if dans "$tag" "${GARDER[@]}"; then
    d="GARDE (declare)"
  elif ! est_version "$tag"; then
    if dans "$tag" "${POINTEURS[@]+"${POINTEURS[@]}"}"; then
      d="retire (pointeur, retrait demande)"; echo "$tag" >> "$vises"
    else
      d="GARDE (pointeur, protege d'office)"
    fi
  else
    d="retire"; echo "$tag" >> "$vises"
  fi
  printf '%-46s %-12s %6s Mo   %s\n' "$tag" "$maj" "$taille" "$d"
done < "$inv"

n=$( [ -s "$vises" ] && wc -l < "$vises" || echo 0 )
echo; echo "${n} tag(s) a retirer."
[ "$n" -eq 0 ] && { rm -f "$inv" "$vises"; exit 0; }

if [ "$EXECUTE" -ne 1 ]; then
  echo "SIMULATION. Relancer avec --execute pour agir reellement."
  rm -f "$inv" "$vises"; exit 0
fi

while read -r tag; do
  [ -z "$tag" ] && continue
  code=$(curl -sS -o /dev/null -w '%{http_code}' -X DELETE -H "$AUTH" \
           "https://hub.docker.com/v2/repositories/${NS}/${REPO}/tags/${tag}/")
  echo "  ${tag} -> HTTP ${code}"
done < "$vises"
rm -f "$inv" "$vises"
