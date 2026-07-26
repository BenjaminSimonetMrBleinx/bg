# Le corps qui s'effondre.
#
# Godot sait faire un ragdoll a partir d'un Skeleton3D, mais il ne le fait pas
# tout seul : il faut un PhysicalBone3D par os, avec sa forme, sa masse et ses
# limites d'articulation. L'editeur propose de les generer ; le squelette
# arrive ici par un .glb regenere a chaque livraison, donc tout ce qui serait
# pose a la main dans la scene serait perdu au prochain import.
#
# On les FABRIQUE donc au chargement, depuis la table ci-dessous. Elle décrit
# le corps humain une fois — quels os portent de la matiere, quel diametre,
# quelle masse — et elle vaudra pour n'importe quel personnage du meme rig.
#
# CE QUI SE PASSE QUAND ON SE TROMPE : un ragdoll mal contraint ne tombe pas
# mollement, il EXPLOSE. Les os se repoussent, le corps part en vrille et
# traverse le sol en une demi-seconde. C'est pour ca que les limites sont
# serrees et la masse repartie plutot qu'uniforme.
class_name Ragdoll
extends RefCounted

## Les os qui portent de la matiere, et ce qu'ils pesent.
##
##   os          nom dans le squelette
##   longueur    en metres, le long de l'os
##   rayon       la capsule autour
##   masse       en kg. Le total fait 78 kg, ce qui est un homme
##   liberte     ouverture de l'articulation en degres. Un cou a 30 degres et
##               un genou a 90 : c'est ce qui empeche le pantin desarticule
const MEMBRES := [
	{ "os": "Hips", "longueur": 0.18, "rayon": 0.15, "masse": 14.0, "liberte": 45.0 },
	{ "os": "Spine01", "longueur": 0.22, "rayon": 0.14, "masse": 16.0, "liberte": 25.0 },
	{ "os": "Spine", "longueur": 0.20, "rayon": 0.14, "masse": 10.0, "liberte": 20.0 },
	{ "os": "Head", "longueur": 0.20, "rayon": 0.10, "masse": 5.0, "liberte": 30.0 },
	{ "os": "LeftArm", "longueur": 0.27, "rayon": 0.05, "masse": 2.5, "liberte": 75.0 },
	{ "os": "LeftForeArm", "longueur": 0.25, "rayon": 0.04, "masse": 1.8, "liberte": 80.0 },
	{ "os": "RightArm", "longueur": 0.27, "rayon": 0.05, "masse": 2.5, "liberte": 75.0 },
	{ "os": "RightForeArm", "longueur": 0.25, "rayon": 0.04, "masse": 1.8, "liberte": 80.0 },
	{ "os": "LeftUpLeg", "longueur": 0.40, "rayon": 0.08, "masse": 8.0, "liberte": 60.0 },
	{ "os": "LeftLeg", "longueur": 0.38, "rayon": 0.06, "masse": 4.0, "liberte": 70.0 },
	{ "os": "RightUpLeg", "longueur": 0.40, "rayon": 0.08, "masse": 8.0, "liberte": 60.0 },
	{ "os": "RightLeg", "longueur": 0.38, "rayon": 0.06, "masse": 4.0, "liberte": 70.0 },
]

## Le calque de collision des corps du ragdoll. Le meme que le decor, et
## surtout PAS celui du joueur : la capsule du personnage est encore la, et un
## ragdoll qui s'appuie dessus se fait ejecter.
const CALQUE := 1

var _squelette: Skeleton3D
var _simulateur: PhysicalBoneSimulator3D
var _actif: bool = false
var _os: Array[PhysicalBone3D] = []


func actif() -> bool:
	return _actif


