# Les voitures qui roulent.
#
# Elles n'existaient pas : la ville n'avait que des voitures a l'arret. C'est
# le manque le plus visible d'un GTA — une rue sans circulation ne se lit pas
# comme une ville, quelle que soit la densite du mobilier.
#
# Le graphe des rues vient du generateur, comme les lampadaires et le
# mobilier. Une ville regeneree avec une autre graine fait circuler ses
# voitures toute seule.
#
# Elles sont des AnimatableBody3D : des corps cinematiques, deplaces a la main
# et non simules. C'est le point important. Une circulation en physique — avec
# suspension, adherence, changement de voie — est l'endroit precis ou les
# projets a deux meurent. Ici une voiture suit une ligne et s'arrete si
# quelque chose la barre ; elle pousse le joueur s'il se met devant, parce que
# c'est ce que fait un AnimatableBody3D, et ca suffit.
class_name Trafic
extends Node3D

@export var reglages: Reglages
@export var routes_json: String = "res://assets/ville/ville_lampes.json"

const MODELE := "res://assets/vehicules/garee_%s.glb"

## Combien de voitures en circulation. Une dizaine suffit sur quatre ilots :
## ce qui compte est d'en croiser une de temps en temps, pas d'embouteiller.
@export_range(0, 60, 1) var combien: int = 10

## Modeles mis en circulation, avec leurs poids. L'Alpine n'y est pas : elle
## est garee, et une piece unique qui passe en boucle cesse d'etre unique.
const MODELES := [
	["pickup", 34], ["berline", 28], ["break", 24], ["aztek", 14],
]

var _agents: Array[Circulant] = []


func _ready() -> void:
	var data := _lire()
	if data.is_empty():
		return
	var noeuds: Array = data["noeuds"]
	var voisins := _voisinage(noeuds.size(), data["aretes"])
	var aretes: Array = data["aretes"]
	if aretes.is_empty():
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = 20082010          # les annees de la serie, et une graine stable

	var modeles := {}
	for i in combien:
		var nom := _tirer(rng)
		if not modeles.has(nom):
			var chemin := MODELE % nom
			modeles[nom] = (ResourceLoader.load(chemin) as PackedScene
					if ResourceLoader.exists(chemin) else null)
		if modeles[nom] == null:
			push_error("trafic : %s introuvable. Regenerer : " % (MODELE % nom)
					+ "blender -b -P outils/gen_voiture.py -- --modele tous --garee")
			continue

		var arete: Array = aretes[rng.randi() % aretes.size()]
		# Un sens sur deux, sinon toute la circulation tourne dans le meme sens
		# et les rues d'un cote sont desertes.
		var de: int = arete[0] if rng.randf() < 0.5 else arete[1]
		var vers: int = arete[1] if de == arete[0] else arete[0]

		var v := Circulant.new()
		v.name = "Voiture_%02d" % i
		v.vitesse = reglages.trafic_vitesse * rng.randf_range(0.82, 1.15)
		v.ecart = float(data.get("demi_voie", 2.75))
		# Couche 1 : le joueur et sa voiture les percutent comme un mur.
		v.collision_layer = 1
		v.collision_mask = 0

		var forme := CollisionShape3D.new()
		var boite := BoxShape3D.new()
		boite.size = Vector3(1.9, 1.5, 4.6)
		forme.shape = boite
		forme.position.y = 0.75
		v.add_child(forme)
		v.add_child((modeles[nom] as PackedScene).instantiate())
		add_child(v)
		# Le regard doit voir le joueur ET les autres voitures, donc la couche
		# 1 comme la 2. Pose apres l'entree dans l'arbre : un RayCast3D hors de
		# l'arbre ne peut pas interroger le monde.
		v.poser_le_regard(reglages.trafic_garde, 1 | 2)
		v.demarrer(noeuds, voisins, de, vers, rng)
		_agents.append(v)

	print("trafic : %d voiture(s) en circulation, %d carrefours"
			% [_agents.size(), noeuds.size()])


## Les voitures en circulation, pour les tests. Un trafic qui ne bouge pas
## ressemble exactement a un trafic qui n'existe pas.
func agents() -> Array[Circulant]:
	return _agents


func _lire() -> Dictionary:
	if not FileAccess.file_exists(routes_json):
		return {}
	var data: Variant = JSON.parse_string(
			FileAccess.get_file_as_string(routes_json))
	if typeof(data) != TYPE_DICTIONARY:
		return {}
	var g: Variant = (data as Dictionary).get("graphe", {})
	if typeof(g) != TYPE_DICTIONARY or not (g as Dictionary).has("noeuds"):
		push_warning("trafic : aucun graphe dans %s. Regenerer la ville."
				% routes_json)
		return {}
	return g


# La liste des voisins de chaque carrefour. On la construit une fois plutot
# que de parcourir les aretes a chaque intersection : a douze troncons c'est
# gratuit, mais c'est la boucle qui tourne le plus souvent du systeme.
static func _voisinage(combien_noeuds: int, aretes: Array) -> Dictionary:
	var v := {}
	for i in combien_noeuds:
		v[i] = []
	for a in aretes:
		v[int(a[0])].append(int(a[1]))
		v[int(a[1])].append(int(a[0]))
	return v


static func _tirer(rng: RandomNumberGenerator) -> String:
	var total := 0
	for m in MODELES:
		total += int(m[1])
	var seuil := rng.randi() % total
	for m in MODELES:
		seuil -= int(m[1])
		if seuil < 0:
			return str(m[0])
	return str(MODELES[0][0])
