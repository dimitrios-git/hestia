// mesh-scene — the single scene implementation behind every mesh flavour:
// the tci ambient WebLattice (hexField + undulation + drift, geometry verbatim
// from stoa's CurriculumMap3D.tsx) plus the ACCENT-FLASH layer — nodes "fire"
// (accent glow, fast attack / smooth decay) and the pulse propagates one hop
// to grid neighbours at reduced strength. flavour=plain is simply
// flashCount=0. Consumed by mesh.html (the frame-stepped bake) and by
// preview/preview-entry.js (the live tuning page) — ONE implementation, no
// drift between preview and bake.
//
// Loop seamlessness: the three motion frequencies are snapped to integer
// cycles of loopT, and flash envelopes are evaluated on WRAPPED time deltas
// from a seeded, fixed event schedule — frame N-1 steps into frame 0 like any
// other frame.
//
// Flash events only pick nodes that project comfortably INSIDE the viewport
// (|NDC| < 0.85 at rest): the lattice overfills the frame for the drift
// margin, so a uniform pick over all nodes lands most flashes offscreen
// (caught live via projection debugging, 2026-07). The visible set is
// computed per camera aspect — portrait renders get their own.
import * as THREE from 'three';

// Defaults. The flash values are the APPROVED 2026-07 tuning (dimitrios, via
// the preview page) — the flash-mesh release bakes exactly these.
export const P = {
  variant: 'dark',
  loopT: 120,
  flashCount: 33,
  flashDur: 3.3,
  flashPeak: 1.0,
  spread: true,
  spreadDelay: 0.35,
  spreadPeak: 0.45,
  seed: 33,
};

export const COLORS = {
  dark:  { bg: '#1a1a1a', line: '#cfc8ba', accent: '#d7005f' },
  light: { bg: '#f5f5f5', line: '#3a352c', accent: '#d7005f' },
};

