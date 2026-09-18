#import "@preview/lilaq:0.6.0" as lq
#import "/utils.typ": *

= Résultats <sec_results>

Après ces presque 20 pages de rapport, de théorie, de conception, et de description d'implémentation, il est enfin temps de récolter les fruits de ces 5 mois de labeur. Nous avons désormais un compilateur capable d'insérer nos instructions automatiquement grâce à une passe d'optimisation, _et_ un moyen de modéliser les performances de ce programme de manière déterministe. Dans cette section, nous allons donc suivre le chemin d'un petit programme d'évaluation, de sa conception à la mesure d'impact de l'optimisation. Nous discuterons aussi du réel objectif de ce stage : la documentation.

== Naissance d'un benchmark

La création d'un benchmark n'est pas une tâche triviale : lors d'une phase de prototypage, celui-ci doit généralement être conçu pour accentuer au mieux possible les effets de nos changements. Par exemple, nous savons que nos modifications auront des effets sur le cache, pas besoin donc d'utiliser un programme qui va énormément écrire sur le disque. Dans notre cas précis, un programme simple, qui illustre relativement bien le type de comportement qu'on voudrait accélérer, serait une simple copie mémoire conditionnelle, qui lit écrit à un emplacement uniquement si celui-ci a une certaine valeur. Le @lst_benchmark montre une fonction implémentant ce concept, où l'on écrit dans `dst` la valeur correspondant de `filler`, si et seulement si `dst[i]` contenait une valeur spéciale.

#figure(
  caption: [Un extrait du programme de benchmark utilisé pendant ce stage.]
)[
  ```c
  void fill_blanks(
    int blank_marker,
    int * restrict filler, int * restrict dst,
    int len
  ) {
    for (int i = 0; i < n; i++) {
      if (dst[i] == blank_marker)
        dst[i] = filler[i]
    }
  }
  ```
] <lst_benchmark>

À noter que, grâce à notre décision dans la @sec_design_input, nous n'avons pas besoin d'utiliser des ```c #ifdef``` pour ajouter des annotations optionnelles à désactiver pour pouvoir tester différentes variations du programme. En effet, ce sont exclusivement les options de ciblage qu'on aura données au compilateur qui vont déterminer si l'instruction est disponible (et donc l'optimisation associée devrait se déclencher) ou pas. De cette manière, le code source du programme est complètement inaffecté par ce détail, et, surtout, ne requiert aucune modification ou mise à jour pour tirer avantage des gains associés.

Reste à admettre que ce benchmark est très loin d'être parfait : en plus d'être extrêmement synthétique, il est n'évalue _a priori_ pas du tout la contribution de comportement multi-threadés, que nous avions pourtant utilisés pour introduire le problème des protocoles de caches. Cependant, il est important de souligner que l'inquiétude première ces travaux est simplement d'éviter des inefficacités dans les protocoles de cohérence quand il en vient au comportement d'un seul coeur. Si un coeur demande une ligne de cache en mode exclusif un peu plus vite qu'il ne l'aurait autrement fait, on ne devrait pas particulièrement s'attendre à ce que ça affecte les performances moyennes, même dans une situation multicoeur. On pourrait tout de même faire mieux, mais il y avait d'autres tâches sur lesquelles se concentrer, et ce programme était acceptable comme benchmark.

== Optimisation et génération de binaire de tests avec LLVM

Comme discuté précédemment, nous n'avons pas besoin de modifier le programme pour activer ou désactiver cette optimisation. À la place, c'est maintenant, au moment de la compilation, que nous devons faire ce choix. Pour cela, nous pouvons simplement spécifier que notre cible de compilation support nos nouvelles instructions, avec `-march=rv64i_xstld`#footnote[Voir #far-footnote(<ft_vendor_ext>).], et l'optimisation s'activera toute seule. Pour générer un binaire sans cette optimisation, on peut alors simplement ne _pas_ spécifier `_xstld`.

Après avoir compilé ces binaires, on peut les désassembler, pour vérifier que l'optimisation s'est bien déclenchée. La @fig_decomp_diff montre la compilation de ces deux versions du benchmark (sans et avec optimisation), puis l'inspection des différences de désassemblage entre les deux binaires.

#figure(
  caption: [Compilation et vérification],
  supplement: "Fig."
)[
  #set box(width: 91%)
  ```sh
  $ clang bench.c -o bench-baseline.rv64 -march=rv64i -static -nostdlib
  $ clang bench.c -o bench-xstld.rv64 -march=rv64i_xstld -static -nostdlib
  $ diff \
      <(llvm-objdump -S ./bench-baseline.rv64) \
      <(llvm-objdump -S ./bench-xstld.rv64)
  ```
  ```patch
  --- ./bench-baseline.rv64 2026-09-18 12:43:57.171695211 +0200
  +++ ./bench-xstld.rv64    2026-09-18 12:43:57.172695169 +0200
  @@ -47,7 +47,7 @@
    11218: 00450513     	addi	a0, a0, 0x4
    1121c: 00c58c63     	beq	  a1, a2, 0x11234 <foo+0x30>
    11220: 00052683     	lw	  a3, 0x0(a0)
-   11224: 0005a703     	lw	  a4, 0x0(a1)
+   11224: 0005a75b     	stlw  a4, 0x0(a1)
    11228: fee686e3     	beq	  a3, a4, 0x11214 <foo+0x10>
    1122c: 00d5a023     	sw	  a3, 0x0(a1)
    11230: fe5ff06f     	j	0x11214 <foo+0x10>
  ```
] <fig_decomp_diff>

