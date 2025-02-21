;; Service Agreement Smart Contract
;; This contract enables creation and management of service agreements
;; between service providers and clients.

;; Error codes
(define-constant ERR_UNAUTHORIZED_ACCESS (err u100))
(define-constant ERR_AGREEMENT_ALREADY_EXISTS (err u101))
(define-constant ERR_AGREEMENT_NOT_FOUND (err u102))
(define-constant ERR_INVALID_AGREEMENT_STATUS (err u103))
(define-constant ERR_INSUFFICIENT_PAYMENT_AMOUNT (err u104))
(define-constant ERR_INVALID_PRINCIPAL_ADDRESS (err u105))
(define-constant ERR_INVALID_INPUT_PARAMETERS (err u106))

;; Contract data maps and variables
(define-data-var contract-admin-address principal tx-sender)
(define-map ServiceAgreementDetails
    { agreement-id: uint }
    {
        provider-principal: principal,
        client-principal: principal,
        agreement-start-timestamp: uint,
        agreement-end-timestamp: uint,
        total-payment-amount: uint,
        current-status: (string-ascii 20),
        service-details: (string-ascii 256)
    }
)

(define-map ProviderPerformanceMetrics
    { provider-principal: principal }
    {
        current-rating: uint,
        lifetime-agreements: uint,
        completed-agreements-count: uint
    }
)

(define-map DisputeRecordDetails
    { agreement-id: uint }
    {
        dispute-creator: principal,
        dispute-details: (string-ascii 256),
        current-dispute-status: (string-ascii 20),
        resolution-details: (optional (string-ascii 256))
    }
)

;; Initialize contract
(define-public (initialize-contract (new-admin-address principal))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-admin-address)) ERR_UNAUTHORIZED_ACCESS)
        (asserts! (is-valid-principal-address new-admin-address) ERR_INVALID_PRINCIPAL_ADDRESS)
        (ok (var-set contract-admin-address new-admin-address))
    )
)

;; Create new service agreement
(define-public (create-service-agreement 
    (agreement-id uint)
    (provider-principal principal)
    (client-principal principal)
    (start-timestamp uint)
    (end-timestamp uint)
    (payment-amount uint)
    (service-details (string-ascii 256)))
    
    (let
        ((existing-agreement (get-service-agreement-details agreement-id)))
        (asserts! (is-none existing-agreement) ERR_AGREEMENT_ALREADY_EXISTS)
        (asserts! (>= end-timestamp start-timestamp) ERR_INVALID_AGREEMENT_STATUS)
        (asserts! (> payment-amount u0) ERR_INVALID_AGREEMENT_STATUS)
        (asserts! (is-valid-principal-address provider-principal) ERR_INVALID_PRINCIPAL_ADDRESS)
        (asserts! (is-valid-principal-address client-principal) ERR_INVALID_PRINCIPAL_ADDRESS)
        (asserts! (is-valid-description-length service-details) ERR_INVALID_INPUT_PARAMETERS)
        
        (map-set ServiceAgreementDetails
            { agreement-id: agreement-id }
            {
                provider-principal: provider-principal,
                client-principal: client-principal,
                agreement-start-timestamp: start-timestamp,
                agreement-end-timestamp: end-timestamp,
                total-payment-amount: payment-amount,
                current-status: "PENDING",
                service-details: service-details
            }
        )
        
        ;; Initialize or update provider metrics
        (match (map-get? ProviderPerformanceMetrics { provider-principal: provider-principal })
            existing-metrics
            (map-set ProviderPerformanceMetrics
                { provider-principal: provider-principal }
                {
                    current-rating: (get current-rating existing-metrics),
                    lifetime-agreements: (+ (get lifetime-agreements existing-metrics) u1),
                    completed-agreements-count: (get completed-agreements-count existing-metrics)
                }
            )
            (map-set ProviderPerformanceMetrics
                { provider-principal: provider-principal }
                {
                    current-rating: u0,
                    lifetime-agreements: u1,
                    completed-agreements-count: u0
                }
            )
        )
        (ok true)
    )
)

;; Accept service agreement
(define-public (accept-service-agreement (agreement-id uint))
    (let
        ((agreement-details (unwrap! (get-service-agreement-details agreement-id) ERR_AGREEMENT_NOT_FOUND)))
        (asserts! (is-eq (get current-status agreement-details) "PENDING") ERR_INVALID_AGREEMENT_STATUS)
        (asserts! (is-eq tx-sender (get provider-principal agreement-details)) ERR_UNAUTHORIZED_ACCESS)
        
        (map-set ServiceAgreementDetails
            { agreement-id: agreement-id }
            (merge agreement-details { current-status: "ACTIVE" })
        )
        (ok true)
    )
)

