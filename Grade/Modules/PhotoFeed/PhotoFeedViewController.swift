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
        unlink(actualUrl!.path)

        PHAssetResourceManager.default().writeData(for: resources[1],
                                                   toFile: actualUrl!,
                                                   options: nil) { [weak self] (error) in
                                                    if error == nil {
                                                        self?.goToEditor(andOpen: actualUrl!)
                                                    }
                                                    print("completed in \(time.timeIntervalSinceNow)" +
                                                        " with error: \(error)")
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

}
