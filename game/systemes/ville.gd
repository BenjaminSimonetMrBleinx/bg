# Assemble le quartier : la geometrie generee, ses collisions, et ses
# lampadaires.
#
# La geometrie vient d'un .glb produit par outils/gen_ville.py. Les lampadaires
# ne sont PAS dans le .glb : ils arrivent en JSON et sont instancies ici avec
# l'intensite, la portee et la couleur de reglages.tres. Un glTF figerait ces
# valeurs ; en donnees, elles restent au curseur.
extends Node3D

@export var reglages: Reglages
@export var geometrie: PackedScene
@export var lampes_json: String = "res://assets/ville/ville_lampes.json"

## Emis une fois la ville prete, avec son etendue en metres.
signal prete(etendue: float)

var etendue: float = 0.0


func _ready() -> void:
	_poser_geometrie()
	_poser_lampes()
	prete.emit(etendue)


func _poser_geometrie() -> void:
	if geometrie == null:
		push_error("ville : aucune geometrie assignee")
		return
	var noeud := geometrie.instantiate()
	add_child(noeud)
	_ajouter_collisions(noeud)


# Le .glb ne contient que des maillages. On leur fabrique des corps statiques
# a la volee plutot que de les stocker : la geometrie etant regeneree a chaque
# changement de graine, des collisions figees se desynchroniseraient.
func _ajouter_collisions(noeud: Node) -> void:
	if noeud is MeshInstance3D:
		var mi := noeud as MeshInstance3D
		if mi.mesh != null:
			mi.create_trimesh_collision()
	for enfant in noeud.get_children():
		_ajouter_collisions(enfant)


func _poser_lampes() -> void:
	if reglages == null:
		push_error("ville : aucune ressource Reglages assignee")
		return
	if not FileAccess.file_exists(lampes_json):
		push_warning("ville : %s introuvable, aucun lampadaire" % lampes_json)
		return

	var brut := FileAccess.get_file_as_string(lampes_json)
	var data = JSON.parse_string(brut)
	if typeof(data) != TYPE_DICTIONARY:
		push_error("ville : %s illisible" % lampes_json)
		return

	etendue = float(data.get("etendue", 0.0))

	var parent := Node3D.new()
	parent.name = "Lampes"
	add_child(parent)

	for entree in data.get("lampes", []):
		var p: Array = entree["pos"]
		var v: Array = entree.get("vers", [0.0, 0.0, 0.0])
		var lumiere := OmniLight3D.new()
		# la source est sous la potence, decalee vers la chaussee
		lumiere.position = Vector3(
			float(p[0]) + float(v[0]) * 0.6,
			float(p[1]),
			float(p[2]) + float(v[2]) * 0.6)
		lumiere.light_color = reglages.lampe_couleur
		lumiere.light_energy = reglages.lampe_energie
		lumiere.omni_range = reglages.lampe_portee
		lumiere.omni_attenuation = reglages.lampe_attenuation
		lumiere.shadow_enabled = reglages.lampe_ombres
		# Sans cette limite, une rue entiere de lampadaires sature le rendu
		# de la moindre facade. La PS2 avait la meme contrainte, en pire.
		lumiere.distance_fade_enabled = true
		lumiere.distance_fade_begin = reglages.brouillard_fin * 0.7
		lumiere.distance_fade_length = reglages.brouillard_fin * 0.3
		parent.add_child(lumiere)

	print("ville : %d lampadaires, etendue %.0f m" % [parent.get_child_count(), etendue])
