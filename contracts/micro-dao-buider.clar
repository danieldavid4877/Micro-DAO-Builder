(define-constant ERR_NOT_AUTHORIZED (err u401))
(define-constant ERR_DAO_NOT_EXISTS (err u404))
(define-constant ERR_DAO_ALREADY_EXISTS (err u409))
(define-constant ERR_NOT_MEMBER (err u403))
(define-constant ERR_PROPOSAL_NOT_EXISTS (err u405))
(define-constant ERR_ALREADY_VOTED (err u406))
(define-constant ERR_VOTING_ENDED (err u407))
(define-constant ERR_PROPOSAL_NOT_PASSED (err u408))
(define-constant ERR_INSUFFICIENT_BALANCE (err u409))

(define-data-var dao-counter uint u0)
(define-data-var proposal-counter uint u0)

(define-map daos
    uint
    {
        name: (string-ascii 64),
        description: (string-ascii 256),
        creator: principal,
        member-count: uint,
        treasury-balance: uint,
        voting-period: uint,
        min-approval-percentage: uint,
        created-at: uint
    }
)

(define-map dao-members
    {dao-id: uint, member: principal}
    {joined-at: uint, is-admin: bool}
)

(define-map proposals
    uint
    {
        dao-id: uint,
        title: (string-ascii 128),
        description: (string-ascii 512),
        proposer: principal,
        amount: uint,
        recipient: principal,
        yes-votes: uint,
        no-votes: uint,
        created-at: uint,
        executed: bool
    }
)

(define-map votes
    {proposal-id: uint, voter: principal}
    {vote: bool, voted-at: uint}
)

(define-map user-daos
    principal
    {dao-list: (list 100 uint)}
)

(define-map member-activity
    {dao-id: uint, member: principal}
    {
        proposals-created: uint,
        votes-cast: uint,
        last-activity-block: uint,
        reputation-score: uint
    }
)

(define-public (create-dao (name (string-ascii 64)) (description (string-ascii 256)) (voting-period uint) (min-approval-percentage uint))
    (let
        (
            (dao-id (+ (var-get dao-counter) u1))
            (creator tx-sender)
        )
        (asserts! (> (len name) u0) (err u400))
        (asserts! (<= min-approval-percentage u100) (err u400))
        (asserts! (> voting-period u0) (err u400))
        
        (map-set daos dao-id {
            name: name,
            description: description,
            creator: creator,
            member-count: u1,
            treasury-balance: u0,
            voting-period: voting-period,
            min-approval-percentage: min-approval-percentage,
            created-at: stacks-block-height
        })
        
        (map-set dao-members {dao-id: dao-id, member: creator} {
            joined-at: stacks-block-height,
            is-admin: true
        })
        
        (map-set member-activity {dao-id: dao-id, member: creator} {
            proposals-created: u0,
            votes-cast: u0,
            last-activity-block: stacks-block-height,
            reputation-score: u100
        })
        
        (map-set user-daos creator {
            dao-list: (list dao-id)
        })
        
        (var-set dao-counter dao-id)
        (ok dao-id)
    )
)

(define-public (join-dao (dao-id uint))
    (let
        (
            (dao-info (unwrap! (map-get? daos dao-id) ERR_DAO_NOT_EXISTS))
            (member-info (map-get? dao-members {dao-id: dao-id, member: tx-sender}))
            (current-user-daos (default-to {dao-list: (list)} (map-get? user-daos tx-sender)))
        )
        (asserts! (is-none member-info) (err u409))
        
        (map-set dao-members {dao-id: dao-id, member: tx-sender} {
            joined-at: stacks-block-height,
            is-admin: false
        })
        
        (map-set member-activity {dao-id: dao-id, member: tx-sender} {
            proposals-created: u0,
            votes-cast: u0,
            last-activity-block: stacks-block-height,
            reputation-score: u50
        })
        
        (map-set daos dao-id (merge dao-info {
            member-count: (+ (get member-count dao-info) u1)
        }))
        
        (map-set user-daos tx-sender {
            dao-list: (unwrap! (as-max-len? (append (get dao-list current-user-daos) dao-id) u100) (err u500))
        })
        
        (ok true)
    )
)

