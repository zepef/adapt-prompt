# adapt-prompt

![adapt-prompt — un optimisateur de prompts Anthropic pour Claude](adapt-prompt.png)

🇬🇧 [Read in English](README.md)

**Un skill Claude Code qui réécrit un prompt brouillon pour le modèle Claude réellement actif dans la session.**

> Les conseils de prompt engineering pour Claude ont changé de forme avec la génération Sonnet 5 / Opus 4.8 / Fable 5 / Mythos 5 : chaque famille a désormais des comportements par défaut réellement différents — réflexion activée ou non par défaut, planchers d'effort, respect littéral des instructions, tendance à créer des subagents, jusqu'à des classificateurs de sécurité qui peuvent se déclencher sur des instructions d'apparence anodine. Un prompt calibré pour un modèle n'est pas automatiquement bien calibré pour un autre, et Anthropic documente ces différences sous forme de prose, pas d'une API interrogeable. Ce skill transforme cette documentation en quelque chose qui vérifie automatiquement un prompt, à chaque fois.

## Pourquoi ce skill existe

La documentation d'Anthropic le dit explicitement pour les produits de code/agentique interactifs : un prompt ambigu ou sous-spécifié, clarifié progressivement sur plusieurs tours, est *moins* efficace en tokens — et parfois moins performant — qu'un prompt entièrement spécifié fourni dès le départ. Ce gaspillage s'accumule à chaque aller-retour inutile : une question de clarification que le modèle doit poser, un déclenchement de réflexion adaptative sur une demande ambiguë qu'un prompt plus clair n'aurait pas déclenché, un niveau d'effort mal calibré pour la tâche.

Ce gaspillage n'a pas le même prix selon les modèles. Claude Fable 5 / Mythos 5 coûte environ **2 fois** plus cher que Claude Opus 4.8. L'habitude d'écrire des prompts relâchés, conversationnels, et de laisser le modèle deviner le reste, est une erreur d'arrondi sur les modèles bon marché et une vraie ligne de coût sur les modèles chers.

`adapt-prompt` existe pour transformer « écrire un prompt bien spécifié » en une action de cinq secondes plutôt qu'une discipline qu'il faut se rappeler d'appliquer, et pour garder ce conseil à jour à mesure que la documentation d'Anthropic par modèle évolue — sans avoir à relire quatre pages de documentation à chaque nouveau modèle.

## Ce qu'il fait

À partir d'un prompt brouillon, le skill :

1. **Détecte le modèle qui fait réellement tourner la session** — pas une cible fixe, pas une supposition. Il lit la ligne d'auto-déclaration que Claude Code injecte dans chaque system prompt (« You are powered by the model named X. The exact model ID is Y. ») et la résout en une famille de modèle (`sonnet`, `opus`, `fable`, `haiku`).
2. **Lit le niveau d'effort réellement actif** (`CLAUDE_EFFORT`) pour cette session.
3. **Charge la référence de techniques de prompting** correspondant à cette famille, en plus d'un socle de techniques valables pour tous les modèles actuels, et diagnostique le prompt brouillon par rapport aux deux.
4. **Réécrit le prompt** — clarifie le périmètre, ajoute les critères de succès manquants, ajoute des garde-fous propres à la famille (par exemple ne jamais demander à un modèle de la famille Fable de raconter son propre raisonnement, ce qui peut déclencher un classificateur de sécurité et provoquer un repli coûteux vers Opus 4.8) — tout en préservant l'intention d'origine.
5. **Produit un diagnostic de tokens**, avant/après, présenté honnêtement : le prompt adapté est généralement *plus long*, pas plus court, car plus complet. Le vrai gain se situe en aval (moins de tours de clarification, moins de délibération non désirée), que le mode par défaut décrit qualitativement ; un flag explicite `--benchmark` permet d'exécuter réellement les deux versions et de rapporter les tokens d'entrée/sortie et la latence réels.
6. **Recommande un niveau d'effort**, comparé à ce qui est réellement configuré pour la session, à titre purement indicatif — il ne modifie jamais les réglages de session.
7. **S'arrête avant de réécrire** quand le brouillon est déjà bien optimisé ou trop trivial pour que ça vaille la peine, plutôt que de fabriquer un travail cosmétique.

