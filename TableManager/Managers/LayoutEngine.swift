//
//  LayoutEngine.swift
//  TableManager
//
//  Created for TableManager macOS app
//

import Foundation
import Cocoa

/// Responsible for creating, managing and applying window layouts
class LayoutEngine {
    
    // MARK: - Properties
    
    /// Window manager instance for window manipulation
    private let windowManager: WindowManager
    
    /// Minimum acceptable distance for considering positions as separate grid lines
    private let gridPositionTolerance: CGFloat = 15.0
    
    /// Minimum aspect ratio difference to consider custom sizing
    private let aspectRatioTolerance: CGFloat = 0.2
    
    // MARK: - Initialization
    
    init(windowManager: WindowManager) {
        self.windowManager = windowManager
    }
    
    // MARK: - Public Methods
    
    /// Creates a grid layout with specified rows and columns for a display
    /// - Parameters:
    ///   - rows: Number of rows
    ///   - columns: Number of columns
    ///   - displayID: Display ID to create layout for
    /// - Returns: Created layout
    func createGridLayout(rows: Int, columns: Int, displayID: CGDirectDisplayID) -> Layout {
        // Get display bounds
        let displayBounds = CGDisplayBounds(displayID)
        
        // Calculate slot size
        let slotWidth = displayBounds.width / CGFloat(columns)
        let slotHeight = displayBounds.height / CGFloat(rows)
        
        var slots: [Slot] = []
        
        // Create slots for each cell in the grid
        for row in 0..<rows {
            for col in 0..<columns {
                let x = displayBounds.minX + (slotWidth * CGFloat(col))
                let y = displayBounds.minY + (slotHeight * CGFloat(row))
                
                let frame = CGRect(x: x, y: y, width: slotWidth, height: slotHeight)
                
                let slot = Slot(
                    id: "\(row)_\(col)",
                    frame: frame,
                    displayID: displayID,
                    priority: 0
                )
                
                slots.append(slot)
            }
        }
        
        return Layout(
            id: UUID().uuidString,
            name: "Grid \(rows)×\(columns)",
            slots: slots,
            matchingStrategy: .sequential
        )
    }
    
    /**
     Creates a grid layout with overlapping slots for compact display on smaller screens
     - Parameters:
       - rows: Number of rows
       - columns: Number of columns
       - overlap: Overlap percentage (0.0-0.5)
       - displayID: Display ID to create layout for
     - Returns: Created layout with overlapping slots
     */
    func createOverlappingGridLayout(rows: Int, columns: Int, overlap: CGFloat = 0.3, displayID: CGDirectDisplayID) -> Layout {
        // Make sure overlap is within reasonable bounds
        let safeOverlap = min(max(overlap, 0.0), 0.5)
        
        // Get display bounds
        let displayBounds = CGDisplayBounds(displayID)
        
        // Calculate slot size without overlap
        let fullSlotWidth = displayBounds.width / CGFloat(columns)
        let fullSlotHeight = displayBounds.height / CGFloat(rows)
        
        // Calculate effective dimensions with overlap
        let effectiveWidth = fullSlotWidth * (1.0 + safeOverlap)
        let effectiveHeight = fullSlotHeight * (1.0 + safeOverlap)
        
        var slots: [Slot] = []
        
        // Create slots for each cell in the grid
        for row in 0..<rows {
            for col in 0..<columns {
                // Calculate position with overlap
                let x = displayBounds.minX + (fullSlotWidth * CGFloat(col)) * (1.0 - safeOverlap)
                let y = displayBounds.minY + (fullSlotHeight * CGFloat(row)) * (1.0 - safeOverlap)
                
                let frame = CGRect(x: x, y: y, width: effectiveWidth, height: effectiveHeight)
                
                let slot = Slot(
                    id: "\(row)_\(col)",
                    frame: frame,
                    displayID: displayID,
                    priority: 0
                )
                
                slots.append(slot)
            }
        }
        
        return Layout(
            id: UUID().uuidString,
            name: "Overlapping Grid \(rows)×\(columns)",
            slots: slots,
            matchingStrategy: .sequential
        )
    }
    
