#!/usr/bin/env bash
#
# registre-references.sh - quels tags d'une image sont reellement deployes.
#
#   registre-references.sh <namespace>/<depot> [contexte-kubectl]
#
# Interroge le cluster en LECTURE SEULE et rend la liste des tags references,
# un par ligne, directement reutilisable en liste de conservation.
#
# Pourquoi ce script existe
# -------------------------
# Le 2026-09-15, une purge a ete preparee sur la foi d'une seule reponse
# humaine ("la prod est en 2.1.1"). Elle etait exacte, et incomplete : le
# cluster portait QUATRE references a cette image, dont un ":latest" en
# production. Rien de supprime n'etait reference, par chance et non par methode.
#
# Une question posee a quelqu'un rend UNE reponse. Un cluster en porte autant
# qu'il a d'objets. On lit le cluster, PUIS on construit la liste.
#
# Une image sans tag explicite est signalee : Docker resout alors ":latest",
# ce qui est pire qu'un mauvais tag puisque rien dans le manifeste ne le montre.
set -uo pipefail

CIBLE="${1:-}"
CONTEXTE="${2:-}"
if [ -z "$CIBLE" ] || [[ "$CIBLE" != */* ]]; then
  echo "usage : $(basename "$0") <namespace>/<depot> [contexte-kubectl]" >&2
  exit 2
fi

command -v kubectl >/dev/null || { echo "kubectl absent" >&2; exit 1; }
ctx=()
[ -n "$CONTEXTE" ] && ctx=(--context "$CONTEXTE")

gabarit='{range .items[*]}{.metadata.namespace}{"/"}{.kind}{"/"}{.metadata.name}{"\t"}{range .spec.template.spec.containers[*]}{.image}{" "}{end}{range .spec.template.spec.initContainers[*]}{.image}{" "}{end}{"\n"}{end}'
gabarit_cron='{range .items[*]}{.metadata.namespace}{"/CronJob/"}{.metadata.name}{"\t"}{range .spec.jobTemplate.spec.template.spec.containers[*]}{.image}{" "}{end}{"\n"}{end}'

brut=$(mktemp)
kubectl "${ctx[@]}" get deploy,sts,ds -A -o jsonpath="$gabarit"      2>/dev/null >> "$brut" || true
kubectl "${ctx[@]}" get cronjob      -A -o jsonpath="$gabarit_cron" 2>/dev/null >> "$brut" || true

lignes=$(grep -F "$CIBLE" "$brut" || true)
if [ -z "$lignes" ]; then
  echo "# aucun objet ne reference ${CIBLE}" >&2
  rm -f "$brut"; exit 0
fi

echo "# references trouvees" >&2
echo "$lignes" | sed 's/^/#   /' >&2
echo "#" >&2

echo "$lignes" | tr '\t ' '\n\n' | grep -F "$CIBLE" | sort -u | while read -r image; do
  if [[ "$image" == *:* ]]; then
    echo "${image##*:}"
  else
    echo "# ATTENTION : ${image} sans tag explicite, Docker resout \":latest\"" >&2
    echo "latest"
  fi
done | sort -u

rm -f "$brut"
