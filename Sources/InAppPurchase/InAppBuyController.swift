//
//  KindKitInAppStore
//

import Foundation
import StoreKit
import TPInAppReceipt
import KindKitCore
import KindKitObserver

public protocol IInAppBuyControllerObserver : AnyObject {
    
    func didPurchasing(_ controller: InAppBuyController)
    func didPurchased(_ controller: InAppBuyController)
    func didDeferred(_ controller: InAppBuyController)
    func didFailure(_ controller: InAppBuyController, error: Error)
    func didCancelled(_ controller: InAppBuyController)
    
}

public class InAppBuyController {
    
    public let purchase: InAppPurchase
    public let options: InAppPayment.Options
    public private(set) var isLoading: Bool
    public private(set) var isBuying: Bool
    
    private var _observer: Observer< IInAppBuyControllerObserver >

    public init(
        purchase: InAppPurchase,
        options: InAppPayment.Options
    ) {
        self.purchase = purchase
        self.options = options
        self.isLoading = false
        self.isBuying = false
        self._observer = Observer()
        self._subscribe()
    }
    
    deinit {
        self._unsubscribe()
    }
    
    public func add(observer: IInAppBuyControllerObserver, priority: ObserverPriority) {
        self._observer.add(observer, priority: priority)
    }
    
    public func remove(observer: IInAppBuyControllerObserver) {
        self._observer.remove(observer)
    }
    
    public func buy() {
        guard self.isLoading == false && self.isBuying == false else { return }
        if let product = self.purchase.product {
            self._buy(product: product)
        } else {
            self._load()
        }
    }
    
}

private extension InAppBuyController {
    
    func _subscribe() {
        self.purchase.add(observer: self, priority: .utility)
    }
    
    func _unsubscribe() {
        self.purchase.remove(observer: self)
    }
    
    func _load() {
        self.isLoading = true
        self.purchase.load()
    }
    
    func _buy(product: InAppProduct) {
        self.isBuying = true
        self.purchase.buy(
            product: product,
            options: self.options
        )
    }
    
}

extension InAppBuyController : IInAppPurchaseObserver {
    
    public func didUpdate(_ purchase: InAppPurchase) {
        if self.isLoading == true {
            if let product = self.purchase.product {
                self.isLoading = false
                self._buy(product: product)
            }
        } else if self.isBuying == true {
            if let payment = self.purchase.payment {
                switch payment.status {
                case .unknown: break
                case .purchasing:
                    self._observer.notify({ $0.didPurchasing(self) })
                case .purchased:
                    switch self.purchase.status {
                    case .unknown, .empty:
                        break
                    case .piece, .subcription:
                        self.isBuying = false
                        self._observer.notify({ $0.didPurchased(self) })
                    }
                case .deferred:
                    self.isBuying = false
                    self._observer.notify({ $0.didDeferred(self) })
                case .failure(let error):
                    self.isBuying = false
                    self._observer.notify({ $0.didFailure(self, error: error) })
                case .cancelled:
                    self.isBuying = false
                    self._observer.notify({ $0.didCancelled(self) })
                }
            }
        }
    }
    
}