;; Complete service agreement
(define-public (complete-service-agreement (agreement-id uint))
    (let
        ((agreement-details (unwrap! (get-service-agreement-details agreement-id) ERR_AGREEMENT_NOT_FOUND)))
        (asserts! (is-eq (get current-status agreement-details) "ACTIVE") ERR_INVALID_AGREEMENT_STATUS)
        (asserts! (is-eq tx-sender (get client-principal agreement-details)) ERR_UNAUTHORIZED_ACCESS)
        
        ;; Update agreement status
        (map-set ServiceAgreementDetails
            { agreement-id: agreement-id }
            (merge agreement-details { current-status: "COMPLETED" })
        )
        
        ;; Update provider metrics
        (let ((provider-metrics (unwrap! (map-get? ProviderPerformanceMetrics 
                { provider-principal: (get provider-principal agreement-details) }) 
                ERR_AGREEMENT_NOT_FOUND)))
            (map-set ProviderPerformanceMetrics
                { provider-principal: (get provider-principal agreement-details) }
                (merge provider-metrics {
                    completed-agreements-count: (+ (get completed-agreements-count provider-metrics) u1)
                })
            )
            (ok true)
        )
    )
)

;; File service dispute
(define-public (file-service-dispute 
    (agreement-id uint)
    (dispute-details (string-ascii 256)))
    
    (let
        ((agreement-details (unwrap! (get-service-agreement-details agreement-id) ERR_AGREEMENT_NOT_FOUND)))
        (asserts! (or
            (is-eq tx-sender (get provider-principal agreement-details))
            (is-eq tx-sender (get client-principal agreement-details))
        ) ERR_UNAUTHORIZED_ACCESS)
        (asserts! (is-valid-description-length dispute-details) ERR_INVALID_INPUT_PARAMETERS)
        
        (map-set DisputeRecordDetails
            { agreement-id: agreement-id }
            {
                dispute-creator: tx-sender,
                dispute-details: dispute-details,
                current-dispute-status: "PENDING",
                resolution-details: none
            }
        )
        
        (map-set ServiceAgreementDetails
            { agreement-id: agreement-id }
            (merge agreement-details { current-status: "DISPUTED" })
        )
        (ok true)
    )
)

;; Resolve service dispute
(define-public (resolve-service-dispute
    (agreement-id uint)
    (resolution-details (string-ascii 256))
    (new-status (string-ascii 20)))
    
    (let
        ((agreement-details (unwrap! (get-service-agreement-details agreement-id) ERR_AGREEMENT_NOT_FOUND))
         (dispute-details (unwrap! (get-dispute-details agreement-id) ERR_AGREEMENT_NOT_FOUND)))
        
        (asserts! (is-eq tx-sender (var-get contract-admin-address)) ERR_UNAUTHORIZED_ACCESS)
        (asserts! (is-eq (get current-status agreement-details) "DISPUTED") ERR_INVALID_AGREEMENT_STATUS)
        (asserts! (is-valid-agreement-status new-status) ERR_INVALID_AGREEMENT_STATUS)
        (asserts! (is-valid-description-length resolution-details) ERR_INVALID_INPUT_PARAMETERS)
        
        ;; Update dispute record
        (map-set DisputeRecordDetails
            { agreement-id: agreement-id }
            (merge dispute-details {
                current-dispute-status: "RESOLVED",
                resolution-details: (some resolution-details)
            })
        )
        
        ;; Update agreement status
        (map-set ServiceAgreementDetails
            { agreement-id: agreement-id }
            (merge agreement-details { current-status: new-status })
        )
        (ok true)
    )
)

;; Rate service provider
(define-public (submit-provider-rating 
    (provider-principal principal)
    (rating-value uint))
    
    (let
        ((provider-metrics (unwrap! (map-get? ProviderPerformanceMetrics { provider-principal: provider-principal }) ERR_AGREEMENT_NOT_FOUND)))
        (asserts! (is-valid-principal-address provider-principal) ERR_INVALID_PRINCIPAL_ADDRESS)
        (asserts! (<= rating-value u5) ERR_INVALID_AGREEMENT_STATUS)
        (asserts! (> rating-value u0) ERR_INVALID_AGREEMENT_STATUS)
        
        (map-set ProviderPerformanceMetrics
            { provider-principal: provider-principal }
            (merge provider-metrics {
                current-rating: (/ (+ (* (get current-rating provider-metrics) 
                               (get lifetime-agreements provider-metrics)) 
                            rating-value)
                         (+ (get lifetime-agreements provider-metrics) u1))
            })
        )
        (ok true)
    )
)

;; Getter functions
(define-read-only (get-service-agreement-details (agreement-id uint))
    (map-get? ServiceAgreementDetails { agreement-id: agreement-id })
)

(define-read-only (get-provider-metrics (provider-principal principal))
    (map-get? ProviderPerformanceMetrics { provider-principal: provider-principal })
)

(define-read-only (get-dispute-details (agreement-id uint))
    (map-get? DisputeRecordDetails { agreement-id: agreement-id })
)

;; Helper functions
(define-private (is-valid-agreement-status (status-value (string-ascii 20)))
    (or
        (is-eq status-value "PENDING")
        (is-eq status-value "ACTIVE")
        (is-eq status-value "COMPLETED")
        (is-eq status-value "DISPUTED")
        (is-eq status-value "CANCELLED")
    )
)

;; Principal validation
(define-private (is-valid-principal-address (principal-address principal))
    (and 
        (not (is-eq principal-address tx-sender))
        (is-ok (principal-destruct? principal-address))
    )
)

;; Description validation
(define-private (is-valid-description-length (description-text (string-ascii 256)))
    (and
        (>= (len description-text) u1)
        (<= (len description-text) u256)
    )
)