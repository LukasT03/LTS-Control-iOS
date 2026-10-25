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
