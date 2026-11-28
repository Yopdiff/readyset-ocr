# ReadySet 패치 노트 (상세)

- **이전**: `ReadySet.zip` (지난번 GitHub 업로드 버전)
- **이후**: `ReadySet_1.zip` (현재 버전)
- **규모**: 새 파일 8개 · 수정 11개 · 삭제 0개 · 그대로 42개
- 정확한 줄 단위 변경은 함께 올린 **`CHANGES.diff`** 참고 (`diff -ruN before after` 결과)

---

## 0. 한눈에 보기

| 파일 | 상태 | 줄 변경 | 요약 |
|---|---|---|---|
| `ClosingTime.swift` | 새 파일 | 82줄 | 직장 마감 시간 계산 + Review용 "몇 시에 마감?" 카드 |
| `ScanQualityNotes.swift` | 새 파일 | 43줄 | 못 읽은 칸 / 저해상도 사진 안내 |
| `MascotShape.swift` | 새 파일 | 131줄 | 마스코트 실루엣 + 모양 변신(Shape morphing) |
| `MascotView.swift` | 새 파일 | 220줄 | 마스코트 몸통·눈·표정·그림자 |
| `MascotAnimation.swift` | 새 파일 | 338줄 | 반복 애니메이션 + 완료 모션 |
| `ScheduleLoadingView.swift` | 새 파일 | 55줄 | 분석 중 로딩 카드 |
| `OnboardingView.swift` | 새 파일 | 274줄 | 온보딩 2페이지 + `IdleMascot` |
| `TutorialOverlay.swift` | 새 파일 | 337줄 | 튜토리얼 단계·진행 관리·스포트라이트·말풍선 |
| `Models.swift` | 수정 | +4 −1 | `Workplace.closingMinutes` 추가 |
| `PersistenceModels.swift` | 수정 | +5 −1 | `WorkplaceRecord.closingMinutes` 저장 |
| `WorkplaceDialogs.swift` | 수정 | +64 −4 | 마감 시간 입력 줄, **`onSave` 시그니처 변경** |
| `ManageWorkplacesView.swift` | 수정 | +23 −8 | 마감 시간 저장·표시 |
| `ReviewScheduleView.swift` | 수정 | +268 −110 | CL 자동 채우기, 품질 안내, 직장 Edit, 튜토리얼 |
| `ShiftFormView.swift` | 수정 | +55 −7 | 직장 Edit, 마감 시간, 튜토리얼 |
| `AddScheduleView.swift` | 수정 | +45 −17 | 마스코트 로딩, 완료 모션 후 이동, 튜토리얼 |
| `HomeView.swift` | 수정 | +20 −5 | 튜토리얼 대상·말풍선 |
| `ContentView.swift` | 수정 | +39 −8 | 온보딩/메인 분기, 튜토리얼 관리자 |
| `SettingsView.swift` | 수정 | +31 −0 | 튜토리얼 대상·말풍선, 개발용 줄 추가 |
| `AboutView.swift` | 수정 | +5 −4 | 회색 placeholder → 마스코트 타일 |

---

## 1. ⚠️ 호환성에 영향 있는 변경 (먼저 확인)

### 1-1. `WorkplaceDialog.onSave` 시그니처 변경
```swift
// 이전
let onSave: (_ name: String, _ nameOnSchedule: String) -> Void

// 이후
let onSave: (_ name: String, _ nameOnSchedule: String, _ closingMinutes: Int?) -> Void
```
- 생성자에 `initialClosingMinutes: Int? = nil` 추가 (`initialNameOnSchedule` 다음, `onSave` 앞)
- 호출하는 곳 **3군데 모두 수정됨**: `ReviewScheduleView`, `ManageWorkplacesView`, `ShiftFormView`
- 새로 `WorkplaceDialog`를 쓰는 곳이 있다면 클로저 인자를 3개로 받아야 함

### 1-2. `TutorialController` EnvironmentObject 필요
아래 5개 화면이 `@EnvironmentObject private var tutorial: TutorialController`를 사용함.
- `HomeView`, `AddScheduleView`, `ReviewScheduleView`, `ShiftFormView`, `SettingsView`
- 앱에서는 `ContentView`가 주입함
- **Preview에도 `.environmentObject(TutorialController())`가 필요** (모두 추가됨). 없으면 Preview가 멈춤