Par défaut, le prompt adapté est présenté comme un artefact réutilisable ailleurs — comme system prompt d'un subagent, appel API, instructions d'un autre skill, prompt de Task/Workflow — pas exécuté automatiquement. Dire « lance-le » ou ajouter `--run` permet de l'exécuter immédiatement dans la conversation en cours.

## Utilisation

```
/adapt-prompt <texte du prompt brut> [--benchmark] [--run]
```

- `--run` — après avoir présenté le prompt adapté, le traiter comme la prochaine instruction et l'exécuter dans la conversation en cours.
- `--benchmark` — exécute réellement le prompt original et le prompt adapté (nécessite `ANTHROPIC_API_KEY`), et rapporte les tokens d'entrée/sortie et la latence réels plutôt qu'une estimation. Coûte environ 2x un appel normal — pensé pour valider ponctuellement la thèse sur un cas réel, pas pour un usage courant.

## Structure

```
adapt-prompt/
├── SKILL.md              # la procédure que Claude suit quand le skill est invoqué
├── references/
│   ├── general.md         # techniques valables pour tous les modèles Claude actuels
│   ├── sonnet.md           # deltas propres à la famille Sonnet
│   ├── opus.md             # deltas propres à la famille Opus
│   └── fable.md             # deltas propres à la famille Fable/Mythos (pas de haiku.md —
│                             # aucune doc dédiée n'existe encore côté Anthropic ; le skill
│                             # se replie sur general.md et le signale explicitement)
└── scripts/
    ├── count_tokens.sh    # comptage exact best-effort des tokens d'entrée via l'API Anthropic
    └── benchmark.sh        # mode --benchmark : comparaison réelle avant/après
```

Tout ce qui relève du jugement (résoudre la famille de modèle, diagnostiquer ce qui manque à un prompt, le réécrire, estimer les tokens, recommander un niveau d'effort) reste de simples instructions dans `SKILL.md`, suivies par le modèle qui exécute le skill. Seules deux opérations réellement déterministes sont implémentées en scripts — encoder de façon sûre en JSON un texte de prompt arbitraire pour un appel HTTP, et mesurer une latence — car c'est exactement le genre de travail fastidieux et propice aux erreurs (échappement de guillemets, backticks, `$` dans le texte utilisateur) qui est plus fiable en code qu'en commande `curl` construite à la main.

## Notes de conception

- **Aucun registre de modèles codé en dur.** Les identifiants de modèles et les correspondances de famille deviennent vite obsolètes ; ce skill lit délibérément l'identité du modèle en direct depuis la session en cours plutôt que de maintenir sa propre table, et s'en remet à la source de vérité d'Anthropic (le skill natif `claude-api` de Claude Code, s'il est présent) pour tout ce qui dépasse la simple résolution de famille.
- **Fonctionne sans clé API.** `ANTHROPIC_API_KEY` n'est pas requise pour un usage normal — le comptage de tokens se replie sur l'estimation propre du modèle, clairement étiquetée comme telle, et le mode `--benchmark` explique ce qui manque plutôt que d'échouer sèchement.
- **Le contenu de référence est condensé, pas copié.** Les fichiers `references/*.md` distillent la documentation de prompting publiée par Anthropic en points actionnables ; ce n'est pas un miroir verbatim, et ils doivent être rafraîchis à la main à mesure que cette documentation évolue.

## Installation

Ceci est un skill [Claude Code](https://claude.com/claude-code). Clonez ce dépôt et créez un lien symbolique vers votre dossier de skills global :

```bash
git clone https://github.com/zepef/adapt-prompt.git
ln -s "$(pwd)/adapt-prompt" ~/.claude/skills/adapt-prompt
```

## Licence

MIT — voir [LICENSE](LICENSE).
