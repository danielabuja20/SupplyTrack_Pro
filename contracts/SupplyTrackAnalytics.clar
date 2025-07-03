(define-constant contract-owner tx-sender)
(define-constant err-not-authorized (err u300))
(define-constant err-invalid-timeframe (err u301))
(define-constant err-no-data (err u302))

(define-map analytics-summary
    { supplier-id: principal, timeframe: uint }
    {
        total-products: uint,
        total-shipments: uint,
        avg-delivery-time: uint,
        quality-score: uint,
        compliance-rate: uint,
        last-updated: uint
    }
)

(define-map performance-metrics
    { product-id: uint, metric-type: (string-ascii 20) }
    {
        total-count: uint,
        success-rate: uint,
        avg-response-time: uint,
        trend-direction: (string-ascii 10),
        last-calculated: uint
    }
)

(define-map supply-chain-kpis
    { kpi-id: uint }
    {
        kpi-name: (string-ascii 50),
        current-value: uint,
        target-value: uint,
        unit: (string-ascii 10),
        trend: (string-ascii 10),
        last-updated: uint,
        category: (string-ascii 20)
    }
)

(define-map dashboard-alerts
    { alert-id: uint }
    {
        alert-type: (string-ascii 30),
        severity: uint,
        message: (string-ascii 200),
        affected-products: uint,
        created-at: uint,
        status: (string-ascii 20)
    }
)

(define-data-var next-kpi-id uint u1)
(define-data-var next-dashboard-alert-id uint u1)

(define-public (update-supplier-analytics
    (supplier principal)
    (timeframe uint)
    (total-products uint)
    (total-shipments uint)
    (avg-delivery-time uint)
    (quality-score uint)
    (compliance-rate uint))
    (begin
        (asserts! (> timeframe u0) err-invalid-timeframe)
        (asserts! (<= quality-score u100) err-invalid-timeframe)
        (asserts! (<= compliance-rate u100) err-invalid-timeframe)
        (ok (map-set analytics-summary
            { supplier-id: supplier, timeframe: timeframe }
            {
                total-products: total-products,
                total-shipments: total-shipments,
                avg-delivery-time: avg-delivery-time,
                quality-score: quality-score,
                compliance-rate: compliance-rate,
                last-updated: stacks-block-height
            }
        ))
    )
)

(define-public (record-performance-metric
    (product-id uint)
    (metric-type (string-ascii 20))
    (total-count uint)
    (success-rate uint)
    (avg-response-time uint)
    (trend-direction (string-ascii 10)))
    (begin
        (asserts! (<= success-rate u100) err-invalid-timeframe)
        (ok (map-set performance-metrics
            { product-id: product-id, metric-type: metric-type }
            {
                total-count: total-count,
                success-rate: success-rate,
                avg-response-time: avg-response-time,
                trend-direction: trend-direction,
                last-calculated: stacks-block-height
            }
        ))
    )
)

(define-public (create-kpi
    (kpi-name (string-ascii 50))
    (current-value uint)
    (target-value uint)
    (unit (string-ascii 10))
    (trend (string-ascii 10))
    (category (string-ascii 20)))
    (let
        ((kpi-id (var-get next-kpi-id)))
        (var-set next-kpi-id (+ kpi-id u1))
        (ok (map-set supply-chain-kpis
            { kpi-id: kpi-id }
            {
                kpi-name: kpi-name,
                current-value: current-value,
                target-value: target-value,
                unit: unit,
                trend: trend,
                last-updated: stacks-block-height,
                category: category
            }
        ))
    )
)

(define-public (update-kpi
    (kpi-id uint)
    (new-value uint)
    (new-trend (string-ascii 10)))
    (let
        ((existing-kpi (unwrap! (map-get? supply-chain-kpis { kpi-id: kpi-id }) err-no-data)))
        (ok (map-set supply-chain-kpis
            { kpi-id: kpi-id }
            (merge existing-kpi
                {
                    current-value: new-value,
                    trend: new-trend,
                    last-updated: stacks-block-height
                }
            )
        ))
    )
)

(define-public (create-dashboard-alert
    (alert-type (string-ascii 30))
    (severity uint)
    (message (string-ascii 200))
    (affected-products uint))
    (let
        ((alert-id (var-get next-dashboard-alert-id)))
        (asserts! (<= severity u5) err-invalid-timeframe)
        (var-set next-dashboard-alert-id (+ alert-id u1))
        (ok (map-set dashboard-alerts
            { alert-id: alert-id }
            {
                alert-type: alert-type,
                severity: severity,
                message: message,
                affected-products: affected-products,
                created-at: stacks-block-height,
                status: "active"
            }
        ))
    )
)

(define-public (resolve-dashboard-alert (alert-id uint))
    (let
        ((alert (unwrap! (map-get? dashboard-alerts { alert-id: alert-id }) err-no-data)))
        (ok (map-set dashboard-alerts
            { alert-id: alert-id }
            (merge alert { status: "resolved" })
        ))
    )
)

