# Un passage : une zone qu'on franchit pour arriver ailleurs.
#
# Il ne teleporte rien lui-meme. Il constate qu'on est dedans, et le dit au
# controleur — qui seul sait s'il faut emmener la voiture, ou refuser parce
# qu'on est a pied. Un declencheur qui deplacerait le joueur devrait connaitre
# l'etat du jeu, et cet etat vit deja ailleurs.
#
# On SCRUTE plutot que d'ecouter body_entered.
#
# La raison est mesurable : le joueur au volant est desactive — process_mode a
# DISABLED, capsule retiree du monde physique — et ce n'est donc pas lui qui
# entre dans la zone, c'est le vehicule. Un signal branche sur le mauvais corps
# ne se declenche jamais, et rien ne le signale. En demandant a la zone ce
# qu'elle contient, on lit la verite du moment quel que soit l'etat.
class_name Passage
extends Area3D

## Ou l'on ressort, en coordonnees du monde.
@export var destination: Vector3 = Vector3.ZERO

## Dans quelle direction on regarde en arrivant, en degres.
@export var cap_degres: float = 0.0

## Faut-il un vehicule ? Le passage vers le desert l'exige ; celui du retour
## non, sinon quelqu'un qui descend de voiture reste coince la-bas.
@export var exige_vehicule: bool = true

## Ce qu'on affiche a pied quand le vehicule est exige.
@export var refus: String = "Vous devez etre en voiture pour vous rendre ici"

## Le nom du lieu ou l'on arrive, annonce a la mission. Vide = on ne dit rien,
## ce qui est le cas des passages de retour : revenir en ville ne fait avancer
## aucun objectif.
@export var zone: String = ""

## Ce passage n'existe qu'a partir de cette etape de la mission. C'est ce qui
## empeche d'aller chez Tuco avant d'avoir la marchandise — et le refus
## ci-dessous explique pourquoi, au lieu de laisser croire a un decor ferme.
@export var etape_minimale: String = ""
@export var refus_etape: String = ""


func cap() -> float:
	return deg_to_rad(cap_degres)


## Ce corps est-il dans la zone ? On passe le corps plutot que de chercher un
## type : le controleur sait qui conduit, le passage n'a pas a le deviner.
func contient(corps: Node3D) -> bool:
	if corps == null:
		return false
	for c in get_overlapping_bodies():
		if c == corps:
			return true
	return false
