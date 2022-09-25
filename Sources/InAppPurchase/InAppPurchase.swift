//
//  KindKitInAppStore
//

import Foundation
import StoreKit
import KindKit

public protocol IInAppPurchaseObserver : AnyObject {
    
    func didUpdate(_ purchase: InAppPurchase)
    
}

public class InAppPurchase {
    
    public let id: String
    public let config: Config
    public private(set) var status: Status
    public private(set) var product: InAppProduct?
    public private(set) var payment: InAppPayment?
    
    private var _observer: Observer< IInAppPurchaseObserver >
    
    public init(
        id: String,
        config: Config = Config()
    ) {
        self.id = id
        self.config = config
        self.status = .unknown
        self._observer = Observer()
        InAppManager.shared.register(self)
    }
    
    deinit {
        InAppManager.shared.unregister(self)
    }
    
    public func add(observer: IInAppPurchaseObserver, priority: ObserverPriority) {
        self._observer.add(observer, priority: priority)
    }
    
    public func remove(observer: IInAppPurchaseObserver) {
        self._observer.remove(observer)
    }
    
}

public extension InAppPurchase {
    
    struct Config {
        
        public let production: ConfigVariant
        public let sandbox: ConfigVariant
        
        public init(
            production: ConfigVariant = ConfigVariant(extraExpirationInterval: 60 * 60),
            sandbox: ConfigVariant = ConfigVariant(extraExpirationInterval: 60)
        ) {
            self.production = production
            self.sandbox = sandbox
        }
        
    }
    
    struct ConfigVariant {
        
        public let extraExpirationInterval: TimeInterval
        
        public init(
            extraExpirationInterval: TimeInterval
        ) {
            self.extraExpirationInterval = extraExpirationInterval
        }
        
    }

    enum Status : Equatable {
        case unknown
        case piece(_ data: [Piece])
        case subcription(_ data: Subcription)
        case empty
    }

}

public extension InAppPurchase.Status {
    
    struct Piece : Equatable {
        
        public let date: Date
        public var quantity: Int = 1

    }
    
    struct Subcription : Equatable {
        
        public let date: Date
        public let expirationDate: Date
        public let cancelationDate: Date?

    }
    
}

public extension InAppPurchase {
    
    var skProduct: SKProduct? {
        return self.product?.skProduct
    }
    
}

extension InAppPurchase {
    
    @discardableResult
    func load() -> InAppProduct {
        if let product = self.product {
            switch product.status {
            case .unknown, .loading, .success:
                return product
            case .failure, .missing:
                break
            }
        }
        let product = InAppProduct(purchase: self)
        self.product = product
        InAppManager.shared.load(product: product)
        return product
    }
    
    @discardableResult
    func buy(
        product: InAppProduct,
        options: InAppPayment.Options
    ) -> InAppPayment {
        if let payment = self.payment {
            switch payment.status {
            case .unknown, .purchasing, .deferred:
                return payment
            case .purchased, .failure, .cancelled:
                break
            }
        }
        let payment = InAppPayment(purchase: self, options: options)
        self.payment = payment
        InAppManager.shared.buy(payment: payment)
        return payment
    }
    
    @discardableResult
    func payment(transaction: SKPaymentTransaction) -> InAppPayment {
        if let payment = self.payment {
            return payment
        }
        let payment = InAppPayment(purchase: self, options: InAppPayment.Options(payment: transaction.payment))
        self.payment = payment
        return payment
    }
    
    func set(status: Status) {
        self.status = status
        self.didUpdate()
    }
    
    func didUpdate() {
        self._observer.notify({ $0.didUpdate(self) })
    }
    
}
