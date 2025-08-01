(define-fungible-token property-token)

(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-PROPERTY-NOT-FOUND (err u101))
(define-constant ERR-INSUFFICIENT-BALANCE (err u102))
(define-constant ERR-PROPERTY-ALREADY-EXISTS (err u103))
(define-constant ERR-INVALID-AMOUNT (err u104))
(define-constant ERR-TRANSFER-FAILED (err u105))
(define-constant ERR-NOT-OWNER (err u106))
(define-constant ERR-PROPERTY-NOT-ACTIVE (err u107))
(define-constant ERR-INVALID-PRICE (err u108))
(define-constant ERR-INSUFFICIENT-FUNDS (err u109))

(define-data-var contract-owner principal tx-sender)
(define-data-var property-counter uint u0)
(define-data-var platform-fee uint u250)

(define-map properties
  { property-id: uint }
  {
    owner: principal,
    total-tokens: uint,
    price-per-token: uint,
    property-value: uint,
    address: (string-ascii 200),
    active: bool,
    created-at: uint
  }
)

(define-map property-ownership
  { property-id: uint, owner: principal }
  { tokens: uint }
)

(define-map property-sales
  { property-id: uint, seller: principal }
  { tokens: uint, price-per-token: uint }
)

(define-map user-properties
  { user: principal, property-id: uint }
  { tokens: uint }
)

(define-map property-dividends
  { property-id: uint }
  { total-dividends: uint, dividends-per-token: uint, last-distribution: uint }
)

(define-map user-dividend-claims
  { user: principal, property-id: uint }
  { last-claim-block: uint }
)

(define-public (create-property (address (string-ascii 200)) (property-value uint) (total-tokens uint))
  (let
    (
      (property-id (+ (var-get property-counter) u1))
      (price-per-token (/ property-value total-tokens))
    )
    (asserts! (> property-value u0) ERR-INVALID-AMOUNT)
    (asserts! (> total-tokens u0) ERR-INVALID-AMOUNT)
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    
    (map-set properties
      { property-id: property-id }
      {
        owner: tx-sender,
        total-tokens: total-tokens,
        price-per-token: price-per-token,
        property-value: property-value,
        address: address,
        active: true,
        created-at: stacks-block-height
      }
    )
    
    (map-set property-ownership
      { property-id: property-id, owner: tx-sender }
      { tokens: total-tokens }
    )
    
    (map-set user-properties
      { user: tx-sender, property-id: property-id }
      { tokens: total-tokens }
    )
    
    (var-set property-counter property-id)
    (ok property-id)
  )
)

(define-public (buy-tokens (property-id uint) (token-amount uint))
  (let
    (
      (property (unwrap! (map-get? properties { property-id: property-id }) ERR-PROPERTY-NOT-FOUND))
      (owner-balance (default-to u0 (get tokens (map-get? property-ownership { property-id: property-id, owner: (get owner property) }))))
      (total-cost (* token-amount (get price-per-token property)))
      (platform-fee-amount (/ (* total-cost (var-get platform-fee)) u10000))
      (owner-payment (- total-cost platform-fee-amount))
    )
    (asserts! (get active property) ERR-PROPERTY-NOT-ACTIVE)
    (asserts! (> token-amount u0) ERR-INVALID-AMOUNT)
    (asserts! (>= owner-balance token-amount) ERR-INSUFFICIENT-BALANCE)
    (asserts! (>= (stx-get-balance tx-sender) total-cost) ERR-INSUFFICIENT-FUNDS)
    
    (try! (stx-transfer? owner-payment tx-sender (get owner property)))
    (try! (stx-transfer? platform-fee-amount tx-sender (var-get contract-owner)))
    
    (map-set property-ownership
      { property-id: property-id, owner: (get owner property) }
      { tokens: (- owner-balance token-amount) }
    )
    
    (let
      (
        (buyer-current-tokens (default-to u0 (get tokens (map-get? property-ownership { property-id: property-id, owner: tx-sender }))))
      )
      (map-set property-ownership
        { property-id: property-id, owner: tx-sender }
        { tokens: (+ buyer-current-tokens token-amount) }
      )
      
      (map-set user-properties
        { user: tx-sender, property-id: property-id }
        { tokens: (+ buyer-current-tokens token-amount) }
      )
    )
    
    (ok true)
  )
)

