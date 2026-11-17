"""Generate mock work-schedule files for ReadySet OCR testing.

Outputs (next to this script):
  schedules.xlsx         - one sheet per spreadsheet-style format
  png/*.png              - "screenshots" of each format (rendered with Edge headless)
  html/*.html            - the HTML used to render each screenshot
  expected.json          - answer key: the shifts that belong to the test user

Test user: Jamie Park. Week: Mon 2026-10-26 .. Sun 2026-11-01 (Hotel E spans 2 weeks).
Run:  python generate.py
"""
import json
import os
import subprocess
from datetime import date, timedelta

from openpyxl import Workbook
from openpyxl.styles import Alignment, Border, Font, PatternFill, Side

HERE = os.path.dirname(os.path.abspath(__file__))
PNG = os.path.join(HERE, "png")
HTML = os.path.join(HERE, "html")
os.makedirs(PNG, exist_ok=True)
os.makedirs(HTML, exist_ok=True)

EDGE = r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
USER = "Jamie Park"
WEEK = [date(2026, 10, 26) + timedelta(days=i) for i in range(7)]
EN_DAYS = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
KO_DAYS = ["월", "화", "수", "목", "금", "토", "일"]

# ---------------------------------------------------------------- formats
# Each format: grid (list of rows, first row = header), plus answer key.

# A. Café A - classic weekly grid: staff rows x day columns, "6-1:30" style times.
cafe_header = ["Name"] + [f"{EN_DAYS[i]} {d.month}/{d.day}" for i, d in enumerate(WEEK)]
cafe_rows = [
    ["Sarah Thompson", "6-12", "6-12", "OFF", "OFF", "12-6", "8-4", "8-4"],
    ["Jamie Lee", "12-6", "OFF", "6-1:30", "6-1:30", "OFF", "12-6", "OFF"],
    ["Jamie Park", "6-1:30", "7-2", "OFF", "6-12", "OFF", "8-4", "OFF"],
    ["Daniel Cho", "OFF", "12-6", "12-6", "OFF", "6-1:30", "OFF", "12-6"],
    ["Priya Nair", "1:30-8", "1:30-8", "1:30-8", "12-6", "OFF", "OFF", "8-4"],
    ["Marcus Bell", "OFF", "6-12", "6-12", "1:30-8", "1:30-8", "4-8", "OFF"],
]
cafe_expected = [
    ("2026-10-26", "06:00", "13:30"),
    ("2026-10-27", "07:00", "14:00"),
    ("2026-10-29", "06:00", "12:00"),
    ("2026-10-31", "08:00", "16:00"),
]

# B. Restaurant B - transposed: date rows x staff columns, "5p-10p" style, one overnight.
rest_header = ["Date", "Kim, S.", "Park, J.", "Nguyen, T.", "Rossi, M.", "Ahmed, R."]
rest_rows = [
    ["Mon Oct 26", "4p-10p", "-", "5p-11p", "-", "11a-4p"],
    ["Tue Oct 27", "-", "5p-10p", "4p-10p", "11a-4p", "-"],
    ["Wed Oct 28", "11a-4p", "-", "-", "5p-11p", "4p-10p"],
    ["Thu Oct 29", "5p-11p", "-", "11a-4p", "-", "5p-10p"],
    ["Fri Oct 30", "4p-10p", "6p-12a", "5p-11p", "4p-CL", "-"],
    ["Sat Oct 31", "11a-4p", "-", "4p-CL", "5p-11p", "4p-10p"],
    ["Sun Nov 1", "-", "11a-4p", "-", "11a-4p", "5p-10p"],
]
rest_expected = [
    ("2026-10-27", "17:00", "22:00"),
    ("2026-10-30", "18:00", "00:00", "overnight: ends 2026-10-31 00:00"),
    ("2026-11-01", "11:00", "16:00"),
]