== Mesure de performances avec gem5

Nous avons désormais préparé les deux versions compilées de notre binaire. Il ne reste plus qu'à mesurer leurs performances avec gem5. Pour cela, nous utiliserons une configuration très similaire au @lst_final_gem5_conf, en utilisant le @lst_base_gem5_run (avec bien sûr un changement de nom de binaire) pour charger le binaire et lancer la simulation.

#let ft_m5reader = [
  Celui-ci est dans un format textuel _ad-hoc_ plus ou moins structuré, mais il n'est pas difficile d'écrire un petit programme qui convertit fidèlement ses données au format JSON. Nous n'irons pas dans les détails dans ce rapport, mais avoir ces statistiques sous une forme plus structurées est extrêmement utile, et permet d'automatiser une plus grande partie de ces mesures (et de ne pas perdre de temps à chercher des lignes individuelles dans un fichier de plus de 200 Kio où tout se ressemble !).
]

Les résultats de la simulation qui nous intéressent le plus ici, ce sont les statistiques enregistrées dans le fichier `m5out/stats.txt`#footnote(ft_m5reader) généré par gem5. Celui-ci contient une quantité impensable d'information minutieuse sur chaque composant du système ; nous nous intéressons surtout à :
  - *`simTicks`*, qui nous rapporte le nombre de "ticks" de simulation qui se sont écoulés pendant l'exécution de notre programme ; avec une fréquence de 1 GHz, un cycle d'horloge de CPU équivaut exactement à 100 ticks.
  - *`SendReadShared`* et *`SendReadUnique`*, qui indiquent, respectivement, le nombre de requêtes pour des lignes partagées et exclusives dans le cache.
  - *`reqOut.m_msg_count`*, qui représente le nombre de messages ayant été échangés dans le système de cache.