### 1-3. `Workplace` 생성자 인자 추가
```swift
init(id: UUID = UUID(), name: String, nameOnSchedule: String = "",
     aliases: [String] = [], color: WorkplaceColor = .blue,
     closingMinutes: Int? = nil)   // ← 추가 (기본값 nil이라 기존 호출은 그대로 동작)
```

### 1-4. 저장 데이터 변경
- **SwiftData**: `WorkplaceRecord`에 `closingMinutes: Int?` 추가. Optional이라 자동 마이그레이션되고 기존 데이터 유지
- **UserDefaults 새 키**
  - `userName` (String): 온보딩에서 입력한 이름
  - `hasCompletedOnboarding` (Bool): 온보딩 완료 여부
  - `tutorialPending` (Bool): 온보딩에서 Show me how를 눌렀는지
  - `tutorialStep` (String): 진행 중인 튜토리얼 단계 (`TutorialStep.rawValue`)
- 키 이름은 `AppStorageKey` enum(`OnboardingView.swift`)에 모아둠. `tutorialStep`만 `TutorialController` 안에 있음

### 1-5. 처음 실행 동작 변경
- `hasCompletedOnboarding`이 없으면(= false) **온보딩이 먼저 뜸**. 기존 테스트 기기에서도 한 번은 온보딩이 나옴

---

## 2. 수정된 파일 상세

### `Models.swift` (+4 −1)
- `struct Workplace`
  - 프로퍼티 추가: `var closingMinutes: Int?` (자정부터 몇 분. 22:00 = 1320, 모르면 nil)
  - `init`에 `closingMinutes: Int? = nil` 인자 추가 + 대입
- 나머지(`WorkplaceColor`, `Shift`, `AlarmSound`, `AlarmSettings`)는 변경 없음

### `PersistenceModels.swift` (+5 −1)
- `WorkplaceRecord`
  - `var closingMinutes: Int?` 추가
  - `init(from:)`, `update(from:)`에서 `closingMinutes` 복사
- `extension Workplace { init(record:) }`: `closingMinutes: record.closingMinutes` 전달

### `WorkplaceDialogs.swift` (+64 −4)
`WorkplaceDialog`만 변경. `ModalCard`, `DialogHeader`, `DeleteWorkplaceDialog`는 그대로.
- 시그니처 변경 (위 1-1 참고)
- 새 상태: `@State hasClosingTime: Bool`, `@State closingTime: Date`
  - 처음 정할 때 기본값은 **오후 10시**
- 새 계산 값: `closingMinutes: Int?` (`hasClosingTime`이 false면 nil)
- `canSave` 조건 변경
  ```swift
  // 이전: 이름이나 근무표 이름이 바뀌어야 저장 가능
  // 이후: 마감 시간만 바뀌어도 저장 가능
  && (trimmedName != initialName
      || trimmedNameOnSchedule != initialNameOnSchedule
      || closingMinutes != initialClosingMinutes)
  ```
- 화면: "YOUR NAME ON THE SCHEDULE" 아래에 **CLOSING TIME (OPTIONAL)** 추가
  - 없을 때: `Not set` + `Set closing time` 버튼
  - 있을 때: `DatePicker(.hourAndMinute)` + `Remove` 버튼
  - 안내: "Used for shifts marked "CL" or "Close"."

### `ManageWorkplacesView.swift` (+23 −8)
- Add: `onSave`에서 `closingMinutes`가 있으면 `addWorkplace` 후 `updateWorkplace`로 저장
  (`ShiftStore.addWorkplace`는 그대로 두고, 화면 쪽에서 한 번 더 업데이트하는 방식)
- Edit: `initialClosingMinutes: workplace.closingMinutes` 전달, 저장 시 `latest.closingMinutes = closingMinutes`
- `WorkplaceRow`: `detailText` 계산 프로퍼티 추가
  - 이전: `"Employee name: Taylor"`
  - 이후: `"Employee name: Taylor · Closes 10:00 PM"` (마감 시간이 있을 때만 뒤에 붙음)

### `ReviewScheduleView.swift` (+268 −110)
가장 많이 바뀐 파일. 기존 이름 매칭 로직(1~4단계)은 **동작 그대로**이고 함수 이름만 정리됨.