(define-public (list-tokens-for-sale (property-id uint) (token-amount uint) (price-per-token uint))
  (let
    (
      (property (unwrap! (map-get? properties { property-id: property-id }) ERR-PROPERTY-NOT-FOUND))
      (seller-balance (default-to u0 (get tokens (map-get? property-ownership { property-id: property-id, owner: tx-sender }))))
    )
    (asserts! (get active property) ERR-PROPERTY-NOT-ACTIVE)
    (asserts! (> token-amount u0) ERR-INVALID-AMOUNT)
    (asserts! (> price-per-token u0) ERR-INVALID-PRICE)
    (asserts! (>= seller-balance token-amount) ERR-INSUFFICIENT-BALANCE)
    
    (map-set property-sales
      { property-id: property-id, seller: tx-sender }
      { tokens: token-amount, price-per-token: price-per-token }
    )
    
    (ok true)
  )
)

(define-public (buy-from-listing (property-id uint) (seller principal) (token-amount uint))
  (let
    (
      (property (unwrap! (map-get? properties { property-id: property-id }) ERR-PROPERTY-NOT-FOUND))
      (listing (unwrap! (map-get? property-sales { property-id: property-id, seller: seller }) ERR-PROPERTY-NOT-FOUND))
      (seller-balance (default-to u0 (get tokens (map-get? property-ownership { property-id: property-id, owner: seller }))))
      (total-cost (* token-amount (get price-per-token listing)))
      (platform-fee-amount (/ (* total-cost (var-get platform-fee)) u10000))
      (seller-payment (- total-cost platform-fee-amount))
    )
    (asserts! (get active property) ERR-PROPERTY-NOT-ACTIVE)
    (asserts! (> token-amount u0) ERR-INVALID-AMOUNT)
    (asserts! (<= token-amount (get tokens listing)) ERR-INSUFFICIENT-BALANCE)
    (asserts! (>= seller-balance token-amount) ERR-INSUFFICIENT-BALANCE)
    (asserts! (>= (stx-get-balance tx-sender) total-cost) ERR-INSUFFICIENT-FUNDS)
    
    (try! (stx-transfer? seller-payment tx-sender seller))
    (try! (stx-transfer? platform-fee-amount tx-sender (var-get contract-owner)))
    
    (map-set property-ownership
      { property-id: property-id, owner: seller }
      { tokens: (- seller-balance token-amount) }
    )
    
    (let
      (
        (buyer-current-tokens (default-to u0 (get tokens (map-get? property-ownership { property-id: property-id, owner: tx-sender }))))
        (remaining-listing-tokens (- (get tokens listing) token-amount))
      )
      (map-set property-ownership
        { property-id: property-id, owner: tx-sender }
        { tokens: (+ buyer-current-tokens token-amount) }
      )
      
      (map-set user-properties
        { user: tx-sender, property-id: property-id }
        { tokens: (+ buyer-current-tokens token-amount) }
      )
      
      (if (is-eq remaining-listing-tokens u0)
        (map-delete property-sales { property-id: property-id, seller: seller })
        (map-set property-sales
          { property-id: property-id, seller: seller }
          { tokens: remaining-listing-tokens, price-per-token: (get price-per-token listing) }
        )
      )
    )
    
    (ok true)
  )
)

(define-public (distribute-dividends (property-id uint) (total-dividend-amount uint))
  (let
    (
      (property (unwrap! (map-get? properties { property-id: property-id }) ERR-PROPERTY-NOT-FOUND))
      (dividends-per-token (/ total-dividend-amount (get total-tokens property)))
    )
    (asserts! (is-eq tx-sender (get owner property)) ERR-NOT-OWNER)
    (asserts! (> total-dividend-amount u0) ERR-INVALID-AMOUNT)
    (asserts! (>= (stx-get-balance tx-sender) total-dividend-amount) ERR-INSUFFICIENT-FUNDS)
    
    (map-set property-dividends
      { property-id: property-id }
      { 
        total-dividends: total-dividend-amount,
        dividends-per-token: dividends-per-token,
        last-distribution: stacks-block-height
      }
    )
    
    (ok true)
  )
)

