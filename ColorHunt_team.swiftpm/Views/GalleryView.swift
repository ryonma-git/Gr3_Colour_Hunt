import SwiftUI

/// MY COLORS。色ごとに、とった写真をならべる。
/// いまは RED だけだが、ColorProfile.catalog に色を足せば節が増える。
struct GalleryView: View {
    @EnvironmentObject private var storage: StorageService

    let onClose: () -> Void

    private let columns = [GridItem(.adaptive(minimum: 140), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                if storage.captures.isEmpty {
                    emptyState
                } else {
                    LazyVStack(alignment: .leading, spacing: 30) {
                        ForEach(ColorProfile.catalog) { profile in
                            section(title: profile.displayName,
                                    dotColor: profile.displayColor,
                                    items: storage.captures(for: profile.id))
                        }
                        section(title: "OTHER",
                                dotColor: Theme.subtle,
                                items: unknownCaptures)
                    }
                    .padding(20)
                }
            }
            .background(Theme.background)
            .navigationTitle("MY COLORS")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("とじる") { onClose() }
                        .font(Theme.label(18))
                }
            }
        }
    }

    /// カタログにない色の写真も、見えなくならないように出す
    private var unknownCaptures: [ColorCapture] {
        storage.captures.filter { ColorProfile.profile(id: $0.targetColor) == nil }
    }

    @ViewBuilder
    private func section(title: String, dotColor: Color, items: [ColorCapture]) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Circle()
                        .fill(dotColor)
                        .frame(width: 22, height: 22)
                    Text(title)
                        .font(Theme.display(34))
                        .foregroundColor(Theme.ink)
                    Text("\(items.count)")
                        .font(Theme.label(20))
                        .foregroundColor(Theme.subtle)
                }

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(items) { capture in
                        NavigationLink {
                            GalleryDetailView(capture: capture)
                        } label: {
                            cell(capture)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func cell(_ capture: ColorCapture) -> some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay(ThumbnailImage(url: storage.imageURL(for: capture)))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .accessibilityLabel(capture.displayName + " " + capture.capturedAtText)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera")
                .font(.system(size: 54))
                .foregroundColor(Theme.subtle)
            Text("まだ しゃしんが ありません")
                .font(Theme.label(24))
                .foregroundColor(Theme.subtle)
            Text("START から いろを さがしてみよう")
                .font(.system(size: 17))
                .foregroundColor(Theme.subtle)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 90)
    }
}
