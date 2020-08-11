//
//  ViewController.swift
//  MacVideoNinja
//
//  Created by Steve Sheets on 8/10/20.
//  Copyright © 2020 Steve Sheets. All rights reserved.
//

import Cocoa
import AVKit

class ViewController: NSViewController, NSTabViewDelegate {

    // MARK: IBOutlets
    
    @IBOutlet weak var mainTabView: NSTabView!
    
    @IBOutlet weak var playerView: AVPlayerView!
    
    @IBOutlet weak var assert1Button: NSButton!
    @IBOutlet weak var asset1Label: NSTextField!
    @IBOutlet weak var assert2Button: NSButton!
    @IBOutlet weak var asset2Label: NSTextField!
    @IBOutlet weak var audioLabel: NSTextField!
    @IBOutlet weak var audioButton: NSButton!
    @IBOutlet weak var mergeButton: NSButton!
    @IBOutlet weak var spinnerView: NSProgressIndicator!
    
    // MARK: Properties
    
    var firstAsset: AVAsset?
    var secondAsset: AVAsset?
    var audioAsset: AVAsset?
    var calculating = false

    // MARK: Private Functions
    
    private func selectMedia(uti: String,  closure: @escaping (URL)-> Void) {
        guard let window = self.view.window else { return }
        
        // Invoke Open Panel, opening video from file or photo library
        
        let aPanel = NSOpenPanel()
        
        aPanel.canChooseFiles = true
        aPanel.canChooseDirectories = false
        aPanel.resolvesAliases = true
        aPanel.allowsMultipleSelection = false
        aPanel.allowedFileTypes = [uti]

        aPanel.beginSheetModal(for: window, completionHandler: { num in
            
            // Confirms user select single media
            
            guard num == .OK, let url = aPanel.url  else { return }
            
            
            // Invoke closure with URL to media
            
            closure(url)
        })

    }
    
    private func saveMedia(closure: @escaping (URL)-> Void) {
        guard let window = self.view.window else { return }

        // Invoke Save Panel, to locate where merged file will save to.
        
        let aPanel = NSSavePanel()
        
        aPanel.canCreateDirectories = true
        aPanel.showsTagField = false
        aPanel.nameFieldStringValue = "mergeVideo.mov"

        aPanel.beginSheetModal(for: window, completionHandler: { num in
            
            // Confirms user select single media
            
            guard num == .OK, let url = aPanel.url  else { return }
            
            // Invoke closure with URL to media
            
            closure(url)
        })
    }

    private func videoCompositionInstruction(_ track: AVCompositionTrack, asset: AVAsset) -> AVMutableVideoCompositionLayerInstruction {
        let instruction = AVMutableVideoCompositionLayerInstruction(assetTrack: track)
        let assetTrack = asset.tracks(withMediaType: AVMediaType.video)[0]

        let scaleToFitRatio = 640 / assetTrack.naturalSize.width

        let scaleFactor = CGAffineTransform(scaleX: scaleToFitRatio, y: scaleToFitRatio)
        let concat = assetTrack.preferredTransform.concatenating(scaleFactor).concatenating(CGAffineTransform(translationX: 0, y: 640 / 2))
        instruction.setTransform(concat, at: .zero)

        return instruction
    }

    private func exportDidFinish(_ session: AVAssetExportSession) {
      // Cleanup assets
        firstAsset = nil
        secondAsset = nil
        audioAsset = nil
        calculating = false

        // Update UI
        
        updateUI()
    }
    
    private func merge(url: URL) {
        
        // Requires Asset 1 & 2
        
        guard let firstAsset = firstAsset, let secondAsset = secondAsset else { return }
        
        // 1 - Create AVMutableComposition object. This object will hold your AVMutableCompositionTrack instances.
        let mixComposition = AVMutableComposition()

        // 2 - Create two video tracks
        guard
          let firstTrack = mixComposition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: Int32(kCMPersistentTrackID_Invalid))
          else { return }

        do {
          try firstTrack.insertTimeRange(
            CMTimeRangeMake(start: .zero, duration: firstAsset.duration),
            of: firstAsset.tracks(withMediaType: .video)[0],
            at: .zero)
        } catch {
          print("Failed to load first track")
          return
        }

