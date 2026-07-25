// Rue d'Albuquerque la nuit, rendue hors navigateur pour controle visuel.
//   node outils/rendu-rue-ps1.js .tmp/check.png
// Meme code que le rendu de docs/brief/index.html.
//
// Artefacts d'epoque volontaires :
//   - sommets arrondis au pixel (vertex snapping)
//   - UV interpoles sans correction de perspective (affine texture mapping)
//   - couleurs quantifiees en 15 bits, comme la sortie video PS1
const fs = require('fs');
const zlib = require('zlib');

const W = 320, H = 180;              // resolution horizontale d'epoque
const FOCAL = 220;
const FOG = [34, 38, 50], FOG_A = 6, FOG_B = 54;
const GROUND = -1.5, WALK = -1.32, WALL = 7;

const D = new Uint8Array(W * H * 4);
const zbuf = new Float32Array(W * H).fill(1e9);

const proj = (x, y, z) => [
  Math.round(W / 2 + x * FOCAL / z),   // <- le snapping est ici
  Math.round(H / 2 - y * FOCAL / z), z];
const fog = z => { const t = (z - FOG_A) / (FOG_B - FOG_A); return t < 0 ? 0 : t > 1 ? 1 : t; };
const put = (x, y, r, g, b) => { const i = (y * W + x) * 4; D[i] = r; D[i + 1] = g; D[i + 2] = b; D[i + 3] = 255; };
const hash = (a, b) => { let h = ((a * 73856093) ^ (b * 19349663)) >>> 0; h = (h ^ (h >>> 13)) >>> 0; return (h % 1024) / 1024; };

// ---------------------------------------------------------------- ciel
for (let y = 0; y < H; y++) {
  const t = y / H;
  for (let x = 0; x < W; x++) {
    const dx = Math.abs(x - W / 2) / (W / 2);
    const glow = Math.max(0, 1 - dx * 1.5) * Math.max(0, t - 0.18) * 1.7;
    const haze = Math.max(0, 1 - Math.abs(y - H / 2) / 46) * 0.62;
    const r = 7 + t * 16 + glow * 44, g = 9 + t * 18 + glow * 28, b = 16 + t * 25 + glow * 14;
    put(x, y, r + (FOG[0] - r) * haze, g + (FOG[1] - g) * haze, b + (FOG[2] - b) * haze);
  }
}

// ------------------------------------------------------------ rasterisation
function tri(a, b, cc, shade) {
  const minx = Math.max(0, Math.floor(Math.min(a[0], b[0], cc[0])));
  const maxx = Math.min(W - 1, Math.ceil(Math.max(a[0], b[0], cc[0])));
  const miny = Math.max(0, Math.floor(Math.min(a[1], b[1], cc[1])));
  const maxy = Math.min(H - 1, Math.ceil(Math.max(a[1], b[1], cc[1])));
  const den = (b[1] - cc[1]) * (a[0] - cc[0]) + (cc[0] - b[0]) * (a[1] - cc[1]);
  if (Math.abs(den) < 1e-9) return;
  for (let y = miny; y <= maxy; y++) {
    for (let x = minx; x <= maxx; x++) {
      const w0 = ((b[1] - cc[1]) * (x - cc[0]) + (cc[0] - b[0]) * (y - cc[1])) / den;
      const w1 = ((cc[1] - a[1]) * (x - cc[0]) + (a[0] - cc[0]) * (y - cc[1])) / den;
      const w2 = 1 - w0 - w1;
      if (w0 < -0.003 || w1 < -0.003 || w2 < -0.003) continue;
      const z = a[2] * w0 + b[2] * w1 + cc[2] * w2;
      const i = y * W + x;
      if (z >= zbuf[i]) continue;
      zbuf[i] = z;
      shade(x, y, w0, w1, w2, z);
    }
  }
}

