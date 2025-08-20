;; Enhanced Vaccine Distribution Management System Smart Contract
;; A comprehensive blockchain-based solution for tracking vaccine inventory, 
;; managing healthcare provider authorizations, monitoring storage conditions,
;; and maintaining complete immunization records with full audit trails.

;; Administrative Control Variables
(define-data-var system-administrator principal tx-sender)

;; System Error Definitions
(define-constant ERR-UNAUTHORIZED-ACCESS (err u100))
(define-constant ERR-INVALID-VACCINE-BATCH-DATA (err u101))
(define-constant ERR-DUPLICATE-BATCH-EXISTS (err u102))
(define-constant ERR-BATCH-NOT-FOUND (err u103))
(define-constant ERR-INSUFFICIENT-VACCINE-INVENTORY (err u104))
(define-constant ERR-INVALID-PATIENT-IDENTIFIER (err u105))
(define-constant ERR-PATIENT-ALREADY-VACCINATED (err u106))
(define-constant ERR-TEMPERATURE-STORAGE-BREACH (err u107))
(define-constant ERR-EXPIRED-VACCINE-BATCH (err u108))
(define-constant ERR-INVALID-ADMINISTRATION-SITE (err u109))
(define-constant ERR-VACCINATION-LIMIT-EXCEEDED (err u110))
(define-constant ERR-INSUFFICIENT-DOSE-SPACING (err u111))
(define-constant ERR-ADMINISTRATOR-PRIVILEGE-REQUIRED (err u112))
(define-constant ERR-MALFORMED-INPUT-DATA (err u113))
(define-constant ERR-INVALID-FUTURE-DATE (err u114))
(define-constant ERR-INVALID-STORAGE-CAPACITY (err u115))

;; System Configuration Constants
(define-constant min-ultra-cold-storage-temp (- 70))
(define-constant max-refrigerated-storage-temp 8)
(define-constant mandatory-dose-interval-days u21)
(define-constant maximum-permitted-doses u4)
(define-constant min-string-length u1)
(define-constant current-block-timestamp block-height)
(define-constant max-temperature-violations u2)
(define-constant max-immunization-history-entries u10)
(define-constant max-adverse-reaction-entries u5)
(define-constant max-temperature-log-entries u100)

;; Core Data Storage Maps
(define-map vaccine-batch-registry
    { batch-tracking-id: (string-ascii 32) }
    {
        pharmaceutical-manufacturer: (string-ascii 50),
        vaccine-brand-name: (string-ascii 50),
        manufacturing-timestamp: uint,
        expiration-timestamp: uint,
        available-dose-count: uint,
        optimal-storage-temperature: int,
        batch-operational-status: (string-ascii 20),
        cold-chain-violation-count: uint,
        designated-storage-facility: (string-ascii 100),
        quality-assurance-notes: (string-ascii 500)
    }
)

(define-map patient-immunization-database
    { unique-patient-identifier: (string-ascii 32) }
    {
        complete-vaccination-history: (list 10 {
            source-vaccine-batch: (string-ascii 32),
            administration-timestamp: uint,
            vaccine-product-administered: (string-ascii 50),
            sequential-dose-number: uint,
            healthcare-provider-principal: principal,
            vaccination-facility-location: (string-ascii 100),
            next-dose-due-date: (optional uint)
        }),
        cumulative-doses-administered: uint,
        documented-adverse-events: (list 5 (string-ascii 200)),
        medical-contraindication-status: (optional (string-ascii 200))
    }
)

(define-map certified-healthcare-providers 
    principal 
    {
        professional-designation: (string-ascii 20),
        healthcare-institution-name: (string-ascii 100),
        license-validity-timestamp: uint
    }
)

(define-map cold-storage-facility-registry
    (string-ascii 100)
    {
        facility-street-address: (string-ascii 200),
        maximum-storage-capacity: uint,
        current-inventory-level: uint,
        temperature-monitoring-log: (list 100 {
            sensor-reading-timestamp: uint,
            recorded-temperature-celsius: int
        })
    }
)

;; Administrative Privilege Validation
(define-private (validate-system-administrator-privileges)
    (is-eq tx-sender (var-get system-administrator))
)

;; Enhanced Principal Address Validation
(define-private (validate-principal-address (target-principal principal))
    (and 
        (not (is-eq target-principal tx-sender))
        (not (is-eq target-principal (var-get system-administrator)))
        (match (principal-destruct? target-principal)
            validation-success true
            validation-error false)
    )
)

;; Comprehensive String Validation Functions
(define-private (validate-short-identifier-string (input-string (string-ascii 32)))
    (> (len input-string) min-string-length)
)

