//
//  DashboardEditorViewController.swift
//  nutribase
//
//  UIKit-based dashboard editor with drag-and-drop reordering
//

import UIKit
import SwiftUI

class DashboardEditorViewController: UIViewController {
    
    // MARK: - Properties
    
    // Collection view
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Int, CardType>!
    
    // DEBUG: Hover overlay to visualize gridPosition calculation
    private var hoverOverlay: UIView?
    
    // External API - returns flat card order (derived from slotRows)
    var cardOrder: [CardType] {
        get { DashboardGridEngine.flattenSlotRows(_slotRows) }
        set {
            // Convert flat order to slot-based rows
            _slotRows = DashboardGridEngine.buildSlotRows(from: newValue, isWeightChartExpanded: isWeightChartExpanded, isNovaGroupsCompact: isNovaGroupsCompact, isNutriScoreCompact: isNutriScoreCompact)
            rebuildPlacementsFromSlotRows()
        }
    }
    
    // SOURCE OF TRUTH: Slot-based rows with explicit left/right positions
    private var _slotRows: [DashboardSlotRow] = []
    
    // Placements derived from slotRows (cached for layout performance)
    private var placements: [CardType: GridPlacement] = [:]
    
    // Hidden cards
    var hiddenCards: [CardType] = []
    
    // Callbacks
    var onCardOrderChanged: (([CardType]) -> Void)?
    var onCardRemoved: ((CardType) -> Void)?
    var onDismiss: (() -> Void)?
    var onAddWidget: (() -> Void)?
    
    // Card view provider (for live rendering - fallback)
    var cardViewProvider: ((CardType) -> AnyView)?
    
    // Snapshot image provider (for stable editor rendering)
    var snapshotProvider: ((CardType) -> UIImage?)?
    
    // Color scheme for snapshot rendering
    var colorScheme: ColorScheme = .light
    
    // Header view provider (for scrollable header)
    var headerView: AnyView?
    var headerHeight: CGFloat = 60
    
    // Footer view provider (scrolls with content at bottom)
    var footerView: AnyView?
    var footerHeight: CGFloat = 60
    
    // Sentinel for "Add Widget" button
    static let addWidgetSentinel = CardType.empty
    
    // Section insets (top inset now comes from header height)
    private var sectionInsets: UIEdgeInsets {
        UIEdgeInsets(top: headerHeight, left: 0, bottom: footerView != nil ? 16 : 100, right: 0)
    }
    
    // Grid origin Y - matches section.contentInsets.top used in layout
    private var gridOriginY: CGFloat { sectionInsets.top }
    
    // Weight chart expanded mode
    var isWeightChartExpanded: Bool = false {
        didSet {
            if oldValue != isWeightChartExpanded && dataSource != nil {
                rebuildPlacementsFromSlotRows()
                applySnapshot(animating: true)
            }
        }
    }
    
    // NOVA Groups compact mode
    var isNovaGroupsCompact: Bool = false {
        didSet {
            if oldValue != isNovaGroupsCompact && dataSource != nil {
                rebuildPlacementsFromSlotRows()
                applySnapshot(animating: true)
            }
        }
    }
    
    // NutriScore compact mode
    var isNutriScoreCompact: Bool = false {
        didSet {
            if oldValue != isNutriScoreCompact && dataSource != nil {
                rebuildPlacementsFromSlotRows()
                applySnapshot(animating: true)
            }
        }
    }
    
    // Drag state (slotRows is source of truth)
    private var draggedCard: CardType?
    private var originalSlotRows: [DashboardSlotRow] = []  // Saved before drag
    private var isDragging: Bool = false
    private var lastHoveredRow: Int = -1   // Track to avoid redundant updates
    private var lastHoveredSlot: Int = -1  // Slot within row (0 or 1)
    
    // CADisplayLink drag tracking (bypasses drop delegate blue box)
    private var dragTrackingLink: CADisplayLink?
    private weak var activeDragSession: UIDragSession?
    
    // Auto-scroll during drag
    private var autoScrollLink: CADisplayLink?
    private var autoScrollSpeed: CGFloat = 0  // pixels per frame (positive = down, negative = up)
    private let autoScrollEdgeThreshold: CGFloat = 80  // distance from edge to trigger
    private let autoScrollMaxSpeed: CGFloat = 8  // max pixels per frame
    
    // MARK: - Lifecycle
    
    // Embedded mode (no navigation bar)
    var isEmbedded: Bool = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear  // Transparent to show gradient from parent
        
