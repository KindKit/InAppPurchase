//
//  KindKitInAppStore
//

import Foundation
import StoreKit
import KindKit

public class InAppPayment {
    
    public unowned let purchase: InAppPurchase
    public let options: Options
    public private(set) var status: Status
    
    init(
        purchase: InAppPurchase,
        options: Options
    ) {
        self.purchase = purchase
        self.options = options
        self.status = .unknown
    }
    
}

public extension InAppPayment {

    enum Status {
        case unknown
        case purchasing
        case purchased
        case deferred
        case failure(_ error: Error)
        case cancelled
    }

}

public extension InAppPayment {
    
    struct Options {
        
        public let quantity: Int
        public let applicationUsername: String?
        public let simulatesAskToBuyInSandbox: Bool
        
        public init(
            quantity: Int = 1,
            applicationUsername: String? = nil,
            simulatesAskToBuyInSandbox: Bool = false
        ) {
            self.quantity = quantity
            self.applicationUsername = applicationUsername
            self.simulatesAskToBuyInSandbox = simulatesAskToBuyInSandbox
        }
        
        init(
            payment: SKPayment
        ) {
            self.quantity = payment.quantity
            self.applicationUsername = payment.applicationUsername
            if #available(macOS 10.14, *) {
                self.simulatesAskToBuyInSandbox = payment.simulatesAskToBuyInSandbox
            } else {
                self.simulatesAskToBuyInSandbox = false
            }
        }
        
    }
    
}

public extension InAppPayment {
    
    var error: Error? {
        switch self.status {
        case .failure(let error): return error
        default: return nil
        }
    }
    
}

extension InAppPayment {
    
    func set(status: Status) {
        self.status = status
        self.purchase.didUpdate()
    }
    
}