(define-private (validate-brief-descriptor-string (input-string (string-ascii 20)))
    (> (len input-string) min-string-length)
)

(define-private (validate-standard-text-string (input-string (string-ascii 50)))
    (> (len input-string) min-string-length)
)

(define-private (validate-extended-text-string (input-string (string-ascii 100)))
    (> (len input-string) min-string-length)
)

(define-private (validate-detailed-text-string (input-string (string-ascii 200)))
    (> (len input-string) min-string-length)
)

(define-private (validate-future-date-timestamp (target-timestamp uint))
    (> target-timestamp current-block-timestamp)
)

(define-private (validate-positive-capacity-value (capacity-amount uint))
    (> capacity-amount u0)
)

;; System Information Retrieval Functions
(define-read-only (retrieve-current-system-administrator)
    (ok (var-get system-administrator))
)

(define-read-only (verify-healthcare-provider-credentials (provider-principal principal))
    (match (map-get? certified-healthcare-providers provider-principal)
        provider-credential-data 
        (>= (get license-validity-timestamp provider-credential-data) current-block-timestamp)
        false
    )
)

;; Administrative Management Functions
(define-public (transfer-system-administration-rights (new-system-administrator principal))
    (begin
        (asserts! (validate-system-administrator-privileges) ERR-ADMINISTRATOR-PRIVILEGE-REQUIRED)
        (asserts! (validate-principal-address new-system-administrator) ERR-MALFORMED-INPUT-DATA)
        (ok (var-set system-administrator new-system-administrator))
    )
)

(define-public (register-authorized-healthcare-provider 
    (provider-principal-address principal)
    (medical-specialization (string-ascii 20))
    (affiliated-healthcare-facility (string-ascii 100))
    (professional-license-expiration uint))
    (begin
        (asserts! (validate-system-administrator-privileges) ERR-UNAUTHORIZED-ACCESS)
        (asserts! (validate-principal-address provider-principal-address) ERR-MALFORMED-INPUT-DATA)
        (asserts! (validate-brief-descriptor-string medical-specialization) ERR-MALFORMED-INPUT-DATA)
        (asserts! (validate-extended-text-string affiliated-healthcare-facility) ERR-MALFORMED-INPUT-DATA)
        (asserts! (validate-future-date-timestamp professional-license-expiration) ERR-INVALID-FUTURE-DATE)
        (ok (map-set certified-healthcare-providers 
            provider-principal-address 
            {
                professional-designation: medical-specialization,
                healthcare-institution-name: affiliated-healthcare-facility,
                license-validity-timestamp: professional-license-expiration
            }))
    )
)

(define-public (establish-storage-facility
    (facility-unique-identifier (string-ascii 100))
    (complete-street-address (string-ascii 200))
    (total-storage-capacity uint))
    (begin
        (asserts! (validate-system-administrator-privileges) ERR-UNAUTHORIZED-ACCESS)
        (asserts! (validate-extended-text-string facility-unique-identifier) ERR-MALFORMED-INPUT-DATA)
        (asserts! (validate-detailed-text-string complete-street-address) ERR-MALFORMED-INPUT-DATA)
        (asserts! (validate-positive-capacity-value total-storage-capacity) ERR-INVALID-STORAGE-CAPACITY)
        (ok (map-set cold-storage-facility-registry
            facility-unique-identifier
            {
                facility-street-address: complete-street-address,
                maximum-storage-capacity: total-storage-capacity,
                current-inventory-level: u0,
                temperature-monitoring-log: (list)
            }))
    )
)

