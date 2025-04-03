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

;; new product
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

;; to Data Maps
(define-map certifications
    { product-id: uint }
    {
        certification-type: (string-ascii 20),
        issuer: principal,
        expiry: uint,
        active: bool
    }
)

;; Public Function
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


;; to Data Maps
(define-map location-history
    { product-id: uint, timestamp: uint }
    {
        location: (string-ascii 50),
        handler: principal
    }
)

;; Public Function
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



;; to Data Maps
(define-map batches
    { batch-id: uint }
    {
        product-id: uint,
        quantity: uint,
        production-date: uint,
        expiry-date: uint
    }
)

;; Public Function
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



;; to Data Maps
(define-map price-history
    { product-id: uint, timestamp: uint }
    {
        price: uint,
        currency: (string-ascii 10)
    }
)

;; Public Function
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



;; to Data Maps
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

;; Public Function
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



;; to Data Maps
(define-map warranties
    { product-id: uint }
    {
        duration: uint,
        terms: (string-ascii 100),
        issuer: principal,
        active: bool
    }
)

;; Public Function
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


;; to Constants
(define-constant err-invalid-rating (err u103))

;; to Data Maps
(define-map quality-reports
    { product-id: uint, report-id: uint }
    {
        inspector: principal,
        rating: uint,
        notes: (string-ascii 200),
        timestamp: uint
    }
)

;; Public Function
(define-public (submit-quality-report 
    (product-id uint) 
    (report-id uint)
    (rating uint)
    (notes (string-ascii 200)))
    (let
        ((inspector tx-sender))
        (asserts! (is-supplier inspector) err-not-authorized)
        (asserts! (<= rating u10) err-invalid-rating)
        (ok (map-set quality-reports
            { product-id: product-id, report-id: report-id }
            {
                inspector: inspector,
                rating: rating,
                notes: notes,
                timestamp: stacks-block-height
            }
        ))
    )
)


(define-map recalls
    { recall-id: uint }
    {
        product-id: uint,
        reason: (string-ascii 200),
        severity: uint,
        recall-date: uint,
        resolved: bool
    }
)

;; Public Function
(define-public (initiate-recall 
    (recall-id uint)
    (product-id uint)
    (reason (string-ascii 200))
    (severity uint))
    (let
        ((supplier tx-sender))
        (asserts! (is-product-supplier product-id supplier) err-not-authorized)
        (ok (map-set recalls
            { recall-id: recall-id }
            {
                product-id: product-id,
                reason: reason,
                severity: severity,
                recall-date: stacks-block-height,
                resolved: false
            }
        ))
    )
)


;; to Data Maps
(define-map maintenance-schedule
    { product-id: uint, schedule-id: uint }
    {
        description: (string-ascii 100),
        interval: uint,
        last-maintenance: uint,
        next-due: uint
    }
)

;; Public Function
(define-public (set-maintenance-schedule 
    (product-id uint)
    (schedule-id uint)
    (description (string-ascii 100))
    (interval uint))
    (let
        ((supplier tx-sender))
        (asserts! (is-product-supplier product-id supplier) err-not-authorized)
        (ok (map-set maintenance-schedule
            { product-id: product-id, schedule-id: schedule-id }
            {
                description: description,
                interval: interval,
                last-maintenance: stacks-block-height,
                next-due: (+ stacks-block-height interval)
            }
        ))
    )
)


;; to Data Maps
(define-map customer-feedback
    { product-id: uint, feedback-id: uint }
    {
        customer: principal,
        rating: uint,
        comment: (string-ascii 200),
        timestamp: uint
    }
)

;; Public Function
(define-public (submit-feedback
    (product-id uint)
    (feedback-id uint)
    (rating uint)
    (comment (string-ascii 200)))
    (ok (map-set customer-feedback
        { product-id: product-id, feedback-id: feedback-id }
        {
            customer: tx-sender,
            rating: rating,
            comment: comment,
            timestamp: stacks-block-height
        }
    ))
)

;; to Data Maps
(define-map product-documents
    { product-id: uint, doc-id: uint }
    {
        doc-type: (string-ascii 50),
        doc-hash: (string-ascii 64),
        version: uint,
        upload-date: uint
    }
)

;; Public Function
(define-public (add-product-document
    (product-id uint)
    (doc-id uint)
    (doc-type (string-ascii 50))
    (doc-hash (string-ascii 64))
    (version uint))
    (let
        ((supplier tx-sender))
        (asserts! (is-product-supplier product-id supplier) err-not-authorized)
        (ok (map-set product-documents
            { product-id: product-id, doc-id: doc-id }
            {
                doc-type: doc-type,
                doc-hash: doc-hash,
                version: version,
                upload-date: stacks-block-height
            }
        ))
    )
)

;; to Data Maps
(define-map environmental-metrics
    { product-id: uint, metric-id: uint }
    {
        carbon-footprint: uint,
        energy-usage: uint,
        waste-generated: uint,
        report-date: uint
    }
)

;; Public Function
(define-public (record-environmental-metrics
    (product-id uint)
    (metric-id uint)
    (carbon-footprint uint)
    (energy-usage uint)
    (waste-generated uint))
    (let
        ((supplier tx-sender))
        (asserts! (is-product-supplier product-id supplier) err-not-authorized)
        (ok (map-set environmental-metrics
            { product-id: product-id, metric-id: metric-id }
            {
                carbon-footprint: carbon-footprint,
                energy-usage: energy-usage,
                waste-generated: waste-generated,
                report-date: stacks-block-height
            }
        ))
    )
)

;; to Data Maps
(define-map supplier-ratings
    { supplier-id: principal }
    {
        reliability-score: uint,
        quality-score: uint,
        delivery-score: uint,
        last-updated: uint,
        total-ratings: uint
    }
)

;; Public Function
(define-public (update-supplier-rating
    (supplier principal)
    (reliability uint)
    (quality uint)
    (delivery uint))
    (let
        ((existing-rating (default-to 
            {
                reliability-score: u0,
                quality-score: u0,
                delivery-score: u0,
                last-updated: u0,
                total-ratings: u0
            }
            (map-get? supplier-ratings { supplier-id: supplier }))))
        (asserts! (is-supplier tx-sender) err-not-authorized)
        (ok (map-set supplier-ratings
            { supplier-id: supplier }
            {
                reliability-score: (+ (get reliability-score existing-rating) reliability),
                quality-score: (+ (get quality-score existing-rating) quality),
                delivery-score: (+ (get delivery-score existing-rating) delivery),
                last-updated: stacks-block-height,
                total-ratings: (+ (get total-ratings existing-rating) u1)
            }
        ))
    )
)

