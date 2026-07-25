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

1. **Fausse piste, corrigée le jour même.** J'ai d'abord conclu que l'éclairage par sommet
   imposait de tesseller toutes les grandes surfaces — un sol de 4 sommets n'étant éclairé
   qu'à ses 4 coins. C'était vrai en par-sommet, mais **on a gardé le par-pixel**, et là un
   sol de 4 sommets s'éclaire très bien. La vraie cause du sol noir était le point 4.
   Leçon de méthode : j'ai tiré une règle générale d'une observation faite dans une
   configuration qu'on allait justement abandonner. Les docs ont été corrigées.
2. **Par sommet et par pixel donnent le même rendu à 512×384.** L'écart est invisible à
   cette résolution. On garde le par-pixel : plus prévisible, et le look PS2 vient du
   filtrage, de la basse résolution et du brouillard, pas du mode d'ombrage.
3. **L'ambiante doit être nettement au-dessus de la couleur du brouillard**, sinon tout ce
   qui n'est pas sous un lampadaire est un aplat parfaitement noir. Montée de 0,16 à 0,50.
4. **Le premier plan a besoin de sa propre source.** Le noir de l'avant-plan n'était pas un
   bug d'éclairage mais de composition : le lampadaire le plus proche était à 16 m. Dans le
   jeu réel, ce sont les phares du véhicule qui régleront ça — à ne pas oublier en V3.

**Aussi** : passage en **4/3** (rendu interne 512 × 384, fenêtre 1024 × 768, ratio verrouillé
donc bandes noires sur écran large). Et convention audio arrêtée : WAV+QOA pour les
bruitages, Ogg pour la musique, jamais de MP3, tout son 3D en mono.

**Prochain** : V2, textures 128 px et générateur de ville.

---

## 2026-07-25 (suite) — V2 et V3 : la ville existe, la voiture roule

**Voulu** : une ville générée qu'on puisse parcourir, et un véhicule conduisible.

**Obtenu** : les deux. Chaîne complète Python → Blender → glTF → Godot, sans intervention
humaine. Ville de 2 × 2 îlots, 122 m de côté, 743 faces. Voiture de 54 faces, roue de 30.

**Surprises** :

1. **Une seule travée par texture de façade était une erreur.** Toutes les fenêtres d'un
   immeuble se retrouvaient dans le même état — bâtiment entièrement éteint, mort. Passé à
   2 × 2 travées : le mélange allumé/éteint apparaît, et la répétition se voit moins. C'est
   ce que faisaient les jeux PS2, pour cette raison exacte.
2. **32 lampadaires à énergie 9 saturent tout.** Le premier rendu était un aplat orange.
   Descendu à 2,6 avec 17 m de portée. Leçon : l'éclairage se règle après avoir posé
   *toutes* les sources, jamais sur une seule.
3. **La caméra de capture était écrasée par la caméra de poursuite**, qui réécrit sa
   position à chaque image de physique. L'outil crée maintenant sa propre caméra et la rend
   active — robuste quel que soit le script en place.
4. **Le toit de la voiture était en verre.** Mon test « est-ce la cabine ? » couvrait tout
   le pavillon. Seules les faces réellement inclinées — pare-brise et hayon — sont vitrées.
5. **Une gomme de pneu photométriquement juste est invisible de nuit.** Éclaircie
   arbitrairement de 27 à 46. Le réalisme perd contre la lisibilité, systématiquement.

**Ce que je ne peux pas juger** : si conduire est agréable. Les 150 images de physique
tournent sans erreur, la voiture tient la route, mais le ressenti se teste au clavier.
C'est le seul point où Benjamin est indispensable.

**Deux bugs remontés par Benjamin au premier essai au clavier**, et ils valident la
méthode : je ne pouvais pas les trouver seul.

6. **Le `VehicleBody3D` de Godot pousse vers +Z, pas vers -Z.** Exception à la convention
   du moteur, où tout le reste — caméras, `look_at` — regarde vers -Z. J'ai tranché en
   mesurant plutôt qu'en relisant la documentation : `outils/test_sens.gd` applique une
   poussée et projette le déplacement sur le nez. Verdict sans appel, 9,81 m à l'envers.
   Corrigé par une constante `SENS_POUSSEE`, pas en retournant la scène — mélanger deux
   conventions dans un même projet coûte plus cher qu'un signe documenté.
7. **La marche arrière tremblait parce que je comparais une vitesse NON signée.** Reculer
   fait monter cette vitesse, elle repasse le seuil, le code croit qu'on avance et freine,
   la vitesse retombe, il repart en arrière. Plusieurs fois par seconde. Corrigé en
   projetant la vélocité sur l'axe du nez : le signe distingue enfin « je freine » de
   « je recule ».

Le test de sens est resté dans le dépôt comme non-régression, accessible par
`.\bg.ps1 test`. C'est typiquement le piège qui revient à la première refonte.

**Prochain** : V4, Walter jouable à pied.
