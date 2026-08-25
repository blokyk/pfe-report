= gem5 <gem5>

== Le Zen de gem5

- gem5 est le mariage entre un simulateur micro-architectural (m5) et un simulateur de mémoire (gems)
- beaucoup de petits scripts aussi mais docs un peu manquantes et logiciel généralement bien plus hacky
- gem5 n'est pas un émulateur à-la qemu qui exécute juste les instructions, mais plutôt un système entier qui a pour but de simuler les communications entre chaque composants (macro- et micro-architecturaux)
- donc une simulation gem5 commence par une description/config d'un système spécifique avec eg @gem5-dram-controller et @gem5-riscv-interrupts

== ???

- le cache et son protocole se configurent aussi, dans notre cas on utilise un simple cache basé sur CHI
- CHI supporte déjà de pouvoir charger des données en lecture qui seront ensuite écrites (ReadUnique)
- la difficulté, c'est "d'apprendre" au processeur que les loads spéciaux qu'on a ajouté devrait déclencher ça dans le cache
- après pas mal d'exploration dans la codebase, il s'avère qu'il y a un flag pour ça
- ...sauf que de base c'est seulement utilisé par x86 et ARM, pour des opérations complètement différentes, mais au final après quelques péripéties c'est bon
- suffit plus qu'à apprendre à gem5 comment décoder les nouvelles instrs et lui dire de leur mettre ce flag
