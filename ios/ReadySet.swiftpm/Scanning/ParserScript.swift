/// GENERATED from web/parser.js by `npm run sync-ios` (in web/). Do not edit here.
/// Edit web/parser.js, then run the script again.
enum ParserScript {
    static let source = #"""
/* ReadySet schedule parser — no AI, just geometry + patterns.
 *
 * Input : OCR words [{text, conf, x0, y0, x1, y1}] (any OCR engine) + the user's name(s).
 * Output: the user's shifts, which layout was detected, and anything that needs review.
 *
 * Layouts handled
 *   grid        staff are rows, dates are a header row            (Café A, Bakery C, Hotel E)
 *   transposed  dates are rows, staff are a header row            (Restaurant B)
 *   list        personal schedule: a date, then its time range    (scheduling-app screenshot)
 *
 * Works in the browser (window.ReadySet) and in Node (require).
 */
(function (root, factory) {
  const api = factory();
  if (typeof module === 'object' && module.exports) module.exports = api;
  else root.ReadySet = api;
})(typeof self !== 'undefined' ? self : this, function () {
  'use strict';

  const NAME_THRESHOLD = 0.75;

  // ------------------------------------------------------------------ names
  const letters = (s) => s.toLowerCase().replace(/[^\p{L}]/gu, '');

  function levenshtein(a, b) {
    if (a === b) return 0;
    let prev = Array.from({ length: b.length + 1 }, (_, i) => i);
    for (let i = 1; i <= a.length; i++) {
      const cur = [i];
      for (let j = 1; j <= b.length; j++) {
        cur[j] = Math.min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (a[i - 1] === b[j - 1] ? 0 : 1));
      }
      prev = cur;
    }
    return prev[b.length];
  }

  const similarity = (a, b) => (!a || !b ? 0 : 1 - levenshtein(a, b) / Math.max(a.length, b.length));

  /** Ways a name is commonly written on a schedule, each with a weight (1 = as good as the full name). */
  function nameVariants(name) {
    const parts = name.split(/[\s,.\-]+/).map(letters).filter(Boolean);
    if (!parts.length) return [];
    if (parts.length === 1) return [{ t: parts[0], w: 1 }];
    const first = parts[0], last = parts[parts.length - 1];
    return [
      { t: parts.join(''), w: 1 },
      { t: first + last, w: 1 },
      { t: last + first, w: 1 },
      { t: first[0] + last, w: 0.97 },   // J. Park
      { t: last + first[0], w: 0.97 },   // Park, J.
      { t: first + last[0], w: 0.9 },    // Jamie P.
      { t: last, w: 0.8 },
      { t: first, w: 0.8 },
    ];
  }

  /** 0..1: how well a label read from the schedule matches any of the user's names. */
  function scoreName(label, names) {
    const cand = letters(label);
    if (cand.length < 2) return 0;
    let best = 0;
    for (const n of names) for (const v of nameVariants(n)) best = Math.max(best, similarity(cand, v.t) * v.w);
    return best;
  }

  const cleanLabel = (s) => s.replace(/^[\d\s|.,、。:;=_\-'"‘’“”`~]+|[\s|、。:;=_'"‘’“”`~]+$/g, '').replace(/\s+/g, ' ')
    // a checkbox in front of the name, read by OCR as "V", "✓", "□"…: "V Cindy" → "Cindy"
    .replace(/^[vVxX✓✔☑☐□■]\s+(?=\p{L}{2})/u, '');

  // ------------------------------------------------------------------ times
  const MER = '(a\\.?m?\\.?|p\\.?m?\\.?)';
  const TIME_RANGE = new RegExp(
    // the colon is optional: OCR sometimes drops it ("530-1330"), and some rotas write "0600-1430"
    '(?<!\\d)(\\d{1,2})(?:[:.]?(\\d{2}))?\\s?' + MER + '?\\s?(?:[-–—~^%=_]{1,3}|\\bto\\b)\\s?' +
    '(?:(\\d{1,2})(?:[:.]?(\\d{2}))?\\s?' + MER + '?(?![\\d])|(cl|close|closing|마감))', 'i');
  const OFF = /^([o0q]ff?|x|×|휴무|휴f?|휴|쉼|[-–—]+|rest|day\s*off|not\s*scheduled|n\/a)$/i;
  const NOISE = /^[\s=.,_:;'"`|。、]+|[\s=.,_:;'"`|。、]+$/g;

  /**
   * OCR often loses or garbles the dash in a shift:
   *   "4.830" / "630.930" / "3.9" / "4.CL"  → a dot was read instead of the dash
   *   "5CL" / "SCL" / "GCL"                  → the dash vanished (S = 5, G = 6)
   * A dot followed by 0 or 5 ("3.5", "6.0", "5.50") is left alone: that is an hours total, not a shift.
   */
  function fixSeparators(text) {
    return text
      .replace(/\b[sS](?=-?(cl|close)\b)/gi, '5')
      .replace(/\bG(?=-?(cl|close)\b)/gi, '6')   // i: "CL" is usually upper case
      .replace(/(\d{1,4})\.(?=(?:\d{3,4}|[1-46-9])(?!\d)|cl\b|close\b)/gi, '$1-')
      .replace(/(?<![\d:.\-])(\d{1,4})(?=(cl|close)\b)/gi, '$1-');
  }

  const hhmm = (mins) => {
    mins = ((mins % 1440) + 1440) % 1440;
    return String(Math.floor(mins / 60)).padStart(2, '0') + ':' + String(mins % 60).padStart(2, '0');
  };

  /** Pick the candidate time that comes soonest after (dir=1) or before (dir=-1) `ref`. */
  function nearest(cands, ref, dir) {
    let best = null, bestGap = Infinity;
    for (const c of cands) {
      const gap = (((c - ref) * dir) % 1440 + 1440) % 1440;
      if (gap > 0 && gap < bestGap) { best = c; bestGap = gap; }
    }
    return best === null ? cands[0] : best;
  }

  /**
   * Read one cell. Returns
   *   {kind:'shift', start:'HH:MM', end:'HH:MM'|null, overnight, assumed, toClose}
   *   {kind:'off'} | {kind:'empty'} | {kind:'unknown', raw}
   * `assumed` = no AM/PM was written, so it was guessed (start 5–11 → AM, otherwise PM).
   * `codes`   = optional legend map, e.g. {A: {kind:'shift', ...}, X: {kind:'off'}}.
   * `hint24`  = the schedule uses a 24-hour clock elsewhere, so read "5:30 - 11:00" as 24-hour too.
   */
  function parseShift(raw, codes, hint24) {
    const bare = String(raw).replace(NOISE, '');
    if (!bare) return { kind: 'empty' };
    if (codes) {
      const c = bare.toUpperCase().replace('×', 'X');
      if (codes[c]) return Object.assign({ code: c }, codes[c]);
    }
    const m = TIME_RANGE.exec(fixSeparators(bare));
    if (!m) return OFF.test(bare) ? { kind: 'off' } : { kind: 'unknown', raw: bare };

    const h1 = +m[1], m1 = +(m[2] || 0), mer1 = m[3] ? m[3][0].toLowerCase() : null;
    const toClose = !!m[7];
    const h2 = toClose ? null : +m[4], m2 = toClose ? 0 : +(m[5] || 0), mer2 = m[6] ? m[6][0].toLowerCase() : null;
    if (m1 > 59 || m2 > 59) return { kind: 'unknown', raw: bare };

    const anyMer = mer1 || mer2;
    const is24 = !anyMer && (hint24 || h1 > 12 || h2 > 12 || h1 === 0 || h2 === 0 || /(?<!\d)0\d[:.]\d{2}/.test(bare));
    const to24 = (h, mer) => (h % 12) * 60 + (mer === 'p' ? 720 : 0);
    let s, e = null, assumed = false;

    if (is24) {
      if (h1 > 24 || (h2 !== null && h2 > 24)) return { kind: 'unknown', raw: bare };
      s = h1 * 60 + m1;
      if (!toClose) e = h2 * 60 + m2;
    } else {
      if (h1 < 1 || h1 > 12 || (h2 !== null && (h2 < 1 || h2 > 12))) return { kind: 'unknown', raw: bare };
      const e12 = toClose ? null : (h2 % 12) * 60 + m2;
      const s12 = (h1 % 12) * 60 + m1;
      if (mer1) s = to24(h1, mer1) + m1;
      else if (mer2) s = nearest([s12, s12 + 720], to24(h2, mer2) + m2, -1);
      else {
        assumed = true;
        // closing shifts ("5-CL", "530-CL") start in the afternoon; only 10 or 11 "-CL" is a morning start
        const morning = toClose ? h1 >= 10 && h1 <= 11 : h1 >= 5 && h1 <= 11;
        s = s12 + (morning ? 0 : 720);
      }
      if (!toClose) e = mer2 ? to24(h2, mer2) + m2 : nearest([e12, e12 + 720], s, 1);
    }
    s %= 1440;
    if (e !== null) e %= 1440;
    return {
      kind: 'shift', start: hhmm(s), end: e === null ? null : hhmm(e),
      overnight: e !== null && e <= s, assumed, toClose,
    };
  }

  // ------------------------------------------------------------------ dates
  const MONTHS = ['jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec'];
  const MONTH_RE = 'jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|june?|july?|aug(?:ust)?|sep(?:t(?:ember)?)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?';
  const WEEKDAY = /^(mon|tue|wed|thu|fri|sat|sun)[a-z]*[,.]?$|^[월화수목금토일](요일)?[,.]?$/i;
  const DATE_PATTERNS = [
    // 23-Nov, 23 Nov, 23.Nov (day first). Listed before "Nov 24" so "23-Nov 24-Nov" isn't read as Nov 24.
    {
      re: new RegExp('(?<![\\d/])(\\d{1,2})[-\\s.]?(' + MONTH_RE + ')(?![a-z])', 'gi'),
      md: (m) => [MONTHS.indexOf(m[2].slice(0, 3).toLowerCase()) + 1, +m[1]],
    },
    // 10/26  (month/day)
    { re: /(?<![\d/])(\d{1,2})\s?\/\s?(\d{1,2})(?![\d/])/g, md: (m) => [+m[1], +m[2]] },
    // Oct 26, MonOct26, Nov l (OCR reads "1" as "l")
    {
      re: new RegExp('(?:(?<![a-z])|(?<=mon|tue|wed|thu|fri|sat|sun))(' + MONTH_RE + ')\\.?,?\\s?(\\d{1,2}|[li]\\d?|\\d[lio])(?![\\d:a-z])', 'gi'),
      md: (m) => [MONTHS.indexOf(m[1].slice(0, 3).toLowerCase()) + 1, +m[2].replace(/[li]/gi, '1').replace(/o/gi, '0')],
    },
    // 10월 26일
    { re: /(\d{1,2})\s?월\s?(\d{1,2})\s?일/g, md: (m) => [+m[1], +m[2]] },
  ];

  const iso = (y, m, d) => y + '-' + String(m).padStart(2, '0') + '-' + String(d).padStart(2, '0');

  /** Schedules rarely show the year: pick the one that puts the date closest to `ref`. */
  function pickYear(month, day, ref) {
    let best = ref.getFullYear(), bestGap = Infinity;
    for (let y = ref.getFullYear() - 1; y <= ref.getFullYear() + 1; y++) {
      const gap = Math.abs(new Date(y, month - 1, day) - ref);
      if (gap < bestGap) { best = y; bestGap = gap; }
    }
    return best;
  }

  /** All dates on a line, each with the word range and x-extent it covers. */
  function findDates(line, ref) {
    const found = [];
    for (const p of DATE_PATTERNS) {
      p.re.lastIndex = 0;
      let m;
      while ((m = p.re.exec(line.text))) {
        const [month, day] = p.md(m);
        if (!(month >= 1 && month <= 12 && day >= 1 && day <= 31)) continue;
        const a = m.index, b = m.index + m[0].length - 1;
        if (found.some((f) => a <= f.b && b >= f.a)) continue;
        const wi0 = line.charWord[a], wi1 = line.charWord[b];
        const ws = line.words.slice(wi0, wi1 + 1);
        const x0 = Math.min(...ws.map((w) => w.x0)), x1 = Math.max(...ws.map((w) => w.x1));
        found.push({ date: iso(pickYear(month, day, ref), month, day), a, b, wi0, wi1, x0, x1, xc: (x0 + x1) / 2 });
      }
    }
    return found.sort((p, q) => p.a - q.a);
  }

  // ------------------------------------------------------------------ geometry
  const median = (arr) => {
    if (!arr.length) return 0;
    const s = [...arr].sort((a, b) => a - b);
    return s[Math.floor(s.length / 2)];
  };
  const xc = (w) => (w.x0 + w.x1) / 2;

  /** Group OCR words into text lines (top to bottom), each sorted left to right. */
  function groupLines(words) {
    const ws = words.filter((w) => w.text && w.text.trim()).map((w) => Object.assign({ yc: (w.y0 + w.y1) / 2 }, w));
    const h = median(ws.map((w) => w.y1 - w.y0)) || 10;
    ws.sort((a, b) => a.yc - b.yc);
    const lines = [];
    for (const w of ws) {
      const last = lines[lines.length - 1];
      if (last && Math.abs(w.yc - last.yc) < h * 0.6) {
        last.words.push(w);
        last.yc += (w.yc - last.yc) / last.words.length;
      } else lines.push({ yc: w.yc, words: [w] });
    }
    for (const l of lines) {
      l.words.sort((a, b) => a.x0 - b.x0);
      l.text = '';
      l.charWord = [];
      l.words.forEach((w, i) => {
        if (i) { l.text += ' '; l.charWord.push(i); }
        for (let k = 0; k < w.text.length; k++) l.charWord.push(i);
        l.text += w.text;
      });
    }
    return { lines, lineHeight: h };
  }

  const joinWords = (ws) => ws.map((w) => w.text).join(' ');
  const minConf = (ws) => (ws.length ? Math.min(...ws.map((w) => (w.conf == null ? 100 : w.conf))) : 0);

  /** Cluster x-centres into column centres. */
  function clusterColumns(xs, tol) {
    const s = [...xs].sort((a, b) => a - b);
    const cols = [];
    for (const x of s) {
      const last = cols[cols.length - 1];
      if (last && x - last.max <= tol) { last.sum += x; last.n++; last.max = x; }
      else cols.push({ sum: x, n: 1, max: x });
    }
    return cols.map((c) => c.sum / c.n);
  }

  function nearestIndex(centres, x, maxDist) {
    let best = -1, bestD = maxDist;
    centres.forEach((c, i) => { const d = Math.abs(c - x); if (d <= bestD) { best = i; bestD = d; } });
    return best;
  }

  // ------------------------------------------------------------------ legend (shift codes)
  /** Lines like "A  07:00 – 15:00" or "X  Day off" define what single-letter cells mean. */
  function findLegend(lines) {
    const codes = {};
    let shiftCodes = 0;
    for (const l of lines) {
      for (let i = 0; i < Math.min(3, l.words.length - 1); i++) {
        // anything before the code can only be a row number (OCR may misread it, e.g. "9" as "Ss")
        if (l.words.slice(0, i).some((w) => w.text.replace(NOISE, '').length > 2)) break;
        const tok = l.words[i].text.replace(NOISE, '').toUpperCase();
        if (!/^[A-Z]$/.test(tok)) continue;
        if (/^\p{L}$/u.test(l.words[i + 1].text.replace(NOISE, ''))) continue;   // "g B 15:00": B is the code
        const r = parseShift(joinWords(l.words.slice(i + 1)));
        if (r.kind === 'shift' || r.kind === 'off') {
          codes[tok] = r;
          if (r.kind === 'shift') shiftCodes++;
        }
        break;
      }
    }
    return shiftCodes ? codes : null;
  }

  // ------------------------------------------------------------------ weekday-only headers
  const DAY_INDEX = { sun: 0, mon: 1, tue: 2, wed: 3, thu: 4, fri: 5, sat: 6, '일': 0, '월': 1, '화': 2, '수': 3, '목': 4, '금': 5, '토': 6 };
  const DAY_TOKEN = /^(sun|mon|tue|wed|thu|fri|sat)[a-z]*\.?$|^([월화수목금토일])(요일)?$/i;

  /**
   * A header row of weekday names with no dates. The first column is dated as the most recent
   * such weekday on or before `weekOf`; the rest follow in order. The user must confirm the week.
   */
  function findWeekdayHeader(lines, weekOf) {
    let best = null;
    for (const line of lines) {
      const days = [];
      for (const w of line.words) {
        const m = DAY_TOKEN.exec(w.text.replace(NOISE, ''));
        if (m) days.push({ wd: DAY_INDEX[(m[1] || m[2]).slice(0, 3).toLowerCase()], xc: xc(w) });
      }
      if (days.length >= 3 && (!best || days.length > best.days.length)) best = { line, days };
    }
    if (!best) return null;
    const base = typeof weekOf === 'string' ? new Date(+weekOf.slice(0, 4), +weekOf.slice(5, 7) - 1, +weekOf.slice(8, 10)) : new Date(weekOf);
    base.setHours(12, 0, 0, 0);
    base.setDate(base.getDate() - ((base.getDay() - best.days[0].wd + 7) % 7));
    let offset = 0;
    const dates = best.days.map((d, i) => {
      if (i) offset += (d.wd - best.days[i - 1].wd + 7) % 7 || 7;
      const dt = new Date(base);
      dt.setDate(base.getDate() + offset);
      return { date: iso(dt.getFullYear(), dt.getMonth() + 1, dt.getDate()), xc: d.xc };
    });
    return { line: best.line, dates };
  }

  // ------------------------------------------------------------------ layouts
  function pickMatch(candidates) {
    const sorted = [...candidates].sort((a, b) => b.score - a.score);
    const best = sorted[0];
    if (!best || best.score < NAME_THRESHOLD) return { match: null, ambiguous: false };
    const second = sorted[1];
    const ambiguous = best.score < 0.9 || (!!second && second.score >= NAME_THRESHOLD && best.score - second.score < 0.1);
    return { match: best, ambiguous };
  }

  function cellsToShifts(cells, codes, out, hint24) {
    for (const c of cells) {
      const raw = joinWords(c.words);
      const r = parseShift(raw, codes, hint24);
      if (r.kind === 'shift') {
        out.shifts.push({
          date: c.date, start: r.start, end: r.end, overnight: r.overnight,
          assumed: r.assumed, toClose: r.toClose, raw: raw.replace(NOISE, ''), conf: minConf(c.words),
        });
      } else if (r.kind === 'unknown') out.issues.push({ date: c.date, raw: r.raw });
    }
  }

  function parseGrid(lines, header, dates, names, codes) {
    const cols = dates.slice().sort((a, b) => a.xc - b.xc);
    const centres = cols.map((c) => c.xc);
    const spacing = median(centres.slice(1).map((c, i) => c - centres[i])) || 60;
    const leftBound = centres[0] - spacing / 2;
    const rows = [];
    for (const l of lines) {
      if (l.yc <= header.yc) continue;
      const label = cleanLabel(joinWords(l.words.filter((w) => xc(w) < leftBound)));
      const cells = cols.map((c) => ({ date: c.date, words: [] }));
      for (const w of l.words) {
        if (xc(w) < leftBound) continue;
        const i = nearestIndex(centres, xc(w), spacing * 0.6);
        if (i >= 0) cells[i].words.push(w);
      }
      const filled = cells.filter((c) => parseShift(joinWords(c.words), codes).kind !== 'empty').length;
      if (letters(label).length < 2) continue;
      rows.push({ label, score: scoreName(label, names), cells, filled, yc: l.yc });
    }
    // Keep a name even if none of its cells could be read (e.g. text on dark cells), as long as the row
    // sits inside the table — between the first and last rows that do have shifts. Lines above or
    // below the table (titles, legends, notes) are still ignored.
    const ys = rows.filter((r) => r.filled).map((r) => r.yc);
    if (!ys.length) return [];
    const top = Math.min(...ys), bottom = Math.max(...ys);
    return rows.filter((r) => r.filled || (r.yc >= top && r.yc <= bottom));
  }

  function parseTransposed(lines, dateLines, names) {
    const first = dateLines[0];
    const cellWords = (dl) => dl.line.words.filter((w, i) => i > dl.d.wi1);
    const h = median(dateLines.map((dl) => dl.line.words[0].y1 - dl.line.words[0].y0)) || 10;
    const centres = clusterColumns(dateLines.flatMap((dl) => cellWords(dl).map(xc)), h);
    const spacing = median(centres.slice(1).map((c, i) => c - centres[i])) || 80;
    const headerLines = lines.filter((l) => l.yc < first.line.yc).slice(-3);
    // Each line above the dates is a possible header (a screenshot may also show spreadsheet column
    // letters or a title there). Per column, keep the label that looks most like the user's name;
    // if none does, keep the one closest to the data.
    const best = centres.map(() => ({ label: '', score: 0 }));
    for (const l of headerLines) {
      const parts = centres.map(() => []);
      for (const w of l.words) {
        const i = nearestIndex(centres, xc(w), spacing * 0.6);
        if (i >= 0) parts[i].push(w.text);
      }
      parts.forEach((p, i) => {
        const label = cleanLabel(p.join(' '));
        if (letters(label).length < 2) return;
        const score = scoreName(label, names);
        if (score >= best[i].score) best[i] = { label, score };
      });
    }
    return centres.map((c, i) => {
      const label = best[i].label;
      const cells = dateLines.map((dl) => ({
        date: dl.d.date,
        words: cellWords(dl).filter((w) => nearestIndex(centres, xc(w), spacing * 0.6) === i),
      }));
      return { label, score: scoreName(label, names), cells };
    }).filter((col) => letters(col.label).length >= 2);
  }

  function parseList(lines, dateLines, out, hint24) {
    const isDateLine = new Set(dateLines.map((dl) => dl.line));
    for (const dl of dateLines) {
      const idx = lines.indexOf(dl.line);
      const sameLine = dl.line.words.filter((w, i) => i > dl.d.wi1);
      const tries = [sameLine];
      for (let k = idx + 1; k <= idx + 2 && k < lines.length && !isDateLine.has(lines[k]); k++) tries.push(lines[k].words);
      for (const ws of tries) {
        const r = parseShift(joinWords(ws), null, hint24);
        if (r.kind === 'shift') {
          out.shifts.push({
            date: dl.d.date, start: r.start, end: r.end, overnight: r.overnight,
            assumed: r.assumed, toClose: r.toClose, raw: joinWords(ws).replace(NOISE, ''), conf: minConf(ws),
          });
          break;
        }
      }
    }
  }

  /**
   * Main entry point.
   * @param words OCR words [{text, conf, x0, y0, x1, y1}]
   * @param opts  {names: string[], refDate?: Date, weekOf?: 'YYYY-MM-DD' | Date}
   *              weekOf is only used when the schedule shows weekday names but no dates.
   * @returns {layout, shifts, issues, match, ambiguous, candidates, needsName, datesAssumed}
   */
  function extractShifts(words, opts) {
    const names = (opts.names || []).filter((n) => n && n.trim());
    const ref = opts.refDate || new Date();
    const { lines } = groupLines(words);
    const out = { layout: 'none', shifts: [], issues: [], match: null, ambiguous: false, candidates: [], needsName: false, datesAssumed: false };

    const hint24 = words.some((w) => /(?<![\d:])(1[3-9]|2[0-3]):[0-5]\d/.test(w.text));
    const dated = lines.map((line) => ({ line, dates: findDates(line, ref) })).filter((x) => x.dates.length);

    const useSeries = (series) => {
      out.candidates = series.map((s) => ({ label: s.label, score: +s.score.toFixed(2) })).sort((a, b) => b.score - a.score);
      const { match, ambiguous } = pickMatch(series);
      if (!match) { out.needsName = true; return; }
      out.match = { label: match.label, score: +match.score.toFixed(2) };
      out.ambiguous = ambiguous;
      return match;
    };

    // grid: one line holds a row of dates
    let header = dated.length ? dated.reduce((a, b) => (b.dates.length > a.dates.length ? b : a)) : null;
    if (!header || header.dates.length < 3) {
      // no dates in the header? try weekday names (SUN MON TUE ...) and date them from the chosen week
      const wk = findWeekdayHeader(lines, opts.weekOf || ref);
      if (wk) { header = wk; out.datesAssumed = true; out.weekStart = wk.dates[0].date; }
    }
    if (header && header.dates.length >= 3) {
      out.layout = 'grid';
      const codes = findLegend(lines);
      const match = useSeries(parseGrid(lines, header.line, header.dates, names, codes));
      if (match) cellsToShifts(match.cells, codes, out, hint24);
      return finish(out);
    }
    if (!dated.length) return out;

    // lines that START with a date (only a weekday or row number may come before it)
    const dateLines = dated.map(({ line, dates }) => ({ line, d: dates[0] }))
      .filter(({ line, d }) => line.words.slice(0, d.wi0).every((w) => WEEKDAY.test(w.text) || !/\p{L}/u.test(w.text)));
    if (!dateLines.length) return out;

    // transposed: a date row carries several people's shifts
    const multi = dateLines.some(({ line, d }) => {
      const rest = joinWords(line.words.filter((w, i) => i > d.wi1));
      return (rest.match(new RegExp(TIME_RANGE.source, 'gi')) || []).length >= 2;
    });
    if (multi) {
      out.layout = 'transposed';
      const match = useSeries(parseTransposed(lines, dateLines, names));
      if (match) cellsToShifts(match.cells, null, out, hint24);
      return finish(out);
    }

    out.layout = 'list';
    parseList(lines, dateLines, out, hint24);
    return finish(out);
  }

  function finish(out) {
    out.shifts.sort((a, b) => (a.date + a.start).localeCompare(b.date + b.start));
    return out;
  }

  // ------------------------------------------------------------------ calendar export (.ics)
  // Text from the user (workplace name) must never start a new calendar line:
  // any line break becomes "\n" text, and other control characters are dropped.
  const icsEscape = (s) => String(s)
    .replace(/\\/g, '\\\\').replace(/;/g, '\\;').replace(/,/g, '\\,')
    .replace(/\r\n|\r|\n/g, '\\n')
    .replace(/[\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f]/g, '');
  const icsFold = (line) => line.replace(/(.{60})(?=.)/gu, '$1\r\n ');
  const addDays = (isoDate, n) => {
    const [y, m, d] = isoDate.split('-').map(Number);
    const dt = new Date(Date.UTC(y, m - 1, d + n));
    return iso(dt.getUTCFullYear(), dt.getUTCMonth() + 1, dt.getUTCDate());
  };
  const icsLocal = (isoDate, time) => isoDate.replace(/-/g, '') + 'T' + time.replace(':', '') + '00';
  const mins = (t) => +t.slice(0, 2) * 60 + +t.slice(3, 5);
  const pretty = (t) => {
    const h = +t.slice(0, 2), m = t.slice(3, 5);
    return ((h + 11) % 12 + 1) + ':' + m + ' ' + (h < 12 ? 'AM' : 'PM');
  };

  /**
   * Build an .ics calendar (works in Google Calendar, Outlook and Apple Calendar).
   * @param shifts [{date:'YYYY-MM-DD', start:'HH:MM', end:'HH:MM'}]  end <= start means it ends the next day
   * @param opts   {workplace, wakeMinutes?: number, reminderTime?: 'HH:MM' (evening before), now?: Date}
   * Times are "floating" local times: 06:00 means 06:00 wherever the phone is.
   */
  function buildICS(shifts, opts) {
    const workplace = opts.workplace || 'Work';
    const stamp = (opts.now || new Date()).toISOString().replace(/[-:]/g, '').replace(/\.\d+/, '');
    const slug = letters(workplace) || 'work';
    const L = ['BEGIN:VCALENDAR', 'VERSION:2.0', 'PRODID:-//ReadySet//Shift Schedule//EN', 'CALSCALE:GREGORIAN', 'METHOD:PUBLISH'];
    for (const s of shifts) {
      const endDate = mins(s.end) <= mins(s.start) ? addDays(s.date, 1) : s.date;
      L.push('BEGIN:VEVENT',
        'UID:' + s.date + 'T' + s.start.replace(':', '') + '-' + slug + '@readyset.local',
        'DTSTAMP:' + stamp,
        'DTSTART:' + icsLocal(s.date, s.start),
        'DTEND:' + icsLocal(endDate, s.end),
        'SUMMARY:' + icsEscape('Work · ' + workplace),
        'DESCRIPTION:' + icsEscape(pretty(s.start) + ' – ' + pretty(s.end) + ' at ' + workplace + '. Added by ReadySet.'));
      if (opts.wakeMinutes > 0) {
        L.push('BEGIN:VALARM', 'ACTION:DISPLAY', 'TRIGGER:-PT' + Math.round(opts.wakeMinutes) + 'M',
          'DESCRIPTION:' + icsEscape('Wake up — ' + workplace + ' at ' + pretty(s.start)), 'END:VALARM');
      }
      if (opts.reminderTime) {
        const before = mins(s.start) + 1440 - mins(opts.reminderTime);   // minutes from "evening before" to shift start
        L.push('BEGIN:VALARM', 'ACTION:DISPLAY', 'TRIGGER:-PT' + before + 'M',
          'DESCRIPTION:' + icsEscape('Tomorrow: ' + workplace + ' at ' + pretty(s.start)), 'END:VALARM');
      }
      L.push('END:VEVENT');
    }
    L.push('END:VCALENDAR');
    return L.map(icsFold).join('\r\n') + '\r\n';
  }

  return { extractShifts, parseShift, scoreName, buildICS, groupLines, findDates, findLegend, NAME_THRESHOLD };
});
"""#
}
