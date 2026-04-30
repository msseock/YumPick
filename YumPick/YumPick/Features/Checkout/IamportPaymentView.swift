import SwiftUI
import iamport_ios

struct IamportPaymentView: UIViewControllerRepresentable {
    let payment: IamportPayment
    let onResult: (IamportResponse?) -> Void

    func makeUIViewController(context: Context) -> IamportPaymentViewController {
        IamportPaymentViewController(payment: payment, onResult: onResult)
    }

    func updateUIViewController(_ uiViewController: IamportPaymentViewController, context: Context) {}
}

final class IamportPaymentViewController: UIViewController {
    private let payment: IamportPayment
    private let onResult: (IamportResponse?) -> Void
    private var hasStartedPayment = false

    init(payment: IamportPayment, onResult: @escaping (IamportResponse?) -> Void) {
        self.payment = payment
        self.onResult = onResult
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !hasStartedPayment else { return }
        hasStartedPayment = true
        Iamport.shared.payment(
            viewController: self,
            userCode: SecretConstants.impUserCode,
            payment: payment
        ) { [weak self] response in
            self?.onResult(response)
        }
    }
}
