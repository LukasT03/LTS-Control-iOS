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

/// List row that pushes its destination in compact width and opens it as a sheet otherwise
/// (the settings column on iPad has no room to push).
struct AdaptiveDetailRow<Destination: View>: View {
    @Environment(LayoutModel.self) private var layoutModel
    @State private var isPresented = false

    let title: LocalizedStringKey
    var value: String? = nil
    @ViewBuilder let destination: () -> Destination

    var body: some View {
        if layoutModel.isCompactWidth {
            NavigationLink {
                titledDestination
            } label: {
                label(valueColor: .gray)
            }
        } else {
            Button {
                isPresented = true
            } label: {
                HStack {
                    label(valueColor: .secondary)
                    DisclosureChevron()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $isPresented) {
                NavigationStack {
                    titledDestination
                        .toolbar { SheetCloseButton() }
                }
            }
        }
    }

    private var titledDestination: some View {
        destination()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
    }

    private func label(valueColor: Color) -> some View {
        HStack {
            Text(title)
            Spacer()
            if let value {
                Text(value)
                    .foregroundColor(valueColor)
            }
        }
        .contentShape(Rectangle())
    }
}