// Quad texture. Les UV sont interpoles lineairement en espace ecran :
// c'est precisement l'absence de correction de perspective de la PS1.
function texQuad(pts, UV, tex, light) {
  const p = pts.map(v => proj(v[0], v[1], v[2]));
  const run = (i0, i1, i2) => (x, y, w0, w1, w2, z) => {
    const u = UV[i0][0] * w0 + UV[i1][0] * w1 + UV[i2][0] * w2;
    const v = UV[i0][1] * w0 + UV[i1][1] * w1 + UV[i2][1] * w2;
    const c = tex(u, v);
    const L = light ? light(u, v) : 1;
    const f = fog(z);
    const r = c[0] * L, g = c[1] * L, b = c[2] * L;
    put(x, y, r + (FOG[0] - r) * f, g + (FOG[1] - g) * f, b + (FOG[2] - b) * f);
  };
  tri(p[0], p[1], p[2], run(0, 1, 2));
  tri(p[0], p[2], p[3], run(0, 2, 3));
}
const flat = (pts, col) => texQuad(pts, [[0, 0], [1, 0], [1, 1], [0, 1]], () => col);

// ------------------------------------------------------------ eclairage
const LAMPS = [[-4.7, 10], [4.7, 19], [-4.7, 28], [4.7, 38], [-4.7, 49]];
function lampAt(wx, wz) {
  let s = 0;
  for (const L of LAMPS) { const dx = wx - L[0], dz = wz - L[1]; s += 7 / (1 + (dx * dx + dz * dz) * 0.38); }
  return s > 1.8 ? 1.8 : s;
}

// ------------------------------------------------------------- textures
function asphaltTex(u, v) {
  const vv = v - Math.floor(v);
  if (u > 0.474 && u < 0.526 && vv < 0.44) {                 // ligne axiale
    const w = hash(Math.floor(u * 90), Math.floor(v * 90));
    return [168 + w * 24, 154 + w * 22, 100 + w * 18];
  }
  if (u < 0.045 || u > 0.955) return [96, 94, 90];           // rives
  const n = hash(Math.floor(u * 46), Math.floor(v * 46));
  const p = hash(Math.floor(u * 9) + 31, Math.floor(v * 9) + 17);   // taches
  const g = 34 + n * 15 - p * 7;
  return [g, g + 1, g + 6];
}

// Facade : un module = une travee de fenetre. Les fenetres sont DANS la
// texture, pas en geometrie — c'est ce qui donne le rendu PS1.
function facadeTex(u, v, base, seed) {
  const cu = Math.floor(u), cv = Math.floor(v);
  const uu = u - cu, vv = v - cv;
  const n = hash(Math.floor(u * 26) + seed, Math.floor(v * 26));
  if (vv < 0.11) {                                            // bandeau d'etage
    const g = 0.60 + n * 0.16;
    return [base[0] * g, base[1] * g, base[2] * g];
  }
  if (uu > 0.19 && uu < 0.81 && vv > 0.26 && vv < 0.82) {
    if (uu < 0.235 || uu > 0.765 || vv < 0.30 || vv > 0.785)  // encadrement
      return [base[0] * 1.22, base[1] * 1.2, base[2] * 1.16];
    const k = hash(cu * 3 + seed, cv * 5 + 11);
    const j = 0.86 + hash(Math.floor(u * 34), Math.floor(v * 34)) * 0.3;
    if (k > 0.80) return [92 * j, 196 * j, 122 * j];          // neon vert
    if (k > 0.46) return [204 * j, 152 * j, 74 * j];          // ampoule chaude
    return [23 * j, 26 * j, 35 * j];                          // vitre eteinte
  }
  const g = 0.84 + n * 0.30;                                  // crepi bruite
  return [base[0] * g, base[1] * g, base[2] * g];
}

function walkTex(u, v) {
  const uu = u - Math.floor(u), vv = v - Math.floor(v);
  const n = hash(Math.floor(u * 30), Math.floor(v * 30));
  const joint = (uu < 0.06 || vv < 0.06) ? 0.72 : 1;
  const g = (58 + n * 14) * joint;
  return [g, g, g + 7];
}