;; Vaccine Inventory Management Functions
(define-public (add-new-vaccine-batch-to-inventory 
    (batch-tracking-identifier (string-ascii 32))
    (pharmaceutical-company-name (string-ascii 50))
    (commercial-vaccine-name (string-ascii 50))
    (batch-production-date uint)
    (vaccine-expiration-date uint)
    (initial-dose-quantity uint)
    (required-storage-temperature-celsius int)
    (assigned-storage-location (string-ascii 100)))
    (begin
        (asserts! (verify-healthcare-provider-credentials tx-sender) ERR-UNAUTHORIZED-ACCESS)
        (asserts! (validate-short-identifier-string batch-tracking-identifier) ERR-MALFORMED-INPUT-DATA)
        (asserts! (validate-standard-text-string pharmaceutical-company-name) ERR-MALFORMED-INPUT-DATA)
        (asserts! (validate-standard-text-string commercial-vaccine-name) ERR-MALFORMED-INPUT-DATA)
        (asserts! (validate-extended-text-string assigned-storage-location) ERR-MALFORMED-INPUT-DATA)
        (asserts! (is-none (map-get? vaccine-batch-registry {batch-tracking-id: batch-tracking-identifier})) ERR-DUPLICATE-BATCH-EXISTS)
        (asserts! (validate-positive-capacity-value initial-dose-quantity) ERR-INVALID-VACCINE-BATCH-DATA)
        (asserts! (validate-future-date-timestamp vaccine-expiration-date) ERR-INVALID-FUTURE-DATE)
        (asserts! (> vaccine-expiration-date batch-production-date) ERR-INVALID-VACCINE-BATCH-DATA)
        (asserts! (and (>= required-storage-temperature-celsius min-ultra-cold-storage-temp) 
                      (<= required-storage-temperature-celsius max-refrigerated-storage-temp)) 
                 ERR-TEMPERATURE-STORAGE-BREACH)
        
        (ok (map-set vaccine-batch-registry 
            {batch-tracking-id: batch-tracking-identifier}
            {
                pharmaceutical-manufacturer: pharmaceutical-company-name,
                vaccine-brand-name: commercial-vaccine-name,
                manufacturing-timestamp: batch-production-date,
                expiration-timestamp: vaccine-expiration-date,
                available-dose-count: initial-dose-quantity,
                optimal-storage-temperature: required-storage-temperature-celsius,
                batch-operational-status: "operational",
                cold-chain-violation-count: u0,
                designated-storage-facility: assigned-storage-location,
                quality-assurance-notes: ""
            }))
    )
)

(define-public (modify-vaccine-batch-operational-status
    (batch-tracking-identifier (string-ascii 32))
    (new-operational-status (string-ascii 20)))
    (begin
        (asserts! (verify-healthcare-provider-credentials tx-sender) ERR-UNAUTHORIZED-ACCESS)
        (asserts! (validate-short-identifier-string batch-tracking-identifier) ERR-MALFORMED-INPUT-DATA)
        (asserts! (validate-brief-descriptor-string new-operational-status) ERR-MALFORMED-INPUT-DATA)
        (match (map-get? vaccine-batch-registry {batch-tracking-id: batch-tracking-identifier})
            existing-batch-data (ok (map-set vaccine-batch-registry 
                {batch-tracking-id: batch-tracking-identifier}
                (merge existing-batch-data {batch-operational-status: new-operational-status})))
            ERR-BATCH-NOT-FOUND
        )
    )
)

(define-public (document-cold-chain-temperature-violation
    (affected-batch-identifier (string-ascii 32))
    (temperature-reading-celsius int))
    (begin
        (asserts! (verify-healthcare-provider-credentials tx-sender) ERR-UNAUTHORIZED-ACCESS)
        (asserts! (validate-short-identifier-string affected-batch-identifier) ERR-MALFORMED-INPUT-DATA)
        (match (map-get? vaccine-batch-registry {batch-tracking-id: affected-batch-identifier})
            current-batch-data (ok (map-set vaccine-batch-registry 
                {batch-tracking-id: affected-batch-identifier}
                (merge current-batch-data {
                    cold-chain-violation-count: (+ (get cold-chain-violation-count current-batch-data) u1),
                    batch-operational-status: (if (> (get cold-chain-violation-count current-batch-data) max-temperature-violations) 
                                    "temperature-compromised" 
                                    (get batch-operational-status current-batch-data))
                })))
            ERR-BATCH-NOT-FOUND
        )
    )
)

