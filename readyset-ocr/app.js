/* ReadySet prototype UI: upload → OCR (in the browser) → review → download .ics
 * Everything runs locally; the screenshot never leaves the device. */
(function () {
  'use strict';
  const $ = (id) => document.getElementById(id);

  // ---------------------------------------------------------------- saved settings
  const store = {
    get(key, fallback) { try { return JSON.parse(localStorage.getItem(key)) ?? fallback; } catch { return fallback; } },
    set(key, value) { try { localStorage.setItem(key, JSON.stringify(value)); } catch { /* private mode: fine */ } },
  };
  const settings = Object.assign({
    name: '', wake: 120, reminderOn: true, reminderTime: '20:00', current: 0,
    // aliases = how this workplace writes the user's name, learned when the user confirms a match
    workplaces: [{ name: 'Café A', korean: false, aliases: [] }, { name: 'Restaurant B', korean: false, aliases: [] }, { name: 'Bakery C', korean: true, aliases: [] }],
  }, store.get('readyset.settings', {}));
  const save = () => store.set('readyset.settings', settings);
  const workplace = () => settings.workplaces[settings.current] || settings.workplaces[0];

  const SAMPLES = [
    { file: 'A_cafe_weekly_grid.png', label: 'Café A · grid', workplace: 'Café A' },
    { file: 'B_restaurant_transposed.png', label: 'Restaurant B · flipped', workplace: 'Restaurant B' },
    { file: 'C_bakery_korean.png', label: 'Bakery C · 한국어', workplace: 'Bakery C', korean: true },
    { file: 'D_grocery_app_dark.png', label: 'Grocery D · app', workplace: 'Grocery D' },
    { file: 'E_hotel_codes_2week.png', label: 'Hotel E · codes', workplace: 'Hotel E' },
    { file: 'F_diner_weekdays_colour.png', label: 'Diner F · no dates', workplace: 'Diner F' },
  ];

  const state = { file: null, imageURL: null, words: null, result: null, shifts: [], weekOf: null, editing: -1, pickName: false };

  // ---------------------------------------------------------------- small helpers
  function h(tag, props, ...children) {
    const el = document.createElement(tag);
    for (const [k, v] of Object.entries(props || {})) {
      if (k === 'class') el.className = v;
      else if (k.startsWith('on')) el.addEventListener(k.slice(2), v);
      else if (v !== false && v != null) el.setAttribute(k, v === true ? '' : v);
    }
    for (const c of children.flat()) if (c != null && c !== false) el.append(c);
    return el;
  }
  const prettyDate = (iso) => new Date(+iso.slice(0, 4), +iso.slice(5, 7) - 1, +iso.slice(8, 10))
    .toLocaleDateString('en-US', { weekday: 'short', month: 'short', day: 'numeric' });
  const prettyTime = (t) => { const hh = +t.slice(0, 2); return ((hh + 11) % 12 + 1) + ':' + t.slice(3, 5) + ' ' + (hh < 12 ? 'AM' : 'PM'); };
  const todayISO = () => { const d = new Date(); return d.getFullYear() + '-' + String(d.getMonth() + 1).padStart(2, '0') + '-' + String(d.getDate()).padStart(2, '0'); };

  // ---------------------------------------------------------------- screen 1: add schedule
  function renderWorkplaces() {
    const sel = $('workplace');
    sel.replaceChildren(...settings.workplaces.map((w, i) => h('option', { value: i }, w.name)), h('option', { value: 'new' }, '+ Add workplace…'));
    sel.value = String(settings.current);
    $('korean').checked = !!workplace().korean;
  }

  function setFile(file) {
    state.file = file;
    if (state.imageURL) URL.revokeObjectURL(state.imageURL);
    state.imageURL = URL.createObjectURL(file);
    $('drop').replaceChildren(h('img', { src: state.imageURL, alt: 'Selected schedule' }), h('span', { class: 'small' }, 'Tap to change'));
    $('add-error').hidden = true;
    updateGo();
  }
  const updateGo = () => { $('go').disabled = !state.file; };

  function selectWorkplace(name, korean) {
    let i = settings.workplaces.findIndex((w) => w.name === name);
    if (i < 0) { settings.workplaces.push({ name, korean: !!korean, aliases: [] }); i = settings.workplaces.length - 1; }
    settings.current = i;
    save();
    renderWorkplaces();
  }

  async function useSample(s) {
    const blob = await (await fetch('samples/' + s.file)).blob();
    selectWorkplace(s.workplace, s.korean);
    if (!$('name').value.trim()) { $('name').value = 'Jamie Park'; settings.name = 'Jamie Park'; save(); }
    setFile(new File([blob], s.file, { type: 'image/png' }));
  }

  // ---------------------------------------------------------------- OCR
  const workers = {};
  let onProgress = () => {};
  async function getWorker(korean) {
    const key = korean ? 'kor' : 'eng';
    if (!workers[key]) workers[key] = await Tesseract.createWorker(korean ? ['kor', 'eng'] : ['eng'], 1, {
      workerPath: 'vendor/worker.min.js', corePath: 'vendor/core',   // OCR engine is bundled; only language data is downloaded (once)
      logger: (m) => onProgress(m),
    });
    return workers[key];
  }

  async function readWords(file, korean) {
    const bitmap = await createImageBitmap(file);
    const scale = ReadySetPrep.chooseScale(bitmap.width, bitmap.height);
    const canvas = document.createElement('canvas');
    canvas.width = Math.round(bitmap.width * scale);
    canvas.height = Math.round(bitmap.height * scale);
    const ctx = canvas.getContext('2d', { willReadFrequently: true });
    ctx.imageSmoothingQuality = 'high';
    ctx.drawImage(bitmap, 0, 0, canvas.width, canvas.height);
    const pixels = ctx.getImageData(0, 0, canvas.width, canvas.height);
    ReadySetPrep.prepare(pixels.data, canvas.width, canvas.height, scale);
    ctx.putImageData(pixels, 0, 0);

    const worker = await getWorker(korean);
    const { data } = await worker.recognize(canvas);
    return (data.words || []).map((w) => ({
      text: w.text, conf: Math.round(w.confidence),
      x0: w.bbox.x0 / scale, y0: w.bbox.y0 / scale, x1: w.bbox.x1 / scale, y1: w.bbox.y1 / scale,
    }));
  }

  async function findShifts() {
    settings.name = $('name').value.trim();
    workplace().korean = $('korean').checked;
    save();
    $('go').disabled = true;
    $('add-error').hidden = true;
    $('progress').hidden = false;
    onProgress = (m) => {
      const loading = m.status !== 'recognizing text';
      $('progress-text').textContent = loading ? 'Getting the text reader ready… (first time only)' : 'Reading your schedule…';
      $('progress-bar').style.width = Math.round((loading ? 0.1 : 0.1 + m.progress * 0.9) * 100) + '%';
    };
    try {
      state.words = await readWords(state.file, workplace().korean);
      state.weekOf = null;
      parse();
      show('review');
    } catch (err) {
      console.error(err);
      $('add-error').textContent = 'Something went wrong while reading the image. Check your connection (the text reader downloads once) and try again.';
      $('add-error').hidden = false;
    } finally {
      $('progress').hidden = true;
      updateGo();
    }
  }

  function parse() {
    const names = [settings.name, ...workplace().aliases];
    state.result = ReadySet.extractShifts(state.words, { names, weekOf: state.weekOf || undefined });
    state.shifts = state.result.shifts.map((s) => Object.assign({}, s));
    state.editing = -1;
    state.pickName = false;
    $('done').hidden = true;
    renderReview();
  }

  // ---------------------------------------------------------------- screen 2: review
  function confirmAlias(label) {
    if (!workplace().aliases.includes(label)) workplace().aliases.push(label);
    save();
    parse();
  }

  function renderNotices() {
    const r = state.result, box = $('notices'), out = [];
    const chips = () => h('div', { class: 'chips' }, r.candidates.slice(0, 12).map((c) =>
      h('button', { class: 'chip', onclick: () => confirmAlias(c.label) }, c.label)));

    if (r.layout === 'none') {
      out.push(h('div', { class: 'notice bad' }, h('b', {}, "We couldn't find a schedule in this image. "),
        'Try a sharper screenshot that shows the dates or weekdays, or add your shifts by hand below.'));
    } else if (r.needsName) {
      out.push(h('div', { class: 'notice' },
        h('b', {}, settings.name ? `We couldn't find “${settings.name}” on this schedule. ` : 'Which one is you? '),
        r.candidates.length ? 'Tap your name and we\'ll remember it for ' + workplace().name + '.' : 'No names could be read.', chips()));
    } else if (r.match && (r.ambiguous || state.pickName)) {
      out.push(h('div', { class: 'notice' }, h('b', {}, `We matched “${r.match.label}”. `), 'Is that you?',
        state.pickName ? chips() : h('div', { class: 'chips' },
          h('button', { class: 'chip', onclick: () => confirmAlias(r.match.label) }, 'Yes, that\'s me'),
          h('button', { class: 'chip', onclick: () => { state.pickName = true; renderNotices(); } }, 'No, show names'))));
    } else if (r.match) {
      out.push(h('div', { class: 'notice ok' }, 'Showing shifts for ', h('b', {}, r.match.label), ' at ' + workplace().name + '. ',
        h('button', { class: 'chip', style: 'margin-left:4px;padding:2px 10px', onclick: () => { state.pickName = true; renderNotices(); } }, 'Not you?')));
    }
    for (const issue of r.issues) {
      out.push(h('div', { class: 'notice' }, h('b', {}, prettyDate(issue.date) + ': '), `couldn't read “${issue.raw}”. If you work that day, add it below.`));
    }
    box.replaceChildren(...out);
  }

  function shiftRow(s, i) {
    const needsEnd = !s.end;
    if (state.editing === i) {
      const field = (label, type, key, cls) => h('div', { class: cls || '' }, h('label', {}, label),
        h('input', { type, value: s[key] || '', 'aria-label': label, onchange: (e) => { s[key] = e.target.value; } }));
      return h('div', { class: 'shift' },
        h('div', { class: 'edit' }, field('Date', 'date', 'date', 'full'), field('Starts', 'time', 'start'), field('Ends', 'time', 'end'),
          h('button', { class: 'ghost', onclick: () => { state.shifts.splice(i, 1); state.editing = -1; renderShifts(); } }, 'Delete'),
          h('button', { class: 'ghost', style: 'background:#2b2b2b;color:#fff;border-color:#2b2b2b', onclick: () => {
            if (!s.date || !s.start) return;
            s.assumed = false; s.toClose = false; s.edited = true; state.editing = -1; renderShifts();
          } }, 'Done')));
    }
    const overnight = s.end && s.end <= s.start;
    const tags = [
      needsEnd && h('span', { class: 'tag bad' }, s.toClose ? 'Ends at close — set an end time' : 'Set an end time'),
      s.assumed && h('span', { class: 'tag' }, 'AM/PM guessed — check'),
      overnight && h('span', { class: 'tag plain' }, 'Ends next day'),
      !s.edited && s.conf != null && s.conf < 60 && h('span', { class: 'tag' }, 'Hard to read — check'),
    ].filter(Boolean);
    return h('div', { class: 'shift' + (needsEnd ? ' needs' : '') },
      h('div', { class: 'line' },
        h('span', { class: 'date' }, prettyDate(s.date)),
        h('span', { class: 'time' }, prettyTime(s.start) + ' – ' + (s.end ? prettyTime(s.end) : '?')),
        h('button', { class: 'icon', 'aria-label': 'Edit shift on ' + prettyDate(s.date), onclick: () => { state.editing = i; renderShifts(); } }, '✎')),
      tags.length ? h('div', { class: 'tags' }, tags) : null);
  }

  function renderShifts() {
    state.shifts.sort((a, b) => (a.date + a.start).localeCompare(b.date + b.start));
    $('shifts').replaceChildren(...state.shifts.map(shiftRow));
    const n = state.shifts.length;
    $('count').textContent = n === 1 ? '1 shift found' : n + ' shifts found';
    $('export').disabled = !n || state.shifts.some((s) => !s.end || !s.date || !s.start);
    $('export').textContent = n ? `Add my ${n === 1 ? 'shift' : n + ' shifts'}` : 'Add my shifts';
  }

  function renderReview() {
    $('thumb').src = state.imageURL;
    renderNotices();
    $('week-field').hidden = !state.result.datesAssumed;
    if (state.result.datesAssumed) $('week').value = state.result.weekStart;
    $('wake').value = String(settings.wake);
    $('reminder-on').checked = settings.reminderOn;
    $('reminder-time').value = settings.reminderTime;
    renderShifts();
  }

  function exportICS() {
    const ics = ReadySet.buildICS(state.shifts, {
      workplace: workplace().name,
      wakeMinutes: settings.wake,
      reminderTime: settings.reminderOn ? settings.reminderTime : null,
    });
    const slug = workplace().name.toLowerCase().normalize('NFD').replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '') || 'work';
    const filename = `readyset-${slug}-${state.shifts[0].date}.ics`;
    const a = h('a', { href: URL.createObjectURL(new Blob([ics], { type: 'text/calendar' })), download: filename });
    document.body.append(a);
    a.click();
    a.remove();
    setTimeout(() => URL.revokeObjectURL(a.href), 5000);
    $('done').replaceChildren(h('b', {}, `Saved ${filename}. `),
      'Open it to add the shifts to your calendar. In Google Calendar on the web: Settings → Import & export → Import.');
    $('done').hidden = false;
    return ics;
  }

  function show(screen) {
    $('screen-add').hidden = screen !== 'add';
    $('screen-review').hidden = screen !== 'review';
    window.scrollTo(0, 0);
  }

  // ---------------------------------------------------------------- wiring
  $('samples').replaceChildren(...SAMPLES.map((s) => h('button', { class: 'chip', onclick: () => useSample(s) }, s.label)));
  $('name').value = settings.name;
  renderWorkplaces();

  $('drop').addEventListener('click', () => $('file').click());
  $('drop').addEventListener('keydown', (e) => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); $('file').click(); } });
  $('file').addEventListener('change', (e) => { if (e.target.files[0]) setFile(e.target.files[0]); });
  $('drop').addEventListener('dragover', (e) => { e.preventDefault(); $('drop').classList.add('over'); });
  $('drop').addEventListener('dragleave', () => $('drop').classList.remove('over'));
  $('drop').addEventListener('drop', (e) => {
    e.preventDefault();
    $('drop').classList.remove('over');
    const f = [...e.dataTransfer.files].find((x) => x.type.startsWith('image/'));
    if (f) setFile(f);
  });
  document.addEventListener('paste', (e) => {
    const f = [...(e.clipboardData?.files || [])].find((x) => x.type.startsWith('image/'));
    if (f && !$('screen-add').hidden) setFile(f);
  });

  $('workplace').addEventListener('change', (e) => {
    const isNew = e.target.value === 'new';
    $('new-workplace').hidden = !isNew;
    if (isNew) { $('new-workplace').focus(); return; }
    settings.current = +e.target.value;
    save();
    $('korean').checked = !!workplace().korean;
  });
  $('new-workplace').addEventListener('change', (e) => {
    const name = e.target.value.trim();
    if (!name) return;
    selectWorkplace(name, $('korean').checked);
    e.target.value = '';
    e.target.hidden = true;
  });
  $('name').addEventListener('change', (e) => { settings.name = e.target.value.trim(); save(); });
  $('go').addEventListener('click', findShifts);

  $('back').addEventListener('click', () => show('add'));
  $('week').addEventListener('change', (e) => { if (e.target.value) { state.weekOf = e.target.value; parse(); } });
  $('add-shift').addEventListener('click', () => {
    const last = state.shifts[state.shifts.length - 1];
    state.shifts.push({ date: last ? last.date : todayISO(), start: last ? last.start : '09:00', end: last ? last.end : '17:00', edited: true });
    state.editing = state.shifts.length - 1;
    renderShifts();
  });
  $('wake').addEventListener('change', (e) => { settings.wake = +e.target.value; save(); });
  $('reminder-on').addEventListener('change', (e) => { settings.reminderOn = e.target.checked; save(); });
  $('reminder-time').addEventListener('change', (e) => { if (e.target.value) { settings.reminderTime = e.target.value; save(); } });
  $('export').addEventListener('click', exportICS);

  // for the end-to-end check in the browser console
  window.ReadySetApp = { state, settings, exportICS: () => ReadySet.buildICS(state.shifts, { workplace: workplace().name, wakeMinutes: settings.wake, reminderTime: settings.reminderOn ? settings.reminderTime : null }) };
})();
