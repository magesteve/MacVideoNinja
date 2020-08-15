//
//  MergeVideoViewController.swift
//  MacVideoNinja
//
//  Created by Steve Sheets on 8/13/20.
//  Copyright © 2020 Steve Sheets. All rights reserved.
//

import Cocoa
import AVFoundation
import AVKit

class MergeVideoViewController: NSViewController {

       // MARK: IBOutlets
       
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
       var videoSize: CGSize = CGSize(width: 640, height: 480)

       // MARK: Private Functions
              
       enum ImageOrientation {
           case up
           case down
           case left
           case right
       }

       private func orientationFromTransform(_ transform: CGAffineTransform) -> (orientation: ImageOrientation, isPortrait: Bool) {
         var assetOrientation = ImageOrientation.up
         var isPortrait = false
         let tfA = transform.a
         let tfB = transform.b
         let tfC = transform.c
         let tfD = transform.d

         if tfA == 0 && tfB == 1.0 && tfC == -1.0 && tfD == 0 {
           assetOrientation = .right
           isPortrait = true
         } else if tfA == 0 && tfB == -1.0 && tfC == 1.0 && tfD == 0 {
           assetOrientation = .left
           isPortrait = true
         } else if tfA == 1.0 && tfB == 0 && tfC == 0 && tfD == 1.0 {
           assetOrientation = .up
         } else if tfA == -1.0 && tfB == 0 && tfC == 0 && tfD == -1.0 {
           assetOrientation = .down
         }
         return (assetOrientation, isPortrait)
       }
       