        // Extend view into safe area (under status bar)
        edgesForExtendedLayout = .all
        extendedLayoutIncludesOpaqueBars = true
        
        if !isEmbedded {
            setupNavigationBar()
        }
        setupCollectionView()
        setupDataSource()
        setupDragAndDrop() // STEP 2: Re-enabled to test gridPosition
        applySnapshot(animating: false)
    }
    
    // MARK: - Setup
    
    private func setupNavigationBar() {
        title = "Edit Dashboard"
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Done",
            style: .done,
            target: self,
            action: #selector(doneTapped)
        )
    }
    
    @objc private func doneTapped() {
        onDismiss?()
    }
    
    private func setupCollectionView() {
        let layout = makeCustomLayout()
        
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.backgroundColor = .clear
        collectionView.delegate = self
        collectionView.contentInsetAdjustmentBehavior = .never
        
        // Disable bouncing to prevent scrolling into empty space
        collectionView.alwaysBounceVertical = false
        collectionView.bounces = false
        
        // Register cell
        collectionView.register(DashboardCardCell.self, forCellWithReuseIdentifier: DashboardCardCell.reuseIdentifier)
        
        // Register header supplementary view
        collectionView.register(UICollectionReusableView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "header")
        
        // Register footer supplementary view
        collectionView.register(UICollectionReusableView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter, withReuseIdentifier: "footer")
        
        view.addSubview(collectionView)
    }
    
    private func makeCustomLayout() -> UICollectionViewCompositionalLayout {
        return UICollectionViewCompositionalLayout { [weak self] sectionIndex, environment in
            guard let self = self else { return nil }
            
            let containerWidth = environment.container.effectiveContentSize.width
            
            // Always use placements (rebuilt from cardOrder during drag)
            let activePlacements = self.placements
            
            // Get current snapshot items (in placement order)
            let items = self.dataSource?.snapshot().itemIdentifiers ?? []
            
            // Build frames using grid engine placements
            var frames: [CGRect] = []
            
            for cardType in items {
                if cardType == Self.addWidgetSentinel {
                    // Add Widget button gets placed after all cards
                    let lastRow = self.getNextAvailableRow(from: activePlacements)
                    let sentinelPlacement = GridPlacement(card: cardType, col: 0, row: lastRow, colSpan: 2, rowSpan: 1)
                    let frame = DashboardGridEngine.frame(for: sentinelPlacement, containerWidth: containerWidth)
                    frames.append(frame)
                } else if let placement = activePlacements[cardType] {
                    // Use grid engine to calculate frame from placement
                    let frame = DashboardGridEngine.frame(for: placement, containerWidth: containerWidth)
                    frames.append(frame)
                }
            }
            
            // Calculate total height
            let totalHeight = DashboardGridEngine.totalHeight(for: activePlacements) + DashboardGridEngine.cellHeight + DashboardGridEngine.spacing
            
            let groupSize = NSCollectionLayoutSize(
                widthDimension: .absolute(containerWidth),
                heightDimension: .absolute(max(totalHeight, 100))
            )
            
            let group = NSCollectionLayoutGroup.custom(layoutSize: groupSize) { _ in
                return frames.enumerated().map { index, frame in
                    NSCollectionLayoutGroupCustomItem(frame: frame)
                }
            }
            
            let section = NSCollectionLayoutSection(group: group)
            section.contentInsets = NSDirectionalEdgeInsets(
                top: self.headerView != nil ? 0 : self.sectionInsets.top,
                leading: 0,
                bottom: self.sectionInsets.bottom,
                trailing: 0
            )
            
            // Add header and/or footer if provided
            var supplementaryItems: [NSCollectionLayoutBoundarySupplementaryItem] = []
            
            if self.headerView != nil {
                let headerSize = NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1.0),
                    heightDimension: .absolute(self.headerHeight)
                )
                let header = NSCollectionLayoutBoundarySupplementaryItem(
                    layoutSize: headerSize,
                    elementKind: UICollectionView.elementKindSectionHeader,
                    alignment: .top
                )
                supplementaryItems.append(header)
            }
            
            if self.footerView != nil {
                let footerSize = NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1.0),
                    heightDimension: .absolute(self.footerHeight)
                )
                let footer = NSCollectionLayoutBoundarySupplementaryItem(
                    layoutSize: footerSize,
                    elementKind: UICollectionView.elementKindSectionFooter,
                    alignment: .bottom
                )
                supplementaryItems.append(footer)
            }
            
            if !supplementaryItems.isEmpty {
                section.boundarySupplementaryItems = supplementaryItems
            }
            
            return section
        }
    }
    
    // MARK: - Grid Placement Helpers
    
    /// Returns the next available row after all placements
    private func getNextAvailableRow(from placementsToCheck: [CardType: GridPlacement]? = nil) -> Int {
        let checkPlacements = placementsToCheck ?? placements
        guard !checkPlacements.isEmpty else { return 0 }
        
        var maxRowEnd = 0
        for placement in checkPlacements.values {
            let rowEnd = placement.row + placement.rowSpan
            if rowEnd > maxRowEnd {
                maxRowEnd = rowEnd
            }
        }
        return maxRowEnd
    }
    
    // STEP 8: Hover detection returns LOGICAL row AND slot (0 or 1)
    // NOTE: session.location(in: collectionView) returns CONTENT coordinates (already scrolled)
    // Uses originalSlotRows to match reorderCard's row structure
    // Converts visual row (affected by tall cards) to logical row (slotRows index)
    private func hoveredPosition(for location: CGPoint) -> (row: Int, slot: Int) {
        // location.y is already in content coords - DON'T add contentOffset
        let gridY = location.y - gridOriginY
        let rowHeight = DashboardGridEngine.cellHeight + DashboardGridEngine.spacing
        let visualRow = max(0, Int(gridY / rowHeight))
        
        // Use originalSlotRows for consistent row indexing with reorderCard
        let slotRows = originalSlotRows.isEmpty ? _slotRows : originalSlotRows
        
        // Convert visual row to logical row (accounting for tall cards)
        var logicalRow = 0
        var currentVisualRow = 0
        for (idx, slotRow) in slotRows.enumerated() {
            // Get the max rowSpan for this logical row
            let maxRowSpan = slotRow.cards.map { card in
                DashboardGridEngine.size(of: card, isWeightChartExpanded: isWeightChartExpanded, isNovaGroupsCompact: isNovaGroupsCompact, isNutriScoreCompact: isNutriScoreCompact).rowSpan
            }.max() ?? 1
            
            if visualRow < currentVisualRow + maxRowSpan {
                logicalRow = idx
                break
            }
            currentVisualRow += maxRowSpan
            logicalRow = idx + 1
        }
        logicalRow = min(logicalRow, slotRows.count)
        
        // Slot: 0 = left half, 1 = right half
        let midX = collectionView.bounds.width / 2
        let slot = location.x < midX ? 0 : 1
        
        return (logicalRow, slot)
    }
    
    // STEP 9: Swap-based reorder using SLOT-BASED ROWS
    // When displacing a card, it goes to where the dragged card came from (true swap)
    private func reorderCard(_ card: CardType, toRow targetRow: Int, slot: Int) {
        // Work with a copy of original slot rows (preserves structure during drag)
        var slotRows = originalSlotRows
        
        // Check if dragged card is wide
        let draggedSize = DashboardGridEngine.size(of: card, isWeightChartExpanded: isWeightChartExpanded, isNovaGroupsCompact: isNovaGroupsCompact, isNutriScoreCompact: isNutriScoreCompact)
        let isWideCard = draggedSize.colSpan == 2
        
        // === STEP 1: Find and remember original position ===
        var originalRow = -1
        var originalSlot = -1
        for rowIdx in 0..<slotRows.count {
            if slotRows[rowIdx].left == card {
                originalRow = rowIdx
                originalSlot = 0
                break
            } else if slotRows[rowIdx].right == card {
                originalRow = rowIdx
                originalSlot = 1
                break
            }
        }
        
        // === STEP 2: Handle based on target ===
        let clampedRow = min(targetRow, slotRows.count)
        
        // Same position as original - restore to original state
        if clampedRow == originalRow && slot == originalSlot {
            _slotRows = originalSlotRows
            rebuildPlacementsFromSlotRows()
            return
        }
        
        if isWideCard {
            // Wide cards: remove from original, insert as own row
            if originalSlot == 0 {
                slotRows[originalRow].left = nil
            } else {
                slotRows[originalRow].right = nil
            }
            slotRows.removeAll { $0.isEmpty }
            let insertRow = min(targetRow, slotRows.count)
            slotRows.insert(.wide(card), at: insertRow)
        } else if clampedRow >= slotRows.count {
            // Inserting past end - remove from original, append new row
            if originalSlot == 0 {
                slotRows[originalRow].left = nil
            } else {
                slotRows[originalRow].right = nil
            }
            slotRows.removeAll { $0.isEmpty }
            if slot == 0 {
                slotRows.append(.leftOnly(card))
            } else {
                slotRows.append(.rightOnly(card))
            }
        } else {
            // Inserting into existing row
            let targetSlotRow = slotRows[clampedRow]
            
            if targetSlotRow.isWideCard {
                // Can't insert into wide card's row - insert above it
                if originalSlot == 0 {
                    slotRows[originalRow].left = nil
                } else {
                    slotRows[originalRow].right = nil
                }
                slotRows.removeAll { $0.isEmpty }
                let insertRow = min(targetRow, slotRows.count)
                if slot == 0 {
                    slotRows.insert(.leftOnly(card), at: insertRow)
                } else {
                    slotRows.insert(.rightOnly(card), at: insertRow)
                }
            } else {
                // Small card inserting into small card row - TRUE SWAP
                let targetCard: CardType? = slot == 0 ? targetSlotRow.left : targetSlotRow.right
                
                // Place dragged card at target
                if slot == 0 {
                    slotRows[clampedRow].left = card
                } else {
                    slotRows[clampedRow].right = card
                }
                
                // Place displaced card (if any) at original position
                if let displaced = targetCard {
                    if originalSlot == 0 {
                        slotRows[originalRow].left = displaced
                    } else {
                        slotRows[originalRow].right = displaced
                    }
                } else {
                    // No displaced card - just clear original position
                    if originalSlot == 0 {
                        slotRows[originalRow].left = nil
                    } else {
                        slotRows[originalRow].right = nil
                    }
                }
            }
        }
        
        // === STEP 3: COLLAPSE any rows that became empty ===
        slotRows.removeAll { $0.isEmpty }
        
        // Update source of truth
        _slotRows = slotRows
        
        // Rebuild placements from slot rows
        rebuildPlacementsFromSlotRows()
    }
    
    /// Cascades a displaced card down to the next available slot
    private func cascadeSlotCard(_ card: CardType, startingAfterRow: Int, in slotRows: inout [DashboardSlotRow]) {
        let nextRow = startingAfterRow + 1
        
        if nextRow >= slotRows.count {
            // No more rows - append new row with card in left slot
            slotRows.append(.leftOnly(card))
            return
        }
        
        let nextSlotRow = slotRows[nextRow]
        
        if nextSlotRow.isWideCard {
            // Can't merge with wide card - insert new row before it
            slotRows.insert(.leftOnly(card), at: nextRow)
        } else if nextSlotRow.left == nil {
            // Left slot available
            slotRows[nextRow].left = card
        } else if nextSlotRow.right == nil {
            // Right slot available
            slotRows[nextRow].right = card
        } else {
            // Row is full - cascade further (displace left card)
            let displaced = nextSlotRow.left!
            slotRows[nextRow].left = card
            cascadeSlotCard(displaced, startingAfterRow: nextRow, in: &slotRows)
        }
    }
    
    /// Rebuilds placements from slot-based rows
    private func rebuildPlacementsFromSlotRows() {
        placements = DashboardGridEngine.buildPlacements(
            from: _slotRows,
            isWeightChartExpanded: isWeightChartExpanded,
            isNovaGroupsCompact: isNovaGroupsCompact,
            isNutriScoreCompact: isNutriScoreCompact,
            hiddenCards: Set(hiddenCards)
        )
    }
    
    /// Rebuilds placements directly from row structure (preserves intended row boundaries)
    private func rebuildPlacementsFromRows(_ rows: [DashboardRow]) {
        placements.removeAll()
        
        var currentRow = 0
        for row in rows {
            var col = 0
            for card in row.cards {
                // Skip hidden cards
                if hiddenCards.contains(card) { continue }
                
                let (colSpan, rowSpan) = DashboardGridEngine.size(of: card, isWeightChartExpanded: isWeightChartExpanded, isNovaGroupsCompact: isNovaGroupsCompact, isNutriScoreCompact: isNutriScoreCompact)
                placements[card] = GridPlacement(card: card, col: col, row: currentRow, colSpan: colSpan, rowSpan: rowSpan)
                col += colSpan
            }
            // Move to next row (account for tall cards)
            let maxRowSpan = row.cards.compactMap { placements[$0]?.rowSpan }.max() ?? 1
            currentRow += maxRowSpan
        }
    }
    
    // Overlay shows specific slot position
    // row parameter is LOGICAL row (buildRows index), convert to visual row for Y position
    private func showSlotOverlay(at row: Int, slot: Int) {
        hoverOverlay?.removeFromSuperview()
        
        let containerWidth = collectionView.bounds.width
        let cellWidth = (containerWidth - DashboardGridEngine.horizontalPadding * 2 - DashboardGridEngine.spacing) / 2
        let cellHeight = DashboardGridEngine.cellHeight
        let spacing = DashboardGridEngine.spacing
        
        // Check if dragged card is wide/tall
        let draggedSize = draggedCard.map { DashboardGridEngine.size(of: $0, isWeightChartExpanded: isWeightChartExpanded, isNovaGroupsCompact: isNovaGroupsCompact, isNutriScoreCompact: isNutriScoreCompact) }
        let isWide = draggedSize?.colSpan == 2
        let draggedRowSpan = draggedSize?.rowSpan ?? 1
        
        let x: CGFloat
        let width: CGFloat
        
        if isWide {
            // Wide card - full width overlay
            x = DashboardGridEngine.horizontalPadding
            width = containerWidth - DashboardGridEngine.horizontalPadding * 2
        } else {
            // Small card - slot-specific overlay
            x = DashboardGridEngine.horizontalPadding + CGFloat(slot) * (cellWidth + spacing)
            width = cellWidth
        }
        
        // Convert logical row to visual row (accounting for tall cards)
        let slotRows = originalSlotRows.isEmpty ? _slotRows : originalSlotRows
        var visualRow = 0
        for idx in 0..<min(row, slotRows.count) {
            let maxRowSpan = slotRows[idx].cards.map { card in
                DashboardGridEngine.size(of: card, isWeightChartExpanded: isWeightChartExpanded, isNovaGroupsCompact: isNovaGroupsCompact, isNutriScoreCompact: isNutriScoreCompact).rowSpan
            }.max() ?? 1
            visualRow += maxRowSpan
        }
        
        let y = gridOriginY + CGFloat(visualRow) * (cellHeight + spacing)
        let height = CGFloat(draggedRowSpan) * cellHeight + CGFloat(draggedRowSpan - 1) * spacing
        
        let overlay = UIView(frame: CGRect(x: x, y: y, width: width, height: height))
        overlay.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.2)
        overlay.layer.cornerRadius = 16
        overlay.layer.borderWidth = 2
        overlay.layer.borderColor = UIColor.systemBlue.cgColor
        overlay.isUserInteractionEnabled = false
        
        collectionView.addSubview(overlay)
        hoverOverlay = overlay
    }
    
    /// DEBUG: Hides the hover overlay
    private func hideHoverOverlay() {
        hoverOverlay?.removeFromSuperview()
        hoverOverlay = nil
    }
    
    private func setupDataSource() {
        dataSource = UICollectionViewDiffableDataSource<Int, CardType>(collectionView: collectionView) { [weak self] collectionView, indexPath, cardType in
            guard let self = self,
                  let cell = collectionView.dequeueReusableCell(withReuseIdentifier: DashboardCardCell.reuseIdentifier, for: indexPath) as? DashboardCardCell else {
                return UICollectionViewCell()
            }
            
            if cardType == Self.addWidgetSentinel {
                // Add widget button - styled to match Food Log's Add Section button
                let addView = AnyView(
                    Button(action: { [weak self] in
                        self?.onAddWidget?()
                    }) {
                        VStack {
                            Image(systemName: "plus.circle.fill")
                                .font(.largeTitle)
                                .foregroundColor(.blue)
                            Text("Add Widget")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [5]))
                                .foregroundColor(.blue.opacity(0.5))
                        )
                    }
                    .buttonStyle(.plain)
                )
                cell.configure(with: addView, showRemoveButton: false)
            } else {
                // Regular card - use snapshot image for stable rendering
                if let snapshotProvider = self.snapshotProvider,
                   let snapshot = snapshotProvider(cardType) {
                    // Use pre-rendered snapshot (stable, no SwiftUI layout)
                    cell.configure(with: snapshot, showRemoveButton: true)
                } else if let provider = self.cardViewProvider {
                    // Fallback to live SwiftUI (legacy path)
                    let size = DashboardGridEngine.size(of: cardType, isWeightChartExpanded: self.isWeightChartExpanded, isNovaGroupsCompact: self.isNovaGroupsCompact, isNutriScoreCompact: self.isNutriScoreCompact)
                    let height = CGFloat(size.rowSpan) * DashboardGridEngine.cellHeight +
                                 CGFloat(max(0, size.rowSpan - 1)) * DashboardGridEngine.spacing
                    
                    let wrapped = AnyView(
                        provider(cardType)
                            .transaction { $0.animation = nil }
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                            .frame(height: height)
                    )
                    cell.configure(with: wrapped, showRemoveButton: true)
                }
                cell.setInteractionEnabled(false)  // Disable taps in edit mode
                cell.onRemove = { [weak self] in
                    self?.removeCard(cardType)
                }
            }
            
            return cell
        }
        
        // Configure supplementary views (header + footer)
        dataSource.supplementaryViewProvider = { [weak self] collectionView, kind, indexPath in
            guard let self = self else { return nil }
            
            if kind == UICollectionView.elementKindSectionHeader, let headerContent = self.headerView {
                let headerView = collectionView.dequeueReusableSupplementaryView(
                    ofKind: kind,
                    withReuseIdentifier: "header",
                    for: indexPath
                )
                headerView.backgroundColor = .clear
                headerView.subviews.forEach { $0.removeFromSuperview() }
                
                let hostingController = UIHostingController(rootView: headerContent)
                hostingController.view.backgroundColor = .clear
                hostingController.view.isOpaque = false
                hostingController.view.frame = headerView.bounds
                hostingController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                headerView.addSubview(hostingController.view)
                
                return headerView
            }
            
            if kind == UICollectionView.elementKindSectionFooter, let footerContent = self.footerView {
                let footerView = collectionView.dequeueReusableSupplementaryView(
                    ofKind: kind,
                    withReuseIdentifier: "footer",
                    for: indexPath
                )
                footerView.backgroundColor = .clear
                footerView.subviews.forEach { $0.removeFromSuperview() }
                
                let hostingController = UIHostingController(rootView: footerContent)
                hostingController.view.backgroundColor = .clear
                hostingController.view.isOpaque = false
                hostingController.view.frame = footerView.bounds
                hostingController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                footerView.addSubview(hostingController.view)
                
                return footerView
            }
            
            return nil
        }
    }
    
    // MARK: - Snapshot Management
    
    private func applySnapshot(animating: Bool = true) {
        var snapshot = NSDiffableDataSourceSnapshot<Int, CardType>()
        snapshot.appendSections([0])
        
        // Get cards in placement order (sorted by row, then col)
        let sortedCards = DashboardGridEngine.sortedPlacements(placements).map { $0.card }
        
        // Add cards + add widget sentinel
        var items = sortedCards
        items.append(Self.addWidgetSentinel)
        snapshot.appendItems(items)
        
        // Let diffable data source handle its own animations - no outer UIView.animate
        dataSource.apply(snapshot, animatingDifferences: animating) { [weak self] in
            self?.collectionView.collectionViewLayout.invalidateLayout()
        }
    }
    
    // MARK: - Drag and Drop
    
    private func setupDragAndDrop() {
        collectionView.dragInteractionEnabled = true
        collectionView.dragDelegate = self
        collectionView.dropDelegate = self
    }
    
    // MARK: - Actions
    
    private func removeCard(_ cardType: CardType) {
        guard placements[cardType] != nil else { return }
        
        // Remove card from slot rows
        for rowIdx in 0..<_slotRows.count {
            if _slotRows[rowIdx].left == cardType {
                _slotRows[rowIdx].left = nil
                break
            } else if _slotRows[rowIdx].right == cardType {
                _slotRows[rowIdx].right = nil
                break
            }
        }
        // Collapse empty rows
        _slotRows.removeAll { $0.isEmpty }
        rebuildPlacementsFromSlotRows()
        
        onCardRemoved?(cardType)
        applySnapshot()
        onCardOrderChanged?(cardOrder)
    }
    
    func addCard(_ cardType: CardType) {
        guard placements[cardType] == nil else { return }
        
        // Check if card is wide
        let cardSize = DashboardGridEngine.size(of: cardType, isWeightChartExpanded: isWeightChartExpanded, isNovaGroupsCompact: isNovaGroupsCompact, isNutriScoreCompact: isNutriScoreCompact)
        let isWide = cardSize.colSpan == 2
        
        if isWide {
            // Wide cards get their own row at the end
            _slotRows.append(.wide(cardType))
        } else {
            // Try to find a row with an empty slot, otherwise create new row
            var added = false
            for rowIdx in 0..<_slotRows.count {
                if !_slotRows[rowIdx].isWideCard {
                    if _slotRows[rowIdx].left == nil {
                        _slotRows[rowIdx].left = cardType
                        added = true
                        break
                    } else if _slotRows[rowIdx].right == nil {
                        _slotRows[rowIdx].right = cardType
                        added = true
                        break
                    }
                }
            }
            if !added {
                _slotRows.append(.leftOnly(cardType))
            }
        }
        rebuildPlacementsFromSlotRows()
        
        applySnapshot()
        onCardOrderChanged?(cardOrder)
    }
    
    /// Sets card order and reloads the snapshot - use when order changes externally
    func setCardOrderAndReload(_ newOrder: [CardType], animated: Bool = false) {
        // Deduplicate and convert to slot rows
        let deduplicated = deduplicateCards(newOrder)
        _slotRows = DashboardGridEngine.buildSlotRows(from: deduplicated, isWeightChartExpanded: isWeightChartExpanded, isNovaGroupsCompact: isNovaGroupsCompact, isNutriScoreCompact: isNutriScoreCompact)
        rebuildPlacementsFromSlotRows()
        applySnapshot(animating: animated)
    }
    
    /// Initialize placements if empty (called when cardOrder is set externally before view loads)
    func initializePlacementsIfNeeded(from cards: [CardType]) {
        if placements.isEmpty && !cards.isEmpty {
            // Deduplicate and convert to slot rows
            let deduplicated = deduplicateCards(cards)
            _slotRows = DashboardGridEngine.buildSlotRows(from: deduplicated, isWeightChartExpanded: isWeightChartExpanded, isNovaGroupsCompact: isNovaGroupsCompact, isNutriScoreCompact: isNutriScoreCompact)
            rebuildPlacementsFromSlotRows()
        }
    }
    
    /// Helper to remove duplicate card types (keeps first occurrence)
    private func deduplicateCards(_ cards: [CardType]) -> [CardType] {
        var seen = Set<CardType>()
        return cards.filter { card in
            if seen.contains(card) { return false }
            seen.insert(card)
            return true
        }
    }
}

