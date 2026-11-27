import SwiftUI

// MARK: - 칸 제목
struct FieldLabel: View {
    let text: String
    init(_ text: String) { self.text = text }
    
    var body: some View {
        Text(text)
            .font(AppFont.montserrat(12, .medium, relativeTo: .footnote))
    }
}

// MARK: - Workplace 드롭다운
struct WorkplacePicker: View {
    let workplaces: [Workplace]
    @Binding var selectedID: UUID?
    let onNewWorkplace: () -> Void
    
    @State private var isExpanded = false
    
    var body: some View {
        let selected = workplaces.first { $0.id == selectedID }
        
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
            } label: {
                HStack {
                    if let selected {
                        WorkplaceLabel(workplace: selected, font: AppFont.montserrat(15, .medium, relativeTo: .body))
                    } else {
                        Text("Choose a workplace")
                            .font(AppFont.montserrat(15, relativeTo: .body))
                            .foregroundStyle(AppColor.primary.opacity(0.5))
                    }
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 48)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(isExpanded ? "Hides workplaces" : "Shows workplaces")
            
            if isExpanded {
                ForEach(workplaces) { workplace in
                    Divider()
                    Button {
                        selectedID = workplace.id
                        withAnimation(.easeInOut(duration: 0.2)) { isExpanded = false }
                    } label: {
                        HStack {
                            WorkplaceLabel(workplace: workplace, font: AppFont.montserrat(15, relativeTo: .body))
                            Spacer()
                            if workplace.id == selectedID {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                        }
                        .padding(.horizontal, 16)
                        .frame(minHeight: 48)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(workplace.id == selectedID ? .isSelected : [])
                }
                
                Divider()
                Button {
                    isExpanded = false
                    onNewWorkplace()
                } label: {
                    Text("+ New workplace")
                        .font(AppFont.montserrat(15, .medium, relativeTo: .body))
                        .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                        .padding(.horizontal, 16)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .cardStyle()
    }
}

// MARK: - Schedule Week 칸
struct ScheduleWeekField: View {
    let range: DateInterval
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(TextFormat.weekRange(range))
                    .font(AppFont.montserrat(15, .medium, relativeTo: .body))
                Spacer()
                Image(systemName: "calendar")
                    .font(.system(size: 16))
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 48)
            .contentShape(Rectangle())
            .cardStyle()
        }
        .buttonStyle(.plain)
        .accessibilityHint("Change the schedule week")
    }
}

// MARK: - Schedule Week 선택 창
struct ScheduleWeekSheet: View {
    let onSave: (Date) -> Void
    @State private var pickedDate: Date
    @Environment(\.dismiss) private var dismiss
    
    init(weekStart: Date, onSave: @escaping (Date) -> Void) {
        self.onSave = onSave
        _pickedDate = State(initialValue: weekStart)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("First week", selection: $pickedDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                } footer: {
                    Text("Pick any day in the first week of this schedule. All shifts will move to match.")
                }
            }
            .navigationTitle("Schedule Week")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(pickedDate)
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - "We'll look for": 이름 확인과 선택
struct NameMatchSection: View {
    let result: ExtractionResult
    let requiresChoice: Bool          // 처음 보는 근무표: 반드시 직접 골라야 함
    var preferredName: String? = nil  // 진짜 이름 (OCR이 다르게 읽었을 때만)
    @Binding var isPicking: Bool
    let onPick: (String) -> Void
    let onTypeName: () -> Void
    
    private let columns = [GridItem(.adaptive(minimum: 120), spacing: 8)]
    
    private var promptText: String {
        if result.nameCandidates.isEmpty {
            return "We couldn't read any names on this schedule."
        }
        if requiresChoice {
            return result.matchedName != nil
            ? "New schedule format. Tap your name to confirm. Our best guess is highlighted, and we'll remember your choice next time."
            : "New schedule format. Tap your name, and we'll remember it next time."
        }
        return "Which one is you? Tap your name and we'll remember it for this workplace."
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let matched = result.matchedName, !isPicking, !requiresChoice {
                if result.isNameAmbiguous {
                    ReviewNote(text: preferredName.map { "We found “\(matched)”, which looks like \($0). Is that you?" }
                               ?? "We matched “\(matched)”. Is that you?")
                    HStack(spacing: 8) {
                        chip("Yes, that's me", isHighlighted: true) { onPick(matched) }
                        chip("No, show names") { isPicking = true }
                    }
                } else {
                    Button {
                        isPicking = true
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(preferredName ?? matched)
                                    .font(AppFont.montserrat(15, .medium, relativeTo: .body))
                                if preferredName != nil {
                                    Text("Shown as “\(matched)” on this schedule")
                                        .font(AppFont.montserrat(11, relativeTo: .caption))
                                        .foregroundStyle(AppColor.primary.opacity(0.6))
                                }
                            }
                            Spacer()
                            Image(systemName: "pencil")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .frame(minHeight: 48)
                        .contentShape(Rectangle())
                        .cardStyle()
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Looking for \(preferredName ?? matched)")
                    .accessibilityHint("Choose a different name")
                }
            } else {
                Text(promptText)
                    .font(AppFont.montserrat(12, relativeTo: .footnote))
                    .foregroundStyle(AppColor.primary.opacity(0.7))
                
                LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                    ForEach(result.nameCandidates, id: \.label) { candidate in
                        chip(candidate.label, isHighlighted: candidate.label == result.matchedName) {
                            onPick(candidate.label)
                        }
                    }
                }
                
                HStack {
                    Button("Type my name", action: onTypeName)
                    Spacer()
                    if !requiresChoice, result.matchedName != nil {
                        Button("Cancel") { isPicking = false }
                    }
                }
                .font(AppFont.montserrat(12, .medium, relativeTo: .footnote))
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
        }
    }
    
    private func chip(_ title: String, isHighlighted: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(AppFont.montserrat(13, .medium, relativeTo: .subheadline))
                .lineLimit(1)
                .foregroundStyle(isHighlighted ? AppColor.background : AppColor.primary)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, minHeight: 36)
                .background(isHighlighted ? AppColor.primary : AppColor.background,
                            in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppColor.muted, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
