# Enregistre ce que les bus d'appareil produisent VRAIMENT, pour l'ecouter.
#
#   godot --path game --script res://verifs/ecouter_canaux.gd
#
# POURQUOI CE N'EST PAS UN FILTRE FFMPEG EQUIVALENT. Le traitement telephone et
# interphone vit dans default_bus_layout.tres, donc dans le moteur : les
# fichiers de assets/voix/ sont la voix pure et ne contiennent rien de ce qu'on
# entend en jeu. Reproduire les memes reglages dans ffmpeg pour fabriquer un
# extrait donnerait une APPROXIMATION — un autre filtre, un autre ordre, une
# autre implementation — et on validerait a l'oreille quelque chose que le jeu
# ne joue pas.
#
# On fait donc jouer chaque replique par Godot, a travers son vrai bus, et on
# capte la sortie avec un AudioEffectRecord. Ce qui est ecrit est exactement ce
# qui sort des haut-parleurs.
#
# PAS EN HEADLESS : sans fenetre, Godot prend le pilote audio muet, les effets
# ne tournent pas et les fichiers sortiraient vides. bg.ps1 lance donc ce
# script avec une fenetre, comme diag_son.
extends SceneTree

const VOIX := "res://assets/voix/%s_%s.wav"

## Ou tombent les extraits. .tmp/ parce que ca se regenere en une commande.
const SORTIE := "res://../.tmp/essai-canaux/"

var _a_faire: Array = []
var _i := 0
var _etape := 0
var _n := 0
var _record: AudioEffectRecord
var _lecteur: AudioStreamPlayer
var _bus_capture := -1
var _ecrits := 0
var _dossier := ""


static func _simplifier(nom: String) -> String:
	var sortie := ""
	for c in nom.to_lower():
		if (c >= "a" and c <= "z") or (c >= "0" and c <= "9"):
			sortie += c
	return sortie


func _initialize() -> void:
	_dossier = ProjectSettings.globalize_path(SORTIE)
	DirAccess.make_dir_recursive_absolute(_dossier)

	var brut := FileAccess.get_file_as_string("res://donnees/dialogues.json")
	var data: Variant = JSON.parse_string(brut)
	if typeof(data) != TYPE_DICTIONARY:
		print("ECHEC dialogues.json illisible")
		quit(1)
		return

	# On ne garde que les repliques qui traversent un appareil, et on prepare
	# DEUX rendus pour chacune : le direct et le filtre. Un extrait filtre seul
	# ne dit pas grand-chose — c'est l'ecart entre les deux qui s'entend.
	var vus: Dictionary = {}
	for cle in (data as Dictionary):
		if typeof(data[cle]) != TYPE_DICTIONARY:
			continue
		for conv in (data[cle] as Dictionary).get("conversations", []):
			for r in conv:
				var canal := str((r as Dictionary).get("canal", ""))
				if canal == "":
					continue
				var qui := str((r as Dictionary).get("qui", ""))
				var vo := str((r as Dictionary).get("vo", ""))
				var chemin := VOIX % [_simplifier(qui), vo.md5_text().substr(0, 10)]
				if vus.has(chemin):
					continue
				vus[chemin] = true
				_a_faire.append({
					"chemin": chemin, "qui": qui, "vo": vo, "canal": canal,
				})

	# Le magnetophone se pose sur le Master : c'est le dernier point avant la
	# sortie, donc ce qu'on capte a subi TOUTE la chaine, y compris le renvoi
	# du bus d'appareil vers Interface.
	_bus_capture = AudioServer.get_bus_index("Master")
	_record = AudioEffectRecord.new()
	AudioServer.add_bus_effect(_bus_capture, _record)

	_lecteur = AudioStreamPlayer.new()
	root.add_child(_lecteur)

	print("")
	print("--- %d replique(s) a rendre, en direct et filtree ---" % _a_faire.size())


func _process(_delta: float) -> bool:
	# On laisse le moteur audio demarrer avant la premiere prise.
	if _etape == 0:
		_n += 1
		if _n < 20:
			return false
		_etape = 1
		_n = 0
		return false

	if _i >= _a_faire.size():
		print("")
		print("%d fichier(s) ecrits" % _ecrits)
		print("-> %s" % _dossier)
		quit(0 if _ecrits > 0 else 1)
		return true

	var item: Dictionary = _a_faire[_i]

	# Etape 1 : la version DIRECTE, telle qu'elle serait sans appareil.
	# Etape 2 : la meme, a travers son bus.
	if _etape == 1 or _etape == 3:
		var flux := ResourceLoader.load(item["chemin"]) as AudioStream
		if flux == null:
			printerr("  introuvable : %s" % item["chemin"])
			_i += 1
			_etape = 1
			return false
		_lecteur.stream = flux
		_lecteur.bus = "Interface" if _etape == 1 else Dialogue.BUS_PAR_CANAL[item["canal"]]
		_record.set_recording_active(true)
		_lecteur.play()
		_etape += 1
		_n = 0
		return false

	# On attend la fin du son, plus une marge : la queue d'un filtre resonant
	# sort APRES la derniere image du flux, et la couper net s'entend.
	_n += 1
	var duree := _lecteur.stream.get_length()
	if _n < int(duree * Engine.get_frames_per_second()) + 20:
		return false

	_record.set_recording_active(false)
	var pris := _record.get_recording()
	if pris != null:
		var suffixe: String = "direct" if _etape == 2 else str(item["canal"])
		var nom := "%02d_%s_%s.wav" % [_i + 1, _simplifier(str(item["qui"])), suffixe]
		# ON MESURE LE FICHIER PRODUIT : save_to_wav peut rendre OK sur une
		# capture vide, donc on imprime la duree reellement ecrite.
		pris.save_to_wav(_dossier + nom)
		var secondes := float(pris.data.size()) / (pris.mix_rate * (4 if pris.stereo else 2))
		print("  %-34s %5.1f s   %s" % [nom, secondes, item["vo"].substr(0, 34)])
		_ecrits += 1

	if _etape == 2:
		_etape = 3          # on refait la meme, filtree cette fois
	else:
		_etape = 1
		_i += 1
	_n = 0
	return false