(define-public (add-member (dao-id uint) (new-member principal))
    (let
        (
            (dao-info (unwrap! (map-get? daos dao-id) ERR_DAO_NOT_EXISTS))
            (admin-info (unwrap! (map-get? dao-members {dao-id: dao-id, member: tx-sender}) ERR_NOT_MEMBER))
            (member-info (map-get? dao-members {dao-id: dao-id, member: new-member}))
            (current-user-daos (default-to {dao-list: (list)} (map-get? user-daos new-member)))
        )
        (asserts! (get is-admin admin-info) ERR_NOT_AUTHORIZED)
        (asserts! (is-none member-info) (err u409))
        
        (map-set dao-members {dao-id: dao-id, member: new-member} {
            joined-at: stacks-block-height,
            is-admin: false
        })
        
        (map-set member-activity {dao-id: dao-id, member: new-member} {
            proposals-created: u0,
            votes-cast: u0,
            last-activity-block: stacks-block-height,
            reputation-score: u50
        })
        
        (map-set daos dao-id (merge dao-info {
            member-count: (+ (get member-count dao-info) u1)
        }))
        
        (map-set user-daos new-member {
            dao-list: (unwrap! (as-max-len? (append (get dao-list current-user-daos) dao-id) u100) (err u500))
        })
        
        (ok true)
    )
)

(define-public (deposit-to-dao (dao-id uint) (amount uint))
    (let
        (
            (dao-info (unwrap! (map-get? daos dao-id) ERR_DAO_NOT_EXISTS))
            (member-info (unwrap! (map-get? dao-members {dao-id: dao-id, member: tx-sender}) ERR_NOT_MEMBER))
        )
        (asserts! (> amount u0) (err u400))
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        
        (map-set daos dao-id (merge dao-info {
            treasury-balance: (+ (get treasury-balance dao-info) amount)
        }))
        
        (ok true)
    )
)

(define-public (create-proposal (dao-id uint) (title (string-ascii 128)) (description (string-ascii 512)) (amount uint) (recipient principal))
    (let
        (
            (proposal-id (+ (var-get proposal-counter) u1))
            (dao-info (unwrap! (map-get? daos dao-id) ERR_DAO_NOT_EXISTS))
            (member-info (unwrap! (map-get? dao-members {dao-id: dao-id, member: tx-sender}) ERR_NOT_MEMBER))
        )
        (asserts! (> (len title) u0) (err u400))
        (asserts! (>= (get treasury-balance dao-info) amount) ERR_INSUFFICIENT_BALANCE)
        
        (map-set proposals proposal-id {
            dao-id: dao-id,
            title: title,
            description: description,
            proposer: tx-sender,
            amount: amount,
            recipient: recipient,
            yes-votes: u0,
            no-votes: u0,
            created-at: stacks-block-height,
            executed: false
        })
        
        (let
            (
                (current-activity (default-to 
                    {proposals-created: u0, votes-cast: u0, last-activity-block: u0, reputation-score: u50} 
                    (map-get? member-activity {dao-id: dao-id, member: tx-sender})
                ))
            )
            (map-set member-activity {dao-id: dao-id, member: tx-sender} (merge current-activity {
                proposals-created: (+ (get proposals-created current-activity) u1),
                last-activity-block: stacks-block-height,
                reputation-score: (+ (get reputation-score current-activity) u10)
            }))
        )
        
        (var-set proposal-counter proposal-id)
        (ok proposal-id)
    )
)

