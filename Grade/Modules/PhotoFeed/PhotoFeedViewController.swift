//
//  PhotoFeedViewController.swift
//  Grade
//
//  Created by Rory Bain on 19/07/2017.
//  Copyright © 2017 Rory Bain. All rights reserved.
//

import Foundation
import UIKit
import PhotosUI
import Photos
import AVFoundation

class PhotoFeedViewController: UICollectionViewController, UICollectionViewDelegateFlowLayout {

    fileprivate let imageManager = PHCachingImageManager()
    fileprivate let queue: DispatchQueue
    fileprivate let fetchResult: PHFetchResult<PHAsset> = {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "mediaSubtype == %ld", PHAssetMediaSubtype.photoLive.rawValue)
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        return PHAsset.fetchAssets(with: options)
    }()

    init() {
        self.queue = DispatchQueue(label: "com.photo.prewarm", qos: .default, attributes: [.concurrent],
                                   autoreleaseFrequency: .inherit, target: nil)
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        super.init(collectionViewLayout: layout)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        collectionView?.backgroundColor = .white
        collectionView?.register(PhotoFeedCollectionViewCell.self)
        collectionView?.isPrefetchingEnabled = true
        collectionView?.prefetchDataSource = self
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        let asset = fetchResult.object(at: indexPath.item)
        let heightRatio = view.frame.width / CGFloat(asset.pixelWidth)
        let height = CGFloat(asset.pixelHeight) * heightRatio
        return CGSize(width: view.frame.width, height: height)
    }

}

extension PhotoFeedViewController {

    override func collectionView(_ collectionView: UICollectionView,
                                 cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell: PhotoFeedCollectionViewCell = collectionView.dequeueReusableCell(forIndexPath: indexPath)
        let asset = fetchResult.object(at: indexPath.item)

        let heightRatio = view.frame.width / CGFloat(asset.pixelWidth)
        let height = CGFloat(asset.pixelHeight) * heightRatio

        if let currRequest = cell.currentRequest {
            imageManager.cancelImageRequest(currRequest)
        }

        let options = PHLivePhotoRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true

        imageManager.requestLivePhoto(for: asset,
                                      targetSize:  CGSize(width: self.view.frame.width, height: height),
                                      contentMode: .default,
                                      options: nil) { (livePhoto, _) in
                                        cell.setup(with: livePhoto)
        }

        return cell
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return fetchResult.count
    }

    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

}

extension PhotoFeedViewController: UICollectionViewDataSourcePrefetching {

    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        let size = CGSize(width: self.view.frame.width, height: self.view.frame.height)
        queue.async {
            self.imageManager.startCachingImages(for: indexPaths.map {
                self.fetchResult.object(at: $0.item)
                }, targetSize:  size,
                   contentMode: .aspectFit, options: nil)
        }
    }

    func collectionView(_ collectionView: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
        let size = CGSize(width: self.view.frame.width, height: self.view.frame.height)
        queue.async {
            self.imageManager.stopCachingImages(for: indexPaths.map {
                self.fetchResult.object(at: $0.item)
                }, targetSize:  size,
                   contentMode: .aspectFit, options: nil)
        }
    }

}

extension PhotoFeedViewController {

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let asset = fetchResult.object(at: indexPath.item)
        let resources = PHAssetResource.assetResources(for: asset)
        let time = Date()
        let path = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        let actualUrl = path?.appendingPathComponent("live.m4v")
        let reverseUrl = path?.appendingPathComponent("reverse.m4v")
        unlink(actualUrl!.path)
        unlink(reverseUrl!.path)

        PHAssetResourceManager.default()
            .writeData(for: resources[1],
                       toFile: actualUrl!,
                       options: nil) { [weak self] (error) in
                        if error == nil {
                            let asset = AVAsset(url: actualUrl!)
                            PhotoFeedViewController.reverse(asset,
                                                            outputURL: reverseUrl!,
                                                            completion: { (returnAsset) in
                                                                PhotoFeedViewController.mergeAssets([asset, returnAsset],
                                                                                                    completion: { (combinedAssetsURL) in
                                                                                                        DispatchQueue.main.async { [weak self] in
                                                                                                            self?.goToEditor(andOpen: combinedAssetsURL)

                                                                                                        }
                                                                })
                                                                print("got asset!!")
                            })
                            //                                                        self?.goToEditor(andOpen: actualUrl!)
                        }
                        print("completed in \(time.timeIntervalSinceNow)" +
                            " with error: \(String(describing: error))")
        }

