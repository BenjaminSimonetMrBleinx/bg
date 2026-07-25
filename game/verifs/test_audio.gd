# Verifie que le son est reellement en place.
#
#   godot --path game --script res://verifs/test_audio.gd
#
# Un son absent ne fait pas de bruit, ce qui est exactement le probleme :
# rien ne signale l'echec. Ce test controle ce qui ne s'entend pas — que les
# bus existent, que la nappe tourne, et qu'elle boucle.
extends SceneTree

# Assez long pour que le fondu d'ouverture soit termine : c'est justement
# ce qu'on veut controler.
const POSE := 300
const BUS := ["Master", "Ambiance", "Effets", "Musique", "Interface"]

var _n := 0
var _erreurs: Array[String] = []


func _initialize() -> void:
	var ps := ResourceLoader.load("res://scenes/monde.tscn") as PackedScene
	root.add_child(ps.instantiate())


func _verifier(ok: bool, message: String) -> void:
	if ok:
		print("  ok   " + message)
	else:
		_erreurs.append(message)
		printerr("  ECHEC " + message)


func _process(_d: float) -> bool:
	_n += 1
	if _n < POSE:
		return false

	print("\n--- bus ---")
	for nom in BUS:
		var i := AudioServer.get_bus_index(nom)
		_verifier(i >= 0, "bus '%s'%s" % [nom,
				("" if i < 0 else "  %+.1f dB" % AudioServer.get_bus_volume_db(i))])

	print("\n--- ambiance ---")
	var audio := _trouver(root, "Audio")
	if audio == null:
		printerr("  ECHEC noeud Audio introuvable")
		_erreurs.append("Audio")
	else:
		var lecteur := audio.find_child("Ambiance", true, false) as AudioStreamPlayer
		_verifier(lecteur != null, "lecteur d'ambiance present")
		if lecteur != null:
			_verifier(lecteur.stream != null, "un flux est assigne")
			_verifier(lecteur.playing, "la nappe tourne")
			_verifier(lecteur.bus == "Ambiance", "elle sort sur le bus Ambiance")
			# Le controle qui compte : la nappe demarre a -60 dB et remonte
			# par fondu. Si le fondu ne tourne pas, elle "joue" sans qu'on
			# entende quoi que ce soit — et rien ne le signale.
			_verifier(lecteur.volume_db > -12.0,
					"le fondu d'ouverture est monte (%.1f dB)" % lecteur.volume_db)
			if lecteur.stream is AudioStreamOggVorbis:
				_verifier((lecteur.stream as AudioStreamOggVorbis).loop,
						"elle est marquee en boucle")
			print("       flux : %s  (%.1f s)"
					% [lecteur.stream.resource_path.get_file(),
					   lecteur.stream.get_length()])

	print("")
	if _erreurs.is_empty():
		print("TEST AUDIO OK")
		quit(0)
	else:
		printerr("TEST AUDIO ECHOUE : %d probleme(s)" % _erreurs.size())
		quit(1)
	return true


func _trouver(n: Node, nom: String) -> Node:
	if n.name == nom:
		return n
	for e in n.get_children():
		var t := _trouver(e, nom)
		if t != null:
			return t
	return null