(define-public (vote-proposal (proposal-id uint) (vote-yes bool))
    (let
        (
            (proposal-info (unwrap! (map-get? proposals proposal-id) ERR_PROPOSAL_NOT_EXISTS))
            (dao-info (unwrap! (map-get? daos (get dao-id proposal-info)) ERR_DAO_NOT_EXISTS))
            (member-info (unwrap! (map-get? dao-members {dao-id: (get dao-id proposal-info), member: tx-sender}) ERR_NOT_MEMBER))
            (existing-vote (map-get? votes {proposal-id: proposal-id, voter: tx-sender}))
        )
        (asserts! (is-none existing-vote) ERR_ALREADY_VOTED)
        (asserts! (<= (- stacks-block-height (get created-at proposal-info)) (get voting-period dao-info)) ERR_VOTING_ENDED)
        
        (map-set votes {proposal-id: proposal-id, voter: tx-sender} {
            vote: vote-yes,
            voted-at: stacks-block-height
        })
        
        (if vote-yes
            (map-set proposals proposal-id (merge proposal-info {
                yes-votes: (+ (get yes-votes proposal-info) u1)
            }))
            (map-set proposals proposal-id (merge proposal-info {
                no-votes: (+ (get no-votes proposal-info) u1)
            }))
        )
        
        (let
            (
                (current-activity (default-to 
                    {proposals-created: u0, votes-cast: u0, last-activity-block: u0, reputation-score: u50} 
                    (map-get? member-activity {dao-id: (get dao-id proposal-info), member: tx-sender})
                ))
            )
            (map-set member-activity {dao-id: (get dao-id proposal-info), member: tx-sender} (merge current-activity {
                votes-cast: (+ (get votes-cast current-activity) u1),
                last-activity-block: stacks-block-height,
                reputation-score: (+ (get reputation-score current-activity) u5)
            }))
        )
        
        (ok true)
    )
)

(define-public (execute-proposal (proposal-id uint))
    (let
        (
            (proposal-info (unwrap! (map-get? proposals proposal-id) ERR_PROPOSAL_NOT_EXISTS))
            (dao-info (unwrap! (map-get? daos (get dao-id proposal-info)) ERR_DAO_NOT_EXISTS))
        )
        (asserts! (not (get executed proposal-info)) (err u410))
        (asserts! (> (- stacks-block-height (get created-at proposal-info)) (get voting-period dao-info)) ERR_VOTING_ENDED)
        
        (let
            (
                (total-votes (+ (get yes-votes proposal-info) (get no-votes proposal-info)))
                (approval-percentage (if (> total-votes u0) (/ (* (get yes-votes proposal-info) u100) total-votes) u0))
            )
            (asserts! (>= approval-percentage (get min-approval-percentage dao-info)) ERR_PROPOSAL_NOT_PASSED)
            
            (try! (as-contract (stx-transfer? (get amount proposal-info) tx-sender (get recipient proposal-info))))
            
            (map-set proposals proposal-id (merge proposal-info {
                executed: true
            }))
            
            (map-set daos (get dao-id proposal-info) (merge dao-info {
                treasury-balance: (- (get treasury-balance dao-info) (get amount proposal-info))
            }))
            
            (ok true)
        )
    )
)

(define-read-only (get-dao (dao-id uint))
    (map-get? daos dao-id)
)

(define-read-only (get-proposal (proposal-id uint))
    (map-get? proposals proposal-id)
)

(define-read-only (is-dao-member (dao-id uint) (member principal))
    (is-some (map-get? dao-members {dao-id: dao-id, member: member}))
)

(define-read-only (get-member-info (dao-id uint) (member principal))
    (map-get? dao-members {dao-id: dao-id, member: member})
)

(define-read-only (get-user-daos (user principal))
    (map-get? user-daos user)
)

(define-read-only (get-vote (proposal-id uint) (voter principal))
    (map-get? votes {proposal-id: proposal-id, voter: voter})
)

(define-read-only (get-dao-count)
    (var-get dao-counter)
)

(define-read-only (get-proposal-count)
    (var-get proposal-counter)
)

(define-public (remove-member (dao-id uint) (member-to-remove principal))
    (let
        (
            (dao-info (unwrap! (map-get? daos dao-id) ERR_DAO_NOT_EXISTS))
            (admin-info (unwrap! (map-get? dao-members {dao-id: dao-id, member: tx-sender}) ERR_NOT_MEMBER))
            (member-info (unwrap! (map-get? dao-members {dao-id: dao-id, member: member-to-remove}) ERR_NOT_MEMBER))
        )
        (asserts! (get is-admin admin-info) ERR_NOT_AUTHORIZED)
        (asserts! (not (is-eq member-to-remove (get creator dao-info))) (err u411))
        
        (map-delete dao-members {dao-id: dao-id, member: member-to-remove})
        (map-delete member-activity {dao-id: dao-id, member: member-to-remove})
        
        (map-set daos dao-id (merge dao-info {
            member-count: (- (get member-count dao-info) u1)
        }))
        
        (ok true)
    )
)

