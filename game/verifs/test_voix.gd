# Verifie que les repliques sont doublees, et qu'on les entend.
#
#   godot --headless --path game --script res://verifs/test_voix.gd
#
# Le generateur est en PowerShell, le lecteur en GDScript, et les deux ne se
# rejoignent QUE sur un nom de fichier. S'ils calculent l'empreinte
# differemment, le jeu cherche un fichier qui n'existe pas : le dialogue
# s'affiche normalement, personne ne parle, et rien n'est signale.
#
# ON MESURE LE VOLUME REELLEMENT SORTI, pas la presence du fichier. Un WAV
# valide de zero seconde se charge sans erreur et ne s'entend pas ; compter les
# fichiers l'aurait declare bon.
#
# LE TEST N'A PAS SA PROPRE CONVENTION. Il appelle Dialogue.VOIX,
# Dialogue._simplifier() et Dialogue._prononce() plutot que de les recopier :
# un test qui refait le calcul du jeu valide SA convention, pas celle qui sert
# vraiment. Les deux resteraient d'accord entre elles en etant fausses toutes
# les deux.
#
# LE DEUXIEME PIEGE, sans rapport avec le premier : un .wav pose dans
# assets/voix/ n'est pas encore une ressource. Godot doit l'IMPORTER, ce qui
# n'arrive qu'au prochain lancement. Entre les deux, le fichier est la et le jeu
# ne peut pas le lire. Les deux cas se reparent differemment — regenerer, ou
# simplement ouvrir Godot — donc le test les distingue.
extends SceneTree

const POSE := 40
const ECOUTE := 45

var _n := 0
var _etape := 0
var _d: Node
var _bus := -1
var _crete := -200.0
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


func _process(_delta: float) -> bool:
	_n += 1

	if _etape == 0:
		if _n < POSE:
			return false
		_d = _trouver(root, "Dialogue")
		_bus = AudioServer.get_bus_index("Interface")
		if _d == null:
			printerr("noeud Dialogue introuvable")
			quit(1)
			return true

		print("--- un enregistrement par replique ---")
		var brut := FileAccess.get_file_as_string("res://donnees/dialogues.json")
		var data: Dictionary = JSON.parse_string(brut)

		# Par personnage : [ont leur voix, absentes, posees pas importees]
		var par_qui: Dictionary = {}
		var total := 0
		var sans_vo := 0
		var manquants: Array[String] = []
		var pas_importees := 0

		for cle in data:
			if typeof(data[cle]) != TYPE_DICTIONARY:
				continue
			for conv in (data[cle] as Dictionary).get("conversations", []):
				for r in conv:
					var replique: Dictionary = r
					var qui := str(replique.get("qui", ""))
					# Ce qui est PARLE, qui n'est plus ce qui est affiche :
					# le jeu est en VO anglaise sous-titree francais.
					var dit: String = Dialogue._prononce(replique)
					if dit == "":
						continue
					total += 1
					if not replique.has("vo"):
						sans_vo += 1
					if not par_qui.has(qui):
						par_qui[qui] = [0, 0, 0]
					var compte: Array = par_qui[qui]

					# Exactement le calcul du jeu.
					var chemin: String = Dialogue.VOIX % [
							Dialogue._simplifier(qui),
							dit.md5_text().substr(0, 10)]
					if ResourceLoader.exists(chemin):
						compte[0] += 1
					elif FileAccess.file_exists(chemin):
						compte[2] += 1
						pas_importees += 1
					else:
						compte[1] += 1
						manquants.append("%s : %s" % [qui, dit])

		print("  %-14s %6s %6s %10s" % ["qui", "ont", "sans", "a importer"])
		var noms := par_qui.keys()
		noms.sort()
		for qui in noms:
			var c: Array = par_qui[qui]
			print("  %-14s %6d %6d %10d" % [qui, c[0], c[1], c[2]])
		print("       %d replique(s), dont %d sans VO anglaise" % [total, sans_vo])

		for m in manquants.slice(0, 3):
			printerr("       manque : " + m)
		if pas_importees > 0:
			# CE N'EST PAS UN ECHEC DE LA CHAINE : le fichier est bon, il
			# manque une ouverture de Godot. Le dire evite de regenerer des
			# voix qui sont deja la.
			printerr("       %d posee(s) mais pas importee(s) :" % pas_importees)
			printerr("       godot --headless --path game --import")

		_verifier(total > 0, "il y a des repliques")
		_verifier(manquants.is_empty(),
				"toutes ont un enregistrement (%d manquant(s))" % manquants.size())
		_verifier(pas_importees == 0, "toutes sont importees")

		print("--- on ouvre une conversation et on ecoute ---")
		_verifier(_bus >= 0, "le bus Interface existe")
		_d.call("demarrer", "walter" if _d.call("connait", "walter") else "skyler")
		_etape = 1
		_n = 0
		return false

	if _etape == 1:
		# On laisse passer quelques images avant de mesurer : le lecteur
		# demarre sur la trame suivante, et le melangeur a une latence.
		if _n > 6:
			_crete = maxf(_crete, AudioServer.get_bus_peak_volume_left_db(_bus, 0))
		if _n < ECOUTE:
			return false

		print("       crete bus Interface  %.1f dB" % _crete)
		_verifier(_crete > -60.0, "on entend la voix")
		if _crete > -60.0 and _crete < -35.0:
			print("       (faible : verifier volume_interface dans reglages.tres)")

		print("")
		if _erreurs.is_empty():
			print("TEST VOIX OK")
			quit(0)
		else:
			printerr("TEST VOIX ECHOUE : %d probleme(s)" % _erreurs.size())
			quit(1)
		return true

	return false
