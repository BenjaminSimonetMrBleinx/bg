// La vapeur, la fumee, la poussiere : tout ce qui flotte et qu'on traverse.
//
// CE QU'IL CORRIGE, ET QUI SE VOYAIT.
//
// La vapeur du labo etait un QuadMesh avec un materiau additif : un carre uni.
// Deux defauts, tous les deux visibles depuis que le rendu est monte a 960x720.
//
//   1. Le quad se COUPE NET la ou il traverse la paillasse. Une arete droite au
//      milieu d'un nuage, et l'illusion tombe. C'est le defaut principal, et
//      c'est le fondu de contact qui le regle.
//   2. Le sprite n'a aucune forme. Une bouffee de vapeur n'est pas un carre.
//
// Aucune texture : la forme est calculee. C'est la meme logique que
// ciel_nuit.gdshader, qui fabrique ses etoiles plutot que de les peindre — et
// la meme fonction de hachage, pour n'en avoir qu'une dans le projet.
//
// depth_draw_never : une particule ne doit jamais cacher celle qui est derriere.
// cull_disabled : on la traverse, donc on la voit des deux cotes.
shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 couleur : source_color = vec4(0.86, 0.90, 0.94, 1.0);

// Sur combien de metres la particule s'efface au contact d'une surface. C'est
// CE nombre qui supprime l'arete : en dessous, le quad recoupe la paillasse.
uniform float douceur_contact : hint_range(0.0, 1.0) = 0.18;

uniform float opacite : hint_range(0.0, 4.0) = 1.0;

// Combien la bouffee est dechiquetee. A 0 c'est un disque propre, ce qui est
// bon pour de la vapeur de becher ; monte, c'est de la fumee.
uniform float grain : hint_range(0.0, 1.0) = 0.45;

// La taille du motif de bruit. Grand = de grosses volutes, petit = du sable.
uniform float grain_echelle : hint_range(1.0, 32.0) = 6.0;

uniform sampler2D profondeur : hint_depth_texture, filter_linear_mipmap;


float hache(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.71, 0.113, 0.419));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}


// Un bruit continu, interpole entre les coins d'une grille. Le hachage seul
// donne du poivre et sel ; il faut le lisser pour obtenir des volutes.
float bruit(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(hache(i + vec3(0.0, 0.0, 0.0)), hache(i + vec3(1.0, 0.0, 0.0)), f.x);
	float b = mix(hache(i + vec3(0.0, 1.0, 0.0)), hache(i + vec3(1.0, 1.0, 0.0)), f.x);
	float c = mix(hache(i + vec3(0.0, 0.0, 1.0)), hache(i + vec3(1.0, 0.0, 1.0)), f.x);
	float d = mix(hache(i + vec3(0.0, 1.0, 1.0)), hache(i + vec3(1.0, 1.0, 1.0)), f.x);
	return mix(mix(a, b, f.y), mix(c, d, f.y), f.z);
}


void fragment() {
	// LA FORME. Un disque aux bords fondus plutot qu'un carre : c'est ce qui
	// fait la difference entre « une bouffee » et « un sprite ».
	vec2 c = UV - vec2(0.5);
	float a = 1.0 - smoothstep(0.18, 0.5, length(c));

	// LE GRAIN. INSTANCE_CUSTOM.x differe d'une particule a l'autre : sans lui
	// les cent bouffees d'un jet portent exactement le meme motif, et le jet
	// se lit comme une repetition au lieu d'un nuage.
	if (grain > 0.001) {
		float n = bruit(vec3(UV * grain_echelle, INSTANCE_CUSTOM.x * 37.0));
		a *= mix(1.0, n, grain);
	}

	// LE CYCLE DE VIE. GPUParticles3D ecrit l'age normalise dans
	// INSTANCE_CUSTOM.y. On monte vite et on redescend lentement : une vapeur
	// apparait d'un coup au bec du ballon et se dissipe en montant.
	float age = INSTANCE_CUSTOM.y;
	a *= smoothstep(0.0, 0.12, age) * (1.0 - smoothstep(0.35, 1.0, age));

	// LE FONDU DE CONTACT, la vraie raison d'etre de ce shader.
	//
	// On lit la profondeur de ce qui est DEJA dessine a cet endroit de l'ecran
	// et on la compare a la notre. Quand les deux se rapprochent — c'est-a-dire
	// quand le quad entre dans la paillasse — l'opacite tombe, et l'arete
	// disparait au lieu de couper le nuage en deux.
	//
	// La profondeur du tampon est non lineaire : il faut la reprojeter pour
	// que « dix-huit centimetres » veuille dire dix-huit centimetres partout,
	// et pas seulement au ras de la camera.
	if (douceur_contact > 0.001) {
		float brut = texture(profondeur, SCREEN_UV).r;
		vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, brut);
		vec4 vue = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
		float derriere = -(vue.xyz / vue.w).z;
		float ici = -VERTEX.z;
		a *= clamp((derriere - ici) / douceur_contact, 0.0, 1.0);
	}

	ALBEDO = couleur.rgb;
	ALPHA = clamp(a * couleur.a * opacite, 0.0, 1.0);
}