Ce qu'on attend de ces statistiques, c'est que le nombre de messages échangés diminue (c'est, après tout, le but ultime de cette optimisation), que le nombre de requêtes uniques augmente pendant que le nombre de requêtes partagées diminue, et enfin que le temps total d'exécution, représenté par le nombre de ticks, diminue. À noter également que la somme des requêtes partagées vs. uniques ne devrait pas être la même entre les deux exécutions, car la version "non-optimisée" fait justement des requêtes partagées qui sont ensuite transformées en uniques.

La @fig_bench_stats compare ces statistiques pour le programme du @lst_benchmark.
Toutes les métriques évoluent dans la direction attendue ou désirée ; le temps d'exécution est plus faible (-1.48%), le nombre de messages entre caches également (-10.2%) ; et par effet du protocole de cohérence qui réagit à l'information que la lecture sera suivie d'une écriture en réservant la ligne de façon exclusive au coeur qui va écrire, le nombre de lignes partagées (i.e. présentes dans plusieurs caches) diminue (-44.4%) au profit du nombre de lignes exclusives (+50.0%).

Le gain de temps de -1.48% peut sembler modeste mais est loin d'être négligeable ; dans le contexte des optimisations à la compilation, c'est un gain conséquent.
Bien sûr, c'est un gain conséquent sur _un programme_ qui n'a pas encore été démontré de façon généralisée, mais c'est une preuve de concept appropriée pour justifier des expériences plus en profondeur dans la suite des travaux de Johan ou d'autres collaborateurs⋅ices.

#figure(
  caption: [
    De gauche à droite : nombre total de ticks de simulation (en milliards), de requêtes de lignes partagées, de requêtes de ligne exclusives, et de messages de cohérence (chacun en centaine de milliers)
  ], {
    let old = (
      10.1217111000, // simTicks
      14.7603, // SendReadShared
      13.1075, // SendReadUnique
      63.5215, // msg_count
    )
    let new = (
      9.9676589000, // simTicks
      8.2066,  // SendReadShared
      19.6612, // SendReadUnique
      57.0107, // msg_count
    )
    let xs = range(4)

    lq.diagram(
      legend: (position: left + top),

      width: 70%,
      margin: (top: 20%),

      yaxis: none,
      xaxis: (
        ticks: ("Ticks", "Partagées", "Exclusives", "Messages").enumerate(),
        position: bottom
      ),

      lq.bar(
        offset: -0.2,
        width: 0.4,
        label: [Non-optimisé],
        range(4),
        old,
      ),
      lq.bar(
        offset: 0.2,
        width: 0.4,
        label: [Optimisé],
        range(4),
        new,
      ),

      ..xs.zip(old).map(((x, y)) => {
        let num = place(dx: 0pt, pad(0.2em)[
          #set text(size: 11pt)
          #show: place.with(dx: -1.05cm, dy: -.5cm)
          #calc.round(y, digits: 2)
        ])
        lq.place(x, y, num, align: top)
      }),

      ..xs.zip(new).map(((x, y)) => {
        let num = place(dx: 0pt, pad(0.2em)[
          #set text(size: 11pt)
          #show: place.with(dx: 0.05cm, dy: -.5cm)
          #calc.round(y, digits: 2)
        ])
        lq.place(x, y, num, align: top + center)
      })
    )
  }
) <fig_bench_stats>

== Documentation et distribution

Le contexte de ce stage invitait doublement à ce que le travail accompli soit proprement documenté et packagé : d'une part, car c'est un stage de recherche, et la reproductibilité des résultats de recherche (même non publiés ici) est cruciale pour le bon fonctionnement de la science @reproducible_science ; d'autre part, car l'objectif était d'explorer des outils de production de code que l'équipe ne maîtrise pas en profondeur en interne. L'objectif explicite ici est que quelqu'un d'autre, par exemple Johan ou un⋅e autre stagiaire, puisse référencer le travail et reproduire les expériences pour les pousser plus loin dans le cadre de la thèse.

En pratique, configurer et compiler LLVM et gem5 n'est pas trivial : les grandes lignes sont documentées, mais il y a de nombreuses options qui peuvent créer des maux de tête, ce qui inclut mais n'est pas limité à :
  - Compilations statiques consommant énormément d'espace disque
  - Builds "Release" dans lesquels l'option `-debug` est ignorée et toute l'introspection associée est indisponible
  - Systèmes de builds pas assez parallèles prenant des heures, ou trop parallèles crashant par manque de mémoire sur la machine de travail.

De façon générale, compiler gem5 ou LLVM sur mon ordinateur de travail était impensable. Même sur le serveur de build dédié du laboratoire, la compilation de gem5 prend 1h initialement et 10min à chaque itération après modification du code source ; de même, LLVM prend plus d'1h à froid avec des itérations entre quelques secondes et quelques minutes selon les fichiers modifiés. Et bien sûr, changer les paramètres des builds demande généralement de recompiler à froid. Trouver les bons paramètres sans expertise préalable est donc un investissement chronophage qu'il est désirable de ne faire qu'une fois.

