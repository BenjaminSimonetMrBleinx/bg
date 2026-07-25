# Verifie le comportement en virage, et la sortie de virage.
#
#   godot --path game --script res://verifs/test_virage.gd
#
# Ecrit apres un defaut signale au clavier : « quand je tourne j'ai
# l'impression qu'elle touche le sol sur le cote et ca la ralentit, et
# ensuite ca dandine quand je reprends avancer ».
#
# Trois choses a mesurer, et aucune ne se voit sur une capture :
#   - la gite maximale de la caisse. Trop de roulis et le flanc touche le
#     sol, ce qui freine brutalement.
#   - la vitesse gardee dans la courbe, rapportee a la ligne droite.
#   - l'oscillation APRES le virage, une fois les roues droites. C'est le
#     dandinement : la caisse rend l'energie qu'elle a stockee en penchant.
extends SceneTree

const POSE := 40
const LANCE := 240        # acceleration en ligne droite
const VIRAGE := 200       # braquage maintenu
const SORTIE := 160       # roues droites, on regarde si ca oscille

const ROULIS_MAX := 16.0  # degres de gite toleres (au-dela, ca se voit)
const GARDE_MIN := 0.08   # metres sous le bas de caisse : en dessous, ca racle
const PERTE_MAX := 0.42   # part de vitesse perdue dans la courbe
const OSCIL_MAX := 3.5   # degres de contre-roulis toleres en sortie

var _n := 0
var _phase := 0
var _v: VehicleBody3D
var _c: Node
var _kmh_ligne := 0.0
var _kmh_virage := 0.0
var _roulis_max := 0.0
var _oscillation := 0.0
var _roulis_precedent := 0.0
var _roulis_depart := 0.0
var _garde_min := 999.0
var _erreurs: Array[String] = []


func _initialize() -> void:
	var ps := ResourceLoader.load("res://scenes/monde.tscn") as PackedScene
	root.add_child(ps.instantiate())


func _verifier(ok: bool, msg: String) -> void:
	if ok:
		print("  ok   " + msg)
	else:
		_erreurs.append(msg)
		printerr("  ECHEC " + msg)


func _trouver(n: Node, nom: String) -> Node:
	if n.name == nom:
		return n
	for e in n.get_children():
		var t := _trouver(e, nom)
		if t != null:
			return t
	return null


func _roulis() -> float:
	return rad_to_deg(asin(clampf(_v.global_transform.basis.x.y, -1.0, 1.0)))


# Hauteur du point le plus bas du bas de caisse, au-dessus du sol.
#
# C'EST la mesure qui compte, pas l'angle de gite. Le defaut signale etait
# « elle touche le sol sur le cote » : une caisse peut pencher de quinze
# degres sans rien toucher si elle est haute, et racler a huit si elle est
# basse. L'angle seul ne dit rien.
#
# La caisse est une boite de 1,86 x 1,2 x 4,6 centree a 0,99 : ses quatre
# coins inferieurs sont donc a (+-0,93 ; 0,55 ; +-2,3) en local.
const SOL := -0.05          # altitude du desert


func _garde_au_sol() -> float:
	var mini := INF
	for sx in [-0.93, 0.93]:
		for sz in [-2.3, 2.3]:
			var coin: Vector3 = _v.global_transform * Vector3(sx, 0.55, sz)
			mini = minf(mini, coin.y)
	return mini - SOL