# C. Bakery C - Korean sheet, "06:00~13:30" style, 휴무 = day off, name in Korean.
bak_title = "10월 5주차 근무표 (10/26 ~ 11/1)"
bak_header = ["이름"] + [f"{KO_DAYS[i]} ({d.month}/{d.day})" for i, d in enumerate(WEEK)]
bak_rows = [
    ["김민지", "05:30~12:00", "05:30~12:00", "휴무", "05:30~12:00", "휴무", "06:00~14:00", "06:00~14:00"],
    ["이서준", "휴무", "12:00~18:00", "12:00~18:00", "휴무", "12:00~18:00", "12:00~18:00", "휴무"],
    ["박제이미", "휴무", "휴무", "06:00~11:00", "휴무", "휴무", "휴무", "06:00~10:00"],
    ["최유나", "12:00~18:00", "휴무", "05:30~12:00", "12:00~18:00", "05:30~12:00", "휴무", "12:00~17:00"],
    ["정하늘", "06:00~14:00", "06:00~14:00", "휴무", "06:00~14:00", "06:00~14:00", "휴무", "휴무"],
]
bak_expected = [
    ("2026-10-28", "06:00", "11:00"),
    ("2026-11-01", "06:00", "10:00"),
]

# D. Grocery D - scheduling-app screenshot (mobile, dark mode, card list, no names).
groc_cards = [
    ("Mon, Oct 26", "3:00 PM – 9:00 PM", "Cashier · Front End", "6h"),
    ("Thu, Oct 29", "2:00 PM – 8:00 PM", "Stocking · Aisle 4-7", "6h"),
    ("Sat, Oct 31", "5:00 PM – 10:00 PM", "Cashier · Front End", "5h"),
]
groc_expected = [
    ("2026-10-26", "15:00", "21:00"),
    ("2026-10-29", "14:00", "20:00"),
    ("2026-10-31", "17:00", "22:00"),
]

# E. Hotel E - two-week grid with shift CODES + legend, decoy name "J. Parks".
hotel_days = [date(2026, 10, 26) + timedelta(days=i) for i in range(14)]
hotel_legend = [("A", "07:00 – 15:00"), ("B", "15:00 – 23:00"), ("N", "23:00 – 07:00"), ("X", "Day off")]
hotel_codes = {
    "M. Alvarez": "AAXBBXN" + "NXXAABB",
    "J. Parks":   "BBAXXAA" + "XBBNNXX",
    "J. Park":    "XXXXAXX" + "BXXXNXA",
    "L. Chen":    "NNXAABX" + "AAXXBBN",
    "R. Okafor":  "XABBNXX" + "XNAAXAB",
}
hotel_expected = [
    ("2026-10-30", "07:00", "15:00"),
    ("2026-11-02", "15:00", "23:00"),
    ("2026-11-06", "23:00", "07:00", "overnight: ends 2026-11-07 07:00"),
    ("2026-11-08", "07:00", "15:00"),
]

