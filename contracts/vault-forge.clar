;; Title: VaultForge Protocol
;; Summary: Revolutionary over-collateralized lending protocol with intelligent liquidation engine
;; Description: VaultForge represents the next evolution in DeFi lending infrastructure. Built on Stacks,
;;              this protocol combines military-grade security with institutional-level risk management.
;;              Features include dynamic interest compounding, automated liquidation cascades, and
;;              sophisticated collateral optimization algorithms that maximize capital efficiency while
;;              maintaining bulletproof solvency guarantees.

;; ECONOMIC PARAMETERS

(define-constant CONTRACT-OWNER tx-sender)

;; Error Constants
(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-INSUFFICIENT-BALANCE (err u402))
(define-constant ERR-INVALID-AMOUNT (err u403))
(define-constant ERR-INSUFFICIENT-COLLATERAL (err u404))
(define-constant ERR-LOAN-NOT-FOUND (err u405))
(define-constant ERR-LOAN-ALREADY-EXISTS (err u406))
(define-constant ERR-MATH-OVERFLOW (err u407))
(define-constant ERR-LOAN-NOT-LIQUIDATABLE (err u408))
(define-constant ERR-LOAN-NOT-REPAYABLE (err u409))
(define-constant ERR-INVALID-LOAN-ID (err u410))

;; Risk Management Parameters
(define-constant COLLATERAL-RATIO u150) ;; 150% minimum collateral ratio
(define-constant LIQUIDATION-THRESHOLD u130) ;; 130% liquidation threshold
(define-constant INTEREST-RATE-YEARLY u50) ;; 5.0% annual interest (scaled by 10)
(define-constant BLOCKS-PER-YEAR u52560) ;; ~10 minute blocks, 365 days
(define-constant INTEREST-RATE-PER-BLOCK (/ (* INTEREST-RATE-YEARLY u100000) (* BLOCKS-PER-YEAR u1000)))
(define-constant PROTOCOL-FEE-PERCENT u10) ;; 1.0% protocol fee from interest (scaled by 10)

;; DATA STRUCTURES

;; User Account Management
(define-map user-deposits
  principal
  uint
)
(define-map total-deposits
  uint
  uint
) ;; [height, amount]
(define-map protocol-fees
  uint
  uint
) ;; [height, amount]

;; Loan Position Tracking
(define-map loans
  { loan-id: uint }
  {
    borrower: principal,
    collateral-amount: uint,
    loan-amount: uint,
    interest-accumulated: uint,
    creation-height: uint,
    last-interest-height: uint,
    status: (string-ascii 20),
  }
)

;; User Loan Registry
(define-map user-loans
  principal
  (list 20 uint)
)

;; Protocol State Variables
(define-data-var loan-nonce uint u0)
(define-data-var total-collateral uint u0)
(define-data-var total-borrowed uint u0)
(define-data-var paused bool false)

;; ADMINISTRATIVE FUNCTIONS

(define-public (set-paused (paused-state bool))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (var-set paused paused-state)
    (ok paused-state)
  )
)

;; HELPER FUNCTIONS

(define-read-only (get-current-stacks-block-height)
  stacks-block-height
)

(define-read-only (get-user-deposit (user principal))
  (default-to u0 (map-get? user-deposits user))
)

(define-read-only (get-loan-details (loan-id uint))
  (map-get? loans { loan-id: loan-id })
)

(define-read-only (get-user-loans (user principal))
  (default-to (list) (map-get? user-loans user))
)

(define-read-only (get-protocol-stats)
  {
    total-collateral: (var-get total-collateral),
    total-borrowed: (var-get total-borrowed),
    protocol-fees: (default-to u0 (map-get? protocol-fees (get-current-stacks-block-height))),
    loan-count: (var-get loan-nonce),
  }
)

;; FINANCIAL CALCULATIONS

(define-read-only (calculate-interest
    (principal-amount uint)
    (blocks-elapsed uint)
  )
  (let (
      (interest-per-block (/ (* principal-amount INTEREST-RATE-PER-BLOCK) u1000000))
      (total-interest (* interest-per-block blocks-elapsed))
    )
    total-interest
  )
)

(define-read-only (calculate-collateral-ratio
    (collateral-amount uint)
    (loan-amount uint)
    (interest-accumulated uint)
  )
  (let ((total-debt (+ loan-amount interest-accumulated)))
    (if (is-eq total-debt u0)
      u0
      (/ (* collateral-amount u1000) total-debt)
    )
  )
)