(define-public (claim-dividends (property-id uint))
  (let
    (
      (property (unwrap! (map-get? properties { property-id: property-id }) ERR-PROPERTY-NOT-FOUND))
      (user-tokens (default-to u0 (get tokens (map-get? property-ownership { property-id: property-id, owner: tx-sender }))))
      (dividend-info (unwrap! (map-get? property-dividends { property-id: property-id }) ERR-PROPERTY-NOT-FOUND))
      (last-claim (default-to u0 (get last-claim-block (map-get? user-dividend-claims { user: tx-sender, property-id: property-id }))))
      (dividend-amount (* user-tokens (get dividends-per-token dividend-info)))
    )
    (asserts! (> user-tokens u0) ERR-INSUFFICIENT-BALANCE)
    (asserts! (< last-claim (get last-distribution dividend-info)) ERR-NOT-AUTHORIZED)
    
    (try! (as-contract (stx-transfer? dividend-amount tx-sender tx-sender)))
    
    (map-set user-dividend-claims
      { user: tx-sender, property-id: property-id }
      { last-claim-block: stacks-block-height }
    )
    
    (ok dividend-amount)
  )
)

(define-public (transfer-tokens (property-id uint) (recipient principal) (token-amount uint))
  (let
    (
      (property (unwrap! (map-get? properties { property-id: property-id }) ERR-PROPERTY-NOT-FOUND))
      (sender-balance (default-to u0 (get tokens (map-get? property-ownership { property-id: property-id, owner: tx-sender }))))
      (recipient-balance (default-to u0 (get tokens (map-get? property-ownership { property-id: property-id, owner: recipient }))))
    )
    (asserts! (get active property) ERR-PROPERTY-NOT-ACTIVE)
    (asserts! (> token-amount u0) ERR-INVALID-AMOUNT)
    (asserts! (>= sender-balance token-amount) ERR-INSUFFICIENT-BALANCE)
    
    (map-set property-ownership
      { property-id: property-id, owner: tx-sender }
      { tokens: (- sender-balance token-amount) }
    )
    
    (map-set property-ownership
      { property-id: property-id, owner: recipient }
      { tokens: (+ recipient-balance token-amount) }
    )
    
    (map-set user-properties
      { user: recipient, property-id: property-id }
      { tokens: (+ recipient-balance token-amount) }
    )
    
    (ok true)
  )
)

(define-public (set-platform-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    (asserts! (<= new-fee u1000) ERR-INVALID-AMOUNT)
    (var-set platform-fee new-fee)
    (ok true)
  )
)

(define-public (toggle-property-status (property-id uint))
  (let
    (
      (property (unwrap! (map-get? properties { property-id: property-id }) ERR-PROPERTY-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender (get owner property)) ERR-NOT-OWNER)
    
    (map-set properties
      { property-id: property-id }
      (merge property { active: (not (get active property)) })
    )
    
    (ok true)
  )
)

(define-read-only (get-property (property-id uint))
  (map-get? properties { property-id: property-id })
)

(define-read-only (get-user-tokens (property-id uint) (user principal))
  (default-to u0 (get tokens (map-get? property-ownership { property-id: property-id, owner: user })))
)

(define-read-only (get-property-listing (property-id uint) (seller principal))
  (map-get? property-sales { property-id: property-id, seller: seller })
)

(define-read-only (get-property-dividends (property-id uint))
  (map-get? property-dividends { property-id: property-id })
)

(define-read-only (get-user-dividend-info (property-id uint) (user principal))
  (map-get? user-dividend-claims { user: tx-sender, property-id: property-id })
)

(define-read-only (get-platform-fee)
  (var-get platform-fee)
)

(define-read-only (get-property-count)
  (var-get property-counter)
)

(define-read-only (get-contract-owner)
  (var-get contract-owner)
)
