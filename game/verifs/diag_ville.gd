# Ce que coute la ville, en chiffres.
#
#   godot --path game --script res://verifs/diag_ville.gd
#
# Ce n'est PAS une suite de tests : il n'y a rien a valider, aucun seuil ecrit
# quelque part, et le fichier ne dit jamais non. C'est un instrument. On
# l'utilise avant et apres avoir change la taille de la ville, et on compare
# les deux relevés.
#
# CE QU'IL MESURE, ET POURQUOI CEUX-LA. La geometrie n'est pas le probleme :
# une ville de huit ilots de cote tient en douze mille faces, ce qui ne coute
# rien. Ce qui monte avec la surface, c'est tout ce qui est POSE dedans —
# lampadaires, mobilier, voitures garees, passants — et chacun est un noeud,
# donc un cout par image que le nombre de triangles ne dit pas.
extends SceneTree

## Images laissees passer avant de commencer a chronometrer. Les premieres
## portent la construction des collisions, l'instanciation du decor et la
## COMPILATION DES SHADERS, qui se fait a la premiere image ou chaque materiau
## entre dans le champ. Une seconde de chauffe ne suffisait pas : le releve
## mesurait encore son propre demarrage et le sortait comme un pire cas du jeu.
const CHAUFFE := 180

## Duree de la mesure. Dix secondes, la ou trois ne laissaient pas a un a-coup
## periodique le temps de se produire deux fois — et un a-coup vu une seule fois
## ne se distingue pas d'un accident. On compte en SECONDES et pas en images :
## sans la synchro verticale le jeu tire des centaines d'images par seconde, et
## un compte d'images retrecirait la fenetre d'observation juste au moment ou
## l'on cherche le pic rare.
const MESURE_MS := 10000.0

## Au-dessus de ce temps, l'image est ratee : c'est le seuil des 30 images par
## seconde, ecrit en millisecondes parce que c'est ainsi qu'on le mesure.
const SEUIL_RATEE_MS := 33.3

var _monde: Node
var _n := 0
var _debut_ms := 0
var _chargement_ms := 0
var _heure: float = -1.0

# Une entree par image mesuree, dans l'ordre ou elles sont tombees. L'ORDRE
# EST LA MOITIE DE L'INFORMATION : un pic a la premiere image mesuree est un
# reste de demarrage, un pic qui revient toutes les deux secondes est un
# traitement periodique, et les deux sortent le meme chiffre si on ne garde
# que le maximum.
var _cumul_ms := 0.0
var _image_ms: PackedFloat32Array = PackedFloat32Array()
var _scripts_ms: PackedFloat32Array = PackedFloat32Array()
var _physique_ms: PackedFloat32Array = PackedFloat32Array()


func _initialize() -> void:
	# L'HEURE SE POSE EN LIGNE DE COMMANDE, et ce n'est pas un confort.
	#
	#   godot --path game --script res://verifs/diag_ville.gd -- --heure 22
	#
	# De jour les lampadaires sont MASQUES, donc ils ne coutent rien : mesurer
	# a midi une ville de deux mille lampadaires ne mesure pas les lampadaires.
	# Le pire cas de ce jeu est la nuit, et c'est celui qu'il faut relever.
	for i in OS.get_cmdline_user_args().size() - 1:
		if OS.get_cmdline_user_args()[i] == "--heure":
			_heure = float(OS.get_cmdline_user_args()[i + 1])
	# LA SYNCHRO VERTICALE S'ENLEVE POUR MESURER. Avec elle, toute image qui
	# tient dans le budget sort a 16,7 ms — median, 99e centile et pire cas
	# affichent le meme chiffre, et on ne sait pas s'il restait dix
	# millisecondes de marge ou une demie. Le joueur, lui, la garde : ce releve
	# ne dit pas ce qu'il voit, il dit ce que la ville coute.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	# ET LA FENETRE NE REPREND PAS LE PREMIER PLAN. Le releve tourne dix
	# secondes pendant qu'on fait autre chose : s'il s'impose devant, il fait
	# reduire ce qui tournait en plein ecran a cote. Godot n'a pas d'option en
	# ligne de commande pour naitre sans focus — il le prend a la creation, une
	# fois — mais au moins il ne le reprend plus ensuite.
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	_debut_ms = Time.get_ticks_msec()
	var ps := ResourceLoader.load("res://scenes/monde.tscn") as PackedScene
	_monde = ps.instantiate()
	root.add_child(_monde)
	# Le temps de CHARGEMENT compte l'instanciation et le premier _ready de
	# tout l'arbre : les collisions fabriquees a la volee, les 512 lampadaires,
	# les 1682 elements de decor. C'est ce qu'attend le joueur au lancement.
	_chargement_ms = Time.get_ticks_msec() - _debut_ms