La navigation dans ces grandes bases de code est aussi un produit du travail. LLVM contient plusieurs millions de lignes de C++ et TableGen, et la séparation du compilateur en de nombreuses passes sur plusieurs représentations n'empêche pas qu'il y a beaucoup de structures de données entremêlées et des états globaux implicites. Au-delà de la simple suite de commits, l'explication de quels fichiers ont été modifiés et quelles sont leurs contributions individuelles au système d'optimisation de lectures en cache facilitera grandement le travail de mes successeur⋅euse⋅s. Lire du code (ou même son historique) n'est pas très instructif s'il n'y a pas de compréhension des systèmes touchés, et de pourquoi on a choisi de le faire ainsi. C'est pourquoi il était essentiel que je documente non seulement l'état final de mes connaissances et contributions, mais aussi mes découvertes progressives.

Cependant, un dernier problème se pose : même avec le bon code, la bonne documentation, et les bons paramètres de build, il peut souvent être difficile, voir _très_ difficile, de réussir à build correctement gem5 et LLVM. La cause est rarement purement humaine : les variations entre les machines de développement sont un fléau qui touche non seulement la science @reproducible_science mais aussi l'ingénieure en général, et elles peuvent être bien plus complexe à détecter. De plus, il serait trop optimiste de laisser la faute uniquement à la machine : le système de build de gem5 est très fragile et têtu (il hallucine souvent des disparitions et apparitions de dépendances, et sa nature monadique @build_systems le rend encore plus difficile à débugger). De même, il n'est pas toujours possible de build LLVM à partir de n'importe quelle révision, car sa branche principale se retrouve fréquemment au moins partiellement cassée.

C'est pour tenter de parer à ces problèmes que j'ai utilisé Nix @nix pour tenter de "packager" mon travail le plus possible : Nix permet de décrire de manière absolument _exacte_ les dépendances de chaque composant individuel. Par exemple, la révision exacte de LLVM que j'ai utilisée pendant mon stage est déclarée, ainsi que les étapes que j'ai suivies pour le build, mais surtout, les versions exactes des dépendances de LLVM sont déclarées, ainsi que les versions des outils de builds utilisés. Et il en est de même pour chaque maillon de cette chaîne : les dépendances exactes des outils de builds sont déclarées, et leurs dépendances aussi, etc. _ad infinitum_, jusqu'à arriver à un seul binaire exact qui est capable, accompagné des étapes utilisées pour construire chaque dépendance, de recréer l'entièreté de cette chaîne, jusqu'à LLVM, et plus loin si besoin.

#let ft_ironic = [
  Oui, je suis consciente de l'ironie de la légèreté cette phrase, quand ce rapport entier est dédié à explorer les caches en détail. Si ça vous rassure, un cache Nix est entièrement en lecture seule, donc nous n'avons pas de problème de cohérence de cache ici.
]

Ceci permet donc de recréer _à l'identique_ le build de LLVM que j'ai utilisé, car chaque compilation est exécutée dans une sandbox qui masque complètement n'importe quel objet (variable d'environnement, binaires sur le disque, internet, etc.) n'ayant pas été déclarée explicitement comme une dépendance. En plus des avantages évidents de pouvoir s'assurer que deux instructions de builds donnent exactement le même résultat sur différentes machines, cela permet aussi d'utiliser un cache#footnote(ft_ironic) pour distribuer des builds, plutôt que de demander à chaque personne de compiler manuellement sa propre copie. Et grâce au système de dépendances exactes de Nix, l'utilisation de ce cache est toujours équivalent à un build local, et ne demande pas de modifier d'état global sur la machine.

Un autre avantage de Nix est les outillages qui se sont développés autour, qui sont désormais assez matures pour pouvoir décrire tout aussi simplement un environnement de build classique (c.-à-d. avec la variable d'environnement `$CC` pointant vers un compilateur, `$LD` vers un éditeur de lien, etc.) mais utilisant notre version modifiée de LLVM. Et cet environnement de développement, puisqu'il est décrit avec Nix, a les mêmes propriétés de reproductibilité qu'un build "classique". Ainsi, il sera facile pour mes successeur⋅euse⋅s de reprendre exactement là où je me suis arrêtée, notamment même une _shell_ bash ayant exactement les mêmes outils que ce que j'utilisais moi-même#footnote[Dont l'outil de conversion de statistiques gem5 mentionné plus haut ! Et ce, sans avoir besoin de s'inquiéter de comment il est build, ou de sur quel repo il est distribué, etc.].
