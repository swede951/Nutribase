//
//  DashboardGridEngine.swift
//  nutribase
//
//  Grid-based layout engine for dashboard cards
//  Uses explicit placements instead of flow layout to avoid drag/drop ambiguity
//

import Foundation
import UIKit

// MARK: - Grid Placement Model

struct GridPlacement: Hashable, Codable {
    let card: CardType
    var col: Int      // 0 or 1
    var row: Int      // 0, 1, 2, ...
    var colSpan: Int  // 1 or 2
    var rowSpan: Int  // 1, 2, or 3
    
    // Computed property: cells occupied by this placement
    var occupiedCells: [(row: Int, col: Int)] {
        var cells: [(Int, Int)] = []
        for r in row..<(row + rowSpan) {
            for c in col..<(col + colSpan) {
                cells.append((r, c))
            }
        }
        return cells
    }
}

// MARK: - Dashboard Row Model (Legacy - for buildRows compatibility)

/// A row in the dashboard grid - contains 1 or 2 cards
/// Wide cards consume the entire row, small cards pair up
/// Named DashboardRow to avoid conflict with SwiftUI's GridRow
struct DashboardRow {
    var cards: [CardType]  // 1 or 2 cards max
    
    var isWide: Bool {
        cards.count == 1 && cards.first.map { DashboardGridEngine.size(of: $0).colSpan == 2 } ?? false
    }
}

// MARK: - Slot-Based Row Model (Option B - Source of Truth)

/// A row with explicit left/right slots - preserves intentional gaps
/// This is the TRUE source of truth for card positions
struct DashboardSlotRow: Codable, Equatable {
    var left: CardType?      // Slot 0
    var right: CardType?     // Slot 1
    var isWideCard: Bool     // If true, left spans both columns, right must be nil
    
    init(left: CardType? = nil, right: CardType? = nil, isWideCard: Bool = false) {
        self.left = left
        self.right = isWideCard ? nil : right  // Wide cards can't have right slot
        self.isWideCard = isWideCard
    }
    
    /// Create from a wide card
    static func wide(_ card: CardType) -> DashboardSlotRow {
        DashboardSlotRow(left: card, right: nil, isWideCard: true)
    }
    
    /// Create from one small card (left slot)
    static func leftOnly(_ card: CardType) -> DashboardSlotRow {
        DashboardSlotRow(left: card, right: nil, isWideCard: false)
    }
    
    /// Create from one small card (right slot) - intentional gap on left
    static func rightOnly(_ card: CardType) -> DashboardSlotRow {
        DashboardSlotRow(left: nil, right: card, isWideCard: false)
    }
    
    /// Create from two small cards
    static func pair(_ leftCard: CardType, _ rightCard: CardType) -> DashboardSlotRow {
        DashboardSlotRow(left: leftCard, right: rightCard, isWideCard: false)
    }
    
    /// Returns true if row is completely empty
    var isEmpty: Bool {
        left == nil && right == nil
    }
    
    /// Returns true if row has an available slot
    var hasEmptySlot: Bool {
        !isWideCard && (left == nil || right == nil)
    }
    
    /// Returns all cards in this row (for flat list conversion)
    var cards: [CardType] {
        var result: [CardType] = []
        if let l = left { result.append(l) }
        if let r = right { result.append(r) }
        return result
    }
    
    /// Returns the slot (0 or 1) for a given card, or nil if not in row
    func slot(of card: CardType) -> Int? {
        if left == card { return 0 }
        if right == card { return 1 }
        return nil
    }
}

// MARK: - Dashboard Grid Engine

class DashboardGridEngine {
    
    // MARK: - Constants
    
    static let columnCount = 2
    static let cellHeight: CGFloat = 150  // Base cell height (matches FixedSizeCard)
    static let spacing: CGFloat = 16
    static let horizontalPadding: CGFloat = 16
    
    // MARK: - Card Size Definition
    