(define-read-only (is-liquidatable (loan-id uint))
  (if (or (> loan-id (var-get loan-nonce)) (is-none (get-loan-details loan-id)))
    false
    (match (get-loan-details loan-id)
      loan-data (let (
          (updated-interest (+ (get interest-accumulated loan-data)
            (calculate-interest (get loan-amount loan-data)
              (- (get-current-stacks-block-height)
                (get last-interest-height loan-data)
              ))
          ))
          (collateral-ratio (calculate-collateral-ratio (get collateral-amount loan-data)
            (get loan-amount loan-data) updated-interest
          ))
        )
        (< collateral-ratio (* LIQUIDATION-THRESHOLD u10))
      )
      false
    )
  )
)

;; COLLATERAL MANAGEMENT

(define-public (deposit (amount uint))
  (begin
    (asserts! (not (var-get paused)) ERR-NOT-AUTHORIZED)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    ;; Execute STX transfer from user to contract
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    ;; Update user's collateral balance
    (map-set user-deposits tx-sender (+ (get-user-deposit tx-sender) amount))
    ;; Record deposit in protocol ledger
    (map-set total-deposits (get-current-stacks-block-height)
      (+
        (default-to u0
          (map-get? total-deposits (get-current-stacks-block-height))
        )
        amount
      ))
    ;; Update global collateral counter
    (var-set total-collateral (+ (var-get total-collateral) amount))
    (ok amount)
  )
)

(define-public (withdraw (amount uint))
  (begin
    (asserts! (not (var-get paused)) ERR-NOT-AUTHORIZED)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (let ((current-deposit (get-user-deposit tx-sender)))
      ;; Verify sufficient balance
      (asserts! (>= current-deposit amount) ERR-INSUFFICIENT-BALANCE)
      ;; Execute STX transfer from contract to user
      (try! (as-contract (stx-transfer? amount (as-contract tx-sender) tx-sender)))
      ;; Update user's collateral balance
      (map-set user-deposits tx-sender (- current-deposit amount))
      ;; Update global collateral counter
      (var-set total-collateral (- (var-get total-collateral) amount))
      (ok amount)
    )
  )
)

;; LENDING OPERATIONS

(define-public (borrow
    (collateral-amount uint)
    (loan-amount uint)
  )
  (begin
    (asserts! (not (var-get paused)) ERR-NOT-AUTHORIZED)
    (asserts! (> collateral-amount u0) ERR-INVALID-AMOUNT)
    (asserts! (> loan-amount u0) ERR-INVALID-AMOUNT)
    (let (
        (user-deposit (get-user-deposit tx-sender))
        (collateral-value (* collateral-amount u1000))
        (minimum-collateral-required (* loan-amount COLLATERAL-RATIO u10))
        (loan-id (+ (var-get loan-nonce) u1))
        (current-height (get-current-stacks-block-height))
      )
      ;; Verify user has sufficient collateral
      (asserts! (>= user-deposit collateral-amount) ERR-INSUFFICIENT-BALANCE)
      ;; Verify collateral ratio meets protocol requirements
      (asserts! (>= collateral-value minimum-collateral-required)
        ERR-INSUFFICIENT-COLLATERAL
      )
      ;; Lock collateral in user's account
      (map-set user-deposits tx-sender (- user-deposit collateral-amount))
      ;; Create loan position record
      (map-set loans { loan-id: loan-id } {
        borrower: tx-sender,
        collateral-amount: collateral-amount,
        loan-amount: loan-amount,
        interest-accumulated: u0,
        creation-height: current-height,
        last-interest-height: current-height,
        status: "active",
      })
      ;; Add loan to user's portfolio
      (map-set user-loans tx-sender
        (unwrap! (as-max-len? (append (get-user-loans tx-sender) loan-id) u20)
          ERR-NOT-AUTHORIZED
        ))
      ;; Update protocol counters
      (var-set loan-nonce loan-id)
      (var-set total-borrowed (+ (var-get total-borrowed) loan-amount))
      ;; Transfer borrowed amount to user
      (try! (as-contract (stx-transfer? loan-amount (as-contract tx-sender) tx-sender)))
      (ok loan-id)
    )
  )
)

;; INTEREST ACCRUAL ENGINE