       private func videoCompositionInstruction(_ track: AVCompositionTrack, asset: AVAsset) -> AVMutableVideoCompositionLayerInstruction {
           let instruction = AVMutableVideoCompositionLayerInstruction(assetTrack: track)
           let assetTrack = asset.tracks(withMediaType: AVMediaType.video)[0]

           let transform = assetTrack.preferredTransform
           let assetInfo = orientationFromTransform(transform)

           var scaleToFitRatio = videoSize.width / assetTrack.naturalSize.width
           if assetInfo.isPortrait {
               scaleToFitRatio = videoSize.width / assetTrack.naturalSize.height
               let scaleFactor = CGAffineTransform(scaleX: scaleToFitRatio, y: scaleToFitRatio)
               instruction.setTransform(assetTrack.preferredTransform.concatenating(scaleFactor), at: .zero)
           } else {
               let scaleFactor = CGAffineTransform(scaleX: scaleToFitRatio, y: scaleToFitRatio)
               var concat = assetTrack.preferredTransform.concatenating(scaleFactor)
               if assetInfo.orientation == .down {
                   let fixUpsideDown = CGAffineTransform(rotationAngle: CGFloat(Double.pi))
                   let windowBounds = videoSize
                   let yFix = assetTrack.naturalSize.height + windowBounds.height
                   let centerFix = CGAffineTransform(translationX: assetTrack.naturalSize.width, y: yFix)
                   concat = fixUpsideDown.concatenating(centerFix).concatenating(scaleFactor)
               }
               instruction.setTransform(concat, at: .zero)
           }

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
           guard let firstTrack = mixComposition.addMutableTrack(withMediaType: .video, preferredTrackID: Int32(kCMPersistentTrackID_Invalid)) else { return }

           do {
             try firstTrack.insertTimeRange(CMTimeRangeMake(start: .zero, duration: firstAsset.duration), of: firstAsset.tracks(withMediaType: .video)[0], at: .zero)
           } catch {
             print("Failed to load first track")
             return
           }

           guard let secondTrack = mixComposition.addMutableTrack(withMediaType: .video, preferredTrackID: Int32(kCMPersistentTrackID_Invalid)) else { return }

           do {
             try secondTrack.insertTimeRange(CMTimeRangeMake(start: .zero, duration: secondAsset.duration), of: secondAsset.tracks(withMediaType: .video)[0], at: firstAsset.duration)
           } catch {
             print("Failed to load second track")
             return
           }

           // 3 - Composition Instructions
           let mainInstruction = AVMutableVideoCompositionInstruction()
           mainInstruction.timeRange = CMTimeRangeMake(start: .zero, duration: CMTimeAdd(firstAsset.duration, secondAsset.duration))

           // 4 - Set up the instructions — one for each asset
           let firstInstruction = videoCompositionInstruction(firstTrack, asset: firstAsset)
           firstInstruction.setOpacity(0.0, at: firstAsset.duration)
           let secondInstruction = videoCompositionInstruction(secondTrack, asset: secondAsset)

           // 5 - Add all instructions together and create a mutable video composition
           mainInstruction.layerInstructions = [firstInstruction, secondInstruction]
           let mainComposition = AVMutableVideoComposition()
           mainComposition.instructions = [mainInstruction]
           mainComposition.frameDuration = CMTimeMake(value: 1, timescale: 30)
           mainComposition.renderSize = CGSize(width: videoSize.width, height: videoSize.height)

           // 6 - Audio track
           if let loadedAudioAsset = audioAsset {
             let audioTrack = mixComposition.addMutableTrack(withMediaType: .audio, preferredTrackID: 0)
             do {
               try audioTrack?.insertTimeRange(CMTimeRangeMake(start: CMTime.zero, duration: CMTimeAdd( firstAsset.duration, secondAsset.duration)), of: loadedAudioAsset.tracks(withMediaType: .audio)[0], at: .zero)
             } catch {
               print("Failed to load Audio track")
             }
           }

           // 7 - Create Exporter
           guard let exporter = AVAssetExportSession(asset: mixComposition, presetName: AVAssetExportPresetHighestQuality) else { return }
           exporter.outputURL = url
           exporter.outputFileType = AVFileType.mov
           exporter.shouldOptimizeForNetworkUse = true
           exporter.videoComposition = mainComposition

           calculating = true
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
               spinnerView.isHidden = true
               spinnerView.stopAnimation(nil)
           }
       }
       
       // MARK: IBAction Functions

       @IBAction func loadAsset1Action(_ sender: Any) {
    
           // Invoke Open Panel, opening video from file or photo library
           
        VideoHelper.selectMedia(viewController: self, uti: "public.movie") { [weak self] url in
               guard let strongSelf = self else { return }
               
               // Save reference to asset 1
               
               let asset = AVAsset(url: url)
               strongSelf.firstAsset = asset
               strongSelf.asset1Label.stringValue = url.lastPathComponent
               
               let tracks = asset.tracks(withMediaType: .video)
               if let track = tracks.first {
                   strongSelf.videoSize = track.naturalSize
               }
           }

       }
       
       @IBAction func loadAsset2Action(_ sender: Any) {

           // Invoke Open Panel, opening video from file or photo library
           
           VideoHelper.selectMedia(viewController: self, uti: "public.movie") { [weak self] url in
               guard let strongSelf = self else { return }
               
               // Save reference to asset 2
               
               strongSelf.secondAsset = AVAsset(url: url)
               strongSelf.asset2Label.stringValue = url.lastPathComponent
           }
           
       }
       
       @IBAction func loadAudioAction(_ sender: Any) {
           
           // Invoke Open Panel, opening audio from file or itunes library
           
           VideoHelper.selectMedia(viewController: self, uti: "public.audio") { [weak self] url in
               guard let strongSelf = self else { return }
               
               // Save reference to audio
               
               strongSelf.audioAsset = AVAsset(url: url)
               strongSelf.audioLabel.stringValue = url.lastPathComponent
           }

       }
       
       @IBAction func mergeAction(_ sender: Any) {
           
           // Invoke Save Panel, to find location to save
           
        VideoHelper.saveMedia(viewController: self, name: "mergeVideo.mov") { [weak self] url in
               guard let strongSelf = self else { return }

               strongSelf.merge(url: url)
           }

       }
       
    // MARK: Lifecycle Functions

    override func viewDidAppear() {
        super.viewDidAppear()
        
        updateUI()
    }

}