    /// Returns the grid size (colSpan, rowSpan) for a given card type
    /// This is the single source of truth for card dimensions
    static func size(of card: CardType, isWeightChartExpanded: Bool = false, isNovaGroupsCompact: Bool = false, isNutriScoreCompact: Bool = false) -> (colSpan: Int, rowSpan: Int) {
        switch card {
        case .weightChart:
            return isWeightChartExpanded ? (2, 3) : (1, 1)
        case .novaGroups:
            return isNovaGroupsCompact ? (1, 1) : (2, 1)
        case .nutriScore:
            return isNutriScoreCompact ? (1, 1) : (2, 1)
        case .dailyGoals, .gutHealth:
            return (2, 1)  // Wide cards
        case .currentWeight, .calorieTarget, .protein, .carbs, .fat, .fibre, .activity:
            return (1, 1)  // Small cards
        case .empty:
            return (1, 1)
        }
    }
    
    // MARK: - Row Building (STEP 1)
    
    /// Builds rows from a linear card order
    /// Rules:
    /// - A row has max 2 slots
    /// - A wide card consumes the whole row
    /// - A small card consumes 1 slot
    static func buildRows(from cards: [CardType], isWeightChartExpanded: Bool = false, isNovaGroupsCompact: Bool = false, isNutriScoreCompact: Bool = false) -> [DashboardRow] {
        var rows: [DashboardRow] = []
        var currentRow: [CardType] = []
        
        for card in cards {
            let cardSize = size(of: card, isWeightChartExpanded: isWeightChartExpanded, isNovaGroupsCompact: isNovaGroupsCompact, isNutriScoreCompact: isNutriScoreCompact)
            
            if cardSize.colSpan == 2 {
                // Wide card - flush existing row first
                if !currentRow.isEmpty {
                    rows.append(DashboardRow(cards: currentRow))
                    currentRow = []
                }
                rows.append(DashboardRow(cards: [card]))
            } else {
                // Small card - add to current row
                currentRow.append(card)
                if currentRow.count == 2 {
                    rows.append(DashboardRow(cards: currentRow))
                    currentRow = []
                }
            }
        }
        
        // Flush any remaining cards
        if !currentRow.isEmpty {
            rows.append(DashboardRow(cards: currentRow))
        }
        
        return rows
    }
    
    /// Debug print rows
    static func debugPrintRows(_ rows: [DashboardRow]) {
        print("📊 Grid Rows (\(rows.count) rows):")
        for (i, row) in rows.enumerated() {
            let cardNames = row.cards.map { $0.rawValue }.joined(separator: ", ")
            let type = row.isWide ? "WIDE" : (row.cards.count == 2 ? "PAIR" : "SINGLE")
            print("   Row \(i): [\(cardNames)] (\(type))")
        }
    }
    
    // MARK: - Slot-Based Row Helpers
    
    /// Build slot-based rows from a flat card order (initial conversion)
    static func buildSlotRows(from cards: [CardType], isWeightChartExpanded: Bool = false, isNovaGroupsCompact: Bool = false, isNutriScoreCompact: Bool = false) -> [DashboardSlotRow] {
        var slotRows: [DashboardSlotRow] = []
        var pendingSmallCard: CardType? = nil
        
        for card in cards {
            let cardSize = size(of: card, isWeightChartExpanded: isWeightChartExpanded, isNovaGroupsCompact: isNovaGroupsCompact, isNutriScoreCompact: isNutriScoreCompact)
            
            if cardSize.colSpan == 2 {
                // Wide card - flush pending first
                if let pending = pendingSmallCard {
                    slotRows.append(.leftOnly(pending))
                    pendingSmallCard = nil
                }
                slotRows.append(.wide(card))
            } else {
                // Small card
                if let pending = pendingSmallCard {
                    slotRows.append(.pair(pending, card))
                    pendingSmallCard = nil
                } else {
                    pendingSmallCard = card
                }
            }
        }
        
        // Flush any remaining small card
        if let pending = pendingSmallCard {
            slotRows.append(.leftOnly(pending))
        }
        
        return slotRows
    }
    
