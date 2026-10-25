import SwiftUI

/// Close button for sheets: an "xmark" on iOS 26, the text "Schließen" before.
struct SheetCloseButton: ToolbarContent {
    @Environment(\.dismiss) private var dismiss

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                dismiss()
            } label: {
                if #available(iOS 26, *) {
                    Image(systemName: "xmark")
                } else {
                    Text("Schließen")
                }
            }
        }
    }
}

extension View {
    /// Prominent full-width button at the bottom of a sheet, as on Apple's welcome screens.
    /// Used by the splash and tips sheets so both look the same.
    @ViewBuilder
    func sheetBottomButton<Content: View>(@ViewBuilder _ button: () -> Content) -> some View {
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        if #available(iOS 26, *) {
            safeAreaBar(edge: .bottom) {
                button()
                    .buttonStyle(.glassProminent)
                    .buttonSizing(.flexible)
                    .controlSize(.large)
                    .fontWeight(.semibold)
                    // On iPad Apple keeps the button narrower than the content.
                    .frame(maxWidth: isPad ? 400 : .infinity)
                    .padding(.horizontal, 40)
                    // The iPad sheet has no bottom safe area, so the button would touch the edge.
                    .padding(.bottom, isPad ? 40 : 0)
            }
        } else {
            safeAreaInset(edge: .bottom) {
                button()
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .fontWeight(.semibold)
                    .frame(maxWidth: isPad ? 400 : .infinity)
                    .padding(.horizontal, 40)
                    .padding(.bottom)
            }
        }
    }
}

extension View {
    /// The system's horizontal container margins, before iOS 27.1 the standard padding.
    /// Next to iPhone Duo's vertical bar the margin is 0, since the bar's safe area inset already includes it.
    /// `isSymmetric` uses the larger margin on both sides, for views that extend under the bar.
    @ViewBuilder
    func horizontalPadding(isSymmetric: Bool = false) -> some View {
        if #available(iOS 27.1, *) {
            if isSymmetric {
                modifier(SymmetricContainerMargins())
            } else {
                contentMargins(for: .container, edges: .horizontal)
            }
        } else {
            padding(.horizontal)
        }
    }
}

@available(iOS 27.1, *)
private struct SymmetricContainerMargins: ViewModifier {
    @State private var margin: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, margin)
            .onGeometryChange(for: CGFloat.self) { proxy in
                let margins = proxy.contentMargins(for: .container, edges: .horizontal)
                return max(margins.leading, margins.trailing)
            } action: { margin = $0 }
    }
}

struct DisclosureChevron: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .foregroundStyle(.tertiary)
            .font(.system(size: 14))
            .fontWeight(.semibold)
    }
}

/// List row with a title and optional value that pushes the destination registered for `page`.
struct DetailRow<Page: Hashable>: View {
    @Environment(\.isSplitLayout) private var isSplitLayout

    let title: LocalizedStringKey
    var value: Text? = nil
    let page: Page

    var body: some View {
        NavigationLink(value: page) {
            HStack {
                Text(title)
                Spacer()
                if let value {
                    value
                        .foregroundColor(.gray)
                }
                // Links in a split view column have no chevron of their own; there is no API to turn it on.
                if isSplitLayout {
                    DisclosureChevron()
                }
            }
        }
    }
}
