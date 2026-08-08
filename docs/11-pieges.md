# Les pièges

**Ce que ce projet a appris en se trompant.** Un piège entre ici quand il a
coûté plus d'une heure, ou quand il a été payé deux fois.

Ils ont presque tous la même forme, et c'est le seul enseignement qui compte :

> **rien ne prévient.** Le code tourne, la console annonce un nombre juste, la
> capture semble correcte, aucun avertissement n'est émis — et le résultat est
> faux. Un piège qui lève une erreur n'est pas un piège, c'est un bug.

---

## 1. Mesurer la scène au lieu du fichier produit

**Payé quatre fois.** C'est le piège central du projet.

| Cas | Ce que la console disait | Ce que le fichier contenait |
|---|---|---|
| Lacet d'import de l'Aztek | rotation appliquée | aucune rotation, jamais |
| Figurants | 1,68 m | 170 m |
| Objets équipés | accrochés, visibles | rendus à 1/100 de leur taille |
| Pieds de Walter | −13 m | mesure en unités d'armature, pas en mètres |

**La parade.** Tout outil qui écrit un `.glb` le **relit** et annonce ses cotes
finales dans le repère de Godot. `importer_modele.py` et
`mettre_a_l_echelle.py` le font ; tout nouvel outil doit le faire.

---

## 2. `bpy.ops.object.transform_apply` n'agit que sur la sélection

Sans objet sélectionné **et actif**, l'opérateur repart sans rien faire et sans
se plaindre. Le `--lacet` de l'import n'a jamais fonctionné pour cette raison,
et deux tentatives de « retourner la voiture » n'ont rien changé puisque ni
l'une ni l'autre n'était appliquée.

**La parade.** Écrire dans les données : `obj.data.transform(Matrix...)`. Et
quand l'objet porte déjà une transformation, conjuguer : `M⁻¹ · S · M`, sinon
on met à l'échelle dans un repère déjà mis à l'échelle et le résultat ne bouge
pas.

---

## 3. L'échelle d'objet ne survit pas à l'export glTF

Une armature à la bonne taille dans Blender sort à sa taille d'origine dans le
`.glb` si l'échelle vit sur l'**objet**. Les figurants sortaient à 170 m avec
un fichier de travail parfaitement juste.

**La parade.** `outils/mettre_a_l_echelle.py`, qui écrit dans les données et
relit le fichier.

---

## 4. Les unités d'armature ne sont pas des mètres

Sur le rig de Walter, l'échelle du squelette vaut **0,011** : ses os sont longs
de deux mille unités. Conséquences observées :

- une mesure de pieds annonçait −13 m pour tous les clips, donc ne
  discriminait rien ;
- un décalage de 24 cm posé sur une attache d'os valait 2,6 mm, et le chapeau
  restait planté dans le crâne ;
- **tout objet équipé était rendu à un centième de sa taille** — le revolver
  mesurait deux millimètres. Il était chargé, accroché, déclaré visible.

**La parade.** Diviser par `ancre.global_transform.basis.get_scale()`, ou
exprimer le décalage dans le repère du monde et le convertir une fois
(`aplomb` dans `outils.json`).

---

## 5. La boîte englobante d'un maillage décrit la géométrie AVANT déformation

Sur un personnage livré à plat, elle annonce n'importe quoi. Les figurants du
pack sont **invisibles** sans leur clip : leur maillage de repos est couché.

**La parade.** Mesurer sur les **os**, jamais sur la boîte.

---

## 6. Une action encore assignée repose le squelette sous vos pieds

Elle est réévaluée au prochain rafraîchissement. En mesurant le crâne pour y
poser un chapeau, on obtenait 1,24 m au lieu de 1,85 : le squelette était
encore dans la pose **assise** du clip précédent.

**La parade.** `arm.animation_data.action = None` avant toute mesure.

---

## 7. Les rotations ne se transfèrent pas entre deux rigs différents

Mesuré : les os de Walter pointent chacun dans l'axe de leur membre ; ceux d'un
Biped pointent **tous** dans la même direction. Recopier une pose de l'un à
l'autre donne une contorsion, pas une pose.