**새 상태 / 계산 값**
- `@EnvironmentObject tutorial: TutorialController`
- `@State closingFilledIDs: Set<ExtractedShift.ID>`: 마감 시간으로 **자동 채운** 근무 ID
- `@State isEditingClosingTime`: "Change closing time"을 눌렀는지
- `@State isEditingWorkplace`: Edit Workplace 창
- `isShowingWorkplaceDialog`: 추가 창 또는 수정 창이 떠 있는지
- `openCloseCount`: 끝 시간이 nil인 CL 근무 수

**`saveBlocker` 문구 변경**
- 이전: "Set an end time for shifts marked "Close"."
- 이후: "Set a closing time for shifts marked "Close"."

**레이아웃 변경**
- Workplace 영역과 이름("We'll look for") 영역을 **각각 `VStack`으로 묶음** (튜토리얼에서 따로 강조하려고)
- Workplace 드롭다운 아래 새 줄: "Manage workplaces anytime in Settings." + **Edit** (직장 선택 시에만)
- 근무 목록 영역도 `VStack`으로 묶고, 이름 선택 후에는 위에서부터:
  1. `ScanQualityNotes` (새)
  2. `closingTimeSection` (새)
  3. 기존 `ExtractedShiftsSection`
- 튜토리얼 대상 표시: `.reviewWorkplace`, `.reviewName`, `.reviewShifts`, `.reviewSaveButton`

**인식 흐름 변경**
```swift
// 이전
private func runRecognition() {
    hasEdits = false
    // ... 1~4단계 매칭 ...
}

// 이후
private func runRecognition() {
    hasEdits = false
    isEditingClosingTime = false
    matchShifts()        // 기존 1~4단계 매칭 (내용 동일, 함수만 분리)
    applyClosingTime()   // 저장된 마감 시간으로 CL 근무 채우기
}
```

**새 함수**
- `applyClosingTime()`: 직장에 마감 시간이 있으면 `end == nil`인 근무를 `workplace.closingDate(after: start)`로 채우고 `closingFilledIDs`에 기록
- `setClosingTime(_:)`: 카드에서 고른 마감 시간을 직장에 저장 + **아직 비어 있는 CL 근무와 자동으로 채웠던 근무**를 모두 새 시간으로 다시 채움
- `editWorkplace(_:name:nameOnSchedule:closingMinutes:)`: Edit 창 저장. 마감 시간이 바뀌었으면 `setClosingTime` 호출
- `closingTimeSection` (`@ViewBuilder`)
  - CL 근무가 남아 있거나 Change를 눌렀으면 → `ClosingTimeCard`
  - 자동으로 채웠으면 → "Shifts marked "Close" end at 10:00 PM, ○○'s closing time." + "Change closing time"

**기존 함수 변경**
- `save(_:)`, `delete(_:)`: `closingFilledIDs.remove(shift.id)` 추가 → 사용자가 직접 고친 근무는 마감 시간이 바뀌어도 덮어쓰지 않음
- `saveShifts()`: 끝에 `tutorial.advance(fromAny: [...], to: .shiftsAdded)` 추가
- 새 직장 추가(`onSave`): 인자 3개 + 마감 시간 저장

**modifier 변경**
- `.navigationBarBackButtonHidden(isShowingNewWorkplace)` → `(isShowingWorkplaceDialog)`
- `.tutorialOverlay(...)` 추가 (직장 창이 떠 있으면 숨김)
- `.overlay`에 `else if isEditingWorkplace` 분기로 Edit Workplace 창 추가

### `ShiftFormView.swift` (+55 −7)
- `@EnvironmentObject tutorial`, `@State isEditingWorkplace` 추가
- 새 계산 값
  - `editableWorkplace`: `store.workplaces`에 있는 직장만 (보관/삭제된 직장은 수정 불가)
  - `isShowingWorkplaceDialog`
- Workplace 구역
  - `Section("Workplace")` → `Section { } header: { } footer: { }` 형태로 변경
  - 직장 선택 시 **Edit [직장 이름]** 버튼 추가
  - footer: "You can also manage workplaces in Settings › Manage workplaces."
