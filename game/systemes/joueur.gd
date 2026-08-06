# Walter a pied.
#
# Ce script ne s'occupe que de ce qui est PROPRE au joueur : lire les touches,
# le faire pivoter et avancer, et franchir les bordures de trottoir.
#
# Les commandes sont celles des jeux de l'epoque : GAUCHE et DROITE font
# PIVOTER sur place, AVANT et ARRIERE deplacent selon l'orientation du
# personnage. La camera n'entre pas dans le calcul.
#
# Ce n'est pas de la nostalgie. Pendant trois versions, la direction se
# lisait sur la camera — et comme la camera suit le personnage, aller sur le
# cote la faisait tourner, ce qui faisait tourner la direction, ce qui la
# faisait tourner encore. On y a repondu en bloquant la camera, puis en
# figeant le repere a l'appui. Les deux marchaient et aucun n'etait franc.
# Ici la boucle n'existe pas : il n'y a rien a casser.
#
# La marche elle-meme vit dans silhouette.gd, partagee avec les pietons de la
# rue. Elle y a ete deplacee parce que le maillage est le meme pour tout le
# monde : la dupliquer aurait garanti que les deux demarches divergent au
# premier reglage.
class_name Joueur
extends CharacterBody3D

## Emis quand Walter prend un coup, et quand il tombe. Le premier sert au HUD,
## le second a l'ecran de fin. Aucun des deux n'est traite ici : mourir met en
## jeu le ralenti, le noir et blanc, une musique et un ragdoll, et rien de tout
## cela n'est l'affaire du personnage qui marche.
signal blesse(restant: float)
signal mort

## Points de vie, sur 100. Une balle en retire un quart — quatre balles et
## c'est fini, ce qui est peu et c'est voulu : on ne gagne pas un echange de
## tirs contre les hommes de Tuco, on s'enfuit.
var pv: float = 100.0
var _vivant: bool = true

## Outil de test : les coups ne portent plus. Pose par le menu des outils, et
## jamais par le jeu — c'est pour traverser une fusillade quand on vient
## verifier autre chose que la fusillade.
var invulnerable: bool = false


func vivant() -> bool:
	return _vivant


## Encaisse des degats. Renvoie vrai si le coup a ete fatal.
func blesser(degats: float) -> bool:
	if not _vivant or degats <= 0.0 or invulnerable:
		return false
	pv = maxf(0.0, pv - degats)
	blesse.emit(pv)
	if pv > 0.0:
		return false
	_vivant = false
	bloque = true
	mort.emit()
	return true


## Remet Walter d'aplomb. Appele en recommencant une partie.
func ressusciter() -> void:
	pv = 100.0
	_vivant = true
	bloque = false
	velocity = Vector3.ZERO

@export var reglages: Reglages
## Conserve pour la compatibilite de la scene. Le deplacement ne s'en sert
## plus du tout : c'est precisement ce qui a regle le probleme.
@export var camera: NodePath

## Est-on a l'interieur d'une maison ? Pose par le controleur au passage de la
## porte. Ne sert qu'au son des pas : le parquet et le trottoir ne sonnent pas
## pareil, et le joueur est le seul a savoir ou il est.
var interieur: bool = false

## L'allure en cours. Lue par les tests, et par rien d'autre : le personnage
## n'a pas besoin de se souvenir, il recalcule a chaque image.
var _allure: String = "trot"

var _cam: Camera3D
var _audio: Audio

## Le systeme audio, retrouve A LA DEMANDE et garde ensuite.
##
## Pas dans _ready() : le noeud Audio est declare plus bas dans la scene, donc
## il n'est pas encore dans son groupe quand celui-ci s'initialise. Le chercher
## trop tot donnait null, definitivement, et le silence qui suit ressemble a un
## mecanisme pas encore branche.
func _son() -> Audio:
	if _audio == null:
		_audio = Audio.courant(self)
	return _audio

