/* Image clean-up before OCR. Pure pixel maths, shared by the browser (canvas) and Node tests (sharp).
 *
 *   1. greyscale
 *   2. dark-mode screenshots are inverted (OCR wants dark text on a light page)
 *   3. coloured / grey cell backgrounds are flattened to white
 *   4. contrast stretch
 *   5. table borders are erased — long thin lines make the OCR drop first letters and misread colons
 *
 * The caller upscales the image first (small screen text reads far better at ~3x).
 */
(function (root, factory) {
  const api = factory();
  if (typeof module === 'object' && module.exports) module.exports = api;
  else root.ReadySetPrep = api;
})(typeof self !== 'undefined' ? self : this, function () {
  'use strict';

  /** How much to upscale an image of this size: 3x for small screenshots, less for big ones. */
  function chooseScale(width, height) {
    return Math.max(1, Math.min(3, 4200 / Math.max(width, height)));
  }

  function otsu(hist, total) {
    let sum = 0;
    for (let i = 0; i < 256; i++) sum += i * hist[i];
    let sumB = 0, wB = 0, best = 0, thr = 127;
    for (let t = 0; t < 256; t++) {
      wB += hist[t];
      if (!wB) continue;
      const wF = total - wB;
      if (!wF) break;
      sumB += t * hist[t];
      const mB = sumB / wB, mF = (sum - sumB) / wF;
      const between = wB * wF * (mB - mF) * (mB - mF);
      if (between > best) { best = between; thr = t; }
    }
    return thr;
  }

  /**
   * Make every background white, whatever colour the cell is (colour-coded shifts, grey "off" cells,
   * dark-mode cards). The background is estimated with a morphological closing — it wipes out thin
   * dark things (text, borders) but keeps the edges of coloured areas — then each pixel is divided by it.
   * Done on a grid `step` px coarse to stay fast.
   */
  function flattenBackground(g, w, h, step) {
    const gw = Math.ceil(w / step), gh = Math.ceil(h / step), R = 4;
    let a = new Uint8Array(gw * gh), b = new Uint8Array(gw * gh);
    for (let y = 0; y < h; y++) {
      const row = Math.floor(y / step) * gw;
      for (let x = 0; x < w; x++) {
        const v = g[y * w + x], k = row + Math.floor(x / step);
        if (v > a[k]) a[k] = v;
      }
    }
    const pass = (src, dst, horizontal, wantMax) => {
      for (let y = 0; y < gh; y++) for (let x = 0; x < gw; x++) {
        let m = wantMax ? 0 : 255;
        for (let d = -R; d <= R; d++) {
          const xx = horizontal ? x + d : x, yy = horizontal ? y : y + d;
          if (xx < 0 || yy < 0 || xx >= gw || yy >= gh) continue;
          const v = src[yy * gw + xx];
          if (wantMax ? v > m : v < m) m = v;
        }
        dst[y * gw + x] = m;
      }
    };
    pass(a, b, true, true); pass(b, a, false, true);     // dilate
    pass(a, b, true, false); pass(b, a, false, false);   // erode
    for (let y = 0; y < h; y++) {
      const row = Math.floor(y / step) * gw;
      for (let x = 0; x < w; x++) {
        const bg = a[row + Math.floor(x / step)] || 1, v = (g[y * w + x] * 255) / bg;
        g[y * w + x] = v > 255 ? 255 : v;
      }
    }
  }

  /**
   * @param rgba  Uint8ClampedArray / Buffer of RGBA pixels (modified in place → greyscale RGBA)
   * @param scale the upscale factor already applied (line thickness limits depend on it)
   */
  function prepare(rgba, w, h, scale) {
    const n = w * h;
    const g = new Uint8Array(n);
    let sum = 0;
    for (let i = 0, p = 0; i < n; i++, p += 4) {
      g[i] = (rgba[p] * 299 + rgba[p + 1] * 587 + rgba[p + 2] * 114) / 1000;
      sum += g[i];
    }
    if (sum / n < 110) for (let i = 0; i < n; i++) g[i] = 255 - g[i];

    flattenBackground(g, w, h, Math.max(1, Math.round(scale)));

    // contrast stretch between the 1st and 99th percentile
    const hist = new Uint32Array(256);
    for (let i = 0; i < n; i++) hist[g[i]]++;
    let lo = 0, hi = 255, acc = 0;
    for (let v = 0; v < 256; v++) { acc += hist[v]; if (acc >= n * 0.01) { lo = v; break; } }
    acc = 0;
    for (let v = 255; v >= 0; v--) { acc += hist[v]; if (acc >= n * 0.01) { hi = v; break; } }
    if (hi - lo > 40) {
      const k = 255 / (hi - lo);
      hist.fill(0);
      for (let i = 0; i < n; i++) {
        const v = (g[i] - lo) * k;
        g[i] = v < 0 ? 0 : v > 255 ? 255 : v;
        hist[g[i]]++;
      }
    }

    // erase table borders: dark runs that are long in one direction and thin in the other
    const thr = otsu(hist, n);
    const LONG = Math.round(34 * scale), THIN = Math.round(3 * scale), HALO = Math.ceil(scale / 2) + 1;
    const hrun = new Uint16Array(n), vrun = new Uint16Array(n);
    for (let y = 0; y < h; y++) {
      let start = -1;
      for (let x = 0; x <= w; x++) {
        const dark = x < w && g[y * w + x] < thr;
        if (dark && start < 0) start = x;
        if (!dark && start >= 0) {
          const len = Math.min(65535, x - start);
          for (let k = start; k < x; k++) hrun[y * w + k] = len;
          start = -1;
        }
      }
    }
    for (let x = 0; x < w; x++) {
      let start = -1;
      for (let y = 0; y <= h; y++) {
        const dark = y < h && g[y * w + x] < thr;
        if (dark && start < 0) start = y;
        if (!dark && start >= 0) {
          const len = Math.min(65535, y - start);
          for (let k = start; k < y; k++) vrun[k * w + x] = len;
          start = -1;
        }
      }
    }
    const out = new Uint8Array(g);
    for (let y = 0; y < h; y++) {
      for (let x = 0; x < w; x++) {
        const i = y * w + x;
        if (hrun[i] >= LONG && vrun[i] <= THIN) {
          for (let d = -HALO - vrun[i]; d <= HALO + vrun[i]; d++) { const yy = y + d; if (yy >= 0 && yy < h) out[yy * w + x] = 255; }
        } else if (vrun[i] >= LONG && hrun[i] <= THIN) {
          for (let d = -HALO - hrun[i]; d <= HALO + hrun[i]; d++) { const xx = x + d; if (xx >= 0 && xx < w) out[y * w + xx] = 255; }
        }
      }
    }

    for (let i = 0, p = 0; i < n; i++, p += 4) {
      rgba[p] = rgba[p + 1] = rgba[p + 2] = out[i];
      rgba[p + 3] = 255;
    }
    return rgba;
  }

  return { prepare, chooseScale };
});
