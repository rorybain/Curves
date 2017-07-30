//
//  PhotoFeedViewModel.swift
//  Grade
//
//  Created by Rory Bain on 30/07/2017.
//  Copyright © 2017 Rory Bain. All rights reserved.
//

protocol PhotoFeedViewOutput: class {
    func didSelectAsset(_ asset: PHAsset)
}

import Foundation
import Photos

class PhotoFeedViewModel {

    weak var view: PhotoFeedViewInput!
    fileprivate let wireframe: PhotoFeedWireframe!

    fileprivate let filesPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    fileprivate let assetResourceManager: PHAssetResourceManager

    init(view: PhotoFeedViewInput,
         wireframe: PhotoFeedWireframe,
         assetResourceManager: PHAssetResourceManager = PHAssetResourceManager.default()) {
        self.view = view
        self.wireframe = wireframe
        self.assetResourceManager = assetResourceManager
    }

    fileprivate func createReversedVideo(from asset: AVAsset) {
        let reverseUrl = filesPath.appendingPathComponent("reverse.m4v")
        unlink(reverseUrl.path)

        VideoUtils.reverse(asset, outputURL: reverseUrl) { [weak self] reversedAsset in
            self?.concatenateVideos([asset, reversedAsset])
        }
    }

    fileprivate func concatenateVideos(_ assets: [AVAsset]) {
        VideoUtils.mergeAssets(assets) { [weak self] concatenatedAssetURL in
            self?.goToEditor(url: concatenatedAssetURL)
        }
    }

    fileprivate func goToEditor(url: URL) {
        DispatchQueue.main.async { [weak self] in
            self?.wireframe.goToEditor(andOpen: url)
        }
    }

}

extension PhotoFeedViewModel: PhotoFeedViewOutput {

    func didSelectAsset(_ asset: PHAsset) {
        let resources = PHAssetResource.assetResources(for: asset)

        let actualUrl = filesPath.appendingPathComponent("live.m4v")
        unlink(actualUrl.path)

        PHAssetResourceManager.default()
            .writeData(for: resources[1], toFile: actualUrl, options: nil) { [weak self] error in
                guard error == nil else {
                    print(error as Any)
                    // tODO error message
                    return
                }

                self?.createReversedVideo(from: AVAsset(url: actualUrl))
        }
    }

}
