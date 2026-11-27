// Copies web/parser.js into the iOS app (ios/ReadySet.swiftpm/Scanning/ParserScript.swift).
// parser.js is the one source of truth: edit it, run `npm run sync-ios`, commit both files.
//   node scripts/sync-ios.mjs          write ParserScript.swift
//   node scripts/sync-ios.mjs --check  exit 1 if ParserScript.swift is out of date
import fs from 'node:fs';
import { pathToFileURL } from 'node:url';

const PARSER = new URL('../parser.js', import.meta.url);
export const SWIFT = new URL('../../ios/ReadySet.swiftpm/Scanning/ParserScript.swift', import.meta.url);

export function swiftSource() {
  const js = fs.readFileSync(PARSER, 'utf8').replace(/\r\n/g, '\n').replace(/\n+$/, '');
  if (js.includes('"""#')) throw new Error('parser.js contains """# which would end the Swift string early');
  return [
    '/// GENERATED from web/parser.js by `npm run sync-ios` (in web/). Do not edit here.',
    '/// Edit web/parser.js, then run the script again.',
    'enum ParserScript {',
    '    static let source = #"""',
    js,
    '"""#',
    '}',
    '',
  ].join('\n');
}

export function isUpToDate() {
  const have = fs.existsSync(SWIFT) ? fs.readFileSync(SWIFT, 'utf8').replace(/\r\n/g, '\n') : '';
  return have === swiftSource();
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  if (process.argv.includes('--check')) {
    if (!isUpToDate()) {
      console.error('ParserScript.swift is out of date. Run: npm run sync-ios');
      process.exit(1);
    }
    console.log('ParserScript.swift is up to date.');
  } else {
    fs.writeFileSync(SWIFT, swiftSource());
    console.log('Wrote ios/ReadySet.swiftpm/Scanning/ParserScript.swift');
  }
}