// ------------------------------------------------------------- la scene
// Segments courts : plus un quad couvre de profondeur, plus la deformation
// affine est franche. C'est un curseur, pas un effet binaire.
const SEG = [2.2, 3.2, 4.6, 6.4, 8.8, 12, 16.5, 23, 32, 44, 60];
const TILE = 0.20;
for (let i = 0; i < SEG.length - 1; i++) {
  const z0 = SEG[i], z1 = SEG[i + 1];
  texQuad(
    [[-4, GROUND, z0], [4, GROUND, z0], [4, GROUND, z1], [-4, GROUND, z1]],
    [[0, z0 * TILE], [1, z0 * TILE], [1, z1 * TILE], [0, z1 * TILE]],
    (u, v) => {                                    // flaques de lumiere chaudes
      const c = asphaltTex(u, v), L = lampAt(u * 8 - 4, v / TILE);
      const m = 0.5 + L * 0.30;
      return [c[0] * m + L * 26, c[1] * m + L * 17, c[2] * m + L * 5];
    });
  for (const sg of [-1, 1]) {
    const xa = 4 * sg, xb = WALL * sg;
    texQuad(
      [[xa, WALK, z0], [xb, WALK, z0], [xb, WALK, z1], [xa, WALK, z1]],
      [[0, z0 * 0.6], [1.6, z0 * 0.6], [1.6, z1 * 0.6], [0, z1 * 0.6]],
      walkTex,
      (u, v) => 0.42 + lampAt(xa + (xb - xa) * (u / 1.6), v / 0.6) * 0.4);
  }
}

const BZ = [6, 13.5, 22, 31, 42, 56];
const BCOL = [[92, 76, 64], [68, 72, 88], [102, 82, 66], [60, 66, 80], [94, 80, 68]];
const HT = [5.8, 7.6, 4.6, 8.8, 6.4];
const MU = 3.4, MV = 2.9;                        // taille d'un module de facade

for (let s = 0; s < 2; s++) {
  const sg = s === 0 ? -1 : 1;
  for (let i = 0; i < BZ.length - 1; i++) {
    const z0 = BZ[i], z1 = BZ[i + 1], h = HT[(i + s * 2) % 5];
    const base = BCOL[(i + s * 3) % 5], wx = WALL * sg, seed = i * 13 + s * 41;
    const nu = (z1 - z0) / MU, nv = (h - WALK) / MV;
    const lit = 0.52 + lampAt(wx, (z0 + z1) / 2) * 0.38;
    texQuad([[wx, WALK, z0], [wx, WALK, z1], [wx, h, z1], [wx, h, z0]],
      [[0, 0], [nu, 0], [nu, nv], [0, nv]],
      (u, v) => facadeTex(u, v, base, seed), () => lit);
    const du = 6 / MU;
    texQuad([[wx, WALK, z0], [13 * sg, WALK, z0], [13 * sg, h, z0], [wx, h, z0]],
      [[0, 0], [du, 0], [du, nv], [0, nv]],
      (u, v) => facadeTex(u, v, base, seed + 7), () => 0.4);
    flat([[wx, h, z0], [13 * sg, h, z0], [13 * sg, h, z1], [wx, h, z1]],
      [base[0] * 0.3, base[1] * 0.3, base[2] * 0.34]);        // toit
  }
}

for (const [lx, lz] of LAMPS) {
  const inward = lx < 0 ? -1 : 1;
  flat([[lx - 0.07, GROUND, lz], [lx + 0.07, GROUND, lz], [lx + 0.07, 2.5, lz], [lx - 0.07, 2.5, lz]], [24, 24, 30]);
  const hx = lx - 0.55 * inward;
  flat([[hx, 2.5, lz], [lx + 0.07 * inward, 2.5, lz], [lx + 0.07 * inward, 2.62, lz], [hx, 2.62, lz]], [30, 30, 36]);
  flat([[hx - 0.3, 2.28, lz], [hx + 0.3, 2.28, lz], [hx + 0.3, 2.5, lz], [hx - 0.3, 2.5, lz]], [244, 200, 132]);
}

// -------------------------------------------- quantification 15 bits + trame
const bayer = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5];
const step = 255 / 31;
for (let i = 0; i < W * H; i++) {
  const th = ((bayer[(((i / W) | 0) & 3) * 4 + ((i % W) & 3)] + 0.5) / 16 - 0.5) * 0.85;
  for (let ch = 0; ch < 3; ch++) {
    const q = Math.round((D[i * 4 + ch] + th * step) / step) * step;
    D[i * 4 + ch] = q < 0 ? 0 : q > 255 ? 255 : q;
  }
}

// ------------------------------------------------------------- sortie PNG
const S = 3, OW = W * S, OH = H * S;
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
