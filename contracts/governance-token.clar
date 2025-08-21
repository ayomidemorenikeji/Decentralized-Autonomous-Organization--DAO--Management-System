;; Governance Token Contract
;; Implements SIP-010 fungible token standard for DAO voting rights

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant TOKEN-NAME "DAO Governance Token")
(define-constant TOKEN-SYMBOL "DAOG")
(define-constant TOKEN-DECIMALS u6)
(define-constant TOKEN-TOTAL-SUPPLY u1000000000000) ;; 1M tokens with 6 decimals

;; Error codes
(define-constant ERR-UNAUTHORIZED (err u401))
(define-constant ERR-INSUFFICIENT-BALANCE (err u402))
(define-constant ERR-INVALID-AMOUNT (err u403))
(define-constant ERR-ALREADY-INITIALIZED (err u404))
(define-constant ERR-NOT-INITIALIZED (err u405))

;; Data variables
(define-data-var token-initialized bool false)
(define-data-var contract-owner principal CONTRACT-OWNER)

;; Data maps
(define-map token-balances principal uint)
(define-map token-allowances {owner: principal, spender: principal} uint)
(define-map voting-power principal uint)

;; SIP-010 trait implementation
(define-trait sip-010-trait
  (
    (transfer (uint principal principal (optional (buff 34))) (response bool uint))
    (get-name () (response (string-ascii 32) uint))
    (get-symbol () (response (string-ascii 32) uint))
    (get-decimals () (response uint uint))
    (get-balance (principal) (response uint uint))
    (get-total-supply () (response uint uint))
    (get-token-uri () (response (optional (string-utf8 256)) uint))
  )
)

;; Initialize the contract
(define-public (initialize)
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-UNAUTHORIZED)
    (asserts! (not (var-get token-initialized)) ERR-ALREADY-INITIALIZED)
    (map-set token-balances (var-get contract-owner) TOKEN-TOTAL-SUPPLY)
    (map-set voting-power (var-get contract-owner) TOKEN-TOTAL-SUPPLY)
    (var-set token-initialized true)
    (ok true)
  )
)

;; SIP-010 Functions
(define-public (transfer (amount uint) (from principal) (to principal) (memo (optional (buff 34))))
  (begin
    (asserts! (var-get token-initialized) ERR-NOT-INITIALIZED)
    (asserts! (or (is-eq tx-sender from) (is-eq contract-caller from)) ERR-UNAUTHORIZED)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (let
      (
        (from-balance (get-balance-of from))
        (to-balance (get-balance-of to))
      )
      (asserts! (>= from-balance amount) ERR-INSUFFICIENT-BALANCE)
      (map-set token-balances from (- from-balance amount))
      (map-set token-balances to (+ to-balance amount))
      (map-set voting-power from (- (get-voting-power-of from) amount))
      (map-set voting-power to (+ (get-voting-power-of to) amount))
      (print {action: "transfer", from: from, to: to, amount: amount, memo: memo})
      (ok true)
    )
  )
)

(define-read-only (get-name)
  (ok TOKEN-NAME)
)

(define-read-only (get-symbol)
  (ok TOKEN-SYMBOL)
)

(define-read-only (get-decimals)
  (ok TOKEN-DECIMALS)
)

(define-read-only (get-balance (who principal))
  (ok (get-balance-of who))
)

(define-read-only (get-total-supply)
  (ok TOKEN-TOTAL-SUPPLY)
)

(define-read-only (get-token-uri)
  (ok none)
)

;; Helper functions
(define-read-only (get-balance-of (who principal))
  (default-to u0 (map-get? token-balances who))
)

(define-read-only (get-voting-power-of (who principal))
  (default-to u0 (map-get? voting-power who))
)

;; Governance functions
(define-public (delegate-voting-power (to principal) (amount uint))
  (begin
    (asserts! (var-get token-initialized) ERR-NOT-INITIALIZED)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (let
      (
        (sender-voting-power (get-voting-power-of tx-sender))
        (to-voting-power (get-voting-power-of to))
      )
      (asserts! (>= sender-voting-power amount) ERR-INSUFFICIENT-BALANCE)
      (map-set voting-power tx-sender (- sender-voting-power amount))
      (map-set voting-power to (+ to-voting-power amount))
      (print {action: "delegate", from: tx-sender, to: to, amount: amount})
      (ok true)
    )
  )
)

(define-public (mint (to principal) (amount uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-UNAUTHORIZED)
    (asserts! (var-get token-initialized) ERR-NOT-INITIALIZED)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (let
      (
        (to-balance (get-balance-of to))
        (to-voting-power (get-voting-power-of to))
      )
      (map-set token-balances to (+ to-balance amount))
      (map-set voting-power to (+ to-voting-power amount))
      (print {action: "mint", to: to, amount: amount})
      (ok true)
    )
  )
)

;; Admin functions
(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-UNAUTHORIZED)
    (var-set contract-owner new-owner)
    (ok true)
  )
)

(define-read-only (get-contract-owner)
  (var-get contract-owner)
)

(define-read-only (is-initialized)
  (var-get token-initialized)
)
