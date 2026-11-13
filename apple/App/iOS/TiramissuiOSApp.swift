import SwiftUI
import DesignSystem
import HanCore

/// App iPhone — chỉ học và ôn (GĐ4, ưu tiên thấp). Khung rỗng.
@main
struct TiramissuiOSApp: App {
    var body: some Scene {
        WindowGroup {
            TabView {
                Tab("Hôm nay", systemImage: "house") { placeholder("Hôm nay") }
                Tab("Học", systemImage: "rectangle.on.rectangle") { placeholder("Học") }
                Tab("Nghe", systemImage: "headphones") { placeholder("Nghe") }
            }
        }
    }

    private func placeholder(_ title: String) -> some View {
        ContentUnavailableView(title, systemImage: "hammer", description: Text("Làm ở giai đoạn 4"))
    }
}
