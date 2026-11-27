import SwiftUI
import PhotosUI
import UIKit

@MainActor
enum ImageLoading {
    /// 사진 앨범에서 고른 항목을 UIImage로 불러옴 (실패하면 nil)
    static func loadImage(from item: PhotosPickerItem) async -> UIImage? {
        guard let data = try? await item.loadTransferable(type: Data.self) else {
            return nil
        }
        return UIImage(data: data)
    }
}
