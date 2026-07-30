# Le cycle du jour et de la nuit.
#
#   godot --path game --script res://verifs/test_temps.gd
#
# Ce qui se verifie ici tient en une phrase : quand l'heure avance, TOUT suit
# ensemble. Le ciel, le soleil, les lampadaires et les fenetres allumees sont
# quatre mecanismes distincts, et rien ne les oblige a rester d'accord — un
# ciel de midi au-dessus de lampadaires allumes est parfaitement possible, et
# c'est exactement le genre de defaut qu'on ne voit qu'en capture.
#
# On balaie donc les vingt-quatre heures et on verifie la COHERENCE, pas des
# valeurs choisies : plus il fait nuit, plus les lampes eclairent et moins le
# soleil donne. Une valeur exacte se reglera au curseur ; un ordre inverse est
# un bug.
extends SceneTree

const POSE := 30

var _n := 0
var _erreurs: Array[String] = []
var _monde: Node
var _temps: Temps
var _ville: Node
var _soleil: DirectionalLight3D


func _initialize() -> void:
	var ps := ResourceLoader.load("res://scenes/monde.tscn") as PackedScene
	_monde = ps.instantiate()
	root.add_child(_monde)


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
	return true


func _scenario() -> void:
	_temps = _trouver(_monde, "Temps") as Temps
	_ville = _trouver(_monde, "Ville")
	if _temps == null or _ville == null:
		printerr("  ECHEC Temps ou Ville introuvable")
		quit(1)
		return

	# L'HEURE POSEE AU LANCEMENT. Elle vient de la mission quand la mission en
	# impose une, sinon du monde. On compare a ce que la mission DIT, pas a une
	# heure ecrite ici : le jour ou la mission 1 se jouera a l'aube, ce test
	# doit suivre sans qu'on y touche.
	print("\n--- l'heure du lancement ---")
	var mission := _trouver(_monde, "Mission")
	if mission != null and mission.has_method("heure_de_depart"):
		var voulue: float = mission.call("heure_de_depart")
		if voulue >= 0.0:
			_verifier(absf(Reglages.heure - voulue) < 0.5,
					"la mission impose %05.2f h, le monde est a %05.2f h"
							% [voulue, Reglages.heure])
		else:
			print("       la mission n'impose aucune heure")

	# L'HORLOGE AVANCE-T-ELLE ? Elle a ete figee pendant tout le developpement
	# des couleurs, et la remettre a zero est un geste d'une seconde : ce test
	# est la pour que ca ne parte pas en livraison.
	print("\n--- l'horloge avance ---")
	var vitesse: float = _temps.reglages.temps_vitesse
	_verifier(vitesse > 0.0, "temps_vitesse vaut %.3f h/s" % vitesse)
	if vitesse > 0.0:
		_temps.regler(8.0)
		_temps._process(10.0)
		var attendu := 8.0 + vitesse * 10.0
		_verifier(absf(Reglages.heure - attendu) < 0.001,
				"dix secondes font %.2f h : %05.2f -> %05.2f h"
						% [vitesse * 10.0, 8.0, Reglages.heure])
		# Le tour complet en minutes, pour qu'il soit ECRIT quelque part et
		# qu'on voie tout de suite si quelqu'un l'a multiplie par dix.
		print("       une journee complete en %.0f minutes" % (24.0 / vitesse / 60.0))

	# LA LUMIERE DE PORCHE. Elle n'etait pas creee du tout quand le monde
	# chargeait de jour : une maison chargee a midi restait noire toute la nuit,
	# et c'est ce qui interdisait a une mission de choisir son heure.
	print("\n--- le porche suit l'heure ---")
	var maison := _trouver(_monde, "MaisonWalter")
	if maison == null:
		maison = _premiere_maison(_monde)
	if maison == null:
		_verifier(false, "aucune maison trouvee dans la scene")
	else:
		var porche := maison.get_node_or_null("Porche") as OmniLight3D
		_verifier(porche != null,
				"la maison '%s' a une lumiere de porche" % maison.name)
		if porche != null:
			_temps.regler(13.0)
			_verifier(not porche.visible,
					"a midi elle est eteinte (energie %.2f)" % porche.light_energy)
			_temps.regler(23.0)
			_verifier(porche.visible and porche.light_energy > 0.0,
					"a 23 h elle eclaire (energie %.2f)" % porche.light_energy)

	print("\n--- la part de nuit suit l'heure ---")
	for cas in [[13.0, 0.0], [12.0, 0.0], [22.0, 1.0], [3.0, 1.0], [0.0, 1.0]]:
		Reglages.heure = cas[0]
		var p := Reglages.nuit_part()
		_verifier(is_equal_approx(p, cas[1]),
				"a %05.2f h, part de nuit = %.2f (attendu %.0f)"
						% [cas[0], p, cas[1]])

	# Les transitions doivent etre PROGRESSIVES, pas des interrupteurs. Une
	# premiere version basculait d'un coup, et l'aube n'existait pas.
	Reglages.heure = 7.1
	var aube := Reglages.nuit_part()
	_verifier(aube > 0.05 and aube < 0.95,
			"l'aube est une valeur intermediaire (%.2f)" % aube)
	Reglages.heure = 20.1
	var soir := Reglages.nuit_part()
	_verifier(soir > 0.05 and soir < 0.95,
			"le crepuscule aussi (%.2f)" % soir)

	print("\n--- tout suit ensemble ---")
	# On releve chaque grandeur a plusieurs heures, puis on compare les
	# tendances. Comparer a des valeurs absolues aurait fige les reglages : le
	# jour ou quelqu'un eclaircit la nuit, le test tomberait sans qu'aucun
	# comportement n'ait change.
	var releves := []
	for h in [13.0, 19.9, 22.0]:
		_temps.regler(h)
		_soleil = _trouver(_monde, "Soleil") as DirectionalLight3D
		var lampes := _ville.get_node_or_null("Lampes") as Node3D
		var energie_lampe := 0.0
		if lampes != null and lampes.get_child_count() > 0:
			energie_lampe = (lampes.get_child(0) as OmniLight3D).light_energy
		releves.append({
			"h": h,
			"nuit": Reglages.nuit_part(),
			"soleil": _soleil.light_energy if _soleil != null else 0.0,
			"lampe": energie_lampe,
			"fenetres": _emission(),
		})
		print("       %05.2f h  nuit %.2f  soleil %.2f  lampe %.2f  fenetres %.2f"
				% [h, releves[-1]["nuit"], releves[-1]["soleil"],
				   releves[-1]["lampe"], releves[-1]["fenetres"]])

	var midi: Dictionary = releves[0]
	var nuit: Dictionary = releves[2]
	_verifier(midi["soleil"] > nuit["soleil"],
			"le soleil donne moins la nuit")
	_verifier(nuit["lampe"] > midi["lampe"],
			"les lampadaires donnent plus la nuit")
	_verifier(nuit["fenetres"] > midi["fenetres"],
			"les fenetres s'allument la nuit")
	_verifier(is_zero_approx(midi["lampe"]) and is_zero_approx(midi["fenetres"]),
			"et sont completement eteintes a midi")

	# Le crepuscule doit etre ENTRE les deux sur toutes les grandeurs a la fois.
	# C'est le controle qui attrape un systeme reste sur un interrupteur pendant
	# que les autres sont passes au continu.
	var soir_r: Dictionary = releves[1]
	for grandeur in ["lampe", "fenetres"]:
		_verifier(soir_r[grandeur] > midi[grandeur]
						and soir_r[grandeur] <= nuit[grandeur],
				"au crepuscule, '%s' est entre les deux (%.2f)"
						% [grandeur, soir_r[grandeur]])

	print("\n--- vingt-quatre heures sans accident ---")
	# Un balayage complet : aucune grandeur ne doit devenir negative, infinie
	# ou absurde a une heure particuliere. C'est bon marche et ca couvre les
	# heures auxquelles personne ne pense — 4 h du matin, minuit pile.
	var souci := ""
	for i in 96:
		_temps.regler(float(i) * 0.25)
		var p := Reglages.nuit_part()
		if p < 0.0 or p > 1.0 or is_nan(p):
			souci = "part de nuit %.2f a %05.2f h" % [p, Reglages.heure]
			break
		var e := _emission()
		if e < 0.0 or e > 1.0 or is_nan(e):
			souci = "emission %.2f a %05.2f h" % [e, Reglages.heure]
			break
	_verifier(souci == "", "96 quarts d'heure balayes%s"
			% ("" if souci == "" else " — " + souci))

	# On repose l'heure de depart : les autres suites tournent dans le meme
	# processus si on enchaine, et une heure laissee a 23 h les surprendrait.
	_temps.regler(13.0)

	print("")
	if _erreurs.is_empty():
		print("TEST TEMPS OK")
		quit(0)
	else:
		printerr("TEST TEMPS ECHOUE : %d probleme(s)" % _erreurs.size())
		quit(1)


# L'emission des fenetres se lit sur le materiau, pas sur une variable du
# script : c'est ce que le rendu utilise reellement.
func _emission() -> float:
	var m := _premier_materiau_emissif(_ville)
	return m.emission_energy_multiplier if m != null else -1.0


func _premier_materiau_emissif(n: Node) -> BaseMaterial3D:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.mesh != null:
			for i in mi.mesh.get_surface_count():
				var m := mi.mesh.surface_get_material(i) as BaseMaterial3D
				if m != null and m.emission_enabled:
					return m
	for e in n.get_children():
		var t := _premier_materiau_emissif(e)
		if t != null:
			return t
	return null


func _premiere_maison(n: Node) -> Node:
	if n is Maison:
		return n
	for e in n.get_children():
		var t := _premiere_maison(e)
		if t != null:
			return t
	return null


func _trouver(n: Node, nom: String) -> Node:
	if n.name == nom:
		return n
	for e in n.get_children():
		var t := _trouver(e, nom)
		if t != null:
			return t
	return null