## La marche. DEUX implementations, et le personnage decide laquelle :
##
##   - Demarche  pour un modele a squelette, qui porte sa propre animation
##   - Silhouette pour un maillage segmente, anime par du code
##
## Les deux exposent avancer(vitesse, delta) et emettent 'pas'. Walter est
## passe au squelette ; les passants suivront quand leurs modeles arriveront.
var _silhouette: Silhouette
var _demarche: Demarche
var _rayon: float = 0.28
var _gravite: float = ProjectSettings.get_setting("physics/3d/default_gravity", 14.0)

## L'accroupissement, et la capsule qui va avec.
##
## Baisser le modele sans toucher a la capsule ne sert a RIEN : on continue de
## buter sur ce sous quoi on vient de se baisser, et s'accroupir n'a plus
## d'autre effet que d'aller moins vite.
var _accroupi: bool = false
var _capsule: CapsuleShape3D
var _debout: float = 1.78


## La capsule suit l'allure. Elle est ancree AU SOL et pas au centre : une
## capsule qu'on raccourcit sans la redescendre laisse les pieds en l'air, et
## le personnage tombe de vingt centimetres a chaque accroupissement.
func _regler_la_capsule() -> void:
	if _capsule == null:
		return
	var h: float = reglages.accroupi_capsule if _accroupi else _debout
	_capsule.height = maxf(2.0 * _rayon + 0.01, h)
	var forme := $Collision as CollisionShape3D
	if forme != null:
		forme.position.y = _capsule.height * 0.5


## Est-il accroupi ? Pour les tests, et pour qui voudra s'en servir plus tard :
## rien d'autre ne distingue un personnage accroupi d'un personnage lent.
func accroupi() -> bool:
	return _accroupi

## Diagnostic, lu par les tests : nombre de bordures effectivement franchies,
## et raison du dernier refus. Un franchissement rate est silencieux sinon, et
## on passe son temps a supposer pourquoi.
var franchissements: int = 0
var _refus: String = ""


func raison_refus() -> String:
	return _refus


## L'allure en cours — marche, trot ou course — et l'animation qui la joue.
##
## Pour les tests, et il en faut : trois allures qui jouent toutes le meme clip
## a la meme vitesse ressemblent exactement a trois allures qui marchent.
func allure() -> String:
	return _allure


func animation() -> String:
	return _demarche.animation() if _demarche != null else ""


## Prend une pose declaree dans donnees/poses.json — telephoner, degainer,
## s'accroupir. Elle se melange par-dessus la marche : les segments qu'elle ne
## nomme pas continuent leur cycle, donc on peut marcher en telephonant.
func poser(nom: String) -> void:
	# Les poses de donnees/poses.json font tourner des SEGMENTS nommes. Un
	# personnage a squelette n'en a pas : ses gestes viendront de vraies
	# animations, pas de rotations posees a la main. On ne fait donc rien
	# plutot que de faire semblant.
	if _silhouette != null:
		_silhouette.poser(nom)


func relacher_la_pose() -> void:
	if _silhouette != null:
		_silhouette.relacher()


## Joue un geste — se coiffer, lire. Renvoie sa duree en secondes, ou zero si
## le personnage ne sait pas le faire : l'appelant ne doit pas bloquer le
## joueur pour une animation qui ne jouera pas.
func geste(nom: String) -> float:
	return _demarche.geste(nom) if _demarche != null else 0.0


func geste_en_cours() -> String:
	return _demarche.geste_en_cours() if _demarche != null else ""


func annuler_le_geste() -> void:
	if _demarche != null:
		_demarche.annuler_le_geste()


## La pose en cours, pour les tests. Le poids d'un fondu n'est visible nulle
## part ailleurs, et une pose qui ne se declenche pas ressemble exactement a
## une pose qui n'existe pas.
func pose() -> String:
	return _silhouette.pose() if _silhouette != null else ""


