//
//  Wireframe.swift
//  Grade
//
//  Created by Rory Bain on 30/07/2017.
//  Copyright © 2017 Rory Bain. All rights reserved.
//

import UIKit

class PhotoFeedWireframe {

    weak var viewController: PhotoFeedViewController!

    func goToEditor(andOpen url: URL) {
        let nextViewController = EditorViewController()
        nextViewController.selectedLivePhotoUrl = url
        viewController.navigationController?.pushViewController(nextViewController, animated: true)
    }

}
