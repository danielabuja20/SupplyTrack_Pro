;; Supply Chain Compliance Auditing Contract
;; Tracks regulatory compliance, audit trails, and automated violation detection

(define-constant contract-owner tx-sender)
(define-constant err-not-authorized (err u400))
(define-constant err-invalid-input (err u401))
(define-constant err-compliance-exists (err u402))
(define-constant err-compliance-not-found (err u403))
(define-constant err-invalid-score (err u404))
(define-constant err-audit-not-found (err u405))
(define-constant err-violation-not-found (err u406))

;; Track compliance requirements for different regulatory standards
(define-map compliance-requirements
    { requirement-id: uint }
    {
        regulation-name: (string-ascii 50),
        requirement-type: (string-ascii 30),
        severity-level: uint,
        description: (string-ascii 200),
        compliance-threshold: uint,
        created-by: principal,
        created-at: uint,
        status: (string-ascii 20)
    }
)

;; Store compliance scores and assessments for suppliers/products
(define-map compliance-assessments
    { entity-id: principal, requirement-id: uint }
    {
        compliance-score: uint,
        assessment-date: uint,
        assessor: principal,
        notes: (string-ascii 300),
        evidence-hash: (string-ascii 64),
        next-review-date: uint,
        status: (string-ascii 20)
    }
)

;; Audit trail for all compliance activities
(define-map audit-trail
    { audit-id: uint }
    {
        entity-id: principal,
        action-type: (string-ascii 30),
        requirement-id: uint,
        previous-score: uint,
        new-score: uint,
        auditor: principal,
        timestamp: uint,
        details: (string-ascii 300),
        risk-level: (string-ascii 20)
    }
)

;; Track compliance violations
(define-map compliance-violations
    { violation-id: uint }
    {
        entity-id: principal,
        requirement-id: uint,
        violation-type: (string-ascii 40),
        severity: uint,
        detected-at: uint,
        reported-by: principal,
        description: (string-ascii 400),
        remediation-plan: (string-ascii 500),
        status: (string-ascii 20),
        resolved-at: uint
    }
)

;; Compliance certification tracking
(define-map compliance-certifications
    { cert-id: uint }
    {
        entity-id: principal,
        certification-type: (string-ascii 50),
        issuing-authority: (string-ascii 100),
        issue-date: uint,
        expiry-date: uint,
        certificate-number: (string-ascii 50),
        verification-hash: (string-ascii 64),
        status: (string-ascii 20)
    }
)

;; Data variables for auto-incrementing IDs
(define-data-var next-requirement-id uint u1)
(define-data-var next-audit-id uint u1)
(define-data-var next-violation-id uint u1)
(define-data-var next-cert-id uint u1)

;; Create a new compliance requirement
(define-public (create-compliance-requirement
    (regulation-name (string-ascii 50))
    (requirement-type (string-ascii 30))
    (severity-level uint)
    (description (string-ascii 200))
    (compliance-threshold uint))
    (let
        ((requirement-id (var-get next-requirement-id)))
        (asserts! (>= severity-level u1) err-invalid-input)
        (asserts! (<= severity-level u5) err-invalid-input)
        (asserts! (<= compliance-threshold u100) err-invalid-input)
        (var-set next-requirement-id (+ requirement-id u1))
        (ok (map-set compliance-requirements
            { requirement-id: requirement-id }
            {
                regulation-name: regulation-name,
                requirement-type: requirement-type,
                severity-level: severity-level,
                description: description,
                compliance-threshold: compliance-threshold,
                created-by: tx-sender,
                created-at: stacks-block-height,
                status: "active"
            }
        ))
    )
)

