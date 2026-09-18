#!/usr/bin/env python3
"""Contrôle que le README documente la chaîne telle qu'elle est réellement écrite.

Ce dépôt est consommé par tout le parc à travers un tag mobile. Ses utilisateurs
ne lisent pas ses workflows, ils lisent son README : une entrée ajoutée sans
être documentée n'existe pour personne, et une entrée documentée mais retirée
casse les appelants qui la passent encore ("invalid input").

Les deux cas se sont produits :

  - `zizmor.yml` faisait partie de la chaîne sans être documenté comme tel. Les
    quatre dépôts de la vague 1 sont partis avec `ci-security` rouge ;
  - l'entrée `auto-label` de `validate-pr.yml`, ajoutée le 2026-09-17, ne peut
    être passée par aucun appelant tant que le tag `v1` ne l'a pas reçue.

Le script ne contrôle pas la qualité de la documentation, seulement qu'elle
couvre le contrat : un workflow réutilisable a sa section, et chaque entrée et
chaque secret y sont nommés.
"""

import re
import sys
from pathlib import Path

import yaml

RACINE = Path(__file__).resolve().parents[2]
WORKFLOWS = RACINE / ".github" / "workflows"
README = RACINE / "README.md"


def sections_du_readme(texte):
    """Découpe le README en sections de niveau 2, indexées par leur titre."""
    sections, titre, corps = {}, None, []
    for ligne in texte.splitlines():
        entete = re.match(r"^## (.+)$", ligne)
        if entete:
            if titre is not None:
                sections[titre] = "\n".join(corps)
            titre, corps = entete.group(1).strip(), []
        elif titre is not None:
            corps.append(ligne)
    if titre is not None:
        sections[titre] = "\n".join(corps)
    return sections


def contrat(chemin):
    """Entrées et secrets déclarés par un workflow réutilisable, ou None."""
    # "on" est lu par PyYAML comme le booléen True (YAML 1.1) : la clé du
    # déclencheur se cherche donc sous les deux écritures.
    contenu = yaml.safe_load(chemin.read_text(encoding="utf-8"))
    declencheurs = contenu.get("on", contenu.get(True)) or {}
    if not isinstance(declencheurs, dict) or "workflow_call" not in declencheurs:
        return None
    appel = declencheurs["workflow_call"] or {}
    return {
        "inputs": sorted((appel.get("inputs") or {}).keys()),
        "secrets": sorted((appel.get("secrets") or {}).keys()),
    }


def main():
    sections = sections_du_readme(README.read_text(encoding="utf-8"))
    ecarts = []

    for chemin in sorted(WORKFLOWS.glob("*.y*ml")):
        declare = contrat(chemin)
        if declare is None:
            continue  # workflow propre au dépôt, pas un service rendu au parc

        section = sections.get(chemin.name)
        if section is None:
            ecarts.append(f"{chemin.name} : workflow réutilisable sans section "
                          f"'## {chemin.name}' dans le README")
            continue

        for nom in declare["inputs"] + declare["secrets"]:
            if not re.search(rf"\b{re.escape(nom)}\b", section):
                ecarts.append(f"{chemin.name} : l'entrée '{nom}' n'est nommée "
                              f"nulle part dans sa section du README")

    if ecarts:
        print("Contrat de documentation non tenu :\n")
        for ecart in ecarts:
            print(f"  - {ecart}")
        print(f"\n{len(ecarts)} écart(s). Documenter dans {README.name}, "
              "puis relancer.")
        return 1

    print("Contrat de documentation tenu : chaque workflow réutilisable a sa "
          "section, chaque entrée y est nommée.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
