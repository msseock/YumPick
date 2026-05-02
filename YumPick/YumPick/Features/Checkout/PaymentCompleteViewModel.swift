import Foundation

@Observable
final class PaymentCompleteViewModel {

    enum Phase {
        case validating
        case success
        case failure
    }

    // MARK: - State

    let orderCode: String
    let totalPrice: Int
    var phase: Phase = .validating
    var errorMessage: String? = nil
    var result: PaymentValidationResponse? = nil

    // MARK: - Dependencies

    private let checkoutClient: CheckoutClientProtocol

    init(
        orderCode: String,
        totalPrice: Int,
        checkoutClient: CheckoutClientProtocol = CheckoutClient()
    ) {
        self.orderCode = orderCode
        self.totalPrice = totalPrice
        self.checkoutClient = checkoutClient
    }

    // MARK: - Actions

    func validate(impUid: String) async {
        phase = .validating
        do {
            result = try await checkoutClient.validatePayment(impUid: impUid)
            phase = .success
        } catch {
            errorMessage = error.localizedDescription
            phase = .failure
        }
    }
}