(define-public (transfer-admin (dao-id uint) (new-admin principal))
    (let
        (
            (dao-info (unwrap! (map-get? daos dao-id) ERR_DAO_NOT_EXISTS))
            (current-admin-info (unwrap! (map-get? dao-members {dao-id: dao-id, member: tx-sender}) ERR_NOT_MEMBER))
            (new-admin-info (unwrap! (map-get? dao-members {dao-id: dao-id, member: new-admin}) ERR_NOT_MEMBER))
        )
        (asserts! (is-eq tx-sender (get creator dao-info)) ERR_NOT_AUTHORIZED)
        
        (map-set dao-members {dao-id: dao-id, member: tx-sender} (merge current-admin-info {
            is-admin: false
        }))
        
        (map-set dao-members {dao-id: dao-id, member: new-admin} (merge new-admin-info {
            is-admin: true
        }))
        
        (map-set daos dao-id (merge dao-info {
            creator: new-admin
        }))
        
        (ok true)
    )
)

(define-public (update-dao-settings (dao-id uint) (new-voting-period uint) (new-min-approval uint))
    (let
        (
            (dao-info (unwrap! (map-get? daos dao-id) ERR_DAO_NOT_EXISTS))
            (admin-info (unwrap! (map-get? dao-members {dao-id: dao-id, member: tx-sender}) ERR_NOT_MEMBER))
        )
        (asserts! (get is-admin admin-info) ERR_NOT_AUTHORIZED)
        (asserts! (> new-voting-period u0) (err u400))
        (asserts! (<= new-min-approval u100) (err u400))
        
        (map-set daos dao-id (merge dao-info {
            voting-period: new-voting-period,
            min-approval-percentage: new-min-approval
        }))
        
        (ok true)
    )
)

(define-public (withdraw-treasury (dao-id uint) (amount uint) (recipient principal))
    (let
        (
            (dao-info (unwrap! (map-get? daos dao-id) ERR_DAO_NOT_EXISTS))
            (admin-info (unwrap! (map-get? dao-members {dao-id: dao-id, member: tx-sender}) ERR_NOT_MEMBER))
        )
        (asserts! (get is-admin admin-info) ERR_NOT_AUTHORIZED)
        (asserts! (>= (get treasury-balance dao-info) amount) ERR_INSUFFICIENT_BALANCE)
        
        (try! (as-contract (stx-transfer? amount tx-sender recipient)))
        
        (map-set daos dao-id (merge dao-info {
            treasury-balance: (- (get treasury-balance dao-info) amount)
        }))
        
        (ok true)
    )
)

(define-read-only (get-proposal-status (proposal-id uint))
    (let
        (
            (proposal-info (unwrap! (map-get? proposals proposal-id) ERR_PROPOSAL_NOT_EXISTS))
            (dao-info (unwrap! (map-get? daos (get dao-id proposal-info)) ERR_DAO_NOT_EXISTS))
            (total-votes (+ (get yes-votes proposal-info) (get no-votes proposal-info)))
            (approval-percentage (if (> total-votes u0) (/ (* (get yes-votes proposal-info) u100) total-votes) u0))
            (voting-ended (> (- stacks-block-height (get created-at proposal-info)) (get voting-period dao-info)))
        )
        (ok {
            proposal-id: proposal-id,
            total-votes: total-votes,
            approval-percentage: approval-percentage,
            voting-ended: voting-ended,
            executed: (get executed proposal-info),
            passed: (and voting-ended (>= approval-percentage (get min-approval-percentage dao-info)))
        })
    )
)

(define-read-only (get-dao-proposals (dao-id uint))
    (let
        (
            (all-proposal-ids (list
                u1 u2 u3 u4 u5 u6 u7 u8 u9 u10 u11 u12 u13 u14 u15 u16 u17 u18 u19 u20
                u21 u22 u23 u24 u25 u26 u27 u28 u29 u30 u31 u32 u33 u34 u35 u36 u37 u38 u39 u40
                u41 u42 u43 u44 u45 u46 u47 u48 u49 u50 u51 u52 u53 u54 u55 u56 u57 u58 u59 u60
                u61 u62 u63 u64 u65 u66 u67 u68 u69 u70 u71 u72 u73 u74 u75 u76 u77 u78 u79 u80
                u81 u82 u83 u84 u85 u86 u87 u88 u89 u90 u91 u92 u93 u94 u95 u96 u97 u98 u99 u100
            ))
        )
        (ok (get results (fold check-proposal-for-dao all-proposal-ids {dao-id: dao-id, results: (list)})))
    )
)