;; Record compliance assessment for an entity
(define-public (record-compliance-assessment
    (entity-id principal)
    (requirement-id uint)
    (compliance-score uint)
    (notes (string-ascii 300))
    (evidence-hash (string-ascii 64))
    (next-review-days uint))
    (let
        ((audit-id (var-get next-audit-id))
         (existing-assessment (map-get? compliance-assessments { entity-id: entity-id, requirement-id: requirement-id }))
         (previous-score (if (is-some existing-assessment) 
                           (get compliance-score (unwrap-panic existing-assessment)) 
                           u0)))
        (asserts! (<= compliance-score u100) err-invalid-score)
        (asserts! (is-some (map-get? compliance-requirements { requirement-id: requirement-id })) err-compliance-not-found)
        
        ;; Record audit trail
        (var-set next-audit-id (+ audit-id u1))
        (map-set audit-trail
            { audit-id: audit-id }
            {
                entity-id: entity-id,
                action-type: "assessment",
                requirement-id: requirement-id,
                previous-score: previous-score,
                new-score: compliance-score,
                auditor: tx-sender,
                timestamp: stacks-block-height,
                details: notes,
                risk-level: (if (< compliance-score u60) "high" 
                           (if (< compliance-score u80) "medium" "low"))
            }
        )
        
        ;; Record assessment
        (ok (map-set compliance-assessments
            { entity-id: entity-id, requirement-id: requirement-id }
            {
                compliance-score: compliance-score,
                assessment-date: stacks-block-height,
                assessor: tx-sender,
                notes: notes,
                evidence-hash: evidence-hash,
                next-review-date: (+ stacks-block-height next-review-days),
                status: (if (>= compliance-score u80) "compliant" "non-compliant")
            }
        ))
    )
)

;; Report a compliance violation
(define-public (report-compliance-violation
    (entity-id principal)
    (requirement-id uint)
    (violation-type (string-ascii 40))
    (severity uint)
    (description (string-ascii 400))
    (remediation-plan (string-ascii 500)))
    (let
        ((violation-id (var-get next-violation-id)))
        (asserts! (>= severity u1) err-invalid-input)
        (asserts! (<= severity u5) err-invalid-input)
        (asserts! (is-some (map-get? compliance-requirements { requirement-id: requirement-id })) err-compliance-not-found)
        
        (var-set next-violation-id (+ violation-id u1))
        (ok (map-set compliance-violations
            { violation-id: violation-id }
            {
                entity-id: entity-id,
                requirement-id: requirement-id,
                violation-type: violation-type,
                severity: severity,
                detected-at: stacks-block-height,
                reported-by: tx-sender,
                description: description,
                remediation-plan: remediation-plan,
                status: "open",
                resolved-at: u0
            }
        ))
    )
)

;; Resolve a compliance violation
(define-public (resolve-compliance-violation (violation-id uint))
    (let
        ((violation (unwrap! (map-get? compliance-violations { violation-id: violation-id }) err-violation-not-found)))
        (ok (map-set compliance-violations
            { violation-id: violation-id }
            (merge violation {
                status: "resolved",
                resolved-at: stacks-block-height
            })
        ))
    )
)

;; Issue compliance certification
(define-public (issue-compliance-certification
    (entity-id principal)
    (certification-type (string-ascii 50))
    (issuing-authority (string-ascii 100))
    (validity-days uint)
    (certificate-number (string-ascii 50))
    (verification-hash (string-ascii 64)))
    (let
        ((cert-id (var-get next-cert-id)))
        (var-set next-cert-id (+ cert-id u1))
        (ok (map-set compliance-certifications
            { cert-id: cert-id }
            {
                entity-id: entity-id,
                certification-type: certification-type,
                issuing-authority: issuing-authority,
                issue-date: stacks-block-height,
                expiry-date: (+ stacks-block-height validity-days),
                certificate-number: certificate-number,
                verification-hash: verification-hash,
                status: "active"
            }
        ))
    )
)

;; Read-only functions

;; Get compliance requirement details
(define-read-only (get-compliance-requirement (requirement-id uint))
    (map-get? compliance-requirements { requirement-id: requirement-id })
)

;; Get compliance assessment for entity and requirement
(define-read-only (get-compliance-assessment (entity-id principal) (requirement-id uint))
    (map-get? compliance-assessments { entity-id: entity-id, requirement-id: requirement-id })
)

;; Get audit trail entry
(define-read-only (get-audit-entry (audit-id uint))
    (map-get? audit-trail { audit-id: audit-id })
)

;; Get violation details
(define-read-only (get-violation-details (violation-id uint))
    (map-get? compliance-violations { violation-id: violation-id })
)

