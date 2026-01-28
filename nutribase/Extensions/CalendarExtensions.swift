//
//  CalendarExtensions.swift
//  nutribase
//
//  Created on 25/12/2024.
//

import Foundation

extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components) ?? date
    }
    
    func endOfMonth(for date: Date) -> Date {
        let startOfMonth = self.startOfMonth(for: date)
        let nextMonth = self.date(byAdding: .month, value: 1, to: startOfMonth) ?? date
        return self.date(byAdding: .day, value: -1, to: nextMonth) ?? date
    }
}