- `.overlay`: 새 직장 추가 창(인자 3개 + 마감 시간 저장) + **Edit Workplace 창** 추가
- `.tutorialOverlay(tutorial, showing: [.manualEntry], ...)` 추가
- `save()`: 끝에 `tutorial.advance(from: .manualEntry, to: .shiftsAdded)`
- 주석 정리: "TODO (Phase 4): 알람·리마인더 취소/예약" 삭제 → `ShiftStore.persist()`가 자동으로 다시 예약하므로

### `AddScheduleView.swift` (+45 −17)
**로딩 화면 교체**
```swift
// 이전
.overlay { if isRecognizing { FindingShiftsOverlay().transition(.opacity) } }
.animation(.easeInOut(duration: 0.2), value: isRecognizing)
.navigationBarBackButtonHidden(isRecognizing)

// 이후
.overlay {
    if isShowingLoading {
        ScheduleLoadingView(isFinished: isLoadingFinished).transition(.opacity)
    }
}
.animation(.easeInOut(duration: 0.25), value: isShowingLoading)
.navigationBarBackButtonHidden(isShowingLoading)
```
- 새 상태: `isShowingLoading`(로딩 카드 표시), `isLoadingFinished`(완료 모션 시작)
- `isRecognizing`은 버튼 글자("Finding shifts…")와 비활성화 용도로만 사용

**`findShifts()` 흐름 변경**
```swift
// 이전: 성공하면 바로 Review
recognizedSchedule = .fromOCR(words: words)
isShowingReview = true

// 이후: 완료 모션 → 1.1초 → Review
recognizedSchedule = .fromOCR(words: words)
isLoadingFinished = true                        // 마스코트 완료 모션 시작
try? await Task.sleep(for: .seconds(1.1))
tutorial.advance(from: .findShifts, to: .reviewWorkplace)
isShowingReview = true
isShowingLoading = false
```
- 실패 처리: `recognitionFailed = true` → `showFailure()` (로딩 닫기 + 알림창)
- **실제 분석이 끝나기 전에는 완료 모션을 시작하지 않음**

**그 외**
- `openManualEntry()` 추가: 튜토리얼을 `manualEntry` 단계로 넘기고 직접 입력 화면 열기 (버튼, 알림창 두 곳에서 사용)
- `loadSelectedImage()`: 사진을 불러오면 튜토리얼 `choosePhoto → findShifts`
- 튜토리얼 대상: 사진 칸 `.photoPicker`, Find my shifts `.findShiftsButton`
- `.tutorialOverlay(...)`: 로딩 중이거나 알림창이 떠 있으면 숨김
- `#Preview("Loading card")` 삭제 (`FindingShiftsOverlay` 미리보기용이었음)

### `HomeView.swift` (+20 −5)
- `@EnvironmentObject tutorial` 추가
- `openAddSchedule()` 추가: 튜토리얼 `addSchedule → choosePhoto` 후 Add Schedule 열기
  - 헤더 + 버튼, `AddScheduleButton`, "Add your first schedule" 세 곳 모두 이 함수 사용
- 튜토리얼 대상: `AddScheduleButton`, "Add your first schedule" 버튼 (`.addScheduleButton`)
- `.tutorialOverlay(tutorial, showing: [.addSchedule, .shiftsAdded])`
  - `shiftsAdded`의 "Set up alarms" → `tutorial.goToSettings()`

### `ContentView.swift` (+39 −8)
**구조 변경**
```swift
// 이전: body = TabView { ... } + modifiers

// 이후
var body: some View {
    ZStack {
        if hasCompletedOnboarding { mainTabs } else { OnboardingView() }
    }
    // + 공통 modifiers
}
private var mainTabs: some View { TabView { ... } .tint(...) }   // 기존 TabView 내용 그대로
```
- 새 프로퍼티
  - `@StateObject private var tutorial = TutorialController()`
  - `@AppStorage(AppStorageKey.hasCompletedOnboarding) private var hasCompletedOnboarding`
- modifier 위치 이동: `.preferredColorScheme`, `.environmentObject(store)`, `onChange(of: scenePhase)`를 TabView → 바깥 ZStack으로
- 추가
  - `.environmentObject(tutorial)`
  - `onChange(of: hasCompletedOnboarding)`: 완료되면 Home 탭 + `tutorial.startIfPending()`
  - `onChange(of: tutorial.requestedTab)`: 튜토리얼이 요청하면 탭 이동 (예: Settings)

