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
    func sheetBottomButton<Content: View>(@ViewBuilder _ button: () -> Content) -> some View {
        modifier(SheetBottomButton(button: button()))
    }
}

private struct SheetBottomButton<Button: View>: ViewModifier {
    @Environment(\.isSplitLayout) private var isSplitLayout
    let button: Button

    private let isPad = UIDevice.current.userInterfaceIdiom == .pad
    /// On iPad and the unfolded iPhone Duo Apple keeps the button narrower than the content.
    private var maxWidth: CGFloat { isPad || isSplitLayout ? 400 : .infinity }

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.safeAreaBar(edge: .bottom) {
                button
                    .buttonStyle(.glassProminent)
                    .buttonSizing(.flexible)
                    .controlSize(.large)
                    .fontWeight(.semibold)
                    .frame(maxWidth: maxWidth)
                    // Goes right up to iPhone Duo's vertical bar, like the content above it.
                    .horizontalPadding(40)
                    // The iPad sheet has no bottom safe area, so the button would touch the edge.
                    .padding(.bottom, isPad ? 40 : 0)
            }
        } else {
            content.safeAreaInset(edge: .bottom) {
                button
                    .buttonStyle(.borderedProminent)
                    // Rounder than the default, as on Apple's welcome screens.
                    .buttonBorderShape(.roundedRectangle(radius: 14))
                    .controlSize(.large)
                    .fontWeight(.semibold)
                    .frame(maxWidth: maxWidth)
                    .padding(.horizontal, 40)
                    .padding(.bottom, isPad ? 40 : nil)
            }
        }
    }
}

extension View {
    /// The system's horizontal container margins, before iOS 27.1 the standard padding.
    /// Next to iPhone Duo's vertical bar the margin is 0, since the bar's safe area inset already includes it.
    /// `isSymmetric` uses the larger margin on both sides, for views that extend under the bar.
    /// `includesBottom` pads the bottom by the same margin, for views that sit at the bottom edge.
    @ViewBuilder
    func horizontalPadding(isSymmetric: Bool = false, includesBottom: Bool = false) -> some View {
        if #available(iOS 27.1, *) {
            modifier(ContainerMarginPadding(isSymmetric: isSymmetric, includesBottom: includesBottom))
        } else {
            padding(includesBottom ? [.horizontal, .bottom] : .horizontal)
        }
    }
}

/// Reads the margins and pads by them: `contentMargins(for:)` itself sizes wrapping text for a different width
/// than it lays it out in, so a ScrollView around it ends up too short or too tall.
@available(iOS 27.1, *)
private struct ContainerMarginPadding: ViewModifier {
    let isSymmetric: Bool
    let includesBottom: Bool
    @State private var margins = EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)

    func body(content: Content) -> some View {
        let symmetric = max(margins.leading, margins.trailing)
        content
            .padding(.leading, isSymmetric ? symmetric : margins.leading)
            .padding(.trailing, isSymmetric ? symmetric : margins.trailing)
            .padding(.bottom, includesBottom ? symmetric : 0)
            .onGeometryChange(for: EdgeInsets.self) { proxy in
                proxy.contentMargins(for: .container, edges: .horizontal)
            } action: { margins = $0 }
    }
}

extension View {
    /// Pads both sides by `length`, except the side of iPhone Duo's vertical bar,
    /// whose safe area inset already keeps the content clear of it.
    @ViewBuilder
    func horizontalPadding(_ length: CGFloat) -> some View {
        if #available(iOS 27.1, *) {
            modifier(VerticalBarSideOmittingPadding(length: length))
        } else {
            padding(.horizontal, length)
        }
    }
}

@available(iOS 27.1, *)
private struct VerticalBarSideOmittingPadding: ViewModifier {
    @Environment(\.toolbarVerticalEdge) private var edge
    let length: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(.leading, edge == .leading ? 0 : length)
            .padding(.trailing, edge == .trailing ? 0 : length)
    }
}

extension View {
    /// Lets the view extend under iPhone Duo's vertical bar, which runs down the side of the window
    /// with the status bar at its top. For content below that, so it centers on the full width.
    @ViewBuilder
    func ignoresVerticalBar(_ isEnabled: Bool = true) -> some View {
        if #available(iOS 27.1, *), isEnabled {
            modifier(VerticalBarIgnoringModifier())
        } else {
            self
        }
    }
}

@available(iOS 27.1, *)
private struct VerticalBarIgnoringModifier: ViewModifier {
    @Environment(\.toolbarVerticalEdge) private var edge

    func body(content: Content) -> some View {
        content.ignoresSafeArea(.container, edges: {
            switch edge {
            case .leading: .leading
            case .trailing: .trailing
            case nil: []
            }
        }())
    }
}

extension View {
    /// On iPhone Duo the tab bar sits in the vertical bar, so at the bottom only the home indicator inset is left.
    /// The view then ignores it and keeps `spacing` instead. The keyboard is ignored with it: while the keyboard is up
    /// the inset counts as both, and ignoring only the container would let the view move up.
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
            .ignoresSafeArea(.all, edges: barEdge != nil ? .bottom : [])
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

/// List row with a title and optional icon and value that pushes the destination registered for `page`.
struct DetailRow<Page: Hashable>: View {
    @Environment(\.isSplitLayout) private var isSplitLayout

    let title: LocalizedStringKey
    var systemImage: String? = nil
    var value: Text? = nil
    let page: Page

    var body: some View {
        NavigationLink(value: page) {
            HStack {
                if let systemImage {
                    Label {
                        Text(title)
                    } icon: {
                        Image(systemName: systemImage)
                            .foregroundStyle(.tint)
                    }
                } else {
                    Text(title)
                }
                Spacer()
                if let value {
                    value
                        .foregroundColor(.gray)
                }
                // Since iOS 26 links in a split view column have no chevron of their own; there is no API to turn it on.
                if #available(iOS 26, *), isSplitLayout {
                    DisclosureChevron()
                }
            }
        }
    }
}
