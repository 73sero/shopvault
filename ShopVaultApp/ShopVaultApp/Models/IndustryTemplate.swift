import Foundation

/// Pre-defined product templates for first-launch onboarding.
/// Users pick one (or skip with `.empty`) to seed their inventory with realistic
/// example products that match their business type.
struct IndustryTemplate: Identifiable, Hashable {
    let id: String
    let label: String
    let icon: String
    let tagline: String
    let products: [TemplateProduct]
}

struct TemplateProduct: Hashable {
    let code: String
    let name: String
    let specification: String
    let price: Decimal
}

extension IndustryTemplate {
    static let all: [IndustryTemplate] = [
        cafeBakery,
        retailStore,
        serviceBusiness,
        empty
    ]

    static let cafeBakery = IndustryTemplate(
        id: "cafe",
        label: "Café & Bakery",
        icon: "cup.and.saucer.fill",
        tagline: "Espresso, baked goods, beans to take home",
        products: [
            TemplateProduct(code: "ESP",  name: "Espresso",        specification: "single shot", price: 2.20),
            TemplateProduct(code: "DOP",  name: "Doppio",          specification: "double shot", price: 3.00),
            TemplateProduct(code: "LAT",  name: "Latte",           specification: "300ml",       price: 4.20),
            TemplateProduct(code: "CAP",  name: "Cappuccino",      specification: "200ml",       price: 3.80),
            TemplateProduct(code: "AME",  name: "Americano",       specification: "250ml",       price: 3.20),
            TemplateProduct(code: "CRO",  name: "Croissant",       specification: "butter",      price: 2.80),
            TemplateProduct(code: "MUF",  name: "Muffin",          specification: "blueberry",   price: 3.20),
            TemplateProduct(code: "BNS",  name: "Beans Bag",       specification: "250g",        price: 14.00),
            TemplateProduct(code: "BNL",  name: "Beans Bag",       specification: "1kg",         price: 42.00)
        ]
    )

    static let retailStore = IndustryTemplate(
        id: "retail",
        label: "Retail Store",
        icon: "bag.fill",
        tagline: "Apparel, accessories, lifestyle goods",
        products: [
            TemplateProduct(code: "TEE-S", name: "T-Shirt",         specification: "S",           price: 24.00),
            TemplateProduct(code: "TEE-M", name: "T-Shirt",         specification: "M",           price: 24.00),
            TemplateProduct(code: "TEE-L", name: "T-Shirt",         specification: "L",           price: 24.00),
            TemplateProduct(code: "MUG",   name: "Ceramic Mug",     specification: "350ml",       price: 14.00),
            TemplateProduct(code: "NTB",   name: "Notebook",        specification: "A5 lined",    price: 12.00),
            TemplateProduct(code: "TOTE",  name: "Tote Bag",        specification: "canvas",      price: 18.00),
            TemplateProduct(code: "STK",   name: "Sticker Pack",    specification: "5 pieces",    price: 6.00),
            TemplateProduct(code: "CAP",   name: "Cap",             specification: "one size",    price: 22.00)
        ]
    )

    static let serviceBusiness = IndustryTemplate(
        id: "service",
        label: "Service Business",
        icon: "wrench.adjustable.fill",
        tagline: "Consultations, sessions, retainers",
        products: [
            TemplateProduct(code: "CON-30", name: "Consultation",   specification: "30 minutes",  price: 75.00),
            TemplateProduct(code: "CON-60", name: "Consultation",   specification: "60 minutes",  price: 140.00),
            TemplateProduct(code: "PRO-D",  name: "Project Day",    specification: "8 hours",     price: 980.00),
            TemplateProduct(code: "WSH",    name: "Workshop",       specification: "half day",    price: 450.00),
            TemplateProduct(code: "RET-M",  name: "Monthly Retainer", specification: "10 hours",  price: 1200.00),
            TemplateProduct(code: "DEP",    name: "Deposit",        specification: "booking",     price: 150.00)
        ]
    )

    static let empty = IndustryTemplate(
        id: "empty",
        label: "Start from scratch",
        icon: "tray",
        tagline: "Add your own products later",
        products: []
    )
}
