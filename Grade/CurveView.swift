//
//  CurveView.swift
//  Grade
//
//  Created by Rory Bain on 20/05/2017.
//  Copyright © 2017 Rory Bain. All rights reserved.
//

import Foundation
import UIKit

protocol CurveViewDelegate: class {
    func valueChanged(pointIndex: Int, value: CGPoint)
}

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

    private var viewInset: CGFloat = 20 {
        didSet {
            setNeedsDisplay()
        }
    }

    weak var delegate: CurveViewDelegate?

    var currentItem: (offset: Int, element: CGPoint)?
    var currentItemStartY: CGFloat?
    var panStartY: CGFloat?
    var shouldVibrate = false

    init() {
        super.init(frame: .zero)
        clipsToBounds = false
        layer.masksToBounds = false
        backgroundColor = .white
        let gestureRecog = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        addGestureRecognizer(gestureRecog)
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    func setup(with item: CurveViewModel) {
        self.lineColor = item.curve.colour()
        self.points = item.points
    }

    override func draw(_ rect: CGRect) {
        super.draw(rect)

        let insetRect = rect.insetBy(dx: viewInset, dy: viewInset)

        drawBaseLine(insetRect)

        let scaledPoints = CurveView.scale(points, toRect: insetRect)
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

// MARK: Tap Handling

extension CurveView {

    func handlePan(_ sender: UIPanGestureRecognizer) {
        switch sender.state {
        case .began: handleBegan(sender)
        case .changed: handleChanged(sender)
        case .ended, .cancelled: handleEnded(sender)
        default: return
        }
    }

    private func handleChanged(_ sender: UIPanGestureRecognizer) {
        guard let currentItem = currentItem,
            let panStartY = panStartY,
            let currentItemStartY = currentItemStartY else { return }

        let newPosition = sender.location(in: self)
        let newScaledY = 1 - (newPosition.y / frame.height)

        let movedAmmount = newScaledY - panStartY
        var movedPosition = currentItemStartY + movedAmmount

        if movedPosition < 0 {
            movedPosition = 0
        } else if movedPosition > 1 {
            movedPosition = 1
        }

        if (movedPosition == 1 || movedPosition == 0) && shouldVibrate {
            shouldVibrate = false
            HapticManager.selectionChanged()
        }

        if (movedPosition > 0.05 && movedPosition < 0.95) || (movedPosition < 0.95 && movedPosition > 0.05) {
            shouldVibrate = true
        }

        let pointIndex = currentItem.offset
        points[pointIndex] = CGPoint(x: currentItem.element.x, y: movedPosition)

        delegate?.valueChanged(pointIndex: pointIndex, value: points[pointIndex])
    }

    private func handleBegan(_ sender: UIPanGestureRecognizer) {

        let position = sender.location(in: self)
        let scaledX = position.x / frame.width
        let scaledY = 1 - (position.y / frame.height)

        currentItem = points
            .enumerated()
            .max(by: { abs(scaledX - $0.element.x) > abs(scaledX - $1.element.x) }) // closest point to touch by 'x'
        panStartY = scaledY
        guard let currentItem = currentItem else { return }
        currentItemStartY = points[currentItem.offset].y
    }

    private func handleEnded(_ sender: UIPanGestureRecognizer) {
        currentItem = nil
        panStartY = nil
        currentItemStartY = nil
    }

}
