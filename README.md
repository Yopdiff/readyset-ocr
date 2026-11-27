# ReadySet

Take a screenshot of your work schedule. ReadySet finds your shifts and sets your wake-up alarms.

## Folders

- `ios/` — the iPhone app (Swift). Open `ReadySet.swiftpm` in Xcode or Swift Playgrounds.
- `web/` — browser prototype and the shared schedule parser (`parser.js`)
- `mock-schedules/` — sample schedules for testing
- `docs/` — notes, including the iOS code review and what's left to do

## Changing the parser

`web/parser.js` is the only copy to edit. The iPhone app uses it too.

```bash
cd web
npm install
npm run sync-ios
npm test
```

`npm run sync-ios` copies it into the app. `npm test` fails if you forget.

## Try the web prototype

```bash
cd web
python -m http.server 5173 --bind 127.0.0.1
```

Then open http://localhost:5173. (`--bind 127.0.0.1` keeps other devices on your Wi-Fi from opening it.)
