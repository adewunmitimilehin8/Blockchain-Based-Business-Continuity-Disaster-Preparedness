;; Risk Assessment Contract
;; Manages business continuity risk assessments

(define-constant ERR-NOT-AUTHORIZED (err u200))
(define-constant ERR-ASSESSMENT-NOT-FOUND (err u201))
(define-constant ERR-INVALID-RISK-LEVEL (err u202))

(define-data-var assessment-counter uint u0)

(define-map risk-assessments
  { assessment-id: uint }
  {
    assessor: principal,
    organization: (string-ascii 100),
    assessment-type: (string-ascii 50),
    risk-level: uint,
    impact-score: uint,
    likelihood-score: uint,
    mitigation-status: (string-ascii 20),
    created-at: uint,
    updated-at: uint
  }
)

(define-map risk-factors
  { assessment-id: uint, factor-id: uint }
  {
    factor-name: (string-ascii 100),
    description: (string-ascii 500),
    severity: uint,
    probability: uint,
    mitigation-plan: (string-ascii 500)
  }
)

(define-public (create-assessment
  (organization (string-ascii 100))
  (assessment-type (string-ascii 50))
  (risk-level uint)
  (impact-score uint)
  (likelihood-score uint))
  (let ((assessment-id (+ (var-get assessment-counter) u1)))
    (asserts! (<= risk-level u5) ERR-INVALID-RISK-LEVEL)
    (asserts! (<= impact-score u10) ERR-INVALID-RISK-LEVEL)
    (asserts! (<= likelihood-score u10) ERR-INVALID-RISK-LEVEL)

    (map-set risk-assessments
      { assessment-id: assessment-id }
      {
        assessor: tx-sender,
        organization: organization,
        assessment-type: assessment-type,
        risk-level: risk-level,
        impact-score: impact-score,
        likelihood-score: likelihood-score,
        mitigation-status: "pending",
        created-at: block-height,
        updated-at: block-height
      }
    )

    (var-set assessment-counter assessment-id)
    (print { event: "assessment-created", assessment-id: assessment-id })
    (ok assessment-id)
  )
)

(define-public (add-risk-factor
  (assessment-id uint)
  (factor-id uint)
  (factor-name (string-ascii 100))
  (description (string-ascii 500))
  (severity uint)
  (probability uint)
  (mitigation-plan (string-ascii 500)))
  (begin
    (asserts! (is-some (map-get? risk-assessments { assessment-id: assessment-id })) ERR-ASSESSMENT-NOT-FOUND)
    (asserts! (<= severity u5) ERR-INVALID-RISK-LEVEL)
    (asserts! (<= probability u5) ERR-INVALID-RISK-LEVEL)

    (map-set risk-factors
      { assessment-id: assessment-id, factor-id: factor-id }
      {
        factor-name: factor-name,
        description: description,
        severity: severity,
        probability: probability,
        mitigation-plan: mitigation-plan
      }
    )

    (print { event: "risk-factor-added", assessment-id: assessment-id, factor-id: factor-id })
    (ok true)
  )
)

(define-public (update-mitigation-status
  (assessment-id uint)
  (new-status (string-ascii 20)))
  (begin
    (asserts! (is-some (map-get? risk-assessments { assessment-id: assessment-id })) ERR-ASSESSMENT-NOT-FOUND)

    (map-set risk-assessments
      { assessment-id: assessment-id }
      (merge
        (unwrap-panic (map-get? risk-assessments { assessment-id: assessment-id }))
        {
          mitigation-status: new-status,
          updated-at: block-height
        }
      )
    )

    (print { event: "mitigation-status-updated", assessment-id: assessment-id, status: new-status })
    (ok true)
  )
)

(define-read-only (get-assessment (assessment-id uint))
  (map-get? risk-assessments { assessment-id: assessment-id })
)

(define-read-only (get-risk-factor (assessment-id uint) (factor-id uint))
  (map-get? risk-factors { assessment-id: assessment-id, factor-id: factor-id })
)

(define-read-only (calculate-risk-score (impact uint) (likelihood uint))
  (* impact likelihood)
)

(define-read-only (get-assessment-count)
  (var-get assessment-counter)
)
