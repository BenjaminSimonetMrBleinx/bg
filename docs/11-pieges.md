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

## 16. Un état différé n'est pas un état absent

Le chapeau bascule au milieu du geste, une demi-seconde après le choix. Un test
qui mesure tout de suite trouve l'objet **précédent** encore visible et conclut
que tout va bien. Attendre une **condition**, jamais un nombre de trames : le
mode sans fenêtre ne tourne pas à la vitesse d'un affichage.
