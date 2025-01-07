;; Define the contract for the automated grading system
(define-data-var contract-owner principal tx-sender)

;; Constants for validation
(define-constant MIN-POINTS u0)
(define-constant MAX-POINTS u1000)
(define-constant MIN-CRITERIA-LENGTH u1)
(define-constant MAX-ASSIGNMENT-ID u1000000)
(define-constant HASH_LENGTH u32)

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-ASSIGNMENT (err u101))
(define-constant ERR-DEADLINE-PASSED (err u102))
(define-constant ERR-ALREADY-GRADED (err u103))
(define-constant ERR-INVALID-POINTS (err u104))
(define-constant ERR-INVALID-DEADLINE (err u105))
(define-constant ERR-INVALID-CRITERIA (err u106))
(define-constant ERR-INVALID-ASSIGNMENT-ID (err u107))
(define-constant ERR-EMPTY-TITLE (err u108))
(define-constant ERR-INVALID-CONTENT-HASH (err u109))

;; Define assignment structure
(define-map assignments
    { assignment-id: uint }
    {
        title: (string-ascii 100),
        total-points: uint,
        submission-deadline: uint,
        grading-criteria: (list 10 (string-ascii 100))
    }
)

;; Define submissions structure
(define-map submissions
    { assignment-id: uint, student-id: principal }
    {
        submitted-at: uint,
        content-hash: (buff 32),
        grade: (optional uint),
        feedback: (optional (string-ascii 500))
    }
)

;; Helper functions for validation
(define-private (validate-points (points uint))
    (and (>= points MIN-POINTS)
         (<= points MAX-POINTS))
)

(define-private (validate-deadline (deadline uint))
    (> deadline block-height)
)

(define-private (validate-criteria (criteria (list 10 (string-ascii 100))))
    (>= (len criteria) MIN-CRITERIA-LENGTH)
)

(define-private (validate-assignment-id (id uint))
    (<= id MAX-ASSIGNMENT-ID)
)

(define-private (validate-title (title (string-ascii 100)))
    (not (is-eq (len title) u0))
)

(define-private (validate-content-hash (hash (buff 32)))
    (and 
        ;; Check that the hash is exactly 32 bytes
        (is-eq (len hash) HASH_LENGTH)
        ;; Check that the hash is not all zeros
        (not (is-eq hash 0x0000000000000000000000000000000000000000000000000000000000000000))
    )
)

;; Public functions

(define-public (create-assignment (assignment-id uint) 
                                (title (string-ascii 100))
                                (total-points uint)
                                (deadline uint)
                                (criteria (list 10 (string-ascii 100))))
    (begin
        ;; Check authorization
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        
        ;; Validate inputs
        (asserts! (validate-assignment-id assignment-id) ERR-INVALID-ASSIGNMENT-ID)
        (asserts! (validate-title title) ERR-EMPTY-TITLE)
        (asserts! (validate-points total-points) ERR-INVALID-POINTS)
        (asserts! (validate-deadline deadline) ERR-INVALID-DEADLINE)
        (asserts! (validate-criteria criteria) ERR-INVALID-CRITERIA)
        
        ;; Insert assignment after validation
        (ok (map-insert assignments
            { assignment-id: assignment-id }
            {
                title: title,
                total-points: total-points,
                submission-deadline: deadline,
                grading-criteria: criteria
            }
        ))
    )
)

(define-public (submit-assignment (assignment-id uint) 
                                (content-hash (buff 32)))
    (let ((assignment (unwrap! (map-get? assignments { assignment-id: assignment-id })
                              ERR-INVALID-ASSIGNMENT))
          (current-time block-height))
        ;; Validate assignment ID and content hash
        (asserts! (validate-assignment-id assignment-id) ERR-INVALID-ASSIGNMENT-ID)
        (asserts! (validate-content-hash content-hash) ERR-INVALID-CONTENT-HASH)
        
        ;; Check deadline
        (asserts! (<= current-time (get submission-deadline assignment))
                 ERR-DEADLINE-PASSED)
        
        ;; Insert submission after validation
        (ok (map-insert submissions
            { 
                assignment-id: assignment-id,
                student-id: tx-sender
            }
            {
                submitted-at: current-time,
                content-hash: content-hash,
                grade: none,
                feedback: none
            }
        ))
    )
)

;; Read-only functions

(define-read-only (get-assignment (assignment-id uint))
    (begin
        (asserts! (validate-assignment-id assignment-id) ERR-INVALID-ASSIGNMENT-ID)
        (match (map-get? assignments { assignment-id: assignment-id })
            assignment (ok assignment)
            ERR-INVALID-ASSIGNMENT
        )
    )
)

(define-read-only (get-submission (assignment-id uint) (student-id principal))
    (begin
        (asserts! (validate-assignment-id assignment-id) ERR-INVALID-ASSIGNMENT-ID)
        (match (map-get? submissions { assignment-id: assignment-id, student-id: student-id })
            submission (ok submission)
            ERR-INVALID-ASSIGNMENT
        )
    )
)
