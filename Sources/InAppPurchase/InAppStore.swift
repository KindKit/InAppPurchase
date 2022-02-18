//
//  KindKitInAppStore
//

import Foundation
import StoreKit

public struct InAppStore {
}

public extension InAppStore {
    
    static var isAvailable: Bool {
        return SKPaymentQueue.canMakePayments()
    }
    
    @available(macOS, unavailable)
    @available(iOS 13.4, *)
    func showPriceConsentIfNeeded() {
        InAppManager.shared.showPriceConsentIfNeeded()
    }
    
    @available(macOS, unavailable)
    @available(iOS 14.0, *)
    func presentCodeRedemptionSheet() {
        InAppManager.shared.presentCodeRedemptionSheet()
    }
    
}