    /// Convert slot-based rows to flat card order
    static func flattenSlotRows(_ slotRows: [DashboardSlotRow]) -> [CardType] {
        return slotRows.flatMap { $0.cards }
    }
    
    /// Build placements directly from slot-based rows
    static func buildPlacements(from slotRows: [DashboardSlotRow], isWeightChartExpanded: Bool = false, isNovaGroupsCompact: Bool = false, isNutriScoreCompact: Bool = false, hiddenCards: Set<CardType> = []) -> [CardType: GridPlacement] {
        var placements: [CardType: GridPlacement] = [:]
        var visualRow = 0
        
        for slotRow in slotRows {
            if slotRow.isWideCard, let card = slotRow.left {
                // Wide card - skip if hidden
                if !hiddenCards.contains(card) {
                    let (colSpan, rowSpan) = size(of: card, isWeightChartExpanded: isWeightChartExpanded, isNovaGroupsCompact: isNovaGroupsCompact, isNutriScoreCompact: isNutriScoreCompact)
                    placements[card] = GridPlacement(card: card, col: 0, row: visualRow, colSpan: colSpan, rowSpan: rowSpan)
                    visualRow += rowSpan
                }
            } else {
                // Small cards row
                var rowUsed = false
                
                if let leftCard = slotRow.left, !hiddenCards.contains(leftCard) {
                    let (colSpan, rowSpan) = size(of: leftCard, isWeightChartExpanded: isWeightChartExpanded, isNovaGroupsCompact: isNovaGroupsCompact, isNutriScoreCompact: isNutriScoreCompact)
                    placements[leftCard] = GridPlacement(card: leftCard, col: 0, row: visualRow, colSpan: colSpan, rowSpan: rowSpan)
                    rowUsed = true
                }
                
                if let rightCard = slotRow.right, !hiddenCards.contains(rightCard) {
                    let (colSpan, rowSpan) = size(of: rightCard, isWeightChartExpanded: isWeightChartExpanded, isNovaGroupsCompact: isNovaGroupsCompact, isNutriScoreCompact: isNutriScoreCompact)
                    placements[rightCard] = GridPlacement(card: rightCard, col: 1, row: visualRow, colSpan: colSpan, rowSpan: rowSpan)
                    rowUsed = true
                }
                
                if rowUsed {
                    visualRow += 1
                }
            }
        }
        
        return placements
    }
    
    /// Find a card's position in slot-based rows
    static func findCard(_ card: CardType, in slotRows: [DashboardSlotRow]) -> (row: Int, slot: Int)? {
        for (rowIdx, slotRow) in slotRows.enumerated() {
            if let slot = slotRow.slot(of: card) {
                return (rowIdx, slot)
            }
        }
        return nil
    }
    
    // MARK: - Default Placements
    
