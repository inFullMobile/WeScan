//
//  ScannerViewController.swift
//  WeScan
//
//  Created by Boris Emorine on 2/8/18.
//  Copyright © 2018 WeTransfer. All rights reserved.
//

import UIKit
import AVFoundation

struct PreviewConst {
    let horizontalMargin: CGFloat = 12.0
    let navigationBarHeight: CGFloat = 34.0
    let previewRectRatio: CGFloat = 537.0 / 388.0
    private(set) var parentViewBounds: CGRect = .zero
    private(set) var previewFrame: CGRect = .zero

    var topMargin: CGFloat {
        return previewFrame.origin.y
    }
    var bottomMargin: CGFloat {
        return parentViewBounds.height - previewFrame.height - previewFrame.origin.y
    }
    mutating func updateWithParent(viewBounds: CGRect) {
        parentViewBounds = viewBounds
        previewFrame = centeredRect(in: viewBounds)
    }
    private func centeredRect(in bounds: CGRect) -> CGRect {
        let width = bounds.width - 2 * horizontalMargin
        let height = width / previewRectRatio
        let size = CGSize(width: width, height: height)
        let verticalMargin = (bounds.height - size.height) / 2.0 - navigationBarHeight
        return CGRect(x: horizontalMargin, y: verticalMargin, width: size.width, height: size.height)
    }
}

/// The `ScannerViewController` offers an interface to give feedback to the user regarding quadrilaterals that are detected. It also gives the user the opportunity to capture an image with a detected rectangle.
final class ScannerViewController: UIViewController {
    
    private var captureSessionManager: CaptureSessionManager?
    private lazy var videoPreviewLayer: AVCaptureVideoPreviewLayer = {
        let layer = AVCaptureVideoPreviewLayer()
        layer.cornerRadius = 8
        return layer
    }()
    
    /// The view that shows the focus rectangle (when the user taps to focus, similar to the Camera app)
    private var focusRectangle: FocusRectangleView!
    
    /// The view that draws the detected rectangles (It's just for preview). It's size is used to calculate position of quadrilaterals.
    private let quadView = QuadrilateralView()
        
    /// Whether flash is enabled
    private var flashEnabled = false
    
    /// The original bar style that was set by the host app
    private var originalBarStyle: UIBarStyle?
    
    private var quadViewTopConstraint: NSLayoutConstraint?
    private var quadViewBottomConstraint: NSLayoutConstraint?
    
    /// Contains preview frame. It is used to set preview scanner size.
    private var previewConst = PreviewConst()
    
