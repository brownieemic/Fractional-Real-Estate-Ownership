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
(define-constant ERR-POOL-NOT-FOUND (err u110))
(define-constant ERR-SLIPPAGE-EXCEEDED (err u111))
(define-constant ERR-POOL-EXISTS (err u112))
(define-constant ERR-INSUFFICIENT-LIQUIDITY (err u113))

(define-data-var contract-owner principal tx-sender)
(define-data-var property-counter uint u0)
(define-data-var platform-fee uint u250)
(define-data-var liquidity-fee uint u300)
(define-data-var price-impact-factor uint u1000)

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

(define-map liquidity-pools
  { property-id: uint }
  {
    stx-reserve: uint,
    token-reserve: uint,
    total-supply: uint,
    base-price: uint,
    last-trade-block: uint,
    is-active: bool
  }
)

(define-map pool-shares
  { property-id: uint, provider: principal }
  { shares: uint }
)

(define-map trade-history
  { property-id: uint, block-height: uint }
  {
    trade-type: (string-ascii 10),
    amount: uint,
    price: uint,
    trader: principal
  }
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

(define-public (create-liquidity-pool (property-id uint) (initial-stx uint) (initial-tokens uint))
  (let
    (
      (property (unwrap! (map-get? properties { property-id: property-id }) ERR-PROPERTY-NOT-FOUND))
      (user-tokens (get-user-tokens property-id tx-sender))
      (base-price (/ initial-stx initial-tokens))
      (initial-shares (if (< initial-stx initial-tokens) initial-stx initial-tokens))
    )
    (asserts! (is-none (map-get? liquidity-pools { property-id: property-id })) ERR-POOL-EXISTS)
    (asserts! (> initial-stx u0) ERR-INVALID-AMOUNT)
    (asserts! (> initial-tokens u0) ERR-INVALID-AMOUNT)
    (asserts! (>= user-tokens initial-tokens) ERR-INSUFFICIENT-BALANCE)
    (asserts! (>= (stx-get-balance tx-sender) initial-stx) ERR-INSUFFICIENT-FUNDS)
    
    (try! (stx-transfer? initial-stx tx-sender (as-contract tx-sender)))
    
    (map-set property-ownership
      { property-id: property-id, owner: tx-sender }
      { tokens: (- user-tokens initial-tokens) }
    )
    
    (map-set liquidity-pools
      { property-id: property-id }
      {
        stx-reserve: initial-stx,
        token-reserve: initial-tokens,
        total-supply: initial-shares,
        base-price: base-price,
        last-trade-block: stacks-block-height,
        is-active: true
      }
    )
    
    (map-set pool-shares
      { property-id: property-id, provider: tx-sender }
      { shares: initial-shares }
    )
    
    (ok initial-shares)
  )
)

(define-public (add-liquidity (property-id uint) (stx-amount uint) (max-tokens uint))
  (let
    (
      (pool (unwrap! (map-get? liquidity-pools { property-id: property-id }) ERR-POOL-NOT-FOUND))
      (user-tokens (get-user-tokens property-id tx-sender))
      (current-shares (get-pool-shares property-id tx-sender))
      (tokens-needed (/ (* stx-amount (get token-reserve pool)) (get stx-reserve pool)))
      (shares-to-mint (/ (* stx-amount (get total-supply pool)) (get stx-reserve pool)))
    )
    (asserts! (get is-active pool) ERR-POOL-NOT-FOUND)
    (asserts! (> stx-amount u0) ERR-INVALID-AMOUNT)
    (asserts! (<= tokens-needed max-tokens) ERR-SLIPPAGE-EXCEEDED)
    (asserts! (>= user-tokens tokens-needed) ERR-INSUFFICIENT-BALANCE)
    (asserts! (>= (stx-get-balance tx-sender) stx-amount) ERR-INSUFFICIENT-FUNDS)
    
    (try! (stx-transfer? stx-amount tx-sender (as-contract tx-sender)))
    
    (map-set property-ownership
      { property-id: property-id, owner: tx-sender }
      { tokens: (- user-tokens tokens-needed) }
    )
    
    (map-set liquidity-pools
      { property-id: property-id }
      (merge pool
        {
          stx-reserve: (+ (get stx-reserve pool) stx-amount),
          token-reserve: (+ (get token-reserve pool) tokens-needed),
          total-supply: (+ (get total-supply pool) shares-to-mint)
        }
      )
    )
    
    (map-set pool-shares
      { property-id: property-id, provider: tx-sender }
      { shares: (+ current-shares shares-to-mint) }
    )
    
    (ok shares-to-mint)
  )
)

(define-public (amm-buy-tokens (property-id uint) (token-amount uint) (max-stx-cost uint))
  (let
    (
      (pool (unwrap! (map-get? liquidity-pools { property-id: property-id }) ERR-POOL-NOT-FOUND))
      (stx-cost (get-buy-price property-id token-amount))
      (fee-amount (/ (* stx-cost (var-get liquidity-fee)) u10000))
      (total-cost (+ stx-cost fee-amount))
      (user-tokens (get-user-tokens property-id tx-sender))
      (new-stx-reserve (+ (get stx-reserve pool) stx-cost))
      (new-token-reserve (- (get token-reserve pool) token-amount))
    )
    (asserts! (get is-active pool) ERR-POOL-NOT-FOUND)
    (asserts! (> token-amount u0) ERR-INVALID-AMOUNT)
    (asserts! (<= total-cost max-stx-cost) ERR-SLIPPAGE-EXCEEDED)
    (asserts! (>= (get token-reserve pool) token-amount) ERR-INSUFFICIENT-LIQUIDITY)
    (asserts! (>= (stx-get-balance tx-sender) total-cost) ERR-INSUFFICIENT-FUNDS)
    
    (try! (stx-transfer? stx-cost tx-sender (as-contract tx-sender)))
    (try! (stx-transfer? fee-amount tx-sender (var-get contract-owner)))
    
    (map-set liquidity-pools
      { property-id: property-id }
      (merge pool
        {
          stx-reserve: new-stx-reserve,
          token-reserve: new-token-reserve,
          last-trade-block: stacks-block-height
        }
      )
    )
    
    (map-set property-ownership
      { property-id: property-id, owner: tx-sender }
      { tokens: (+ user-tokens token-amount) }
    )
    
    (map-set user-properties
      { user: tx-sender, property-id: property-id }
      { tokens: (+ user-tokens token-amount) }
    )
    
    (map-set trade-history
      { property-id: property-id, block-height: stacks-block-height }
      {
        trade-type: "buy",
        amount: token-amount,
        price: (/ stx-cost token-amount),
        trader: tx-sender
      }
    )
    
    (ok token-amount)
  )
)

(define-public (amm-sell-tokens (property-id uint) (token-amount uint) (min-stx-receive uint))
  (let
    (
      (pool (unwrap! (map-get? liquidity-pools { property-id: property-id }) ERR-POOL-NOT-FOUND))
      (stx-receive (get-sell-price property-id token-amount))
      (fee-amount (/ (* stx-receive (var-get liquidity-fee)) u10000))
      (net-receive (- stx-receive fee-amount))
      (user-tokens (get-user-tokens property-id tx-sender))
      (new-stx-reserve (- (get stx-reserve pool) stx-receive))
      (new-token-reserve (+ (get token-reserve pool) token-amount))
    )
    (asserts! (get is-active pool) ERR-POOL-NOT-FOUND)
    (asserts! (> token-amount u0) ERR-INVALID-AMOUNT)
    (asserts! (>= net-receive min-stx-receive) ERR-SLIPPAGE-EXCEEDED)
    (asserts! (>= user-tokens token-amount) ERR-INSUFFICIENT-BALANCE)
    (asserts! (>= (get stx-reserve pool) stx-receive) ERR-INSUFFICIENT-LIQUIDITY)
    
    (try! (as-contract (stx-transfer? net-receive tx-sender tx-sender)))
    (try! (as-contract (stx-transfer? fee-amount tx-sender (var-get contract-owner))))
    
    (map-set liquidity-pools
      { property-id: property-id }
      (merge pool
        {
          stx-reserve: new-stx-reserve,
          token-reserve: new-token-reserve,
          last-trade-block: stacks-block-height
        }
      )
    )
    
    (map-set property-ownership
      { property-id: property-id, owner: tx-sender }
      { tokens: (- user-tokens token-amount) }
    )
    
    (map-set user-properties
      { user: tx-sender, property-id: property-id }
      { tokens: (- user-tokens token-amount) }
    )
    
    (map-set trade-history
      { property-id: property-id, block-height: stacks-block-height }
      {
        trade-type: "sell",
        amount: token-amount,
        price: (/ stx-receive token-amount),
        trader: tx-sender
      }
    )
    
    (ok net-receive)
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

(define-read-only (get-liquidity-pool (property-id uint))
  (map-get? liquidity-pools { property-id: property-id })
)

(define-read-only (get-pool-shares (property-id uint) (provider principal))
  (default-to u0 (get shares (map-get? pool-shares { property-id: property-id, provider: provider })))
)

(define-read-only (get-current-price (property-id uint))
  (match (map-get? liquidity-pools { property-id: property-id })
    pool
    (if (> (get token-reserve pool) u0)
      (/ (get stx-reserve pool) (get token-reserve pool))
      (get base-price pool)
    )
    u0
  )
)

(define-read-only (get-buy-price (property-id uint) (token-amount uint))
  (match (map-get? liquidity-pools { property-id: property-id })
    pool
    (let
      (
        (stx-reserve (get stx-reserve pool))
        (token-reserve (get token-reserve pool))
        (k (* stx-reserve token-reserve))
        (new-token-reserve (+ token-reserve token-amount))
        (new-stx-reserve (/ k new-token-reserve))
        (stx-needed (- stx-reserve new-stx-reserve))
        (price-impact (/ (* stx-needed (var-get price-impact-factor)) u10000))
      )
      (+ stx-needed price-impact)
    )
    u0
  )
)

(define-read-only (get-sell-price (property-id uint) (token-amount uint))
  (match (map-get? liquidity-pools { property-id: property-id })
    pool
    (let
      (
        (stx-reserve (get stx-reserve pool))
        (token-reserve (get token-reserve pool))
        (k (* stx-reserve token-reserve))
        (new-token-reserve (- token-reserve token-amount))
        (new-stx-reserve (/ k new-token-reserve))
        (stx-received (- new-stx-reserve stx-reserve))
        (price-impact (/ (* stx-received (var-get price-impact-factor)) u10000))
      )
      (- stx-received price-impact)
    )
    u0
  )
)