    /// Creates default placements for initial dashboard layout
    /// Weight chart expanded (2×3) layout:
    /// Row 0-2: [currentWeight] [weightChart ----]
    ///          [calorieTarget] [   2×3        ]
    ///          [protein      ] [              ]
    /// Row 3:   [novaGroups -------------- 2×1]
    /// Row 4:   [nutriScore -------------- 2×1]
    /// Row 5:   [carbs] [fat]
    /// Row 6:   [activity] [empty]
    /// Row 7:   [gutHealth --------------- 2×1]
    static func defaultPlacements(isWeightChartExpanded: Bool = true) -> [CardType: GridPlacement] {
        var placements: [CardType: GridPlacement] = [:]
        
        if isWeightChartExpanded {
            // Weight chart expanded: 2×3 starting at row 0, col 0
            // Small cards stack in left column beside it
            placements[.weightChart] = GridPlacement(card: .weightChart, col: 0, row: 0, colSpan: 2, rowSpan: 3)
            
            // These go after the weight chart
            placements[.currentWeight] = GridPlacement(card: .currentWeight, col: 0, row: 3, colSpan: 1, rowSpan: 1)
            placements[.calorieTarget] = GridPlacement(card: .calorieTarget, col: 1, row: 3, colSpan: 1, rowSpan: 1)
            
            // Row 4: protein (left), carbs (right)
            placements[.protein] = GridPlacement(card: .protein, col: 0, row: 4, colSpan: 1, rowSpan: 1)
            placements[.carbs] = GridPlacement(card: .carbs, col: 1, row: 4, colSpan: 1, rowSpan: 1)
            
            // Row 5: novaGroups (wide)
            placements[.novaGroups] = GridPlacement(card: .novaGroups, col: 0, row: 5, colSpan: 2, rowSpan: 1)
            
            // Row 6: nutriScore (wide)
            placements[.nutriScore] = GridPlacement(card: .nutriScore, col: 0, row: 6, colSpan: 2, rowSpan: 1)
            
            // Row 7: fat (left), activity (right)
            placements[.fat] = GridPlacement(card: .fat, col: 0, row: 7, colSpan: 1, rowSpan: 1)
            placements[.activity] = GridPlacement(card: .activity, col: 1, row: 7, colSpan: 1, rowSpan: 1)
            
            // Row 8: gutHealth (wide)
            placements[.gutHealth] = GridPlacement(card: .gutHealth, col: 0, row: 8, colSpan: 2, rowSpan: 1)
        } else {
            // Weight chart compact: 1×1
            // Row 0: currentWeight (left), weightChart (right)
            placements[.currentWeight] = GridPlacement(card: .currentWeight, col: 0, row: 0, colSpan: 1, rowSpan: 1)
            placements[.weightChart] = GridPlacement(card: .weightChart, col: 1, row: 0, colSpan: 1, rowSpan: 1)
            
            // Row 1: calorieTarget (left), protein (right)
            placements[.calorieTarget] = GridPlacement(card: .calorieTarget, col: 0, row: 1, colSpan: 1, rowSpan: 1)
            placements[.protein] = GridPlacement(card: .protein, col: 1, row: 1, colSpan: 1, rowSpan: 1)
            
            // Row 2: novaGroups (wide)
            placements[.novaGroups] = GridPlacement(card: .novaGroups, col: 0, row: 2, colSpan: 2, rowSpan: 1)
            
            // Row 3: nutriScore (wide)
            placements[.nutriScore] = GridPlacement(card: .nutriScore, col: 0, row: 3, colSpan: 2, rowSpan: 1)
            
            // Row 4: carbs (left), fat (right)
            placements[.carbs] = GridPlacement(card: .carbs, col: 0, row: 4, colSpan: 1, rowSpan: 1)
            placements[.fat] = GridPlacement(card: .fat, col: 1, row: 4, colSpan: 1, rowSpan: 1)
            
            // Row 5: activity (left), empty on right
            placements[.activity] = GridPlacement(card: .activity, col: 0, row: 5, colSpan: 1, rowSpan: 1)
            
            // Row 6: gutHealth (wide)
            placements[.gutHealth] = GridPlacement(card: .gutHealth, col: 0, row: 6, colSpan: 2, rowSpan: 1)
        }
        
        return placements
    }
    
    // MARK: - Frame Calculation
    
