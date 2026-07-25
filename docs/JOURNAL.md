# Journal

Une entrée par session. Quatre lignes suffisent. La ligne « surprise » est la plus
utile des quatre : c'est celle qu'on relit dans trois semaines.

---

## 2026-07-25 — V0 et V1 : le projet tourne et je peux le regarder

**Voulu** : un squelette Godot qui charge, le rendu PS2 en place, et surtout savoir si
Claude peut produire une image de Godot tout seul.

**Obtenu** : les deux. `godot --path game --script res://outils/capture.gd` rend une image
512×288 via Vulkan et l'enregistre. La boucle « génère, rends, regarde, corrige » est donc
fermée côté Godot aussi, pas seulement côté Blender.

**Surprises** — quatre, toutes utiles pour la suite :

1. **L'éclairage par sommet exige de la géométrie tessellée.** Un sol de 4 sommets n'est
   éclairé qu'à ses 4 coins, donc noir partout ailleurs. Les jeux PS2 tessellaient leurs
   sols pour cette raison exacte. **Le générateur de ville devra découper la chaussée en
   cellules de 2 m environ**, sinon les lampadaires n'éclaireront rien.
2. **Par sommet et par pixel donnent le même rendu à 512×288.** L'écart est invisible à
   cette résolution. On garde le par-pixel : plus prévisible, et le look PS2 vient du
   filtrage, de la basse résolution et du brouillard, pas du mode d'ombrage.
3. **L'ambiante doit être nettement au-dessus de la couleur du brouillard**, sinon tout ce
   qui n'est pas sous un lampadaire est un aplat parfaitement noir. Montée de 0,16 à 0,50.
4. **Le premier plan a besoin de sa propre source.** Le noir de l'avant-plan n'était pas un
   bug d'éclairage mais de composition : le lampadaire le plus proche était à 16 m. Dans le
   jeu réel, ce sont les phares du véhicule qui régleront ça — à ne pas oublier en V3.

**Prochain** : V2, textures 128 px et générateur de ville. Le sol tessellé est une
contrainte d'entrée, pas une optimisation à faire plus tard.