## Prepare le corps. A appeler une fois, au chargement : construire douze
## corps physiques au moment de la mort couterait une saccade a l'image
## precise ou le jeu doit etre le plus lisible.
##
## Renvoie faux si le personnage n'a pas de squelette — les passants generes
## n'en ont pas, et ils ne meurent pas.
func preparer(racine: Node) -> bool:
	_squelette = racine.find_child("Skeleton3D", true, false) as Skeleton3D
	if _squelette == null:
		return false

	_simulateur = PhysicalBoneSimulator3D.new()
	_simulateur.name = "Ragdoll"
	_squelette.add_child(_simulateur)

	var poses: Array[int] = []
	for m in MEMBRES:
		var i := _squelette.find_bone(str(m["os"]))
		if i < 0:
			continue
		poses.append(i)
		_simulateur.add_child(_fabriquer(m, i))

	if _os.is_empty():
		push_warning("ragdoll : aucun os reconnu dans %s" % racine.name)
		return false
	# On NE SIMULE PAS tout de suite. Tant que personne n'est mort, c'est
	# l'animation qui pilote le squelette ; des corps physiques actifs des le
	# depart tireraient dessus et le personnage marcherait en se tordant.
	return true


func _fabriquer(m: Dictionary, index: int) -> PhysicalBone3D:
	var corps := PhysicalBone3D.new()
	corps.name = "Os_" + str(m["os"])
	corps.bone_name = str(m["os"])
	corps.mass = float(m["masse"])
	# SANS AUCUNE COLLISION tant qu'on est vivant, et c'est le point le plus
	# important du fichier.
	#
	# Les corps existent des le chargement — les fabriquer au moment de la mort
	# couterait une saccade a l'image ou le jeu doit etre le plus lisible. Mais
	# des corps physiques accroches a un personnage qui marche BOUSCULENT tout :
	# mesure faite, le joueur traversait le sol du salon et tombait a moins
	# soixante-quinze metres, et quatre suites de tests sont devenues rouges
	# d'un coup sans qu'aucune ne parle de ragdoll.
	corps.collision_layer = 0
	corps.collision_mask = 0
	# Un peu d'amortissement, sinon le corps rebondit comme un sac de balles
	# de ping-pong. La chair ne rebondit pas.
	corps.linear_damp_mode = PhysicalBone3D.DAMP_MODE_REPLACE
	corps.linear_damp = 0.6
	corps.angular_damp_mode = PhysicalBone3D.DAMP_MODE_REPLACE
	corps.angular_damp = 3.0
	corps.joint_type = PhysicalBone3D.JOINT_TYPE_CONE
	corps.set("joint_constraints/swing_span", float(m["liberte"]))
	corps.set("joint_constraints/twist_span", float(m["liberte"]) * 0.5)

	var forme := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = float(m["rayon"])
	capsule.height = maxf(float(m["longueur"]), float(m["rayon"]) * 2.0 + 0.02)
	forme.shape = capsule
	# La capsule est posee LE LONG de l'os, pas centree sur son origine : un
	# os Godot part de son articulation, donc la matiere est devant lui.
	forme.position = Vector3(0.0, -capsule.height * 0.5, 0.0)
	corps.add_child(forme)
	_os.append(corps)
	return corps


## Le corps s'effondre. `poussee` est l'elan a lui donner — la direction du
## tir, typiquement : un corps qui tombe droit alors qu'on vient de le
## mitrailler de face se lit comme un bug.
func lacher(poussee: Vector3 = Vector3.ZERO) -> void:
	if _actif or _simulateur == null:
		return
	_actif = true
	# Les collisions ne s'allument qu'ICI : le corps devient une masse au
	# moment ou il cesse d'etre un personnage, et pas avant.
	for corps in _os:
		corps.collision_layer = CALQUE
		corps.collision_mask = CALQUE
	# La pose de depart de la simulation est celle de l'ANIMATION EN COURS.
	# C'est ce que fait physical_bones_start_simulation : les corps prennent
	# la position des os, puis la physique reprend a partir de la. Sans ca, le
	# corps se teleporterait en pose de repos avant de tomber.
	_simulateur.physical_bones_start_simulation()
	if poussee.length_squared() > 0.0:
		for corps in _os:
			# Le buste prend l'essentiel : pousser uniformement fait partir le
			# corps en translation, comme un mannequin sur un rail.
			var part := 1.0 if corps.bone_name in ["Spine01", "Spine", "Hips"] else 0.35
			corps.apply_central_impulse(poussee * corps.mass * part)


## Rend le squelette a l'animation. Pour recommencer une partie.
func relever() -> void:
	if not _actif or _simulateur == null:
		return
	_actif = false
	_simulateur.physical_bones_stop_simulation()
	for corps in _os:
		corps.collision_layer = 0
		corps.collision_mask = 0
