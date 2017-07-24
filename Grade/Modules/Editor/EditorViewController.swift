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

class EditorViewController: UIViewController {

    let padding: CGFloat = 16

    let curveView = CurveView()

    var currentImage: UIImage?
    var selectedLivePhotoUrl: URL?

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

    var sourceImage: GPUImagePicture?
    let rgbFilter = GPUImageToneCurveFilter()
    var exportFilter = GPUImageToneCurveFilter()

    var items = [CurveDataItem.Curve.all, .red, .green, .blue].map({ CurveDataItem($0) })

    var segmenetedControl: UISegmentedControl!

    var movie: GPUImageMovie?
    var exportMovie: GPUImageMovie?
    var writer: GPUImageMovieWriter?
    var timer: Timer?

    fileprivate func setupCurveView() {
        curveView.autoPinEdge(toSuperviewEdge: .leading, withInset: padding)
        curveView.autoPinEdge(toSuperviewEdge: .trailing, withInset: padding)
        curveView.autoSetDimension(.height, toSize: 250)
        curveView.autoPinEdge(.bottom, to: .top, of: segmenetedControl, withOffset: -padding)
    }

    fileprivate func setupSaveButton() {
        saveButton.autoPinEdge(toSuperviewEdge: .trailing, withInset: padding)
        saveButton.autoPinEdge(.bottom, to: .top, of: curveView, withOffset: 0)
        saveButton.autoSetDimension(.height, toSize: 60)
    }

    fileprivate func setupImageView() {
        imageView.autoPinEdge(.bottom, to: .top, of: saveButton, withOffset: -padding)
        imageView.autoPinEdge(toSuperviewEdge: .leading, withInset: padding)
        imageView.autoPinEdge(toSuperviewEdge: .trailing, withInset: padding)
        imageView.autoPinEdge(toSuperviewEdge: .top, withInset: padding + 20)
    }

    fileprivate func setupLabel() {
        label.autoPinEdge(.leading, to: .leading, of: imageView)
        label.autoPinEdge(.trailing, to: .trailing, of: imageView)
        label.autoPinEdge(.top, to: .top, of: imageView)
        label.autoPinEdge(.bottom, to: .bottom, of: imageView)
    }

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

        setupCurveView()
        setupSaveButton()
        setupImageView()
        setupLabel()

