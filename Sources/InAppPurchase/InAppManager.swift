//
//  KindKitInAppStore
//

import Foundation
import StoreKit
import KindKit
import TPInAppReceipt

class InAppManager : NSObject {
    
    private var _queue: SKPaymentQueue
    private var _verifyReceiptTask: DispatchWorkItem?
    private var _reverifyTimer: DispatchWorkItem?
    private var _purchases: [InAppPurchase] {
        return self._weakPurchases.compactMap({ $0.value })
    }
    private var _weakPurchases: [WeakObject< InAppPurchase >]
    private var _restoreControllers: [InAppRestoreController] {
        return self._weakRestoreControllers.compactMap({ $0.value })
    }
    private var _weakRestoreControllers: [WeakObject< InAppRestoreController >]
    private var _productsTask: DispatchWorkItem?
    private var _productsQueries: [ProductsQuery]
    
    override init() {
        self._queue = SKPaymentQueue.default()
        self._weakPurchases = []
        self._weakRestoreControllers = []
        self._productsQueries = []
        super.init()
        self._queue.add(self)
        #if os(iOS)
        NotificationCenter.default.addObserver(self, selector: #selector(_notificationEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
        #endif
    }
    
    deinit {
        #if os(iOS)
        NotificationCenter.default.removeObserver(self, name: UIApplication.didBecomeActiveNotification, object: nil)
        #endif
        self._reverifyTimer?.cancel()
        self._verifyReceiptTask?.cancel()
        self._productsTask?.cancel()
        self._productsQueries.removeAll()
        self._queue.remove(self)
    }
    
}

extension InAppManager {
    
    static let shared = InAppManager()
    
}

extension InAppManager {
    
    class ProductsQuery {
        
        var products: [InAppProduct]
        var skRequest: SKProductsRequest
        
        init(
            products: [InAppProduct],
            delegate: SKProductsRequestDelegate
        ) {
            self.products = products
            for product in self.products {
                product.set(status: .loading)
            }
            
            let productIds = products.compactMap({ $0.purchase.id })
            
            self.skRequest = SKProductsRequest(productIdentifiers: Set(productIds))
            self.skRequest.delegate = delegate
            self.skRequest.start()
        }
        
        deinit {
            self.skRequest.cancel()
        }
        
    }
    
}

extension InAppManager {
    
    func register(_ purchase: InAppPurchase) {
        self._weakPurchases.append(WeakObject(purchase))
        self._verifyReceiptIfNeeded()
    }

    func unregister(_ purchase: InAppPurchase) {
        self._weakPurchases.removeAll(where: {
            guard let existPurchase = $0.value else { return true }
            return existPurchase === purchase
        })
    }
    
    func register(_ controller: InAppRestoreController) {
        self._weakRestoreControllers.append(WeakObject(controller))
    }
    
    func unregister(_ controller: InAppRestoreController) {
        self._weakRestoreControllers.removeAll(where: {
            guard let existController = $0.value else { return true }
            return existController === controller
        })
    }

    func load(product: InAppProduct) {
        self._loadProductsIfNeeded()
    }
    
    func buy(
        payment: InAppPayment
    ) {
        guard let product = payment.purchase.product else {
            fatalError("Purchase '\(payment.purchase.id)' not loaded product")
        }
        guard let skProduct = product.skProduct else {
            fatalError("Invalid product status \(product.status) on purchase '\(payment.purchase.id)'")
        }
        let skPayment = SKMutablePayment(product: skProduct)
        skPayment.quantity = payment.options.quantity
        skPayment.applicationUsername = payment.options.applicationUsername
        #if os(iOS) || os(tvOS) || os(watchOS)
        if #available(iOS 8.3, watchOS 6.2, *) {
            skPayment.simulatesAskToBuyInSandbox = payment.options.simulatesAskToBuyInSandbox
        }
        #endif
        self._queue.add(skPayment)
    }
    
    func restore(
        applicationUsername: String?
    ) {
        self._queue.restoreCompletedTransactions(
            withApplicationUsername: applicationUsername
        )
    }
    
    @available(macOS, unavailable)
    @available(iOS 13.4, *)
    func showPriceConsentIfNeeded() {
        self._queue.showPriceConsentIfNeeded()
    }
    
