(define-constant contract-owner tx-sender)
(define-constant err-not-authorized (err u200))
(define-constant err-alert-not-found (err u201))
(define-constant err-invalid-threshold (err u202))

(define-map alert-configs
    { alert-id: uint }
    {
        alert-type: (string-ascii 30),
        product-id: uint,
        threshold-value: uint,
        recipient: principal,
        active: bool,
        created-by: principal,
        created-at: uint
    }
)

(define-map active-alerts
    { alert-id: uint, trigger-id: uint }
    {
        product-id: uint,
        alert-type: (string-ascii 30),
        message: (string-ascii 200),
        severity: uint,
        triggered-at: uint,
        acknowledged: bool,
        recipient: principal
    }
)

(define-map alert-history
    { product-id: uint, history-id: uint }
    {
        alert-type: (string-ascii 30),
        triggered-count: uint,
        last-triggered: uint,
        total-acknowledgments: uint
    }
)

(define-data-var next-alert-id uint u1)
(define-data-var next-trigger-id uint u1)

(define-public (create-inventory-alert 
    (product-id uint) 
    (low-stock-threshold uint) 
    (recipient principal))
    (let
        ((alert-id (var-get next-alert-id)))
        (asserts! (> low-stock-threshold u0) err-invalid-threshold)
        (var-set next-alert-id (+ alert-id u1))
        (ok (map-set alert-configs
            { alert-id: alert-id }
            {
                alert-type: "low-inventory",
                product-id: product-id,
                threshold-value: low-stock-threshold,
                recipient: recipient,
                active: true,
                created-by: tx-sender,
                created-at: stacks-block-height
            }
        ))
    )
)

(define-public (create-expiry-alert 
    (product-id uint) 
    (days-before-expiry uint) 
    (recipient principal))
    (let
        ((alert-id (var-get next-alert-id)))
        (var-set next-alert-id (+ alert-id u1))
        (ok (map-set alert-configs
            { alert-id: alert-id }
            {
                alert-type: "expiry-warning",
                product-id: product-id,
                threshold-value: days-before-expiry,
                recipient: recipient,
                active: true,
                created-by: tx-sender,
                created-at: stacks-block-height
            }
        ))
    )
)

(define-public (create-maintenance-alert 
    (product-id uint) 
    (days-overdue-threshold uint) 
    (recipient principal))
    (let
        ((alert-id (var-get next-alert-id)))
        (var-set next-alert-id (+ alert-id u1))
        (ok (map-set alert-configs
            { alert-id: alert-id }
            {
                alert-type: "maintenance-overdue",
                product-id: product-id,
                threshold-value: days-overdue-threshold,
                recipient: recipient,
                active: true,
                created-by: tx-sender,
                created-at: stacks-block-height
            }
        ))
    )
)

(define-public (trigger-inventory-alert 
    (alert-id uint) 
    (current-quantity uint))
    (let
        ((config (unwrap! (map-get? alert-configs { alert-id: alert-id }) err-alert-not-found))
         (trigger-id (var-get next-trigger-id)))
        (asserts! (get active config) err-not-authorized)
        (asserts! (< current-quantity (get threshold-value config)) err-invalid-threshold)
        (var-set next-trigger-id (+ trigger-id u1))
        (map-set active-alerts
            { alert-id: alert-id, trigger-id: trigger-id }
            {
                product-id: (get product-id config),
                alert-type: "low-inventory",
                message: "Inventory below threshold",
                severity: u3,
                triggered-at: stacks-block-height,
                acknowledged: false,
                recipient: (get recipient config)
            }
        )
        (update-alert-history (get product-id config) "low-inventory")
    )
)

