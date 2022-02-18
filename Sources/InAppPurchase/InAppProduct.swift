//
//  KindKitInAppStore
//

import Foundation
import StoreKit

public class InAppProduct {
    
    public unowned let purchase: InAppPurchase
    public private(set) var status: Status
    
    public init(purchase: InAppPurchase) {
        self.purchase = purchase
        self.status = .unknown
    }
    
}

public extension InAppProduct {
    
    enum Status {
        case unknown
        case loading
        case success(_ info: SKProduct)
        case failure(_ error: Error)
        case missing
    }
    
}

public extension InAppProduct {
    
    var skProduct: SKProduct? {
        switch self.status {
        case .success(let skProduct): return skProduct
        default: return nil
        }
    }
    
    var error: Error? {
        switch self.status {
        case .failure(let error): return error
        default: return nil
        }
    }
    
    var localizedPrice: String? {
        guard let skProduct = self.skProduct else { return nil }
        return self.localizedPrice(skProduct: skProduct)
    }
    
    var localizedTitle: String? {
        return self.skProduct?.localizedTitle
    }
    
    var localizedDescription: String? {
        return self.skProduct?.localizedDescription
    }

}

extension InAppProduct {
    
    func set(status: Status) {
        self.status = status
        self.purchase.didUpdate()
    }
    
    func localizedPrice(skProduct: SKProduct, locale: Locale? = nil) -> String? {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = locale ?? skProduct.priceLocale
        return formatter.string(from: skProduct.price)
    }
    
}
