// Rend le même visuel que la page, hors navigateur, pour pouvoir le regarder.
const fs = require('fs');
const zlib = require('zlib');

const W = 192, H = 108;
const D = new Uint8Array(W * H * 4);
const zbuf = new Float32Array(W * H).fill(1e9);

const FOCAL = 132;
const FOG = [32, 36, 48], FOG_A = 6, FOG_B = 50;
const GROUND = -1.5, WALK = -1.32, WALL = 7;

function proj(x, y, z) {
  return [Math.round(W / 2 + x * FOCAL / z), Math.round(H / 2 - y * FOCAL / z), z];
}
function fog(z) { const t = (z - FOG_A) / (FOG_B - FOG_A); return t < 0 ? 0 : t > 1 ? 1 : t; }
function put(x, y, r, g, b) {
  const i = (y * W + x) * 4;
  D[i] = r; D[i + 1] = g; D[i + 2] = b; D[i + 3] = 255;
}

for (let y = 0; y < H; y++) {
  const t = y / H;
  for (let x = 0; x < W; x++) {
    const dx = Math.abs(x - W / 2) / (W / 2);
    const g = Math.max(0, 1 - dx * 1.5) * Math.max(0, t - 0.20) * 1.7;
    const haze = Math.max(0, 1 - Math.abs(y - 54) / 30) * 0.6;
    let sr = 6 + t * 15 + g * 42, sg2 = 8 + t * 17 + g * 27, sb = 14 + t * 23 + g * 13;
    put(x, y, sr + (FOG[0] - sr) * haze, sg2 + (FOG[1] - sg2) * haze, sb + (FOG[2] - sb) * haze);
  }
}

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
      const idx = y * W + x;
      if (z >= zbuf[idx]) continue;
      zbuf[idx] = z;
      shade(x, y, w0, w1, w2, z);
    }
  }
}
function quad(pts, shadeFor) {
  const p = [];
  for (let i = 0; i < 4; i++) p.push(proj(pts[i][0], pts[i][1], pts[i][2]));
  tri(p[0], p[1], p[2], shadeFor(0, 1, 2));
  tri(p[0], p[2], p[3], shadeFor(0, 2, 3));
}
function flat(pts, col) {
  quad(pts, () => (x, y, w0, w1, w2, z) => {
    const f = fog(z);
    put(x, y, col[0] + (FOG[0] - col[0]) * f, col[1] + (FOG[1] - col[1]) * f, col[2] + (FOG[2] - col[2]) * f);
  });
}

