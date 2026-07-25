// Rue d'Albuquerque la nuit, rendue hors navigateur pour controle visuel.
//   node outils/rendu-rue-ps2.js .tmp/check.png
// Meme code que le rendu de docs/brief/index.html.
//
// Cible : PS2 (Vice City / San Andreas), PAS PS1. Concretement :
//   - correction de perspective  -> les textures ne glissent PAS
//   - precision sous-pixel       -> les sommets ne tremblent PAS
//   - filtrage bilineaire        -> textures floues, pas de texels carres
//   - couleur 24 bits            -> pas de tramage
//   - eclairage Gouraud          -> degrades doux sur les facades
const fs = require('fs');
const zlib = require('zlib');

const W = 512, H = 288;              // ordre de grandeur PS2
const FOCAL = 352;
const FOG = [36, 40, 54], FOG_A = 7, FOG_B = 58;
const GROUND = -1.5, WALK = -1.32, WALL = 7, KERB = 0.18;
const TEXEL = 104;                   // texels par unite UV (~128px cote PS2)

const D = new Uint8Array(W * H * 4);
const zbuf = new Float32Array(W * H).fill(1e9);

// pas de Math.round : la PS2 transformait les sommets en virgule flottante
const proj = (x, y, z) => [W / 2 + x * FOCAL / z, H / 2 - y * FOCAL / z, z];
const fog = z => { const t = (z - FOG_A) / (FOG_B - FOG_A); return t < 0 ? 0 : t > 1 ? 1 : t; };
const hash = (a, b) => { let h = ((a * 73856093) ^ (b * 19349663)) >>> 0; h = (h ^ (h >>> 13)) >>> 0; return (h % 1024) / 1024; };

// ---------------------------------------------------------------- ciel
for (let y = 0; y < H; y++) {
  const t = y / H;
  for (let x = 0; x < W; x++) {
    const dx = Math.abs(x - W / 2) / (W / 2);
    const glow = Math.max(0, 1 - dx * 1.5) * Math.max(0, t - 0.18) * 1.7;
    const haze = Math.max(0, 1 - Math.abs(y - H / 2) / 74) * 0.62;
    const r = 8 + t * 17 + glow * 46, g = 10 + t * 19 + glow * 30, b = 18 + t * 27 + glow * 15;
    const i = (y * W + x) * 4;
    D[i] = r + (FOG[0] - r) * haze; D[i + 1] = g + (FOG[1] - g) * haze;
    D[i + 2] = b + (FOG[2] - b) * haze; D[i + 3] = 255;
  }
}

// ------------------------------------------------------------ rasterisation
// Les poids barycentriques sont corriges par la profondeur avant d'etre
// transmis : c'est la correction de perspective que la PS1 n'avait pas.
function tri(a, b, cc, shade) {
  const minx = Math.max(0, Math.ceil(Math.min(a[0], b[0], cc[0]) - 0.5));
  const maxx = Math.min(W - 1, Math.floor(Math.max(a[0], b[0], cc[0]) + 0.5));
  const miny = Math.max(0, Math.ceil(Math.min(a[1], b[1], cc[1]) - 0.5));
  const maxy = Math.min(H - 1, Math.floor(Math.max(a[1], b[1], cc[1]) + 0.5));
  const den = (b[1] - cc[1]) * (a[0] - cc[0]) + (cc[0] - b[0]) * (a[1] - cc[1]);
  if (Math.abs(den) < 1e-9) return;
  const ia = 1 / a[2], ib = 1 / b[2], ic = 1 / cc[2];
  for (let y = miny; y <= maxy; y++) {
    for (let x = minx; x <= maxx; x++) {
      const w0 = ((b[1] - cc[1]) * (x - cc[0]) + (cc[0] - b[0]) * (y - cc[1])) / den;
      const w1 = ((cc[1] - a[1]) * (x - cc[0]) + (a[0] - cc[0]) * (y - cc[1])) / den;
      const w2 = 1 - w0 - w1;
      if (w0 < 0 || w1 < 0 || w2 < 0) continue;
      const iz = w0 * ia + w1 * ib + w2 * ic;
      const z = 1 / iz;
      const i = y * W + x;
      if (z >= zbuf[i]) continue;
      zbuf[i] = z;
      shade(i, w0 * ia / iz, w1 * ib / iz, w2 * ic / iz, z);
    }
  }
}

