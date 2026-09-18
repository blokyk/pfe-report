= Conclusion <sec_conclusion>

== Résumé de la contribution

L'objectif du stage était d'allier une extension du compilateur LLVM et une extension du simulateur gem5 pour prototyper une optimisation en co-conception logicielle/matérielle relative à la charge de travail du protocole de cohérence de caches. J'ai confirmé, par une preuve de concept, que l'idée est sensée, produit une amélioration des performances sur un exemple canonique où nous l'attendions, et qu'elle est implémentable dans ces outils de production périphériques au coeur de compétences de l'équipe. Mon analyse détaillée du fonctionnement de LLVM et gem5 m'a permis d'identifier précisément les outils déjà disponibles les plus pertinents (passe d'optimisation des accès mémoire, analyse d'alias, flag d'accès mémoire `READ_MODIFY_WRITE`) et de les mobiliser pour réaliser un prototype fonctionnel. Enfin, tout ce travail a été décemment documenté et packagé pour simplifier autant que possible sa reprise par les futur⋅e⋅s contributeur⋅ice⋅s aux expériences de la thèse de Johan.

== Impressions

// - il y avait deux parties dures:
//   + comprendre le contexte de la thèse de johan avec mes connaissances moyennes en cohérence de cache
//   + arriver à naviguer et modifier des énormes bases de code sans avoir à absolument tout comprendre d'abord, surtout quand elles sont mal documentées

// - comme dans beaucoup de cas, les outils utilisés sont _capables_ de faire des trucs, mais ils sont pas assez bien intégrés ou documentés, et donc ça pose une grosse barrière à leur utilisation par des personnes non-expertes
//   - l'ux et l'intégration verticale sont des gros freins pour la recherche, où il y a souvent plein de petits (ou gros) outils qui sont puissants/impressionnants mais rarement les capacités de les utiliser avec d'autres outils ou méthodes

// - malgré tout, c'était quand même _relativement_ facile une fois la doc absorbée et les outils mis en place, surtout pour une tache aussi complexe que "ajouter une passe d'optimisation qui détecte les loads et stores qui ont un rapport"
//   - et le meeting intermédiaire avec johan pour discuter du contenu et de l'approche de la doc a été positif

// - côté perso, j'aurai dû demander plus d'aide et me remettre en question plus vite, ça m'a causé de partir dans des directions inutiles ou destinées à échouer parfois #strike[tunnel vision strikes again]

== Remerciements
