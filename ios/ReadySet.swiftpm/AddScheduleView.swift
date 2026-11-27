import SwiftUI
import PhotosUI

struct AddScheduleView: View {
    var onFinish: () -> Void = { }
    
    @State private var selectedItem: PhotosPickerItem?     // 앨범에서 고른 항목
    @State private var selectedImage: UIImage?             // 불러온 이미지
    @State private var isLoadingImage = false
    @State private var loadFailed = false
    
    @State private var isRecognizing = false               // 글자 읽는 중
    @State private var recognizedSchedule: RecognizedSchedule?
    @State private var recognitionFailed = false
    
    @State private var isShowingReview = false
    @State private var isShowingManualEntry = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Add Schedule")
                    .font(AppFont.montserrat(28, .bold, relativeTo: .largeTitle))
                    .padding(.top, 8)
                
                Text("Upload your schedule")
                    .font(AppFont.montserrat(20, .bold, relativeTo: .title3))
                    .padding(.top, 24)
                
                Text("We'll find your shifts automatically.")
                    .font(AppFont.montserrat(13, relativeTo: .subheadline))
                    .foregroundStyle(AppColor.primary.opacity(0.7))
                    .padding(.top, 4)
                
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    PhotoDropZone(image: selectedImage, isLoading: isLoadingImage)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(selectedImage == nil ? "Choose schedule photo" : "Change schedule photo")
                .padding(.top, 24)
                
                if loadFailed {
                    Text("Couldn't open this photo. Please choose another one.")
                        .font(AppFont.montserrat(12, relativeTo: .footnote))
                        .padding(.top, 8)
                } else if selectedImage != nil {
                    Text("Tap the image to choose a different photo.")
                        .font(AppFont.montserrat(12, relativeTo: .footnote))
                        .foregroundStyle(AppColor.primary.opacity(0.6))
                        .padding(.top, 8)
                }
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 16) {
                PrimaryButton(title: isRecognizing ? "Finding shifts…" : "Find my shifts", minHeight: 52) {
                    Task { await findShifts() }
                }
                .disabled(selectedImage == nil || isRecognizing)
                
                Button {
                    isShowingManualEntry = true
                } label: {
                    Text("Enter shifts manually")
                        .font(AppFont.montserrat(13, .medium, relativeTo: .subheadline))
                        .underline()
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .background(AppColor.background)
        }
        .foregroundStyle(AppColor.primary)
        .background(AppColor.background)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .task(id: selectedItem) {
            await loadSelectedImage()
        }
        .navigationDestination(isPresented: $isShowingReview) {
            if let selectedImage, let recognizedSchedule {
                ReviewScheduleView(image: selectedImage, schedule: recognizedSchedule, onFinish: onFinish)
            }
        }
        .navigationDestination(isPresented: $isShowingManualEntry) {
            ShiftFormView(mode: .add(.now), onFinish: onFinish)
        }
        .alert("Couldn't read this image", isPresented: $recognitionFailed) {
            Button("Enter shifts manually") { isShowingManualEntry = true }
            Button("Try another photo", role: .cancel) { }
        } message: {
            Text("Try a clearer screenshot of your schedule, or add your shifts yourself.")
        }
        // 읽는 동안 로딩 카드 띄우기 + Back 버튼 숨기기
        .overlay {
            if isRecognizing { FindingShiftsOverlay().transition(.opacity) }
        }
        .animation(.easeInOut(duration: 0.2), value: isRecognizing)
        .navigationBarBackButtonHidden(isRecognizing)
    }
    
    /// 고른 사진을 이미지로 불러오기
    private func loadSelectedImage() async {
        guard let selectedItem else { return }
        
        isLoadingImage = true
        loadFailed = false
        
        let image = await ImageLoading.loadImage(from: selectedItem)
        selectedImage = image
        loadFailed = (image == nil)
        isLoadingImage = false
    }
    
    /// Vision으로 글자를 읽고, 근무표 모양을 찾았으면 Review로 이동
    private func findShifts() async {
        guard let selectedImage else { return }
        isRecognizing = true
        defer { isRecognizing = false }
        
        do {
            async let plainRead = TextRecognizer.recognizeWords(in: selectedImage)
            async let cleanRead = try? TextRecognizer.recognizeWords(in: selectedImage, preprocess: true)
            let plainWords = try await plainRead
            let cleanWords = await cleanRead ?? []
            let words = OCRMerger.merge(plain: plainWords, preprocessed: cleanWords)
            
            // 날짜·요일이 있는 근무표 모양을 찾았는지 먼저 확인 (글자가 없어도 여기서 걸러짐)
            guard let check = ScheduleParser.shared.extract(words: words, names: []),
                  check.layout != "none"
            else {
                recognitionFailed = true
                return
            }
            
            recognizedSchedule = .fromOCR(words: words)
            isShowingReview = true
        } catch {
            recognitionFailed = true
        }
    }
}

// MARK: - 점선 사진 선택 박스
struct PhotoDropZone: View {
    let image: UIImage?
    let isLoading: Bool
    
    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 260)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .padding(12)
            } else if isLoading {
                ProgressView()
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 24))
                    Text("Choose photo")
                        .font(AppFont.montserrat(16, .bold, relativeTo: .headline))
                        .padding(.top, 4)
                    Text("JPG, PNG, HEIC")
                        .font(AppFont.montserrat(11, relativeTo: .caption))
                        .foregroundStyle(AppColor.primary.opacity(0.6))
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 124)
        .background(Color(hex: 0xFAFAFA), in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(AppColor.muted, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
        )
        .contentShape(Rectangle())
    }
}

#Preview {
    NavigationStack {
        AddScheduleView()
    }
    .environmentObject(ShiftStore.sample)
}

#Preview("Loading card") {
    NavigationStack {
        AddScheduleView()
            .overlay { FindingShiftsOverlay() }
    }
    .environmentObject(ShiftStore.sample)
}
