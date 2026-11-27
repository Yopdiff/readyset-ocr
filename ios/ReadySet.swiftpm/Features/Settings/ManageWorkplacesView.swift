import SwiftUI

struct ManageWorkplacesView: View {
    @EnvironmentObject private var store: ShiftStore
    
    /// 지금 떠 있는 창
    private enum ActiveDialog {
        case add
        case edit(Workplace)
        case delete(Workplace)
    }
    @State private var dialog: ActiveDialog?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Manage Workplaces")
                    .font(AppFont.montserrat(26, .bold, relativeTo: .largeTitle))
                    .padding(.top, 8)
                Text("Manage your workplaces and employee names.")
                    .font(AppFont.montserrat(12, relativeTo: .footnote))
                    .foregroundStyle(AppColor.primary.opacity(0.7))
                    .padding(.top, 4)
                
                VStack(spacing: 8) {
                    if store.workplaces.isEmpty {
                        Text("No workplaces yet. Add one to get started.")
                            .font(AppFont.montserrat(13, relativeTo: .subheadline))
                            .foregroundStyle(AppColor.primary.opacity(0.6))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                    }
                    
                    ForEach(store.workplaces) { workplace in
                        WorkplaceRow(
                            workplace: workplace,
                            onEdit: { show(.edit(workplace)) },
                            onDelete: { show(.delete(workplace)) }
                        )
                    }
                    
                    Button {
                        show(.add)
                    } label: {
                        Text("+ Add new workplace")
                            .font(AppFont.montserrat(13, .medium, relativeTo: .subheadline))
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .contentShape(Rectangle())
                            .cardStyle()
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 24)
            }
            .foregroundStyle(AppColor.primary)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(AppColor.background)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(dialog != nil)
        .toolbar(.hidden, for: .tabBar)
        .overlay {
            if let dialog {
                dialogView(dialog)
                    .transition(.opacity)
            }
        }
    }
    
    // MARK: - 창
    
    @ViewBuilder
    private func dialogView(_ dialog: ActiveDialog) -> some View {
        switch dialog {
        case .add:
            WorkplaceDialog(
                title: "Add New Workplace",
                saveTitle: "Save Workplace",
                onSave: { name, nameOnSchedule in
                    store.addWorkplace(name: name, nameOnSchedule: nameOnSchedule)
                    close()
                },
                onClose: close
            )
            
        case .edit(let workplace):
            WorkplaceDialog(
                title: "Edit Workplace",
                saveTitle: "Save Changes",
                initialName: workplace.name,
                initialNameOnSchedule: workplace.nameOnSchedule,
                onSave: { name, nameOnSchedule in
                    // 창을 여는 동안 바뀌었을 수 있으니 최신 정보를 가져와 수정
                    if var latest = store.workplaces.first(where: { $0.id == workplace.id }) {
                        latest.name = name
                        latest.nameOnSchedule = nameOnSchedule
                        store.updateWorkplace(latest)
                    }
                    close()
                },
                onClose: close
            )
            
        case .delete(let workplace):
            DeleteWorkplaceDialog(
                workplaceName: workplace.name,
                onDelete: {
                    store.deleteWorkplace(workplace.id)
                    close()
                },
                onClose: close
            )
        }
    }
    
    private func show(_ newDialog: ActiveDialog) {
        withAnimation { dialog = newDialog }
    }
    
    private func close() {
        withAnimation { dialog = nil }
    }
}

// MARK: - 직장 한 줄
struct WorkplaceRow: View {
    let workplace: Workplace
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: onEdit) {
                HStack(spacing: 12) {
                    Image(systemName: "pencil")
                        .font(.system(size: 14, weight: .medium))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        WorkplaceLabel(workplace: workplace, font: AppFont.montserrat(14, .semibold, relativeTo: .subheadline))
                        Text(workplace.nameOnSchedule.isEmpty
                             ? "No employee name"
                             : "Employee name: \(workplace.nameOnSchedule)")
                        .font(AppFont.montserrat(11, relativeTo: .caption))
                        .foregroundStyle(AppColor.primary.opacity(0.7))
                    }
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Edit workplace")
            
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 15))
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Delete \(workplace.name)")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .cardStyle()
    }
}

#Preview {
    NavigationStack {
        ManageWorkplacesView()
    }
    .environmentObject(ShiftStore.sample)
}