func _process(_d: float) -> bool:
	_n += 1
	if _n < POSE:
		return false

	if _v == null:
		_c = _trouver(root, "Controleur")
		_v = _trouver(root, "Vehicule") as VehicleBody3D
		if _c == null or _v == null:
			printerr("noeuds introuvables")
			quit(1)
			return true
		_c.call("_monter")
		# Plein desert : rien a heurter sur des centaines de metres.
		_v.global_position = Vector3(-140.0, 0.6, 140.0)
		_v.rotation = Vector3.ZERO
		_v.linear_velocity = Vector3.ZERO
		_v.angular_velocity = Vector3.ZERO
		_n = 0
		print("--- lancement en ligne droite ---")
		return false

	_v.call("_propulser", 1.0, _v.call("vitesse_kmh"))

	if _phase == 0:
		if _n < LANCE:
			return false
		_kmh_ligne = _v.call("vitesse_kmh")
		print("       vitesse en ligne droite  %.1f km/h" % _kmh_ligne)
		print("--- braquage maintenu ---")
		_phase = 1
		_n = 0
		return false

	if _phase == 1:
		# Braquage a fond, tenu. On mesure la gite et la vitesse gardee.
		_v.call("_braquer", 1.0, _v.call("vitesse_kmh"), 1.0 / 60.0)
		if _n > 30:
			_roulis_max = maxf(_roulis_max, absf(_roulis()))
			_garde_min = minf(_garde_min, _garde_au_sol())
		if _n < VIRAGE:
			return false
		_kmh_virage = _v.call("vitesse_kmh")
		print("       vitesse en courbe        %.1f km/h" % _kmh_virage)
		print("       gite maximale            %.1f deg" % _roulis_max)
		print("--- roues droites, on ecoute si ca dandine ---")
		_phase = 2
		_n = 0
		_roulis_precedent = _roulis()
		_roulis_depart = _roulis()
		return false

	# Roues droites : on remet le volant au centre et on ne touche plus rien.
	_v.call("_braquer", 0.0, _v.call("vitesse_kmh"), 1.0 / 60.0)

	# Le CONTRE-ROULIS : de combien la caisse repart-elle de l'autre cote
	# avant de se poser. Une caisse saine revient a plat avec un depassement
	# faible ; une caisse sous-amortie repart franchement dans l'autre sens,
	# et c'est ca qu'on ressent comme un dandinement.
	#
	# Une premiere version comparait deux images consecutives — mais ne
	# mettait a jour sa reference qu'apres la 40e, si bien que le premier
	# ecart mesure valait quarante images de mouvement. Elle annoncait 8
	# degres PAR IMAGE, ce qui n'avait aucun sens physique.
	if _roulis_max > 0.5:
		var contre := -_roulis() * signf(_roulis_depart)
		_oscillation = maxf(_oscillation, contre)
	_roulis_precedent = _roulis()
	if _n < SORTIE:
		return false

	var perte := 1.0 - _kmh_virage / maxf(1.0, _kmh_ligne)
	print("       contre-roulis en sortie   %.2f deg" % _oscillation)
	print("       vitesse perdue en courbe  %.0f %%" % (perte * 100.0))

	print("       garde au sol minimale    %.3f m" % _garde_min)

	# On verifie la GARDE, pas l'angle. Le defaut signale etait « elle touche
	# le sol sur le cote » : une caisse peut pencher de quinze degres sans
	# rien racler si elle est haute, et frotter a huit si elle est basse.
	# L'angle tout seul ne dit rien, et un seuil dessus condamnerait une
	# voiture parfaitement saine.
	_verifier(_garde_min > GARDE_MIN,
			"le bas de caisse ne touche pas (%.3f m, seuil %.2f)"
			% [_garde_min, GARDE_MIN])
	_verifier(_roulis_max < ROULIS_MAX,
			"elle ne se couche pas franchement (%.1f deg, seuil %.0f)"
			% [_roulis_max, ROULIS_MAX])
	_verifier(perte < PERTE_MAX,
			"elle garde sa vitesse en courbe (%.0f %% perdus, seuil %.0f)"
			% [perte * 100.0, PERTE_MAX * 100.0])
	_verifier(_oscillation < OSCIL_MAX,
			"elle ne dandine pas en sortie (%.2f deg de contre-roulis, seuil %.1f)"
			% [_oscillation, OSCIL_MAX])
	_verifier(_v.global_position.y > -1.0, "elle n'est pas passee sous le sol")

	print("")
	if _erreurs.is_empty():
		print("TEST VIRAGE OK")
		quit(0)
	else:
		printerr("TEST VIRAGE ECHOUE : %d probleme(s)" % _erreurs.size())
		quit(1)
	return true