**Symptôme observé :** Jesse planté sans animation, avec une marche dont la
foulée mesurait **zéro mètre**. Et Tuco assis les bras en croix.

**La parade.** Refabriquer les clips sur le squelette cible à partir de SA
marche livrée. Le report entre rigs différents passe par l'espace monde, et
reste non résolu — c'est le fond du ticket #16.

---

## 8. Un solveur ne paie que ce qu'on lui fait payer

Le geste des lunettes visait la bonne cible et faisait passer l'avant-bras dans
la poitrine sur **douze centimètres**, parce que le coût ne regardait que le
point d'arrivée. Le chemin ne coûtait rien.

**La parade.** Modéliser le buste et le crâne en volumes mesurés sur le rig, et
payer ce que le membre traverse. Et doser : on remonte ses lunettes coude bas,
on ne met **pas** un chapeau coude bas — avec le même réglage, la main
s'arrêtait à dix centimètres du crâne.

---

## 9. Godot ne propage pas les entrées dans un SubViewport

Toute l'interface du jeu vit dans un `SubViewport` affiché par un
`TextureRect`. Un `_gui_input` ou un `_unhandled_input` y est **silencieusement
mort** : la roue s'ouvrait, s'animait, se fermait, et la sélection ne bougeait
jamais.

**La parade.** Scruter (`Input.is_action_just_pressed`), c'est la convention du
projet. Et convertir la souris à la main :
`get_tree().root.get_mouse_position() / Vector2(root.size) * size`.

---

## 10. Un modèle rigué regarde +Z, un modèle sans animation regarde −Z

Le canal racine de l'animation écrase la rotation d'import. Le critère du demi-
tour est donc la **présence d'un `AnimationPlayer`**, pas le format du fichier.
Sans ça, Jesse et Tuco tournaient le dos à qui leur parlait.

---

## 11. Un générateur écrase un modèle livré sans le dire

Le Jesse de Guillaume — 6,6 Mo — a été remplacé par 68 Ko de corps générique
par un `generer` lancé pour une tout autre raison.

**La parade.** Retirer de la table du générateur toute clé dont le modèle est
livré. C'est fait pour `jesse` et pour `chapeau` ; à vérifier à chaque
intégration.

---

## 12. La version vit dans `project.godot`, et nulle part ailleurs

`config/version=`. `version.json` en est régénéré. Bumper le second ne fait
rien de visible, et l'exécutable annoncerait un numéro que le jeu contredit.

---

## 13. `-Modifies` n'est pas ciblé

Dès qu'un fichier partagé bouge — `monde.tscn`, `controleur.gd` — il relance
les 27 suites. Croire qu'on économise en l'utilisant est une erreur commise
deux fois dans la même journée.

---

## 14. Une expression régulière trop courte attrape ses voisins

`acceleration = [0-9.]+` a aussi remplacé `marche_acceleration`, ce qui a réglé
l'accélération de la marche à 900. Rattrapé dans le diff, pas par un test.

---

## 15. Supprimer un objet en Blender invalide les références Python

Y compris celles vers **d'autres** objets. Les lectures renvoient de la mémoire
réattribuée, les écritures partent dans le vide, sans erreur.

**La parade.** Re-résoudre par le nom après toute suppression.

---

## 16. Un here-string PowerShell ne tient pas dans un bloc YAML

PowerShell exige que le `"@` de fermeture soit en **colonne zéro**. Un bloc
YAML `run: |` se termine dès qu'une ligne revient en colonne zéro. Les deux
règles s'excluent.

Le fichier de workflow devenait invalide, et GitHub échouait **en zéro seconde
sur chaque push**, y compris ceux qui n'avaient rien à voir avec une release —
donc un mail d'échec à chaque commit.

**La parade.** Un tableau de chaînes joint par `-join "`n"`, indenté comme le
reste. Et une vérification locale avant de pousser :

```powershell
python -c "import yaml,io; yaml.safe_load(io.open('.github/workflows/release.yml',encoding='utf-8'))"
```