        let tapGestureRecog = UITapGestureRecognizer(target: self, action: #selector(imagePressed))
        imageView.addGestureRecognizer(tapGestureRecog)

        if let selectedLivePhotoUrl = selectedLivePhotoUrl {
            processVideo(selectedLivePhotoUrl)
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        timer?.invalidate()
    }

    fileprivate func filterImage() {
        rgbFilter.rgbCompositeControlPoints = items[0].points.map({ NSValue(cgPoint: $0) })
        rgbFilter.redControlPoints = items[1].points.map({ NSValue(cgPoint: $0) })
        rgbFilter.greenControlPoints = items[2].points.map({ NSValue(cgPoint: $0) })
        rgbFilter.blueControlPoints = items[3].points.map({ NSValue(cgPoint: $0) })
        sourceImage?.processImage()
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
        if let currentImage = currentImage {
            saveImage(currentImage)
        } else if let movie = movie {
            saveMovie(movie)
        }
    }

    private func saveImage(_ currentImage: UIImage) {
        guard let filteredImage = rgbFilter.image(byFilteringImage: currentImage) else { return }
        PHPhotoLibrary.shared().performChanges({
            PHAssetCreationRequest.creationRequestForAsset(from: filteredImage)
        }) { [weak self] (success, error) in
            if success {
                self?.showFinishedSavingMessage()
            } else {
                print("failed with \(String(describing: error))")
            }
        }
    }

    private func saveMovie(_ movie: GPUImageMovie) {

        exportMovie?.removeAllTargets()
//        rgbFilter.removeAllTargets()
//        movie.removeAllTargets()
        self.writer?.endProcessing()
//        self.movie?.endProcessing()
        self.exportMovie?.endProcessing()
        self.exportMovie = nil
        self.writer = nil

        exportFilter = GPUImageToneCurveFilter() // if i don't make a new curve filter then video did end processing seems to not call
        exportFilter.rgbCompositeControlPoints = rgbFilter.rgbCompositeControlPoints
        exportFilter.redControlPoints = rgbFilter.redControlPoints
        exportFilter.greenControlPoints = rgbFilter.greenControlPoints
        exportFilter.blueControlPoints = rgbFilter.blueControlPoints

        guard let exportMovie = GPUImageMovie(url: movie.url) else { return }
        self.exportMovie = exportMovie
        exportMovie.shouldRepeat = false
        exportMovie.playAtActualSpeed = false
        exportMovie.addTarget(exportFilter)

        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let url = docs.appendingPathComponent("Movie.m4v")

        unlink(url.path)
        print(url)

        let asset = AVURLAsset(url: exportMovie.url)
        let assetTrack = asset.tracks(withMediaType: AVMediaTypeVideo).first
        let size = assetTrack?.naturalSize ?? .zero
        guard let writer = GPUImageMovieWriter(movieURL: url, size: size) else { fatalError("failed to create writer") }
        self.writer = writer

        exportFilter.addTarget(writer)
        writer.encodingLiveVideo = false
        writer.shouldPassthroughAudio = false
        writer.delegate = self
        //        movie.audioEncodingTarget = writer
        //        movie.enableSynchronizedEncoding(using: writer)
        writer.startRecording()
        exportMovie.startProcessing()
        timer = Timer.scheduledTimer(timeInterval: 0.3, target: self,
                                     selector: #selector(updateProgress), userInfo: nil, repeats: true)

        writer.completionBlock = { [ weak self] in
            print("Success")
            guard let writer = self?.writer else { fatalError("writer is nil!!") }
//            self?.rgbFilter.removeTarget(writer)
            self?.exportFilter.removeTarget(writer)
            writer.finishRecording()
            self?.writeFileToCameraRoll(atURL: url)
        }

        writer.failureBlock = { error in
            print("ERROROROROROR")
            print(error)
        }

    }

    func updateProgress() {
        print("progress is \(String(describing: exportMovie?.progress))")
    }

    private func writeFileToCameraRoll(atURL url: URL) {
        PHPhotoLibrary.shared().performChanges({
            PHAssetCreationRequest.creationRequestForAssetFromVideo(atFileURL: url)
        }) { [weak self] (success, error) in
            if success {
                self?.showFinishedSavingMessage()
            } else {
                print("failed with \(String(describing: error))")
            }
        }
    }

    private func showFinishedSavingMessage() {
        DispatchQueue.main.async { [weak self] in
            self?.timer?.invalidate()
            let alert = UIAlertController(title: "Finished recording", message: nil, preferredStyle: .alert)
            let ok = UIAlertAction(title: "Ok", style: .default, handler: nil)
            alert.addAction(ok)
            self?.present(alert, animated: true, completion: nil)
        }
    }

}

extension EditorViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {

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
        saveButton.isHidden = false
        movie?.removeTarget(rgbFilter)
        sourceImage?.removeTarget(rgbFilter)
        movie = nil

        guard let movie = GPUImageMovie(url: videoURL) else { return }
        self.movie = movie

        items = [CurveDataItem.Curve.all, .red, .green, .blue].map({ CurveDataItem($0) })
        movie.playAtActualSpeed = true
        movie.shouldRepeat = true
        movie.addTarget(rgbFilter)
        rgbFilter.addTarget(imageView)
        movie.startProcessing()
    }

    func set(_ image: UIImage) {
        movie?.removeTarget(rgbFilter)
        sourceImage?.removeTarget(rgbFilter)
        movie = nil

        saveButton.isHidden = false
        items = [CurveDataItem.Curve.all, .red, .green, .blue].map({ CurveDataItem($0) })
        currentImage = image
        sourceImage = GPUImagePicture(image: image)
        guard let sourceImage = sourceImage else { return }

        sourceImage.addTarget(rgbFilter)
        rgbFilter.addTarget(imageView)
        sourceImage.processImage()
    }

}

extension EditorViewController: CurveViewDelegate {

    func valueChanged(pointIndex: Int, value: CGPoint) {
        let segIndex = segmenetedControl.selectedSegmentIndex
        items[segIndex].points[pointIndex] = value
        filterImage()
    }

}

extension EditorViewController: GPUImageMovieWriterDelegate {

    func movieRecordingCompleted() {
        writer?.finishRecording()
        print("Movie recording completed")
    }

    func movieRecordingFailedWithError(_ error: Error!) {
        writer?.finishRecording()
        print("movie recording failed")
    }

}
