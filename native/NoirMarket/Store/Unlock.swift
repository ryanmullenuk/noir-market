import Foundation
import Observation
import StoreKit

/// The one in-app purchase: a non-consumable that opens all 14 cities.
/// The entitlement lives with StoreKit, never inside the save, so a new game can't lose it.
@MainActor
@Observable
final class Unlock {
    static let productID = "games.redhead.noirmarket.unlockallcities"

    private(set) var unlocked = false
    private(set) var product: Product?
    private(set) var busy = false
    var message: String?
    var onChange: ((Bool) -> Void)?
    @ObservationIgnored private var updates: Task<Void, Never>?

    /// True when the full game has been bought.
    var full: Bool { unlocked }

    /// Exactly what the purchase includes, shown wherever it's offered.
    static let includes = "All 14 cities · Long Game and Sprint · three backgrounds · four colour palettes"

    func start() async {
        if updates == nil {
            updates = Task { [weak self] in
                for await result in Transaction.updates {
                    guard case .verified(let transaction) = result, transaction.productID == Self.productID else { continue }
                    await self?.refresh()
                    await transaction.finish()
                }
            }
        }
        await refresh()
        await loadProduct()
    }

    func refresh() async {
        var entitled = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let t) = result, t.productID == Self.productID, t.revocationDate == nil { entitled = true }
        }
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-unlockAll") { entitled = true }
        #endif
        unlocked = entitled
        onChange?(entitled)
    }

    func loadProduct() async {
        guard product == nil else { return }
        product = try? await Product.products(for: [Self.productID]).first
    }

    func purchase() async {
        guard !busy else { return }
        if product == nil { await loadProduct() }
        guard let product else {
            message = "The App Store isn’t answering. Try again in a moment."
            return
        }
        busy = true
        message = nil
        defer { busy = false }
        do {
            switch try await product.purchase() {
            case .success(let result):
                guard case .verified(let t) = result, t.productID == Self.productID else {
                    message = "Apple couldn’t verify that purchase, so nothing was unlocked."
                    return
                }
                await t.finish()
                await refresh()
            case .pending:
                message = "Your purchase is waiting for approval."
            case .userCancelled:
                break
            @unknown default:
                message = "Purchase didn’t complete."
            }
        } catch {
            message = "Purchase didn’t complete. Please try again later."
        }
    }

    func restore() async {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        do {
            try await AppStore.sync()
            await refresh()
            message = unlocked ? "All cities restored." : "No unlock found for this Apple Account."
        } catch {
            message = "Couldn’t restore purchases. Please try again."
        }
    }
}