**Ce que ça rappelle :** un workflow ne se teste pas en le poussant. Un fichier
de configuration qui n'est validé que par le serveur distant est un fichier
qu'on écrit à l'aveugle.

---

## 17. Un état différé n'est pas un état absent

Le chapeau bascule au milieu du geste, une demi-seconde après le choix. Un test
qui mesure tout de suite trouve l'objet **précédent** encore visible et conclut
que tout va bien. Attendre une **condition**, jamais un nombre de trames : le
mode sans fenêtre ne tourne pas à la vitesse d'un affichage.

---

## 18. Un compteur de moteur n'est pas la mesure qu'il annonce

`diag_ville.gd` a signalé un effondrement du jeu : pire cas tombé de 38 à
**7 images/seconde**, 8 images ratées sur 180, et **16,5 ms de scripts par
image**. De quoi ouvrir une session d'optimisation. Le jeu tournait en réalité
avec vingt-six fois la marge nécessaire, et **zéro** image ratée.

Trois compteurs, trois mensonges — et aucun n'était un bug :

| Ce qu'on lisait | Ce que c'est vraiment |
|---|---|
| `Engine.get_frames_per_second()` échantillonné par image | Un compteur **rafraîchi une fois par seconde**. 180 échantillons sur 3 s ne donnent que 3 valeurs : « 8 images ratées » = 8 échantillons pris dans la même seconde basse, et « 7 au pire » = une seconde entière, jamais une image |
| `Performance.TIME_PROCESS`, lu comme « scripts par image » | Le **maximum de la seconde écoulée**, sur tout le traitement hors physique. Les 16,5 ms valaient une synchro verticale (16,7 ms) — le chiffre disait « le jeu tourne pile à 60 » |
| 60 images de chauffe | ≈ 1 seconde. Le chargement étant descendu à 0,52 s, la mesure démarrait dans la compilation des shaders et la publiait comme pire cas du jeu |

**La parade.** Mesurer le `delta` de chaque image, soi-même, et couper la
synchro verticale — sinon toute image qui tient dans le budget sort à 16,7 ms
et médiane, 99e centile et pire cas affichent le même chiffre. Sortir le **99e
centile** plutôt que la moyenne, et **l'instant** de chaque pic : trois pics
collés au début sont un reste de chauffe, trois pics régulièrement espacés sont
un traitement périodique, et le maximum seul ne permet ni l'une ni l'autre
lecture.

**Ce que ça rappelle :** la règle d'or dit *une image ou un nombre, jamais une
conviction*. Elle a un revers — **un nombre n'est une preuve que si on a lu le
code qui le produit.** Ici l'instrument mesurait sa propre synchro verticale et
son propre démarrage, et il l'annonçait avec l'aplomb d'un chiffre. C'est la
première fois que ce projet se trompe dans ce sens-là : d'habitude un outil
annonce un nombre juste et écrit un fichier faux ; cette fois il n'y avait pas
de fichier, seulement le nombre, et personne pour le contredire.

---

## 19. Une vérification qui se place elle-même au bon endroit valide toujours

`test_desert.gd` contrôlait qu'on peut repartir du désert. Il **téléportait la
voiture sur la zone de retour**, puis vérifiait qu'elle rentrait en ville. Il
passait au vert depuis une semaine pendant que la zone était à **vingt-six
mètres de la piste**, donc introuvable en roulant.

Le test ne mesurait pas ce qu'il annonçait. Il mesurait ce qui se passe *une
fois qu'on y est* — c'est-à-dire la seule partie qui n'était pas cassée.

Même famille, même soirée, trois fois :

| L'instrument | Ce qu'il annonçait | Ce qu'il mesurait |
|---|---|---|
| `test_desert.gd` | « on peut repartir » | ce qui arrive quand on est déjà sur la sortie |
| Situation `camping_car_porte` | « la porte du jeu tombe sur la porte du modèle » | du sable, à 29 m du véhicule, en écrivant un PNG valide |
| La même, vue à la verticale exacte | une géométrie | une image **sans haut ni bas** : caméra au-dessus visant droit en dessous, l'orientation n'est plus définie et rien n'y est trancheable |