# F. Diner F - colour-coded grid, weekday names only (NO dates), first names only, 24h times.
#    Blank cell = not working. The app must ask which week this is (answer key assumes week of Sun 2026-10-25).
diner_header = ["", "SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]
diner_rows = [
    ["Hannah", "13:30 - 21:30", "", "", "", "", "", "14:00 - 22:30"],
    ["Seongmin", "", "5:30 - 13:30", "5:30 - 13:30", "", "", "", "5:30 - 11:00"],
    ["Jason", "", "16:00 - 21:30", "13:30 - 21:30", "13:30 - 21:30", "13:30 - 21:30", "14:00 - 22:30", ""],
    ["Jamie", "", "5:30 - 13:30", "", "10:00 - 14:00", "", "13:30 - 21:30", "5:30 - 11:00"],
    ["Chloe", "11:00 - 16:00", "", "10:00 - 14:00", "5:30 - 10:00", "", "5:30 - 14:00", "11:00 - 16:00"],
    ["Will", "", "", "5:30 - 10:00", "", "5:30 - 13:30", "5:30 - 11:00", ""],
]
diner_expected = [
    ("2026-10-26", "05:30", "13:30"),
    ("2026-10-28", "10:00", "14:00"),
    ("2026-10-30", "13:30", "21:30"),
    ("2026-10-31", "05:30", "11:00"),
]


def diner_colour(v):
    if not v:
        return "#bfbfbf"
    h = int(v.split(":")[0])
    return "#fff2cc" if h < 9 else "#f8cbad" if h < 13 else "#ea9999"


# ---------------------------------------------------------------- Excel
thin = Side(style="thin", color="BFBFBF")
border = Border(left=thin, right=thin, top=thin, bottom=thin)
center = Alignment(horizontal="center", vertical="center")


def write_grid(ws, rows, start_row=1, header_fill="D9E1F2"):
    for r, row in enumerate(rows):
        for c, val in enumerate(row):
            cell = ws.cell(row=start_row + r, column=c + 1, value=val)
            cell.border = border
            cell.alignment = center if c else Alignment(vertical="center")
            if r == 0:
                cell.font = Font(bold=True)
                cell.fill = PatternFill("solid", fgColor=header_fill)
    ws.column_dimensions["A"].width = 18
    for c in range(2, len(rows[0]) + 1):
        ws.column_dimensions[ws.cell(row=1, column=c).column_letter].width = 13


wb = Workbook()
ws = wb.active
ws.title = "A - Cafe A"
write_grid(ws, [cafe_header] + cafe_rows)

ws = wb.create_sheet("B - Restaurant B")
write_grid(ws, [rest_header] + rest_rows, header_fill="FCE4D6")

ws = wb.create_sheet("C - Bakery C")
ws["A1"] = bak_title
ws["A1"].font = Font(bold=True, size=14)
write_grid(ws, [bak_header] + bak_rows, start_row=3, header_fill="E2EFDA")

ws = wb.create_sheet("E - Hotel E")
hotel_header = ["Staff"] + [f"{EN_DAYS[d.weekday()][0]}\n{d.day}" for d in hotel_days]
write_grid(ws, [hotel_header] + [[n] + list(c) for n, c in hotel_codes.items()], header_fill="EDEDED")
for c in range(2, 16):
    ws.column_dimensions[ws.cell(row=1, column=c).column_letter].width = 5
ws.row_dimensions[1].height = 30
base = len(hotel_codes) + 3
ws.cell(row=base, column=1, value="Legend").font = Font(bold=True)
for i, (code, desc) in enumerate(hotel_legend):
    ws.cell(row=base + 1 + i, column=1, value=code)
    ws.cell(row=base + 1 + i, column=2, value=desc)

ws = wb.create_sheet("F - Diner F")
write_grid(ws, [diner_header] + diner_rows, header_fill="FFFFFF")
for r, row in enumerate(diner_rows):
    for c, v in enumerate(row[1:]):
        ws.cell(row=r + 2, column=c + 2).fill = PatternFill("solid", fgColor=diner_colour(v)[1:].upper())

wb.save(os.path.join(HERE, "schedules.xlsx"))

# ---------------------------------------------------------------- HTML screenshots
EXCEL_CSS = """
body{margin:0;background:#fff;font-family:Calibri,'Segoe UI','Malgun Gothic',sans-serif;font-size:15px}
.bar{background:#217346;color:#fff;padding:7px 12px;font:13px 'Segoe UI'}
.fx{border-bottom:1px solid #d4d4d4;padding:4px 8px;font:13px 'Segoe UI';color:#444;background:#fafafa}
table{border-collapse:collapse}
td,th{border:1px solid #d4d4d4;padding:4px 10px;white-space:nowrap;height:22px}
th.hd{background:#f3f3f3;color:#666;font-weight:normal;font-size:12px;padding:2px 6px}
td.rn{background:#f3f3f3;color:#666;font-size:12px;text-align:center;width:28px;padding:0 4px}
td.c{text-align:center} td.h{font-weight:bold}
"""


def excel_page(title, grid, header_bg, extra_top=None, extra_bottom=None, col_w=None):
    ncols = len(grid[0])
    letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"[:ncols]
    out = [f"<html><head><meta charset='utf-8'><style>{EXCEL_CSS}</style></head><body>",
           f"<div class='bar'>{title} - Excel</div><div class='fx'>fx</div><table>",
           "<tr><th class='hd'></th>" + "".join(f"<th class='hd'>{l}</th>" for l in letters) + "</tr>"]
    rn = 1
    rows = []
    if extra_top:
        rows.append(("top", extra_top))
        rows.append(("blank", None))
    for i, r in enumerate(grid):
        rows.append(("hdr" if i == 0 else "row", r))
    if extra_bottom:
        rows.append(("blank", None))
        rows.extend(("legend", l) for l in extra_bottom)
    for kind, r in rows:
        out.append(f"<tr><td class='rn'>{rn}</td>")
        if kind == "top":
            out.append(f"<td colspan='{ncols}' style='font-size:19px;font-weight:bold;border:none'>{r}</td>")
        elif kind == "blank":
            out.append("".join("<td></td>" for _ in range(ncols)))
        elif kind == "legend":
            out.append(f"<td class='h'>{r[0]}</td><td colspan='3'>{r[1]}</td>" + "<td></td>" * (ncols - 4))
        else:
            for j, v in enumerate(r):
                style = f"background:{header_bg};" if kind == "hdr" else ""
                if col_w and j:
                    style += f"width:{col_w}px;"
                cls = ("h " if kind == "hdr" else "") + ("c" if j else "")
                out.append(f"<td class='{cls}' style='{style}'>{v}</td>")
        out.append("</tr>")
        rn += 1
    for _ in range(3):
        out.append(f"<tr><td class='rn'>{rn}</td>" + "<td></td>" * ncols + "</tr>")
        rn += 1
    out.append("</table></body></html>")
    return "".join(out)


def app_page():
    cards = "".join(
        f"""<div class='card'><div class='row'><div><div class='day'>{d}</div>
        <div class='time'>{t}</div><div class='role'>{r}</div></div>
        <div class='hrs'>{h}</div></div></div>""" for d, t, r, h in groc_cards)
    off = "".join(f"<div class='off'>{d} · Not scheduled</div>" for d in
                  ["Tue, Oct 27", "Wed, Oct 28", "Fri, Oct 30", "Sun, Nov 1"])
    return f"""<html><head><meta charset='utf-8'><style>
    body{{margin:0;background:#121417;color:#e8eaed;font-family:'Segoe UI',sans-serif;width:390px}}
    .status{{display:flex;justify-content:space-between;padding:12px 22px 6px;font-size:14px;font-weight:600}}
    .top{{padding:10px 20px 4px}} .top h1{{margin:0;font-size:26px}}
    .sub{{color:#9aa0a6;font-size:14px;margin-top:4px}}
    .tabs{{display:flex;gap:8px;padding:14px 20px}}
    .tab{{padding:6px 14px;border-radius:16px;background:#202328;font-size:13px;color:#9aa0a6}}
    .tab.on{{background:#3ddc97;color:#0b2a1c;font-weight:600}}
    .card{{margin:10px 16px;background:#1d2025;border-radius:14px;padding:14px 16px;border-left:4px solid #3ddc97}}
    .row{{display:flex;justify-content:space-between;align-items:center}}
    .day{{font-size:13px;color:#9aa0a6}} .time{{font-size:19px;font-weight:600;margin:3px 0}}
    .role{{font-size:13px;color:#9aa0a6}} .hrs{{font-size:14px;color:#3ddc97;font-weight:600}}
    .off{{margin:6px 20px;font-size:13px;color:#6b7178}}
    .total{{margin:14px 20px;font-size:14px;color:#9aa0a6}}
    </style></head><body>
    <div class='status'><span>9:41</span><span>5G ▮▮▮ 82%</span></div>
    <div class='top'><h1>My Schedule</h1><div class='sub'>Grocery D · Week of Oct 26</div></div>
    <div class='tabs'><span class='tab'>‹ Prev</span><span class='tab on'>This week</span><span class='tab'>Next ›</span></div>
    {cards}{off}<div class='total'>Total this week: 17h</div></body></html>"""


def render(name, html, w, h):
    hp = os.path.join(HTML, name + ".html")
    with open(hp, "w", encoding="utf-8") as f:
        f.write(html)
    out = os.path.join(PNG, name + ".png")
    cmd = [EDGE, "--headless=new", "--disable-gpu", "--hide-scrollbars",
           f"--window-size={w},{h}", f"--screenshot={out}", "file:///" + hp.replace("\\", "/")]
    for attempt in range(3):          # Edge headless occasionally hangs; retry
        try:
            subprocess.run(cmd, check=True, timeout=40, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            break
        except subprocess.TimeoutExpired:
            if attempt == 2:
                raise
    print("rendered", out)


render("A_cafe_weekly_grid", excel_page("CafeA_Schedule_Oct26", [cafe_header] + cafe_rows, "#DDEBF7"), 1020, 330)
render("B_restaurant_transposed", excel_page("RestaurantB_week44", [rest_header] + rest_rows, "#FCE4D6"), 760, 360)
render("C_bakery_korean", excel_page("베이커리C_근무표", [bak_header] + bak_rows, "#E2EFDA", extra_top=bak_title), 1060, 340)
render("D_grocery_app_dark", app_page(), 390, 760)
hotel_grid = [["Staff"] + [f"{EN_DAYS[d.weekday()][0]}<br>{d.month}/{d.day}" for d in hotel_days]] + \
             [[n] + list(c) for n, c in hotel_codes.items()]
render("E_hotel_codes_2week", excel_page("HotelE_Rota_Oct26-Nov8", hotel_grid, "#EDEDED",
                                         extra_bottom=[("Legend", "")] + hotel_legend, col_w=34), 1020, 440)

diner_html = ("<html><head><meta charset='utf-8'><style>body{margin:14px;background:#fff;font:bold 12px Arial}"
              "table{border-collapse:collapse}td{border:1.5px solid #222;padding:3px 6px;width:92px;height:17px;"
              "text-align:center;white-space:nowrap}td.n{text-align:left;width:86px}</style></head><body><table>")
diner_html += "<tr>" + "".join(f"<td class='{'n' if i == 0 else ''}'>{v}</td>" for i, v in enumerate(diner_header)) + "</tr>"
for row in diner_rows:
    diner_html += f"<tr><td class='n'>{row[0]}</td>" + "".join(
        f"<td style='background:{diner_colour(v)};color:#c00000'>{v}</td>" for v in row[1:]) + "</tr>"
diner_html += "</table></body></html>"
render("F_diner_weekdays_colour", diner_html, 880, 210)

# ---------------------------------------------------------------- answer key
def pack(rows):
    return [dict(date=r[0], start=r[1], end=r[2], **({"note": r[3]} if len(r) > 3 else {})) for r in rows]


expected = {
    "user": USER,
    "formats": {
        "A_cafe_weekly_grid": {"workplace": "Café A", "name_in_file": "Jamie Park",
                               "challenge": "12h times without am/pm (6-1:30); decoy 'Jamie Lee'",
                               "shifts": pack(cafe_expected)},
        "B_restaurant_transposed": {"workplace": "Restaurant B", "name_in_file": "Park, J.",
                                    "challenge": "names are columns, dates are rows; 'Last, F.' format; overnight 6p-12a; 'CL' = close",
                                    "shifts": pack(rest_expected)},
        "C_bakery_korean": {"workplace": "Bakery C", "name_in_file": "박제이미",
                            "challenge": "Korean text; user name in Korean (needs alias); 휴무 = off",
                            "shifts": pack(bak_expected)},
        "D_grocery_app_dark": {"workplace": "Grocery D", "name_in_file": None,
                               "challenge": "app screenshot, dark mode, card list, no name (personal schedule)",
                               "shifts": pack(groc_expected)},
        "E_hotel_codes_2week": {"workplace": "Hotel E", "name_in_file": "J. Park",
                                "challenge": "shift codes resolved via legend; 2 weeks; decoy 'J. Parks'; overnight N",
                                "shifts": pack(hotel_expected)},
        "F_diner_weekdays_colour": {"workplace": "Diner F", "name_in_file": "Jamie", "week_of": "2026-10-25",
                                    "challenge": "weekday names only, no dates (user confirms the week); coloured cells; "
                                                 "first names only; 24h without leading zero (5:30 - 11:00)",
                                    "shifts": pack(diner_expected)},
    },
}
with open(os.path.join(HERE, "expected.json"), "w", encoding="utf-8") as f:
    json.dump(expected, f, ensure_ascii=False, indent=2)
print("done")
