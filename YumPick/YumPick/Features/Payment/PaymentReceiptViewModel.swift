import Foundation

@Observable
final class PaymentReceiptViewModel {
    var receipt: PaymentReceipt? = nil
    var isLoading = false
    var errorMessage: String? = nil

    private let client: PaymentClientProtocol

    init(client: PaymentClientProtocol = PaymentClient()) {
        self.client = client
    }

    func load(orderCode: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            receipt = try await client.fetchReceipt(orderCode: orderCode)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
