// Le contenu des becher, des ballons et des bidons.
//
// CE QUI FAIT QU'UN CYLINDRE COLORE CESSE D'ETRE UN CYLINDRE COLORE, et ce
// n'est PAS la transparence — c'est le menisque et le bord.
//
// La verrerie du labo est aujourd'hui une rangee de cubes blancs et verts. En
// leur donnant ce materiau, trois choses arrivent d'un coup :
//
//   1. LE BORD S'ECLAIRE. Un liquide vu de biais montre plus d'epaisseur qu'un
//      liquide vu de face : c'est le Fresnel, et c'est ce qui donne le volume.
//   2. LE HAUT S'ASSOMBRIT. La surface d'un liquide dans un tube remonte le
//      long de la paroi — le menisque. C'est un detail d'un centimetre, et
//      c'est celui que l'oeil lit comme « il y a du liquide dedans ».
//   3. CE QU'IL Y A DERRIERE SE DEFORME. Une refraction courte, une seule
//      lecture d'ecran. A 960x720 elle ne coute rien.
//
// Pas de simulation, pas de surface animee : un liquide au repos dans un becher
// ne bouge pas, et le faire onduler serait le seul detail anime d'une piece
// immobile.
shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_opaque;

uniform vec4 couleur : source_color = vec4(0.32, 0.62, 0.28, 0.86);

// Combien le liquide est trouble. A 0 il est clair comme de l'eau, a 1 il est
// opaque comme du solvant use.
uniform float trouble : hint_range(0.0, 1.0) = 0.35;

// De combien ce qu'il y a derriere se decale, en fraction d'ecran. Tres petit :
// au-dela, le becher devient une loupe et on voit le decor glisser.
uniform float refraction : hint_range(0.0, 0.1) = 0.018;

// La hauteur du menisque, en fraction de la hauteur du maillage.
uniform float menisque : hint_range(0.0, 0.4) = 0.08;

// L'eclat du bord. C'est lui qui dit l'epaisseur.
uniform float bord : hint_range(0.0, 3.0) = 0.9;

uniform sampler2D ecran : hint_screen_texture, filter_linear_mipmap;

varying float hauteur_locale;


void vertex() {
	// La position verticale dans le maillage, ramenee entre 0 et 1. On s'en
	// sert pour le menisque : il n'existe qu'en haut.
	hauteur_locale = clamp(VERTEX.y * 0.5 + 0.5, 0.0, 1.0);
}


void fragment() {
	// LE FRESNEL. De face on regarde a travers, de biais on regarde le long —
	// donc a travers plus de matiere. C'est ce qui allume les bords.
	float face = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float fresnel = pow(1.0 - face, 3.0);

	// LA REFRACTION. Une seule lecture, decalee par la normale. On ne cherche
	// pas la physique : on cherche que le fond ne soit pas RIGOUREUSEMENT
	// aligne avec ce qui l'entoure, parce que c'est ca qui trahit une vitre
	// peinte.
	vec2 decale = NORMAL.xy * refraction * (1.0 - face);
	vec3 derriere = texture(ecran, SCREEN_UV + decale).rgb;

	// LE MENISQUE. La derniere tranche du haut s'assombrit : le liquide y
	// remonte contre la paroi et s'y epaissit.
	float creux = 1.0 - smoothstep(1.0 - menisque, 1.0, hauteur_locale) * 0.55;

	vec3 teinte = couleur.rgb * creux;
	// Le trouble decide de ce qu'on voit : sa propre couleur, ou le decor a
	// travers. Un solvant use ne laisse rien passer, de l'eau presque tout.
	ALBEDO = mix(derriere * couleur.rgb, teinte, trouble);
	ALBEDO += fresnel * couleur.rgb * bord;

	ALPHA = clamp(couleur.a + fresnel * 0.35, 0.0, 1.0);
	// Un liquide n'est pas mat : il rend la lumiere du plafonnier, et c'est ce
	// reflet qui le pose dans la piece.
	ROUGHNESS = mix(0.08, 0.35, trouble);
	SPECULAR = 0.6;
}