**La parade.** Avant de croire un test qui passe, se demander **quel geste du
joueur il reproduit**. S'il commence par placer quelque chose à la main, il ne
vérifie pas qu'on peut y arriver — et « on peut y arriver » est presque toujours
la question. Ajouter alors la mesure que le placement empêchait de poser : ici,
la distance entre la sortie et le point d'arrivée, en mètres imprimés.

**Le corollaire pour les captures.** Une vue qui vise des coordonnées écrites à
la main se périme le jour où le générateur bouge ce qu'elle photographie, et
elle ne le dit pas. Une vue se pose **autour de ce qu'elle montre** — c'est ce
que fait `autour` dans `scenarios.json`. Et jamais à la verticale exacte : il
faut un angle, sinon l'image n'a pas d'orientation et on y lit ce qu'on veut.

---

## 20. Couper un lien ne remet pas la valeur par défaut, il découvre celle du dessous

Trois variantes du camping-car sont sorties **entièrement blanches**, alors que
leur texture de couleur était bien dans le fichier et correctement liée.

La cause : en jetant les canaux PBR inutiles, on avait coupé le lien de la
texture **émissive** vers le shader. Or l'entrée « émission » d'un Principled
vaut blanc, force 1, par défaut — la texture ne faisait que la moduler. Le lien
coupé, il restait un blanc plein : le matériau émettait, l'export écrivait
`emissiveFactor: [1, 1, 1]`, et la couleur de base était noyée dessous.

**La parade.** Après avoir débranché une entrée, **écrire la valeur neutre**
qu'on veut voir à la place. Débrancher n'est pas neutraliser.

**Comment on l'a trouvé** : en lisant le bloc `materials` du `.glb` produit, pas
en regardant Blender. La scène Blender était juste ; c'est le fichier qui
portait le défaut, et c'est encore la règle numéro un du projet.

---

## 21. Une capture montre où un objet FINIT, pas où on l'a posé

Le point d'entrée du camping-car a été placé, puis photographié avec Walter
dessus : l'image le montrait **dehors, contre le flanc, devant la porte**.
Impeccable. Le test, lui, annonçait le point **1,20 m à l'intérieur de la
coque**.

Les deux avaient raison. La coque du véhicule est aussi sa **collision** : la
capsule du joueur, téléportée dans le volume, en avait été **éjectée par la
physique** dans les images qui précèdent la prise de vue. La photo montrait
l'endroit où Walter s'était stabilisé, pas celui où on l'avait mis.

**La parade.** Un scénario qui `place` quelque chose puis photographie ne prouve
la position que si rien ne peut la corriger entre-temps. Pour un point qui doit
être *atteignable*, mesurer la géométrie — `test_desert.gd` interroge désormais
la boîte de la coque et imprime la marge en mètres, négative dedans, positive
dehors.

**Et la leçon de méthode :** quand une image et un nombre se contredisent, aucun
des deux ne ment forcément. Ils ne répondent simplement pas à la même question,
et il faut trouver laquelle avant de corriger quoi que ce soit.

---

## 22. Une conversation ne s'ouvre ni en capture, ni dans la suite `mission`

Deux vérifications de la boucle des courses se sont arrêtées **sans un mot** :
Godot quittait, aucun message d'erreur, aucune trace. Le point commun : les deux
finissaient par ouvrir un dialogue.

- La situation de capture appuyait sur la touche d'interaction devant le plan de
  travail. La conversation s'ouvrait, l'image n'était jamais prise.
- La suite `mission` appelait `point_utilise()`, qui démarre la réponse de
  Skyler.

**Ce n'était pas le contenu neuf.** On l'a mesuré en démarrant `telephone_skyler`
— une fiche qui existe depuis des semaines — au même endroit : même arrêt net.
C'est le contexte qui ne le supporte pas, pas la fiche.