    private lazy var shutterButton: ShutterButton = {
        let button = ShutterButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(captureImage(_:)), for: .touchUpInside)
        return button
    }()
    
    private lazy var cancelButton: UIButton = {
        let button = UIButton()
        button.setTitle(NSLocalizedString("wescan.scanning.cancel", tableName: nil, bundle: Bundle(for: ScannerViewController.self), value: "Cancel", comment: "The cancel button"), for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(cancelImageScannerController), for: .touchUpInside)
        return button
    }()
    
    private lazy var autoScanButton: UIBarButtonItem = {
        let title = NSLocalizedString("wescan.scanning.auto", tableName: nil, bundle: Bundle(for: ScannerViewController.self), value: "Auto", comment: "The auto button state")
        let button = UIBarButtonItem(title: title, style: .plain, target: self, action: #selector(toggleAutoScan))
        button.tintColor = .white
        
        return button
    }()
    
    private lazy var flashButton: UIBarButtonItem = {
        let image = UIImage(named: "flash", in: Bundle(for: ScannerViewController.self), compatibleWith: nil)
        let button = UIBarButtonItem(image: image, style: .plain, target: self, action: #selector(toggleFlash))
        button.tintColor = .white
        
        return button
    }()
    
    private lazy var activityIndicator: UIActivityIndicatorView = {
        let activityIndicator = UIActivityIndicatorView(style: .gray)
        activityIndicator.hidesWhenStopped = true
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        return activityIndicator
    }()
    
    private lazy var headerContainerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private lazy var headerView: ScannerHeaderView = {
        let view = ScannerHeaderView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    // MARK: - Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = nil
        
        setupViews()
        setupNavigationBar()
        setupConstraints()
        
        captureSessionManager = CaptureSessionManager(videoPreviewLayer: videoPreviewLayer, previewConst: previewConst)
        captureSessionManager?.delegate = self
        
        originalBarStyle = navigationController?.navigationBar.barStyle
        
        NotificationCenter.default.addObserver(self, selector: #selector(subjectAreaDidChange), name: Notification.Name.AVCaptureDeviceSubjectAreaDidChange, object: nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setNeedsStatusBarAppearanceUpdate()
        
        CaptureSession.current.isEditing = false
        quadView.removeQuadrilateral()
        captureSessionManager?.start()
        UIApplication.shared.isIdleTimerDisabled = true
        
        navigationController?.navigationBar.barStyle = .blackTranslucent
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        updatePreviewWithParent(viewBounds: view.layer.bounds)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        UIApplication.shared.isIdleTimerDisabled = false
        
        navigationController?.navigationBar.isTranslucent = false
        navigationController?.navigationBar.barStyle = originalBarStyle ?? .default
        captureSessionManager?.stop()
        guard let device = AVCaptureDevice.default(for: AVMediaType.video) else { return }
        if device.torchMode == .on {
            toggleFlash()
        }
    }
    
    // MARK: - Setups
    
    private func setupViews() {
        view.backgroundColor = .darkGray
        view.layer.addSublayer(videoPreviewLayer)
        quadView.translatesAutoresizingMaskIntoConstraints = false
        quadView.editable = false
        headerContainerView.addSubview(headerView)
        view.addSubview(quadView)
        view.addSubview(headerContainerView)
        view.addSubview(cancelButton)
        view.addSubview(shutterButton)
        view.addSubview(activityIndicator)
    }
    
    private func setupNavigationBar() {
        navigationItem.setLeftBarButton(flashButton, animated: false)
        navigationItem.setRightBarButton(autoScanButton, animated: false)
        
        if UIImagePickerController.isFlashAvailable(for: .rear) == false {
            let flashOffImage = UIImage(named: "flashUnavailable", in: Bundle(for: ScannerViewController.self), compatibleWith: nil)
            flashButton.image = flashOffImage
            flashButton.tintColor = UIColor.lightGray
        }
    }
    
    private func setupConstraints() {
        var quadViewConstraints = [NSLayoutConstraint]()
        var headerViewConstraints = [NSLayoutConstraint]()
        var cancelButtonConstraints = [NSLayoutConstraint]()
        var shutterButtonConstraints = [NSLayoutConstraint]()
        var activityIndicatorConstraints = [NSLayoutConstraint]()
        
        let quadViewTopConstraint = quadView.topAnchor.constraint(equalTo: view.topAnchor, constant: previewConst.topMargin)
        let quadViewBottomConstraint = quadView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -previewConst.bottomMargin)
        
        quadViewConstraints = [
            quadViewTopConstraint,
            quadViewBottomConstraint,
            view.trailingAnchor.constraint(equalTo: quadView.trailingAnchor, constant: previewConst.horizontalMargin),
            quadView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: previewConst.horizontalMargin)
        ]
        
        self.quadViewTopConstraint = quadViewTopConstraint
        self.quadViewBottomConstraint = quadViewBottomConstraint
        
        shutterButtonConstraints = [
            shutterButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            shutterButton.widthAnchor.constraint(equalToConstant: 65.0),
            shutterButton.heightAnchor.constraint(equalToConstant: 65.0)
        ]
        
        activityIndicatorConstraints = [
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ]
        
        if #available(iOS 11.0, *) {
            cancelButtonConstraints = [
                cancelButton.leftAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leftAnchor, constant: 24.0),
                view.safeAreaLayoutGuide.bottomAnchor.constraint(equalTo: cancelButton.bottomAnchor, constant: (65.0 / 2) - 10.0)
            ]
            
            let shutterButtonBottomConstraint = view.safeAreaLayoutGuide.bottomAnchor.constraint(equalTo: shutterButton.bottomAnchor, constant: 8.0)
            shutterButtonConstraints.append(shutterButtonBottomConstraint)
            
            headerViewConstraints = [
                headerContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: previewConst.horizontalMargin),
                headerContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -previewConst.horizontalMargin),
                headerContainerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: previewConst.horizontalMargin),
                headerContainerView.bottomAnchor.constraint(equalTo: quadView.topAnchor, constant: -previewConst.horizontalMargin),
                headerView.leadingAnchor.constraint(equalTo: headerContainerView.leadingAnchor),
                headerView.trailingAnchor.constraint(equalTo: headerContainerView.trailingAnchor),
                headerView.centerYAnchor.constraint(equalTo: headerContainerView.centerYAnchor)
            ]
            
        } else {
            cancelButtonConstraints = [
                cancelButton.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 24.0),
                view.bottomAnchor.constraint(equalTo: cancelButton.bottomAnchor, constant: (65.0 / 2) - 10.0)
            ]
            
            let shutterButtonBottomConstraint = view.bottomAnchor.constraint(equalTo: shutterButton.bottomAnchor, constant: 8.0)
            shutterButtonConstraints.append(shutterButtonBottomConstraint)
        }
        
        NSLayoutConstraint.activate(quadViewConstraints + cancelButtonConstraints + shutterButtonConstraints + activityIndicatorConstraints + headerViewConstraints)
    }
    
    private func updatePreviewWithParent(viewBounds: CGRect) {
        previewConst.updateWithParent(viewBounds: viewBounds)
        captureSessionManager?.previewConst = previewConst
        
        videoPreviewLayer.frame = previewConst.previewFrame
        
        quadViewTopConstraint?.constant = previewConst.topMargin
        quadViewBottomConstraint?.constant = -previewConst.bottomMargin
    }
    
    // MARK: - Tap to Focus
    
    /// Called when the AVCaptureDevice detects that the subject area has changed significantly. When it's called, we reset the focus so the camera is no longer out of focus.
    @objc private func subjectAreaDidChange() {
        /// Reset the focus and exposure back to automatic
        do {
            try CaptureSession.current.resetFocusToAuto()
        } catch {
            let error = ImageScannerControllerError.inputDevice
            guard let captureSessionManager = captureSessionManager else { return }
            captureSessionManager.delegate?.captureSessionManager(captureSessionManager, didFailWithError: error)
            return
        }
        
        /// Remove the focus rectangle if one exists
        CaptureSession.current.removeFocusRectangleIfNeeded(focusRectangle, animated: true)
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        
        guard  let touch = touches.first else { return }
        let touchPoint = touch.location(in: view)
        let convertedTouchPoint: CGPoint = videoPreviewLayer.captureDevicePointConverted(fromLayerPoint: touchPoint)
        
        CaptureSession.current.removeFocusRectangleIfNeeded(focusRectangle, animated: false)
        
        guard previewConst.previewFrame.contains(touchPoint) else {
            return
        }
        
        focusRectangle = FocusRectangleView(touchPoint: touchPoint)
        view.addSubview(focusRectangle)
        
        do {
            try CaptureSession.current.setFocusPointToTapPoint(convertedTouchPoint)
        } catch {
            let error = ImageScannerControllerError.inputDevice
            guard let captureSessionManager = captureSessionManager else { return }
            captureSessionManager.delegate?.captureSessionManager(captureSessionManager, didFailWithError: error)
            return
        }
    }
    
    // MARK: - Actions
    
    @objc private func captureImage(_ sender: UIButton) {
        (navigationController as? ImageScannerController)?.flashToBlack()
        shutterButton.isUserInteractionEnabled = false
        captureSessionManager?.capturePhoto()
    }
    
    @objc private func toggleAutoScan() {
        if CaptureSession.current.isAutoScanEnabled {
            CaptureSession.current.isAutoScanEnabled = false
            autoScanButton.title = NSLocalizedString("wescan.scanning.manual", tableName: nil, bundle: Bundle(for: ScannerViewController.self), value: "Manual", comment: "The manual button state")
        } else {
            CaptureSession.current.isAutoScanEnabled = true
            autoScanButton.title = NSLocalizedString("wescan.scanning.auto", tableName: nil, bundle: Bundle(for: ScannerViewController.self), value: "Auto", comment: "The auto button state")
        }
    }
    
    @objc private func toggleFlash() {
        let state = CaptureSession.current.toggleFlash()
        
        let flashImage = UIImage(named: "flash", in: Bundle(for: ScannerViewController.self), compatibleWith: nil)
        let flashOffImage = UIImage(named: "flashUnavailable", in: Bundle(for: ScannerViewController.self), compatibleWith: nil)
        
        switch state {
        case .on:
            flashEnabled = true
            flashButton.image = flashImage
            flashButton.tintColor = .yellow
        case .off:
            flashEnabled = false
            flashButton.image = flashImage
            flashButton.tintColor = .white
        case .unknown, .unavailable:
            flashEnabled = false
            flashButton.image = flashOffImage
            flashButton.tintColor = UIColor.lightGray
        }
    }
    
    @objc private func cancelImageScannerController() {
        guard let imageScannerController = navigationController as? ImageScannerController else { return }
        imageScannerController.imageScannerDelegate?.imageScannerControllerDidCancel(imageScannerController)
    }
    
}

