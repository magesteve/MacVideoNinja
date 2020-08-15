//
//  RecordVideoViewController.swift
//  MacVideoNinja
//
//  Created by Steve Sheets on 8/13/20.
//  Copyright © 2020 Steve Sheets. All rights reserved.
//

import Cocoa
import AVFoundation
import AVKit

class RecordVideoViewController: NSViewController, AVCaptureFileOutputRecordingDelegate {
    
    // MARK: Enum
    
    enum recordingState {
        case unready
        case ready
        case starting
        case recording
    }
    
    // MARK: IBOutlets
    
    @IBOutlet weak var recordButton: NSButton!
    @IBOutlet weak var recordingView: NSView!
    
    // MARK: Properties
    
    var captureSession: AVCaptureSession?
    var capturePreviewLayer: AVCaptureVideoPreviewLayer?
    var captureDeviceInputCamera: AVCaptureDeviceInput?
    var captureDeviceInputMicrophone: AVCaptureDeviceInput?
    var captureMovieFileOutput: AVCaptureMovieFileOutput?
    var captureURL: URL?
    var captureState: recordingState = .unready
    

    // MARK: IBAction Functions
    
    @IBAction func recordAction(_ sender: Any) {
        guard let output = captureMovieFileOutput else { return }
        
        if output.isRecording {
            output.stopRecording()
            
            captureState = .ready
            updateUI()
        }
        else {
            VideoHelper.saveMedia(viewController: self, name: "capturedVideo.mov") { [weak self] url in
                guard let strongSelf = self else { return }
                
                output.startRecording(to: url, recordingDelegate: strongSelf)
                strongSelf.captureState = .recording
                strongSelf.updateUI()
            }
        }
    }
    
    // MARK: Private Functions
    
    private func prepareVideoCapture() {
        guard captureSession==nil else { return }

        let session = AVCaptureSession()
        session.beginConfiguration()
        session.sessionPreset = .high

        let layer = AVCaptureVideoPreviewLayer(session: session)
        
        guard let camera = AVCaptureDevice.default(for: AVMediaType.video), let cameraInput = try? AVCaptureDeviceInput(device: camera)   else { return }
        
        
        if session.canAddInput(cameraInput) {
            session.addInput(cameraInput)
        }
    
//var microphoneInput: AVCaptureDeviceInput? = nil
//        do {
//            let input = try AVCaptureDeviceInput(device: microphone)
//            if session.canAddInput(input) {
//                session.addInput(input)
//                microphoneInput = input
//            }
//        } catch {
//            return
//        }
 //       captureDeviceInputMicrophone = microphoneInput

        let movie = AVCaptureMovieFileOutput()
        if session.canAddOutput(movie) {
            session.addOutput(movie)
        }
    
        session.commitConfiguration()

        layer.frame = recordingView.bounds
        layer.videoGravity = .resizeAspectFill
        recordingView.layer?.addSublayer(layer)

        captureSession = session
        capturePreviewLayer = layer
        captureDeviceInputCamera = cameraInput
        captureMovieFileOutput = movie

        captureState = .ready
        updateUI()

        session.startRunning()
    }
    
    private func updateUI() {
        switch (captureState) {
            case .unready:
                recordButton.isEnabled = false
                recordButton.title = "Video Unavailable"
            case .ready:
                recordButton.isEnabled = true
                recordButton.title = "Record Video"
            case .starting:
                recordButton.isEnabled = false
                recordButton.title = "Record Video"
            case .recording:
                recordButton.title = "Stop Recording"
                recordButton.isEnabled = true
        }
        
    }
    
    private func requestAccess() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized: // The user has previously granted access to the camera.
                prepareVideoCapture()
            
            case .notDetermined: // The user has not yet been asked for camera access.
                AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                    guard let strongSelf = self else { return }

                    if granted {
                        strongSelf.prepareVideoCapture()
                    }
                }
            
            case .denied: // The user has previously denied access.
                return

            case .restricted: // The user can't grant access due to restrictions.
                return
            
            @unknown default:
                return
        }
//        switch AVCaptureDevice.authorizationStatus(for: .audio) {
//            case .authorized: // The user has previously granted access to the camera.
//                canUseAudio = true
//                self.updateUI()
//
//            case .notDetermined: // The user has not yet been asked for camera access.
//                AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
//                    guard let strongSelf = self else { return }
//
//                    if granted {
//                        strongSelf.canUseAudio = true
//                        strongSelf.updateUI()
//                    }
//                }
//
//            case .denied: // The user has previously denied access.
//                return
//
//            case .restricted: // The user can't grant access due to restrictions.
//                return
//
//            @unknown default:
//                return
//        }
    }
    
    // MARK: Lifecycle Functions

    override func viewDidAppear() {
        super.viewDidAppear()
        
        recordingView.wantsLayer = true

        requestAccess()
        updateUI()
    }
    
    // MARK: Delegate Functions
    
    func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo: URL, from: [AVCaptureConnection]) {
        captureState = .recording
        
        print("start Output \(output.description), Url \(didStartRecordingTo.description), AVCaptureConnections \(from.description)")
        
        updateUI()
    }
    
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        print("finish Output \(output.description), Url \(outputFileURL.description), AVCaptureConnections \(connections.description)")

        if let error = error {
            print("Error: \(error.localizedDescription)")
        
        } else {
            
        }
        
        captureState = .ready
        updateUI()
    }
    
}
