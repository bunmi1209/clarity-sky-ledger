;; SkyLedger - Aviation Carbon Credit Platform

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-invalid-credit (err u101))
(define-constant err-insufficient-balance (err u102))
(define-constant err-credit-not-verified (err u103))
(define-constant err-invalid-price (err u104))

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
    verified: bool,
    retired: bool
  }
)

(define-map market-listings
  { listing-id: uint }
  {
    seller: principal,
    credit-amount: uint,
    price-per-credit: uint
  }
)

(define-data-var credit-counter uint u0)
(define-data-var listing-counter uint u0)
(define-data-var total-retired uint u0)

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
                verified: false,
                retired: false
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

;; Create market listing
(define-public (create-listing (credit-amount uint) (price-per-credit uint))
    (let (
        (new-listing-id (+ (var-get listing-counter) u1))
        (sender-balance (ft-get-balance carbon-credit tx-sender))
    )
        (asserts! (>= sender-balance credit-amount) err-insufficient-balance)
        (asserts! (> price-per-credit u0) err-invalid-price)
        
        (map-set market-listings
            { listing-id: new-listing-id }
            {
                seller: tx-sender,
                credit-amount: credit-amount,
                price-per-credit: price-per-credit
            }
        )
        (var-set listing-counter new-listing-id)
        (ok new-listing-id)
    )
)

;; Purchase credits from market
(define-public (purchase-listing (listing-id uint))
    (match (map-get? market-listings { listing-id: listing-id })
        listing-data
            (let (
                (total-cost (* (get credit-amount listing-data) (get price-per-credit listing-data)))
                (seller (get seller listing-data))
            )
                (try! (stx-transfer? total-cost tx-sender seller))
                (try! (transfer-credits (get credit-amount listing-data) tx-sender))
                (map-delete market-listings { listing-id: listing-id })
                (ok true)
            )
        err-invalid-credit
    )
)

;; Retire carbon credits
(define-public (retire-credits (credit-id uint))
    (match (map-get? credit-registry { credit-id: credit-id })
        registry-data
            (begin
                (asserts! (get verified registry-data) err-credit-not-verified)
                (asserts! (not (get retired registry-data)) err-invalid-credit)
                (try! (ft-burn? carbon-credit (get emission-amount registry-data) tx-sender))
                (map-set credit-registry
                    { credit-id: credit-id }
                    (merge registry-data { retired: true })
                )
                (var-set total-retired (+ (var-get total-retired) (get emission-amount registry-data)))
                (ok true)
            )
        err-invalid-credit
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

(define-read-only (get-listing-details (listing-id uint))
    (ok (map-get? market-listings { listing-id: listing-id }))
)

(define-read-only (get-total-retired)
    (ok (var-get total-retired))
)