// MARK: - UICollectionViewDelegate

extension DashboardEditorViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
    }
}

// MARK: - UICollectionViewDragDelegate

extension DashboardEditorViewController: UICollectionViewDragDelegate {
    func collectionView(_ collectionView: UICollectionView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        guard let cardType = dataSource.itemIdentifier(for: indexPath),
              cardType != Self.addWidgetSentinel else {
            return []
        }
        
        // Save original slotRows before drag
        originalSlotRows = _slotRows
        draggedCard = cardType
        isDragging = true
        lastHoveredRow = -1
        lastHoveredSlot = -1
        
        // Haptic feedback on drag start
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        let itemProvider = NSItemProvider(object: cardType.rawValue as NSString)
        let dragItem = UIDragItem(itemProvider: itemProvider)
        dragItem.localObject = cardType
        
        // Hide chrome on dragged cell
        if let cell = collectionView.cellForItem(at: indexPath) as? DashboardCardCell {
            cell.setEditingChromeHidden(true)
        }
        
        return [dragItem]
    }
    
    func collectionView(_ collectionView: UICollectionView, dragPreviewParametersForItemAt indexPath: IndexPath) -> UIDragPreviewParameters? {
        guard let cell = collectionView.cellForItem(at: indexPath) else { return nil }
        
        let parameters = UIDragPreviewParameters()
        parameters.backgroundColor = .clear
        
        let previewRect = cell.contentView.bounds
        parameters.visiblePath = UIBezierPath(roundedRect: previewRect, cornerRadius: 16)
        
        return parameters
    }
    
