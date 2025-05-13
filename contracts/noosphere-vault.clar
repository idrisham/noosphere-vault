;; Noosphere Repository Contract - Digital Asset Archiving System
;; Enables secure cataloging, ownership verification, and controlled sharing of knowledge assets


;; Core Data Structures
(define-map knowledge-vault
  { asset-uid: uint }
  {
    asset-descriptor: (string-ascii 80),
    asset-creator: principal,
    asset-magnitude: uint,
    archiving-timestamp: uint,
    asset-summary: (string-ascii 256),
    asset-tags: (list 8 (string-ascii 40))
  }
)

(define-map permission-ledger
  { asset-uid: uint, viewer: principal }
  { viewing-rights: bool }
)

;; System Administration Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERROR_NOT_AUTHORIZED (err u300))
(define-constant ERROR_ITEM_MISSING (err u301))
(define-constant ERROR_DUPLICATE_ENTRY (err u302))
(define-constant ERROR_INVALID_DESCRIPTOR (err u303))
(define-constant ERROR_INVALID_DIMENSIONS (err u304))
(define-constant ERROR_PERMISSIONS_DENIED (err u305))

;; Asset Counter Management
(define-data-var asset-counter uint u0)

;; Validator Helper Functions
(define-private (asset-exists? (asset-uid uint))
  (is-some (map-get? knowledge-vault { asset-uid: asset-uid }))
)

(define-private (validate-tag-collection (tags (list 8 (string-ascii 40))))
  (and
    (> (len tags) u0)
    (<= (len tags) u8)
    (is-eq (len (filter validate-individual-tag tags)) (len tags))
  )
)

(define-private (validate-individual-tag (tag (string-ascii 40)))
  (and 
    (> (len tag) u0)
    (< (len tag) u41)
  )
)

(define-private (is-asset-owner (asset-uid uint) (owner principal))
  (match (map-get? knowledge-vault { asset-uid: asset-uid })
    asset-data (is-eq (get asset-creator asset-data) owner)
    false
  )
)

(define-private (fetch-asset-magnitude (asset-uid uint))
  (default-to u0 
    (get asset-magnitude 
      (map-get? knowledge-vault { asset-uid: asset-uid })
    )
  )
)

;; Asset Registration and Management Functions

;; Registers a new knowledge asset in the system
(define-public (archive-knowledge-asset (descriptor (string-ascii 80)) (magnitude uint) (summary (string-ascii 256)) (tags (list 8 (string-ascii 40))))
  (let
    (
      (asset-uid (+ (var-get asset-counter) u1))
    )
    ;; Input validation checks
    (asserts! (> (len descriptor) u0) ERROR_INVALID_DESCRIPTOR)
    (asserts! (< (len descriptor) u81) ERROR_INVALID_DESCRIPTOR)
    (asserts! (> magnitude u0) ERROR_INVALID_DIMENSIONS)
    (asserts! (< magnitude u2000000000) ERROR_INVALID_DIMENSIONS)
    (asserts! (> (len summary) u0) ERROR_INVALID_DESCRIPTOR)
    (asserts! (< (len summary) u257) ERROR_INVALID_DESCRIPTOR)
    (asserts! (validate-tag-collection tags) ERROR_INVALID_DESCRIPTOR)

    ;; Record asset details in vault catalog
    (map-insert knowledge-vault
      { asset-uid: asset-uid }
      {
        asset-descriptor: descriptor,
        asset-creator: tx-sender,
        asset-magnitude: magnitude,
        archiving-timestamp: block-height,
        asset-summary: summary,
        asset-tags: tags
      }
    )

    ;; Grant ownership permissions automatically to creator
    (map-insert permission-ledger
      { asset-uid: asset-uid, viewer: tx-sender }
      { viewing-rights: true }
    )
    
    ;; Update sequential counter
    (var-set asset-counter asset-uid)
    (ok asset-uid)
  )
)

