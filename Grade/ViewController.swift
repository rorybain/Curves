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

    var imageMovie: GPUImageMovie?
    var writer: GPUImageMovieWriter?

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

}

extension ViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        if let videoURL = info[UIImagePickerControllerMediaURL] as? URL {
            picker.dismiss(animated: true, completion: { [weak self] in
                self?.processVideo(videoURL)
            })

        }

        if let image = info[UIImagePickerControllerOriginalImage] as? UIImage {
            set(image)
        }
        picker.dismiss(animated: true, completion: nil)
    }

    func processVideo(_ videoURL: URL) {
        saveButton.isHidden = true
        imageMovie?.removeTarget(rgbFilter)
        imageMovie = nil
        imageMovie = GPUImageMovie(url: videoURL)
        imageMovie?.playAtActualSpeed = true
        imageMovie?.shouldRepeat = true
        imageMovie?.addTarget(rgbFilter)
        rgbFilter.addTarget(imageView)
        let path = NSHomeDirectory().appending("Documents/Movie.m4v")
        //        unlink([path.utf8String])
        do {
            try FileManager.default.removeItem(atPath: path)
        } catch let error {
            print("failed to delete \(error)")
        }


        //        let url = URL(fileURLWithPath: path)
        //        writer = GPUImageMovieWriter(movieURL: url, size: CGSize(width: 640, height: 480))
        //        rgbFilter.addTarget(writer)
        //        writer?.shouldPassthroughAudio = true
        //        imageMovie?.audioEncodingTarget = writer
        //        imageMovie?.enableSynchronizedEncoding(using: writer)

        //        writer?.startRecording()
        imageMovie?.startProcessing()

        //        writer?.completionBlock = { [weak self] in
        //            guard let `self` = self,
        //                let writer = self.writer else { return }
        //            self.rgbFilter.removeTarget(writer)
        //            writer.finishRecording()
        //
        //            let alert = UIAlertController(title: "Finished recording", message: nil, preferredStyle: .alert)
        //            let ok = UIAlertAction(title: "Ok", style: .default, handler: nil)
        //            alert.addAction(ok)
        //            self.present(alert, animated: true, completion: nil)
        //        }

        //        imageMovie?.addTarget(rgbFilter)
        //        let path = NSHomeDirectory().appending("Documents/Movie.m4v")
        //        //unlink(path)
        //        let url = URL(fileURLWithPath: path)
        //        let writer = GPUImageMovieWriter(movieURL: url, size: CGSize(width: 480, height: 640))
        //        rgbFilter.addTarget(writer)
        //        writer?.shouldPassthroughAudio = true
        //        imageMovie?.audioEncodingTarget = writer
        //        imageMovie?.enableSynchronizedEncoding(using: writer)
        //        writer?.startRecording()
        //        imageMovie?.startProcessing()
        //        writer?.completionBlock = { [weak self] in
        //            self?.rgbFilter.removeTarget(writer)
        //            writer?.finishRecording()
        //
        //            let alert = UIAlertController(title: "Finished recording", message: nil, preferredStyle: .alert)
        //            let ok = UIAlertAction(title: "Ok", style: .default, handler: nil)
        //            alert.addAction(ok)
        //            self?.present(alert, animated: true, completion: nil)
        //        }

    }

    func set(_ image: UIImage) {
        imageMovie?.removeTarget(rgbFilter)
        imageMovie = nil
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
