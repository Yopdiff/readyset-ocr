# ReadySet

Turn a screenshot of your work schedule into calendar events with reminders.

No AI, no server. Everything runs in your browser.

## Run

```bash
cd readyset-ocr
python -m http.server 5173
```

Open http://localhost:5173, upload a schedule screenshot (or tap a sample), check the shifts, and download the `.ics` file. It works with Google Calendar, Outlook and Apple Calendar.

## Test

```bash
cd readyset-ocr
npm install
npm test
```

## Folders

- `readyset-ocr/` — the app
- `mock-schedules/` — sample schedules used for testing