;; Legacy compatibility function for system integration
(define-public (catalog-digital-asset (descriptor (string-ascii 80)) (magnitude uint) (summary (string-ascii 256)) (tags (list 8 (string-ascii 40))))
  (let
    (
      (asset-uid (+ (var-get asset-counter) u1))
    )
    ;; Descriptor validation
    (asserts! (> (len descriptor) u0) ERROR_INVALID_DESCRIPTOR)
    (asserts! (< (len descriptor) u81) ERROR_INVALID_DESCRIPTOR)
    
    ;; Magnitude validation
    (asserts! (> magnitude u0) ERROR_INVALID_DIMENSIONS)
    (asserts! (< magnitude u2000000000) ERROR_INVALID_DIMENSIONS)
    
    ;; Summary validation
    (asserts! (> (len summary) u0) ERROR_INVALID_DESCRIPTOR)
    (asserts! (< (len summary) u257) ERROR_INVALID_DESCRIPTOR)
    
    ;; Tags validation
    (asserts! (validate-tag-collection tags) ERROR_INVALID_DESCRIPTOR)

    ;; Record asset information in system ledger
    (map-insert knowledge-vault
      { asset-uid: asset-uid }
      {
        asset-descriptor: descriptor,
        asset-creator: tx-sender,
        asset-magnitude: magnitude,
        archiving-timestamp: block-height,
        asset-summary: summary,
        asset-tags: tags
      }
    )

    ;; Configure default access permissions
    (map-insert permission-ledger
      { asset-uid: asset-uid, viewer: tx-sender }
      { viewing-rights: true }
    )
    
    ;; Increment global sequence counter
    (var-set asset-counter asset-uid)
    (ok asset-uid)
  )
)

;; UI Presentation Functions

;; Generates formatted asset details for interface display
(define-public (render-asset-details (asset-uid uint))
  (let
    (
      (asset-data (unwrap! (map-get? knowledge-vault { asset-uid: asset-uid }) ERROR_ITEM_MISSING))
    )
    ;; Return interface-friendly data structure
    (ok {
      interface-section: "Asset Details",
      asset-descriptor: (get asset-descriptor asset-data),
      asset-creator: (get asset-creator asset-data),
      asset-summary: (get asset-summary asset-data),
      asset-tags: (get asset-tags asset-data)
    })
  )
)

;; Asset Modification and Management

;; Updates existing asset metadata while preserving immutable properties
(define-public (modify-asset-record (asset-uid uint) (updated-descriptor (string-ascii 80)) (updated-magnitude uint) (updated-summary (string-ascii 256)) (updated-tags (list 8 (string-ascii 40))))
  (let
    (
      (asset-data (unwrap! (map-get? knowledge-vault { asset-uid: asset-uid }) ERROR_ITEM_MISSING))
    )
    ;; Verify asset existence and ownership
    (asserts! (asset-exists? asset-uid) ERROR_ITEM_MISSING)
    (asserts! (is-eq (get asset-creator asset-data) tx-sender) ERROR_PERMISSIONS_DENIED)
    
    ;; Validate updated descriptor
    (asserts! (> (len updated-descriptor) u0) ERROR_INVALID_DESCRIPTOR)
    (asserts! (< (len updated-descriptor) u81) ERROR_INVALID_DESCRIPTOR)
    
    ;; Validate updated magnitude
    (asserts! (> updated-magnitude u0) ERROR_INVALID_DIMENSIONS)
    (asserts! (< updated-magnitude u2000000000) ERROR_INVALID_DIMENSIONS)
    
    ;; Validate updated summary
    (asserts! (> (len updated-summary) u0) ERROR_INVALID_DESCRIPTOR)
    (asserts! (< (len updated-summary) u257) ERROR_INVALID_DESCRIPTOR)
    
    ;; Validate updated tags
    (asserts! (validate-tag-collection updated-tags) ERROR_INVALID_DESCRIPTOR)

    ;; Update asset record with new information
    (map-set knowledge-vault
      { asset-uid: asset-uid }
      (merge asset-data { 
        asset-descriptor: updated-descriptor, 
        asset-magnitude: updated-magnitude, 
        asset-summary: updated-summary, 
        asset-tags: updated-tags 
      })
    )
    (ok true)
  )
)

