import SwiftUI

/// MY COLORS。1回の活動（セッション）ごとに、とった写真をならべる。
///
/// 色ごとに分けないのは、「この時間に何枚みつけた」という
/// 体験の単位で見返せるようにするため（CaptureGroup を参照）。
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
                        ForEach(CaptureGroup.groups(from: storage.captures)) { group in
                            section(group)
                        }
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

    private func section(_ group: CaptureGroup) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(group.title)
                    .font(Theme.display(24))
                    .foregroundColor(Theme.ink)
                Text(group.subtitle)
                    .font(Theme.label(15))
                    .foregroundColor(Theme.subtle)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer()
                Text("\(group.items.count)まい")
                    .font(Theme.label(20))
                    .foregroundColor(Theme.ink)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(group.title)、\(group.subtitle)、\(group.items.count)まい")

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(group.items) { capture in
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

    private func cell(_ capture: ColorCapture) -> some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay(ThumbnailImage(url: storage.imageURL(for: capture)))
            .overlay(alignment: .bottom) {
                Text(capture.displayName)
                    .font(Theme.label(14))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.52))
            }
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
