//
//  ViewController.swift
//  Grade
//
//  Created by Rory Bain on 21/05/2017.
//  Copyright © 2017 Rory Bain. All rights reserved.
//

//
//  TestViewController.swift
//  ComputerVis
//
//  Created by Rory Bain on 20/05/2017.
//  Copyright © 2017 Rory Bain. All rights reserved.
//

import Foundation
import UIKit
import GPUImage
import Photos
import PureLayout

class ViewController: UIViewController {

    let padding: CGFloat = 16

    let curveView = CurveView()

    var currentImage: UIImage?

    let imageView: GPUImageView = {
        let imageView = GPUImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.setBackgroundColorRed(238/256, green:238/256, blue: 238/256, alpha: 1)
        return imageView
    }()

    lazy var saveButton: UIButton = {
        let button = UIButton()
        button.setTitle("SAVE", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 14)
        button.addTarget(self, action: #selector(savePressed), for: .touchUpInside)
        button.setTitleColor(.black, for: .normal)
        return button
    }()

    lazy var label: UILabel = {
        let label = UILabel()
        label.backgroundColor = UIColor(colorLiteralRed: 238/256, green: 238/256, blue: 238/256, alpha: 1)
        label.textColor = .black
        label.text = "Tap here to import a photo"
        label.textAlignment = .center
        return label
    }()

    var sourceImage = GPUImagePicture(image: UIImage(named: "test.JPG"))!
    let rgbFilter = GPUImageToneCurveFilter()

    var items = [CurveViewModel.Curve.all, .red, .green, .blue].map({ CurveViewModel($0) })

    var segmenetedControl: UISegmentedControl!

    override func viewDidLoad() {
        super.viewDidLoad()

        saveButton.isHidden = true

        segmenetedControl = UISegmentedControl(items: items.map({ $0.curve.rawValue }))
        segmenetedControl.addTarget(self, action: #selector(changedCurve), for: .valueChanged)
        segmenetedControl.selectedSegmentIndex = 0
        segmenetedControl.tintColor = .black

        curveView.delegate = self

        view.backgroundColor = .white
        view.addSubview(label)
        view.addSubview(segmenetedControl)
        view.addSubview(segmenetedControl)
        view.addSubview(curveView)
        view.addSubview(saveButton)
        view.addSubview(imageView)

        segmenetedControl.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(padding), excludingEdge: .top)

        curveView.autoPinEdge(toSuperviewEdge: .leading, withInset: padding)
        curveView.autoPinEdge(toSuperviewEdge: .trailing, withInset: padding)
        curveView.autoSetDimension(.height, toSize: 250)
        curveView.autoPinEdge(.bottom, to: .top, of: segmenetedControl, withOffset: -padding)

        saveButton.autoPinEdge(toSuperviewEdge: .trailing, withInset: padding)
        saveButton.autoPinEdge(.bottom, to: .top, of: curveView, withOffset: 0)
        saveButton.autoSetDimension(.height, toSize: 60)

        imageView.autoPinEdge(.bottom, to: .top, of: saveButton, withOffset: -padding)
        imageView.autoPinEdge(toSuperviewEdge: .leading, withInset: padding)
        imageView.autoPinEdge(toSuperviewEdge: .trailing, withInset: padding)
        imageView.autoPinEdge(toSuperviewEdge: .top, withInset: padding + 20)

        label.autoPinEdge(.leading, to: .leading, of: imageView)
        label.autoPinEdge(.trailing, to: .trailing, of: imageView)
        label.autoPinEdge(.top, to: .top, of: imageView)
        label.autoPinEdge(.bottom, to: .bottom, of: imageView)

        let tapGestureRecog = UITapGestureRecognizer(target: self, action: #selector(imagePressed))
        imageView.addGestureRecognizer(tapGestureRecog)

    }

    fileprivate func filterImage() {
        rgbFilter.rgbCompositeControlPoints = items[0].points.map({ NSValue(cgPoint: $0) })
        rgbFilter.redControlPoints = items[1].points.map({ NSValue(cgPoint: $0) })
        rgbFilter.greenControlPoints = items[2].points.map({ NSValue(cgPoint: $0) })
        rgbFilter.blueControlPoints = items[3].points.map({ NSValue(cgPoint: $0) })
        sourceImage.processImage()
    }

    func changedCurve() {
        let newItem = items[segmenetedControl.selectedSegmentIndex]
        curveView.setup(with: newItem)
    }

    func imagePressed() {
        let handler = CameraHandler(delegate: self)
        handler.getPhotoLibraryOn(self, canEdit: false)
    }

    func savePressed() {
        guard let currentImage = currentImage,
            let filteredImage = rgbFilter.image(byFilteringImage: currentImage) else { return }
        PHPhotoLibrary.shared().performChanges({
            PHAssetCreationRequest.creationRequestForAsset(from: filteredImage)
        }) { [weak self] (success, error) in
            if success {
                let alert = UIAlertController(title: "Success", message: nil, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
                self?.present(alert, animated: true, completion: nil)
            } else {
                print("failed with \(String(describing: error))")
            }
        }
    }

    func saveComplete() { }
}

extension ViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        if let image = info[UIImagePickerControllerOriginalImage] as? UIImage {
            set(image)
        } else {
            print("Unable to get image")
        }
        picker.dismiss(animated: true, completion: nil)
    }

    func set(_ image: UIImage) {
        saveButton.isHidden = false
        items = [CurveViewModel.Curve.all, .red, .green, .blue].map({ CurveViewModel($0) })
        currentImage = image
        sourceImage = GPUImagePicture(image: image)
        sourceImage.addTarget(rgbFilter)
        rgbFilter.addTarget(imageView)
        sourceImage.processImage()
    }

}

extension ViewController: CurveViewDelegate {

    func valueChanged(pointIndex: Int, value: CGPoint) {
        let segIndex = segmenetedControl.selectedSegmentIndex
        items[segIndex].points[pointIndex] = value
        filterImage()
    }

}
