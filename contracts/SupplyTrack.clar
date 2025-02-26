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