(define-public (trigger-expiry-alert 
    (alert-id uint) 
    (expiry-block uint))
    (let
        ((config (unwrap! (map-get? alert-configs { alert-id: alert-id }) err-alert-not-found))
         (trigger-id (var-get next-trigger-id))
         (blocks-until-expiry (- expiry-block stacks-block-height)))
        (asserts! (get active config) err-not-authorized)
        (asserts! (<= blocks-until-expiry (get threshold-value config)) err-invalid-threshold)
        (var-set next-trigger-id (+ trigger-id u1))
        (map-set active-alerts
            { alert-id: alert-id, trigger-id: trigger-id }
            {
                product-id: (get product-id config),
                alert-type: "expiry-warning",
                message: "Product expiring soon",
                severity: u4,
                triggered-at: stacks-block-height,
                acknowledged: false,
                recipient: (get recipient config)
            }
        )
        (update-alert-history (get product-id config) "expiry-warning")
    )
)

(define-public (acknowledge-alert 
    (alert-id uint) 
    (trigger-id uint))
    (let
        ((alert (unwrap! (map-get? active-alerts { alert-id: alert-id, trigger-id: trigger-id }) err-alert-not-found)))
        (asserts! (is-eq tx-sender (get recipient alert)) err-not-authorized)
        (ok (map-set active-alerts
            { alert-id: alert-id, trigger-id: trigger-id }
            (merge alert { acknowledged: true })
        ))
    )
)

(define-public (deactivate-alert (alert-id uint))
    (let
        ((config (unwrap! (map-get? alert-configs { alert-id: alert-id }) err-alert-not-found)))
        (asserts! (is-eq tx-sender (get created-by config)) err-not-authorized)
        (ok (map-set alert-configs
            { alert-id: alert-id }
            (merge config { active: false })
        ))
    )
)

(define-private (update-alert-history 
    (product-id uint) 
    (alert-type (string-ascii 30)))
    (let
        ((history-id u1)
         (existing (default-to 
            {
                alert-type: alert-type,
                triggered-count: u0,
                last-triggered: u0,
                total-acknowledgments: u0
            }
            (map-get? alert-history { product-id: product-id, history-id: history-id }))))
        (ok (map-set alert-history
            { product-id: product-id, history-id: history-id }
            {
                alert-type: alert-type,
                triggered-count: (+ (get triggered-count existing) u1),
                last-triggered: stacks-block-height,
                total-acknowledgments: (get total-acknowledgments existing)
            }
        ))
    )
)

(define-read-only (get-alert-config (alert-id uint))
    (map-get? alert-configs { alert-id: alert-id })
)

(define-read-only (get-active-alert (alert-id uint) (trigger-id uint))
    (map-get? active-alerts { alert-id: alert-id, trigger-id: trigger-id })
)

(define-read-only (get-product-alert-history (product-id uint))
    (map-get? alert-history { product-id: product-id, history-id: u1 })
)

(define-read-only (is-alert-active (alert-id uint))
    (default-to false 
        (get active (map-get? alert-configs { alert-id: alert-id }))
    )
)

(define-read-only (get-unacknowledged-alerts-count (recipient principal))
    (let
        ((alert-1 (map-get? active-alerts { alert-id: u1, trigger-id: u1 }))
         (alert-2 (map-get? active-alerts { alert-id: u2, trigger-id: u1 }))
         (alert-3 (map-get? active-alerts { alert-id: u3, trigger-id: u1 })))
        (+ 
            (if (and (is-some alert-1) 
                     (is-eq recipient (get recipient (unwrap-panic alert-1)))
                     (not (get acknowledged (unwrap-panic alert-1)))) u1 u0)
            (+ 
                (if (and (is-some alert-2) 
                         (is-eq recipient (get recipient (unwrap-panic alert-2)))
                         (not (get acknowledged (unwrap-panic alert-2)))) u1 u0)
                (if (and (is-some alert-3) 
                         (is-eq recipient (get recipient (unwrap-panic alert-3)))
                         (not (get acknowledged (unwrap-panic alert-3)))) u1 u0)
            )
        )
    )
)