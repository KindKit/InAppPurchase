//
//  KindKitInAppStore
//

import Foundation
import StoreKit
import TPInAppReceipt
import KindKitCore
import KindKitObserver

public protocol IInAppSubscriptionControllerObserver : AnyObject {
    
    func didChange(_ controller: InAppSubscriptionController, canActive: Bool)
    
}

public class InAppSubscriptionController {
    
    public let purchases: [InAppPurchase]
    public private(set) var canActive: Bool
    
    private var _observer: Observer< IInAppSubscriptionControllerObserver >

    public init(
        purchases: [InAppPurchase],
        canActive: Bool
    ) {
        self.purchases = purchases
        self.canActive = canActive
        self._observer = Observer()
        self._subscribe()
    }
    
    deinit {
        self._unsubscribe()
    }
    
    public func add(observer: IInAppSubscriptionControllerObserver, priority: ObserverPriority) {
        self._observer.add(observer, priority: priority)
    }
    
    public func remove(observer: IInAppSubscriptionControllerObserver) {
        self._observer.remove(observer)
    }
    
}

private extension InAppSubscriptionController {
    
    func _subscribe() {
        for purchase in self.purchases {
            purchase.add(observer: self, priority: .utility)
        }
    }
    
    func _unsubscribe() {
        for purchase in self.purchases {
            purchase.remove(observer: self)
        }
    }
    
    func _canActive() -> Bool? {
        let now = Date()
        for purchase in self.purchases {
            switch purchase.status {
            case .unknown:
                return nil
            case .subcription(let data):
                if now < data.expirationDate {
                    return true
                }
            case .piece, .empty:
                break
            }
        }
        return false
    }
    
}

extension InAppSubscriptionController : IInAppPurchaseObserver {
    
    public func didUpdate(_ purchase: InAppPurchase) {
        if let canActive = self._canActive() {
            if self.canActive != canActive {
                self.canActive = canActive
                self._observer.notify({ $0.didChange(self, canActive: canActive) })
            }
        }
    }
    
}
