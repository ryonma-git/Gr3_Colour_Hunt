import SwiftUI

/// 班番号をえらぶ画面。1画面1目的。
/// ここでは色を見せない。色はアプリが決めるもので、児童がえらぶものではない。
struct TeamSelectView: View {
    let onSelect: (Int) -> Void
    let onBack: () -> Void

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 18)]

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Button(action: onBack) {
                        Label("もどる", systemImage: "chevron.left")
                            .font(Theme.label(20))
                            .foregroundColor(Theme.subtle)
                            .padding(.vertical, 10)
                            .padding(.trailing, 12)
                    }
                    .accessibilityLabel("ホームに もどる")
                    Spacer()
                }
                .padding(.horizontal, 20)

                Text("Choose your team")
                    .font(Theme.display(44))
                    .foregroundColor(Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .padding(.top, 4)

                Text("じぶんの はんの ばんごうを おしてね")
                    .font(Theme.label(19))
                    .foregroundColor(Theme.subtle)
                    .padding(.top, 6)

                Spacer(minLength: 12)

                LazyVGrid(columns: columns, spacing: 18) {
                    ForEach(TeamHuntConfiguration.activeAssignments) { assignment in
                        teamCard(assignment.teamNumber)
                    }
                }
                .padding(.horizontal, 24)

                Spacer()
            }
            .padding(.vertical, 18)
        }
    }

    /// カード全体がタップできる。数字だけでなく面で押せるようにしている。
    private func teamCard(_ number: Int) -> some View {
        Button {
            Feedback.tap()
            onSelect(number)
        } label: {
            VStack(spacing: 2) {
                Text("TEAM")
                    .font(Theme.label(16))
                    .foregroundColor(Theme.subtle)
                Text("\(number)")
                    .font(Theme.display(72))
                    .foregroundColor(Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 150)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22)
                            .stroke(Theme.ink.opacity(0.18), lineWidth: 3)
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("チーム \(number)")
    }
}
