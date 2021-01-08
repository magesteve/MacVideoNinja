//
//  RecordVideoViewController.swift
//  MacVideoNinja
//
//  Created by Steve Sheets on 8/13/20.
//  Copyright © 2020 Steve Sheets. All rights reserved.
//

import Cocoa
import AVFoundation
import AVCaptureView

class RecordVideoViewController: NSViewController {
    
    // MARK: IBOutlets
    
    @IBOutlet weak var recordButton: NSButton!
    @IBOutlet weak var captureView: AVCaptureView!
    
    // MARK: Properties
    
    var authorized = false
    
    // MARK: IBAction Functions
    
    @IBAction func recordAction(_ sender: Any) {
    }
    
    // MARK: Private Functions
            
    private func updateUI() {
        recordButton.isEnabled = authorized
    }
        
    // MARK: Lifecycle Functions

    override func viewDidAppear() {
        super.viewDidAppear()
        
        AVCaptureView.requestCaptureAuthorization() { [weak self] in
            guard let strongSelf = self else { return }
            
            strongSelf.authorized = true;
            strongSelf.updateUI()
        }
        
        updateUI()
    }
        
}
