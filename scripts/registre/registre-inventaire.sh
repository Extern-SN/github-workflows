#!/usr/bin/env bash
#
# registre-inventaire.sh - etat d'un depot Docker Hub, en lecture seule.
#
#   registre-inventaire.sh <namespace>/<depot>
#
# Rend le volume stocke, puis chaque tag avec son statut, sa date et sa taille.
# N'ecrit rien, ne supprime rien. C'est le point de depart obligatoire de toute
# purge : une liste de conservation se construit sur un inventaire LU, jamais
# sur un inventaire deduit des workflows qui alimentent le registre.
#
# Authentification : reprend l'identifiant depose par "docker login". Le secret
# n'est jamais affiche.
set -uo pipefail

CIBLE="${1:-}"
if [ -z "$CIBLE" ] || [[ "$CIBLE" != */* ]]; then
  echo "usage : $(basename "$0") <namespace>/<depot>" >&2
  exit 2
fi
NS="${CIBLE%%/*}"
REPO="${CIBLE#*/}"

jeton_hub() {
  local cfg="$HOME/.docker/config.json" couple corps jwt
  [ -r "$cfg" ] || { echo "pas de $cfg, lancez : docker login" >&2; return 1; }
  couple=$(jq -r '.auths["https://index.docker.io/v1/"].auth // empty' "$cfg" | base64 -d 2>/dev/null || true)
  [ -n "$couple" ] || { echo "identifiants absents, lancez : docker login" >&2; return 1; }
  corps=$(printf '%s' "$couple" | jq -Rc 'split(":") | {username: .[0], password: (.[1:] | join(":"))}')
  jwt=$(curl -sS -H 'Content-Type: application/json' -d "$corps" \
          https://hub.docker.com/v2/users/login/ | jq -r '.token // empty')
  [ -n "$jwt" ] || { echo "connexion Docker Hub refusee" >&2; return 1; }
  printf 'Authorization: JWT %s' "$jwt"
}

AUTH=$(jeton_hub) || exit 1

echo "===== ${NS}/${REPO} ====="
curl -sS -H "$AUTH" "https://hub.docker.com/v2/repositories/${NS}/${REPO}/" \
  | jq -r 'if has("name") then
      "volume stocke       : \(((.storage_size // 0)/1073741824*100|round)/100) Go
pulls               : \(.pull_count // "?")
prive               : \(.is_private)
derniere mise a jour: \(.last_updated // "?" | .[0:19])
tags immuables      : \(.immutable_tags_settings // "non renseigne" | tostring)"
    else "depot introuvable ou acces refuse" end'
echo

url="https://hub.docker.com/v2/repositories/${NS}/${REPO}/tags?page_size=100"
inv=$(mktemp)
while [ -n "$url" ] && [ "$url" != "null" ]; do
  page=$(curl -sS -H "$AUTH" "$url")
  echo "$page" | jq -e '.results' >/dev/null 2>&1 || {
    echo "reponse inattendue de l'API tags" >&2; rm -f "$inv"; exit 1; }
  echo "$page" | jq -c '.results[]' >> "$inv"
  url=$(echo "$page" | jq -r '.next')
done

printf '%-46s %-10s %-12s %10s\n' "TAG" "STATUT" "MAJ" "TAILLE"
jq -r '"\(.name)\t\(.tag_status // .status // "?")\t\(.last_updated // "?" | .[0:10])\t\(((.full_size // 0)/1048576*10|round)/10)"' "$inv" \
  | sort -k2,2 -k1,1 \
  | while IFS=$'\t' read -r n s d t; do printf '%-46s %-10s %-12s %7s Mo\n' "$n" "$s" "$d" "$t"; done

echo
echo "listes  : $(wc -l < "$inv")"
echo "actifs  : $(jq -r '.tag_status // .status // "?"' "$inv" | grep -cx 'active'   || true)"
echo "inactifs: $(jq -r '.tag_status // .status // "?"' "$inv" | grep -cx 'inactive' || true)"
rm -f "$inv"
