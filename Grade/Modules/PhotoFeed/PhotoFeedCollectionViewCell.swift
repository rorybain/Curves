//
//  PhotoFeedCollectionViewCell.swift
//  Grade
//
//  Created by Rory Bain on 19/07/2017.
//  Copyright © 2017 Rory Bain. All rights reserved.
//

import UIKit
import PhotosUI
import PureLayout

class PhotoFeedCollectionViewCell: UICollectionViewCell {

    fileprivate let imageView = PHLivePhotoView.newAutoLayout()
    var currentRequest: PHLivePhotoRequestID?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupViews()
    }

    private func setupViews() {
        contentView.addSubview(imageView)
        imageView.autoPinEdgesToSuperviewEdges()
        imageView.isMuted = true
        imageView.delegate = self
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.livePhoto = nil
    }

}

// Public methods

extension PhotoFeedCollectionViewCell {

    func setup(with photo: PHLivePhoto?) {
        imageView.livePhoto = photo
        imageView.startPlayback(with: .hint)
    }

}

extension PhotoFeedCollectionViewCell: PHLivePhotoViewDelegate {

    func livePhotoView(_ livePhotoView: PHLivePhotoView,
                       didEndPlaybackWith playbackStyle: PHLivePhotoViewPlaybackStyle) {
        livePhotoView.startPlayback(with: .hint)
    }

}
