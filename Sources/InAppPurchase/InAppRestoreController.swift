//
//  KindKitInAppStore
//

import Foundation
import StoreKit
import KindKit
import TPInAppReceipt

public protocol IInAppRestoreControllerObserver : AnyObject {
    
    func didFinish(_ controller: InAppRestoreController, purchases: [InAppPurchase], error: Error?)
    
}

public class InAppRestoreController {
    
    public let applicationUsername: String?
    public private(set) var isRestoring: Bool
    
    private var _observer: Observer< IInAppRestoreControllerObserver >
    private var _purchases: [InAppPurchase]

    public init(
        applicationUsername: String? = nil
    ) {
        self.applicationUsername = applicationUsername
        self.isRestoring = false
        self._observer = Observer()
        self._purchases = []
    }
    
    public func add(observer: IInAppRestoreControllerObserver, priority: ObserverPriority) {
        self._observer.add(observer, priority: priority)
    }
    
    public func remove(observer: IInAppRestoreControllerObserver) {
        self._observer.remove(observer)
    }
    
    public func restore() {
        guard self.isRestoring == false else { return }
        self.isRestoring = true
        InAppManager.shared.register(self)
        InAppManager.shared.restore(
            applicationUsername: self.applicationUsername
        )
    }
    
}

extension InAppRestoreController {
    
    func restore(purchase: InAppPurchase) {
        if self._purchases.contains(where: { $0.id == purchase.id }) == false {
            self._purchases.append(purchase)
        }
    }
    
    func finish(error: Error?) {
        self._observer.notify({ $0.didFinish(self, purchases: self._purchases, error: error) })
        self._purchases.removeAll()
        InAppManager.shared.unregister(self)
        self.isRestoring = false
    }
    
}
