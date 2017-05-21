//
//  CurveView.swift
//  Grade
//
//  Created by Rory Bain on 20/05/2017.
//  Copyright © 2017 Rory Bain. All rights reserved.
//

import Foundation
import UIKit

class CurveView: UIView {

    var points: [CGPoint] = [CGPoint(x: 0, y: 0),
                             CGPoint(x: 0.25, y: 0.25),
                             CGPoint(x: 0.5, y: 0.5),
                             CGPoint(x: 0.75, y: 0.75),
                             CGPoint(x: 1, y: 1)] {
        didSet {
            setNeedsDisplay()
        }
    }

    var circleSize: CGFloat = 10 {
        didSet {
            setNeedsDisplay()
        }
    }

    var lineColor: UIColor = .darkGray {
        didSet {
            setNeedsDisplay()
        }
    }

    init() {
        super.init(frame: .zero)

        backgroundColor = .white
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        clipsToBounds = false
        layer.masksToBounds = false
    }

    func setup(with item: CurveViewModel) {
        self.lineColor = item.curve.colour()
        self.points = item.points
    }

    override func draw(_ rect: CGRect) {
        super.draw(rect)

        drawBaseLine(rect)

        let scaledPoints = CurveView.scale(points, toRect: rect)
        let path = UIBezierPath(hermiteInterpolatedPoints: scaledPoints, closed: false)
        lineColor.setStroke()
        path?.lineWidth = 3
        path?.stroke()

        scaledPoints.forEach({ drawCircle(at: $0) })
    }

    static func scale(_ points: [CGPoint], toRect rect: CGRect) -> [CGPoint] {
        return points.map({ CGPoint(x: rect.origin.x + rect.width * $0.x,
                                    y: rect.origin.y + rect.height * (1 - $0.y)) })
    }

    func outline(_ rect: CGRect) {
        let path = UIBezierPath(rect: rect)
        UIColor.gray.setStroke()
        path.lineWidth = 1
        path.stroke()
    }

    // Draws the horizontal line representing a flat curve

    func drawBaseLine(_ rect: CGRect) {
        let p1 = CGPoint(x: rect.origin.x, y: rect.origin.y + rect.height)
        let p2 = CGPoint(x: rect.origin.x + rect.width, y: rect.origin.y)
        let path = UIBezierPath()
        path.move(to: p1)
        path.addLine(to: p2)
        UIColor.black.withAlphaComponent(0.4).setStroke()
        path.lineWidth = 1
        path.stroke()
    }

    func drawCircle(at point: CGPoint) {
        let halfCircle = circleSize / 2
        let rect = CGRect(x: point.x - halfCircle, y: point.y - halfCircle, width: circleSize, height: circleSize)
        let circlePath = UIBezierPath(ovalIn: rect)
        circlePath.lineWidth = 1
        lineColor.set()
        circlePath.stroke()
        circlePath.fill()
    }

}
