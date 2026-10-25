import SwiftUI
import StoreKit

struct TipsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.isSplitLayout) private var isSplitLayout
    
    private static let productIDs = ["smallTip", "mediumTip", "bigTip", "biggerTip", "biggestTip"]

    @State private var products: [String: Product] = [:]
    @State private var isPurchasing: Bool = false
    @State private var purchaseMessage: String?
    @State private var purchaseWasSuccessful: Bool = false
    @State private var selectedTipLevel: Int = 0

    private var selectedProduct: Product? { products[Self.productIDs[selectedTipLevel]] }

    private func changeTipLevel(by delta: Int) {
        guard Self.productIDs.indices.contains(selectedTipLevel + delta) else { return }
        selectedTipLevel += delta
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private var buttonBackground: some View {
        Group {
            if UIDevice.current.userInterfaceIdiom == .pad {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.blue)
            } else {
                Capsule()
                    .fill(.blue)
            }
        }
    }

    private var buttonBottomPadding: CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? (isSplitLayout ? 38 : 14) : 0
    }

    var body: some View {
        NavigationStack {
            Group {
                if let message = purchaseMessage {
                    VStack(spacing: 24) {
                        Image(systemName: purchaseWasSuccessful ? "heart.fill" : "xmark.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 60)
                            .foregroundColor(purchaseWasSuccessful ? .red : .orange)

                        Text(message)
                            .multilineTextAlignment(.center)
                            .font(.title)
                            .padding(.horizontal, 40)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack {
                        Text("Trinkgeld senden")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 3)
                        
                        Text("Wenn dir die App gefällt, kannst du hier eine kleine Spende leisten. Es werden dadurch keine zusätzlichen Funktionalitäten freigeschaltet.")
                            .foregroundColor(Color.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Spacer()
                        HStack {
                            Spacer()
                            Button {
                                changeTipLevel(by: -1)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .resizable()
                                    .tint(Color(UIColor.lightGray))
                                    .frame(width: 38, height: 38)
                            }
                            Spacer()
                            HStack(spacing: 8) {
                                Text("☕️")
                                    .font(.system(size: 60))

                                HStack(alignment: .firstTextBaseline, spacing: 4) {
                                    Text("x")
                                        .font(.largeTitle)

                                    Text("\(selectedTipLevel + 1)")
                                        .font(.largeTitle)
                                        .monospacedDigit()
                                        .contentTransition(.numericText(value: Double(selectedTipLevel + 1)))
                                        .animation(.snappy, value: selectedTipLevel)
                                }
                            }
                            Spacer()
                            Button {
                                changeTipLevel(by: 1)
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .resizable()
                                    .tint(Color(UIColor.lightGray))
                                    .frame(width: 38, height: 38)
                            }
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                        
                        Spacer()
                    }
                }
            }
            .padding(.horizontal, isSplitLayout ? 26 : 20)
            .padding(.top, 20)
            
            .safeAreaInset(edge: .bottom) {
                if purchaseMessage != nil {
                    Button(action: {
                        dismiss()
                    }) {
                        Text("Schließen")
                            .monospacedDigit()
                            .fontWeight(.semibold)
                            .frame(minWidth: 0, maxWidth: 420)
                            .padding(.vertical, 15)
                    }
                    .background(buttonBackground)
                    .foregroundColor(.white)
                    .padding(.horizontal, 36)
                    .padding(.bottom, buttonBottomPadding)
                } else {
                    Button(action: {
                        if let selectedProduct {
                            Task { await purchase(selectedProduct) }
                        }
                    }) {
                        let priceText = selectedProduct?.displayPrice ?? ""
                        Text(priceText.isEmpty ? "Unterstützen" : "Unterstützen \(priceText)")
                            .monospacedDigit()
                            .fontWeight(.semibold)
                            .frame(minWidth: 0, maxWidth: 420)
                            .padding(.vertical, 15)
                    }
                    .background(buttonBackground)
                    .foregroundColor(.white)
                    .padding(.horizontal, 36)
                    .padding(.bottom, buttonBottomPadding)
                    .disabled(selectedProduct == nil || isPurchasing)
                    .redacted(reason: selectedProduct == nil ? .placeholder : [])
                }
            }
            .presentationDetents([.height(340)])
            .task {
                await loadProducts()
                for await result in Transaction.updates {
                    guard case .verified(let transaction) = result else { continue }
                    await transaction.finish()
                }
            }
        }
    }

    func loadProducts() async {
        do {
            let loaded = try await Product.products(for: Self.productIDs)
            products = Dictionary(uniqueKeysWithValues: loaded.map { ($0.id, $0) })
        } catch {
            print("Fehler beim Laden der Produkte: \(error)")
        }
    }

    func purchase(_ product: Product) async {
        isPurchasing = true
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(.verified(_)):
                purchaseWasSuccessful = true
                purchaseMessage = NSLocalizedString("Vielen Dank für deine Unterstützung!", comment: "Shown after a successful tip purchase")
            case .success(.unverified(_, _)):
                purchaseWasSuccessful = false
                purchaseMessage = NSLocalizedString("Zahlung konnte nicht verifiziert werden.", comment: "Shown when the transaction could not be verified")
            case .userCancelled:
                purchaseWasSuccessful = false
                purchaseMessage = nil
            case .pending:
                purchaseWasSuccessful = false
                purchaseMessage = NSLocalizedString("Zahlung wird verarbeitet...", comment: "Shown while the payment is pending")
            @unknown default:
                purchaseWasSuccessful = false
                purchaseMessage = NSLocalizedString("Unbekannter Fehler beim Kauf.", comment: "Shown for an unknown purchase error")
            }
        } catch {
            purchaseWasSuccessful = false
            purchaseMessage = String(format: NSLocalizedString("Fehler beim Kauf: %@", comment: "Shown when the purchase flow throws an error; includes the error description"), error.localizedDescription)
        }
    }
}

#Preview {
    TipsView()
        .presentationDetents([.height(300)])
}
