;; Insurance - Decentralized Protection Platform
;; Buy policies, file claims, and manage risk pools

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u401))
(define-constant ERR_NOT_FOUND (err u404))
(define-constant ERR_POLICY_EXPIRED (err u403))
(define-constant ERR_INVALID_AMOUNT (err u400))
(define-constant ERR_CLAIM_EXISTS (err u405))
(define-constant ERR_INSUFFICIENT_POOL (err u402))

;; Variables
(define-data-var policy-counter uint u0)
(define-data-var claim-counter uint u0)
(define-data-var total-pool-funds uint u0)

;; Policy data
(define-map policies
    { policy-id: uint }
    {
        holder: principal,
        coverage-type: (string-utf8 50),
        coverage-amount: uint,
        premium-paid: uint,
        start-block: uint,
        end-block: uint,
        is-active: bool
    }
)

;; Claims data
(define-map claims
    { claim-id: uint }
    {
        policy-id: uint,
        claimant: principal,
        amount: uint,
        description: (string-utf8 200),
        status: (string-utf8 20), ;; "pending", "approved", "rejected"
        filed-at: uint,
        resolved-at: (optional uint)
    }
)

;; Risk pools
(define-map risk-pools
    { pool-type: (string-utf8 50) }
    {
        total-funds: uint,
        active-policies: uint,
        claims-paid: uint,
        premium-rate: uint ;; per 10000
    }
)

;; Premium payments
(define-map premium-history
    { policy-id: uint, payment-id: uint }
    {
        amount: uint,
        payment-block: uint
    }
)

;; Read-only functions
(define-read-only (get-policy (policy-id uint))
    (map-get? policies { policy-id: policy-id })
)

(define-read-only (get-claim (claim-id uint))
    (map-get? claims { claim-id: claim-id })
)

(define-read-only (get-risk-pool (pool-type (string-utf8 50)))
    (map-get? risk-pools { pool-type: pool-type })
)

(define-read-only (policy-active (policy-id uint))
    (match (get-policy policy-id)
        policy (and
            (get is-active policy)
            (>= stacks-block-height (get start-block policy))
            (<= stacks-block-height (get end-block policy))
        )
        false
    )
)

(define-read-only (calculate-premium (coverage-amount uint) (coverage-type (string-utf8 50)))
    (match (get-risk-pool coverage-type)
        pool (* coverage-amount (get premium-rate pool) (/ u1 u10000))
        u0
    )
)

(define-read-only (get-policy-count)
    (var-get policy-counter)
)