    /// Creates a layout with custom aspect ratios optimized for poker tables
    /// - Parameters:
    ///   - tableCount: Number of tables
    ///   - displayID: Display ID to create layout for
    /// - Returns: Poker-optimized layout
    func createPokerLayout(tableCount: Int, displayID: CGDirectDisplayID) -> Layout {
        // Get display bounds
        let displayBounds = CGDisplayBounds(displayID)
        
        // Determine best grid configuration
        let (rows, columns) = calculateOptimalGridForTableCount(tableCount)
        
        // Standard poker table has aspect ratio around 1.25 (width/height)
        let targetAspectRatio: CGFloat = 1.25
        
        // Calculate grid dimensions
        let gridWidth = displayBounds.width
        let gridHeight = displayBounds.height
        
        // Calculate slot dimensions
        let rawSlotWidth = gridWidth / CGFloat(columns)
        let rawSlotHeight = gridHeight / CGFloat(rows)
        
        // Check if we need to adjust for aspect ratio
        let currentAspectRatio = rawSlotWidth / rawSlotHeight
        
        // Adjusted dimensions
        var slotWidth = rawSlotWidth
        var slotHeight = rawSlotHeight
        
        // If aspect ratio is off by more than tolerance, adjust slot dimensions
        if abs(currentAspectRatio - targetAspectRatio) > aspectRatioTolerance {
            if currentAspectRatio > targetAspectRatio {
                // Too wide, need to reduce width
                slotWidth = slotHeight * targetAspectRatio
            } else {
                // Too tall, need to reduce height
                slotHeight = slotWidth / targetAspectRatio
            }
        }
        
        var slots: [Slot] = []
        
        // Create slots for each cell in the grid
        for row in 0..<rows {
            for col in 0..<columns {
                // Skip if we've created enough slots
                if slots.count >= tableCount {
                    break
                }
                
                // Calculate position with centering if dimensions were adjusted
                let xOffset = (rawSlotWidth - slotWidth) / 2
                let yOffset = (rawSlotHeight - slotHeight) / 2
                
                let x = displayBounds.minX + (rawSlotWidth * CGFloat(col)) + xOffset
                let y = displayBounds.minY + (rawSlotHeight * CGFloat(row)) + yOffset
                
                let frame = CGRect(x: x, y: y, width: slotWidth, height: slotHeight)
                
                let slot = Slot(
                    id: "\(row)_\(col)",
                    frame: frame,
                    displayID: displayID,
                    priority: 0
                )
                
                slots.append(slot)
            }
        }
        
        return Layout(
            id: UUID().uuidString,
            name: "Poker \(tableCount) Tables",
            slots: slots,
            matchingStrategy: .sequential
        )
    }
    
    /// Creates a layout based on currently detected windows
    /// - Returns: Layout based on current window positions
    func captureCurrentLayout() -> Layout {
        return windowManager.captureCurrentLayout()
    }
    
    /// Optimizes a captured layout to create a cleaner grid
    /// - Parameter capturedLayout: Raw captured layout
    /// - Returns: Optimized layout
    func optimizeCapturedLayout(_ capturedLayout: Layout) -> Layout {
        Logger.log("Optimizing captured layout with \(capturedLayout.slots.count) slots", level: .info)
        
        // Group slots by display
        let slotsByDisplay = Dictionary(grouping: capturedLayout.slots) { $0.displayID }
        
        var optimizedSlots: [Slot] = []
        
        // Process each display's slots
        for (displayID, slots) in slotsByDisplay {
            // Get display bounds
            let displayBounds = CGDisplayBounds(displayID)
            
            // Analyze window positions to detect a potential grid
            let optimizedDisplaySlots = detectGridFromSlots(slots, displayBounds: displayBounds)
            optimizedSlots.append(contentsOf: optimizedDisplaySlots)
            
            Logger.log("Optimized \(slots.count) slots on display \(displayID) to \(optimizedDisplaySlots.count) grid slots", level: .debug)
        }
        
        // Preserve the matching strategy from original layout
        return Layout(
            id: UUID().uuidString, 
            name: "Optimized \(capturedLayout.name)",
            slots: optimizedSlots,
            matchingStrategy: capturedLayout.matchingStrategy
        )
    }
    
    /// Applies a layout to current windows
    /// - Parameter layout: Layout to apply
    func applyLayout(_ layout: Layout) {
        windowManager.applyLayout(layout)
    }
    
    // MARK: - Private Methods
    
    /// Calculates the optimal grid dimensions for a given number of tables
    /// - Parameter tableCount: Number of tables
    /// - Returns: Tuple of (rows, columns)
    private func calculateOptimalGridForTableCount(_ tableCount: Int) -> (Int, Int) {
        switch tableCount {
        case 1:
            return (1, 1)
        case 2:
            return (1, 2)
        case 3, 4:
            return (2, 2)
        case 5, 6:
            return (2, 3)
        case 7, 8, 9:
            return (3, 3)
        case 10, 11, 12:
            return (3, 4)
        case 13, 14, 15, 16:
            return (4, 4)
        default:
            // For larger counts, find the closest square root
            let sqrt = Int(Double(tableCount).squareRoot())
            if sqrt * sqrt >= tableCount {
                return (sqrt, sqrt)
            } else if sqrt * (sqrt + 1) >= tableCount {
                return (sqrt, sqrt + 1)
            } else {
                return (sqrt + 1, sqrt + 1)
            }
        }
    }
    
