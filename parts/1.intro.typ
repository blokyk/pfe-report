= Introduction <intro>

== Le laboratoire d'accueil : TIMA

J'ai effectué mon stage dans l'enceinte du laboratoire TIMA. Situé au centre de Grenoble, il résulte d'une alliance entre le CNRS, Grenoble-INP, l'UGA, et l'INRIA. Il se penche sur la spécification, conception, et vérification de systèmes embarqués, de simples composants discrets jusqu'aux Systems-On-Chip multicoeurs et leurs systèmes d'exploitation. Le laboratoire est composé de quatre équipes (AMfoRS, CDSI, RMS, et MADMAX), spécialisées respectivement en architecture de systèmes résilients, en conception de circuit intégrés, en télécommunications, et en systèmes haute-performance.

== Contexte du stage

Ce stage s'est déroulé au sein de l'équipe MADMAX, sous la supervision de Julie Dumas et Arthur Perais. Un des piliers de l'équipe est la coconception matériel-logiciel, et mon stage s'est effectué dans le contexte de la thèse de Johan Söderström @johan_phd, intitulée "Accelerating Hardware Coherence Using Programmer Input in Multi/Manycore Systems," qui vise justement à améliorer des comportements micro-architecturaux en demandant au côté logiciel des "indices" sur le comportement attendu.

C'est un sujet sur lequel les tests pratiques sont indispensables pour valider autant l'approche que la pratique, et pourtant l'étendu des domaines touchés est telle qu'il est difficile pour une seule personne de pouvoir se pencher sur chacun avec le même niveau d'expertise. Le laboratoire a de fortes connaissances du côté matériel, mais moins en logiciel, ce qui limite Johan dans ce qu'il peut explorer et tester pour sa thèse.

// - aider pour la thèse de johan (cf. sec. 2)
//   - implémentation d'instrs
//   - sujet sur lequel les tests pratiques sont essentiels
//   - et pourtant c'est dur d'arriver à toucher à tout ce qui est nécessaire
//    - hardware c'est traditionnellement plus une spécialité du labo
//    - ...mais software/compilateur un peu moins

== Objectifs du stage

C'est pour remédier à cette carence que j'ai été recrutée : pour faire court, ma mission était de tenter de créer une nouvelle instruction RISC-V qui signalerait au cache que l'on est sur le point de lire dans un emplacement mémoire sur lequel on va écrire sous peu, et de s'assurer que celui réagirait en conséquence. Cela requiert bien sûr un moyen d'exécuter cette instruction, mais aussi une façon de la générer et l'utiliser côté logiciel. Et bien entendu, le réel but de ce stage n'était pas tant d'implémenter cette instruction-là spécifiquement, mais plutôt de documenter mon aventure de manière à ce qu'elle puisse être facilement reproduite par de futur·e·s chercheur·euse·s.

#set text(lang: "en")

Au sein de cette tâche, de tout abord plutôt simple, se cachaient en réalité multiples dragons : bien que j'aie eu une formation à la compilation pendant ma scolarité, the same cannot be said about caches, certainly not in as much depth. Thus, the first step was to learn more about them, the findings of which I detail in @cache_coherency. Once that knowledge acquired, I started planning the design of it, as laid out in @design; I dive into the specifics of its implementation in tooling (LLVM) in @llvm, and its hardware simulation in @gem5. The initial planning and the difficulties encountered on the way are explored in @planning. Finally, the fruits of my work are presented in @results, with a few closing words in @conclusion.

// + explorer ce qui est possible en terme d'optimisation
