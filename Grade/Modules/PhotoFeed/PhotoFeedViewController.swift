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

protocol PhotoFeedViewInput: class {

}

class PhotoFeedViewController: UICollectionViewController, UICollectionViewDelegateFlowLayout {

    var viewModel: PhotoFeedViewOutput!

    fileprivate let imageManager = PHCachingImageManager()
    fileprivate let queue: DispatchQueue
    fileprivate let fetchResult: PHFetchResult<PHAsset> = {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "mediaSubtype == %ld", PHAssetMediaSubtype.photoLive.rawValue)
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        return PHAsset.fetchAssets(with: options)
    }()

    init() {
        self.queue = DispatchQueue(label: "com.grade.prewarm", qos: .default, attributes: [.concurrent],
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

        let width = view.frame.width
        let heightRatio = width / CGFloat(asset.pixelWidth)
        let height = CGFloat(asset.pixelHeight) * heightRatio

        if let currRequest = cell.currentRequest {
            imageManager.cancelImageRequest(currRequest)
        }

        let options = PHLivePhotoRequestOptions()
        options.deliveryMode = .opportunistic
        options.isNetworkAccessAllowed = true

        cell.currentRequest = imageManager.requestLivePhoto(for: asset,
                                                            targetSize:  CGSize(width: width, height: height),
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
        let size = view.frame.size
        queue.async {
            self.imageManager.startCachingImages(for: indexPaths.map { self.fetchResult.object(at: $0.item) },
                                                 targetSize:  size,
                                                 contentMode: .aspectFit,
                                                 options: nil)
        }
    }

    func collectionView(_ collectionView: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
        let size = view.frame.size
        queue.async {
            self.imageManager.stopCachingImages(for: indexPaths.map { self.fetchResult.object(at: $0.item) },
                                                targetSize:  size,
                                                contentMode: .aspectFit,
                                                options: nil)
        }
    }

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let asset = fetchResult.object(at: indexPath.item)
        viewModel.didSelectAsset(asset)
    }

}

extension PhotoFeedViewController: PhotoFeedViewInput {

}
