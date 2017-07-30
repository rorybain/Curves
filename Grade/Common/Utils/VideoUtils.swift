//
//  VideoUtils.swift
//  Grade
//
//  Created by Rory Bain on 30/07/2017.
//  Copyright © 2017 Rory Bain. All rights reserved.
//

import AVFoundation

struct VideoUtils {

    static func reverse(_ original: AVAsset,
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

    static func mergeAssets(_ assets: [AVAsset],
                            completion: @escaping (URL) -> Void) {

        let videoComposition = AVMutableComposition()
        var lastTime: CMTime = kCMTimeZero

        let videoCompositionTrack = videoComposition
            .addMutableTrack(withMediaType: AVMediaTypeVideo,
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
        videoCompositionTrack.scaleTimeRange(CMTimeRangeMake(kCMTimeZero, lastTime),
                                             toDuration: CMTimeMultiplyByFloat64(lastTime, 0.5))
        
        let path = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        let mainVideoURL = path?.appendingPathComponent("joined.mov")
        unlink(mainVideoURL?.path)

        guard let exporter = AVAssetExportSession(asset: videoComposition,
                                                  presetName: AVAssetExportPresetHighestQuality) else { return }
        exporter.outputURL = mainVideoURL
        exporter.outputFileType = AVFileTypeQuickTimeMovie

        exporter.exportAsynchronously {
            completion(mainVideoURL!)
        }
    }

}
