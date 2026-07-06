// Browser preview for the accent-flash mesh — live rAF clock, control panel.
import * as THREE from 'three';
import { P, COLORS, buildScene } from '../mesh-scene.js';

const renderer = new THREE.WebGLRenderer({ antialias: true });
renderer.setSize(window.innerWidth, window.innerHeight);
renderer.setPixelRatio(window.devicePixelRatio);
document.body.appendChild(renderer.domElement);

let scene = buildScene(renderer, window.innerWidth, window.innerHeight);

window.addEventListener('resize', () => {
  renderer.setSize(window.innerWidth, window.innerHeight);
  scene.camera.aspect = window.innerWidth / window.innerHeight;
  scene.camera.updateProjectionMatrix();
});

const t0 = performance.now();
let paused = false;
window.__seek = (t) => { paused = true; scene.renderFrame(t); };
window.__resume = () => { paused = false; };
function tick() {
  if (!paused) {
    const t = ((performance.now() - t0) / 1000) % P.loopT;
    scene.renderFrame(t);
    document.getElementById('clock').textContent = 't = ' + t.toFixed(1) + 's / ' + P.loopT + 's';
  }
  requestAnimationFrame(tick);
}
tick();

// ---- control panel wiring
const panel = document.getElementById('panel');
const controls = [
  ['variant',     'select', ['dark', 'light']],
  ['flashCount',  'range', 2, 40, 1],
  ['flashDur',    'range', 0.5, 8, 0.1],
  ['flashPeak',   'range', 0.2, 1, 0.05],
  ['spread',      'check'],
  ['spreadDelay', 'range', 0.1, 1.5, 0.05],
  ['spreadPeak',  'range', 0, 1, 0.05],
  ['seed',        'range', 1, 99, 1],
];
for (const [key, kind, ...rest] of controls) {
  const row = document.createElement('label');
  row.className = 'row';
  const name = document.createElement('span');
  name.textContent = key;
  row.appendChild(name);
  let input;
  if (kind === 'select') {
    input = document.createElement('select');
    for (const opt of rest[0]) {
      const o = document.createElement('option');
      o.value = o.textContent = opt;
      input.appendChild(o);
    }
    input.value = P[key];
    input.onchange = () => { P[key] = input.value; document.body.style.background = COLORS[P.variant].bg; scene.rebuild(); };
  } else if (kind === 'check') {
    input = document.createElement('input');
    input.type = 'checkbox';
    input.checked = P[key];
    input.onchange = () => { P[key] = input.checked; scene.rebuild(); };
  } else {
    input = document.createElement('input');
    input.type = 'range';
    [input.min, input.max, input.step] = rest;
    input.value = P[key];
    const val = document.createElement('em');
    val.textContent = P[key];
    input.oninput = () => { P[key] = parseFloat(input.value); val.textContent = input.value; scene.rebuild(); };
    row.appendChild(val);
  }
  row.appendChild(input);
  panel.appendChild(row);
}
document.getElementById('params').onclick = () => {
  const s = JSON.stringify(P, null, 2);
  navigator.clipboard?.writeText(s);
  alert('Parameters (copied to clipboard):\n\n' + s);
};