(define-private (update-loan-interest (loan-id uint))
  (match (get-loan-details loan-id)
    loan-data (let (
        (current-height (get-current-stacks-block-height))
        (blocks-elapsed (- current-height (get last-interest-height loan-data)))
        (loan-amount (get loan-amount loan-data))
        (new-interest (calculate-interest loan-amount blocks-elapsed))
        (current-interest (get interest-accumulated loan-data))
        (updated-interest (+ current-interest new-interest))
        (protocol-fee (/ (* new-interest PROTOCOL-FEE-PERCENT) u100))
      )
      ;; Accrue protocol fees
      (map-set protocol-fees current-height
        (+ (default-to u0 (map-get? protocol-fees current-height)) protocol-fee)
      )
      ;; Update loan with accrued interest
      (map-set loans { loan-id: loan-id }
        (merge loan-data {
          interest-accumulated: updated-interest,
          last-interest-height: current-height,
        })
      )
      (ok updated-interest)
    )
    ERR-LOAN-NOT-FOUND
  )
)

;; LOAN REPAYMENT SYSTEM

(define-public (repay-loan
    (loan-id uint)
    (repay-amount uint)
  )
  (begin
    (asserts! (not (var-get paused)) ERR-NOT-AUTHORIZED)
    (asserts! (> repay-amount u0) ERR-INVALID-AMOUNT)
    ;; Validate loan existence
    (asserts! (<= loan-id (var-get loan-nonce)) ERR-INVALID-LOAN-ID)
    (asserts! (is-some (get-loan-details loan-id)) ERR-LOAN-NOT-FOUND)
    ;; Sync interest calculations
    (try! (update-loan-interest loan-id))
    (match (get-loan-details loan-id)
      loan-data (let (
          (borrower (get borrower loan-data))
          (loan-amount (get loan-amount loan-data))
          (interest (get interest-accumulated loan-data))
          (collateral (get collateral-amount loan-data))
          (total-owed (+ loan-amount interest))
          (is-full-repayment (>= repay-amount total-owed))
          (actual-repayment (if is-full-repayment
            total-owed
            repay-amount
          ))
          (remaining-loan (if is-full-repayment
            u0
            (- loan-amount
              (if (>= actual-repayment interest)
                (- actual-repayment interest)
                u0
              ))
          ))
          (remaining-interest (if is-full-repayment
            u0
            (if (>= actual-repayment interest)
              u0
              (- interest actual-repayment)
            )
          ))
        )
        ;; Verify borrower authorization
        (asserts! (is-eq tx-sender borrower) ERR-NOT-AUTHORIZED)
        ;; Process repayment transfer
        (try! (stx-transfer? actual-repayment tx-sender (as-contract tx-sender)))
        (if is-full-repayment
          (begin
            ;; Complete loan closure
            (map-set loans { loan-id: loan-id }
              (merge loan-data {
                loan-amount: u0,
                interest-accumulated: u0,
                status: "repaid",
              })
            )
            ;; Release collateral to borrower
            (map-set user-deposits borrower
              (+ (get-user-deposit borrower) collateral)
            )
            ;; Update protocol metrics
            (var-set total-borrowed (- (var-get total-borrowed) loan-amount))
          )
          (begin
            ;; Partial repayment processing
            (map-set loans { loan-id: loan-id }
              (merge loan-data {
                loan-amount: remaining-loan,
                interest-accumulated: remaining-interest,
              })
            )
            ;; Update protocol metrics
            (var-set total-borrowed
              (- (var-get total-borrowed) (- loan-amount remaining-loan))
            )
          )
        )
        (ok actual-repayment)
      )
      ERR-LOAN-NOT-FOUND
    )
  )
)

;; LIQUIDATION ENGINE

