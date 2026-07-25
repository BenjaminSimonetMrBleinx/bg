# Verifie que les repliques sont doublees, et qu'on les entend.
#
#   godot --path game --script res://verifs/test_voix.gd
#
# Le generateur est en PowerShell, le lecteur en GDScript, et les deux ne se
# rejoignent QUE sur un nom de fichier. S'ils calculent l'empreinte
# differemment, le jeu cherche un fichier qui n'existe pas : le dialogue
# s'affiche normalement, personne ne parle, et rien n'est signale.
#
# On mesure donc le volume reellement sorti, pas la presence du fichier.
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
		var total := 0
		var manquants: Array[String] = []
		for cle in data:
			if typeof(data[cle]) != TYPE_DICTIONARY:
				continue
			for conv in (data[cle] as Dictionary).get("conversations", []):
				for r in conv:
					total += 1
					var qui := str(r.get("qui", ""))
					var texte := str(r.get("texte", ""))
					# Exactement le calcul du jeu : si le test refaisait le
					# sien, il validerait sa propre convention et pas celle
					# qui est reellement utilisee.
					var chemin: String = Dialogue.VOIX % [
							Dialogue._simplifier(qui),
							texte.md5_text().substr(0, 10)]
					if not ResourceLoader.exists(chemin):
						manquants.append("%s : %s" % [qui, texte])
		print("       %d replique(s), %d sans voix" % [total, manquants.size()])
		for m in manquants.slice(0, 3):
			printerr("       manque : " + m)
		_verifier(total > 0, "il y a des repliques")
		_verifier(manquants.is_empty(),
				"toutes ont un enregistrement (%d manquant(s))" % manquants.size())

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