    /// Calculates the frame for a placement given container width
    static func frame(for placement: GridPlacement, containerWidth: CGFloat) -> CGRect {
        let availableWidth = containerWidth - (horizontalPadding * 2)
        let cellWidth = (availableWidth - spacing) / 2  // 2 columns with 1 spacing gap
        
        // X position
        let x: CGFloat
        if placement.col == 0 {
            x = horizontalPadding
        } else {
            x = horizontalPadding + cellWidth + spacing
        }
        
        // Y position
        let y = CGFloat(placement.row) * (cellHeight + spacing)
        
        // Width
        let width: CGFloat
        if placement.colSpan == 2 {
            width = availableWidth  // Full width
        } else {
            width = cellWidth
        }
        
        // Height
        let height = CGFloat(placement.rowSpan) * cellHeight + CGFloat(placement.rowSpan - 1) * spacing
        
        return CGRect(x: x, y: y, width: width, height: height)
    }
    
    // MARK: - Total Grid Height
    
    /// Calculates total height needed for all placements
    static func totalHeight(for placements: [CardType: GridPlacement]) -> CGFloat {
        guard !placements.isEmpty else { return 0 }
        
        // Find the maximum row + rowSpan
        var maxRowEnd = 0
        for placement in placements.values {
            let rowEnd = placement.row + placement.rowSpan
            if rowEnd > maxRowEnd {
                maxRowEnd = rowEnd
            }
        }
        
        // Calculate height
        return CGFloat(maxRowEnd) * cellHeight + CGFloat(max(0, maxRowEnd - 1)) * spacing
    }
    
    // MARK: - Sorted Placements (for rendering order)
    
    /// Returns placements sorted by row, then column (top-left to bottom-right)
    static func sortedPlacements(_ placements: [CardType: GridPlacement]) -> [GridPlacement] {
        return placements.values.sorted { a, b in
            if a.row != b.row {
                return a.row < b.row
            }
            return a.col < b.col
        }
    }
    
    // MARK: - Validity Checks
    
    /// Validates that all placements follow grid rules
    /// Returns array of validation errors (empty = valid)
    static func validate(_ placements: [CardType: GridPlacement]) -> [String] {
        var errors: [String] = []
        
        // Check 1: Wide cards (colSpan == 2) must have col == 0
        for (card, placement) in placements {
            if placement.colSpan == 2 && placement.col != 0 {
                errors.append("❌ \(card.rawValue): Wide card (colSpan=2) must start at col=0, but has col=\(placement.col)")
            }
        }
        
        // Check 2: No overlapping cells
        var occupiedCells: [String: CardType] = [:] // "row,col" -> card
        for (card, placement) in placements {
            for cell in placement.occupiedCells {
                let key = "\(cell.row),\(cell.col)"
                if let existingCard = occupiedCells[key] {
                    errors.append("❌ Cell (\(cell.row), \(cell.col)) occupied by both \(existingCard.rawValue) and \(card.rawValue)")
                } else {
                    occupiedCells[key] = card
                }
            }
        }
        
        // Check 3: Column bounds (col must be 0 or 1)
        for (card, placement) in placements {
            if placement.col < 0 || placement.col >= columnCount {
                errors.append("❌ \(card.rawValue): Invalid col=\(placement.col) (must be 0-\(columnCount-1))")
            }
            if placement.col + placement.colSpan > columnCount {
                errors.append("❌ \(card.rawValue): Extends beyond grid (col=\(placement.col), colSpan=\(placement.colSpan))")
            }
        }
        
        return errors
    }
    
    /// Checks if a specific placement is valid (doesn't overlap others)
    static func isValidPlacement(_ placement: GridPlacement, in placements: [CardType: GridPlacement], excluding: CardType? = nil) -> Bool {
        // Wide cards must start at col 0
        if placement.colSpan == 2 && placement.col != 0 {
            return false
        }
        
        // Check column bounds
        if placement.col < 0 || placement.col + placement.colSpan > columnCount {
            return false
        }
        
        // Check for overlaps
        let cellsToCheck = placement.occupiedCells
        for (card, existingPlacement) in placements {
            if card == excluding { continue }
            
            let existingCells = existingPlacement.occupiedCells
            for cell in cellsToCheck {
                for existingCell in existingCells {
                    if cell.row == existingCell.row && cell.col == existingCell.col {
                        return false // Overlap found
                    }
                }
            }
        }
        
        return true
    }
    