(define-private (check-proposal-for-dao (proposal-id uint) (accumulator {dao-id: uint, results: (list 100 uint)}))
    (match (map-get? proposals proposal-id)
        proposal-data 
            (if (is-eq (get dao-id proposal-data) (get dao-id accumulator))
                {dao-id: (get dao-id accumulator), results: (unwrap! (as-max-len? (append (get results accumulator) proposal-id) u100) accumulator)}
                accumulator
            )
        accumulator
    )
)

(define-read-only (get-dao-members-list (dao-id uint))
    (ok (list tx-sender))
)

(define-private (check-dao-membership (dao-id uint) (member principal))
    (is-some (map-get? dao-members {dao-id: dao-id, member: member}))
)

(define-read-only (get-member-activity (dao-id uint) (member principal))
    (map-get? member-activity {dao-id: dao-id, member: member})
)

(define-read-only (get-member-reputation (dao-id uint) (member principal))
    (match (map-get? member-activity {dao-id: dao-id, member: member})
        activity-data (ok (get reputation-score activity-data))
        ERR_NOT_MEMBER
    )
)

(define-read-only (get-dao-top-members (dao-id uint))
    (ok (list {member: tx-sender, reputation: u0}))
)

(define-private (check-member-reputation-for-dao (member principal) (accumulator {dao-id: uint, results: (list 10 {member: principal, reputation: uint})}))
    (match (map-get? member-activity {dao-id: (get dao-id accumulator), member: member})
        activity-data 
            {dao-id: (get dao-id accumulator), results: (unwrap! (as-max-len? (append (get results accumulator) {member: member, reputation: (get reputation-score activity-data)}) u10) accumulator)}
        accumulator
    )
)

(define-public (create-simple-proposal (dao-id uint) (title (string-ascii 128)) (description (string-ascii 512)))
    (create-proposal dao-id title description u0 tx-sender)
)

(define-read-only (get-active-proposals (dao-id uint))
    (let
        (
            (dao-info (unwrap! (map-get? daos dao-id) ERR_DAO_NOT_EXISTS))
            (all-proposal-ids (list
                u1 u2 u3 u4 u5 u6 u7 u8 u9 u10 u11 u12 u13 u14 u15 u16 u17 u18 u19 u20
                u21 u22 u23 u24 u25 u26 u27 u28 u29 u30 u31 u32 u33 u34 u35 u36 u37 u38 u39 u40
                u41 u42 u43 u44 u45 u46 u47 u48 u49 u50 u51 u52 u53 u54 u55 u56 u57 u58 u59 u60
                u61 u62 u63 u64 u65 u66 u67 u68 u69 u70 u71 u72 u73 u74 u75 u76 u77 u78 u79 u80
                u81 u82 u83 u84 u85 u86 u87 u88 u89 u90 u91 u92 u93 u94 u95 u96 u97 u98 u99 u100
            ))
        )
        (ok (get results (fold check-active-proposal-for-dao all-proposal-ids {dao-id: dao-id, results: (list)})))
    )
)

(define-private (check-active-proposal-for-dao (proposal-id uint) (accumulator {dao-id: uint, results: (list 100 uint)}))
    (match (map-get? proposals proposal-id)
        proposal-data 
            (let 
                (
                    (dao-info (unwrap! (map-get? daos (get dao-id proposal-data)) accumulator))
                )
                (if (and 
                    (is-eq (get dao-id proposal-data) (get dao-id accumulator))
                    (not (get executed proposal-data))
                    (<= (- stacks-block-height (get created-at proposal-data)) (get voting-period dao-info))
                )
                {dao-id: (get dao-id accumulator), results: (unwrap! (as-max-len? (append (get results accumulator) proposal-id) u100) accumulator)}
                accumulator
                )
            )
        accumulator
    )
)