**La parade.** Séparer ce qui se mesure de ce qui se joue. `poser_les_courses()`
est publique, fait le retrait et le crédit, et renvoie si on avait de quoi ; le
dialogue vit dans `point_utilise()`, une ligne au-dessus. Le test vérifie la
mécanique et se contente de contrôler que les deux fiches **existent** —
`dialogue.connait()` ne les ouvre pas.

**Le réflexe général :** avant de conclure qu'un ajout casse un test, refaire le
même geste avec quelque chose qui marchait déjà. Ça coûte une exécution et ça
évite de réécrire du code qui n'avait rien.

---

## 23. `generer` ne reproduit pas la ville du dépôt — il en fabrique une plus petite

**Le pire piège trouvé jusqu'ici, parce qu'il détruit sans rien dire.**

`.\bg.ps1 generer` a été lancé pour monter les textures. Il s'est terminé
normalement, sans erreur. La ville est passée de :

| | Avant | Après `generer` |
|---|---|---|
| Étendue | **519 m** | 137 m |
| Lampadaires | **526** | 32 |
| Éléments de décor | **2 674** | 297 |
| Triangles | **62 910** | 7 134 |

**La cause :** `bg.ps1` a `[int]$Blocs = 2` en valeur par défaut, et la ville du
dépôt n'a jamais été générée avec 2 blocs. Le vrai nombre n'est écrit **nulle
part** — ni dans le journal, ni dans les notes de version, ni dans un commentaire.

Le seul symptôme visible venait après, et de biais : `ancrage : aucun lieu nommé
'terrain_vague_3_7'`. La ville neuve n'avait plus les quartiers que le reste du
jeu référence.

**La parade, en attendant mieux : ne pas lancer `generer` tout court.** Les
générateurs s'appellent un par un, et seuls `gen_ville.py` et `gen_banc_graphique.py`
dépendent de `--blocs` :

```powershell
blender -b -P outils/gen_lieux.py   -- --nom tous
blender -b -P outils/gen_maison.py  -- --nom toutes
blender -b -P outils/gen_decor.py   -- --nom tous
```

