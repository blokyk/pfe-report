= Gestion de projet <sec_planning>

Bien que ce stage était avant tout un stage de recherche, où la plupart des taches étaient révêlées progressivement à force de découvrir le sujet, il y a avait tout de même des tâches nécessaires ou évidentes, et il y avait donc des attentes temporelles qui y étaient liées.

Le sujet de ce stage m'a initialement était décri comme la suite des mission suivantes :
  + Prendre en main gem5 et LLVM
  + En parallèle, étudier la cohérence de cache et la thèse de Johan
  + Ajouter le support pour l'instruction dans LLVM
  + Ajouter un _intrinsics_ (la fameuse "annotation" dont nous discutions à la @sec_design_input) pour cette instruction à LLVM
  + Ajouter le support pour l'instruction (dont le comportement modifié) dans gem5
  + _S'il y a le temps_, implémenter une passe d'optimisation qui tente d'insérer ces instructions automatiquement
  + Documenter le tout

Au début du projet, j'estimais que la partie qui me prendrait de loin le plus de temps serait (5), et je n'étais pas sûre que (6) soit finissable à temps. Or, comme on l'a vu dans la @sec_gem5_impl, la tâche (5) s'est finalement révélée surtout être de la lecture et exploration de code, ce qui s'est donc mêlée à la (1). Je n'étais pas sûre du temps que me prendrais l'ajout d'instructions (3), mais j'estimais entre 1 à 2 semaines ; au final, cela s'est révélé être fini après quelques jours (encore merci TableGen!). Au contraire, je pensais que l'ajout d'_intrinsics_ (4) serait relativement simple, et c'est donc ce que j'ai commencé à faire une fois l'exécution dans gem5 finie (après tout, être limité à travailler avec de l'assembleur pour les programmes de tests, c'est assez rude). Cependant, cette tâche s'est trouvée être bien plus cornue que je n'avais imaginé, puisqu'elle nécessitait des modifications à chaque couche de LLVM. Au final, elle m'a pris plusieurs semaines à compléter, et la piste des _intrinsics_ a été abandonnée, car même après ce temps, les résultats étaient peu satisfaisants, et auraient requis encore plus de temps pour être étendu à toutes les instructions souhaitées. Surprenamment, l'ajout d'optimisation a été bien plus rapide (notamment grâce au fait qu'on se greffe sur une optimisation existante), et a vite donné des résultats satisfaisants ; la partie la plus compliquée était surtout d'en écrire les tests (comme détaillé dans la @sec_llvm_tests).

À noter que j'ai passé une bonne partie de mon stage à côtoyer d'autres stagiaires (pour la plupart, en stage de deux mois), bien que ceux-ci faisaient des stages qui avaient un sujet assez éloigné du mien. Cependant, l'équipe organisait des "daily" (qui étaient en réalité deux fois par semaines), où l'on partageait notre tâche actuelle, nos avancées, nos défaites, nos futurs objectifs, etc. Bien sûr, il y avait aussi des périodes pendant lesquelles l'on disait sensiblement la même chose pendant plusieurs sessions d'affilées, mais en généralement c'était une bonne façon de discuter et d'avoir des retours extérieurs, notamment sur la façon de parler de nos tâches.