    @available(macOS, unavailable)
    @available(iOS 14.0, *)
    func presentCodeRedemptionSheet() {
        self._queue.presentCodeRedemptionSheet()
    }
    
}

private extension InAppManager {
    
    @objc
    func _notificationEnterForeground() {
        self._verifyReceiptIfNeeded()
    }
    
    func _loadProductsIfNeeded() {
        if self._productsTask == nil {
            let task = DispatchWorkItem(block: { [unowned self] in
                self._doLoadProducts()
            })
            DispatchQueue.main.async(execute: task)
            self._productsTask = task
        }
    }
    
    func _doLoadProducts() {
        self._productsTask = nil
        self._loadProducts()
    }
    
    func _loadProducts() {
        let products: [InAppProduct] = self._purchases.compactMap({
            guard let product = $0.product else { return nil }
            switch product.status {
            case .unknown, .failure: return product
            default: return nil
            }
        })
        if products.isEmpty == false {
            self._productsQueries.append(ProductsQuery(
                products: products,
                delegate: self
            ))
        }
    }
    
    func _finishRestorePurchases(error: Error?) {
        for restoreController in self._restoreControllers {
            restoreController.finish(error: error)
        }
    }
    
    func _verifyReceiptIfNeeded() {
        if self._verifyReceiptTask == nil {
            let task = DispatchWorkItem(block: { [unowned self] in
                self._doVerifyReceipt()
            })
            DispatchQueue.main.async(execute: task)
            self._verifyReceiptTask = task
        }
    }
    
    func _doVerifyReceipt() {
        self._verifyReceiptTask = nil
        self._verifyLocalReceipt()
    }
    
    func _verifyLocalReceipt() {
        do {
            let receipt = try InAppReceipt.localReceipt()
            try receipt.verifyHash()
            try receipt.verifyBundleIdentifier()
            try receipt.verifySignature()
            try receipt.validate()
            
            let nowDate = Date()
            var expirationDates: [Date] = []
            for purchase in self._purchases {
                if let subscriptionTransition = receipt.lastAutoRenewableSubscriptionPurchase(ofProductIdentifier: purchase.id) {
                    let purchaseDate = subscriptionTransition.purchaseDate
                    let expirationDate = subscriptionTransition.subscriptionExpirationDate!
                    let durationDelta = expirationDate.timeIntervalSince1970 - purchaseDate.timeIntervalSince1970
                    let correctExpirationDate: Date
                    if durationDelta > 60 * 60 * 24 {
                        correctExpirationDate = expirationDate.addingTimeInterval(purchase.config.production.extraExpirationInterval)
                    } else {
                        correctExpirationDate = expirationDate.addingTimeInterval(purchase.config.sandbox.extraExpirationInterval)
                    }
                    purchase.set(status: .subcription(InAppPurchase.Status.Subcription(
                        date: purchaseDate,
                        expirationDate: correctExpirationDate,
                        cancelationDate: subscriptionTransition.cancellationDate
                    )))
                    if nowDate >= purchaseDate && nowDate <= expirationDate {
                        expirationDates.append(correctExpirationDate)
                    }
                } else {
                    let receiptTransactions = receipt.purchases(ofProductIdentifier: purchase.id)
                    if receiptTransactions.isEmpty == false {
                        purchase.set(status: .piece(receiptTransactions.compactMap({
                            InAppPurchase.Status.Piece(date: $0.purchaseDate, quantity: $0.quantity)
                        })))
                    } else {
                        purchase.set(status: .empty)
                    }
                }
            }
            if let expirationDate = expirationDates.sorted().first {
                self._startReverifyTimer(nowDate: nowDate, expirationDate: expirationDate)
            } else {
                self._stopReverifyTimer()
            }
        } catch IARError.initializationFailed(reason: .appStoreReceiptNotFound) {
            for purchase in self._purchases {
                purchase.set(status: .empty)
            }
            self._stopReverifyTimer()
        } catch {
            self._stopReverifyTimer()
        }
    }
    
