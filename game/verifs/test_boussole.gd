# Chaque etape de la mission vise-t-elle un noeud qui existe ?
#
#     godot --headless --path game --script res://verifs/test_boussole.gd
#
# CE QUE CA ATTRAPE, ET POURQUOI IL FALLAIT UN TEST. Une cible mal nommee dans
# mission1.json ne casse rien : la boussole ne montre simplement pas de
# marqueur, ce qui est exactement ce qu'elle fait quand une etape n'a pas de
# cible. Deux causes, un seul symptome — et le symptome est l'absence de
# quelque chose, donc personne ne le remarque.
#
# Le piege est double : find_child rend le PREMIER noeud du nom demande. Il y a
# deux « Sortie » dans le jeu — celle de la maison de Walter et celle du
# camping-car — et rien ne dit laquelle on obtient. Le test imprime donc AUSSI
# la position trouvee : deux etapes qui visent le meme point alors qu'elles
# parlent de deux endroits differents se voient a l'oeil dans la liste.
extends SceneTree


func _initialize() -> void:
	var monde := (load("res://scenes/monde.tscn") as PackedScene).instantiate()
	root.add_child(monde)
	await process_frame
	await process_frame

	var brut := FileAccess.get_file_as_string("res://donnees/mission1.json")
	var d: Variant = JSON.parse_string(brut)
	if typeof(d) != TYPE_DICTIONARY:
		print("ECHEC mission1.json illisible")
		quit(1)
		return

	print("")
	print("--- ou pointe la boussole, etape par etape ---")
	var manquantes := 0
	var sans_cible := 0
	var vues: Dictionary = {}

	for e in (d as Dictionary).get("etapes", []):
		var cle := str((e as Dictionary).get("cle", ""))
		var nom := str((e as Dictionary).get("ou", ""))
		if nom == "":
			print("  %-16s (aucune cible)" % cle)
			sans_cible += 1
			continue
		var n := monde.find_child(nom, true, false) as Node3D
		if n == null:
			print("  %-16s -> '%s' INTROUVABLE" % [cle, nom])
			manquantes += 1
			continue
		var p := n.global_position
		var repere := "%.0f,%.0f" % [p.x, p.z]
		var doublon := " <- meme point que '%s'" % vues[repere] if vues.has(repere) else ""
		print("  %-16s -> %-18s %8.0f %8.0f%s" % [cle, nom, p.x, p.z, doublon])
		if not vues.has(repere):
			vues[repere] = cle

	print("")
	if manquantes > 0:
		print("ECHEC %d cible(s) introuvable(s)" % manquantes)
		quit(1)
		return
	print("OK  %d etape(s) visent un noeud existant, %d sans cible"
			% [(d as Dictionary).get("etapes", []).size() - sans_cible, sans_cible])
	quit()