extension ScannerViewController: RectangleDetectionDelegateProtocol {
    func captureSessionManager(_ captureSessionManager: CaptureSessionManager, didFailWithError error: Error) {
        
        activityIndicator.stopAnimating()
        shutterButton.isUserInteractionEnabled = true
        
        guard let imageScannerController = navigationController as? ImageScannerController else { return }
        imageScannerController.imageScannerDelegate?.imageScannerController(imageScannerController, didFailWithError: error)
    }
    
    func didStartCapturingPicture(for captureSessionManager: CaptureSessionManager) {
        activityIndicator.startAnimating()
        captureSessionManager.stop()
        shutterButton.isUserInteractionEnabled = false
    }
    
    func captureSessionManager(_ captureSessionManager: CaptureSessionManager, didCapturePicture picture: UIImage, withQuad quad: Quadrilateral?) {
        activityIndicator.stopAnimating()
        
        let editVC = EditScanViewController(image: picture, quad: quad)
        navigationController?.pushViewController(editVC, animated: false)
        
        shutterButton.isUserInteractionEnabled = true
    }
    
    func captureSessionManager(_ captureSessionManager: CaptureSessionManager, didDetectQuad quad: Quadrilateral?, _ imageSize: CGSize) {
        guard let quad = quad else {
            // If no quad has been detected, we remove the currently displayed on on the quadView.
            quadView.removeQuadrilateral()
            return
        }
        
        let portraitImageSize = CGSize(width: imageSize.height, height: imageSize.width)
        
        let scaleTransform = CGAffineTransform.scaleTransform(forSize: portraitImageSize, aspectFillInSize: quadView.bounds.size)
        let scaledImageSize = imageSize.applying(scaleTransform)
        
        let rotationTransform = CGAffineTransform(rotationAngle: CGFloat.pi / 2.0)

        let imageBounds = CGRect(origin: .zero, size: scaledImageSize).applying(rotationTransform)

        let translationTransform = CGAffineTransform.translateTransform(fromCenterOfRect: imageBounds, toCenterOfRect: quadView.bounds)
        
        let transforms = [scaleTransform, rotationTransform, translationTransform]
        
        let transformedQuad = quad.applyTransforms(transforms)
        
        quadView.drawQuadrilateral(quad: transformedQuad, animated: true)
    }
    
}