# Un pas est joue DEPUIS LES PIEDS, pas depuis le centre du personnage : a la
# troisieme personne la camera est derriere et au-dessus, et un son emis a
# hauteur de poitrine s'entend trop pres.
#
# La hauteur varie d'un pas a l'autre. Sans elle, deux fichiers seulement — et
# on n'en a que deux — sonnent comme une boucle au bout de quelques metres.
func _poser_le_pied() -> void:
	if _son() == null:
		return
	var v := reglages.pas_variation
	_son().bruit_ici("pas_interieur" if interieur else "pas_exterieur",
			global_position, 1.0 + randf_range(-v, v))


func _ready() -> void:
	if reglages == null:
		push_error("joueur : aucune ressource Reglages assignee")
		set_physics_process(false)
		return
	_cam = get_node_or_null(camera) as Camera3D
	# On essaie le squelette d'abord. S'il n'y en a pas, on retombe sur la
	# silhouette procedurale sans que personne n'ait a le declarer.
	var d := Demarche.new(reglages)
	if d.recenser(self):
		_demarche = d
		_demarche.pas.connect(_poser_le_pied)
		print("JOUEUR : squelette, animation '%s'" % d.animation())
	else:
		_silhouette = Silhouette.new(reglages)
		_silhouette.recenser(self)
		_silhouette.pas.connect(_poser_le_pied)

	# Le franchissement doit degager le rayon de la capsule AU-DELA de
	# l'arete, sinon on retombe dedans. On le lit plutot que de le supposer.
	var forme := $Collision as CollisionShape3D
	if forme != null and forme.shape is CapsuleShape3D:
		# La forme est PROPRE a ce joueur : sans copie, s'accroupir raccourcirait
		# la capsule de toutes les instances qui partagent la ressource, y
		# compris dans une autre scene chargee en meme temps.
		forme.shape = forme.shape.duplicate()
		_capsule = forme.shape as CapsuleShape3D
		_rayon = _capsule.radius
		_debout = _capsule.height


## Outil de test : on traverse tout et on vole. Pose par le menu des outils, et
## par rien d'autre — voir traverser().
var traverse: bool = false

## Vitesse du vol libre, en metres par seconde, et son multiplicateur quand on
## tient sprint. Ce ne sont pas des nombres de ressenti : personne ne reglera
## jamais la vitesse d'un outil de deplacement au dixieme pres, et les sortir
## dans reglages.tres encombrerait un fichier qui parle du JEU.
const VOL_VITESSE := 18.0
const VOL_RAPIDE := 3.0


## Entre ou sort du mode « traverser les murs ».
##
## ON NE PASSE PAS PAR move_and_slide : glisser le long d'un mur EST la
## collision, donc la seule facon de ne pas le rencontrer est de poser la
## position soi-meme. La forme est desactivee en plus, sinon on pousse les corps
## qu'on traverse au lieu de les ignorer.
func traverser(actif: bool) -> void:
	if traverse == actif:
		return
	traverse = actif
	velocity = Vector3.ZERO
	var forme := $Collision as CollisionShape3D
	if forme != null:
		forme.disabled = actif
	if not actif:
		_se_reposer_au_sol()


# ON SORT DEBOUT, JAMAIS DANS UN MUR. Couper le mode a trente metres d'altitude
# ou au milieu d'un batiment laisse le personnage en chute libre ou coince, et
# c'est la seule facon dont cet outil pourrait faire perdre le temps qu'il est
# cense gagner. On cherche donc le sol sous soi et on s'y pose.
func _se_reposer_au_sol() -> void:
	var espace := get_world_3d().direct_space_state
	var requete := PhysicsRayQueryParameters3D.create(
			global_position + Vector3.UP * 2.0,
			global_position + Vector3.DOWN * 300.0)
	requete.exclude = [get_rid()]
	var touche := espace.intersect_ray(requete)
	if touche.is_empty():
		return
	var sol: Vector3 = touche["position"]
	global_position = sol + Vector3.UP * 0.05