;; Public functions
(define-public (create-risk-pool 
    (pool-type (string-utf8 50))
    (initial-funds uint)
    (premium-rate uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (asserts! (> initial-funds u0) ERR_INVALID_AMOUNT)
        (asserts! (> premium-rate u0) ERR_INVALID_AMOUNT)
        
        (map-set risk-pools
            { pool-type: pool-type }
            {
                total-funds: initial-funds,
                active-policies: u0,
                claims-paid: u0,
                premium-rate: premium-rate
            }
        )
        
        (var-set total-pool-funds (+ (var-get total-pool-funds) initial-funds))
        (ok true)
    )
)

(define-public (buy-policy 
    (coverage-type (string-utf8 50))
    (coverage-amount uint)
    (duration uint))
    (let (
        (policy-id (+ (var-get policy-counter) u1))
        (premium (calculate-premium coverage-amount coverage-type))
        (start-block stacks-block-height)
        (end-block (+ stacks-block-height duration))
        (pool (unwrap! (get-risk-pool coverage-type) ERR_NOT_FOUND))
    )
        (asserts! (> coverage-amount u0) ERR_INVALID_AMOUNT)
        (asserts! (> duration u0) ERR_INVALID_AMOUNT)
        (asserts! (> premium u0) ERR_INVALID_AMOUNT)
        
        ;; Create policy
        (map-set policies
            { policy-id: policy-id }
            {
                holder: tx-sender,
                coverage-type: coverage-type,
                coverage-amount: coverage-amount,
                premium-paid: premium,
                start-block: start-block,
                end-block: end-block,
                is-active: true
            }
        )
        
        ;; Update risk pool
        (map-set risk-pools
            { pool-type: coverage-type }
            (merge pool {
                total-funds: (+ (get total-funds pool) premium),
                active-policies: (+ (get active-policies pool) u1)
            })
        )
        
        (var-set policy-counter policy-id)
        (ok policy-id)
    )
)

(define-public (file-claim 
    (policy-id uint)
    (claim-amount uint)
    (description (string-utf8 200)))
    (let (
        (policy (unwrap! (get-policy policy-id) ERR_NOT_FOUND))
        (claim-id (+ (var-get claim-counter) u1))
    )
        (asserts! (is-eq tx-sender (get holder policy)) ERR_UNAUTHORIZED)
        (asserts! (policy-active policy-id) ERR_POLICY_EXPIRED)
        (asserts! (<= claim-amount (get coverage-amount policy)) ERR_INVALID_AMOUNT)
        (asserts! (> claim-amount u0) ERR_INVALID_AMOUNT)
        
        (map-set claims
            { claim-id: claim-id }
            {
                policy-id: policy-id,
                claimant: tx-sender,
                amount: claim-amount,
                description: description,
                status: u"pending",
                filed-at: stacks-block-height,
                resolved-at: none
            }
        )
        
        (var-set claim-counter claim-id)
        (ok claim-id)
    )
)

(define-public (approve-claim (claim-id uint))
    (let (
        (claim (unwrap! (get-claim claim-id) ERR_NOT_FOUND))
        (policy (unwrap! (get-policy (get policy-id claim)) ERR_NOT_FOUND))
        (pool (unwrap! (get-risk-pool (get coverage-type policy)) ERR_NOT_FOUND))
    )
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (asserts! (is-eq (get status claim) u"pending") ERR_CLAIM_EXISTS)
        (asserts! (>= (get total-funds pool) (get amount claim)) ERR_INSUFFICIENT_POOL)
        
        ;; Update claim status
        (map-set claims
            { claim-id: claim-id }
            (merge claim {
                status: u"approved",
                resolved-at: (some stacks-block-height)
            })
        )
        
        ;; Update pool funds
        (map-set risk-pools
            { pool-type: (get coverage-type policy) }
            (merge pool {
                total-funds: (- (get total-funds pool) (get amount claim)),
                claims-paid: (+ (get claims-paid pool) (get amount claim))
            })
        )
        
        (ok (get amount claim))
    )
)

(define-public (reject-claim (claim-id uint))
    (let (
        (claim (unwrap! (get-claim claim-id) ERR_NOT_FOUND))
    )
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (asserts! (is-eq (get status claim) u"pending") ERR_CLAIM_EXISTS)
        
        (map-set claims
            { claim-id: claim-id }
            (merge claim {
                status: u"rejected",
                resolved-at: (some stacks-block-height)
            })
        )
        
        (ok true)
    )
)

(define-public (renew-policy (policy-id uint) (additional-duration uint))
    (let (
        (policy (unwrap! (get-policy policy-id) ERR_NOT_FOUND))
        (premium (calculate-premium (get coverage-amount policy) (get coverage-type policy)))
        (new-end-block (+ (get end-block policy) additional-duration))
        (pool (unwrap! (get-risk-pool (get coverage-type policy)) ERR_NOT_FOUND))
    )
        (asserts! (is-eq tx-sender (get holder policy)) ERR_UNAUTHORIZED)
        (asserts! (> additional-duration u0) ERR_INVALID_AMOUNT)
        
        ;; Update policy
        (map-set policies
            { policy-id: policy-id }
            (merge policy {
                end-block: new-end-block,
                premium-paid: (+ (get premium-paid policy) premium)
            })
        )
        
        ;; Update pool
        (map-set risk-pools
            { pool-type: (get coverage-type policy) }
            (merge pool {
                total-funds: (+ (get total-funds pool) premium)
            })
        )
        
        (ok premium)
    )
)

(define-public (cancel-policy (policy-id uint))
    (let (
        (policy (unwrap! (get-policy policy-id) ERR_NOT_FOUND))
        (pool (unwrap! (get-risk-pool (get coverage-type policy)) ERR_NOT_FOUND))
    )
        (asserts! (is-eq tx-sender (get holder policy)) ERR_UNAUTHORIZED)
        (asserts! (get is-active policy) ERR_POLICY_EXPIRED)
        
        (map-set policies
            { policy-id: policy-id }
            (merge policy { is-active: false })
        )
        
        (map-set risk-pools
            { pool-type: (get coverage-type policy) }
            (merge pool {
                active-policies: (- (get active-policies pool) u1)
            })
        )
        
        (ok true)
    )
)