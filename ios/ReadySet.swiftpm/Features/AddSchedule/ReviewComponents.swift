import SwiftUI

// MARK: - 업로드한 근무표 미리보기
struct SchedulePreview: View {
    let image: UIImage
    
    var body: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity, maxHeight: 160)
            .padding(12)
            .background(Color(hex: 0xFAFAFA), in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(AppColor.muted, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            )
            .accessibilityLabel("Uploaded schedule")
    }
}

// MARK: - 추출된 근무 섹션
struct ExtractedShiftsSection: View {
    let shifts: [ExtractedShift]
    let onEdit: (ExtractedShift) -> Void
    let onAdd: () -> Void
    
    var body: some View {
        let needsReviewCount = shifts.filter(\.needsReview).count
        
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Extracted shifts")
                    .font(AppFont.montserrat(20, .bold, relativeTo: .title3))
                Spacer()
                Text(TextFormat.shiftCount(shifts.count) + " found")
                    .font(AppFont.montserrat(12, relativeTo: .caption))
                    .foregroundStyle(AppColor.primary.opacity(0.6))
            }
            
            if shifts.isEmpty {
                ReviewNote(text: "We couldn't find your shifts on this schedule. Check your name below, or add shifts yourself.")
            } else if needsReviewCount > 0 {
                ReviewNote(text: "Please check the times marked with ⓘ. Some times on this schedule didn't show AM or PM, so we made our best guess.")
            }
            
            ForEach(shifts) { shift in
                ExtractedShiftRow(shift: shift) {
                    onEdit(shift)
                }
            }
            
            Button(action: onAdd) {
                Text("+ Add a shift")
                    .font(AppFont.montserrat(13, .medium, relativeTo: .subheadline))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .cardStyle()
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - 근무 한 줄
struct ExtractedShiftRow: View {
    let shift: ExtractedShift
    let onEdit: () -> Void
    
    var body: some View {
        Button(action: onEdit) {
            HStack(spacing: 8) {
                Text(shift.start.shortDayText)
                    .font(AppFont.montserrat(14, .bold, relativeTo: .subheadline))
                Spacer()
                if shift.needsReview {
                    Image(systemName: "info.circle")
                        .font(.system(size: 13))
                }
                Text(shift.timeRangeText)
                    .font(AppFont.montserrat(13, relativeTo: .subheadline))
                    .foregroundStyle(AppColor.primary.opacity(0.8))
                Image(systemName: "pencil")
                    .font(.system(size: 14, weight: .medium))
                    .padding(.leading, 8)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 48)
            .cardStyle()
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(shift.start.longDayText), \(shift.timeRangeText)\(shift.needsReview ? ", needs checking" : "")")
        .accessibilityHint("Edit this shift")
    }
}

// MARK: - 안내 문구
struct ReviewNote: View {
    let text: String
    
    var body: some View {
        Label {
            Text(text)
        } icon: {
            Image(systemName: "info.circle")
        }
        .font(AppFont.montserrat(12, relativeTo: .footnote))
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.muted.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - 전체 이미지 보기
struct FullImageView: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { dismiss() }
                    }
                }
        }
    }
}
