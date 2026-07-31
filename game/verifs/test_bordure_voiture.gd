# Longer un trottoir en voiture, sans etre arrete.
#
#   godot --path game --script res://verifs/test_bordure_voiture.gd
#
# CE QUE CE TEST A APPRIS, ET QUI N ETAIT PAS CE QU ON CHERCHAIT.
#
# La plainte etait « les trottoirs freinent trop la voiture ». La reponse
# evidente etait de biseauter la bordure, et elle etait fausse : mesure faite
# image par image, franchir un trottoir de dix-huit centimetres a 54 km/h
# coute UN kilometre/heure, et le biseau ne changeait rien du tout.
#
# Ce qui arretait la voiture, c'etait le stationnement. Deux rangees de
# voitures garees sur une chaussee de huit metres laissaient 3,84 m de passage
# pour une caisse de 1,86 m — moins d'un metre de chaque cote. On accrochait
# une aile a la moindre derive, et on lisait ca comme un trottoir collant.
#
# Le test mesure donc le VRAI cas : rouler le long du bord en derivant
# doucement vers lui, comme on le fait sans y penser. Personne ne fonce
# perpendiculairement sur un trottoir.
extends SceneTree

const POSE := 40

## Part de la vitesse conservee apres une seconde et demie a longer le bord.
## Avant l'elargissement de la chaussee : 38 %. Apres : 82 %.
const GARDE_MINIMUM := 0.70

var _n := 0
var _erreurs: Array[String] = []
var _monde: Node
var _vehicule: Vehicule


func _initialize() -> void:
	var ps := ResourceLoader.load("res://scenes/monde.tscn") as PackedScene
	_monde = ps.instantiate()
	root.add_child(_monde)


# Retire les voitures a l'arret autour d'un point. Rend le nombre retire, pour
# que le journal du test dise ce qu'il a change au monde avant de mesurer.
func _degager_les_garees(centre: Vector3, rayon: float) -> int:
	var retirees := 0
	for n in _tous(_monde):
		if n is VoitureGaree and (n as Node3D).global_position.distance_to(centre) < rayon:
			n.queue_free()
			retirees += 1
	if retirees > 0:
		print("       %d voiture(s) garee(s) degagee(s) du circuit" % retirees)
	return retirees


func _tous(n: Node) -> Array[Node]:
	var liste: Array[Node] = [n]
	for e in n.get_children():
		liste.append_array(_tous(e))
	return liste


func _verifier(ok: bool, message: String) -> void:
	if ok:
		print("  ok   " + message)
	else:
		_erreurs.append(message)
		printerr("  ECHEC " + message)


func _process(_d: float) -> bool:
	_n += 1
	if _n != POSE:
		return false
	_scenario()
	return false


func _attendre(images: int) -> void:
	for i in images:
		await physics_frame


func _scenario() -> void:
	_vehicule = _trouver(_monde, "Vehicule") as Vehicule
	if _vehicule == null:
		printerr("  ECHEC Vehicule introuvable")
		quit(1)
		return
	(_trouver(_monde, "Controleur")).call("_monter")
	await _attendre(10)

	print("\n--- on longe le bord en derivant vers lui ---")
	# ON DEGAGE LES VOITURES GAREES DU CIRCUIT.
	#
	# Depuis le 31/07/2026 elles ont un corps physique — avant, on les
	# traversait. Le circuit longe un trottoir, c'est-a-dire exactement la
	# ou elles se garent : la voiture d'essai en percutait une avant meme
	# d'atteindre la bordure.
	#
	# Ce test mesure LE FRANCHISSEMENT D'UNE BORDURE. Ce qui est gare le long
	# n'est pas son sujet, et le degager est plus honnete que de deplacer le
	# circuit jusqu'a tomber par hasard sur une place vide.
	_degager_les_garees(Vector3(9.0, 0.45, -20.0), 30.0)
	_vehicule.global_position = Vector3(9.0, 0.45, -20.0)
	_vehicule.rotation = Vector3(0.0, deg_to_rad(-8.0), 0.0)
	_vehicule.linear_velocity = Vector3.ZERO
	await _attendre(50)

	_vehicule.ignorer_les_chocs()
	_vehicule.linear_velocity = -_vehicule.global_transform.basis.z * 15.0
	var depart := _vehicule.vitesse_kmh()
	var x_depart := _vehicule.global_position.x
	await _attendre(90)

	var garde := _vehicule.vitesse_kmh() / maxf(1.0, depart)
	var avance := _vehicule.global_position.x - x_depart
	print("       %.1f km/h au depart, %.1f apres 1,5 s"
			% [depart, _vehicule.vitesse_kmh()])
	print("       derive de %.2f m vers le bord" % avance)

	_verifier(garde >= GARDE_MINIMUM,
			"elle garde %.0f %% de sa vitesse (minimum %.0f)"
					% [garde * 100.0, GARDE_MINIMUM * 100.0])
	# Si elle n'a pas derive, elle n'a jamais approche le bord et la mesure ne
	# dit rien. C'est le controle qui empeche ce test de passer pour rien.
	_verifier(avance > 1.5,
			"et elle a bien derive jusqu'au bord (%.2f m)" % avance)

	print("")
	if _erreurs.is_empty():
		print("TEST BORDURE OK")
		quit(0)
	else:
		printerr("TEST BORDURE ECHOUE : %d probleme(s)" % _erreurs.size())
		quit(1)


func _trouver(n: Node, nom: String) -> Node:
	if n.name == nom:
		return n
	for e in n.get_children():
		var t := _trouver(e, nom)
		if t != null:
			return t
	return null
