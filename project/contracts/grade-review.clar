;; Grade Review Contract
;; This contract allows students to request reviews of their grades and teachers to respond

;; Constants
(define-constant ERR-NOT-AUTHORIZED (err u200))
(define-constant ERR-INVALID-REVIEW-ID (err u201))
(define-constant ERR-REVIEW-NOT-FOUND (err u202))
(define-constant ERR-ALREADY-REVIEWED (err u203))
(define-constant ERR-INVALID-STATUS (err u204))
(define-constant ERR-INVALID-ASSIGNMENT-ID (err u205))
(define-constant ERR-INVALID-GRADE (err u206))
(define-constant ERR-INVALID-REASON (err u207))
(define-constant ERR-INVALID-FEEDBACK (err u208))
(define-constant MAX-REVIEW-ID u1000000)
(define-constant MAX-ASSIGNMENT-ID u1000000)
(define-constant MAX-GRADE u100)
(define-constant MIN-TEXT-LENGTH u1)
(define-constant MAX-TEXT-LENGTH u500)

;; Define review status values
(define-constant STATUS-PENDING u1)
(define-constant STATUS-APPROVED u2)
(define-constant STATUS-REJECTED u3)

;; Data Variables
(define-data-var contract-owner principal tx-sender)

;; Maps
(define-map grade-reviews
    { review-id: uint }
    {
        assignment-id: uint,
        student-id: principal,
        original-grade: uint,
        reason: (string-ascii 500),
        status: uint,
        reviewer-feedback: (optional (string-ascii 500)),
        new-grade: (optional uint),
        requested-at: uint,
        reviewed-at: (optional uint)
    }
)

;; Counter for review IDs
(define-data-var review-counter uint u0)

;; Helper functions for validation
(define-private (validate-review-id (id uint))
    (<= id MAX-REVIEW-ID)
)

(define-private (validate-assignment-id (id uint))
    (<= id MAX-ASSIGNMENT-ID)
)

(define-private (validate-grade (grade uint))
    (<= grade MAX-GRADE)
)

(define-private (validate-text (text (string-ascii 500)))
    (and 
        (>= (len text) MIN-TEXT-LENGTH)
        (<= (len text) MAX-TEXT-LENGTH)
    )
)

(define-private (validate-optional-grade (grade (optional uint)))
    (match grade
        value (validate-grade value)
        true
    )
)

(define-private (validate-status (status uint))
    (or (is-eq status STATUS-PENDING)
        (is-eq status STATUS-APPROVED)
        (is-eq status STATUS-REJECTED))
)

;; Public functions
(define-public (request-grade-review 
    (assignment-id uint)
    (original-grade uint)
    (reason (string-ascii 500)))
    (let ((new-id (+ (var-get review-counter) u1)))
        (begin
            ;; Validate all inputs
            (asserts! (validate-review-id new-id) ERR-INVALID-REVIEW-ID)
            (asserts! (validate-assignment-id assignment-id) ERR-INVALID-ASSIGNMENT-ID)
            (asserts! (validate-grade original-grade) ERR-INVALID-GRADE)
            (asserts! (validate-text reason) ERR-INVALID-REASON)
            
            ;; Insert new review request
            (map-insert grade-reviews
                { review-id: new-id }
                {
                    assignment-id: assignment-id,
                    student-id: tx-sender,
                    original-grade: original-grade,
                    reason: reason,
                    status: STATUS-PENDING,
                    reviewer-feedback: none,
                    new-grade: none,
                    requested-at: block-height,
                    reviewed-at: none
                }
            )
            
            ;; Increment counter
            (var-set review-counter new-id)
            (ok new-id)
        )
    )
)

(define-public (respond-to-review
    (review-id uint)
    (status uint)
    (feedback (string-ascii 500))
    (new-grade (optional uint)))
    (let ((review (unwrap! (map-get? grade-reviews { review-id: review-id })
                          ERR-REVIEW-NOT-FOUND)))
        (begin
            ;; Check authorization
            (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
            
            ;; Validate all inputs
            (asserts! (validate-review-id review-id) ERR-INVALID-REVIEW-ID)
            (asserts! (validate-status status) ERR-INVALID-STATUS)
            (asserts! (validate-text feedback) ERR-INVALID-FEEDBACK)
            (asserts! (validate-optional-grade new-grade) ERR-INVALID-GRADE)
            
            ;; Check if already reviewed
            (asserts! (is-eq (get status review) STATUS-PENDING) ERR-ALREADY-REVIEWED)
            
            ;; Update review
            (ok (map-set grade-reviews
                { review-id: review-id }
                {
                    assignment-id: (get assignment-id review),
                    student-id: (get student-id review),
                    original-grade: (get original-grade review),
                    reason: (get reason review),
                    status: status,
                    reviewer-feedback: (some feedback),
                    new-grade: new-grade,
                    requested-at: (get requested-at review),
                    reviewed-at: (some block-height)
                }
            ))
        )
    )
)

;; Read-only functions
(define-read-only (get-review (review-id uint))
    (begin
        (asserts! (validate-review-id review-id) ERR-INVALID-REVIEW-ID)
        (match (map-get? grade-reviews { review-id: review-id })
            review (ok review)
            ERR-REVIEW-NOT-FOUND
        )
    )
)

(define-read-only (get-student-reviews (student-id principal))
    (let ((current-id (var-get review-counter)))
        (filter get-student-review-by-id (list current-id))
    )
)

(define-private (get-student-review-by-id (review-id uint))
    (match (map-get? grade-reviews { review-id: review-id })
        review (is-eq (get student-id review) tx-sender)
        false
    )
)
