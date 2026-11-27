import SwiftUI

// MARK: - 화면 가운데 카드 창의 공통 틀 (뒤 어둡게 + 흰 카드)
struct ModalCard<Content: View>: View {
    let onClose: () -> Void
    @ViewBuilder let content: Content
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture { onClose() }
            
            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .foregroundStyle(AppColor.primary)
            .padding(24)
            .background(AppColor.background, in: RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 24)
            .accessibilityAddTraits(.isModal)
        }
    }
}

// MARK: - 창 제목 + X 버튼
struct DialogHeader: View {
    let title: String
    var message: String? = nil
    let onClose: () -> Void
    
    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(AppFont.montserrat(18, .bold, relativeTo: .title3))
                if let message {
                    Text(message)
                        .font(AppFont.montserrat(12, relativeTo: .footnote))
                        .foregroundStyle(AppColor.primary.opacity(0.7))
                }
            }
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
    }
}

// MARK: - 직장 추가·수정 창
struct WorkplaceDialog: View {
    let title: String
    let saveTitle: String
    let onSave: (_ name: String, _ nameOnSchedule: String) -> Void
    let onClose: () -> Void
    
    private let initialName: String
    private let initialNameOnSchedule: String
    @State private var name: String
    @State private var nameOnSchedule: String
    @FocusState private var focusedField: Field?
    
    private enum Field { case name, nameOnSchedule }
    
    init(
        title: String,
        saveTitle: String,
        initialName: String = "",
        initialNameOnSchedule: String = "",
        onSave: @escaping (_ name: String, _ nameOnSchedule: String) -> Void,
        onClose: @escaping () -> Void
    ) {
        self.title = title
        self.saveTitle = saveTitle
        self.onSave = onSave
        self.onClose = onClose
        self.initialName = initialName
        self.initialNameOnSchedule = initialNameOnSchedule
        _name = State(initialValue: initialName)
        _nameOnSchedule = State(initialValue: initialNameOnSchedule)
    }
    
    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedNameOnSchedule: String { nameOnSchedule.trimmingCharacters(in: .whitespacesAndNewlines) }
    
    /// 두 칸 모두 채워져 있고, 처음 값에서 바뀐 게 있어야 저장 가능
    private var canSave: Bool {
        !trimmedName.isEmpty && !trimmedNameOnSchedule.isEmpty
        && (trimmedName != initialName || trimmedNameOnSchedule != initialNameOnSchedule)
    }
    
    var body: some View {
        ModalCard(onClose: onClose) {
            DialogHeader(title: title, onClose: onClose)
            
            FieldLabel("WORKPLACE NAME")
                .padding(.top, 24)
            TextField("e.g. Bakery C", text: $name)
                .font(AppFont.montserrat(15, relativeTo: .body))
                .textInputAutocapitalization(.words)
                .focused($focusedField, equals: .name)
                .submitLabel(.next)
                .onSubmit { focusedField = .nameOnSchedule }
                .padding(.horizontal, 14)
                .frame(minHeight: 44)
                .cardStyle()
                .padding(.top, 8)
            
            FieldLabel("YOUR NAME ON THE SCHEDULE")
                .padding(.top, 20)
            TextField("e.g. Hongwoo", text: $nameOnSchedule)
                .font(AppFont.montserrat(15, relativeTo: .body))
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .nameOnSchedule)
                .submitLabel(.done)
                .padding(.horizontal, 14)
                .frame(minHeight: 44)
                .cardStyle()
                .padding(.top, 8)
            
            PrimaryButton(title: saveTitle, minHeight: 48) {
                onSave(trimmedName, trimmedNameOnSchedule)
            }
            .disabled(!canSave)
            .padding(.top, 24)
        }
        .onAppear {
            if initialName.isEmpty { focusedField = .name }   // 추가할 때만 첫 칸에 커서
        }
    }
}

// MARK: - 직장 삭제 확인 창
struct DeleteWorkplaceDialog: View {
    let workplaceName: String
    let onDelete: () -> Void
    let onClose: () -> Void
    
    var body: some View {
        ModalCard(onClose: onClose) {
            DialogHeader(
                title: "Delete \(workplaceName)?",
                message: "This workplace will be removed from your saved workplaces. Shifts you've already added won't be deleted.",
                onClose: onClose
            )
            
            HStack(spacing: 10) {
                Button(action: onClose) {
                    Text("Cancel")
                        .font(AppFont.montserrat(16, .semibold, relativeTo: .headline))
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .contentShape(Rectangle())
                        .cardStyle()
                }
                .buttonStyle(.plain)
                
                PrimaryButton(title: "Delete", minHeight: 48, action: onDelete)
            }
            .padding(.top, 24)
        }
    }
}
