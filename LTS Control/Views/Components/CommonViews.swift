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
                    .ignoresVerticalBar()
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
                    .ignoresVerticalBar()
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
            modifier(ContainerMarginPadding(isSymmetric: isSymmetric))
        } else {
            padding(.horizontal)
        }
    }
}

/// Reads the margins and pads by them: `contentMargins(for:)` itself sizes wrapping text for a different width
/// than it lays it out in, so a ScrollView around it ends up too short or too tall.
@available(iOS 27.1, *)
private struct ContainerMarginPadding: ViewModifier {
    let isSymmetric: Bool
    @State private var margins = EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)

    func body(content: Content) -> some View {
        let symmetric = max(margins.leading, margins.trailing)
        content
            .padding(.leading, isSymmetric ? symmetric : margins.leading)
            .padding(.trailing, isSymmetric ? symmetric : margins.trailing)
            .onGeometryChange(for: EdgeInsets.self) { proxy in
                proxy.contentMargins(for: .container, edges: .horizontal)
            } action: { margins = $0 }
    }
}

extension View {
    /// Lets the view extend under iPhone Duo's vertical bar, which runs down the side of the window
    /// with the status bar at its top. For content below that, so it centers on the full width.
    /// Text is measured at the narrower width, so its height can come out larger than what it needs on the full width;
    /// `alignment` decides where the content sits in that space.
    @ViewBuilder
    func ignoresVerticalBar(_ isEnabled: Bool = true, alignment: Alignment? = nil) -> some View {
        if #available(iOS 27.1, *), isEnabled {
            modifier(VerticalBarIgnoringModifier(alignment: alignment))
        } else {
            self
        }
    }
}

@available(iOS 27.1, *)
private struct VerticalBarIgnoringModifier: ViewModifier {
    @Environment(\.toolbarVerticalEdge) private var edge
    let alignment: Alignment?

    func body(content: Content) -> some View {
        content.ignoresSafeArea(.container, edges: {
            switch edge {
            case .leading: .leading
            case .trailing: .trailing
            case nil: []
            }
        }(), alignment: alignment)
    }
}

extension View {
    /// On iPhone Duo the tab bar sits in the vertical bar, so at the bottom only the home indicator inset is left.
    /// The view then ignores it and keeps `spacing` instead.
    @ViewBuilder
    func replacingHomeIndicatorInset(with spacing: CGFloat, isEnabled: Bool = true) -> some View {
        if #available(iOS 27.1, *), isEnabled {
            modifier(HomeIndicatorInsetReplacingModifier(spacing: spacing))
        } else {
            self
        }
    }
}

@available(iOS 27.1, *)
private struct HomeIndicatorInsetReplacingModifier: ViewModifier {
    @Environment(\.toolbarVerticalEdge) private var barEdge
    let spacing: CGFloat

    // No branching on the edge: it can flicker while a sheet opens, and a new identity would rebuild the content mid-animation.
    func body(content: Content) -> some View {
        content
            .padding(.bottom, barEdge != nil ? spacing : 0)
            .ignoresSafeArea(.container, edges: barEdge != nil ? .bottom : [])
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
