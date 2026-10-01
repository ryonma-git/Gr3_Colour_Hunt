import SwiftUI

/// はじめる前の画面（SOLO / TEAM 共通）。
///
/// 授業では「まだ始めないで待つ時間」が必ずある。
/// START を押すまではカメラも時計も動かないので、
/// 説明してから、みんなで一斉に始められる。
///
///   SOLO … いろの かず（難易度）と じかん をえらぶ
///   TEAM … じかん をえらぶ
///
/// TEAM の担当色は、この画面では見せない。
/// 先に色が分かると、気にいらない色のときに班をえらび直せてしまうため。
/// 色は START のあとの 3・2・1 で大きく出し、英語で読み上げる。
struct SetupView: View {
    let mode: HuntMode
    /// TEAM のときだけ入る
    let teamNumber: Int?
    /// (難易度, 制限時間の分。0 は「なし」)
    let onStart: (HuntDifficulty, Int) -> Void
    let onBack: () -> Void

    @State private var level: HuntDifficulty
    @State private var limitMinutes: Int
    /// 「そのほか」で −／＋ で動かしている分数
    @State private var customMinutes: Int

    init(mode: HuntMode,
         teamNumber: Int? = nil,
         onStart: @escaping (HuntDifficulty, Int) -> Void,
         onBack: @escaping () -> Void) {
        self.mode = mode
        self.teamNumber = teamNumber
        self.onStart = onStart
        self.onBack = onBack

        let minutes = HuntSettings.limitMinutes(for: mode)
        _level = State(initialValue: HuntSettings.level)
        _limitMinutes = State(initialValue: minutes)
        _customMinutes = State(initialValue: minutes > 0 ? minutes : 10)
    }

    private var isTeam: Bool { mode == .team }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                ScrollView {
                    VStack(spacing: 18) {
                        title

                        if isTeam {
                            colorIsSecretNote
                        } else {
                            block(label: "いろの かず") { levelChips }
                        }

                        block(label: "じかん") {
                            VStack(spacing: 10) {
                                timeChips
                                customRow
                            }
                        }
                    }
                    .frame(maxWidth: 520)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 10)
                }

                footer
            }
        }
    }

    // MARK: - 上

    private var header: some View {
        HStack {
            Button("← もどる") { onBack() }
                .font(Theme.label(18))
                .foregroundColor(Theme.subtle)
            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
    }

    private var title: some View {
        Text(isTeam ? "TEAM \(teamNumber ?? 0)" : "SOLO HUNT")
            .font(Theme.display(46))
            .foregroundColor(Theme.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
    }

    /// 担当の色は START まで見せない（色を見てから班をえらび直せないように）
    private var colorIsSecretNote: some View {
        Text("さがす いろは\nSTART の あとに でます")
            .font(Theme.label(22))
            .foregroundColor(Theme.subtle)
            .multilineTextAlignment(.center)
            .lineSpacing(4)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Theme.ink.opacity(0.05))
            )
            .accessibilityLabel("さがす いろは スタートの あとに でます")
    }

    // MARK: - えらぶところ

    private func block<Content: View>(label: String,
                                      @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(Theme.label(17))
                .foregroundColor(Theme.subtle)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var levelChips: some View {
        HStack(spacing: 10) {
            ForEach(HuntDifficulty.all) { item in
                chip(title: item.label,
                     subtitle: "\(item.count)いろ",
                     isOn: item.id == level.id) {
                    level = item
                    HuntSettings.level = item
                }
            }
        }
    }

    private var timeChips: some View {
        HStack(spacing: 10) {
            ForEach(HuntTimeOptions.presetMinutes, id: \.self) { minutes in
                chip(title: minutes == 0 ? "なし" : "\(minutes)ふん",
                     subtitle: nil,
                     isOn: minutes == limitMinutes) {
                    setLimit(minutes)
                }
            }
        }
    }

    /// 1〜20分のあいだで −／＋。押した時点でそれを選んだことになる。
    private var customRow: some View {
        HStack(spacing: 10) {
            Text("そのほか")
                .font(Theme.label(15))
                .foregroundColor(Theme.subtle)
            Spacer()
            stepperButton("−", label: "1ぷん みじかく") { step(-1) }
            chip(title: "\(isCustom ? limitMinutes : customMinutes)ふん",
                 subtitle: nil,
                 isOn: isCustom) {
                setLimit(customMinutes)
            }
            .frame(width: 120)
            stepperButton("＋", label: "1ぷん ながく") { step(1) }
        }
    }

    private var isCustom: Bool {
        limitMinutes > 0 && !HuntTimeOptions.presetMinutes.contains(limitMinutes)
    }

    private func setLimit(_ minutes: Int) {
        Feedback.tap()
        limitMinutes = minutes
        if minutes > 0 { customMinutes = minutes }
        HuntSettings.setLimitMinutes(minutes, for: mode)
    }

    private func step(_ delta: Int) {
        let base = limitMinutes > 0 ? limitMinutes : customMinutes
        let next = min(HuntTimeOptions.customRange.upperBound,
                       max(HuntTimeOptions.customRange.lowerBound, base + delta))
        setLimit(next)
    }

    private func chip(title: String,
                      subtitle: String?,
                      isOn: Bool,
                      action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 1) {
                Text(title)
                    .font(Theme.label(22))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(Theme.label(13))
                        .opacity(0.75)
                }
            }
            .foregroundColor(isOn ? .white : Theme.ink)
            .frame(maxWidth: .infinity)
            .frame(height: 66)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(isOn ? Theme.ink : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(isOn ? Theme.ink : Theme.ink.opacity(0.18), lineWidth: 3)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
    }

    private func stepperButton(_ symbol: String,
                               label: String,
                               action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(symbol)
                .font(Theme.display(30))
                .foregroundColor(Theme.ink)
                .frame(width: 66, height: 66)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Theme.ink.opacity(0.18), lineWidth: 3)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    // MARK: - 下

    private var footer: some View {
        VStack(spacing: 10) {
            Text(summary)
                .font(Theme.label(17))
                .foregroundColor(Theme.subtle)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Button("START") {
                Feedback.tap()
                onStart(level, limitMinutes)
            }
            .buttonStyle(PrimaryButtonStyle())
            .accessibilityHint("いろさがしを はじめます")
        }
        .padding(.horizontal, 28)
        .padding(.top, 8)
        .padding(.bottom, 18)
    }

    private var summary: String {
        var parts: [String] = []
        if isTeam {
            // 色はここでは出さない
            parts.append("TEAM \(teamNumber ?? 0)")
        } else {
            parts.append(level.labelWithCount)
        }
        parts.append(HuntTimeOptions.label(seconds: Double(limitMinutes) * 60))
        return parts.joined(separator: "・")
    }
}
