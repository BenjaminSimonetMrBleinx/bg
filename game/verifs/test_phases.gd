# Peut-on vraiment sauter a chaque phase de la mission 1 ?
#
#     godot --headless --path game --script res://verifs/test_phases.gd
#
# CE QUE CA ATTRAPE. Le menu de test propose dix phases. Chacune peut echouer de
# deux facons, et AUCUNE des deux ne leve d'erreur :
#
#   1. la cle d'etape n'existe plus dans mission1.json — on renomme une etape,
#      la table de dev.gd garde l'ancien nom, et la ligne du menu ne fait plus
#      rien du tout ;
#   2. l'etape existe mais son 'ou' designe un noeud absent — le joueur reste
#      ou il est, la mission avance quand meme, et on croit que le saut a
#      marche jusqu'a se demander pourquoi le decor n'est pas le bon.
#
# On deroule donc les evenements comme le fait dev.gd, pour de vrai, et on
# verifie qu'on arrive a l'etape visee ET que l'endroit existe.
extends SceneTree


func _initialize() -> void:
	var monde := (load("res://scenes/monde.tscn") as PackedScene).instantiate()
	root.add_child(monde)
	await process_frame
	await process_frame

	var dev := monde.find_child("Dev", true, false)
	if dev == null:
		print("ECHEC noeud Dev introuvable")
		quit(1)
		return
	var m := Mission.courante(dev)
	if m == null:
		print("ECHEC pas de mission")
		quit(1)
		return

	var phases: Array = dev.get("PHASES")
	if phases == null or phases.is_empty():
		print("ECHEC dev.gd ne publie aucune phase")
		quit(1)
		return

	# Les cles d'etape que la mission connait vraiment.
	var connues: Dictionary = {}
	for e in m.etapes():
		connues[str((e as Dictionary).get("cle", ""))] = true

	print("")
	print("--- les phases de la mission 1 ---")
	var rates := 0

	for p in phases:
		var phase: Dictionary = p
		var nom := str(phase["nom"])
		var cible := str(phase["etape"])

		if not connues.has(cible):
			printerr("  ECHEC %-28s l'etape '%s' n'existe pas dans mission1.json"
					% [nom, cible])
			rates += 1
			continue

		# On rembobine et on avance par les MEMES evenements que le jeu : c'est
		# ce que fait dev.gd, et un test qui poserait l'index validerait un
		# chemin que personne n'emprunte.
		m.recommencer()
		var garde := 0
		while not m.finie() and m.cle_etape() != cible and garde < 40:
			garde += 1
			var quoi := str(m.etape().get("valide_par", ""))
			if quoi == "" or not m.evenement(quoi):
				break

		if m.cle_etape() != cible:
			printerr("  ECHEC %-28s bloque a '%s'" % [nom, m.cle_etape()])
			rates += 1
			continue

		var ou := m.ou()
		if ou == "":
			printerr("  ECHEC %-28s l'etape ne dit pas ou aller" % nom)
			rates += 1
			continue
		var n := monde.find_child(ou, true, false) as Node3D
		if n == null:
			printerr("  ECHEC %-28s '%s' introuvable dans la scene" % [nom, ou])
			rates += 1
			continue

		var pos := n.global_position
		print("  ok   %-28s %-18s %7.0f %7.0f  zone '%s'%s"
				% [nom, ou, pos.x, pos.z, str(phase["zone"]),
				"  interieur" if bool(phase["clos"]) else ""])

	# LA LISTE DES LIEUX DOIT RESTER COURTE. Elle publiait quarante et un noms,
	# dont trente-sept parcelles du generateur ; le cadre en montre quatorze.
	# Si elle regrossit, c'est que les parcelles sont revenues.
	var lieux: Array = dev.call("lieux")
	print("")
	print("  %d lieu(x) proposes : %s" % [lieux.size(), ", ".join(lieux)])
	if lieux.size() > 14:
		printerr("  ECHEC la liste des lieux deborde du cadre (%d > 14)"
				% lieux.size())
		rates += 1

	print("")
	if rates > 0:
		print("ECHEC %d phase(s) ou liste(s) en defaut" % rates)
		quit(1)
		return
	print("TEST PHASES OK  %d phase(s) atteignables" % phases.size())
	quit()