;; Remove asset from system catalog
(define-public (purge-asset-record (asset-uid uint))
  (let
    (
      (asset-data (unwrap! (map-get? knowledge-vault { asset-uid: asset-uid }) ERROR_ITEM_MISSING))
    )
    ;; Ensure record exists
    (asserts! (asset-exists? asset-uid) ERROR_ITEM_MISSING)
    ;; Ensure caller owns the asset
    (asserts! (is-eq (get asset-creator asset-data) tx-sender) ERROR_PERMISSIONS_DENIED)

    ;; Remove asset from catalog
    (map-delete knowledge-vault { asset-uid: asset-uid })
    (ok true)
  )
)

;; Optimized Query Functions

;; Retrieves compact asset information for bandwidth-efficient operations
(define-public (fetch-asset-overview (asset-uid uint))
  (let
    (
      (asset-data (unwrap! (map-get? knowledge-vault { asset-uid: asset-uid }) ERROR_ITEM_MISSING))
    )
    ;; Return resource-efficient data structure
    (ok {
      asset-descriptor: (get asset-descriptor asset-data),
      asset-creator: (get asset-creator asset-data),
      asset-magnitude: (get asset-magnitude asset-data)
    })
  )
)
;; This function provides minimal asset information with reduced computational overhead

;; Generates comprehensive asset representation for detailed viewing
(define-public (generate-asset-profile (asset-uid uint))
  (let
    (
      (asset-data (unwrap! (map-get? knowledge-vault { asset-uid: asset-uid }) ERROR_ITEM_MISSING))
    )
    ;; Return complete asset profile for presentation
    (ok {
      descriptor: (get asset-descriptor asset-data),
      creator: (get asset-creator asset-data),
      magnitude: (get asset-magnitude asset-data),
      summary: (get asset-summary asset-data),
      tags: (get asset-tags asset-data)
    })
  )
)

;; Ultra-lightweight asset lookup for critical system operations
(define-public (fetch-minimal-asset-data (asset-uid uint))
  (let
    (
      (asset-data (unwrap! (map-get? knowledge-vault { asset-uid: asset-uid }) ERROR_ITEM_MISSING))
    )
    ;; Return absolute minimum identification data for maximum efficiency
    (ok {
      asset-descriptor: (get asset-descriptor asset-data),
      asset-creator: (get asset-creator asset-data)
    })
  )
)
;; This high-performance function returns only essential identification fields

;; Extracts asset summary text for preview operations
(define-public (fetch-asset-summary (asset-uid uint))
  (let
    (
      (asset-data (unwrap! (map-get? knowledge-vault { asset-uid: asset-uid }) ERROR_ITEM_MISSING))
    )
    (ok (get asset-summary asset-data))
  )
)

;; Validates asset parameters without database modification
(define-public (validate-asset-parameters (descriptor (string-ascii 80)) (magnitude uint) (summary (string-ascii 256)) (tags (list 8 (string-ascii 40))))
  (begin
    ;; Validate descriptor requirements
    (asserts! (> (len descriptor) u0) ERROR_INVALID_DESCRIPTOR)
    (asserts! (< (len descriptor) u81) ERROR_INVALID_DESCRIPTOR)
    
    ;; Validate magnitude requirements
    (asserts! (> magnitude u0) ERROR_INVALID_DIMENSIONS)
    (asserts! (< magnitude u2000000000) ERROR_INVALID_DIMENSIONS)
    
    ;; Validate summary requirements
    (asserts! (> (len summary) u0) ERROR_INVALID_DESCRIPTOR)
    (asserts! (< (len summary) u257) ERROR_INVALID_DESCRIPTOR)
    
    ;; Ensure all tags conform to system requirements
    (asserts! (validate-tag-collection tags) ERROR_INVALID_DESCRIPTOR)
    
    (ok true)
  )
)

