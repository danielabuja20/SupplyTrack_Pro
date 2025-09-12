;; Supplier Authorization Expiry & Renewal System
;; This contract manages expiry dates for supplier authorizations requiring periodic renewal

;; Constants for error handling
(define-constant contract-owner tx-sender)
(define-constant err-not-authorized (err u400))
(define-constant err-supplier-not-found (err u401))
(define-constant err-authorization-expired (err u402))
(define-constant err-invalid-expiry-date (err u403))
(define-constant err-supplier-already-authorized (err u404))
(define-constant err-renewal-too-early (err u405))

;; Authorization period - approximately 1 year in blocks (assuming ~10 minute block times)
(define-constant auth-period u52560) ;; ~365 days * 24 hours * 6 blocks/hour

;; Grace period before expiry where renewal is allowed
(define-constant renewal-grace-period u1440) ;; ~10 days before expiry

;; Supplier authorization tracking with expiry dates
(define-map supplier-authorizations
    { supplier: principal }
    {
        authorized-at: uint,
        expires-at: uint,
        renewed-count: uint,
        status: (string-ascii 20),
        authorized-by: principal,
        last-renewed-by: (optional principal)
    }
)

;; Track authorization history for auditing
(define-map authorization-history
    { supplier: principal, timestamp: uint }
    {
        action: (string-ascii 20),
        previous-expiry: uint,
        new-expiry: uint,
        performed-by: principal,
        notes: (string-ascii 200)
    }
)

;; Initialize a supplier with authorization and expiry date
(define-public (authorize-supplier 
    (supplier principal) 
    (custom-expiry (optional uint))
    (notes (string-ascii 200)))
    (let
        ((current-auth (map-get? supplier-authorizations { supplier: supplier }))
         (expiry-date (if (is-some custom-expiry)
                         (unwrap-panic custom-expiry)
                         (+ stacks-block-height auth-period))))
        
        ;; Check if supplier is already authorized and not expired
        (asserts! (or (is-none current-auth)
                     (is-authorization-expired supplier)) 
                 err-supplier-already-authorized)
        
        ;; Only contract owner can authorize new suppliers
        (asserts! (is-eq tx-sender contract-owner) err-not-authorized)
        
        ;; Validate expiry date is in the future
        (asserts! (> expiry-date stacks-block-height) err-invalid-expiry-date)
        
        ;; Set supplier authorization
        (map-set supplier-authorizations
            { supplier: supplier }
            {
                authorized-at: stacks-block-height,
                expires-at: expiry-date,
                renewed-count: u0,
                status: "active",
                authorized-by: tx-sender,
                last-renewed-by: none
            }
        )
        
        ;; Record in history
        (map-set authorization-history
            { supplier: supplier, timestamp: stacks-block-height }
            {
                action: "authorized",
                previous-expiry: u0,
                new-expiry: expiry-date,
                performed-by: tx-sender,
                notes: notes
            }
        )
        
        (ok expiry-date)
    )
)

;; Allow suppliers to renew their authorization before expiry
(define-public (renew-supplier-authorization (notes (string-ascii 200)))
    (let
        ((supplier tx-sender)
         (current-auth (unwrap! (map-get? supplier-authorizations { supplier: supplier }) 
                               err-supplier-not-found))
         (current-expiry (get expires-at current-auth))
         (new-expiry (+ current-expiry auth-period))
         (blocks-until-expiry (if (> current-expiry stacks-block-height)
                                 (- current-expiry stacks-block-height)
                                 u0)))
        
        ;; Check if supplier is authorized but not yet expired
        (asserts! (not (is-authorization-expired supplier)) err-authorization-expired)
        
        ;; Check if renewal is allowed (within grace period)
        (asserts! (<= blocks-until-expiry renewal-grace-period) err-renewal-too-early)
        
        ;; Update authorization with new expiry
        (map-set supplier-authorizations
            { supplier: supplier }
            (merge current-auth {
                expires-at: new-expiry,
                renewed-count: (+ (get renewed-count current-auth) u1),
                last-renewed-by: (some tx-sender)
            })
        )
        
        ;; Record renewal in history
        (map-set authorization-history
            { supplier: supplier, timestamp: stacks-block-height }
            {
                action: "renewed",
                previous-expiry: current-expiry,
                new-expiry: new-expiry,
                performed-by: tx-sender,
                notes: notes
            }
        )
        
        (ok new-expiry)
    )
)