    /// Finds a valid target cell for dropping a card
    /// Returns the placement if valid, nil if no valid placement at that position
    static func findValidDropTarget(
        for card: CardType,
        at targetRow: Int,
        targetCol: Int,
        in placements: [CardType: GridPlacement],
        isWeightChartExpanded: Bool
    ) -> GridPlacement? {
        let (colSpan, rowSpan) = size(of: card, isWeightChartExpanded: isWeightChartExpanded)
        
        // Wide cards must snap to col 0
        let adjustedCol = colSpan == 2 ? 0 : targetCol
        
        // Clamp col to valid range
        let finalCol = min(max(adjustedCol, 0), columnCount - colSpan)
        
        let proposedPlacement = GridPlacement(
            card: card,
            col: finalCol,
            row: max(targetRow, 0),
            colSpan: colSpan,
            rowSpan: rowSpan
        )
        
        // Check if valid (excluding the card being dragged)
        let (isValid, reason) = isValidPlacementWithReason(proposedPlacement, in: placements, excluding: card)
        if isValid {
            return proposedPlacement
        } else {
            print("   ❌ Invalid: \(reason)")
            return nil
        }
    }
    
    /// Checks if a specific placement is valid, returns reason if not
    static func isValidPlacementWithReason(_ placement: GridPlacement, in placements: [CardType: GridPlacement], excluding: CardType? = nil) -> (Bool, String) {
        // Wide cards must start at col 0
        if placement.colSpan == 2 && placement.col != 0 {
            return (false, "Wide card must be at col 0")
        }
        
        // Check column bounds
        if placement.col < 0 || placement.col + placement.colSpan > columnCount {
            return (false, "Out of column bounds")
        }
        
        // Check for overlaps
        let cellsToCheck = placement.occupiedCells
        for (card, existingPlacement) in placements {
            if card == excluding { continue }
            
            let existingCells = existingPlacement.occupiedCells
            for cell in cellsToCheck {
                for existingCell in existingCells {
                    if cell.row == existingCell.row && cell.col == existingCell.col {
                        return (false, "Overlaps with \(card.rawValue) at (\(cell.row), \(cell.col))")
                    }
                }
            }
        }
        
        return (true, "Valid")
    }
    
    // MARK: - Collision Resolution
    
    /// Resolves collisions when placing a card at a target position
    /// Uses iterative push: only overlapping cards move, one at a time, until stable
    static func resolvePlacement(
        card: CardType,
        at targetRow: Int,
        targetCol: Int,
        in placements: [CardType: GridPlacement],
        isWeightChartExpanded: Bool
    ) -> [CardType: GridPlacement] {
        var result = placements
        let (colSpan, rowSpan) = size(of: card, isWeightChartExpanded: isWeightChartExpanded)
        
        // Wide cards must snap to col 0
        let finalCol = colSpan == 2 ? 0 : min(max(targetCol, 0), columnCount - colSpan)
        
        // Limit target row to maxOccupiedRow + 1 (can't drag into empty space far below)
        let maxRow = maxOccupiedRow(in: placements)
        let finalRow = min(max(targetRow, 0), maxRow + 1)
        
        // Remove dragged card from old position
        result.removeValue(forKey: card)
        
        // Place dragged card at target
        let draggedPlacement = GridPlacement(
            card: card,
            col: finalCol,
            row: finalRow,
            colSpan: colSpan,
            rowSpan: rowSpan
        )
        result[card] = draggedPlacement
        
        // Debug: show state before collision resolution
        print("🔧 resolvePlacement: \(card.rawValue) → (\(finalRow), \(finalCol))")
        print("   Before collision check:")
        for (c, p) in result {
            print("   - \(c.rawValue) at (\(p.row), \(p.col))")
        }
        
        // Iterate until no overlaps (max 50 iterations to prevent infinite loop)
        // The dragged card stays at its target - only OTHER cards can be moved
        var iterations = 0
        while let collision = findFirstCollision(in: result, excluding: card), iterations < 50 {
            iterations += 1
            print("   ⚠️ Collision found: \(collision.card.rawValue) at (\(collision.row), \(collision.col))")
            
            // Move the colliding card to first available position (from row 0)
            // This allows it to fill freed spots (like the dragged card's old position)
            let collidingCard = collision.card
            
            // Remove temporarily to find new position
            result.removeValue(forKey: collidingCard)
            
            // Find first available from row 0 - allows filling freed spots
            if let newPos = findFirstAvailablePosition(
                for: collidingCard,
                in: result,
                isWeightChartExpanded: isWeightChartExpanded
            ) {
                result[collidingCard] = newPos
                print("   ✅ Moved \(collidingCard.rawValue) to (\(newPos.row), \(newPos.col))")
            }
        }
        
        if iterations == 0 {
            print("   ✅ No collisions found")
        }
        
        return result
    }
    
