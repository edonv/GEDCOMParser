//
//  DateObject.swift
//  GEDCOMConverter
//
//  Created by Craig Grummitt on 20/11/17.
//

import Foundation

public struct DateObject: Codable, CustomStringConvertible {
    public var datesDetected: [Date]?
    public var dateOriginalText: String
    
    public init(_ data: String) {
        self.dateOriginalText = data
        self.datesDetected = data.detectDates
    }
    
    public init(_ date: Date) {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd-MMM-yyyy"
        self.dateOriginalText =  formatter.string(from: date)
        self.datesDetected = [date]
    }
    
    public var description: String {
        dateOriginalText
    }
}

extension DateObject: Equatable {
    public static func ==(lhs: DateObject, rhs: DateObject) -> Bool {
        lhs.dateOriginalText == rhs.dateOriginalText
    }
}

// https:// stackoverflow.com/a/32595941/3220708
extension String {
//    var nsString: NSString { self as NSString }
//    var length: Int { nsString.length }
    private var nsRange: NSRange {
        .init(startIndex..<endIndex, in: self)
    }
    
    public var detectDates: [Date]? {
        print("Detecting dates from string:", self)
        
        var date = self
        
        // If only the year is known, to make a complete date let's assume 30 Jun
        if date.isYear() {
            // FIX one day: perhaps this and the following assumption should change the status of the date somehow
            date = "30 Jun " + self
        }
        
        // Work around limitation of NSDataDetector that it only deals with years >= 1700
        let characterSets = CharacterSet(charactersIn: " /\\-.:")
        var parts = date.components(separatedBy: characterSets)
        var joinAgain = false
        
        // If only the month and year is known, make a complete date and let's assume 15 of the month
        if parts.count == 2, parts[0].isMonth(), parts[1].isYear() {
            parts.insert("15", at: 0)
            joinAgain = true
        }
        
        var yearInWaiting: Int?
        var monthInLetters = false
        for (i, part) in parts.enumerated() {
            if part.isYear(),
                // should always be true
               let year = Int(part) {
                yearInWaiting = year
                if year < 1700 {
                    parts[i] = "2000"
                    joinAgain = true
                }
            } else if part.isMonth() {
                monthInLetters = true
            }
        }
        
        if joinAgain {
            date = parts.joined(separator: monthInLetters ? " " : "/")
        }
        
        // Do the date detection
        var returnDates = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
            .matches(in: date, range: nsRange)
            .compactMap(\.date)
        
        if let returnDatesUnwrapped = returnDates,
           returnDatesUnwrapped.count == 0,
           let yearInWaiting = yearInWaiting {
            date = "30 Jun \(yearInWaiting)"
            returnDates = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
                .matches(in: date, range: nsRange)
                .compactMap(\.date)
        }
        
        // Reinstate year that we discovered earlier
        if var returnDates {
            for (i, returnDate) in returnDates.enumerated() {
                if let year = yearInWaiting {
                    var components = Calendar.current.dateComponents([.year, .month, .day], from: returnDate)
                    components.year = year
                    if let date = Calendar.current.date(from: components) {
                        returnDates[i] = date
                    }
                }
            }
            return returnDates
        } else {
            return nil
        }
    }
    
    /// `true` if month
    internal func isMonth() -> Bool {
        return (self.count >= 3 && self.rangeOfCharacter(from: .letters) != nil)
    }
    
    /// `true` if year
    internal func isYear() -> Bool {
        if self.count==4 && !self.contains(" "), let dateAsInt = Int(self), String(dateAsInt) == self {
            return true
        }
        return false
    }
}

extension Collection where Element == String {
    internal var dates: [Date] {
        return compactMap(\.detectDates)
            .flatMap { $0 }
    }
}

