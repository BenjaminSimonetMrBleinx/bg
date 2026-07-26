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


const DECOR := "res://assets/decor/%s.glb"

## Elements de decor qui ne sont pas des .glb du dossier decor. La voiture
## garee est une scene composee : une caisse et quatre roues, comme le
## vehicule jouable mais sans physique.
const SCENES := {
	"voiture_garee": "res://scenes/voiture_garee.tscn",
}

## Le mobilier n'a pas besoin de collision : ce sont des objets bas, et une
## poubelle qui arrete une voiture est plus penible qu'une poubelle qu'on
## traverse. Ceux-la seuls sont solides, parce qu'on ne pardonne pas de
## passer au travers.
const SOLIDES := ["benne", "banc", "cactus", "panneau"]


## Les materiaux de facade qui portent un masque de fenetres allumees. On les
## garde pour pouvoir monter et descendre leur emission a l'heure voulue.
var _fenetres: Array[BaseMaterial3D] = []

## Le porte-lampadaires. Masque en bloc de jour : un noeud invisible n'est pas
## rendu, donc trente-deux sources eteintes ne coutent rien.
var _lampes: Node3D = null


func _ready() -> void:
	_poser_geometrie()
	_recenser_fenetres()
	eclairer_fenetres(0.0 if Reglages.est_jour() else 1.0)
	_poser_lampes()
	_poser_decor()
	prete.emit(etendue)


# Les fenetres allumees sont un masque d'EMISSION sur les facades, pas une
# couleur peinte dedans. C'est ce qui permet de changer d'heure sans
# refabriquer la ville : jusqu'ici l'etat des vitres etait cuit dans la texture,
# choisi a la generation, et le jeu ne pouvait rien y faire.
#
# Les materiaux viennent du .glb importe, donc ils sont PARTAGES entre toutes
# les faces qui les utilisent. Les modifier ici les modifie partout, ce qui est
# exactement ce qu'on veut : quatre materiaux pour toute la ville.
func _recenser_fenetres() -> void:
	_fenetres.clear()
	_collecter(self)


func _collecter(n: Node) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.mesh != null:
			for i in mi.mesh.get_surface_count():
				var m := mi.mesh.surface_get_material(i) as BaseMaterial3D
				if m != null and m.emission_enabled and not _fenetres.has(m):
					_fenetres.append(m)
	for e in n.get_children():
		_collecter(e)


## Allume les fenetres, de 0 (plein jour) a 1 (nuit noire). Continu : l'aube et
## le crepuscule sont des valeurs intermediaires, pas des cas particuliers.
func eclairer_fenetres(part: float) -> void:
	for m in _fenetres:
		m.emission_energy_multiplier = clampf(part, 0.0, 1.0)


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

	# Les lumieres sont TOUJOURS creees, et masquees de jour.
	#
	# Une version anterieure ne les creait pas du tout quand il faisait jour, et
	# c'etait justifie : une source coute meme a energie nulle. Mais avec une
	# heure qui avance, il faudrait alors les fabriquer au crepuscule — trente-
	# deux OmniLight3D d'un coup, en pleine partie, a l'image precise ou le
	# joueur regarde le ciel changer.
	#
	# Un noeud invisible n'est pas rendu du tout : masquer coute ce que couterait
	# ne pas exister, et l'allumage devient continu.
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

	_lampes = parent
	allumer_lampes(Reglages.nuit_part())
	print("ville : %d lampadaires, etendue %.0f m" % [parent.get_child_count(), etendue])


## Allume les lampadaires, de 0 (plein jour, eteints et masques) a 1 (nuit).
##
## Ils s'allument PLUS TOT que la nuit n'arrive : un reverbere s'allume au
## crepuscule, pas quand il fait noir. D'ou la part multipliee avant d'etre
## bornee — a un tiers de nuit, ils donnent deja tout.
func allumer_lampes(part: float) -> void:
	if _lampes == null or reglages == null:
		return
	var f := clampf(part * 3.0, 0.0, 1.0)
	_lampes.visible = f > 0.01
	for l in _lampes.get_children():
		(l as OmniLight3D).light_energy = reglages.lampe_energie * f


# Le mobilier vient du meme fichier que les lampes. Chaque type n'est charge
# QU'UNE FOIS : une PackedScene instanciee cent fois partage son maillage et
# sa texture, alors qu'un ResourceLoader.load par exemplaire les rechargerait
# a chaque appel et ferait de cent poubelles cent fois leur cout.
func _poser_decor() -> void:
	if not FileAccess.file_exists(lampes_json):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(lampes_json))
	if typeof(data) != TYPE_DICTIONARY:
		return
	var liste: Array = data.get("decor", [])
	if liste.is_empty():
		return

	var parent := Node3D.new()
	parent.name = "Decor"
	add_child(parent)

	var modeles := {}
	var manquants := {}
	for entree in liste:
		var type := str(entree.get("type", ""))
		if not modeles.has(type):
			var chemin: String = SCENES.get(type, DECOR % type)
			modeles[type] = (ResourceLoader.load(chemin) as PackedScene
					if ResourceLoader.exists(chemin) else null)
		if modeles[type] == null:
			manquants[type] = true
			continue

		var n := (modeles[type] as PackedScene).instantiate() as Node3D
		var p: Array = entree["pos"]
		n.position = Vector3(float(p[0]), float(p[1]), float(p[2]))
		n.rotation.y = float(entree.get("angle", 0.0))
		# Nomme explicitement : sinon Godot, refusant deux freres homonymes,
		# baptise le second "@Node3D@35". Sur cent trente elements, l'arbre
		# devient illisible et on ne peut plus dire ce qui a ete pose.
		n.name = "%s_%03d" % [type, parent.get_child_count()]
		parent.add_child(n)
		# La voiture garee porte deja son corps statique : lui en fabriquer
		# un second par maillage doublerait la collision et la ferait vibrer.
		if type in SOLIDES:
			_ajouter_collisions(n)

	if not manquants.is_empty():
		push_error("ville : decor introuvable (%s). Regenerer : "
				% ", ".join(manquants.keys())
				+ "blender -b -P outils/gen_decor.py -- --nom tous")

	print("ville : %d elements de decor, %d modeles"
			% [parent.get_child_count(), modeles.size()])
