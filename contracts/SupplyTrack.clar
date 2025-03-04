;; SupplyTrack Pro - Supply Chain Verification Service

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-not-authorized (err u100))
(define-constant err-product-exists (err u101))
(define-constant err-invalid-supplier (err u102))

;; Data Maps
(define-map products 
    { product-id: uint }
    {
        name: (string-ascii 50),
        supplier: principal,
        status: (string-ascii 20),
        timestamp: uint,
        verified: bool
    }
)

(define-map suppliers
    { supplier-id: principal }
    {
        name: (string-ascii 50),
        verified: bool,
        products-count: uint
    }
)

(define-map inventory
    { product-id: uint }
    {
        quantity: uint,
        last-updated: uint
    }
)

;; Public Functions

;; Add new product
(define-public (add-product (product-id uint) (name (string-ascii 50)))
    (let
        ((supplier tx-sender))
        (asserts! (is-supplier supplier) err-not-authorized)
        (ok (map-set products
            { product-id: product-id }
            {
                name: name,
                supplier: supplier,
                status: "created",
                timestamp: stacks-block-height,
                verified: false
            }
        ))
    )
)

;; Register supplier
(define-public (register-supplier (name (string-ascii 50)))
    (ok (map-set suppliers
        { supplier-id: tx-sender }
        {
            name: name,
            verified: false,
            products-count: u0
        }
    ))
)

;; Update inventory
(define-public (update-inventory (product-id uint) (quantity uint))
    (let
        ((supplier tx-sender))
        (asserts! (is-product-supplier product-id supplier) err-not-authorized)
        (ok (map-set inventory
            { product-id: product-id }
            {
                quantity: quantity,
                last-updated: stacks-block-height
            }
        ))
    )
)

;; Read Only Functions

;; Check if address is a supplier
(define-read-only (is-supplier (address principal))
    (default-to false (get verified (map-get? suppliers { supplier-id: address })))
)

;; Get product details
(define-read-only (get-product-details (product-id uint))
    (map-get? products { product-id: product-id })
)

;; Get supplier details
(define-read-only (get-supplier-details (supplier principal))
    (map-get? suppliers { supplier-id: supplier })
)

;; Get inventory level
(define-read-only (get-inventory-level (product-id uint))
    (map-get? inventory { product-id: product-id })
)

;; Private Functions

;; Check if sender is product supplier
(define-private (is-product-supplier (product-id uint) (supplier principal))
    (let
        ((product-data (map-get? products { product-id: product-id })))
        (and 
            (is-some product-data)
            (is-eq (get supplier (unwrap-panic product-data)) supplier)
        )
    )
)

;; Add to Data Maps
(define-map certifications
    { product-id: uint }
    {
        certification-type: (string-ascii 20),
        issuer: principal,
        expiry: uint,
        active: bool
    }
)

;; Add Public Function
(define-public (add-certification (product-id uint) (cert-type (string-ascii 20)) (expiry uint))
    (let
        ((supplier tx-sender))
        (asserts! (is-product-supplier product-id supplier) err-not-authorized)
        (ok (map-set certifications
            { product-id: product-id }
            {
                certification-type: cert-type,
                issuer: supplier,
                expiry: expiry,
                active: true
            }
        ))
    )
)


;; Add to Data Maps
(define-map location-history
    { product-id: uint, timestamp: uint }
    {
        location: (string-ascii 50),
        handler: principal
    }
)

;; Add Public Function
(define-public (update-location (product-id uint) (location (string-ascii 50)))
    (let
        ((handler tx-sender))
        (asserts! (is-supplier handler) err-not-authorized)
        (ok (map-set location-history
            { product-id: product-id, timestamp: stacks-block-height }
            {
                location: location,
                handler: handler
            }
        ))
    )
)



;; Add to Data Maps
(define-map batches
    { batch-id: uint }
    {
        product-id: uint,
        quantity: uint,
        production-date: uint,
        expiry-date: uint
    }
)

;; Add Public Function
(define-public (create-batch (batch-id uint) (product-id uint) (quantity uint) (expiry-date uint))
    (let
        ((supplier tx-sender))
        (asserts! (is-product-supplier product-id supplier) err-not-authorized)
        (ok (map-set batches
            { batch-id: batch-id }
            {
                product-id: product-id,
                quantity: quantity,
                production-date: stacks-block-height,
                expiry-date: expiry-date
            }
        ))
    )
)



;; Add to Data Maps
(define-map price-history
    { product-id: uint, timestamp: uint }
    {
        price: uint,
        currency: (string-ascii 10)
    }
)

;; Add Public Function
(define-public (update-price (product-id uint) (new-price uint) (currency (string-ascii 10)))
    (let
        ((supplier tx-sender))
        (asserts! (is-product-supplier product-id supplier) err-not-authorized)
        (ok (map-set price-history
            { product-id: product-id, timestamp: stacks-block-height }
            {
                price: new-price,
                currency: currency
            }
        ))
    )
)



;; Add to Data Maps
(define-map transfers
    { transfer-id: uint }
    {
        product-id: uint,
        from: principal,
        to: principal,
        quantity: uint,
        timestamp: uint
    }
)

;; Add Public Function
(define-public (transfer-product (transfer-id uint) (product-id uint) (to principal) (quantity uint))
    (let
        ((sender tx-sender))
        (asserts! (is-product-supplier product-id sender) err-not-authorized)
        (ok (map-set transfers
            { transfer-id: transfer-id }
            {
                product-id: product-id,
                from: sender,
                to: to,
                quantity: quantity,
                timestamp: stacks-block-height
            }
        ))
    )
)



;; Add to Data Maps
(define-map warranties
    { product-id: uint }
    {
        duration: uint,
        terms: (string-ascii 100),
        issuer: principal,
        active: bool
    }
)

;; Add Public Function
(define-public (add-warranty (product-id uint) (duration uint) (terms (string-ascii 100)))
    (let
        ((supplier tx-sender))
        (asserts! (is-product-supplier product-id supplier) err-not-authorized)
        (ok (map-set warranties
            { product-id: product-id }
            {
                duration: duration,
                terms: terms,
                issuer: supplier,
                active: true
            }
        ))
    )
)
