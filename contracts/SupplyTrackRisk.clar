;; SupplyTrack Risk Assessment and Mitigation Management

;; Constants for error handling
(define-constant contract-owner tx-sender)
(define-constant err-not-authorized (err u400))
(define-constant err-invalid-risk-score (err u401))
(define-constant err-risk-not-found (err u402))
(define-constant err-invalid-threshold (err u403))
(define-constant err-mitigation-not-found (err u404))

;; Risk factor definitions for different risk categories
(define-map risk-factors
    { factor-id: uint }
    {
        factor-name: (string-ascii 40),
        category: (string-ascii 20),
        weight: uint,
        max-score: uint,
        description: (string-ascii 100),
        active: bool
    }
)

;; Comprehensive risk assessments for suppliers
(define-map supplier-risk-profiles
    { supplier-id: principal }
    {
        overall-risk-score: uint,
        financial-risk: uint,
        operational-risk: uint,
        geographic-risk: uint,
        compliance-risk: uint,
        reputation-risk: uint,
        last-assessed: uint,
        assessment-validity: uint,
        risk-level: (string-ascii 10)
    }
)

;; Product-specific risk assessments
(define-map product-risk-assessments
    { product-id: uint }
    {
        supply-risk: uint,
        quality-risk: uint,
        demand-risk: uint,
        regulatory-risk: uint,
        environmental-risk: uint,
        total-risk-score: uint,
        criticality-level: (string-ascii 15),
        last-updated: uint
    }
)

;; Risk mitigation strategies and their effectiveness
(define-map mitigation-strategies
    { mitigation-id: uint }
    {
        strategy-name: (string-ascii 50),
        target-risk-type: (string-ascii 20),
        implementation-cost: uint,
        expected-reduction: uint,
        actual-reduction: uint,
        status: (string-ascii 15),
        responsible-party: principal,
        start-date: uint,
        completion-date: uint,
        effectiveness-score: uint
    }
)

;; Risk monitoring thresholds and triggers
(define-map risk-thresholds
    { threshold-id: uint }
    {
        risk-category: (string-ascii 20),
        warning-threshold: uint,
        critical-threshold: uint,
        auto-mitigation: bool,
        notification-recipients: (list 3 principal),
        last-triggered: uint,
        trigger-count: uint
    }
)

;; Historical risk trend analysis
(define-map risk-history
    { entity-id: uint, timestamp: uint }
    {
        entity-type: (string-ascii 10),
        risk-score: uint,
        contributing-factors: (list 5 uint),
        mitigation-active: bool,
        trend-direction: (string-ascii 10)
    }
)

;; Data variables for ID management
(define-data-var next-factor-id uint u1)
(define-data-var next-mitigation-id uint u1)
(define-data-var next-threshold-id uint u1)

;; Create new risk factor definition
(define-public (create-risk-factor
    (factor-name (string-ascii 40))
    (category (string-ascii 20))
    (weight uint)
    (max-score uint)
    (description (string-ascii 100)))
    (let
        ((factor-id (var-get next-factor-id)))
        (asserts! (<= weight u100) err-invalid-risk-score)
        (asserts! (<= max-score u100) err-invalid-risk-score)
        (var-set next-factor-id (+ factor-id u1))
        (ok (map-set risk-factors
            { factor-id: factor-id }
            {
                factor-name: factor-name,
                category: category,
                weight: weight,
                max-score: max-score,
                description: description,
                active: true
            }
        ))
    )
)

;; Assess comprehensive supplier risk profile
(define-public (assess-supplier-risk
    (supplier principal)
    (financial-risk uint)
    (operational-risk uint)
    (geographic-risk uint)
    (compliance-risk uint)
    (reputation-risk uint)
    (assessment-validity uint))
    (let
        ((overall-score (calculate-weighted-risk-score financial-risk operational-risk geographic-risk compliance-risk reputation-risk))
         (risk-level (determine-risk-level overall-score)))
        (asserts! (<= financial-risk u100) err-invalid-risk-score)
        (asserts! (<= operational-risk u100) err-invalid-risk-score)
        (asserts! (<= geographic-risk u100) err-invalid-risk-score)
        (asserts! (<= compliance-risk u100) err-invalid-risk-score)
        (asserts! (<= reputation-risk u100) err-invalid-risk-score)
        (ok (map-set supplier-risk-profiles
            { supplier-id: supplier }
            {
                overall-risk-score: overall-score,
                financial-risk: financial-risk,
                operational-risk: operational-risk,
                geographic-risk: geographic-risk,
                compliance-risk: compliance-risk,
                reputation-risk: reputation-risk,
                last-assessed: stacks-block-height,
                assessment-validity: assessment-validity,
                risk-level: risk-level
            }
        ))
    )
)

