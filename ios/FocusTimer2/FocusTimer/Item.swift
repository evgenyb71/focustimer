//
//  Item.swift
//  FocusTimer
//
//  Created by Eugene Bochkarev on 12/26/25.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