(define-public (liquidate (loan-id uint))
  (begin
    (asserts! (not (var-get paused)) ERR-NOT-AUTHORIZED)
    ;; Validate loan existence
    (asserts! (<= loan-id (var-get loan-nonce)) ERR-INVALID-LOAN-ID)
    (asserts! (is-some (get-loan-details loan-id)) ERR-LOAN-NOT-FOUND)
    ;; Sync interest calculations
    (try! (update-loan-interest loan-id))
    ;; Verify liquidation eligibility
    (asserts! (is-liquidatable loan-id) ERR-LOAN-NOT-LIQUIDATABLE)
    (match (get-loan-details loan-id)
      loan-data (let (
          (borrower (get borrower loan-data))
          (loan-amount (get loan-amount loan-data))
          (interest (get interest-accumulated loan-data))
          (collateral (get collateral-amount loan-data))
          (total-debt (+ loan-amount interest))
          (liquidation-bonus (/ (* collateral u5) u100))
          (collateral-for-liquidator (- collateral liquidation-bonus))
          (protocol-fee-from-liquidation (/ (* liquidation-bonus u50) u100))
          (liquidator-bonus (- liquidation-bonus protocol-fee-from-liquidation))
          (current-height (get-current-stacks-block-height))
        )
        ;; Liquidator debt settlement
        (try! (stx-transfer? total-debt tx-sender (as-contract tx-sender)))
        ;; Transfer collateral to liquidator
        (map-set user-deposits tx-sender
          (+ (get-user-deposit tx-sender) collateral-for-liquidator)
        )
        ;; Liquidator bonus allocation
        (map-set user-deposits tx-sender
          (+ (get-user-deposit tx-sender) liquidator-bonus)
        )
        ;; Protocol fee collection
        (map-set protocol-fees current-height
          (+ (default-to u0 (map-get? protocol-fees current-height))
            protocol-fee-from-liquidation
          ))
        ;; Mark loan as liquidated
        (map-set loans { loan-id: loan-id }
          (merge loan-data {
            loan-amount: u0,
            interest-accumulated: u0,
            collateral-amount: u0,
            status: "liquidated",
          })
        )
        ;; Update protocol metrics
        (var-set total-borrowed (- (var-get total-borrowed) loan-amount))
        (var-set total-collateral (- (var-get total-collateral) collateral))
        (ok true)
      )
      ERR-LOAN-NOT-FOUND
    )
  )
)

;; PROTOCOL TREASURY MANAGEMENT

(define-public (withdraw-protocol-fees (amount uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (let (
        (current-height (get-current-stacks-block-height))
        (available-fees (default-to u0 (map-get? protocol-fees current-height)))
      )
      (asserts! (>= available-fees amount) ERR-INSUFFICIENT-BALANCE)
      ;; Transfer fees to protocol owner
      (try! (as-contract (stx-transfer? amount (as-contract tx-sender) CONTRACT-OWNER)))
      ;; Update protocol fee ledger
      (map-set protocol-fees current-height (- available-fees amount))
      (ok amount)
    )
  )
)

;; ANALYTICS & REPORTING

(define-read-only (get-user-loan-ids (user principal))
  (get-user-loans user)
)

(define-read-only (get-user-active-loans (user principal))
  (let (
      (loan-ids (get-user-loans user))
      (active-loans (filter is-loan-active loan-ids))
    )
    active-loans
  )
)

(define-private (is-loan-active (loan-id uint))
  (match (get-loan-details loan-id)
    loan-data (is-eq (get status loan-data) "active")
    false
  )
)

(define-read-only (get-loan-health (loan-id uint))
  (if (or (> loan-id (var-get loan-nonce)) (is-none (get-loan-details loan-id)))
    (err ERR-LOAN-NOT-FOUND)
    (match (get-loan-details loan-id)
      loan-data (let (
          (updated-interest (+ (get interest-accumulated loan-data)
            (calculate-interest (get loan-amount loan-data)
              (- (get-current-stacks-block-height)
                (get last-interest-height loan-data)
              ))
          ))
          (collateral-ratio (calculate-collateral-ratio (get collateral-amount loan-data)
            (get loan-amount loan-data) updated-interest
          ))
        )
        (ok {
          collateral-ratio: collateral-ratio,
          liquidation-threshold: (* LIQUIDATION-THRESHOLD u10),
          is-healthy: (>= collateral-ratio (* LIQUIDATION-THRESHOLD u10)),
        })
      )
      (err ERR-LOAN-NOT-FOUND)
    )
  )
)

(define-read-only (get-market-info)
  {
    collateral-ratio-required: COLLATERAL-RATIO,
    liquidation-threshold: LIQUIDATION-THRESHOLD,
    yearly-interest-rate: INTEREST-RATE-YEARLY,
    protocol-fee: PROTOCOL-FEE-PERCENT,
  }
)

;; PROTOCOL INITIALIZATION

(begin
  ;; Initialize protocol state variables
  (var-set loan-nonce u0)
  (var-set total-collateral u0)
  (var-set total-borrowed u0)
  (var-set paused false)
  ;; Initialize protocol fee tracking
  (map-set protocol-fees (get-current-stacks-block-height) u0)
)
