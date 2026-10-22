import Foundation
import Observation
import StoreKit
#if os(iOS)
import UIKit
#endif

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
        // The App Store can be slow to answer on first launch; try a few times before giving up.
        for attempt in 0..<3 {
            if let found = try? await Product.products(for: [Self.productID]).first {
                product = found
                return
            }
            try? await Task.sleep(for: .seconds(Double(attempt + 1)))
        }
    }

    #if os(iOS)
    /// The window the purchase sheet should appear over (needed on iPad and multi-window).
    private var activeScene: UIWindowScene? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
    }
    #endif

    func purchase() async {
        guard !busy else { return }
        busy = true
        message = nil
        defer { busy = false }
        if product == nil { await loadProduct() }
        guard let product else {
            message = "Couldn’t reach the App Store. Check your connection and try again."
            return
        }
        do {
            let result: Product.PurchaseResult
            #if os(iOS)
            if let scene = activeScene {
                result = try await product.purchase(confirmIn: scene)
            } else {
                result = try await product.purchase()
            }
            #else
            result = try await product.purchase()
            #endif
            switch result {
            case .success(let verification):
                guard case .verified(let t) = verification, t.productID == Self.productID else {
                    message = "Apple couldn’t verify that purchase, so nothing was unlocked."
                    return
                }
                await t.finish()
                await refresh()
                if unlocked { message = "Full game unlocked. Enjoy every city." }
            case .pending:
                message = "Your purchase is waiting for approval."
            case .userCancelled:
                break
            @unknown default:
                message = "Purchase didn’t complete."
            }
        } catch {
            message = "Purchase didn’t complete: \(error.localizedDescription)"
        }
    }

    func restore() async {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        do {
            try await AppStore.sync()
            await refresh()
            message = unlocked ? "Full game restored." : "No Full Game purchase found for this Apple Account."
        } catch {
            message = "Couldn’t restore purchases. Please try again."
        }
    }
}