func _process(delta: float) -> bool:
	_n += 1
	# L'heure se pose APRES le demarrage du scenario, pas avant : il applique
	# l'heure de depart de la mission sur sa premiere image differee, et il
	# ecraserait la notre sans rien dire.
	if _n == 20 and _heure >= 0.0:
		var t := root.get_tree().get_first_node_in_group(Temps.GROUPE) as Temps
		if t != null:
			t.regler(_heure)
	if _n > CHAUFFE:
		# ON MESURE LE TEMPS D'UNE IMAGE, PAS LE COMPTEUR D'IMAGES PAR SECONDE.
		# Engine.get_frames_per_second() est rafraichi une fois par seconde :
		# l'echantillonner a chaque image rend cent fois la meme valeur, et
		# "huit images sous les 30" ne veut alors pas dire huit images ratees,
		# mais huit echantillons pris dans la meme seconde basse. Le delta, lui,
		# mesure une image et une seule. C'est ce qui a fait lire un
		# effondrement du pire cas sur la 0.43 la ou il y avait, peut-etre,
		# une seconde de demarrage.
		_image_ms.append(delta * 1000.0)
		_cumul_ms += delta * 1000.0
		# CES DEUX COMPTEURS-LA SONT DES PICS, ET ILS NE SE RAFRAICHISSENT
		# QU'UNE FOIS PAR SECONDE : le moteur y range le MAXIMUM observe pendant
		# la seconde ecoulee, pas le cout de l'image en cours. Les echantillonner
		# image par image rend mille fois la meme valeur, et pendant la premiere
		# seconde c'est encore celle du chargement. C'est ce chiffre qu'on a lu
		# comme "16,5 ms de scripts par image" sur la 0.43 — c'etait le
		# maximum d'une seconde, et il valait la duree d'une synchro verticale.
		# On jette donc la premiere seconde, et on n'en garde que le pire.
		if _cumul_ms > 1000.0:
			_scripts_ms.append(1000.0 * Performance.get_monitor(
					Performance.TIME_PROCESS))
			_physique_ms.append(1000.0 * Performance.get_monitor(
					Performance.TIME_PHYSICS_PROCESS))
	if _cumul_ms < MESURE_MS:
		return false
	_rapport()
	return true


