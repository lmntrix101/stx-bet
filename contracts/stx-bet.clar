;; STX Betting Smart Contract for Stacks Blockchain

(define-data-var bet-counter uint u0)

(define-map bets
  uint
  {
    creator: principal,
    description: (string-utf8 100),
    deadline: uint,
    yes-stake: uint,
    no-stake: uint,
    resolved: bool,
    result: (optional bool)
  }
)

(define-map stakes
  { bet-id: uint, user: principal }
  {
    outcome: bool,
    amount: uint,
    claimed: bool
  }
)

;; Error constants
(define-constant ERR_NOT_FOUND (err u100))
(define-constant ERR_ALREADY_RESOLVED (err u101))
(define-constant ERR_NOT_ORACLE (err u102))
(define-constant ERR_TOO_EARLY (err u103))
(define-constant ERR_ALREADY_STAKED (err u104))
(define-constant ERR_ALREADY_CLAIMED (err u105))
(define-constant ERR_WRONG_OUTCOME (err u106))
(define-constant ERR_INVALID_AMOUNT (err u107))
(define-constant ERR_TRANSFER_FAILED (err u108))
(define-constant ERR_DEADLINE_PASSED (err u109))

;; Oracle address - replace with actual oracle principal
(define-constant oracle 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7)

;; Create a new bet
(define-public (create-bet (description (string-utf8 100)) (deadline uint))
  (let ((bet-id (+ (var-get bet-counter) u1)))
    (begin
      ;; Check if deadline is in the future
      (asserts! (> deadline stacks-block-height) (err u110))
      (var-set bet-counter bet-id)
      (map-set bets bet-id {
        creator: tx-sender,
        description: description,
        deadline: deadline,
        yes-stake: u0,
        no-stake: u0,
        resolved: false,
        result: none
      })
      (ok bet-id)
    )
  )
)

;; Place a bet with specified amount
(define-public (place-bet (bet-id uint) (outcome bool) (amount uint))
  (let (
    (maybe-bet (map-get? bets bet-id))
    (key { bet-id: bet-id, user: tx-sender })
  )
    (match maybe-bet 
      bet
        (begin
          ;; Check if bet exists and deadline hasn't passed
          (asserts! (< stacks-block-height (get deadline bet)) ERR_DEADLINE_PASSED)
          ;; Check if user hasn't already staked
          (asserts! (is-none (map-get? stakes key)) ERR_ALREADY_STAKED)
          ;; Check if amount is valid
          (asserts! (> amount u0) ERR_INVALID_AMOUNT)
          ;; Transfer STX from user to contract
          (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
          ;; Record the stake
          (map-set stakes key {
            outcome: outcome,
            amount: amount,
            claimed: false
          })
          ;; Update bet totals
          (map-set bets bet-id (merge bet {
            yes-stake: (if outcome (+ (get yes-stake bet) amount) (get yes-stake bet)),
            no-stake: (if (not outcome) (+ (get no-stake bet) amount) (get no-stake bet))
          }))
          (ok true)
        )
      ERR_NOT_FOUND
    )
  )
)

;; Oracle resolves the bet
(define-public (resolve-bet (bet-id uint) (result bool))
  (begin
    ;; Only oracle can resolve
    (asserts! (is-eq tx-sender oracle) ERR_NOT_ORACLE)
    (let ((maybe-bet (map-get? bets bet-id)))
      (match maybe-bet 
        bet
          (begin
            ;; Check if bet is not already resolved
            (asserts! (not (get resolved bet)) ERR_ALREADY_RESOLVED)
            ;; Check if deadline has passed
            (asserts! (>= stacks-block-height (get deadline bet)) ERR_TOO_EARLY)
            ;; Mark bet as resolved
            (map-set bets bet-id (merge bet {
              resolved: true,
              result: (some result)
            }))
            (ok true)
          )
        ERR_NOT_FOUND
      )
    )
  )
)

;; Claim reward for winning bet
(define-public (claim-reward (bet-id uint))
  (let (
    (maybe-bet (map-get? bets bet-id))
    (key { bet-id: bet-id, user: tx-sender })
    (maybe-stake (map-get? stakes key))
  )
    (match maybe-bet 
      bet
        (match maybe-stake 
          stake
            (begin
              ;; Check if bet is resolved
              (asserts! (get resolved bet) ERR_TOO_EARLY)
              ;; Check if not already claimed
              (asserts! (not (get claimed stake)) ERR_ALREADY_CLAIMED)
              ;; Check if user won
              (match (get result bet)
                res
                  (begin
                    (asserts! (is-eq res (get outcome stake)) ERR_WRONG_OUTCOME)
                    (let (
                      (total-pool (+ (get yes-stake bet) (get no-stake bet)))
                      (winner-pool (if res (get yes-stake bet) (get no-stake bet)))
                      (user-stake (get amount stake))
                    )
                      ;; Prevent division by zero
                      (asserts! (> winner-pool u0) (err u111))
                      (let ((reward (/ (* user-stake total-pool) winner-pool)))
                        ;; Mark as claimed
                        (map-set stakes key (merge stake { claimed: true }))
                        ;; Transfer reward
                        (try! (as-contract (stx-transfer? reward tx-sender tx-sender)))
                        (ok reward)
                      )
                    )
                  )
                (err u112) ;; bet result is none
              )
            )
          ERR_NOT_FOUND ;; stake not found
        )
      ERR_NOT_FOUND ;; bet not found
    )
  )
)

;; Read-only functions
(define-read-only (get-bet (bet-id uint))
  (map-get? bets bet-id)
)

(define-read-only (get-stake (bet-id uint) (user principal))
  (map-get? stakes { bet-id: bet-id, user: user })
)

(define-read-only (get-bet-count)
  (var-get bet-counter)
)

(define-read-only (calculate-potential-reward (bet-id uint) (user principal))
  (let (
    (maybe-bet (map-get? bets bet-id))
    (maybe-stake (map-get? stakes { bet-id: bet-id, user: user }))
  )
    (match maybe-bet
      bet
        (match maybe-stake
          stake
            (let (
              (total-pool (+ (get yes-stake bet) (get no-stake bet)))
              (winner-pool (if (get outcome stake) (get yes-stake bet) (get no-stake bet)))
              (user-stake (get amount stake))
            )
              (if (> winner-pool u0)
                (some (/ (* user-stake total-pool) winner-pool))
                none
              )
            )
          none
        )
      none
    )
  )
)

