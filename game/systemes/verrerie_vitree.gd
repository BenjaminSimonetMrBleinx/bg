# Donne du verre a la verrerie generee, sans toucher au generateur.
#
# POURQUOI PAR CODE ET PAS DANS gen_lieux.py.
#
# Les generateurs Blender cuisent des StandardMaterial3D dans le .glb. Un
# ShaderMaterial ne se cuit pas : c'est une ressource Godot, elle n'existe pas
# dans le format glTF. On peut donc soit fabriquer le materiau au chargement,
# soit renoncer — et renoncer voudrait dire garder des cylindres opaques.
#
# On passe par set_surface_override_material : ca laisse la ressource du .glb
# intacte, donc un `generer` qui reecrit le fichier ne perd rien, et les
# maillages qui partagent le meme materiau ne sont pas affectes en cascade.
#
# CE QUE CA CORRIGE. La verrerie du camping-car est faite de quatorze cylindres
# a six cotes, deux ballons et cinq cones — de bonnes silhouettes, et c'etait le
# bon calcul a 512x384 ou aucun detail ne passait. A 960x720 ils se lisent comme
# ce qu'ils sont : des blocs blancs. Le shader ne change pas leur forme, il leur
# donne un bord qui s'allume, un menisque, et ce qu'il y a derriere qui se
# deforme un peu. C'est cela qu'on lit comme « du verre », pas la silhouette.
extends Node

const VERRE := "res://rendu/liquide.gdshader"

## Les maillages a vitrer, et la couleur de ce qu'ils contiennent.
##
## Les noms viennent de gen_lieux.py et sont ceux du .glb. Un maillage absent
## est ignore sans bruit : le decor peut etre regenere sans ces pieces, et une
## erreur ici empecherait la mission de se charger pour un detail d'aspect.
## L'ALPHA DU VERRE EST MONTE APRES COUP, et pas pour faire joli.
##
## A 0,30 les cylindres disparaissaient : on voyait au travers, mais on ne les
## voyait plus. Or c'est leur silhouette qui fait le labo — quatorze verticales
## fines et serrees, c'est le calcul du generateur et il est bon. Un verre
## invisible rend la paillasse vide.
##
## A 0,52 avec un bord franc, on lit les deux : la forme ET la transparence.
const PIECES := {
	"Verrerie": {"couleur": Color(0.87, 0.91, 0.89, 0.52), "trouble": 0.16},
	"Liquides": {"couleur": Color(0.79, 0.55, 0.16, 0.92), "trouble": 0.62},
	"LiquidesVerts": {"couleur": Color(0.32, 0.62, 0.28, 0.92), "trouble": 0.62},
}


func _ready() -> void:
	var shader := load(VERRE) as Shader
	if shader == null:
		push_warning("verrerie : %s introuvable" % VERRE)
		return
	var poses := 0
	for enfant in get_parent().get_children():
		poses += _vitrer(enfant, shader)
	if poses == 0:
		# On le DIT plutot que de laisser croire que c'est fait. Les noms de
		# maillage viennent du generateur : le jour ou il les renomme, ce
		# script cesse silencieusement de servir a quelque chose.
		push_warning("verrerie : aucun maillage reconnu, le decor a-t-il change de noms ?")


func _vitrer(n: Node, shader: Shader) -> int:
	var poses := 0
	if n is MeshInstance3D and PIECES.has(n.name):
		var reglage: Dictionary = PIECES[n.name]
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("couleur", reglage["couleur"])
		mat.set_shader_parameter("trouble", reglage["trouble"])
		# Tres court : a 960x720 une refraction franche fait glisser le decor
		# derriere le becher, et on lit une loupe au lieu d'un recipient.
		mat.set_shader_parameter("refraction", 0.012)
		mat.set_shader_parameter("menisque", 0.10)
		mat.set_shader_parameter("bord", 0.9)
		var mi := n as MeshInstance3D
		for s in range(maxi(1, mi.get_surface_override_material_count())):
			mi.set_surface_override_material(s, mat)
		poses += 1
	for e in n.get_children():
		poses += _vitrer(e, shader)
	return poses