func _rapport() -> void:
	var ville := _trouver(_monde, "Ville")
	var lampes := 0
	var decor := 0
	if ville != null:
		var l := ville.get_node_or_null("Lampes")
		var d := ville.get_node_or_null("Decor")
		lampes = l.get_child_count() if l != null else 0
		decor = d.get_child_count() if d != null else 0

	var etendue := 0.0
	if ville != null and "etendue" in ville:
		etendue = ville.get("etendue")

	print("")
	print("--- la ville ---")
	print("  heure            %05.2f h" % Reglages.heure)
	print("  etendue          %.0f m de cote" % etendue)
	print("  lampadaires      %d" % lampes)
	print("  decor            %d elements" % decor)
	print("  passants         %d" % _compter(_monde, "Pieton"))
	print("  noeuds au total  %d" % _compter_tout(root))
	# OU MARCHENT-ILS. Le trottoir est a 0,18 m, la chaussee a 0,01 et le desert
	# a -0,05 : la hauteur suffit a dire sur quoi quelqu'un se tient, et c'est
	# le controle le plus rapide qu'une foule est bien posee.
	var foule := _trouver(_monde, "Foule")
	if foule != null and foule.get_child_count() > 0:
		var sols := {}
		for p in foule.get_children():
			var y: float = snappedf((p as Node3D).global_position.y, 0.01)
			sols[y] = int(sols.get(y, 0)) + 1
		var lignes: Array[String] = []
		for y in sols:
			lignes.append("%.2f m x%d" % [y, sols[y]])
		print("  passants poses a  %s" % ", ".join(lignes))
		var premier := foule.get_child(0) as Node3D
		print("  le premier en     %s" % str(premier.global_position.round()))

	# Le nombre d'images ratees compte plus que la pire : une seule image a
	# 110 ms est un accident qu'on ne sent pas, dix par seconde sont un jeu qui
	# saccade. La moyenne ne distingue ni l'une ni l'autre — le 99e centile,
	# lui, repond a la seule question qui compte : est-ce que ca s'est senti.
	var median := _centile(_image_ms, 0.5)
	var p99 := _centile(_image_ms, 0.99)
	var pire := _centile(_image_ms, 1.0)
	var ratees := 0
	for t in _image_ms:
		if t > SEUIL_RATEE_MS:
			ratees += 1

	print("")
	print("--- ce que ca coute ---")
	print("  chargement       %d ms" % _chargement_ms)
	print("  mesure           %d images apres %d de chauffe, sur %.1f s" % [
			_image_ms.size(), CHAUFFE, _duree_ms() / 1000.0])
	print("  temps d'image    %.1f ms median (%.0f im/s), %.1f ms au 99e centile, %.1f ms au pire" % [
			median, 1000.0 / maxf(median, 0.001), p99, pire])
	print("  images ratees    %d sur %d au-dessus de %.0f ms" % [
			ratees, _image_ms.size(), SEUIL_RATEE_MS])
	print("  les trois pires  %s" % _quand_les_pires(3))
	print("  memoire          %.0f Mo" % (float(
			Performance.get_monitor(Performance.MEMORY_STATIC)) / 1048576.0))
	# OU passe le temps. Sans ces trois lignes, un chiffre d'images par seconde
	# ne dit pas quoi corriger : on peut aussi bien retirer des lampadaires
	# pendant que ce sont les passants qui coutent.
	#
	# "TRAITEMENT" ET PAS "SCRIPTS" : TIME_PROCESS mesure toute l'image hors
	# physique — le _process de chaque noeud, mais aussi ce que le moteur
	# prepare pour le rendu. Le lire comme du temps de GDScript fait accuser le
	# code d'un cout qui est celui du decor.
	print("  traitement       %.1f ms/image median, %.1f au pire" % [
			_centile(_scripts_ms, 0.5), _centile(_scripts_ms, 1.0)])
	print("  physique         %.1f ms/image median, %.1f au pire" % [
			_centile(_physique_ms, 0.5), _centile(_physique_ms, 1.0)])
	print("  corps physiques  %d actifs" % int(Performance.get_monitor(
			Performance.PHYSICS_3D_ACTIVE_OBJECTS)))
	print("  collisions       %d paires" % int(Performance.get_monitor(
			Performance.PHYSICS_3D_COLLISION_PAIRS)))
	print("  appels de rendu  %d" % int(Performance.get_monitor(
			Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
	print("  primitives       %d" % int(Performance.get_monitor(
			Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
	print("")
	quit(0)


# Le centile se lit sur une COPIE triee : l'ordre du releve dit quand chaque
# pic est tombe, et le trier sur place effacerait ce que la fonction suivante
# va chercher.
func _centile(v: PackedFloat32Array, p: float) -> float:
	if v.is_empty():
		return 0.0
	var trie := v.duplicate()
	trie.sort()
	var dernier := float(trie.size() - 1)
	return trie[int(clampf(round(p * dernier), 0.0, dernier))]


func _duree_ms() -> float:
	return _cumul_ms


# QUAND les pires images sont tombees, en secondes depuis le debut de la mesure.
# Trois pics colles au debut sont un reste de chauffe ; trois pics regulierement
# espaces sont un traitement periodique ; trois pics au hasard sont le decor
# qu'on traverse. Le maximum seul ne permet aucune de ces trois lectures.
func _quand_les_pires(combien: int) -> String:
	if _image_ms.is_empty():
		return "-"
	var instants := PackedFloat32Array()
	var cumul := 0.0
	for t in _image_ms:
		cumul += t
		instants.append(cumul)
	var rangs: Array = []
	for i in _image_ms.size():
		rangs.append([_image_ms[i], i])
	rangs.sort_custom(func(a, b): return float(a[0]) > float(b[0]))
	var lignes: Array[String] = []
	for i in mini(combien, rangs.size()):
		var rang: int = rangs[i][1]
		lignes.append("%.0f ms a %.1f s" % [_image_ms[rang], instants[rang] / 1000.0])
	return ", ".join(lignes)


# Les passants ne sont pas dans un porte-noeuds unique : on les compte par leur
# script plutot que par un chemin, qui se perimerait au premier remaniement.
func _compter(n: Node, classe: String) -> int:
	var total := 1 if n.get_script() != null and str(n.get_script().get_global_name()) == classe else 0
	for e in n.get_children():
		total += _compter(e, classe)
	return total


func _compter_tout(n: Node) -> int:
	var total := 1
	for e in n.get_children():
		total += _compter_tout(e)
	return total


func _trouver(n: Node, nom: String) -> Node:
	if n.name == nom:
		return n
	for e in n.get_children():
		var t := _trouver(e, nom)
		if t != null:
			return t
	return null