    /// Attempts to detect a grid pattern from arbitrary slot positions
    /// - Parameters:
    ///   - slots: Slots to analyze
    ///   - displayBounds: Bounds of the display
    /// - Returns: Optimized slots that form a cleaner grid
    private func detectGridFromSlots(_ slots: [Slot], displayBounds: CGRect) -> [Slot] {
        // If there are few windows, return original slots
        if slots.count < 3 {
            Logger.log("Too few slots (\(slots.count)) to detect grid pattern, keeping original", level: .debug)
            return slots
        }
        
        // Extract X and Y positions
        let xPositions = slots.map { $0.frame.minX }
        let yPositions = slots.map { $0.frame.minY }
        
        // Get unique positions (with tolerance for slight misalignments)
        let uniqueXPositions = findUniquePositionsWithTolerance(xPositions, tolerance: gridPositionTolerance)
        let uniqueYPositions = findUniquePositionsWithTolerance(yPositions, tolerance: gridPositionTolerance)
        
        // Sort positions
        let sortedXPositions = uniqueXPositions.sorted()
        let sortedYPositions = uniqueYPositions.sorted()
        
        // Determine potential grid dimensions
        let columns = sortedXPositions.count
        let rows = sortedYPositions.count
        
        // Calculate average width and height
        var avgWidth: CGFloat = 0
        var avgHeight: CGFloat = 0
        
        if columns > 1 {
            let widths = uniqueXPositions.sorted().enumerated().compactMap { index, x -> CGFloat? in
                return index < uniqueXPositions.count - 1 ? uniqueXPositions.sorted()[index + 1] - x : nil
            }
            avgWidth = widths.reduce(0, +) / CGFloat(widths.count)
        } else {
            // If only one column, use average width of current slots
            avgWidth = slots.map { $0.frame.width }.reduce(0, +) / CGFloat(slots.count)
        }
        
        if rows > 1 {
            let heights = uniqueYPositions.sorted().enumerated().compactMap { index, y -> CGFloat? in
                return index < uniqueYPositions.count - 1 ? uniqueYPositions.sorted()[index + 1] - y : nil
            }
            avgHeight = heights.reduce(0, +) / CGFloat(heights.count)
        } else {
            // If only one row, use average height of current slots
            avgHeight = slots.map { $0.frame.height }.reduce(0, +) / CGFloat(slots.count)
        }
        
        // Check if detected grid is reasonably dense
        let potentialCells = rows * columns
        if potentialCells >= slots.count && potentialCells <= slots.count * 2 {
            Logger.log("Detected grid pattern: \(rows)x\(columns) for \(slots.count) windows", level: .info)
            
            // Create a grid layout with these dimensions
            return createGridSlotsWithSpacing(
                rows: rows,
                columns: columns,
                xPositions: sortedXPositions,
                yPositions: sortedYPositions,
                avgWidth: avgWidth,
                avgHeight: avgHeight,
                displayID: slots.first?.displayID ?? CGMainDisplayID()
            )
        }
        
        // Fall back to creating a regular grid based on the total slots count
        Logger.log("Could not detect clear grid pattern, creating regular grid", level: .info)
        let approximateColumns = Int(sqrt(Double(slots.count)))
        return createRegularGridSlots(
            rows: slots.count / approximateColumns + (slots.count % approximateColumns > 0 ? 1 : 0),
            columns: approximateColumns,
            displayBounds: displayBounds,
            displayID: slots.first?.displayID ?? CGMainDisplayID()
        )
    }
    
    /// Finds unique positions within a tolerance
    /// - Parameters:
    ///   - positions: Array of positions
    ///   - tolerance: Tolerance for considering positions the same
    /// - Returns: Array of unique positions
    private func findUniquePositionsWithTolerance(_ positions: [CGFloat], tolerance: CGFloat) -> [CGFloat] {
        var uniquePositions: [CGFloat] = []
        
        for position in positions {
            // Check if this position is close to any existing unique position
            if !uniquePositions.contains(where: { abs($0 - position) <= tolerance }) {
                uniquePositions.append(position)
            }
        }
        
        return uniquePositions
    }
    