**Ce qui sauve, c'est que `game/assets/` est versionné** : `git checkout --
game/assets` a tout rendu. Si la génération avait été commitée, la ville était
perdue — elle n'existe que comme fichier, sa graine ne suffit pas à la refaire
sans son nombre de blocs.

**Réglé le jour même.** Le nombre a été retrouvé en générant 7, 8 et 9 **dans un
dossier à part** — `gen_ville.py` accepte `--sortie`, donc on peut chercher sans
rien risquer — et en comparant l'étendue publiée :

| `--blocs` | Étendue | Lampadaires |
|---|---|---|
| 7 | 466 m | 384 |
| **8** | **519 m** | **526** |
| 9 | 576 m | 658 |

Huit tombe pile, et la graine 505 était déjà la bonne. `bg.ps1` a maintenant
`[int]$Blocs = 8`, et la valeur est commentée avec la raison — sans quoi elle
redeviendra un nombre magique que le prochain changera.

**La leçon générale : un défaut qui détruit est pire qu'une erreur.** Une commande
qui refuse de tourner se corrige en une minute ; une commande qui tourne et
remplace le travail par autre chose ne se voit que trois sessions plus tard.

---

## 24. `mat.use_nodes = True` casse `generer` en Blender 5.2, et ne sert plus à rien

Le même piège que celui documenté dans `aplatir()`, mais dans neuf générateurs.

`Material.use_nodes` est déprécié. L'affecter écrit un `DeprecationWarning` sur
la **sortie d'erreur**, et PowerShell traite la moindre ligne de stderr d'un
binaire natif comme une erreur : `generer` s'arrêtait sur `gen_ville.py:331`,
avec un message qui parlait de Blender 6.

**Et la ligne ne servait déjà plus.** Mesuré : en Blender 5.2,
`bpy.data.materials.new()` crée **déjà** le `node_tree` et son Principled BSDF.

```
APRES new()      : node_tree = present
BSDF present     : True
```

Les onze occurrences ont été retirées. Les `scene.world.use_nodes` sont restés —
c'est un `World`, pas un `Material`, et ces fichiers ne sont pas dans la chaîne.

**Le réflexe :** avant de contourner un avertissement de dépréciation, vérifier
si la ligne fait encore quelque chose. Souvent elle ne fait plus que se plaindre.

---

## 25. L'échelle était **écrasée**, pas multipliée — et l'instrument mentait aussi

Deux bugs emboîtés, découverts sur le premier modèle 3D généré. L'ordre dans
lequel ils sont apparus est toute la leçon.

### Le symptôme

`integrer -Hauteur 0.48` annonçait `echelle x1.2000 pour atteindre 0.48 m`, et
écrivait un fichier de **1,198 m**. Deux fois et demie trop grand, sans un mot.

### Le vrai bug

```gdscript
obj.scale = (facteur,) * 3        # AVANT — ecrase
obj.scale = tuple(s * facteur for s in obj.scale)   # APRES — multiplie
```

Il était là depuis toujours et **ne pouvait pas se déclencher** : tous les
modèles livrés à la main arrivent à l'échelle 1, et écraser 1 par 1,2 donne 1,2.

Un modèle Tripo, lui, arrive avec **une échelle de 0,4008 sur son nœud**. La
boîte mesurait donc correctement 0,400 m, le facteur 1,2 était correct — et
l'écrasement rendait `0,998 × 1,2` au lieu de `0,400 × 1,2`.

**La règle : une transformation se compose, elle ne se remplace pas.** Un défaut
qui dort pendant cinquante imports n'est pas un défaut absent.

### Le faux coupable, et c'est le plus instructif

Avant de trouver ça, `lire_glb.py` — que je venais d'écrire — a désigné
`importer_modele.py`. Il lisait les `min`/`max` des accesseurs de POSITION en
croyant tenir « la mesure du fichier ».

**Il ignorait les transformations de nœuds.** Sur ce modèle il annonçait 0,998 m
quand l'objet en fait 0,400. J'ai donc conclu que la chaîne écrivait un fichier
faux, et j'ai « corrigé » du code qui n'avait rien — un détachement de parent qui
ne servait à rien.

C'est le **piège 18 à l'identique** : avant de corriger ce qu'un instrument
dénonce, vérifier l'instrument. La différence, cette fois, c'est que
l'instrument avait dix minutes d'âge et que je l'avais écrit moi-même.

`_etendue()` compose maintenant les matrices de nœuds et transforme **les huit
coins** — deux ne suffisent plus dès qu'il y a une rotation.

### Et un troisième cas, qu'il faut dire plutôt que mesurer

La même fonction annonçait **0,018 m pour Walt**, qui fait 1,78 m. Un maillage
peau est en pose de référence : c'est l'armature qui le place. `lire_glb` rend
donc `hauteur = None` sur un modèle riggé, et le dit. **Mieux vaut rien qu'un
nombre faux** — un appelant qui compare à une cible croirait au nombre.

### Ce qui a sauvé la mise

Le garde-fou ajouté au même moment : `integrer` **relit le fichier écrit** et
refuse si la hauteur ne correspond pas à 1 % près. C'est lui qui a rendu les
trois bugs visibles au lieu de les laisser passer en silence.

---

## 26. `diag` mesurait un endroit différent à chaque fois

**Le piège 18 pour la troisième fois, et c'est celui qui coûte le plus cher en
mauvaises conclusions.**

Deux relevés consécutifs, sans qu'une ligne de code ait bougé entre les deux :

```
temps d'image  0.7 ms median,  125 appels de rendu
temps d'image  5.0 ms median,  906 appels de rendu
```

Un facteur sept. J'en ai conclu qu'un shader de verre coûtait quatre
millisecondes, et j'ai commencé à le démonter. Il ne coûte rien : mesuré avec et
sans, à quelques minutes d'écart, **4,8 contre 5,0 ms**.

**La cause :** `monde.tscn` **reprend la sauvegarde** à son chargement. Le relevé
se fait donc là où la dernière partie s'est arrêtée. Et comme chaque
`bg.ps1 capture` joue une situation puis sauvegarde en partant, l'endroit change
tout seul entre deux `diag`. En périphérie de la ville : 22 appels de rendu. En
plein centre : 906.

**La parade.** `diag_ville.gd` pose maintenant le joueur à un **point fixe**,
`(0, 1.5, 0)`, à la même image que l'heure. Deux relevés consécutifs donnent
2,4 et 2,8 ms — cohérents.

Le point est en dur et **pas un lieu nommé** : les noms viennent du générateur et
changent avec la graine. `terrain_vague_3_7` existait le matin et plus
l'après-midi (voir piège 23). `--lieu <nom>` reste disponible pour mesurer
ailleurs volontairement.

---

## 27. J'ai écrasé un test, et le remplaçant était moins exigeant

**Le plus cher de la session, parce qu'il ne se voit pas.** J'ai écrit
`verifs/test_voix.gd` en croyant le créer. Il existait depuis deux commits, et
`git status` l'a affiché `M` — modifié — au lieu de `??`. C'est la seule chose
qui l'a signalé, et je ne l'ai vu qu'au moment de commiter.

Le test que j'ai remplacé faisait **deux choses de plus** que le mien :

1. **Il mesurait la crête du bus audio**, pas la présence du fichier. Un WAV
   valide de zéro seconde se charge sans erreur et ne s'entend pas — compter les
   fichiers l'aurait déclaré bon. Le mien comptait les fichiers.
2. **Il appelait `Dialogue.VOIX` et `Dialogue._simplifier()`** au lieu de les
   recopier. Son commentaire disait pourquoi, et j'ai fait exactement ce qu'il
   interdisait : *« si le test refaisait le sien, il validerait sa propre
   convention et pas celle qui est réellement utilisée »*. Deux copies de la
   même règle restent d'accord entre elles en étant fausses toutes les deux.

**La parade, et elle vaut au-delà des tests :** avant d'écrire un fichier dans
`verifs/`, `outils/` ou `systemes/`, vérifier qu'il n'existe pas. `Write` écrase
sans rien demander. Et devant un `M` là où on attendait `??`, s'arrêter : c'est
un fichier qu'on croyait neuf.

Le test livré est la **fusion** : la mesure de volume et l'appel aux fonctions du
jeu viennent de l'ancien, le détail par personnage et la distinction
« posée mais pas importée » du nouveau. Il relève **−6,5 dB** sur le bus
Interface, ce qui est la seule preuve qu'on entend quelque chose.

---

## 28. `ConvertFrom-Json` rend un tableau comme UN SEUL objet

Trois voix sont sorties fusionnées en une, sous le nom `Jesse Walter Tuco`, sans
la moindre erreur :

```powershell
$lot = @(Get-Content $f -Raw | ConvertFrom-Json)   # $lot.Count = 1
```

PowerShell 5.1 ne déroule pas un tableau JSON dans le pipeline : il l'émet
entier. Le `@()` autour n'en fait donc pas une liste de *n* éléments, mais une
liste de **un** qui les contient tous — et `$v.qui` sur cette collection
concatène silencieusement les valeurs de tous les éléments.

```powershell
$lot = @()
$lot += (Get-Content $f -Raw | ConvertFrom-Json)   # le += aplatit
```

**Ce qui rend ce piège coûteux :** il ne lève rien. La boucle tourne une fois,
le script annonce « 1 voix à ranger » au lieu de 8, et il faut lire ce nombre
pour s'apercevoir qu'il est faux.

### Ce que ça a coûté en affirmations fausses

La note de version de la 0.51.0 annonçait « 0,6 ms avant, 0,7 après ». Les deux
chiffres étaient réels et la conclusion était juste — **la refonte ne coûte
rien** — mais ils décrivaient deux endroits différents et ne se comparaient pas.

La mesure honnête, faite au même point en coupant les effets par réglage :

| | Temps d'image | Appels de rendu |
|---|---|---|
| Effets coupés | 3,0 ms | 751 |
| **0.51.0 complète** | **2,8 ms** | 786 |

L'écart est dans le bruit. **Une mesure de performance ne vaut que si l'on peut
dire où elle a été prise.**
