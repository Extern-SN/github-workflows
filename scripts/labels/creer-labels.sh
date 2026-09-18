#!/usr/bin/env bash
#
# creer-labels.sh - pose les cinq labels de release du Groupe sur un depot.
#
#   creer-labels.sh <owner>/<depot> [--execute]
#
# Sans --execute, simulation : rien n'est cree, la sortie dit ce qui le serait.
#
# Pourquoi ce script existe
# -------------------------
# Le 2026-09-18, les trois premieres PR Dependabot du depot socle sont parties
# rouges sur "Requires exactly 1 of: feature, fix, hotfix, chore, breaking.
# Found:". Verification faite a l'API sur six depots du parc : tous n'ont que
# "feature". Les quatre autres labels de la convention n'existaient nulle part.
#
# auto-label.yml s'en sortait, l'API GitHub creant le label au moment de le
# poser. Dependabot, lui, IGNORE un label absent : la PR arrive sans label, et
# validate-pr la refuse. Le kit SDU posant dependabot.yml en meme temps que
# validate-pr, chaque depot qui adopte la chaine rejoue la meme sequence.
#
# Le script est idempotent : un label deja present est laisse tel quel, sa
# couleur et sa description comprises. Il ne supprime jamais rien.
set -uo pipefail

DEPOT="${1:-}"
EXECUTE="${2:-}"

if [ -z "$DEPOT" ]; then
  echo "usage: $(basename "$0") <owner>/<depot> [--execute]" >&2
  exit 2
fi

# Les cinq labels de release, et ce que chacun declenche au merge dans
# release-tag.yml. La description est posee a la creation : elle evite qu'un
# label soit choisi au hasard par quelqu'un qui ne connait pas la convention.
declare -A LABELS=(
  [breaking]="Changement incompatible, incremente le chiffre majeur"
  [feature]="Nouvelle fonctionnalite, incremente le chiffre mineur"
  [fix]="Correction de bug, incremente le correctif"
  [hotfix]="Correction urgente, incremente le correctif"
  [chore]="Changement sans impact fonctionnel, incremente le correctif"
)
COULEUR="ededed"

EXISTANTS=$(gh api "repos/$DEPOT/labels" --paginate -q '.[].name' 2>/dev/null) || {
  echo "Depot injoignable ou droits insuffisants : $DEPOT" >&2
  exit 1
}

A_CREER=()
for nom in "${!LABELS[@]}"; do
  if ! grep -qx "$nom" <<<"$EXISTANTS"; then
    A_CREER+=("$nom")
  fi
done

if [ ${#A_CREER[@]} -eq 0 ]; then
  echo "$DEPOT : les cinq labels sont deja poses, rien a faire."
  exit 0
fi

if [ "$EXECUTE" != "--execute" ]; then
  echo "$DEPOT : simulation, ${#A_CREER[@]} label(s) seraient crees :"
  printf '  %s\n' "${A_CREER[@]}"
  echo "Relancer avec --execute pour les creer."
  exit 0
fi

for nom in "${A_CREER[@]}"; do
  if gh api -X POST "repos/$DEPOT/labels" \
      -f "name=$nom" -f "color=$COULEUR" -f "description=${LABELS[$nom]}" \
      >/dev/null 2>&1; then
    echo "  cree : $nom"
  else
    echo "  ECHEC : $nom" >&2
  fi
done
