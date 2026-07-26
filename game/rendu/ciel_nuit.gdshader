// Le ciel : degrade, etoiles, et lune.
//
// POURQUOI UN SHADER PLUTOT QU'UNE COULEUR.
//
// Le fond etait un aplat uni. De jour ca passe — un ciel d'Albuquerque a midi
// EST un aplat bleu. De nuit c'etait un mur noir : rien au-dessus des toits,
// aucun repere quand on leve la camera, et surtout aucune source de lumiere
// visible pour justifier qu'on y voie quoi que ce soit.
//
// Les etoiles sont CALCULEES, pas texturees. Une voute etoilee en texture
// demanderait une image de plusieurs milliers de pixels pour que les points ne
// bavent pas, et se repeterait visiblement. Ici chaque direction du ciel donne
// une valeur de bruit, et on allume au-dela d'un seuil : c'est deux lignes, ca
// ne pese rien, et la densite se regle.
//
// Tout s'efface avec `nuit` : a zero le shader rend exactement le degrade de
// jour, donc il remplace l'aplat a toute heure sans cas particulier.
shader_type sky;

// 0 en plein jour, 1 en pleine nuit. C'est Reglages.nuit_part(), transmis tel
// quel : une seule source pour le ciel, le brouillard, les lampadaires et les
// fenetres, sinon ils divergent d'une image et ca se voit.
uniform float nuit : hint_range(0.0, 1.0) = 1.0;

uniform vec3 couleur_zenith : source_color = vec3(0.03, 0.04, 0.07);
uniform vec3 couleur_horizon : source_color = vec3(0.14, 0.16, 0.21);

// La lune. Direction NORMALISEE, en coordonnees du monde.
uniform vec3 lune_direction = vec3(0.35, 0.62, -0.70);
uniform vec3 lune_couleur : source_color = vec3(0.86, 0.89, 1.0);
uniform float lune_taille : hint_range(0.005, 0.12) = 0.035;

// Densite des etoiles. Plus le seuil est haut, moins il y en a.
uniform float etoiles_seuil : hint_range(0.90, 0.9995) = 0.9955;
uniform float etoiles_eclat : hint_range(0.0, 4.0) = 1.6;

// Bruit de valeur sur une direction. Le meme principe que hache() dans
// outils/gen_textures.py : pas de hasard, une fonction de la position, donc le
// ciel ne scintille pas quand la camera tourne.
float hache(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.71, 0.113, 0.419));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

void sky() {
	vec3 dir = normalize(EYEDIR);

	// Le degrade : le zenith est plus sombre que l'horizon, de jour comme de
	// nuit. C'est ce qui donne le volume du ciel ; un aplat n'en a aucun.
	float hauteur = clamp(dir.y, 0.0, 1.0);
	vec3 fond = mix(couleur_horizon, couleur_zenith, pow(hauteur, 0.55));

	// LES ETOILES. On quantifie la direction avant de la hacher : sans cette
	// grille, chaque pixel tire sa propre valeur et le ciel devient du grain
	// plutot qu'un semis de points.
	vec3 grille = floor(dir * 320.0);
	float bruit = hache(grille);
	float etoile = smoothstep(etoiles_seuil, 1.0, bruit);
	// Elles ne descendent pas jusqu'au sol : au ras de l'horizon il y a la
	// ville et la brume, et des points lumineux entre les toits se lisent
	// comme des pixels morts.
	etoile *= smoothstep(0.02, 0.28, dir.y);
	// Chacune a son eclat, tire du meme bruit : un semis de points identiques
	// se lit comme une trame.
	etoile *= 0.45 + 0.55 * hache(grille + 11.0);

	// LA LUNE, un disque avec un halo court. Le halo compte autant que le
	// disque : sans lui elle se decoupe comme un autocollant.
	float d = dot(dir, normalize(lune_direction));
	float disque = smoothstep(1.0 - lune_taille, 1.0 - lune_taille * 0.55, d);
	float halo = smoothstep(1.0 - lune_taille * 6.0, 1.0, d) * 0.22;

	vec3 nuit_ciel = fond
			+ vec3(etoile * etoiles_eclat)
			+ lune_couleur * (disque + halo);

	COLOR = mix(fond, nuit_ciel, nuit);
}
