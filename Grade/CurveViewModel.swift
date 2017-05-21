//
//  CurveViewModel.swift
//  Grade
//
//  Created by Rory Bain on 21/05/2017.
//  Copyright © 2017 Rory Bain. All rights reserved.
//

import Foundation
import UIKit

class CurveViewModel {

    var curve: Curve
    var points: [CGPoint] = [
        CGPoint(x: 0, y: 0),
        CGPoint(x: 0.25, y: 0.25),
        CGPoint(x: 0.5, y: 0.5),
        CGPoint(x: 0.75, y: 0.75),
        CGPoint(x: 1, y: 1)
        ]

    init(_ curve: Curve) {
        self.curve = curve
    }

    enum Curve: String {
        case all = "All"
        case red = "Red"
        case green = "Green"
        case blue = "Blue"

        func colour() -> UIColor {
            switch self {
            case .all: return UIColor.black
            case .red: return UIColor.red
            case .green: return UIColor.green
            case .blue: return UIColor.blue
            }
        }
    }

}