;; Evaluate product-specific risks
(define-public (assess-product-risk
    (product-id uint)
    (supply-risk uint)
    (quality-risk uint)
    (demand-risk uint)
    (regulatory-risk uint)
    (environmental-risk uint))
    (let
        ((total-score (calculate-product-risk-total supply-risk quality-risk demand-risk regulatory-risk environmental-risk))
         (criticality (determine-criticality-level total-score)))
        (asserts! (<= supply-risk u100) err-invalid-risk-score)
        (asserts! (<= quality-risk u100) err-invalid-risk-score)
        (asserts! (<= demand-risk u100) err-invalid-risk-score)
        (asserts! (<= regulatory-risk u100) err-invalid-risk-score)
        (asserts! (<= environmental-risk u100) err-invalid-risk-score)
        (ok (map-set product-risk-assessments
            { product-id: product-id }
            {
                supply-risk: supply-risk,
                quality-risk: quality-risk,
                demand-risk: demand-risk,
                regulatory-risk: regulatory-risk,
                environmental-risk: environmental-risk,
                total-risk-score: total-score,
                criticality-level: criticality,
                last-updated: stacks-block-height
            }
        ))
    )
)

;; Implement risk mitigation strategy
(define-public (create-mitigation-strategy
    (strategy-name (string-ascii 50))
    (target-risk-type (string-ascii 20))
    (implementation-cost uint)
    (expected-reduction uint)
    (responsible-party principal))
    (let
        ((mitigation-id (var-get next-mitigation-id)))
        (asserts! (<= expected-reduction u100) err-invalid-risk-score)
        (var-set next-mitigation-id (+ mitigation-id u1))
        (ok (map-set mitigation-strategies
            { mitigation-id: mitigation-id }
            {
                strategy-name: strategy-name,
                target-risk-type: target-risk-type,
                implementation-cost: implementation-cost,
                expected-reduction: expected-reduction,
                actual-reduction: u0,
                status: "planned",
                responsible-party: responsible-party,
                start-date: stacks-block-height,
                completion-date: u0,
                effectiveness-score: u0
            }
        ))
    )
)

;; Update mitigation strategy progress and effectiveness
(define-public (update-mitigation-progress
    (mitigation-id uint)
    (new-status (string-ascii 15))
    (actual-reduction uint)
    (effectiveness-score uint))
    (let
        ((strategy (unwrap! (map-get? mitigation-strategies { mitigation-id: mitigation-id }) err-mitigation-not-found)))
        (asserts! (is-eq tx-sender (get responsible-party strategy)) err-not-authorized)
        (asserts! (<= actual-reduction u100) err-invalid-risk-score)
        (asserts! (<= effectiveness-score u100) err-invalid-risk-score)
        (ok (map-set mitigation-strategies
            { mitigation-id: mitigation-id }
            (merge strategy
                {
                    status: new-status,
                    actual-reduction: actual-reduction,
                    effectiveness-score: effectiveness-score,
                    completion-date: (if (is-eq new-status "completed") stacks-block-height (get completion-date strategy))
                }
            )
        ))
    )
)

;; Configure risk monitoring thresholds
(define-public (set-risk-threshold
    (risk-category (string-ascii 20))
    (warning-threshold uint)
    (critical-threshold uint)
    (auto-mitigation bool)
    (recipients (list 3 principal)))
    (let
        ((threshold-id (var-get next-threshold-id)))
        (asserts! (<= warning-threshold u100) err-invalid-threshold)
        (asserts! (<= critical-threshold u100) err-invalid-threshold)
        (asserts! (< warning-threshold critical-threshold) err-invalid-threshold)
        (var-set next-threshold-id (+ threshold-id u1))
        (ok (map-set risk-thresholds
            { threshold-id: threshold-id }
            {
                risk-category: risk-category,
                warning-threshold: warning-threshold,
                critical-threshold: critical-threshold,
                auto-mitigation: auto-mitigation,
                notification-recipients: recipients,
                last-triggered: u0,
                trigger-count: u0
            }
        ))
    )
)