const LAMPS = [[-4.7, 9], [4.7, 17], [-4.7, 25], [4.7, 33], [-4.7, 41]];
function lamp(wx, wz) {
  let s = 0;
  for (const L of LAMPS) { const dx = wx - L[0], dz = wz - L[1]; s += 6.5 / (1 + (dx * dx + dz * dz) * 0.4); }
  return s > 1.7 ? 1.7 : s;
}
function asphalt(u, v) {
  const vv = v - Math.floor(v);
  if (u > 0.472 && u < 0.528 && vv < 0.45) return [172, 158, 104];
  const n = ((Math.floor(u * 20) * 73856093) ^ (Math.floor(v * 20) * 19349663)) & 15;
  const g = 38 + n * 1.1;
  return [g, g + 1, g + 5];
}
const TILE = 0.22;
function road(z0, z1) {
  const pts = [[-4, GROUND, z0], [4, GROUND, z0], [4, GROUND, z1], [-4, GROUND, z1]];
  const UV = [[0, z0 * TILE], [1, z0 * TILE], [1, z1 * TILE], [0, z1 * TILE]];
  quad(pts, (i0, i1, i2) => (x, y, w0, w1, w2) => {
    const u = UV[i0][0] * w0 + UV[i1][0] * w1 + UV[i2][0] * w2;
    const v = UV[i0][1] * w0 + UV[i1][1] * w1 + UV[i2][1] * w2;
    const col = asphalt(u, v);
    const wx = u * 8 - 4, wz = v / TILE;
    const L = lamp(wx, wz), f = fog(wz);
    const r = col[0] * (0.52 + L * 0.42) + L * 20;
    const g = col[1] * (0.52 + L * 0.38) + L * 13;
    const b = col[2] * (0.55 + L * 0.30) + L * 5;
    put(x, y, r + (FOG[0] - r) * f, g + (FOG[1] - g) * f, b + (FOG[2] - b) * f);
  });
}
const SEG = [2.2, 3.3, 5, 7, 9.8, 14, 20, 29, 41, 56];
for (let i = 0; i < SEG.length - 1; i++) road(SEG[i], SEG[i + 1]);
for (let i = 0; i < SEG.length - 1; i++) {
  flat([[-WALL, WALK, SEG[i]], [-4, WALK, SEG[i]], [-4, WALK, SEG[i + 1]], [-WALL, WALK, SEG[i + 1]]], [62, 62, 70]);
  flat([[4, WALK, SEG[i]], [WALL, WALK, SEG[i]], [WALL, WALK, SEG[i + 1]], [4, WALK, SEG[i + 1]]], [62, 62, 70]);
}
const BZ = [6, 13, 21, 30, 40, 54];
const BCOL = [[84, 70, 60], [64, 68, 82], [92, 76, 62], [58, 63, 75], [86, 74, 64]];
const HT = [5.6, 7.4, 4.5, 8.6, 6.2];
for (let s = 0; s < 2; s++) {
  const sg = s === 0 ? -1 : 1;
  for (let i = 0; i < BZ.length - 1; i++) {
    const z0 = BZ[i], z1 = BZ[i + 1], h = HT[(i + s * 2) % 5];
    const base = BCOL[(i + s * 3) % 5], wx2 = WALL * sg;
    const lit = lamp(wx2, (z0 + z1) / 2) * 0.5;
    flat([[wx2, WALK, z0], [wx2, WALK, z1], [wx2, h, z1], [wx2, h, z0]],
      [base[0] * (1 + lit), base[1] * (1 + lit * 0.9), base[2] * (1 + lit * 0.7)]);
    flat([[wx2, WALK, z0], [13 * sg, WALK, z0], [13 * sg, h, z0], [wx2, h, z0]],
      [base[0] * 0.52, base[1] * 0.52, base[2] * 0.58]);
    const fx = wx2 - 0.04 * sg, span = (z1 - z0 - 2.4) / 3;
    for (let r2 = 0; r2 < 3; r2++) {
      const wy = 0.1 + r2 * 2.0;
      if (wy + 1.1 > h) continue;
      for (let k = 0; k < 3; k++) {
        const a0 = z0 + 1.2 + k * span, a1 = a0 + span * 0.58;
        const m = (i * 7 + r2 * 3 + k + s * 5) % 9;
        const wc = m === 0 ? [86, 188, 116] : (m < 4 ? [196, 146, 72] : [19, 21, 29]);
        flat([[fx, wy, a0], [fx, wy, a1], [fx, wy + 1.1, a1], [fx, wy + 1.1, a0]], wc);
      }
    }
  }
}
for (const L of LAMPS) {
  const lx = L[0], lz = L[1];
  flat([[lx - 0.09, GROUND, lz], [lx + 0.09, GROUND, lz], [lx + 0.09, 2.3, lz], [lx - 0.09, 2.3, lz]], [21, 21, 26]);
  flat([[lx - 0.42, 2.3, lz], [lx + 0.42, 2.3, lz], [lx + 0.42, 2.62, lz], [lx - 0.42, 2.62, lz]], [238, 192, 122]);
}
const bayer = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5];
const step = 255 / 31;   // 15 bits, comme la PS1
for (let i = 0; i < W * H; i++) {
  const px = i % W, py = (i / W) | 0;
  const th = ((bayer[(py & 3) * 4 + (px & 3)] + 0.5) / 16 - 0.5) * 0.9;
  for (let ch = 0; ch < 3; ch++) {
    const q = Math.round((D[i * 4 + ch] + th * step) / step) * step;
    D[i * 4 + ch] = q < 0 ? 0 : q > 255 ? 255 : q;
  }
}

// --- upscale x5 au plus proche voisin + encodage PNG ---
const S = 5, OW = W * S, OH = H * S;
const raw = Buffer.alloc(OH * (1 + OW * 3));
for (let y = 0; y < OH; y++) {
  const off = y * (1 + OW * 3);
  raw[off] = 0;
  const sy = (y / S) | 0;
  for (let x = 0; x < OW; x++) {
    const si = (sy * W + ((x / S) | 0)) * 4, di = off + 1 + x * 3;
    raw[di] = D[si]; raw[di + 1] = D[si + 1]; raw[di + 2] = D[si + 2];
  }
}
const crcT = [];
for (let n = 0; n < 256; n++) { let ccc = n; for (let k = 0; k < 8; k++) ccc = ccc & 1 ? 0xedb88320 ^ (ccc >>> 1) : ccc >>> 1; crcT[n] = ccc >>> 0; }
const crc = b => { let ccc = 0xffffffff; for (const x of b) ccc = crcT[(ccc ^ x) & 0xff] ^ (ccc >>> 8); return (ccc ^ 0xffffffff) >>> 0; };
const chunk = (type, data) => {
  const len = Buffer.alloc(4); len.writeUInt32BE(data.length);
  const td = Buffer.concat([Buffer.from(type, 'ascii'), data]);
  const cb = Buffer.alloc(4); cb.writeUInt32BE(crc(td));
  return Buffer.concat([len, td, cb]);
};
const ihdr = Buffer.alloc(13);
ihdr.writeUInt32BE(OW, 0); ihdr.writeUInt32BE(OH, 4);
ihdr[8] = 8; ihdr[9] = 2; ihdr[10] = 0; ihdr[11] = 0; ihdr[12] = 0;
const png = Buffer.concat([
  Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
  chunk('IHDR', ihdr), chunk('IDAT', zlib.deflateSync(raw)), chunk('IEND', Buffer.alloc(0))
]);
fs.writeFileSync(process.argv[2], png);
console.log(`${OW}x${OH} ecrit`);
