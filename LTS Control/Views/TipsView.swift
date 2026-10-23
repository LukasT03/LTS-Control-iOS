import SwiftUI
import StoreKit

struct TipsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(LayoutModel.self) private var layoutModel
    
    @State private var smallTipProduct: Product?
    @State private var mediumTipProduct: Product?
    @State private var bigTipProduct: Product?
    @State private var biggerTipProduct: Product?
    @State private var biggestTipProduct: Product?

    @State private var isPurchasing: Bool = false
    @State private var purchaseMessage: String?
    @State private var purchaseWasSuccessful: Bool = false
    @State private var selectedTipLevel: Int = 0

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
                                if selectedTipLevel > 0 {
                                    selectedTipLevel -= 1
                                    let generator = UIImpactFeedbackGenerator(style: .light)
                                    generator.impactOccurred()
                                }
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
                                if selectedTipLevel < 4 {
                                    selectedTipLevel += 1
                                    let generator = UIImpactFeedbackGenerator(style: .light)
                                    generator.impactOccurred()
                                }
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
            .padding(.horizontal, !layoutModel.isCompactWidth ? 26 : 20)
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
                    .background(
                        Group {
                            if UIDevice.current.userInterfaceIdiom == .pad {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(.blue)
                            } else {
                                Capsule()
                                    .fill(.blue)
                            }
                        }
                    )
                    .foregroundColor(.white)
                    .padding(.horizontal, 36)
                    .padding(.bottom, UIDevice.current.userInterfaceIdiom == .pad ? (layoutModel.isCompactWidth ? 14 : 38) : 0)
                } else {
                    Button(action: {
                        let tipLevels: [Product?] = [smallTipProduct, mediumTipProduct, bigTipProduct, biggerTipProduct, biggestTipProduct]
                        let selectedProduct = tipLevels[selectedTipLevel]
                        if let product = selectedProduct {
                            Task { await purchase(product) }
                        }
                    }) {
                        let tipLevels: [Product?] = [smallTipProduct, mediumTipProduct, bigTipProduct, biggerTipProduct, biggestTipProduct]
                        let selectedProduct = tipLevels[selectedTipLevel]
                        let priceText = selectedProduct?.displayPrice ?? ""
                        Text(priceText.isEmpty ? "Unterstützen" : "Unterstützen \(priceText)")
                            .monospacedDigit()
                            .fontWeight(.semibold)
                            .frame(minWidth: 0, maxWidth: 420)
                            .padding(.vertical, 15)
                    }
                    .background(
                        Group {
                            if UIDevice.current.userInterfaceIdiom == .pad {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(.blue)
                            } else {
                                Capsule()
                                    .fill(.blue)
                            }
                        }
                    )
                    .foregroundColor(.white)
                    .padding(.horizontal, 36)
                    .padding(.bottom, UIDevice.current.userInterfaceIdiom == .pad ? (layoutModel.isCompactWidth ? 14 : 38) : 0)
                    .disabled({
                        let tipLevels: [Product?] = [smallTipProduct, mediumTipProduct, bigTipProduct, biggerTipProduct, biggestTipProduct]
                        let selectedProduct = tipLevels[selectedTipLevel]
                        return selectedProduct == nil || isPurchasing
                    }())
                    .redacted(reason: {
                        let tipLevels: [Product?] = [smallTipProduct, mediumTipProduct, bigTipProduct, biggerTipProduct, biggestTipProduct]
                        let selectedProduct = tipLevels[selectedTipLevel]
                        return selectedProduct == nil ? .placeholder : []
                    }())
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
            let products = try await Product.products(for: ["smallTip", "mediumTip", "bigTip", "biggerTip", "biggestTip"])
            for product in products {
                switch product.id {
                case "smallTip": smallTipProduct = product
                case "mediumTip": mediumTipProduct = product
                case "bigTip": bigTipProduct = product
                case "biggerTip": biggerTipProduct = product
                case "biggestTip": biggestTipProduct = product
                default: break
                }
            }
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
