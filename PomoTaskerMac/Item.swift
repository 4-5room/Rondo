//
//  Item.swift
//  PomoTaskerMac
//
//  Created by R S on 2026/04/26.
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