# Le vol libre : avant-arriere sur l'orientation du personnage comme au sol,
# saut et accroupissement pour monter et descendre — ce sont deja les deux
# touches qui veulent dire haut et bas.
func _voler(delta: float) -> void:
	var pivot := Input.get_axis("gauche", "droite")
	if absf(pivot) > 0.01:
		rotation.y -= pivot * deg_to_rad(reglages.pivot_vitesse) * delta

	var devant := -global_transform.basis.z
	devant.y = 0.0
	var direction := devant.normalized() * Input.get_axis("frein", "gaz")
	if Input.is_action_pressed("saut"):
		direction += Vector3.UP
	if Input.is_action_pressed("accroupir"):
		direction += Vector3.DOWN

	velocity = Vector3.ZERO
	if direction.length_squared() < 0.001:
		return
	var vitesse := VOL_VITESSE
	if Input.is_action_pressed("sprint"):
		vitesse *= VOL_RAPIDE
	global_position += direction.normalized() * vitesse * delta


func _physics_process(delta: float) -> void:
	# AVANT TOUT LE RESTE, y compris la gravite : en vol, il n'y a ni sol, ni
	# geste, ni allure, et laisser tourner la suite ferait jouer une animation
	# de marche a quelqu'un qui traverse un mur a cinquante metres du sol.
	if traverse:
		_voler(delta)
		return

	if not is_on_floor():
		velocity.y -= _gravite * delta

	# UN GESTE S'ANNULE EN BOUGEANT.
	#
	# La verification est ici, avant tout le reste, et surtout AVANT `bloque` :
	# pendant un geste le joueur est bloque, donc plus aucune commande de
	# deplacement n'est lue, et une lecture de quatre secondes et demie serait
	# ininterruptible. On regarde donc l'intention, pas le mouvement.
	if _demarche != null and _demarche.geste_en_cours() != "":
		for touche in ["gaz", "frein", "gauche", "droite", "saut", "accroupir"]:
			if Input.is_action_pressed(touche):
				_demarche.annuler_le_geste()
				break

	# Gauche et droite PIVOTENT, elles ne deplacent pas. Avant et arriere
	# deplacent selon l'orientation du personnage, jamais selon la camera.
	#
	# C'est la commande des jeux de l'epoque, et elle regle definitivement le
	# probleme qui nous a poursuivis : tant que la direction se lisait sur la
	# camera, aller sur le cote la faisait tourner, ce qui faisait tourner la
	# direction. Ici, la camera n'entre plus dans le calcul du tout.
	var pivot := Input.get_axis("gauche", "droite")
	if not bloque and absf(pivot) > 0.01:
		rotation.y -= pivot * deg_to_rad(reglages.pivot_vitesse) * delta

	var avance := 0.0
	if not bloque:
		avance = Input.get_axis("frein", "gaz")

	var devant := -global_transform.basis.z
	devant.y = 0.0
	devant = devant.normalized()

	# L'ALLURE : marche dedans, trot dehors, course en maintenant Maj.
	#
	# Le trot est le DEFAUT. Traverser un quartier au pas serait interminable,
	# et un jeu ou l'on marche par defaut oblige a tenir une touche en
	# permanence — ce qui revient a faire du trot le defaut, en moins agreable.
	#
	# Dedans, on marche : courir dans un salon de sept metres n'a aucun sens et
	# se lit tout de suite comme un personnage mal reglé.
	# ACCROUPI tant que la touche est tenue. On peut se deplacer accroupi —
	# c'est meme tout l'interet — mais on ne court pas, et on ne saute pas.
	var accroupi := not bloque and Input.is_action_pressed("accroupir")
	if accroupi != _accroupi:
		_accroupi = accroupi
		_regler_la_capsule()

	var nom_allure := "trot"
	var allure := reglages.trot_vitesse
	var enjambee := reglages.trot_foulee
	if accroupi:
		nom_allure = "accroupi_marche"
		allure = reglages.accroupi_vitesse
		enjambee = reglages.accroupi_foulee
	elif interieur:
		nom_allure = "marche"
		allure = reglages.marche_vitesse
		enjambee = reglages.marche_foulee
	elif avance > 0.0 and Input.is_action_pressed("sprint"):
		# Seulement vers l'AVANT : personne ne sprinte a reculons, et une
		# marche arriere rapide se lit comme un bug.
		nom_allure = "course"
		allure = reglages.course_vitesse
		enjambee = reglages.course_foulee

	# Debout, il se REPOSE — il respire, il se tient d'aplomb, et de temps en
	# temps il remonte ses lunettes. Sans cette allure, un personnage qui ne
	# bouge pas reste plante sur une image de son cycle de marche : jambes
	# ecartees, bras en l'air, exactement comme s'il courait sur pause.
	#
	# La condition porte sur la COMMANDE autant que sur la vitesse : sinon on
	# repasse au repos a chaque changement de direction, quand la vitesse
	# traverse zero.
	var au_sol_avant := Vector2(velocity.x, velocity.z).length()
	if absf(avance) < 0.01 and au_sol_avant < reglages.repos_seuil \
			and _demarche != null:
		var arret := "accroupi" if accroupi else "repos"
		if _demarche.connait(arret):
			nom_allure = arret

	# EN L'AIR, plus rien de tout ca : on saute.
	#
	# ET ON ENTRE DANS LE CLIP AU DECOLLAGE quand on saute en courant. Le clip
	# livre commence par une flexion d'une demi-seconde ; la physique, elle,
	# lance le personnage a l'instant ou l'on appuie. Joue depuis le debut, il
	# s'accroupit en plein vol et donne l'impression de glisser au sol.
	# Sur place la flexion est juste, et on la garde.
	var depart_saut := 0.0
	if not is_on_floor() and _demarche != null and _demarche.connait("saut"):
		nom_allure = "saut"
		if Vector2(velocity.x, velocity.z).length() > reglages.saut_mouvement_seuil:
			depart_saut = reglages.saut_decollage

	_allure = nom_allure
	if _demarche != null:
		_demarche.allure(nom_allure, depart_saut)
		_demarche.foulee = enjambee

	# Reculer est plus lent qu'avancer : personne ne court a reculons.
	if avance < 0.0:
		allure *= reglages.marche_arriere

	# LE SAUT. On saute avec l'elan qu'on avait, pas depuis l'arret.
	#
	# C'est le point qui distingue un saut d'un ressort : la vitesse
	# horizontale n'est PAS remise a zero, et en l'air on ne la recalcule
	# presque plus. Sans ca, relacher la commande en plein vol arreterait le
	# personnage net, suspendu — et sauter en courant reviendrait a sauter sur
	# place, ce qui est precisement ce qu'on ne veut pas.
	if not bloque and Input.is_action_just_pressed("saut") \
			and is_on_floor() and not accroupi:
		velocity.y = reglages.saut_vitesse
		if _son() != null:
			_son().bruit_ici("pas_exterieur", global_position, 0.82)

	var voulu := devant * avance
	var cible := voulu * allure
	var k := clampf(reglages.marche_acceleration * delta, 0.0, 1.0)
	if not is_on_floor():
		# COMMANDE AU NEUTRE EN L'AIR : on ne touche a rien du tout.
		#
		# Ramener la vitesse vers zero, meme lentement, suffit a manger l'elan :
		# un saut dure trois quarts de seconde, et a un quart de l'acceleration
		# au sol il retombait a moins de la moitie de la distance attendue.
		# Personne ne freine en l'air.
		k = 0.0 if absf(avance) < 0.01 else k * reglages.saut_controle
	velocity.x = lerpf(velocity.x, cible.x, k)
	velocity.z = lerpf(velocity.z, cible.z, k)

	move_and_slide()
	# Pas de franchissement de bordure en l'air : la manoeuvre teleporte le
	# personnage vers le haut, et l'enchainer avec un saut le fait grimper les
	# murs par a-coups.
	if is_on_floor():
		_franchir(voulu, delta)

	# Vitesse SIGNEE : la silhouette inverse le cycle de marche quand on
	# recule, sinon il marche a l'endroit en se deplacant a l'envers.
	var au_sol := Vector2(velocity.x, velocity.z).length()
	var signee: float = au_sol * signf(avance) if absf(avance) > 0.01 else au_sol
	if _demarche != null:
		_demarche.avancer(signee, delta)
	else:
		_silhouette.avancer(signee, delta)