;; Patient Immunization Documentation Functions
(define-public (administer-vaccine-and-document
    (patient-unique-identifier (string-ascii 32))
    (vaccine-batch-identifier (string-ascii 32))
    (administration-facility-location (string-ascii 100)))
    (begin
        (asserts! (verify-healthcare-provider-credentials tx-sender) ERR-UNAUTHORIZED-ACCESS)
        (asserts! (validate-short-identifier-string patient-unique-identifier) ERR-INVALID-PATIENT-IDENTIFIER)
        (asserts! (validate-short-identifier-string vaccine-batch-identifier) ERR-MALFORMED-INPUT-DATA)
        (asserts! (validate-extended-text-string administration-facility-location) ERR-INVALID-ADMINISTRATION-SITE)
        
        (match (map-get? vaccine-batch-registry {batch-tracking-id: vaccine-batch-identifier})
            selected-batch-data (begin
                (asserts! (> (get available-dose-count selected-batch-data) u0) ERR-INSUFFICIENT-VACCINE-INVENTORY)
                (asserts! (is-eq (get batch-operational-status selected-batch-data) "operational") ERR-INVALID-VACCINE-BATCH-DATA)
                (asserts! (<= current-block-timestamp (get expiration-timestamp selected-batch-data)) ERR-EXPIRED-VACCINE-BATCH)
                
                (match (map-get? patient-immunization-database {unique-patient-identifier: patient-unique-identifier})
                    existing-patient-record (begin
                        (asserts! (< (get cumulative-doses-administered existing-patient-record) maximum-permitted-doses) 
                                ERR-VACCINATION-LIMIT-EXCEEDED)
                        (let ((next-dose-sequence (+ (get cumulative-doses-administered existing-patient-record) u1)))
                            (if (> next-dose-sequence u1)
                                (asserts! (>= (- current-block-timestamp 
                                    (get administration-timestamp (unwrap-panic (element-at 
                                        (get complete-vaccination-history existing-patient-record) 
                                        (- next-dose-sequence u2))))) 
                                    mandatory-dose-interval-days)
                                    ERR-INSUFFICIENT-DOSE-SPACING)
                                true
                            )
                            
                            (map-set vaccine-batch-registry 
                                {batch-tracking-id: vaccine-batch-identifier}
                                (merge selected-batch-data 
                                    {available-dose-count: (- (get available-dose-count selected-batch-data) u1)}))
                            
                            (ok (map-set patient-immunization-database
                                {unique-patient-identifier: patient-unique-identifier}
                                {
                                    complete-vaccination-history: (unwrap-panic (as-max-len? 
                                        (append (get complete-vaccination-history existing-patient-record)
                                            {
                                                source-vaccine-batch: vaccine-batch-identifier,
                                                administration-timestamp: current-block-timestamp,
                                                vaccine-product-administered: (get vaccine-brand-name selected-batch-data),
                                                sequential-dose-number: next-dose-sequence,
                                                healthcare-provider-principal: tx-sender,
                                                vaccination-facility-location: administration-facility-location,
                                                next-dose-due-date: (some (+ current-block-timestamp mandatory-dose-interval-days))
                                            }
                                        ) max-immunization-history-entries)),
                                    cumulative-doses-administered: next-dose-sequence,
                                    documented-adverse-events: (get documented-adverse-events existing-patient-record),
                                    medical-contraindication-status: (get medical-contraindication-status existing-patient-record)
                                }))))
                    
                    ;; Create initial patient record for first vaccination
                    (begin
                        (map-set vaccine-batch-registry 
                            {batch-tracking-id: vaccine-batch-identifier}
                            (merge selected-batch-data 
                                {available-dose-count: (- (get available-dose-count selected-batch-data) u1)}))
                        
                        (ok (map-set patient-immunization-database
                            {unique-patient-identifier: patient-unique-identifier}
                            {
                                complete-vaccination-history: (list 
                                    {
                                        source-vaccine-batch: vaccine-batch-identifier,
                                        administration-timestamp: current-block-timestamp,
                                        vaccine-product-administered: (get vaccine-brand-name selected-batch-data),
                                        sequential-dose-number: u1,
                                        healthcare-provider-principal: tx-sender,
                                        vaccination-facility-location: administration-facility-location,
                                        next-dose-due-date: (some (+ current-block-timestamp mandatory-dose-interval-days))
                                    }),
                                cumulative-doses-administered: u1,
                                documented-adverse-events: (list),
                                medical-contraindication-status: none
                            })))
                )
            )
            ERR-BATCH-NOT-FOUND
        )
    )
)

;; Data Retrieval and Query Functions
(define-read-only (retrieve-vaccine-batch-information (batch-identifier (string-ascii 32)))
    (map-get? vaccine-batch-registry {batch-tracking-id: batch-identifier})
)

(define-read-only (retrieve-patient-immunization-record (patient-identifier (string-ascii 32)))
    (map-get? patient-immunization-database {unique-patient-identifier: patient-identifier})
)

(define-read-only (retrieve-storage-facility-information (facility-identifier (string-ascii 100)))
    (map-get? cold-storage-facility-registry facility-identifier)
)

(define-read-only (validate-vaccine-batch-suitability-for-administration (batch-identifier (string-ascii 32)))
    (match (map-get? vaccine-batch-registry {batch-tracking-id: batch-identifier})
        batch-quality-data (and
            (is-eq (get batch-operational-status batch-quality-data) "operational")
            (> (get available-dose-count batch-quality-data) u0)
            (<= current-block-timestamp (get expiration-timestamp batch-quality-data))
            (<= (get cold-chain-violation-count batch-quality-data) max-temperature-violations))
        false
    )
)