### `SettingsView.swift` (+31 −0)
- `@EnvironmentObject tutorial` 추가
- 튜토리얼 대상: "Default wake-up alarm" `.wakeUpAlarmRow`, "Shift reminders" `.remindersRow`
- `.tutorialOverlay(tutorial, showing: [.wakeUpAlarm, .reminders, .finished])`
  - `wakeUpAlarm` Next → `reminders`
  - `reminders` "Allow notifications" → `NotificationPermission.request()` → `store.refreshReminders()` → `finished`
  - `finished` Done → `tutorial.end()`
- Developer 구역에 추가 (출시 전 삭제 예정)
  - `Restart tutorial` (subtitle이 지금 **디버그용**: 현재 단계와 pending 값 표시)
  - `MascotTestLinkRow()`, `MascotAnimationTestLinkRow()`, `OnboardingResetRow()`

### `AboutView.swift` (+5 −4)
```swift
// 이전
RoundedRectangle(cornerRadius: 10).fill(AppColor.muted).frame(width: 64, height: 64)

// 이후
IdleMascot(size: 54)
    .offset(y: 4)                    // 발밑 그림자 때문에 몸통이 위로 보여서 보정
    .frame(width: 88, height: 88)
    .background(ScheduleLoadingView.cardColor, in: RoundedRectangle(cornerRadius: 20))
```

---

## 3. 새 파일 상세

### `ClosingTime.swift` (82줄)
- `extension Workplace`
  - `closingDate(after start: Date) -> Date?`: 근무 시작 날짜 기준 마감 시각. **마감이 시작보다 이르거나 같으면 다음 날** (예: 17:30 시작, 01:00 마감)
- `enum ClosingTime`
  - `text(_ minutes: Int) -> String`: 1320 → "10:00 PM" (기기 12/24시간 설정 따름)
  - `minutes(from: Date) -> Int`: 시간 선택기 값 → 자정부터 분
- `struct ClosingTimeCard`: "What time does ○○ close?" + 시간 선택 + "Use this time"
  - 문구 예: "3 shifts end at closing ("CL"). We'll remember this for next time."

### `ScanQualityNotes.swift` (43줄)
- 입력: `image: UIImage`, `result: ExtractionResult`
- `result.unreadableCells`(parser의 `issues`)가 있으면:
  "Couldn't read 1 day: Tue, Nov 25 ("6g"). Add it yourself if you worked that day."
- 이미지 짧은 쪽(`size × scale`)이 **600px 미만**이면:
  "This photo is low resolution, so some shifts may be missed. A full-size screenshot works best."
- 참고: OCR confidence로 흐림을 판단하려 했으나 테스트 결과 구분이 안 돼서(깨끗한 샘플 D 평균 61 < 실제 근무표 64) 사용하지 않음

### `MascotShape.swift` (131줄)
- `enum MascotForm`: square, circle, flower, star
- `struct MascotOutline`
  - 모든 모양을 **"중심에서 120개 방향까지의 거리"**(`radii`)로 표현 → 점 개수와 순서가 같아서 점끼리 섞으면 변신
  - `blended(_ progress: Double)`: 0 네모 · 1 동그라미 · 2 꽃 · 3 별 · 4 다시 네모 (소수는 사이 모양, 음수·4 이상도 순환)
  - 네모: 원본 캐릭터 이미지에서 테두리를 측정한 120개 값 (`squareRadii`)
  - 동그라미·꽃·별: 공식 + `wobble`(느린 sin)로 일부러 살짝 비대칭
- `enum MascotPath.closedPath(through:)`: Catmull-Rom → 베지어 변환으로 매끈한 닫힌 경로
- `struct MascotShape: Shape`
  - `progress`, `spinsWithMorph`(true면 모양당 90° 회전. 현재 미사용)
  - `animatableData = progress` → `withAnimation`으로 실루엣 자체가 보간됨