    /// Removes empty rows by shifting all cards up to fill gaps
    private static func compactGrid(_ placements: [CardType: GridPlacement]) -> [CardType: GridPlacement] {
        guard !placements.isEmpty else { return placements }
        
        // Find all occupied rows
        var occupiedRows = Set<Int>()
        for (_, placement) in placements {
            for r in placement.row..<(placement.row + placement.rowSpan) {
                occupiedRows.insert(r)
            }
        }
        
        // Create a mapping from old row to new row (compacted)
        let sortedRows = occupiedRows.sorted()
        var rowMapping: [Int: Int] = [:]
        var newRow = 0
        var lastMappedRow = -1
        
        for oldRow in sortedRows {
            if oldRow > lastMappedRow + 1 && lastMappedRow >= 0 {
                // Gap detected - don't increment newRow for the gap
            }
            rowMapping[oldRow] = newRow
            if oldRow == lastMappedRow + 1 || lastMappedRow == -1 {
                newRow += 1
            } else {
                newRow += 1
            }
            lastMappedRow = oldRow
        }
        
        // Actually, simpler approach: sort placements by row, assign new sequential rows
        var result: [CardType: GridPlacement] = [:]
        let sorted = sortedPlacements(placements)
        
        // Track which rows are used in the compacted grid
        var usedCells: Set<String> = []
        
        for placement in sorted {
            // Find the first row where this card fits
            var targetRow = 0
            while true {
                let candidate = GridPlacement(
                    card: placement.card,
                    col: placement.col,
                    row: targetRow,
                    colSpan: placement.colSpan,
                    rowSpan: placement.rowSpan
                )
                
                let cells = candidate.occupiedCells.map { "\($0.row),\($0.col)" }
                let hasConflict = cells.contains { usedCells.contains($0) }
                
                if !hasConflict {
                    // Place here
                    result[placement.card] = candidate
                    cells.forEach { usedCells.insert($0) }
                    break
                }
                targetRow += 1
                
                if targetRow > 100 { break } // Safety limit
            }
        }
        
        return result
    }
    
    /// Finds the first collision (overlap) in placements, returns the card that should move
    /// The excluded card (dragged card) stays in place - only other cards can be returned
    private static func findFirstCollision(in placements: [CardType: GridPlacement], excluding: CardType) -> GridPlacement? {
        let sorted = sortedPlacements(placements)
        
        for i in 0..<sorted.count {
            let placement1 = sorted[i]
            let cells1 = Set(placement1.occupiedCells.map { "\($0.row),\($0.col)" })
            
            for j in (i+1)..<sorted.count {
                let placement2 = sorted[j]
                let cells2 = Set(placement2.occupiedCells.map { "\($0.row),\($0.col)" })
                
                if !cells1.isDisjoint(with: cells2) {
                    // Return the card that is NOT the excluded (dragged) card
                    if placement1.card == excluding {
                        return placement2
                    } else if placement2.card == excluding {
                        return placement1
                    } else {
                        // Neither is the dragged card - return the one with larger row
                        return placement2.row >= placement1.row ? placement2 : placement1
                    }
                }
            }
        }
        
        return nil
    }
    
