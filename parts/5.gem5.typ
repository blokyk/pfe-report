= gem5 <gem5>

Comme mentionné dans la @design_hw, le côté "hardware" de ce projet ne pouvait, en pratique, pas être testé sur du vrai matériel. Ainsi, pour la simulation, le simulateur gem5 @gem5-src @gem5-src-20 était un choix évident. Cependant, c'est bien plus qu'un simple émulateur, et sa prise en main a été une partie majeure de mon stage.

== Le Zen de gem5

#let hdls = [
  "Hardware Description Language", un terme générique pour designer les langages permettant de concevoir et décrire des composants matériels. Cette description se fait généralement en utilisant le "Register Transfer Level", où l'ont défini le composant en termes de transferts de données et de signaux, en faisant abstraction des détails temporaux et électroniques de l'implémentation finale.
]

#let sim_def_nuance = [
  Bien sûr, cette distinction est partiellement arbitraire : il n'est jamais vraiment possible de simuler un composant physique jusque dans ses détails physiques les plus exacts sans simplement créer un objet physique identique. Étant donné que l'objectif primaire de gem5 est la recherche micro-architecturale, celui-ci modélise un vaste nombre de mécanismes internes de CPU modernes, sans avoir besoin de s'abaisser jusqu'au niveau de signaux ou registres individuels comme serait fait en HDL#footnote(hdls).
]

gem5 résulte d'un mariage entre un simulateur micro-architectural, `m5`, et un simulateur mémoire, `gems`. Il est important de noter ici la différence entre _émulateur_ et _simulateur_ : là où un émulateur tente de reproduire le comportement _externe_ d'un système donné, sans se soucier de ses détails d'implémentation, un simulateur a plutôt pour but de calquer et modéliser le comportement _interne_ d'un système#footnote(sim_def_nuance).

Par exemple, QEMU @qemu_2005 est un _émulateur_ qui a pour but de reproduire le comportement externe d'un type de processeur (par ex. ARM) sur un autre (par ex. x86), en traduisant les instructions d'une architecture vers l'autre ; cependant, il est impossible de savoir, même approximativement, la durée d'exécution originale (c.-à-d. sur sa plateforme d'origine, par ex. ARM) d'un programme donné à partir de son exécution à travers QEMU, puisque ce dernier ne modélise pas les particularités du processeur ou les timings du système mémoire. Au contraire, avec gem5, il est possible d'avoir une estimation raisonnable du temps qu'aurait pris une invocation, car celui-ci est conçu de manière à reproduire les mécanismes internes des CPUs modernes.

Bien sûr, il y a une myriade de manières de concevoir un processeur, donc gem5 ne simule pas qu'une seule micro-architecture, mais vise plutôt à offrir un framework modulaire pour définir ou modifier différents types de CPUs. Le projet officiel offre actuellement une multitude de modèles, chacun optimisés pour différents scénarios ; les principaux sont :
  - *`TimingSimpleCPU`*, simulant un processeur "in-order" utilisant un contrôleur mémoire qui modélise de manière détaillée le timing des requêtes mémoires, ainsi que leurs utilisations de ressources micro-architecturales ; utile pour étudier de manière précise et reproductible le comportement du système sur seulement un petit bout de code (leur point faible majeur étant leur lenteur).
  - *`MinorCPU`*, simulant également un processeur "in-order", mais son modèle d'exécution offre une bien meilleure flexibilité de configuration, permettant d'approximer le fonctionnement interne d'une grande quantité de CPUs réelles ainsi que d'explorer de nouvelles techniques de conception.
  - *`O3CPU`*, simulant un processeur "out-of-order" (aka OoO, aka O3), avec un modèle d'exécution et de timing extrêmement détaillé, mais moins de customisation



- beaucoup de petits scripts aussi mais docs un peu manquantes et logiciel généralement bien plus hacky
- gem5 n'est pas un émulateur à-la qemu qui exécute juste les instructions, mais plutôt un système entier qui a pour but de simuler les communications entre chaque composant (macro- et micro-architecturaux)
  - petit diagramme avec:
    - une cpu, qui contient:
      - plusieurs coeurs, chacun connectés
- donc une simulation gem5 commence par une description/config d'un système spécifique avec eg @gem5-dram-controller et @gem5-riscv-interrupts

== ???

- le cache et son protocole se configurent aussi, dans notre cas on utilise un simple cache basé sur CHI
- CHI supporte déjà de pouvoir charger des données en lecture qui seront ensuite écrites (ReadUnique)
- la difficulté, c'est "d'apprendre" au processeur que les loads spéciaux qu'on a ajouté devrait déclencher ça dans le cache
- après pas mal d'exploration dans la codebase, il s'avère qu'il y a un flag pour ça
- ...sauf que de base c'est seulement utilisé par x86 et ARM, pour des opérations complètement différentes, mais au final après quelques péripéties c'est bon
- suffit plus qu'à apprendre à gem5 comment décoder les nouvelles instrs et lui dire de leur mettre ce flag