    func collectionView(_ collectionView: UICollectionView, dragSessionWillBegin session: UIDragSession) {
        // Disable manual scrolling during drag but allow programmatic auto-scroll
        collectionView.isScrollEnabled = false
        
        // Start a display link to track drag position (bypasses drop delegate)
        startDragTracking(session: session)
        
        // Start auto-scroll display link for edge-based scrolling
        startAutoScroll()
    }
    
    func collectionView(_ collectionView: UICollectionView, dragSessionDidEnd session: UIDragSession) {
        // Stop tracking
        stopDragTracking()
        stopAutoScroll()
        
        // Re-enable scrolling after drag
        collectionView.isScrollEnabled = true
        
        // Hide hover overlay
        hideHoverOverlay()
        
        // Commit the current cardOrder
        if draggedCard != nil {
            applySnapshot(animating: true)
            onCardOrderChanged?(cardOrder)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        
        // Clear drag state
        isDragging = false
        draggedCard = nil
        originalSlotRows = []
        lastHoveredRow = -1
        lastHoveredSlot = -1
        
        // Show remove buttons on regular cards (not Add Widget)
        for indexPath in collectionView.indexPathsForVisibleItems {
            guard let cardType = dataSource.itemIdentifier(for: indexPath),
                  cardType != Self.addWidgetSentinel,
                  let cell = collectionView.cellForItem(at: indexPath) as? DashboardCardCell else {
                continue
            }
            cell.setEditingChromeHidden(false)
        }
    }
    
    // MARK: - Drag Tracking (bypasses drop delegate blue box)
    
    private func startDragTracking(session: UIDragSession) {
        activeDragSession = session
        dragTrackingLink = CADisplayLink(target: self, selector: #selector(trackDragPosition))
        dragTrackingLink?.add(to: .main, forMode: .common)
    }
    
    private func stopDragTracking() {
        dragTrackingLink?.invalidate()
        dragTrackingLink = nil
        activeDragSession = nil
    }
    
    @objc private func trackDragPosition() {
        guard let session = activeDragSession,
              let draggedCard = draggedCard else { return }
        
        // Get position in VIEW coordinates for edge detection
        let viewLocation = session.location(in: collectionView.superview ?? view)
        updateAutoScrollSpeed(for: viewLocation)
        
        let location = session.location(in: collectionView)
        let (targetRow, targetSlot) = hoveredPosition(for: location)
        
        // Only update if position changed
        guard lastHoveredRow != targetRow || lastHoveredSlot != targetSlot else { return }
        
        lastHoveredRow = targetRow
        lastHoveredSlot = targetSlot
        
        // Show our custom overlay
        showSlotOverlay(at: targetRow, slot: targetSlot)
        
        // Reorder cards (updates slotRows and placements)
        reorderCard(draggedCard, toRow: targetRow, slot: targetSlot)
        
        // During drag, invalidate layout WITHOUT animation to prevent
        // SwiftUI content from re-laying out in visible cells
        UIView.performWithoutAnimation {
            collectionView.collectionViewLayout.invalidateLayout()
            collectionView.layoutIfNeeded()
        }
    }
    
    // MARK: - Auto-scroll during drag
    
    private func startAutoScroll() {
        autoScrollSpeed = 0
        autoScrollLink = CADisplayLink(target: self, selector: #selector(performAutoScroll))
        autoScrollLink?.add(to: .main, forMode: .common)
    }
    
    private func stopAutoScroll() {
        autoScrollLink?.invalidate()
        autoScrollLink = nil
        autoScrollSpeed = 0
    }
    
    /// Calculate scroll speed based on finger proximity to top/bottom edges
    private func updateAutoScrollSpeed(for viewLocation: CGPoint) {
        let visibleHeight = collectionView.bounds.height
        let topEdge = collectionView.safeAreaInsets.top + autoScrollEdgeThreshold
        let bottomEdge = visibleHeight - collectionView.safeAreaInsets.bottom - autoScrollEdgeThreshold
        
        if viewLocation.y < topEdge {
            // Near top edge - scroll up (negative)
            let proximity = max(0, topEdge - viewLocation.y) / autoScrollEdgeThreshold
            autoScrollSpeed = -autoScrollMaxSpeed * proximity
        } else if viewLocation.y > bottomEdge {
            // Near bottom edge - scroll down (positive)
            let proximity = max(0, viewLocation.y - bottomEdge) / autoScrollEdgeThreshold
            autoScrollSpeed = autoScrollMaxSpeed * proximity
        } else {
            autoScrollSpeed = 0
        }
    }
    
    @objc private func performAutoScroll() {
        guard abs(autoScrollSpeed) > 0.5 else { return }
        
        let currentOffset = collectionView.contentOffset.y
        let maxOffset = max(0, collectionView.contentSize.height - collectionView.bounds.height + collectionView.contentInset.bottom)
        let minOffset: CGFloat = -collectionView.contentInset.top
        
        let newOffset = min(max(currentOffset + autoScrollSpeed, minOffset), maxOffset)
        
        guard newOffset != currentOffset else { return }
        
        collectionView.contentOffset.y = newOffset
    }
}

// MARK: - UICollectionViewDropDelegate (minimal - just to allow drop)

extension DashboardEditorViewController: UICollectionViewDropDelegate {
    
    func collectionView(_ collectionView: UICollectionView, canHandle session: UIDropSession) -> Bool {
        // Allow local drags only
        session.localDragSession != nil
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        dropSessionDidUpdate session: UIDropSession,
                        withDestinationIndexPath destinationIndexPath: IndexPath?) -> UICollectionViewDropProposal {
        // Return .cancel to completely disable UIKit's drop indicator
        // We handle everything via CADisplayLink in drag delegate
        return UICollectionViewDropProposal(operation: .cancel)
    }
    
    func collectionView(_ collectionView: UICollectionView, performDropWith coordinator: UICollectionViewDropCoordinator) {
        // No-op - we commit in dragSessionDidEnd instead
    }
}