    /// Creates grid slots with spacing based on detected positions
    /// - Parameters:
    ///   - rows: Number of rows
    ///   - columns: Number of columns
    ///   - xPositions: X positions for columns
    ///   - yPositions: Y positions for rows
    ///   - avgWidth: Average slot width
    ///   - avgHeight: Average slot height
    ///   - displayID: Display ID
    /// - Returns: Array of slots forming a grid
    private func createGridSlotsWithSpacing(
        rows: Int,
        columns: Int,
        xPositions: [CGFloat],
        yPositions: [CGFloat],
        avgWidth: CGFloat,
        avgHeight: CGFloat,
        displayID: CGDirectDisplayID
    ) -> [Slot] {
        var slots: [Slot] = []
        
        // Process each grid cell
        for row in 0..<min(rows, yPositions.count) {
            for col in 0..<min(columns, xPositions.count) {
                // Calculate optimal width for this column
                let width: CGFloat
                if col < xPositions.count - 1 {
                    // Use distance to next column, with 5% spacing
                    width = (xPositions[col + 1] - xPositions[col]) * 0.95
                } else {
                    // Use average width for last column
                    width = avgWidth
                }
                
                // Calculate optimal height for this row
                let height: CGFloat
                if row < yPositions.count - 1 {
                    // Use distance to next row, with 5% spacing
                    height = (yPositions[row + 1] - yPositions[row]) * 0.95
                } else {
                    // Use average height for last row
                    height = avgHeight
                }
                
                let frame = CGRect(x: xPositions[col], y: yPositions[row], width: width, height: height)
                
                let slot = Slot(
                    id: "\(row)_\(col)",
                    frame: frame,
                    displayID: displayID,
                    priority: 0
                )
                
                slots.append(slot)
            }
        }
        
        return slots
    }
    
    /// Creates regular grid slots with equal sizes
    /// - Parameters:
    ///   - rows: Number of rows
    ///   - columns: Number of columns
    ///   - displayBounds: Display bounds
    ///   - displayID: Display ID
    /// - Returns: Array of slots forming a regular grid
    private func createRegularGridSlots(
        rows: Int,
        columns: Int, 
        displayBounds: CGRect,
        displayID: CGDirectDisplayID
    ) -> [Slot] {
        // Use 95% of display with 5% margin
        let usableWidth = displayBounds.width * 0.95
        let usableHeight = displayBounds.height * 0.95
        let xOffset = (displayBounds.width - usableWidth) / 2
        let yOffset = (displayBounds.height - usableHeight) / 2
        
        let slotWidth = usableWidth / CGFloat(columns)
        let slotHeight = usableHeight / CGFloat(rows)
        
        var slots: [Slot] = []
        
        for row in 0..<rows {
            for col in 0..<columns {
                let x = displayBounds.minX + xOffset + (slotWidth * CGFloat(col))
                let y = displayBounds.minY + yOffset + (slotHeight * CGFloat(row))
                
                let frame = CGRect(x: x, y: y, width: slotWidth, height: slotHeight)
                
                let slot = Slot(
                    id: "\(row)_\(col)",
                    frame: frame,
                    displayID: displayID,
                    priority: 0
                )
                
                slots.append(slot)
            }
        }
        
        return slots
    }
}

// MARK: - Supporting Types

/// Window layout containing slots for window positioning
struct Layout: Identifiable, Codable {
    let id: String
    var name: String
    var slots: [Slot]
    var matchingStrategy: MatchingStrategy
    
    /// Assigns windows to slots based on the matching strategy
    /// - Parameter windows: Windows to assign
    /// - Returns: Dictionary mapping windows to slots
    func assignWindowsToSlots(windows: [ManagedWindow]) -> [ManagedWindow: Slot] {
        switch matchingStrategy {
        case .sequential:
            return assignSequentially(windows: windows)
        case .byType:
            return assignByType(windows: windows)
        }
    }
    
    /// Sequential assignment - first window to first slot, etc.
    private func assignSequentially(windows: [ManagedWindow]) -> [ManagedWindow: Slot] {
        var assignments: [ManagedWindow: Slot] = [:]
        
        // Group slots by display
        let slotsByDisplay = Dictionary(grouping: slots) { $0.displayID }
        
        // Group windows by display
        let windowsByDisplay = Dictionary(grouping: windows) { $0.displayID }
        
        // Assign windows for each display
        for (displayID, displayWindows) in windowsByDisplay {
            let displaySlots = slotsByDisplay[displayID] ?? []
            
            // Sort slots by priority (higher priority first)
            let sortedSlots = displaySlots.sorted { $0.priority > $1.priority }
            
            // Assign each window to a slot
            for (index, window) in displayWindows.enumerated() {
                if index < sortedSlots.count {
                    assignments[window] = sortedSlots[index]
                }
            }
        }
        
        return assignments
    }
    
