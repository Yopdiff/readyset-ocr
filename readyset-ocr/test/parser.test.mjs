// Run: npm test      (uses cached OCR output in test/ocr-cache; refresh it with: npm run ocr)
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import RS from '../parser.js';

const expected = JSON.parse(fs.readFileSync(new URL('../../mock-schedules/expected.json', import.meta.url), 'utf8'));
const NAMES = ['Jamie Park', '박제이미'];
const REF = new Date(2026, 9, 20);

test('parseShift: time formats', () => {
  const t = (raw, start, end, extra = {}) => {
    const r = RS.parseShift(raw);
    assert.equal(r.kind, 'shift', raw);
    assert.deepEqual([r.start, r.end], [start, end], raw);
    for (const k in extra) assert.equal(r[k], extra[k], raw + ' ' + k);
  };
  t('6-1:30', '06:00', '13:30', { assumed: true });
  t('7-2', '07:00', '14:00');
  t('12-6', '12:00', '18:00');
  t('1:30-8', '13:30', '20:00');
  t('8-4', '08:00', '16:00');
  t('5p-10p', '17:00', '22:00', { assumed: false });
  t('6p-12a', '18:00', '00:00', { overnight: true });
  t('11a-4p', '11:00', '16:00');
  t('11-4p', '11:00', '16:00');
  t('06:00~13:30', '06:00', '13:30', { assumed: false });
  t('05:30%12:00', '05:30', '12:00');          // OCR misreads "~"
  t('= 12:00^~18:00.', '12:00', '18:00');
  t('23:00 - 07:00', '23:00', '07:00', { overnight: true });
  t('3:00 PM – 9:00 PM 6h', '15:00', '21:00');
  t('4p-CL', '16:00', null, { toClose: true });
  t('530-1330', '05:30', '13:30');               // colon dropped by OCR, or military style
  t('0600-1430', '06:00', '14:30');
  assert.equal(RS.parseShift('5:30 - 11:00', null, true).assumed, false);   // 24h sheet hint
  for (const off of ['OFF', '휴무', '-', 'X', 'Day off']) assert.equal(RS.parseShift(off).kind, 'off', off);
  assert.equal(RS.parseShift('612').kind, 'unknown');
  assert.equal(RS.parseShift(' | ').kind, 'empty');
});

test('scoreName: picks the user, not the look-alike', () => {
  const s = (label) => RS.scoreName(label, NAMES);
  assert.ok(s('Jamie Park') > 0.95);
  assert.ok(s('4 | Jamie Park') > 0.95);
  assert.ok(s('Jamie Lee') < RS.NAME_THRESHOLD);
  assert.ok(s('J. Park') > s('J. Parks'));
  assert.ok(s('Park, J.') >= RS.NAME_THRESHOLD);
  assert.ok(s('Kim, S.') < RS.NAME_THRESHOLD);
  assert.ok(s('박제이미') > 0.95);
  assert.ok(s('김민지') < RS.NAME_THRESHOLD);
});

test('legend: shift codes survive a misread row number in front', () => {
  const line = (y, ...texts) => texts.map((text, i) => ({ text, x0: i * 60, x1: i * 60 + 40, y0: y, y1: y + 12 }));
  const { lines } = RS.groupLines([...line(0, 'Ss', 'A', '07:00', '—', '15:00'), ...line(30, 'g', 'B', '15:00', '-', '23:00'),
    ...line(60, '12', 'X', 'Day', 'off'), ...line(90, '2', 'M.', 'Alvarez', 'A', 'A', 'X')]);
  const codes = RS.findLegend(lines);
  assert.deepEqual(Object.keys(codes).sort(), ['A', 'B', 'X']);
  assert.equal(codes.A.start, '07:00');
  assert.equal(codes.B.end, '23:00');
  assert.equal(codes.X.kind, 'off');
});

for (const [name, exp] of Object.entries(expected.formats)) {
  test('fixture ' + name, () => {
    const words = JSON.parse(fs.readFileSync(new URL('./ocr-cache/' + name + '.json', import.meta.url), 'utf8'));
    const out = RS.extractShifts(words, { names: NAMES, refDate: REF, weekOf: exp.week_of });
    const got = out.shifts.map((s) => [s.date, s.start, s.end]);
    const want = exp.shifts.map((s) => [s.date, s.start, s.end]);
    console.log(`  ${name}: layout=${out.layout} match=${JSON.stringify(out.match)} ambiguous=${out.ambiguous} issues=${JSON.stringify(out.issues)}`);
    assert.deepEqual(got, want);
  });
}

test('buildICS: event, overnight end, both reminders', () => {
  const ics = RS.buildICS([{ date: '2026-10-30', start: '18:00', end: '00:00' }],
    { workplace: 'Restaurant B', wakeMinutes: 120, reminderTime: '20:00', now: new Date(Date.UTC(2026, 9, 20)) });
  assert.match(ics, /DTSTART:20261030T180000\r\n/);
  assert.match(ics, /DTEND:20261031T000000\r\n/);
  assert.match(ics, /TRIGGER:-PT120M/);
  assert.match(ics, /TRIGGER:-PT1320M/);       // 8 PM the evening before an 18:00 shift = 22h
  assert.equal((ics.match(/BEGIN:VALARM/g) || []).length, 2);
});