// mulberry32 — tiny deterministic PRNG (event schedule must be reproducible)
function mulberry32(a) {
  return function () {
    a |= 0; a = (a + 0x6D2B79F5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

// hexField — verbatim plain-mesh geometry, plus endpoint indices for adjacency
function hexField(halfX) {
  const s = 1.05, dx = s * 1.5;
  const cols = Math.ceil((halfX + 2) / dx) * 2 + 1;
  const rows = 6;
  const grid = [], pts = [];
  for (let c = 0; c < cols; c++) {
    grid[c] = [];
    for (let r = 0; r < rows; r++) {
      const x = (c - (cols - 1) / 2) * dx;
      const y = (r - (rows - 1) / 2) * s * Math.sqrt(3) + (c % 2 ? (s * Math.sqrt(3)) / 2 : 0);
      const z = -3.6 - ((c + r) % 3) * 0.45;
      const v = new THREE.Vector3(x, y, z);
      grid[c][r] = v; pts.push(v);
    }
  }
  const seg = [], segIdx = [];
  const idxOf = (c, r) => c * rows + r;
  const link = (ca, ra, cb, rb) => {
    const a = grid[ca]?.[ra], b = grid[cb]?.[rb];
    if (a && b) { seg.push(a, b); segIdx.push(idxOf(ca, ra), idxOf(cb, rb)); }
  };
  for (let c = 0; c < cols; c++) {
    for (let r = 0; r < rows; r++) {
      link(c, r, c, r + 1);
      link(c, r, c + 1, r);
      if (c % 2) link(c, r, c + 1, r + 1);
      else link(c, r, c + 1, r - 1);
    }
  }
  return { points: pts, segments: seg, segIdx };
}

export function buildScene(renderer, W, H) {
  const scene = new THREE.Scene();
  const camera = new THREE.PerspectiveCamera(45, W / H, 0.1, 100);
  camera.position.set(0, 0, 6);

  const hex = hexField(10);
  const nPts = hex.points.length;

  // adjacency for the one-hop propagation
  const adj = Array.from({ length: nPts }, () => []);
  for (let i = 0; i < hex.segIdx.length; i += 2) {
    adj[hex.segIdx[i]].push(hex.segIdx[i + 1]);
    adj[hex.segIdx[i + 1]].push(hex.segIdx[i]);
  }

  // flash-eligible nodes: comfortably inside this camera's viewport
  camera.updateMatrixWorld();
  const _v = new THREE.Vector3();
  const visible = [];
  hex.points.forEach((p, i) => {
    _v.copy(p).project(camera);
    if (Math.abs(_v.x) < 0.85 && Math.abs(_v.y) < 0.85) visible.push(i);
  });

  const toArr = (vs) => {
    const a = new Float32Array(vs.length * 3);
    vs.forEach((v, i) => { a[i * 3] = v.x; a[i * 3 + 1] = v.y; a[i * 3 + 2] = v.z; });
    return a;
  };
  const segBase = toArr(hex.segments);
  const ptBase = toArr(hex.points);

  const hexGeo = new THREE.BufferGeometry();
  hexGeo.setAttribute('position', new THREE.Float32BufferAttribute(segBase.slice(), 3));
  hexGeo.setAttribute('color', new THREE.Float32BufferAttribute(new Float32Array(segBase.length), 3));
  const ptGeo = new THREE.BufferGeometry();
  ptGeo.setAttribute('position', new THREE.Float32BufferAttribute(ptBase.slice(), 3));
  ptGeo.setAttribute('color', new THREE.Float32BufferAttribute(new Float32Array(ptBase.length), 3));

  // Vertex colours carry the flash lerp AND the per-element alpha, emulated by
  // blending toward the ground colour (the ground is opaque, so this equals
  // material opacity against it — and lets flashes brighten past the base).
  const group = new THREE.Group();
  group.add(new THREE.LineSegments(hexGeo, new THREE.LineBasicMaterial({ vertexColors: true })));
  group.add(new THREE.Points(ptGeo, new THREE.PointsMaterial({ vertexColors: true, size: 0.05, sizeAttenuation: true })));
  scene.add(group);

  let events = [];
  const cLine = new THREE.Color(), cAccent = new THREE.Color(), cBg = new THREE.Color();
  let W_UND, W_ROT, W_SWY;
  const TAU = Math.PI * 2;

  function rebuild() {
    const col = COLORS[P.variant];
    cBg.set(col.bg); cLine.set(col.line); cAccent.set(col.accent);
    scene.background = cBg.clone();
    W_UND = TAU * Math.max(1, Math.round(0.5 * P.loopT / TAU)) / P.loopT;
    W_ROT = TAU * Math.max(1, Math.round(0.05 * P.loopT / TAU)) / P.loopT;
    W_SWY = W_ROT; // same snapped k at T=120; kept distinct by the pi/2 phase
    const rnd = mulberry32(P.seed);
    events = Array.from({ length: P.flashCount }, (_, i) => ({
      t0: ((i + rnd() * 0.9) / Math.max(1, P.flashCount)) * P.loopT,
      node: visible[Math.floor(rnd() * visible.length)],
    }));
  }
  rebuild();

  // flash envelope: fast attack (12%), smooth quadratic-ish decay
  function envelope(dt, dur) {
    if (dt < 0 || dt >= dur) return 0;
    const x = dt / dur;
    return x < 0.12 ? x / 0.12 : Math.pow(1 - (x - 0.12) / 0.88, 2.2);
  }

  const intensity = new Float32Array(nPts);

  function renderFrame(t) {
    const und = (geo, base) => {
      const arr = geo.attributes.position.array;
      for (let i = 0; i < base.length; i += 3) {
        arr[i + 2] = base[i + 2] + Math.sin(t * W_UND + base[i] * 0.22 + base[i + 1] * 0.18) * 0.35;
      }
      geo.attributes.position.needsUpdate = true;
    };
    und(hexGeo, segBase);
    und(ptGeo, ptBase);
    group.rotation.z = Math.sin(t * W_ROT) * 0.04;
    group.position.x = Math.sin(t * W_SWY + Math.PI / 2) * 0.25;

    intensity.fill(0);
    for (const ev of events) {
      const dt = ((t - ev.t0) % P.loopT + P.loopT) % P.loopT;
      const e0 = envelope(dt, P.flashDur) * P.flashPeak;
      if (e0 > 0) intensity[ev.node] = Math.max(intensity[ev.node], e0);
      if (P.spread) {
        const e1 = envelope(dt - P.spreadDelay, P.flashDur) * P.spreadPeak;
        if (e1 > 0) for (const nb of adj[ev.node]) intensity[nb] = Math.max(intensity[nb], e1);
      }
    }

    const _c = new THREE.Color();
    const ptCol = ptGeo.attributes.color.array;
    for (let i = 0; i < nPts; i++) {
      _c.copy(cLine).lerp(cAccent, intensity[i]);
      const a = 0.45 + 0.55 * intensity[i];
      ptCol[i * 3] = _c.r * a + cBg.r * (1 - a);
      ptCol[i * 3 + 1] = _c.g * a + cBg.g * (1 - a);
      ptCol[i * 3 + 2] = _c.b * a + cBg.b * (1 - a);
    }
    ptGeo.attributes.color.needsUpdate = true;
    const segCol = hexGeo.attributes.color.array;
    for (let s = 0; s < hex.segIdx.length; s++) {
      const it = intensity[hex.segIdx[s]];
      _c.copy(cLine).lerp(cAccent, it);
      const a = 0.1 + 0.6 * it;
      segCol[s * 3] = _c.r * a + cBg.r * (1 - a);
      segCol[s * 3 + 1] = _c.g * a + cBg.g * (1 - a);
      segCol[s * 3 + 2] = _c.b * a + cBg.b * (1 - a);
    }
    hexGeo.attributes.color.needsUpdate = true;

    renderer.render(scene, camera);
  }

  return { renderFrame, rebuild, camera };
}
