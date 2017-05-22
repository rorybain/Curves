//
//  CameraHandler.swift
//  Grade
//
//  Created by Rory Bain on 21/05/2017.
//  Copyright © 2017 Rory Bain. All rights reserved.
//

import Foundation
import MobileCoreServices
import UIKit

class CameraHandler: NSObject {

    private let imagePicker = UIImagePickerController()
    private let isPhotoLibraryAvailable = UIImagePickerController.isSourceTypeAvailable(.photoLibrary)
    private let isSavedPhotoAlbumAvailable = UIImagePickerController.isSourceTypeAvailable(.savedPhotosAlbum)
    private let isCameraAvailable = UIImagePickerController.isSourceTypeAvailable(.camera)
    private let isRearCameraAvailable = UIImagePickerController.isCameraDeviceAvailable(.rear)
    private let isFrontCameraAvailable = UIImagePickerController.isCameraDeviceAvailable(.front)
    private let sourceTypeCamera = UIImagePickerControllerSourceType.camera
    private let rearCamera = UIImagePickerControllerCameraDevice.rear
    private let frontCamera = UIImagePickerControllerCameraDevice.front

    weak var delegate: (UINavigationControllerDelegate & UIImagePickerControllerDelegate)?

    init(delegate: UINavigationControllerDelegate & UIImagePickerControllerDelegate) {
        self.delegate = delegate
    }

    func getPhotoLibraryOn(_ onVC: UIViewController, canEdit: Bool) {
        imagePicker.allowsEditing = canEdit
        imagePicker.mediaTypes = UIImagePickerController.availableMediaTypes(for: .photoLibrary) ?? []
        imagePicker.delegate = delegate
        onVC.present(imagePicker, animated: true, completion: nil)
    }

    func getCameraOn(_ onVC: UIViewController, canEdit: Bool) {

        if !isCameraAvailable { return }
        let type1 = kUTTypeImage as String

        if isCameraAvailable {
            if let availableTypes = UIImagePickerController.availableMediaTypes(for: .camera) {
                if availableTypes.contains(type1) {
                    imagePicker.mediaTypes = [type1]
                    imagePicker.sourceType = sourceTypeCamera
                }
            }

            if isRearCameraAvailable {
                imagePicker.cameraDevice = rearCamera
            } else if isFrontCameraAvailable {
                imagePicker.cameraDevice = frontCamera
            }
        } else {
            return
        }

        imagePicker.allowsEditing = canEdit
        imagePicker.showsCameraControls = true
        imagePicker.delegate = delegate
        onVC.present(imagePicker, animated: true, completion: nil)
    }
}