### `MascotView.swift` (220줄)
- `enum MascotExpression`: normal, blink, happy(⌒⌒), sleepy(◡◡)
- `struct MascotView`: 재사용 컴포넌트
  - 인자: `size`, `morph`, `spinsWithMorph`, `expression`, `eyeOpenness`, `lookOffset`, `squash`, `hop`, `tilt`, `showsGroundShadow`, `showsDropShadow`, `colors`
  - 비율: 높이 = 가로 × 0.9 (원본 비율)
  - 그라데이션: #93DDFB → #A3A6F8 → #B77CFC (왼쪽 위 → 오른쪽 아래)
  - `squash`: 바닥 기준 가로/세로 반대로 늘이고 줄이기
  - `tilt`: 왼쪽 아래 모서리를 축으로 오른쪽 들어올리기
- `MascotEyes`: 뜬 눈·감은 눈을 **같은 캡슐의 높이**로 처리 (깜빡일 때 두 눈 모양이 겹쳐 보이던 문제 해결)
- `ArcEye`: 눈웃음/졸린 눈 곡선
- `MascotSparkles`: 선 3개 반짝임 (**현재 미사용**, 별로 교체됨)
- `MascotTestView`, `MascotTestLinkRow`: 개발용

### `MascotAnimation.swift` (338줄)
- `enum MascotAnimationStyle`: `.bouncy`(사용 중), `.spin`(비교용, 미사용)
- `enum MascotMotion` (시간 → 값, 순수 계산)
  - `frame(at:cycle:)`: 모양당 52%는 머무르며 출렁임(감쇠 사인), 48%는 변신(예비 동작 → 늘어남, `easeInOutBack`으로 살짝 지나쳤다 돌아옴). 바퀴·모양마다 세기·속도가 다름(`noise`)
  - `spinFrame(at:cycle:)`: 회전형 (미사용)
  - `eyeOpenness(at:)`: 8.4초 동안 불규칙하게 5번 깜빡임 (한 번은 두 번 연속)
- `struct AnimatedMascot`
  - `TimelineView(.animation)`으로 무한 반복, 화면에서 사라지거나 완료되면 멈춤
  - `isFinished = true` → 완료 모션 (약 1초)
    1. 가장 가까운 네모로 복귀 + 살짝 움츠림
    2. 오른쪽 10° 들어올림 + 눈웃음 + 크기 다른 별 3개가 양쪽에서 시간차로 등장
    3. 내려놓으며 출렁, 별 사라짐
  - Reduce Motion: 변신·출렁임 없음 (깜빡임 / 눈웃음만)
  - 옵션: `size`, `style`, `cycleDuration`(로딩에서는 3.6초), `showsDropShadow`, `colors`
- `MascotStarBurst`, `SparkleStar`: 완료 별
- `MascotAnimationTestView`, `MascotAnimationTestLinkRow`: 개발용

### `ScheduleLoadingView.swift` (55줄)
- 뒤 화면을 어둡게(0.25) + 가운데 카드
- 카드 배경 `cardColor = #F6F4FF` (다른 곳에서도 재사용: About 타일, 튜토리얼 말풍선)
- `AnimatedMascot(size: 100, cycleDuration: 3.6, showsDropShadow: false)`
- 문구: "Finding your shifts…" / "Looking through your work schedule."

### `OnboardingView.swift` (274줄)
- `enum AppStorageKey`: `userName`, `hasCompletedOnboarding`, `tutorialPending`
- `struct OnboardingView`: 페이지 전환(`.move` + `.opacity`), 저장된 이름이 있으면 미리 채움
  - Continue → `userName` 저장 → Page 2
  - Show me how → `tutorialPending = true`, `hasCompletedOnboarding = true`
  - Skip for now → `tutorialPending = false`, `hasCompletedOnboarding = true`
- `NamePage` (private): 마스코트 등장 애니메이션, 입력 중 시선 이동(`@FocusState` + 글자 수)
- `WelcomePage` (private): 눈웃음 통통 뛰기, 왼쪽 위 ‹ 뒤로 가기
- `struct IdleMascot` + `enum IdleMotion`: 가만히 있는 마스코트 (`.calm` 숨쉬기·깜빡임 / `.happy` 통통). 튜토리얼 말풍선과 About에서도 사용
- `OnboardingResetRow`: 개발용 (이름이 비어 있으면 "Jiwoo"를 채우고 온보딩 다시 보기)