    /// Type-based assignment - tries to match windows to slots by window type
    private func assignByType(windows: [ManagedWindow]) -> [ManagedWindow: Slot] {
        var assignments: [ManagedWindow: Slot] = [:]
        
        // Group slots by display
        let slotsByDisplay = Dictionary(grouping: slots) { $0.displayID }
        
        // Group windows by type
        let windowsByType = Dictionary(grouping: windows) { $0.type.id }
        
        // For each display, assign windows by type
        for (displayID, displaySlots) in slotsByDisplay {
            // Sort slots by priority
            let sortedSlots = displaySlots.sorted { $0.priority > $1.priority }
            var availableSlots = sortedSlots
            
            // Track which windows are assigned to this display
            var assignedWindowCount = 0
            
            // First, try to assign windows of the same type to consecutive slots
            for (_, typeWindows) in windowsByType {
                // Filter windows on this display
                let displayTypeWindows = typeWindows.filter { $0.displayID == displayID }
                
                // Skip if no windows of this type on this display
                if displayTypeWindows.isEmpty {
                    continue
                }
                
                // Determine how many consecutive slots we need
                let requiredSlots = min(displayTypeWindows.count, availableSlots.count)
                
                // Assign windows to consecutive slots
                for i in 0..<requiredSlots {
                    assignments[displayTypeWindows[i]] = availableSlots[i]
                    assignedWindowCount += 1
                }
                
                // Remove used slots
                availableSlots.removeFirst(requiredSlots)
                
                // Stop if no more slots available
                if availableSlots.isEmpty {
                    break
                }
            }
            
            // If there are unassigned windows on this display, assign them sequentially
            let allDisplayWindows = windows.filter { $0.displayID == displayID }
            let unassignedWindows = allDisplayWindows.filter { !assignments.keys.contains($0) }
            
            for (index, window) in unassignedWindows.enumerated() {
                if index < availableSlots.count {
                    assignments[window] = availableSlots[index]
                }
            }
        }
        
        // If any windows remain unassigned, fall back to sequential assignment
        let unassignedWindows = windows.filter { !assignments.keys.contains($0) }
        if !unassignedWindows.isEmpty {
            // Get all unused slots
            let usedSlots = Set(assignments.values.map { $0.id })
            let unusedSlots = slots.filter { !usedSlots.contains($0.id) }
            
            // Assign remaining windows sequentially
            for (index, window) in unassignedWindows.enumerated() {
                if index < unusedSlots.count {
                    assignments[window] = unusedSlots[index]
                }
            }
        }
        
        return assignments
    }
}

/// Window matching strategy for layout application
enum MatchingStrategy: String, Codable {
    case sequential // First window to first slot
    case byType     // Match windows to slots by window type
}

/// Slot defining a position for a window in a layout
struct Slot: Identifiable, Codable {
    let id: String
    var frame: CGRect
    let displayID: CGDirectDisplayID
    var priority: Int
    
    // Custom coding keys to handle CGRect
    enum CodingKeys: String, CodingKey {
        case id, displayID, priority
        case x, y, width, height
    }
    
    init(id: String, frame: CGRect, displayID: CGDirectDisplayID, priority: Int) {
        self.id = id
        self.frame = frame
        self.displayID = displayID
        self.priority = priority
    }
    
    // Custom encoding for CGRect
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        displayID = try container.decode(UInt32.self, forKey: .displayID)
        priority = try container.decode(Int.self, forKey: .priority)
        
        let x = try container.decode(CGFloat.self, forKey: .x)
        let y = try container.decode(CGFloat.self, forKey: .y)
        let width = try container.decode(CGFloat.self, forKey: .width)
        let height = try container.decode(CGFloat.self, forKey: .height)
        
        frame = CGRect(x: x, y: y, width: width, height: height)
    }
    
    // Custom encoding for CGRect
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(displayID, forKey: .displayID)
        try container.encode(priority, forKey: .priority)
        
        try container.encode(frame.origin.x, forKey: .x)
        try container.encode(frame.origin.y, forKey: .y)
        try container.encode(frame.size.width, forKey: .width)
        try container.encode(frame.size.height, forKey: .height)
    }
}
