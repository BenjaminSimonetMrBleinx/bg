# Les passants de la rue.
#
# Ils sont fabriques ici plutot que poses dans la scene : leurs trajets
# viennent du generateur de ville, en meme temps que les lampadaires et le
# mobilier. Une ville regeneree avec une autre graine repeuple ses trottoirs
# toute seule.
#
# Chaque passant est un CharacterBody3D monte a la volee — capsule, maillage,
# script. Une scene .tscn par modele de passant aurait impose d'en creer une
# nouvelle a chaque personnage ajoute au generateur, pour trois lignes de
# difference.
class_name Foule
extends Node3D

@export var reglages: Reglages
@export var routes_json: String = "res://assets/ville/ville_lampes.json"

const MODELE := "res://assets/personnages/%s.glb"

## Hauteur et rayon de la capsule. Identiques au joueur : c'est le meme
## maillage, il doit occuper la meme place.
const TAILLE := 1.78
const RAYON := 0.28


func _ready() -> void:
	if reglages == null:
		push_error("foule : aucune ressource Reglages assignee")
		return
	if not FileAccess.file_exists(routes_json):
		return

	var data = JSON.parse_string(FileAccess.get_file_as_string(routes_json))
	if typeof(data) != TYPE_DICTIONARY:
		return
	var routes: Array = data.get("pietons", [])
	if routes.is_empty():
		return

	var modeles := {}
	var poses := 0
	for route in routes:
		var nom := str(route.get("modele", "passant_a"))
		if not modeles.has(nom):
			var chemin := MODELE % nom
			modeles[nom] = (ResourceLoader.load(chemin) as PackedScene
					if ResourceLoader.exists(chemin) else null)
		if modeles[nom] == null:
			push_error("foule : %s introuvable. Regenerer : " % (MODELE % nom)
					+ "blender -b -P outils/gen_personnage.py -- --nom tous")
			continue
		_poser(modeles[nom], route, poses)
		poses += 1

	print("foule : %d passant(s), %d modeles" % [poses, modeles.size()])


func _poser(modele: PackedScene, route: Dictionary, index: int) -> void:
	var p := Pieton.new()
	p.name = "Passant_%02d" % index
	p.reglages = reglages
	p.depart = _vec(route.get("depart", [0, 0, 0]))
	p.arrivee = _vec(route.get("arrivee", [0, 0, 0]))
	p.allure = float(route.get("allure", 1.0))
	# Couche 2 comme le joueur : ils ne doivent pas bloquer le rayon de la
	# camera, sinon elle se colle a la nuque des qu'un passant la croise.
	p.collision_layer = 2
	p.collision_mask = 1

	var forme := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = RAYON
	capsule.height = TAILLE
	forme.shape = capsule
	forme.position.y = TAILLE / 2.0
	p.add_child(forme)

	p.add_child(modele.instantiate())
	add_child(p)
	p.global_position = p.depart


static func _vec(v: Variant) -> Vector3:
	var a: Array = v if typeof(v) == TYPE_ARRAY else []
	if a.size() < 3:
		return Vector3.ZERO
	return Vector3(float(a[0]), float(a[1]), float(a[2]))