;; Record risk assessment in historical tracking
(define-public (record-risk-history
    (entity-id uint)
    (entity-type (string-ascii 10))
    (risk-score uint)
    (contributing-factors (list 5 uint))
    (mitigation-active bool)
    (trend-direction (string-ascii 10)))
    (begin
        (asserts! (<= risk-score u100) err-invalid-risk-score)
        (ok (map-set risk-history
            { entity-id: entity-id, timestamp: stacks-block-height }
            {
                entity-type: entity-type,
                risk-score: risk-score,
                contributing-factors: contributing-factors,
                mitigation-active: mitigation-active,
                trend-direction: trend-direction
            }
        ))
    )
)

;; Private function to calculate weighted supplier risk score
(define-private (calculate-weighted-risk-score (financial uint) (operational uint) (geographic uint) (compliance uint) (reputation uint))
    (let
        ((financial-weight u25)
         (operational-weight u30)
         (geographic-weight u15)
         (compliance-weight u20)
         (reputation-weight u10))
        (/ (+ 
            (* financial financial-weight)
            (+ (* operational operational-weight)
               (+ (* geographic geographic-weight)
                  (+ (* compliance compliance-weight)
                     (* reputation reputation-weight)))))
           u100)
    )
)

;; Private function to calculate total product risk
(define-private (calculate-product-risk-total (supply uint) (quality uint) (demand uint) (regulatory uint) (environmental uint))
    (/ (+ supply (+ quality (+ demand (+ regulatory environmental)))) u5)
)

;; Private function to determine risk level category
(define-private (determine-risk-level (score uint))
    (if (<= score u25)
        "low"
        (if (<= score u50)
            "medium"
            (if (<= score u75)
                "high"
                "critical")))
)

;; Private function to determine product criticality level
(define-private (determine-criticality-level (score uint))
    (if (<= score u30)
        "low-critical"
        (if (<= score u60)
            "medium-critical"
            "high-critical"))
)

;; Read-only function to get supplier risk profile
(define-read-only (get-supplier-risk-profile (supplier principal))
    (map-get? supplier-risk-profiles { supplier-id: supplier })
)

;; Read-only function to get product risk assessment
(define-read-only (get-product-risk-assessment (product-id uint))
    (map-get? product-risk-assessments { product-id: product-id })
)

;; Read-only function to get mitigation strategy details
(define-read-only (get-mitigation-strategy (mitigation-id uint))
    (map-get? mitigation-strategies { mitigation-id: mitigation-id })
)

;; Read-only function to get risk factor definition
(define-read-only (get-risk-factor (factor-id uint))
    (map-get? risk-factors { factor-id: factor-id })
)

;; Read-only function to calculate portfolio risk exposure
(define-read-only (calculate-portfolio-risk (supplier-list (list 5 principal)))
    (let
        ((supplier-risks (map get-supplier-risk-score supplier-list)))
        (/ (fold + supplier-risks u0) (len supplier-list))
    )
)

;; Helper function to extract risk score from supplier profile
(define-private (get-supplier-risk-score (supplier principal))
    (default-to u0 
        (get overall-risk-score (map-get? supplier-risk-profiles { supplier-id: supplier }))
    )
)

;; Read-only function to check if risk threshold is breached
(define-read-only (is-risk-threshold-breached (threshold-id uint) (current-score uint))
    (let
        ((threshold (map-get? risk-thresholds { threshold-id: threshold-id })))
        (if (is-some threshold)
            (>= current-score (get critical-threshold (unwrap-panic threshold)))
            false
        )
    )
)

;; Read-only function to get risk trend analysis
(define-read-only (get-risk-trend (entity-id uint) (timeframe uint))
    (map-get? risk-history { entity-id: entity-id, timestamp: timeframe })
)