# Franchissement des bordures de trottoir.
#
# CharacterBody3D ne monte aucune marche tout seul : il glisse le long des
# obstacles verticaux, quelle que soit leur hauteur. Une bordure de 18 cm
# suffit donc a bloquer net, ce qui est intenable dans une ville.
#
# La methode est celle de tous les moteurs : lever, avancer, reposer. Si rien
# ne se trouve sous les pieds apres l'avancee, on annule — sinon on grimperait
# dans le vide.
func _franchir(voulu: Vector3, delta: float) -> void:
	if voulu.length_squared() < 0.01:
		return
	if not is_on_wall():
		_refus = "pas de mur"
		return
	# Contre une ARETE — le haut d'une bordure — la normale de contact est
	# diagonale, pas horizontale : mesure faite, n.y valait 0,40 sur un
	# trottoir de 18 cm. Une premiere version exigeait n.y proche de zero et
	# rejetait donc exactement le cas a traiter. On ne rejette plus que ce qui
	# est franchement un sol, et on raisonne sur la composante horizontale.
	var normale := get_wall_normal()
	if normale.y > 0.75:
		_refus = "c'est un sol (n.y=%.2f)" % normale.y
		return
	var horizontale := Vector3(normale.x, 0.0, normale.z)
	if horizontale.length() < 0.2:
		_refus = "normale sans composante horizontale"
		return
	horizontale = horizontale.normalized()
	if voulu.dot(-horizontale) < 0.2:
		_refus = "on ne pousse pas dedans (%.2f)" % voulu.dot(-horizontale)
		return

	var pas := reglages.hauteur_marche
	if pas <= 0.0:
		return
	var sauvegarde := global_position

	# Il faut avancer d'au moins un rayon de capsule au-dela de l'arete :
	# une avancee proportionnelle au pas de temps ne suffit jamais, on
	# retombe dans la bordure et on reste bloque.
	var portee := _rayon + 0.26
	global_position += Vector3.UP * (pas + 0.02)
	move_and_collide(voulu.normalized() * portee)
	var gagne := global_position.distance_to(sauvegarde)
	if move_and_collide(Vector3.DOWN * (pas + 0.12)) == null:
		global_position = sauvegarde
		_refus = "rien sous les pieds apres %.2f m" % gagne
	else:
		franchissements += 1
		_refus = ""


## Coupe les commandes sans arreter la physique : pendant un dialogue, le
## personnage doit ralentir et reposer ses pieds normalement. Suspendre le
## traitement le figerait en pleine foulee, une jambe en l'air.
var bloque: bool = false


# Repere fige au moment ou l'on commence a bouger, et garde tant que la
# touche est tenue.
#
# C'est ce qui casse la poursuite mutuelle. "Aller a gauche" veut dire a
# gauche DE CE QU'ON VOIT ; si on relisait la camera a chaque image pendant
# qu'elle se replace derriere le personnage, la direction tournerait avec
## Angle de lacet pour qu'un noeud regarde dans la direction donnee.
##
## L'avant d'un noeud Godot est -Z, d'ou les deux negations. Sans elles on
## obtient l'angle oppose. Le joueur ne s'en sert plus — il pivote a la
## commande — mais les pietons de la rue, eux, se tournent vers leur
## destination et en ont besoin.
static func lacet_vers(direction: Vector3) -> float:
	return atan2(-direction.x, -direction.z)


## Vitesse au sol en km/h, pour le HUD et les sons de pas.
func vitesse_kmh() -> float:
	return Vector2(velocity.x, velocity.z).length() * 3.6
