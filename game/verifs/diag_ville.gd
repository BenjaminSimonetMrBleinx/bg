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
## portent la construction des collisions et l'instanciation du decor : les
## compter dans une moyenne d'images par seconde donnerait un chiffre qui ne
## correspond a aucun moment du jeu.
const CHAUFFE := 60

## Images mesurees ensuite.
const MESURE := 180

var _monde: Node
var _n := 0
var _debut_ms := 0
var _chargement_ms := 0
var _fps: Array[float] = []
var _heure: float = -1.0


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
	_debut_ms = Time.get_ticks_msec()
	var ps := ResourceLoader.load("res://scenes/monde.tscn") as PackedScene
	_monde = ps.instantiate()
	root.add_child(_monde)
	# Le temps de CHARGEMENT compte l'instanciation et le premier _ready de
	# tout l'arbre : les collisions fabriquees a la volee, les 512 lampadaires,
	# les 1682 elements de decor. C'est ce qu'attend le joueur au lancement.
	_chargement_ms = Time.get_ticks_msec() - _debut_ms


func _process(_d: float) -> bool:
	_n += 1
	# L'heure se pose APRES le demarrage du scenario, pas avant : il applique
	# l'heure de depart de la mission sur sa premiere image differee, et il
	# ecraserait la notre sans rien dire.
	if _n == 20 and _heure >= 0.0:
		var t := root.get_tree().get_first_node_in_group(Temps.GROUPE) as Temps
		if t != null:
			t.regler(_heure)
	if _n > CHAUFFE:
		_fps.append(Engine.get_frames_per_second())
	if _n < CHAUFFE + MESURE:
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

	# Les images par seconde : la MOYENNE ne suffit pas. Une ville qui tourne a
	# soixante en moyenne mais tombe a douze en tournant un coin de rue est
	# injouable, et la moyenne ne le dit pas. On sort donc aussi le pire.
	var moyenne := 0.0
	var pire := 9999.0
	var sous_30 := 0
	for f in _fps:
		moyenne += f
		pire = minf(pire, f)
		if f < 30.0:
			sous_30 += 1
	moyenne = moyenne / maxf(float(_fps.size()), 1.0)

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

	print("")
	print("--- ce que ca coute ---")
	print("  chargement       %d ms" % _chargement_ms)
	# Le nombre d'images ratees compte plus que la pire : une seule image a
	# 110 ms est un accident qu'on ne sent pas, dix par seconde sont un jeu qui
	# saccade. La moyenne ne distingue pas les deux.
	print("  images/seconde   %.0f en moyenne, %.0f au pire" % [moyenne, pire])
	print("  images ratees    %d sur %d sous les 30 im/s" % [sous_30, _fps.size()])
	print("  memoire          %.0f Mo" % (float(
			Performance.get_monitor(Performance.MEMORY_STATIC)) / 1048576.0))
	# OU passe le temps. Sans ces trois lignes, un chiffre d'images par seconde
	# ne dit pas quoi corriger : on peut aussi bien retirer des lampadaires
	# pendant que ce sont les passants qui coutent.
	print("  scripts          %.1f ms/image" % (1000.0 * Performance.get_monitor(
			Performance.TIME_PROCESS)))
	print("  physique         %.1f ms/image" % (1000.0 * Performance.get_monitor(
			Performance.TIME_PHYSICS_PROCESS)))
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
