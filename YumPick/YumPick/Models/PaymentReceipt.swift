import Foundation

struct PaymentReceipt: Codable, Identifiable {
    // required
    let imp_uid: String
    let merchant_uid: String
    let amount: Int
    let currency: String
    let status: String

    // payment method / channel
    let pay_method: String?
    let channel: String?
    let pg_provider: String?
    let emb_pg_provider: String?
    let pg_tid: String?
    let pg_id: String?
    let escrow: Bool?
    let apply_num: String?

    // bank
    let bank_code: String?
    let bank_name: String?

    // card
    let card_code: String?
    let card_name: String?
    let card_issuer_code: String?
    let card_issuer_name: String?
    let card_publisher_code: String?
    let card_publisher_name: String?
    let card_quota: Int?
    let card_number: String?
    let card_type: Int?

    // virtual account
    let vbank_code: String?
    let vbank_name: String?
    let vbank_num: String?
    let vbank_holder: String?
    let vbank_date: Int?
    let vbank_issued_at: Int?

    // product / buyer
    let name: String?
    let buyer_name: String?
    let buyer_email: String?
    let buyer_tel: String?
    let buyer_addr: String?
    let buyer_postcode: String?
    let custom_data: String?
    let user_agent: String?

    // timestamps + receipt
    let startedAt: String?
    let paidAt: String?
    let receipt_url: String?
    let createdAt: String?
    let updatedAt: String?

    var id: String { imp_uid }
}

#if DEBUG
extension PaymentReceipt {
    static let sample = PaymentReceipt(
        imp_uid: "imp_1234567890",
        merchant_uid: "A1234",
        amount: 10_000,
        currency: "KRW",
        status: "paid",
        pay_method: "card",
        channel: "pc",
        pg_provider: "html5_inicis",
        emb_pg_provider: nil,
        pg_tid: "StdpayCARDINIpayTest20250507000000000",
        pg_id: nil,
        escrow: false,
        apply_num: "12345678",
        bank_code: nil,
        bank_name: nil,
        card_code: "366",
        card_name: "신한카드",
        card_issuer_code: nil,
        card_issuer_name: nil,
        card_publisher_code: nil,
        card_publisher_name: nil,
        card_quota: 0,
        card_number: "411111*********1",
        card_type: 0,
        vbank_code: nil,
        vbank_name: nil,
        vbank_num: nil,
        vbank_holder: nil,
        vbank_date: nil,
        vbank_issued_at: nil,
        name: "크림 도넛 외 2건",
        buyer_name: "홍길동",
        buyer_email: "test@yumpick.kr",
        buyer_tel: "010-0000-0000",
        buyer_addr: nil,
        buyer_postcode: nil,
        custom_data: nil,
        user_agent: nil,
        startedAt: "2025-04-26T15:00:00.000Z",
        paidAt: "2025-04-26T15:00:12.000Z",
        receipt_url: "https://www.iamport.kr/",
        createdAt: "2025-04-26T15:00:12.000Z",
        updatedAt: "2025-04-26T15:00:12.000Z"
    )
}
#endif
