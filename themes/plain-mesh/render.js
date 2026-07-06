// Frame-stepped deterministic render of mesh.html via headless chromium.
// Usage: node render.js <outdir> <bg> <line> [w] [h] [fps] [loopT] [startFrame]
// Emits <outdir>/f%05d.png — frame i is time i/fps, loop closes at loopT.
const puppeteer = require('puppeteer-core');
const fs = require('fs');
const path = require('path');

(async () => {
  const [outdir, bg, line, w = '3840', h = '2160', fps = '24', loopT = '120', start = '0'] = process.argv.slice(2);
  if (!outdir || !bg || !line) { console.error('usage: node render.js <outdir> <bg> <line> [w] [h] [fps] [loopT] [start]'); process.exit(2); }
  fs.mkdirSync(outdir, { recursive: true });

  const frames = Math.round(parseFloat(loopT) * parseFloat(fps));
  const browser = await puppeteer.launch({
    executablePath: '/usr/bin/chromium',
    // NVIDIA EGL vendor stack: claude can't open /dev/dri (render group) but
    // /dev/nvidia* is world-rw — see memory nvidia-gpu-for-claude
    env: { ...process.env,
      __EGL_VENDOR_LIBRARY_FILENAMES: '/usr/share/glvnd/egl_vendor.d/10_nvidia.json',
      __GLX_VENDOR_LIBRARY_NAME: 'nvidia' },
    args: [
      '--headless=new', '--no-sandbox', '--allow-file-access-from-files', '--disable-dev-shm-usage',
      '--use-gl=angle', '--use-angle=gl-egl',
      `--window-size=${w},${h}`, '--hide-scrollbars',
    ],
    defaultViewport: { width: parseInt(w, 10), height: parseInt(h, 10) },
  });
  const page = await browser.newPage();
  const url = 'file://' + path.resolve(__dirname, 'mesh.html') +
    `?w=${w}&h=${h}&bg=${encodeURIComponent(bg)}&line=${encodeURIComponent(line)}&loop=${loopT}`;
  await page.goto(url, { waitUntil: 'load' });
  await page.waitForFunction('window.meshReady === true', { timeout: 30000 });

  const canvas = await page.$('canvas');
  const t0 = Date.now();
  for (let i = parseInt(start, 10); i < frames; i++) {
    const t = i / parseFloat(fps);
    await page.evaluate((tt) => window.renderFrame(tt), t);
    await canvas.screenshot({ path: path.join(outdir, `f${String(i).padStart(5, '0')}.png`) });
    if (i % 100 === 0) {
      const el = (Date.now() - t0) / 1000;
      console.log(`frame ${i}/${frames} (${el.toFixed(0)}s elapsed, ${(el / Math.max(1, i - parseInt(start, 10) + 1)).toFixed(2)}s/frame)`);
    }
  }
  await browser.close();
  console.log(`done: ${frames} frames in ${outdir}`);
})();