// filtrage bilineaire : quatre texels melanges. C'est ce qui donne
// le flou caracteristique de la PS2 au lieu de carres nets.
function bilinear(tex, u, v) {
  const fu = u * TEXEL - 0.5, fv = v * TEXEL - 0.5;
  const iu = Math.floor(fu), iv = Math.floor(fv);
  const du = fu - iu, dv = fv - iv;
  const s = (a, b) => tex((a + 0.5) / TEXEL, (b + 0.5) / TEXEL);
  const c00 = s(iu, iv), c10 = s(iu + 1, iv), c01 = s(iu, iv + 1), c11 = s(iu + 1, iv + 1);
  const a0 = 1 - du, a1 = du, b0 = 1 - dv, b1 = dv;
  return [
    (c00[0] * a0 + c10[0] * a1) * b0 + (c01[0] * a0 + c11[0] * a1) * b1,
    (c00[1] * a0 + c10[1] * a1) * b0 + (c01[1] * a0 + c11[1] * a1) * b1,
    (c00[2] * a0 + c10[2] * a1) * b0 + (c01[2] * a0 + c11[2] * a1) * b1];
}

// vl : lumiere par sommet (Gouraud). pl : lumiere par pixel, depuis les UV.
function texQuad(pts, UV, tex, vl, pl) {
  const p = pts.map(v => proj(v[0], v[1], v[2]));
  const run = (i0, i1, i2) => (idx, w0, w1, w2, z) => {
    const u = UV[i0][0] * w0 + UV[i1][0] * w1 + UV[i2][0] * w2;
    const v = UV[i0][1] * w0 + UV[i1][1] * w1 + UV[i2][1] * w2;
    const c = tex ? bilinear(tex, u, v) : COLTMP;
    let L = 1;
    if (vl) L = vl[i0] * w0 + vl[i1] * w1 + vl[i2] * w2;
    if (pl) { const e = pl(u, v); L = e[0]; c[0] += e[1]; c[1] += e[2]; c[2] += e[3]; }
    const f = fog(z);
    const r = c[0] * L, g = c[1] * L, b = c[2] * L;
    D[idx * 4] = r + (FOG[0] - r) * f;
    D[idx * 4 + 1] = g + (FOG[1] - g) * f;
    D[idx * 4 + 2] = b + (FOG[2] - b) * f;
  };
  tri(p[0], p[1], p[2], run(0, 1, 2));
  tri(p[0], p[2], p[3], run(0, 2, 3));
}
let COLTMP = [0, 0, 0];
const flat = (pts, col, vl) => { COLTMP = col.slice(); texQuad(pts, [[0, 0], [1, 0], [1, 1], [0, 1]], null, vl); };

// ------------------------------------------------------------ eclairage
const LAMPS = [[-4.7, 10], [4.7, 19], [-4.7, 28], [4.7, 38], [-4.7, 49], [4.7, 62]];
function lampAt(wx, wz) {
  let s = 0;
  for (const L of LAMPS) { const dx = wx - L[0], dz = wz - L[1]; s += 5.5 / (1 + (dx * dx + dz * dz) * 0.62); }
  return s > 2 ? 2 : s;
}

// ------------------------------------------------------------- textures
function asphaltTex(u, v) {
  const vv = v - Math.floor(v);
  if (u > 0.476 && u < 0.524 && vv < 0.44) {
    const w = hash((u * 150) | 0, (v * 150) | 0);
    return [172 + w * 22, 158 + w * 20, 104 + w * 16];
  }
  const n = hash((u * 130) | 0, (v * 130) | 0);
  const p = hash(((u * 17) | 0) + 31, ((v * 17) | 0) + 17);
  const g = 41 + n * 12 - p * 8;
  return [g, g + 1, g + 6];
}

