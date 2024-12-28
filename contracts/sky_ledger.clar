;; SkyLedger - Aviation Carbon Credit Platform

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-invalid-credit (err u101))
(define-constant err-insufficient-balance (err u102))

;; Define carbon credit token
(define-fungible-token carbon-credit)

;; Data variables 
(define-data-var credit-price uint u100) ;; Base price in STX
(define-map credit-registry 
  { credit-id: uint } 
  { 
    airline: principal,
    flight-id: (string-ascii 10),
    emission-amount: uint,
    timestamp: uint,
    verified: bool
  }
)

(define-data-var credit-counter uint u0)

;; Register new carbon credits
(define-public (register-credits (flight-id (string-ascii 10)) (emission-amount uint))
    (let
        (
            (new-credit-id (+ (var-get credit-counter) u1))
        )
        (try! (ft-mint? carbon-credit emission-amount tx-sender))
        (map-set credit-registry
            { credit-id: new-credit-id }
            {
                airline: tx-sender,
                flight-id: flight-id,
                emission-amount: emission-amount,
                timestamp: block-height,
                verified: false
            }
        )
        (var-set credit-counter new-credit-id)
        (ok new-credit-id)
    )
)

;; Verify credits - only contract owner
(define-public (verify-credits (credit-id uint))
    (if (is-eq tx-sender contract-owner)
        (begin
            (match (map-get? credit-registry { credit-id: credit-id })
                registry-data (ok (map-set credit-registry
                    { credit-id: credit-id }
                    (merge registry-data { verified: true })
                ))
                err-invalid-credit
            )
        )
        err-owner-only
    )
)

;; Transfer credits
(define-public (transfer-credits (amount uint) (recipient principal))
    (let (
        (sender-balance (ft-get-balance carbon-credit tx-sender))
    )
        (if (>= sender-balance amount)
            (try! (ft-transfer? carbon-credit amount tx-sender recipient))
            err-insufficient-balance
        )
    )
)

;; Read-only functions
(define-read-only (get-credit-details (credit-id uint))
    (ok (map-get? credit-registry { credit-id: credit-id }))
)

(define-read-only (get-credit-balance (account principal))
    (ok (ft-get-balance carbon-credit account))
)

(define-read-only (get-credit-price)
    (ok (var-get credit-price))
)