        //        PHAssetResourceManager.default().requestData(for: resources[1],
        //                                                     options: nil,
        //                                                     dataReceivedHandler: { (data) in
        //                                                        print("got asset in \(time.timeIntervalSinceNow)")
        //        }) { (error) in
        //            print("Failed with \(error)")
        //        }
    }

    private func goToEditor(andOpen url: URL) {
        let nextViewController = EditorViewController()
        nextViewController.selectedLivePhotoUrl = url
        navigationController?.pushViewController(nextViewController, animated: true)
    }

    private static func reverse(_ original: AVAsset,
                                outputURL: URL,
                                completion: @escaping (AVAsset) -> Void) {
        var reader: AVAssetReader! = nil
        do {
            reader = try AVAssetReader(asset: original)
        } catch {
            print("could not initialize reader.")
            return
        }

        guard let videoTrack = original.tracks(withMediaType: AVMediaTypeVideo).last else {
            print("could not retrieve the video track.")
            return
        }

        let readerOutputSettings: [String: Any] = [kCVPixelBufferPixelFormatTypeKey as String:
            Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)]
        let readerOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: readerOutputSettings)
        reader.add(readerOutput)

        reader.startReading()

        // read in samples

        var samples: [CMSampleBuffer] = []
        while let sample = readerOutput.copyNextSampleBuffer() {
            samples.append(sample)
        }

        // Initialize the writer

        let writer: AVAssetWriter
        do {
            writer = try AVAssetWriter(outputURL: outputURL, fileType: AVFileTypeQuickTimeMovie)
        } catch let error {
            fatalError(error.localizedDescription)
        }

        let videoCompositionProps = [AVVideoAverageBitRateKey: videoTrack.estimatedDataRate]
        let writerOutputSettings = [
            AVVideoCodecKey: AVVideoCodecH264,
            AVVideoWidthKey: videoTrack.naturalSize.width,
            AVVideoHeightKey: videoTrack.naturalSize.height,
            AVVideoCompressionPropertiesKey: videoCompositionProps
            ] as [String : Any]

        let writerInput = AVAssetWriterInput(mediaType: AVMediaTypeVideo, outputSettings: writerOutputSettings)
        writerInput.expectsMediaDataInRealTime = false
        writerInput.transform = videoTrack.preferredTransform

        let pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: writerInput,
                                                                      sourcePixelBufferAttributes: nil)

        writer.add(writerInput)
        writer.startWriting()
        writer.startSession(atSourceTime: CMSampleBufferGetPresentationTimeStamp(samples.first!))

        for (index, sample) in samples.enumerated() {
            let presentationTime = CMSampleBufferGetPresentationTimeStamp(sample)
            let imageBufferRef = CMSampleBufferGetImageBuffer(samples[samples.count - 1 - index])
            while !writerInput.isReadyForMoreMediaData {
                Thread.sleep(forTimeInterval: 0.1)
            }
            pixelBufferAdaptor.append(imageBufferRef!, withPresentationTime: presentationTime)

        }

        writer.finishWriting {
            completion(AVAsset(url: outputURL))
        }
    }

    private static func mergeAssets(_ assets: [AVAsset],
                                    completion: @escaping (URL) -> Void) {

        let videoComposition = AVMutableComposition()
        var lastTime: CMTime = kCMTimeZero

        let videoCompositionTrack = videoComposition.addMutableTrack(withMediaType: AVMediaTypeVideo,
                                                                     preferredTrackID: Int32(kCMPersistentTrackID_Invalid))

        for clipIndex in assets {

            do {
                try videoCompositionTrack.insertTimeRange(CMTimeRangeMake(kCMTimeZero, clipIndex.duration),
                                                          of: clipIndex.tracks(withMediaType: AVMediaTypeVideo)[0] ,
                                                          at: lastTime)
                lastTime = CMTimeAdd(lastTime, clipIndex.duration)
            } catch {
                print("Failed to insert track")
            }
        }

        let path = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        let mainVideoURL = path?.appendingPathComponent("joined.mov")
        unlink(mainVideoURL?.path)

        guard let exporter = AVAssetExportSession(asset: videoComposition,
                                                  presetName: AVAssetExportPresetHighestQuality) else { return }
        exporter.outputURL = mainVideoURL
        exporter.outputFileType = AVFileTypeQuickTimeMovie

        exporter.exportAsynchronously() {
            completion(mainVideoURL!)
        }
    }

}
