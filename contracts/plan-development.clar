;; Plan Development Contract
;; Manages business continuity plan creation and versioning

(define-constant ERR-NOT-AUTHORIZED (err u300))
(define-constant ERR-PLAN-NOT-FOUND (err u301))
(define-constant ERR-INVALID-STATUS (err u302))

(define-data-var plan-counter uint u0)

(define-map continuity-plans
  { plan-id: uint }
  {
    developer: principal,
    organization: (string-ascii 100),
    plan-name: (string-ascii 100),
    version: uint,
    status: (string-ascii 20),
    priority-level: uint,
    created-at: uint,
    approved-at: (optional uint),
    approver: (optional principal)
  }
)

(define-map plan-components
  { plan-id: uint, component-id: uint }
  {
    component-name: (string-ascii 100),
    description: (string-ascii 1000),
    procedures: (string-ascii 2000),
    responsible-party: (string-ascii 100),
    timeline: uint,
    resources-required: (string-ascii 500)
  }
)

(define-map plan-approvals
  { plan-id: uint }
  {
    approval-status: (string-ascii 20),
    approved-by: (optional principal),
    approval-date: (optional uint),
    comments: (string-ascii 500)
  }
)

(define-public (create-plan
  (organization (string-ascii 100))
  (plan-name (string-ascii 100))
  (priority-level uint))
  (let ((plan-id (+ (var-get plan-counter) u1)))
    (map-set continuity-plans
      { plan-id: plan-id }
      {
        developer: tx-sender,
        organization: organization,
        plan-name: plan-name,
        version: u1,
        status: "draft",
        priority-level: priority-level,
        created-at: block-height,
        approved-at: none,
        approver: none
      }
    )

    (map-set plan-approvals
      { plan-id: plan-id }
      {
        approval-status: "pending",
        approved-by: none,
        approval-date: none,
        comments: ""
      }
    )

    (var-set plan-counter plan-id)
    (print { event: "plan-created", plan-id: plan-id })
    (ok plan-id)
  )
)

(define-public (add-plan-component
  (plan-id uint)
  (component-id uint)
  (component-name (string-ascii 100))
  (description (string-ascii 1000))
  (procedures (string-ascii 2000))
  (responsible-party (string-ascii 100))
  (timeline uint)
  (resources-required (string-ascii 500)))
  (begin
    (asserts! (is-some (map-get? continuity-plans { plan-id: plan-id })) ERR-PLAN-NOT-FOUND)

    (map-set plan-components
      { plan-id: plan-id, component-id: component-id }
      {
        component-name: component-name,
        description: description,
        procedures: procedures,
        responsible-party: responsible-party,
        timeline: timeline,
        resources-required: resources-required
      }
    )

    (print { event: "component-added", plan-id: plan-id, component-id: component-id })
    (ok true)
  )
)

(define-public (submit-for-approval (plan-id uint))
  (begin
    (asserts! (is-some (map-get? continuity-plans { plan-id: plan-id })) ERR-PLAN-NOT-FOUND)

    (map-set continuity-plans
      { plan-id: plan-id }
      (merge
        (unwrap-panic (map-get? continuity-plans { plan-id: plan-id }))
        { status: "pending-approval" }
      )
    )

    (print { event: "plan-submitted-for-approval", plan-id: plan-id })
    (ok true)
  )
)

(define-public (approve-plan
  (plan-id uint)
  (comments (string-ascii 500)))
  (begin
    (asserts! (is-some (map-get? continuity-plans { plan-id: plan-id })) ERR-PLAN-NOT-FOUND)

    (map-set continuity-plans
      { plan-id: plan-id }
      (merge
        (unwrap-panic (map-get? continuity-plans { plan-id: plan-id }))
        {
          status: "approved",
          approved-at: (some block-height),
          approver: (some tx-sender)
        }
      )
    )

    (map-set plan-approvals
      { plan-id: plan-id }
      {
        approval-status: "approved",
        approved-by: (some tx-sender),
        approval-date: (some block-height),
        comments: comments
      }
    )

    (print { event: "plan-approved", plan-id: plan-id })
    (ok true)
  )
)

(define-public (create-plan-version (plan-id uint))
  (match (map-get? continuity-plans { plan-id: plan-id })
    plan-data
    (let ((new-version (+ (get version plan-data) u1)))
      (map-set continuity-plans
        { plan-id: plan-id }
        (merge plan-data
          {
            version: new-version,
            status: "draft",
            approved-at: none,
            approver: none
          }
        )
      )
      (print { event: "plan-version-created", plan-id: plan-id, version: new-version })
      (ok new-version)
    )
    ERR-PLAN-NOT-FOUND
  )
)

(define-read-only (get-plan (plan-id uint))
  (map-get? continuity-plans { plan-id: plan-id })
)

(define-read-only (get-plan-component (plan-id uint) (component-id uint))
  (map-get? plan-components { plan-id: plan-id, component-id: component-id })
)

(define-read-only (get-plan-approval (plan-id uint))
  (map-get? plan-approvals { plan-id: plan-id })
)

(define-read-only (get-plan-count)
  (var-get plan-counter)
)
