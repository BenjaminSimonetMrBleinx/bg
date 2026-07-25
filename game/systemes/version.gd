# La version du jeu, et d'ou elle vient.
#
# UNE seule source : `application/config/version` dans project.godot. C'est
# deja le champ que Godot utilise pour l'export, les proprietes de l'exe et le
# nom du paquet — en tenir un seul evite le cas classique ou l'ecran-titre, le
# fichier de sauvegarde et l'executable annoncent trois numeros differents.
#
# Le numero de commit, lui, ne peut PAS venir de la : git n'existe pas dans un
# executable livre. bg.ps1 l'ecrit dans donnees/version.json juste avant de
# lancer ou d'exporter. Le fichier est facultatif — sans lui on affiche le
# numero seul, ce qui est le cas quand on ouvre le projet dans l'editeur.
#
# Convention retenue : MAJEUR.MINEUR.CORRECTIF.
#   - MAJEUR 1 le jour ou le jeu se tient de bout en bout. On n'y est pas.
#   - MINEUR a chaque lot de fonctionnalites livre.
#   - CORRECTIF pour ce qui repare sans rien ajouter.
class_name Version
extends RefCounted

const FICHIER := "res://donnees/version.json"

## Ce qu'on affiche quand aucune information de build n'est disponible : on
## travaille dans l'editeur, sur du code qui n'est peut-etre meme pas commite.
const ATELIER := "atelier"

static var _cache: String = ""


## « 0.9.0 » — le numero seul.
static func numero() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0.0.0"))


## « v0.9.0 · a1b2c3d » — ce qu'on affiche a l'ecran et ce qu'on demande a
## quelqu'un qui signale un probleme. Le numero seul ne suffit pas : entre
## deux versions on fait vingt commits, et « ca marche pas en 0.9.0 » ne
## designe rien de precis.
static func texte() -> String:
	if _cache != "":
		return _cache
	_cache = "v" + numero()
	var b := build()
	if b != "":
		_cache += " · " + b
	return _cache


## Le commit, court. Vide si l'information n'a pas ete ecrite.
static func build() -> String:
	if not FileAccess.file_exists(FICHIER):
		return ATELIER
	var lu: Variant = JSON.parse_string(FileAccess.get_file_as_string(FICHIER))
	if typeof(lu) != TYPE_DICTIONARY:
		return ATELIER
	return str((lu as Dictionary).get("commit", ATELIER))