### `TutorialOverlay.swift` (337줄)
- `enum TutorialStep: String` (순서)
  `addSchedule → choosePhoto → findShifts → reviewWorkplace → reviewName → reviewShifts → reviewSave → shiftsAdded → wakeUpAlarm → reminders → finished`
  - 근무표를 못 읽고 직접 입력하면: `choosePhoto/findShifts → manualEntry → shiftsAdded`
  - 단계별 `target`, `message(name:)`, `primaryTitle`(Next / Set up alarms / Allow notifications / Done)
- `enum TutorialTarget`: 강조할 UI 이름표
- `final class TutorialController: ObservableObject` (`@MainActor`)
  - `step`, `requestedTab`, `userName`
  - `startIfPending()`, `advance(from:to:)`, `advance(fromAny:to:)`: **현재 단계가 맞을 때만** 다음으로 (튜토리얼이 아닐 땐 아무 일도 안 함)
  - `goToSettings()`, `end()`, `restart()`(개발용)
  - 단계를 UserDefaults `tutorialStep`에 저장 → 앱을 꺼도 이어짐
- `TutorialAnchorKey` + `.tutorialTarget(_:)`: `anchorPreference`로 UI 위치 수집
- `.tutorialOverlay(step:name:onPrimary:onSkip:)` / `.tutorialOverlay(_:showing:isHidden:onPrimary:)`: `overlayPreferenceValue`로 스포트라이트 + 말풍선
- `TutorialOverlay`
  - `SpotlightShape` + `FillStyle(eoFill: true)`로 대상만 뚫린 어두운 막
  - 막은 `allowsHitTesting(false)` → **실제 버튼을 그대로 누를 수 있음**
  - 대상이 화면 위쪽이면 말풍선은 아래, 아래쪽이면 위. 대상 없으면 가운데 (manualEntry는 아래쪽)
- `TutorialBubble`: 작은 `IdleMascot` + 문구 + Skip tutorial / 기본 버튼

---

## 4. 변경 없는 주요 파일
- `ParserScript.swift`(parser.js): **수정 없음**. 이전에 보낸 Vision 대응 패치가 들어간 버전 그대로
- `ScheduleParser.swift`, `TextRecognizer.swift`, `ImagePreprocessor.swift`, `OCRMerger.swift`: 수정 없음
- `ShiftStore.swift`, `ReminderScheduler.swift`, `WakeAlarmPlanner.swift`, `WakeAlarmScheduler.swift`, `AlarmKitCheck.swift`: 수정 없음
- `HomeComponents.swift`: 수정 없음 (튜토리얼 표시는 `HomeView`에서 붙임)
- `SampleData.swift`: 수정 없음 (Café A의 `nameOnSchedule`은 "Jamie Park")

---

## 5. 정리 예정 (출시 전 삭제)
- Settings → Developer 구역 전체: Load sample data, Erase all data, Restart tutorial, OCR test, Reminder test, Mascot test, Mascot animation, Show onboarding again
- `FindingShiftsOverlay.swift`: 이제 어디서도 쓰지 않음 (파일만 남아 있음)
- `MascotSparkles`(선 3개), `.spin` 애니메이션, `MascotShape.spinsWithMorph`
- `OCRTestView.swift`, `ReminderTestView.swift`, `AlarmKitCheck.swift`의 개발용 부분

## 6. 아직 확인 못 한 것 / Mac 필요
- Playgrounds에서 키보드가 안 떠서 텍스트 입력은 **붙여넣기**로만 테스트 가능 (직장 이름, Type my name, 온보딩 이름)
- AlarmKit: `NSAlarmKitUsageDescription`을 Info.plist에 넣어야 해서 Xcode 필요. 문구가 없으면 코드가 자동으로 건너뜀
  - Playgrounds SDK가 예전 버전이라 `AlarmPresentation.Alert(stopButton:)` 사용 중 → 최신 Xcode에선 deprecated 경고 예상 (그 줄만 지우면 됨)
- 로컬 알림: 예약은 정상 확인됨. Playgrounds에서는 배너가 표시되지 않아 실제 기기 테스트 필요
- Review 화면에서 튜토리얼 강조 대상이 스크롤 밖에 있으면 말풍선 위치가 어색할 수 있음 (자동 스크롤 미구현)
