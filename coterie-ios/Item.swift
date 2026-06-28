//
//  Item.swift
//  coterie-ios
//
//  Created by Ishan Gupta on 28/06/26.
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