// Un module = une travee de fenetre. Les fenetres sont dans la texture.
function facadeTex(u, v, base, seed) {
  const cu = Math.floor(u), cv = Math.floor(v);
  const uu = u - cu, vv = v - cv;
  const n = hash(((u * 90) | 0) + seed, (v * 90) | 0);
  if (vv < 0.10) { const g = 0.58 + n * 0.14; return [base[0] * g, base[1] * g, base[2] * g]; }
  if (uu > 0.19 && uu < 0.81 && vv > 0.26 && vv < 0.82) {
    if (uu < 0.235 || uu > 0.765 || vv < 0.30 || vv > 0.785)
      return [base[0] * 1.24, base[1] * 1.22, base[2] * 1.18];
    const k = hash(cu * 3 + seed, cv * 5 + 11);
    const j = 0.9 + hash((u * 70) | 0, (v * 70) | 0) * 0.22;
    if (k > 0.80) return [94 * j, 200 * j, 126 * j];
    if (k > 0.46) return [208 * j, 156 * j, 78 * j];
    return [24 * j, 27 * j, 37 * j];
  }
  const g = 0.86 + n * 0.26;
  return [base[0] * g, base[1] * g, base[2] * g];
}

function walkTex(u, v) {
  const uu = u - Math.floor(u), vv = v - Math.floor(v);
  const n = hash((u * 110) | 0, (v * 110) | 0);
  const joint = (uu < 0.05 || vv < 0.05) ? 0.74 : 1;
  const g = (64 + n * 11) * joint;
  return [g, g, g + 7];
}

// ------------------------------------------------------------- la scene
// Plus besoin de subdiviser contre la deformation : la perspective est
// corrigee. On subdivise seulement pour l'eclairage par sommet.
const SEG = [2.2, 4, 6.5, 10, 14.5, 20, 27, 36, 47, 62, 80];
const TILE = 0.20;

for (let i = 0; i < SEG.length - 1; i++) {
  const z0 = SEG[i], z1 = SEG[i + 1];
  texQuad([[-4, GROUND, z0], [4, GROUND, z0], [4, GROUND, z1], [-4, GROUND, z1]],
    [[0, z0 * TILE], [1, z0 * TILE], [1, z1 * TILE], [0, z1 * TILE]],
    asphaltTex, null,
    (u, v) => { const L = lampAt(u * 8 - 4, v / TILE); return [0.54 + L * 0.30, L * 14, L * 9, L * 2]; });

  for (const sg of [-1, 1]) {
    const xa = 4 * sg, xb = WALL * sg;
    const lv = [[xa, z0], [xb, z0], [xb, z1], [xa, z1]].map(q => 0.42 + lampAt(q[0], q[1]) * 0.34);
    texQuad([[xa, WALK, z0], [xb, WALK, z0], [xb, WALK, z1], [xa, WALK, z1]],
      [[0, z0 * 0.55], [1.5, z0 * 0.55], [1.5, z1 * 0.55], [0, z1 * 0.55]], walkTex, lv);
    // bordure : une vraie face verticale, pas une ligne peinte
    flat([[xa, GROUND, z0], [xa, WALK, z0], [xa, WALK, z1], [xa, GROUND, z1]],
      [104, 102, 98], [lv[0] * 1.1, lv[0] * 1.1, lv[3] * 1.1, lv[3] * 1.1]);
  }
}

const BZ = [6, 13.5, 22, 31, 42, 56, 72];
const BCOL = [[96, 80, 68], [72, 76, 92], [106, 86, 70], [64, 70, 84], [98, 84, 72]];
const HT = [5.8, 7.6, 4.6, 8.8, 6.4, 7.1];
const MU = 3.4, MV = 2.9;