        guard
          let secondTrack = mixComposition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: Int32(kCMPersistentTrackID_Invalid))
          else { return }

        do {
          try secondTrack.insertTimeRange(
            CMTimeRangeMake(start: .zero, duration: secondAsset.duration),
            of: secondAsset.tracks(withMediaType: .video)[0],
            at: firstAsset.duration)
        } catch {
          print("Failed to load second track")
          return
        }

        // 3 - Composition Instructions
        let mainInstruction = AVMutableVideoCompositionInstruction()
        mainInstruction.timeRange = CMTimeRangeMake(
          start: .zero,
          duration: CMTimeAdd(firstAsset.duration, secondAsset.duration))

        // 4 - Set up the instructions — one for each asset
        let firstInstruction = videoCompositionInstruction(firstTrack, asset: firstAsset)
        firstInstruction.setOpacity(0.0, at: firstAsset.duration)
        let secondInstruction = videoCompositionInstruction(secondTrack, asset: secondAsset)

        // 5 - Add all instructions together and create a mutable video composition
        mainInstruction.layerInstructions = [firstInstruction, secondInstruction]
        let mainComposition = AVMutableVideoComposition()
        mainComposition.instructions = [mainInstruction]
        mainComposition.frameDuration = CMTimeMake(value: 1, timescale: 30)
        mainComposition.renderSize = CGSize(
          width: 640,
          height: 480)

        // 6 - Audio track
        if let loadedAudioAsset = audioAsset {
          let audioTrack = mixComposition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: 0)
          do {
            try audioTrack?.insertTimeRange(
              CMTimeRangeMake(
                start: CMTime.zero,
                duration: CMTimeAdd(
                  firstAsset.duration,
                  secondAsset.duration)),
              of: loadedAudioAsset.tracks(withMediaType: .audio)[0],
              at: .zero)
          } catch {
            print("Failed to load Audio track")
          }
        }

        // 7 - Create Exporter
        guard let exporter = AVAssetExportSession(
          asset: mixComposition,
          presetName: AVAssetExportPresetHighestQuality)
          else { return }
        exporter.outputURL = url
        exporter.outputFileType = AVFileType.mov
        exporter.shouldOptimizeForNetworkUse = true
        exporter.videoComposition = mainComposition

        updateUI()

        // 8 - Perform the Export
        exporter.exportAsynchronously {
          DispatchQueue.main.async {
            self.exportDidFinish(exporter)
          }
        }
    }
    
    private func updateUI() {
        if firstAsset == nil {
            asset1Label.stringValue = "Unloaded"
        }
        if secondAsset == nil {
            asset2Label.stringValue = "Unloaded"
        }
        if audioAsset == nil {
            audioLabel.stringValue = "Unloaded"
        }
        
        assert1Button.isEnabled = !calculating
        assert2Button.isEnabled = !calculating
        audioButton.isEnabled = !calculating
        mergeButton.isEnabled = !calculating

        if calculating {
            spinnerView.isHidden = false
            spinnerView.startAnimation(nil)
        }
        else {
            spinnerView.stopAnimation(nil)
            spinnerView.isHidden = true
        }
    }
    
    // MARK: IBAction Functions

    @IBAction func playVideoAction(_ sender: Any) {

        // Invoke Open Panel, opening video from file or photo library
        
        selectMedia(uti: "public.movie") { [weak self] url in
            guard let strongSelf = self else { return }
            
            // Create player and add to player view
            
            let player = AVPlayer(url: url)
            strongSelf.playerView.player = player
        }
        
    }
    
    @IBAction func loadAsset1Action(_ sender: Any) {
 
        // Invoke Open Panel, opening video from file or photo library
        
        selectMedia(uti: "public.movie") { [weak self] url in
            guard let strongSelf = self else { return }
            
            // Save reference to asset 1
            
            strongSelf.firstAsset = AVAsset(url: url)
            strongSelf.asset1Label.stringValue = url.lastPathComponent
        }

    }
    
    @IBAction func loadAsset2Action(_ sender: Any) {

        // Invoke Open Panel, opening video from file or photo library
        
        selectMedia(uti: "public.movie") { [weak self] url in
            guard let strongSelf = self else { return }
            
            // Save reference to asset 2
            
            strongSelf.secondAsset = AVAsset(url: url)
            strongSelf.asset2Label.stringValue = url.lastPathComponent
        }
        
    }
    
    @IBAction func loadAudioAction(_ sender: Any) {
        
        // Invoke Open Panel, opening audio from file or itunes library
        
        selectMedia(uti: "public.audio") { [weak self] url in
            guard let strongSelf = self else { return }
            
            // Save reference to audio
            
            strongSelf.audioAsset = AVAsset(url: url)
            strongSelf.audioLabel.stringValue = url.lastPathComponent
        }

    }
    
    @IBAction func mergeAction(_ sender: Any) {
        
        // Invoke Save Panel, to find location to save
        saveMedia() { [weak self] url in
            guard let strongSelf = self else { return }

            strongSelf.merge(url: url)
        }

    }
    
    // MARK: Lifecycle & Delegate Functions
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Set TabView delegate to View Controller
        
        mainTabView.delegate = self
    }
    
    func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        
        // When changing tabs, clear everything
        
        // if Player exist, pause it and release from player view
        
        if let player = playerView.player {
            player.pause()
            playerView.player = nil
        }
        
        // Clear Merge Assets
        
        firstAsset = nil
        secondAsset = nil
        audioAsset = nil
        calculating = false
        
        // Update UI
        
        updateUI()
    }

}

