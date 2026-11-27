// OCR every mock PNG and cache the words (text + box) as JSON, so the parser can be tested without re-running OCR.
// Uses the same clean-up (preprocess.js) as the browser app.   usage: npm run ocr [-- filter]
import { createWorker } from 'tesseract.js';
import sharp from 'sharp';
import fs from 'node:fs';
import path from 'node:path';
import Prep from '../preprocess.js';
const filter = process.argv[2] || '';
const dir = path.resolve('../mock-schedules/png');
const out = path.resolve('test/ocr-cache');
fs.mkdirSync(out, { recursive: true });
const workers = { eng: await createWorker(['eng']), kor: await createWorker(['kor', 'eng']) };
for (const f of fs.readdirSync(dir).filter(f => f.endsWith('.png') && f.includes(filter))) {
  const lang = f.includes('korean') ? 'kor' : 'eng';
  const meta = await sharp(path.join(dir, f)).metadata();
  const scale = Prep.chooseScale(meta.width, meta.height);
  const { data, info } = await sharp(path.join(dir, f)).resize({ width: Math.round(meta.width * scale), kernel: 'cubic' })
    .ensureAlpha().raw().toBuffer({ resolveWithObject: true });
  Prep.prepare(data, info.width, info.height, scale);
  const buf = await sharp(data, { raw: { width: info.width, height: info.height, channels: 4 } }).png().toBuffer();
  fs.mkdirSync('test/prepared', { recursive: true });
  fs.writeFileSync(path.join('test/prepared', f), buf);
  const { data: res } = await workers[lang].recognize(buf, {}, { blocks: true });
  const words = [];
  for (const b of res.blocks || []) for (const pa of b.paragraphs) for (const l of pa.lines) for (const w of l.words)
    words.push({ text: w.text, conf: Math.round(w.confidence), x0: w.bbox.x0 / scale, y0: w.bbox.y0 / scale, x1: w.bbox.x1 / scale, y1: w.bbox.y1 / scale });
  fs.writeFileSync(path.join(out, f.replace('.png', '.json')), JSON.stringify(words));
  console.log('==', f, lang, words.length, 'words');
  console.log(res.text);
}
for (const w of Object.values(workers)) await w.terminate();
process.exit(0);