for (let s = 0; s < 2; s++) {
  const sg = s === 0 ? -1 : 1;
  for (let i = 0; i < BZ.length - 1; i++) {
    const z0 = BZ[i], z1 = BZ[i + 1], h = HT[(i + s * 2) % 6];
    const base = BCOL[(i + s * 3) % 5], wx = WALL * sg, seed = i * 13 + s * 41;
    const nu = (z1 - z0) / MU, nv = (h - WALK) / MV;
    // Gouraud : la lumiere est evaluee aux quatre coins et interpolee,
    // d'ou le degrade doux typique des jeux PS2 en eclairage par sommet
    const g = (zz, yy) => 0.34 + lampAt(wx, zz) * 0.4 * Math.max(0.25, 1 - (yy - WALK) / 9);
    texQuad([[wx, WALK, z0], [wx, WALK, z1], [wx, h, z1], [wx, h, z0]],
      [[0, 0], [nu, 0], [nu, nv], [0, nv]],
      (u, v) => facadeTex(u, v, base, seed),
      [g(z0, WALK), g(z1, WALK), g(z1, h), g(z0, h)]);
    const du = 6 / MU, gf = 0.3;
    texQuad([[wx, WALK, z0], [13 * sg, WALK, z0], [13 * sg, h, z0], [wx, h, z0]],
      [[0, 0], [du, 0], [du, nv], [0, nv]],
      (u, v) => facadeTex(u, v, base, seed + 7), [gf, gf * 0.8, gf * 0.7, gf * 0.9]);
    flat([[wx, h, z0], [13 * sg, h, z0], [13 * sg, h, z1], [wx, h, z1]],
      [base[0] * 0.26, base[1] * 0.26, base[2] * 0.3]);
    // corniche
    flat([[wx, h, z0], [wx, h + 0.22, z0], [wx, h + 0.22, z1], [wx, h, z1]],
      [base[0] * 0.7, base[1] * 0.7, base[2] * 0.72]);
  }
}

for (const [lx, lz] of LAMPS) {
  const inw = lx < 0 ? -1 : 1, hx = lx - 0.6 * inw;
  flat([[lx - 0.06, GROUND, lz], [lx + 0.06, GROUND, lz], [lx + 0.06, 2.6, lz], [lx - 0.06, 2.6, lz]], [30, 30, 37]);
  flat([[hx, 2.6, lz], [lx + 0.06 * inw, 2.6, lz], [lx + 0.06 * inw, 2.72, lz], [hx, 2.72, lz]], [34, 34, 41]);
  flat([[hx - 0.28, 2.36, lz], [hx + 0.28, 2.36, lz], [hx + 0.28, 2.6, lz], [hx - 0.28, 2.6, lz]], [250, 212, 148]);
}

// Pas de quantification ni de tramage : la PS2 sortait en 24 bits.

// ------------------------------------------------------------- sortie PNG
const S = 2, OW = W * S, OH = H * S;
const raw = Buffer.alloc(OH * (1 + OW * 3));
for (let y = 0; y < OH; y++) {
  const off = y * (1 + OW * 3), sy = (y / S) | 0;
  raw[off] = 0;
  for (let x = 0; x < OW; x++) {
    const si = (sy * W + ((x / S) | 0)) * 4, di = off + 1 + x * 3;
    raw[di] = D[si]; raw[di + 1] = D[si + 1]; raw[di + 2] = D[si + 2];
  }
}
const crcT = [];
for (let n = 0; n < 256; n++) { let c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; crcT[n] = c >>> 0; }
const crc = b => { let c = 0xffffffff; for (const x of b) c = crcT[(c ^ x) & 0xff] ^ (c >>> 8); return (c ^ 0xffffffff) >>> 0; };
const chunk = (type, data) => {
  const len = Buffer.alloc(4); len.writeUInt32BE(data.length);
  const td = Buffer.concat([Buffer.from(type, 'ascii'), data]);
  const cb = Buffer.alloc(4); cb.writeUInt32BE(crc(td));
  return Buffer.concat([len, td, cb]);
};
const ihdr = Buffer.alloc(13);
ihdr.writeUInt32BE(OW, 0); ihdr.writeUInt32BE(OH, 4);
ihdr[8] = 8; ihdr[9] = 2;
fs.writeFileSync(process.argv[2] || '.tmp/check.png', Buffer.concat([
  Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
  chunk('IHDR', ihdr), chunk('IDAT', zlib.deflateSync(raw)), chunk('IEND', Buffer.alloc(0))]));
console.log(`${OW}x${OH} ecrit (source ${W}x${H})`);