    /// Finds first available position starting from a specific row
    static func findFirstAvailablePositionFrom(
        row startRow: Int,
        for card: CardType,
        in placements: [CardType: GridPlacement],
        isWeightChartExpanded: Bool
    ) -> GridPlacement? {
        let (colSpan, rowSpan) = size(of: card, isWeightChartExpanded: isWeightChartExpanded)
        
        for row in startRow..<100 {
            let colsToTry = colSpan == 2 ? [0] : [0, 1]
            
            for col in colsToTry {
                let candidate = GridPlacement(card: card, col: col, row: row, colSpan: colSpan, rowSpan: rowSpan)
                
                if isValidPlacement(candidate, in: placements, excluding: nil) {
                    return candidate
                }
            }
        }
        
        return nil
    }
    
    /// Finds the first available position for a card (scanning top-to-bottom, left-to-right)
    static func findFirstAvailablePosition(
        for card: CardType,
        in placements: [CardType: GridPlacement],
        isWeightChartExpanded: Bool,
        debug: Bool = false
    ) -> GridPlacement? {
        let (colSpan, rowSpan) = size(of: card, isWeightChartExpanded: isWeightChartExpanded)
        
        // Scan rows from top
        for row in 0..<100 {  // Reasonable upper limit
            // For wide cards, only try col 0
            let colsToTry = colSpan == 2 ? [0] : [0, 1]
            
            for col in colsToTry {
                let candidate = GridPlacement(card: card, col: col, row: row, colSpan: colSpan, rowSpan: rowSpan)
                
                if isValidPlacement(candidate, in: placements, excluding: nil) {
                    if debug {
                        print("   ✅ Found slot for \(card.rawValue) at row \(row), col \(col)")
                    }
                    return candidate
                } else if debug {
                    // Check why it failed
                    let (_, reason) = isValidPlacementWithReason(candidate, in: placements, excluding: nil)
                    print("   ❌ Row \(row), col \(col) invalid for \(card.rawValue): \(reason)")
                }
            }
        }
        
        return nil
    }
    
    // MARK: - Grid Helpers
    
    /// Returns the maximum row occupied by any card in the placements
    static func maxOccupiedRow(in placements: [CardType: GridPlacement]) -> Int {
        var maxRow = 0
        for (_, placement) in placements {
            let bottomRow = placement.row + placement.rowSpan - 1
            maxRow = max(maxRow, bottomRow)
        }
        return maxRow
    }
    
    // MARK: - Signature (for change detection)
    
    /// Creates a stable signature string for placements to detect actual changes
    static func signature(of placements: [CardType: GridPlacement]) -> String {
        sortedPlacements(placements)
            .map { "\($0.card.rawValue):\($0.row),\($0.col)" }
            .joined(separator: "|")
    }
    
    // MARK: - Debug: Print Grid
    
    static func debugPrint(_ placements: [CardType: GridPlacement]) {
        print("=== Dashboard Grid ===")
        for placement in sortedPlacements(placements) {
            let sizeStr = placement.colSpan == 2 ? "wide" : "small"
            let spanStr = placement.rowSpan > 1 ? " (\(placement.rowSpan) rows)" : ""
            print("Row \(placement.row), Col \(placement.col): \(placement.card.rawValue) [\(sizeStr)\(spanStr)]")
        }
        
        // Run validation
        let errors = validate(placements)
        if errors.isEmpty {
            print("✅ Grid is valid")
        } else {
            print("⚠️ Validation errors:")
            errors.forEach { print("  \($0)") }
        }
        print("======================")
    }
}
