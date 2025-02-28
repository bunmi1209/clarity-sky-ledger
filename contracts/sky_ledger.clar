;; SkyLedger - Aviation Carbon Credit Platform

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-invalid-credit (err u101))
(define-constant err-insufficient-balance (err u102))
(define-constant err-credit-not-verified (err u103))
(define-constant err-invalid-price (err u104))
(define-constant err-system-frozen (err u105))
(define-constant err-invalid-amount (err u106))

;; Define carbon credit token
(define-fungible-token carbon-credit)

;; System control
(define-data-var system-frozen bool false)
(define-data-var verification-expiry uint u50400) ;; ~2 weeks in blocks

;; Data variables 
(define-data-var credit-price uint u100)
(define-map credit-registry 
  { credit-id: uint } 
  { 
    airline: principal,
    flight-id: (string-ascii 10),
    emission-amount: uint,
    timestamp: uint,
    verified: bool,
    verified-at: uint,
    credit-type: (string-ascii 10),
    retired: bool
  }
)

(define-map market-listings
  { listing-id: uint }
  {
    seller: principal,
    credit-amount: uint,
    price-per-credit: uint,
    created-at: uint
  }
)

(define-map price-history
  { block-height: uint }
  { average-price: uint }
)

;; Counters
(define-data-var credit-counter uint u0)
(define-data-var listing-counter uint u0)
(define-data-var total-retired uint u0)

;; System control functions
(define-public (set-system-frozen (frozen bool))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (var-set system-frozen frozen))
  )
)

;; Register new carbon credits
(define-public (register-credits (flight-id (string-ascii 10)) (emission-amount uint) (credit-type (string-ascii 10)))
  (begin
    (asserts! (not (var-get system-frozen)) err-system-frozen)
    (asserts! (> emission-amount u0) err-invalid-amount)
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
          verified: false,
          verified-at: u0,
          credit-type: credit-type,
          retired: false
        }
      )
      (var-set credit-counter new-credit-id)
      (print { type: "credit-registered", credit-id: new-credit-id, amount: emission-amount })
      (ok new-credit-id)
    )
  )
)

;; Batch register credits
(define-public (batch-register-credits (flight-ids (list 10 (string-ascii 10))) (amounts (list 10 uint)) (types (list 10 (string-ascii 10))))
  (begin
    (asserts! (not (var-get system-frozen)) err-system-frozen)
    (fold register-credit-fold (zip flight-ids amounts types) (ok true))
  )
)

(define-private (register-credit-fold (params (tuple (flight-id (string-ascii 10)) (amount uint) (credit-type (string-ascii 10)))) (previous-result (response bool uint)))
  (match previous-result
    success (register-credits (get flight-id params) (get amount params) (get credit-type params))
    error (err error)
  )
)

;; Verify credits - only contract owner
(define-public (verify-credits (credit-id uint))
  (if (is-eq tx-sender contract-owner)
    (begin
      (match (map-get? credit-registry { credit-id: credit-id })
        registry-data (ok (map-set credit-registry
          { credit-id: credit-id }
          (merge registry-data { 
            verified: true,
            verified-at: block-height 
          })
        ))
        err-invalid-credit
      )
    )
    err-owner-only
  )
)

[... Additional updated functions omitted for brevity ...]
