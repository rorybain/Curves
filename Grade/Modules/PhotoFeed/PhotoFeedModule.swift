//
//  PhotoFeedModule.swift
//  Grade
//
//  Created by Rory Bain on 30/07/2017.
//  Copyright © 2017 Rory Bain. All rights reserved.
//

import UIKit

struct PhotoFeedModule {

    static func build() -> UIViewController {
        let viewController = PhotoFeedViewController()
        let wireframe = PhotoFeedWireframe()
        let viewModel = PhotoFeedViewModel(view: viewController, wireframe: wireframe)

        viewController.viewModel = viewModel
        wireframe.viewController = viewController

        return viewController
    }

}