(define-read-only (get-supplier-analytics (supplier principal) (timeframe uint))
    (map-get? analytics-summary { supplier-id: supplier, timeframe: timeframe })
)

(define-read-only (get-performance-metrics (product-id uint) (metric-type (string-ascii 20)))
    (map-get? performance-metrics { product-id: product-id, metric-type: metric-type })
)

(define-read-only (get-kpi-details (kpi-id uint))
    (map-get? supply-chain-kpis { kpi-id: kpi-id })
)

(define-read-only (get-dashboard-alert (alert-id uint))
    (map-get? dashboard-alerts { alert-id: alert-id })
)

(define-read-only (calculate-overall-efficiency (supplier principal))
    (let
        ((analytics-week (default-to
            {
                total-products: u0,
                total-shipments: u0,
                avg-delivery-time: u0,
                quality-score: u0,
                compliance-rate: u0,
                last-updated: u0
            }
            (map-get? analytics-summary { supplier-id: supplier, timeframe: u7 })))
         (quality-weight u40)
         (compliance-weight u35)
         (delivery-weight u25))
        (let
            ((quality-component (/ (* (get quality-score analytics-week) quality-weight) u100))
             (compliance-component (/ (* (get compliance-rate analytics-week) compliance-weight) u100))
             (delivery-component (if (> (get avg-delivery-time analytics-week) u0)
                                    (/ (* (- u100 (min (get avg-delivery-time analytics-week) u100)) delivery-weight) u100)
                                    u0)))
            (+ quality-component (+ compliance-component delivery-component))
        )
    )
)

(define-read-only (get-supply-chain-health-score)
    (let
        ((active-suppliers u10)
         (avg-quality u85)
         (avg-compliance u92)
         (avg-delivery-performance u78))
        (let
            ((quality-factor (/ (* avg-quality u30) u100))
             (compliance-factor (/ (* avg-compliance u40) u100))
             (delivery-factor (/ (* avg-delivery-performance u30) u100)))
            (+ quality-factor (+ compliance-factor delivery-factor))
        )
    )
)

(define-read-only (get-critical-alerts-count)
    (let
        ((alert-1 (map-get? dashboard-alerts { alert-id: u1 }))
         (alert-2 (map-get? dashboard-alerts { alert-id: u2 }))
         (alert-3 (map-get? dashboard-alerts { alert-id: u3 }))
         (alert-4 (map-get? dashboard-alerts { alert-id: u4 }))
         (alert-5 (map-get? dashboard-alerts { alert-id: u5 })))
        (+ 
            (if (and (is-some alert-1) 
                     (>= (get severity (unwrap-panic alert-1)) u4)
                     (is-eq (get status (unwrap-panic alert-1)) "active")) u1 u0)
            (+ 
                (if (and (is-some alert-2) 
                         (>= (get severity (unwrap-panic alert-2)) u4)
                         (is-eq (get status (unwrap-panic alert-2)) "active")) u1 u0)
                (+ 
                    (if (and (is-some alert-3) 
                             (>= (get severity (unwrap-panic alert-3)) u4)
                             (is-eq (get status (unwrap-panic alert-3)) "active")) u1 u0)
                    (+ 
                        (if (and (is-some alert-4) 
                                 (>= (get severity (unwrap-panic alert-4)) u4)
                                 (is-eq (get status (unwrap-panic alert-4)) "active")) u1 u0)
                        (if (and (is-some alert-5) 
                                 (>= (get severity (unwrap-panic alert-5)) u4)
                                 (is-eq (get status (unwrap-panic alert-5)) "active")) u1 u0)
                    )
                )
            )
        )
    )
)

(define-read-only (min (a uint) (b uint))
    (if (< a b) a b)
)

(define-read-only (get-kpi-achievement-rate (kpi-id uint))
    (let
        ((kpi (map-get? supply-chain-kpis { kpi-id: kpi-id })))
        (if (is-some kpi)
            (let
                ((kpi-data (unwrap-panic kpi))
                 (current (get current-value kpi-data))
                 (target (get target-value kpi-data)))
                (if (> target u0)
                    (min (/ (* current u100) target) u100)
                    u0
                )
            )
            u0
        )
    )
)

(define-read-only (get-trending-performance (product-id uint))
    (let
        ((delivery-metrics (map-get? performance-metrics { product-id: product-id, metric-type: "delivery" }))
         (quality-metrics (map-get? performance-metrics { product-id: product-id, metric-type: "quality" })))
        {
            delivery-trend: (if (is-some delivery-metrics) 
                               (get trend-direction (unwrap-panic delivery-metrics)) 
                               "unknown"),
            quality-trend: (if (is-some quality-metrics) 
                              (get trend-direction (unwrap-panic quality-metrics)) 
                              "unknown"),
            last-updated: (if (is-some delivery-metrics) 
                             (get last-calculated (unwrap-panic delivery-metrics)) 
                             u0)
        }
    )
)
