# Dit tout ce qu'il faut savoir quand le jeu est muet.
#
#   .\bg.ps1 son
#
# Un jeu sans son ne donne aucune piste : on ne sait pas si le probleme vient
# du fichier, de l'import, du bus, du peripherique de sortie ou du volume
# Windows. Ce script repond aux cinq d'un coup.
extends SceneTree

const AMBIANCE := "res://assets/sons/ambiance/amb_rue_jour.ogg"
const ATTENTE := 120        # ~2 s, le temps que le signal s'etablisse

var _n := 0
var _flux: AudioStream
var _lecteur: AudioStreamPlayer
var _bus := -1
var _crete := -200.0
var _soucis: Array[String] = []


func _initialize() -> void:
	print("")
	print("=== SORTIE AUDIO ===")
	print("  pilote            %s" % AudioServer.get_driver_name())
	print("  peripherique      %s" % AudioServer.get_output_device())
	print("  frequence         %d Hz" % AudioServer.get_mix_rate())
	var appareils := AudioServer.get_output_device_list()
	print("  disponibles       %s" % ", ".join(appareils))
	if AudioServer.get_driver_name() == "Dummy":
		_soucis.append("le pilote audio est 'Dummy' : Windows ne fournit "
				+ "aucune sortie a Godot")

	print("")
	print("=== BUS ===")
	if AudioServer.bus_count <= 1:
		_soucis.append("un seul bus : default_bus_layout.tres n'est pas charge")
	for i in AudioServer.bus_count:
		print("  %-10s %+6.1f dB%s"
				% [AudioServer.get_bus_name(i), AudioServer.get_bus_volume_db(i),
				   "   MUET" if AudioServer.is_bus_mute(i) else ""])
		if AudioServer.is_bus_mute(i):
			_soucis.append("le bus '%s' est coupe" % AudioServer.get_bus_name(i))

	print("")
	print("=== FICHIER D'AMBIANCE ===")
	if not ResourceLoader.exists(AMBIANCE):
		print("  INTROUVABLE : %s" % AMBIANCE)
		_soucis.append("le fichier d'ambiance est introuvable ou non importe")
		_conclure()
		return

	var flux := ResourceLoader.load(AMBIANCE) as AudioStream
	if flux == null:
		print("  CHARGEMENT IMPOSSIBLE")
		_soucis.append("Godot n'arrive pas a lire le fichier : import casse, "
				+ "ou pointeur Git LFS non resolu")
		_conclure()
		return

	print("  type              %s" % flux.get_class())
	print("  duree             %.1f s" % flux.get_length())
	if flux.get_length() < 0.5:
		_soucis.append("le flux dure moins d'une demi-seconde : fichier vide "
				+ "ou pointeur Git LFS")

	_flux = flux


func _process(_d: float) -> bool:
	# La lecture ne peut demarrer qu'une fois le noeud DANS l'arbre : depuis
	# _initialize, Godot refuse avec "Playback can only happen when a node is
	# inside the scene tree". D'ou ce demarrage differe d'une image.
	if _lecteur == null:
		if _flux == null:
			return true
		_bus = maxi(AudioServer.get_bus_index("Ambiance"), 0)
		_lecteur = AudioStreamPlayer.new()
		_lecteur.stream = _flux
		_lecteur.bus = AudioServer.get_bus_name(_bus)
		_lecteur.volume_db = 0.0
		root.add_child(_lecteur)
		_lecteur.play()
		return false

	_n += 1
	if _n > 20:                          # on laisse passer le tout debut
		_crete = maxf(_crete, AudioServer.get_bus_peak_volume_left_db(_bus, 0))
	if _n < ATTENTE:
		return false

	print("")
	print("=== SIGNAL MESURE ===")
	print("  lecture en cours  %s" % ("oui" if _lecteur.playing else "NON"))
	print("  crete sur le bus  %.1f dB" % _crete)
	if _crete < -60.0:
		_soucis.append("aucun signal ne sort du bus : le fichier est "
				+ "silencieux, ou il ne se decode pas")
	elif _crete < -20.0:
		print("  -> du son circule, mais il est FAIBLE")
		_soucis.append(("le fichier ne monte qu'a %.0f dB. " % _crete)
				+ "Un master de jeu devrait culminer vers -6 dB : "
				+ "en dessous, il disparait des que l'ecoute n'est pas ideale")
	else:
		print("  -> du son circule reellement dans le moteur")

	if _lecteur != null:
		_lecteur.stop()
		_lecteur.queue_free()

	_conclure()
	return true


func _conclure() -> void:
	print("")
	if _soucis.is_empty():
		print("DIAGNOSTIC : le moteur produit du son.")
		print("Si tu n'entends toujours rien, le probleme est en dehors du jeu :")
		print("  - mauvais peripherique de sortie choisi par Windows")
		print("  - Godot coupe dans le melangeur de volume Windows")
		print("    (clic droit sur l'icone haut-parleur > Melangeur de volume)")
		quit(0)
	else:
		print("DIAGNOSTIC : %d probleme(s)" % _soucis.size())
		for s in _soucis:
			printerr("  - " + s)
		print("")
		print("Premier reflexe : .\\bg.ps1 reparer")
		quit(1)