    func _startReverifyTimer(nowDate: Date, expirationDate: Date) {
        let dateComponents = Calendar.current.dateComponents([ .second ], from: nowDate, to: expirationDate)
        if let seconds = dateComponents.second, seconds > 0 {
            let timer = DispatchWorkItem(block: { [unowned self] in
                self._stopReverifyTimer()
                self._verifyReceiptIfNeeded()
            })
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(seconds), execute: timer)
            self._reverifyTimer = timer
        } else {
            self._stopReverifyTimer()
        }
    }

    func _stopReverifyTimer() {
        guard let reverifyTimer = self._reverifyTimer else { return }
        reverifyTimer.cancel()
        self._reverifyTimer = nil
    }

}

extension InAppManager : SKRequestDelegate {
    
    @objc
    func request(_ request: SKRequest, didFailWithError error: Error) {
        DispatchQueue.main.async(execute: {
            if let index = self._productsQueries.firstIndex(where: { $0.skRequest === request }) {
                let productQuery = self._productsQueries.remove(at: index)
                for product in productQuery.products {
                    product.set(status: .failure(error))
                }
            }
        })
    }
    
}

extension InAppManager : SKProductsRequestDelegate {
    
    @objc
    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        DispatchQueue.main.async(execute: {
            guard let index = self._productsQueries.firstIndex(where: { $0.skRequest === request }) else { return }
            let productQuery = self._productsQueries.remove(at: index)
            for product in productQuery.products {
                if let skProduct = response.products.first(where: { $0.productIdentifier == product.purchase.id }) {
                    product.set(status: .success(skProduct))
                } else {
                    product.set(status: .missing)
                }
            }
        })
    }
    
}

extension InAppManager : SKPaymentTransactionObserver {
    
    @objc
    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        DispatchQueue.main.async(execute: {
            for transaction in transactions {
                switch transaction.transactionState {
                case .purchasing:
                    if let purchase = self._purchases.first(where: { $0.id == transaction.payment.productIdentifier }) {
                        let payment = purchase.payment(transaction: transaction)
                        payment.set(status: .purchasing)
                    }
                case .purchased:
                    if let purchase = self._purchases.first(where: { $0.id == transaction.payment.productIdentifier }) {
                        let payment = purchase.payment(transaction: transaction)
                        payment.set(status: .purchased)
                        queue.finishTransaction(transaction)
                    }
                    queue.finishTransaction(transaction)
                case .restored:
                    if let purchase = self._purchases.first(where: { $0.id == transaction.payment.productIdentifier }) {
                        for controller in self._restoreControllers {
                            controller.restore(purchase: purchase)
                        }
                    }
                    queue.finishTransaction(transaction)
                case .deferred:
                    if let purchase = self._purchases.first(where: { $0.id == transaction.payment.productIdentifier }) {
                        let payment = purchase.payment(transaction: transaction)
                        payment.set(status: .deferred)
                    }
                case .failed:
                    if let purchase = self._purchases.first(where: { $0.id == transaction.payment.productIdentifier }) {
                        let payment = purchase.payment(transaction: transaction)
                        if let error = transaction.error {
                            if let error = error as? SKError {
                                switch error.code {
                                case .paymentCancelled: payment.set(status: .cancelled)
                                default: payment.set(status: .failure(error))
                                }
                            } else {
                                payment.set(status: .failure(error))
                            }
                        } else {
                            payment.set(status: .failure(SKError(.unknown)))
                        }
                        queue.finishTransaction(transaction)
                    }
                @unknown default:
                    break
                }
            }
        })
    }
    
    @objc
    func paymentQueue(_ queue: SKPaymentQueue, removedTransactions transactions: [SKPaymentTransaction]) {
        DispatchQueue.main.async(execute: {
            self._verifyReceiptIfNeeded()
        })
    }
    
    @objc
    func paymentQueue(_ queue: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: Error) {
        DispatchQueue.main.async(execute: {
            self._finishRestorePurchases(error: error)
        })
    }
    
    @objc
    func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) {
        DispatchQueue.main.async(execute: {
            self._doVerifyReceipt()
            self._finishRestorePurchases(error: nil)
        })
    }
    
    @objc
    func paymentQueue(_ queue: SKPaymentQueue, didRevokeEntitlementsForProductIdentifiers productIdentifiers: [String]) {
        DispatchQueue.main.async(execute: {
            self._verifyReceiptIfNeeded()
        })
    }
    
}
