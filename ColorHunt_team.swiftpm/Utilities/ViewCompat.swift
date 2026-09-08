import SwiftUI

extension View {
    /// iOS 16 / 17 以降の両方で警告なしに使える onChange。
    @ViewBuilder
    func onValueChange<V: Equatable>(of value: V,
                                     perform action: @escaping (V) -> Void) -> some View {
        if #available(iOS 17.0, *) {
            self.onChange(of: value) { _, newValue in action(newValue) }
        } else {
            self.legacyOnChange(of: value, perform: action)
        }
    }

    @available(iOS, deprecated: 17.0, message: "iOS 16 用のフォールバック")
    @ViewBuilder
    fileprivate func legacyOnChange<V: Equatable>(of value: V,
                                                 perform action: @escaping (V) -> Void) -> some View {
        self.onChange(of: value, perform: action)
    }
}
