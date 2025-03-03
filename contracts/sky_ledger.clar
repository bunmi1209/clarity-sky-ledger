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
(define-constant err-listing-expired (err u107))
(define-constant err-verification-expired (err u108))

;; Define carbon credit token
(define-fungible-token carbon-credit)

;; System control
(define-data-var system-frozen bool false)
(define-data-var verification-expiry uint u50400) ;; ~2 weeks in blocks
(define-data-var listing-expiry uint u25200) ;; ~1 week in blocks

;; Analytics tracking
(define-data-var total-credits-traded uint u0)
(define-data-var last-trade-price uint u0)
(define-data-var market-volume-24h uint u0)

;; Data maps
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
    created-at: uint,
    expires-at: uint
  }
)

(define-map price-history
  { block-height: uint }
  { 
    average-price: uint,
    volume: uint,
    num-trades: uint
  }
)

;; Counters
(define-data-var credit-counter uint u0)
(define-data-var listing-counter uint u0)
(define-data-var total-retired uint u0)

;; Enhanced verification functions
(define-public (batch-verify-credits (credit-ids (list 50 uint)))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (not (var-get system-frozen)) err-system-frozen)
    (ok (map verify-single-credit credit-ids))
  )
)

(define-private (verify-single-credit (credit-id uint))
  (match (map-get? credit-registry { credit-id: credit-id })
    registry-data 
      (map-set credit-registry
        { credit-id: credit-id }
        (merge registry-data { 
          verified: true,
          verified-at: block-height 
        })
      )
    false
  )
)

;; Enhanced market functions
(define-public (create-market-listing (credit-amount uint) (price-per-credit uint))
  (let
    (
      (listing-id (+ (var-get listing-counter) u1))
      (expires-at (+ block-height (var-get listing-expiry)))
    )
    (asserts! (not (var-get system-frozen)) err-system-frozen)
    (asserts! (> credit-amount u0) err-invalid-amount)
    (asserts! (> price-per-credit u0) err-invalid-price)
    (asserts! (>= (ft-get-balance carbon-credit tx-sender) credit-amount) err-insufficient-balance)
    
    (try! (ft-transfer? carbon-credit credit-amount tx-sender (as-contract tx-sender)))
    
    (map-set market-listings
      { listing-id: listing-id }
      {
        seller: tx-sender,
        credit-amount: credit-amount,
        price-per-credit: price-per-credit,
        created-at: block-height,
        expires-at: expires-at
      }
    )
    
    (var-set listing-counter listing-id)
    (print { type: "listing-created", listing-id: listing-id, amount: credit-amount, price: price-per-credit })
    (ok listing-id)
  )
)

;; Analytics functions
(define-read-only (get-market-stats)
  (ok {
    total-traded: (var-get total-credits-traded),
    last-price: (var-get last-trade-price),
    volume-24h: (var-get market-volume-24h),
    total-retired: (var-get total-retired)
  })
)

(define-read-only (is-credit-verification-valid (credit-id uint))
  (match (map-get? credit-registry { credit-id: credit-id })
    registry-data (ok (and 
      (get verified registry-data)
      (< (- block-height (get verified-at registry-data)) (var-get verification-expiry))
    ))
    err-invalid-credit
  )
)

[... Additional functions remain unchanged ...]