;; Admin function to manually set supplier expiry or revoke authorization
(define-public (set-supplier-expiry 
    (supplier principal) 
    (new-expiry uint)
    (notes (string-ascii 200)))
    (let
        ((current-auth (unwrap! (map-get? supplier-authorizations { supplier: supplier }) 
                               err-supplier-not-found))
         (current-expiry (get expires-at current-auth)))
        
        ;; Only contract owner can modify expiry dates
        (asserts! (is-eq tx-sender contract-owner) err-not-authorized)
        
        ;; Update expiry date (can be past date to revoke immediately)
        (map-set supplier-authorizations
            { supplier: supplier }
            (merge current-auth {
                expires-at: new-expiry
            })
        )
        
        ;; Record action in history
        (map-set authorization-history
            { supplier: supplier, timestamp: stacks-block-height }
            {
                action: (if (> new-expiry stacks-block-height) "extended" "revoked"),
                previous-expiry: current-expiry,
                new-expiry: new-expiry,
                performed-by: tx-sender,
                notes: notes
            }
        )
        
        (ok new-expiry)
    )
)

;; Revoke supplier authorization immediately
(define-public (revoke-supplier-authorization 
    (supplier principal)
    (notes (string-ascii 200)))
    (let
        ((current-auth (unwrap! (map-get? supplier-authorizations { supplier: supplier }) 
                               err-supplier-not-found)))
        
        ;; Only contract owner can revoke authorizations
        (asserts! (is-eq tx-sender contract-owner) err-not-authorized)
        
        ;; Set expiry to current block to immediately revoke
        (map-set supplier-authorizations
            { supplier: supplier }
            (merge current-auth {
                expires-at: stacks-block-height,
                status: "revoked"
            })
        )
        
        ;; Record revocation in history
        (map-set authorization-history
            { supplier: supplier, timestamp: stacks-block-height }
            {
                action: "revoked",
                previous-expiry: (get expires-at current-auth),
                new-expiry: stacks-block-height,
                performed-by: tx-sender,
                notes: notes
            }
        )
        
        (ok true)
    )
)

;; Private helper function to check if authorization has expired
(define-private (is-authorization-expired (supplier principal))
    (let
        ((auth (map-get? supplier-authorizations { supplier: supplier })))
        (if (is-some auth)
            (let 
                ((auth-data (unwrap-panic auth)))
                (or 
                    (<= (get expires-at auth-data) stacks-block-height)
                    (is-eq (get status auth-data) "revoked")
                )
            )
            true ;; No authorization = expired
        )
    )
)

;; Read-only function to check if supplier is currently authorized
(define-read-only (is-supplier-authorized (supplier principal))
    (not (is-authorization-expired supplier))
)

;; Read-only function to get supplier authorization details
(define-read-only (get-supplier-authorization (supplier principal))
    (map-get? supplier-authorizations { supplier: supplier })
)

;; Read-only function to get authorization history entry
(define-read-only (get-authorization-history (supplier principal) (timestamp uint))
    (map-get? authorization-history { supplier: supplier, timestamp: timestamp })
)

;; Read-only function to check days until expiry
(define-read-only (get-days-until-expiry (supplier principal))
    (let
        ((auth (map-get? supplier-authorizations { supplier: supplier })))
        (if (is-some auth)
            (let
                ((auth-data (unwrap-panic auth))
                 (expiry (get expires-at auth-data)))
                (if (> expiry stacks-block-height)
                    (some (/ (- expiry stacks-block-height) u144)) ;; Approximate blocks per day
                    (some u0) ;; Expired
                )
            )
            none ;; No authorization found
        )
    )
)

;; Read-only function to check if renewal is allowed
(define-read-only (can-renew-authorization (supplier principal))
    (let
        ((auth (map-get? supplier-authorizations { supplier: supplier })))
        (if (is-some auth)
            (let
                ((auth-data (unwrap-panic auth))
                 (expiry (get expires-at auth-data))
                 (blocks-until-expiry (if (> expiry stacks-block-height)
                                        (- expiry stacks-block-height)
                                        u0)))
                (and
                    (not (is-authorization-expired supplier))
                    (<= blocks-until-expiry renewal-grace-period)
                )
            )
            false
        )
    )
)

;; Read-only function to get authorization statistics
(define-read-only (get-authorization-stats (supplier principal))
    (let
        ((auth (map-get? supplier-authorizations { supplier: supplier })))
        (if (is-some auth)
            (let
                ((auth-data (unwrap-panic auth)))
                (some {
                    is-active: (is-supplier-authorized supplier),
                    days-until-expiry: (unwrap-panic (get-days-until-expiry supplier)),
                    renewal-count: (get renewed-count auth-data),
                    can-renew: (can-renew-authorization supplier),
                    status: (get status auth-data)
                })
            )
            none
        )
    )
)
