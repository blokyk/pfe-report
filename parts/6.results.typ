#import "@preview/lilaq:0.6.0" as lq
#import "/utils.typ": *

= Résultats <sec_results>

Après ces presque 20 pages de rapport, de théorie, de conception, et de description d'implémentation, il est enfin temps de récolter les fruits de ces 5 mois de labeur. Nous avons désormais un compilateur capable d'insérer nos instructions automatiquement grâce à une passe d'optimisation, _et_ une moyen de modéliser les performances de ce programme de manière déterministe. Dans cette section, nous allons donc suivre le chemin d'un petit programme d'évaluation, de sa conception à la mesure d'impact de l'optimisation. Nous discuterons aussi du réel objectif de ce stage : la documentation.

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

Reste à admettre que ce benchmark est très loin d'être parfait : en plus d'être extrêmement synthétique, il est n'évalue _a priori_ pas du tout la contribution de comportement multi-threadés, que nous avions pourtant utilisés pour introduire le problème des protocoles de caches. Cependant, il est important de souligner que l'inquiétude première ces travaux est simplement d'éviter des inefficacités dans les protocoles de cohérence quand il en vient au comportement d'un seul coeur. Si un coeur demande une ligne de cache en mode exclusive un peu plus vite qu'il ne l'aurait autrement fait, on ne devrait pas particulièrement s'attendre à ce que ça affecte les performances moyennes, même dans une situation multicoeur. On pourrait tout de même faire mieux, mais il y avait d'autres tâches sur lesquelles se concentrer, et ce programme était acceptable comme benchmark.

== Optimisation et génération de binaire de tests avec LLVM

Comme discuté précédemment, nous n'avons pas besoin de modifier le programme pour activer ou désactiver cette optimisation. À la place, c'est maintenant, au moment de la compilation, que nous devons faire ce choix. Pour cela, nous pouvons simplement spécifier que notre cible de compilation support nos nouvelles instructions, avec `-march=rv64i_xstld`#footnote[Voir #far-footnote(<ft_vendor_ext>).], et l'optimisation s'activera toute seule. Pour générer un binaire sans cette optimisation, on peut alors simplement ne _pas_ spécifier `_xstld`.

Après avoir compilé ces binaires, on peut les déassembler, pour vérifier que l'optimisation s'est bien déclenchée. La @fig_decomp_diff montre la compilation de ces des deux versions du benchmark (sans et avec optimisation), puis l'inspection des différences de désassemblage entre les deux binaires.

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

Nous avons désormais préparé les deux versions compilées de notre binaire. Il ne reste plus qu'à mesurer leurs performances avec gem5. Pour cela, nous utiliserons une configuration très similaire au @lst_final_gem5_conf, en utilisant le @lst_base_gem5_run (avec bien sûr un changement de nom de binaire) pour charger le binaire lancer la simulation.

#let ft_m5reader = [
  Celui-ci est dans un format textuel _ad-hoc_ plus ou moins structuré, mais il n'est pas difficile d'écrire un petit programme qui convertit fidellement ses données au format JSON. Nous n'irons pas dans les détails dans ce rapport, mais avoir ces statistiques sous une forme plus structurées est extrêmement, et permet d'automatiser une plus grande partie de ces mesures.
]

Les résultats de la simulation qui nous intéressent le plus ici, ce sont les statistiques enregistrées dans le fichier `m5out/stats.txt`#footnote(ft_m5reader) généré par gem5. Celui-ci contient une quantité impensable d'information minutieuse sur chaque compoasnt du système ; nous nous intéressons surtout à :
  - *`simTicks`*, qui nous rapporte le nombre de "ticks" de simulation se sont écoulés pendant l'exécution de notre programme ; avec une fréquence de 1 GHz, un cycle d'horloge de CPU équivaut exactement à 100 ticks.
  - *`SendReadShared`* et *`SendReadUnique`*, qui indiquent, respectivement, le nombre de requêtes pour des lignes partagées et exclusives dans le cache.
  - *`reqOut.m_msg_count`*, qui représente le nombre de messages ayant été échangés dans le système de cache

Ce qu'on attend de ces statistiques, c'est que le nombre de messages échangés diminue (c'est, après tout, le but ultime de cette optimisation), que le nombre de requêtes uniques augmentent pendant que le nombre de requêtes partagées diminue, et enfin que le temps total d'exécution, représenté par le nombre de ticks, diminue. À noter également que la somme des requêtes partagés vs. uniques ne devrait pas être la même entre les deux exécutions, car la version "non-optimisée" fait justement des requêtes partagés qui sont ensuite transformées en uniques.

La @fig_bench_stats compare ces statistiques pour 

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

Le contexte de ce stage invitait doublement à ce que le travail accompli soit proprement documenté et packagé, d'une part car c'est un stage de recherche, et la reproductibilité des résultats de recherche (même non publiés ici) est cruciale pour le bon fonctionnement de la sciecnce ; et d'autre part car l'objectif était d'explorer des outils de production de code que l'équipe ne maîtrise pas en profondeur en interne.
Il y a donc un objectif explicite que quelqu'un d'autre, par exemple Johan ou un⋅e autre stagiaire, puisse référencer le travail et reproduire les expériences pour les pousser plus loin dans le cadre de la thèse.

En pratique, configurer et compiler LLVM et gem5 n'est pas trivial ; les grandes lignes sont documentées mais il y a de nombreuses options qui peuvent créer des maux de tête tels que : des compilations statiques consommant énormément d'espace disque ; des compilations en mode "Release" dans lequels l'option `-debug` est ignorée et toute l'introspection associée est indisponible ; ou encore des compilations pas assez parallèles prenant des heures ou trop parallèles crashant par manque de mémoire sur la machine de travail.
De façon générale, #todo[sur le serveur approprié de TIMA], la compilation de Gem5 prend 1 heure initialement et 10 minutes à chaque itération après modification du code source, et LLVM prend également 1 heure à froid avec des itérations entre quelques secondes et quelques minutes selon les fichiers modifiés ; trouver les bons paramètres sans expertise préalable est donc un investissement chronophage qu'il est désirable de ne faire qu'une fois.

La navigation dans ces grandes bases de code est aussi un produit du travail.
LLVM contient plusieurs millions de lignes de C++ et TableGen, et la séparation du compilateur en de nombreuses passes sur plusieurs représentations n'empêche pas qu'il y a beaucoup de structures de données entremêlées et des états globaux implicites.
Au-delà de la simple suite de commits, l'explication de quels fichiers ont été modifiés et quelles sont leurs contributions individuelles au système d'optimisation de lectures en cache facilitera grandement le travail des prochain⋅es.

Reste un dernier problème d'ingénierie relatif aux variations entre les machines de développement.
Le système de compilation de gem5 est fragile (car testé et diffusé principalement dans une image Docker spécifique) et LLVM a fréquemment des bugs sur sa branche `master`, donc il faut épingler une version spécifique ou un commit spécifique.


  - nix à la rescousse:
    - avoir un packaging hermétique
    - permet de facilement pin des versions
    - caching/distribution de builds built-in
    - (bonus: distribuer des dev envs facilements)

https://dl.acm.org/doi/abs/10.1145/2830168.2830172