;; Get certification details
(define-read-only (get-certification-details (cert-id uint))
    (map-get? compliance-certifications { cert-id: cert-id })
)

;; Calculate overall compliance score for an entity
(define-read-only (calculate-compliance-score (entity-id principal))
    (let
        ((assessment-1 (map-get? compliance-assessments { entity-id: entity-id, requirement-id: u1 }))
         (assessment-2 (map-get? compliance-assessments { entity-id: entity-id, requirement-id: u2 }))
         (assessment-3 (map-get? compliance-assessments { entity-id: entity-id, requirement-id: u3 }))
         (score-1 (if (is-some assessment-1) (get compliance-score (unwrap-panic assessment-1)) u0))
         (score-2 (if (is-some assessment-2) (get compliance-score (unwrap-panic assessment-2)) u0))
         (score-3 (if (is-some assessment-3) (get compliance-score (unwrap-panic assessment-3)) u0))
         (total-assessments (+ (if (is-some assessment-1) u1 u0)
                              (+ (if (is-some assessment-2) u1 u0)
                                 (if (is-some assessment-3) u1 u0)))))
        (if (> total-assessments u0)
            (/ (+ score-1 (+ score-2 score-3)) total-assessments)
            u0
        )
    )
)

;; Check if entity is compliant with specific requirement
(define-read-only (is-compliant (entity-id principal) (requirement-id uint))
    (let
        ((assessment (map-get? compliance-assessments { entity-id: entity-id, requirement-id: requirement-id }))
         (requirement (map-get? compliance-requirements { requirement-id: requirement-id })))
        (if (and (is-some assessment) (is-some requirement))
            (let
                ((score (get compliance-score (unwrap-panic assessment)))
                 (threshold (get compliance-threshold (unwrap-panic requirement))))
                (>= score threshold)
            )
            false
        )
    )
)

;; Get compliance risk level for entity
(define-read-only (get-compliance-risk-level (entity-id principal))
    (let
        ((overall-score (calculate-compliance-score entity-id)))
        (if (< overall-score u50)
            "critical"
            (if (< overall-score u70)
                "high"
                (if (< overall-score u85)
                    "medium"
                    "low"
                )
            )
        )
    )
)

;; Count active violations for entity
(define-read-only (count-active-violations (entity-id principal))
    (let
        ((violation-1 (map-get? compliance-violations { violation-id: u1 }))
         (violation-2 (map-get? compliance-violations { violation-id: u2 }))
         (violation-3 (map-get? compliance-violations { violation-id: u3 }))
         (violation-4 (map-get? compliance-violations { violation-id: u4 }))
         (violation-5 (map-get? compliance-violations { violation-id: u5 })))
        (+
            (if (and (is-some violation-1)
                     (is-eq (get entity-id (unwrap-panic violation-1)) entity-id)
                     (is-eq (get status (unwrap-panic violation-1)) "open")) u1 u0)
            (+
                (if (and (is-some violation-2)
                         (is-eq (get entity-id (unwrap-panic violation-2)) entity-id)
                         (is-eq (get status (unwrap-panic violation-2)) "open")) u1 u0)
                (+
                    (if (and (is-some violation-3)
                             (is-eq (get entity-id (unwrap-panic violation-3)) entity-id)
                             (is-eq (get status (unwrap-panic violation-3)) "open")) u1 u0)
                    (+
                        (if (and (is-some violation-4)
                                 (is-eq (get entity-id (unwrap-panic violation-4)) entity-id)
                                 (is-eq (get status (unwrap-panic violation-4)) "open")) u1 u0)
                        (if (and (is-some violation-5)
                                 (is-eq (get entity-id (unwrap-panic violation-5)) entity-id)
                                 (is-eq (get status (unwrap-panic violation-5)) "open")) u1 u0)
                    )
                )
            )
        )
    )
)

;; Check if certification is valid
(define-read-only (is-certification-valid (cert-id uint))
    (let
        ((cert (map-get? compliance-certifications { cert-id: cert-id })))
        (if (is-some cert)
            (let
                ((cert-data (unwrap-panic cert)))
                (and
                    (is-eq (get status cert-data) "active")
                    (> (get expiry-date cert-data) stacks-block-height)
                )
            )
            false
        )
    )
)


