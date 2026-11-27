# iOS 앱 리뷰 (2026-11-27)

`ios/ReadySet.swiftpm` 전체(Swift 파일 52개)를 읽고 정리한 내용이에요.
**Windows에서 작업해서 빌드는 못 했어요.** 아래 "고친 것"도 Mac에서 한 번 빌드해서 확인해야 해요.

## 폴더 구조 (이번에 정리함)

```
App/            앱 시작, 탭 구성
Models/         Shift, Workplace, AlarmSettings, 저장용 모델
Store/          ShiftStore (데이터 저장 + 알람/리마인더 다시 맞추기)
Logic/          날짜·근무 계산, 이름 비교, 표시용 글자
Scanning/       사진 → 글자(Vision) → 근무(parser.js)
Alarms/         Wake-up 알람(AlarmKit), 리마인더(알림)
Features/       화면: Home, Shifts, AddSchedule, Settings
DesignSystem/   색, 글꼴, 공통 버튼
Dev/            개발용 화면과 샘플 데이터 (출시 전 삭제)
```

Swift Playgrounds 앱은 폴더 안 파일을 전부 컴파일해서, 폴더를 나눠도 빌드 설정은 바뀌지 않아요.
`Scanning/ParserScript.swift`는 `web/parser.js`에서 자동으로 만들어요 (`cd web && npm run sync-ios`).

## 고친 것

1. **Wake-up 알람을 건너뛰는 규칙이 위험했어요.**
   예전: 앞 근무가 끝나고 **4시간 안**에 울릴 알람은 건너뜀. 23시 퇴근, 새벽 2시 기상이면 알람이 안 울렸어요.
   지금: 알람 시각에 **아직 근무 중이거나 퇴근한 지 1시간이 안 됐을 때만** 건너뛰어요. (`Alarms/WakeAlarmPlanner.swift`)

2. **화면에 보이는 알람과 실제 알람이 달랐어요.**
   Home·Shifts 화면은 건너뛴 알람이나 이미 지난 알람도 "Wake-up alarm 6:00 AM"처럼 보여줬어요.
   지금은 화면도 실제 예약 규칙(`WakeAlarmPlanner.wakeUpTime`)을 그대로 써요. 알람이 없으면 "No wake-up alarm"이라고 보여줘요.

3. **앱을 열 때마다 알람을 전부 지우고 다시 예약했어요.**
   그 사이에 알람이 비고, 중간에 실패하면 알람이 사라질 수 있었어요.
   지금은 알람 ID를 근무 ID로 고정하고, **바뀐 알람만** 취소·예약해요. (`Alarms/WakeAlarmScheduler.swift`)

4. **이름 보정 기능이 연결되지 않았어요.**
   `TextRecognizer`는 저장된 이름을 받으면 Vision이 헷갈린 이름을 바로잡을 수 있는데, 아무도 이름을 넘겨주지 않았어요.
   지금은 사진을 읽을 때 직장별 이름과 기억한 이름표를 넘겨줘요. (`Features/AddSchedule/AddScheduleView.swift`)

5. 개발용 알람 목록 화면을 `Dev/WakeAlarmPlanSection.swift`로 분리해서, 알람 계산 파일에 화면 코드가 섞이지 않게 했어요.

6. **알람 권한을 앱을 켜자마자 물어봤어요.** 이제 예약할 알람이 처음 생길 때(첫 근무를 추가한 뒤) 물어봐요.

7. **저장소를 못 열면 조용히 넘어갔어요.** 이제 "저장도 안 되고 알람도 안 맞춰진다"는 경고를 보여줘요. (`ShiftStore.isUsingTemporaryStorage`)

8. **Home 화면의 "지금"이 멈춰 있었어요.** 이제 1분마다 다시 그려서, 시작한 근무가 NEXT SHIFT에 남지 않아요.

9. **Review 화면이 다시 그려질 때마다 파서를 돌렸어요.** 이제 Add Schedule에서 이미 구한 첫 결과를 넘겨받아요.

10. **같은 계산이 여러 군데 있었어요.** 정리했어요.
    - "시작·종료 시각이 같으면 저장 불가" 검사 → `CalendarMath.isSameClockTime`
    - "종료가 시작보다 이르면 다음 날" → 파서 결과 변환도 `CalendarMath.shiftEnd` 사용
    - 근무 입력 화면의 Wake-up 알람 미리보기 → 실제 예약 규칙(`WakeAlarmPlanner`) 사용
    - 이미 해결된 "알람 다시 예약" TODO 주석 정리

## 남은 것 (중요한 순서)

1. **실제 알람이 아직 한 번도 울린 적이 없어요.**
   AlarmKit은 앱 설정(Info.plist)에 `NSAlarmKitUsageDescription`이 있어야 하는데, Playgrounds에서는 넣을 수 없어서 알람 코드가 조용히 건너뛰어요.
   → Mac의 Xcode 프로젝트로 옮기고, 실제 아이폰에서 알람이 울리는지 확인해야 해요. 이게 앱의 핵심이에요.

2. **알람 소리 설정이 아무 효과가 없어요.**
   Settings → Alarm sound에서 고른 값이 저장만 되고, 알람 예약할 때 쓰이지 않아요. 소리 파일도 앱에 없어요.
   → 소리 파일을 넣고 연결하거나, 그때까지 설정 화면을 숨기세요.

3. **알람 권한을 묻기 전에 이유를 보여주면 더 좋아요.** 지금은 첫 근무를 추가하면 시스템 권한 창이 바로 떠요.

4. **이 근무만 알람 시간 바꾸기**(피그마 메모)는 아직 없어요. 만들 때는 값을 근무 데이터에 저장하고 `WakeAlarmPlanner`가 쓰게 해야 동기화 때 지워지지 않아요.

5. **이름 비교 코드가 두 벌이에요.** `Logic/NameMatching.swift`는 `parser.js`의 이름 점수 계산을 Swift로 옮긴 거예요. 한쪽을 고치면 다른 쪽도 같이 고쳐야 해요.

6. **출시 전에 지울 것:** `Dev/` 폴더 전체와 `AlarmKitCheck`. (Developer 메뉴는 이미 디버그 빌드에서만 보여요.)
   앱 이름("나의 앱")과 아이콘도 Playgrounds 앱 설정에서 바꿔야 해요.

7. **테스트가 없어요.**
   알람 계산(`WakeAlarmPlanner`), 날짜 계산(`CalendarMath`), 파서 결과 변환(`ParserOutput.toExtractionResult`)은 화면과 상관없는 순수 로직이라 테스트하기 쉬워요.
   Xcode 프로젝트로 옮길 때 테스트 타깃을 만들고, 이 세 가지부터 테스트를 붙이는 걸 추천해요.

## 다음 단계로 추천하는 구조

Playgrounds는 테스트 타깃과 Info.plist를 지원하지 않아서, **Xcode 프로젝트로 옮기는 게 다음 단계**예요.

```
ReadySet.xcodeproj
├─ ReadySet (앱)          지금 ios/ReadySet.swiftpm 의 App, Features, DesignSystem
├─ ReadySetCore (패키지)  Models, Logic, Scanning, Alarms 의 계산 부분 (UI 없음)
└─ ReadySetCoreTests      위 계산 부분 테스트
```

`ReadySetCore`를 따로 떼면 Mac 없이도 이 부분은 CI(GitHub Actions의 macOS 빌드)에서 테스트할 수 있어요.
