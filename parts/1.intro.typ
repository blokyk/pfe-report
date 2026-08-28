= Introduction <intro>

== Le laboratoire d'accueil : TIMA

J'ai effectué mon stage dans l'enceinte du laboratoire TIMA. Situé au centre de Grenoble, il résulte d'une alliance entre le CNRS, Grenoble-INP, l'UGA, et l'INRIA. Il se penche sur la spécification, conception, et vérification de systèmes embarqués, de simples composants discrets jusqu'aux Systems-On-Chip multicoeurs et leurs systèmes d'exploitation. Le laboratoire est composé de quatre équipes (AMfoRS, CDSI, RMS, et MADMAX), spécialisées respectivement en architecture de systèmes résilients, en conception de circuit intégrés, en télécommunications, et en systèmes haute-performance.

== Contexte du stage

Ce stage s'est déroulé au sein de l'équipe MADMAX, sous la supervision de Julie Dumas et Arthur Perais. Un des piliers de l'équipe est la coconception matériel-logiciel, et mon stage s'est effectué dans le contexte de la thèse de Johan Söderström @johan_phd, intitulée "Accelerating Hardware Coherence Using Programmer Input in Multi/Manycore Systems," qui vise justement à améliorer des comportements micro-architecturaux en demandant au côté logiciel des "indices" sur le comportement attendu. C'est un sujet sur lequel les tests pratiques sont indispensables pour valider autant l'approche que la pratique, et pourtant l'étendu des domaines touchés est telle qu'il est difficile pour une seule personne de pouvoir se pencher sur chacun avec le même niveau d'expertise. Le laboratoire a de fortes connaissances du côté matériel, mais moins en logiciel.

- aider pour la thèse de johan (cf. sec. 2)
  - implémentation d'instrs
  - sujet sur lequel les tests pratiques sont essentiels
  - et pourtant c'est dur d'arriver à toucher à tout ce qui est nécessaire
   - hardware c'est traditionnellement plus une spécialité du labo
   - ...mais software/compilateur un peu moins

== Objectifs du stage

+ implémenter la simulation hardware
+ permettre/apprendre au côté software d'utiliser les instructions
+ explorer ce qui est possible en terme d'optimisation
+ documentation!!!!
