# Le releve de cout, mais PENDANT qu'on joue.
#
# `bg.ps1 diag` mesure une camera posee dans une ville vide. Ce qui coute
# vraiment se produit en jouant : on tourne un coin de rue, une mission
# instancie ses acteurs, dix voitures arrivent en meme temps. Aucun de ces
# moments n'existe dans un releve hors jeu.
#
# IL MESURE COMME diag_ville.gd, ET C'EST DELIBERE. Le temps de CHAQUE image
# via delta, jamais Engine.get_frames_per_second() — ce compteur ne se
# rafraichit qu'une fois par seconde, et l'echantillonner par image rend mille
# fois la meme valeur. Un pire cas lu ainsi ne veut rien dire ; ca a coute une
# fausse alerte et une matinee. Voir docs/11-pieges.md, piege 18.
class_name JaugePerf
extends Control

## Sur combien d'images on calcule. Trois secondes environ : assez pour qu'un
## a-coup ait une chance d'y figurer, assez court pour que les chiffres suivent
## ce qu'on est en train de faire.
const FENETRE := 180

## Au-dessus, l'image est ratee : le seuil des 30 images par seconde, ecrit en
## millisecondes parce que c'est ainsi qu'on le mesure.
const SEUIL_RATEE_MS := 33.3

var _images: PackedFloat32Array = PackedFloat32Array()


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)


func _process(delta: float) -> void:
	if not visible:
		return
	_images.append(delta * 1000.0)
	if _images.size() > FENETRE:
		_images.remove_at(0)
	queue_redraw()


## Vide l'historique. A l'allumage : les images d'un menu ouvert ou d'un
## chargement ne disent rien de ce qu'on va regarder.
func repartir() -> void:
	_images.clear()


# Le centile se lit sur une COPIE triee : l'ordre du releve n'a pas d'interet
# ici — la jauge se relit en continu — mais trier sur place fausserait la
# fenetre glissante, qui retire toujours l'entree la plus ancienne.
func _centile(p: float) -> float:
	if _images.is_empty():
		return 0.0
	var trie := _images.duplicate()
	trie.sort()
	var dernier := float(trie.size() - 1)
	return trie[int(clampf(round(p * dernier), 0.0, dernier))]


func _draw() -> void:
	var police := get_theme_default_font()
	if police == null or _images.is_empty():
		return

	var median := _centile(0.5)
	var ratees := 0
	for t in _images:
		if t > SEUIL_RATEE_MS:
			ratees += 1

	var lignes := [
		"%.1f ms  %.0f im/s" % [median, 1000.0 / maxf(median, 0.001)],
		"99e   %.1f ms" % _centile(0.99),
		"pire  %.1f ms" % _centile(1.0),
		"ratees %d / %d" % [ratees, _images.size()],
		"rendu  %d appels" % int(Performance.get_monitor(
				Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"memoire %.0f Mo" % (float(Performance.get_monitor(
				Performance.MEMORY_STATIC)) / 1048576.0),
	]

	# EN BAS A GAUCHE : l'argent occupe le haut a gauche, la version le haut a
	# droite, et le bandeau d'invite le bas au centre. C'est le seul coin libre.
	var l := 96.0
	var h := 8.0 + float(lignes.size()) * 11.0
	var coin := Vector2(4.0, size.y - h - 4.0)
	draw_rect(Rect2(coin, Vector2(l, h)), Color(0.02, 0.02, 0.03, 0.66))

	for i in lignes.size():
		# La premiere ligne porte le chiffre qu'on regarde : elle vire au rouge
		# des qu'une image est ratee. Une couleur se voit sans etre lue, et on
		# ne lit pas un tableau en conduisant.
		var teinte := Color(0.60, 0.82, 0.44)
		if i == 0 and ratees > 0:
			teinte = Color(0.85, 0.35, 0.22)
		elif i > 0:
			teinte = Color(0.72, 0.70, 0.64)
		_ecrire(police, str(lignes[i]), coin + Vector2(5.0, 13.0 + float(i) * 11.0),
				9, teinte)


func _ecrire(police: Font, texte: String, ou: Vector2, taille: int,
		couleur: Color) -> void:
	police.draw_string(get_canvas_item(), ou + Vector2(1, 1), texte,
			HORIZONTAL_ALIGNMENT_LEFT, -1, taille, Color(0, 0, 0, couleur.a))
	police.draw_string(get_canvas_item(), ou, texte, HORIZONTAL_ALIGNMENT_LEFT,
			-1, taille, couleur)
