//
//  ViewController.swift
//  MacVideoNinja
//
//  Created by Steve Sheets on 8/10/20.
//  Copyright © 2020 Steve Sheets. All rights reserved.
//

import Cocoa
import AVFoundation
import AVKit

class PlayVideoViewController: NSViewController {

    // MARK: IBOutlets
    
    @IBOutlet weak var playerView: AVPlayerView!
    
    // MARK: IBAction Functions

    @IBAction func playVideoAction(_ sender: Any) {
        
        // If already playing, stop & release previous movie
        
        if let player = playerView.player {
            player.pause()
            playerView.player = nil
        }

        // Invoke Open Panel, opening video from file or photo library
        
        VideoHelper.selectMedia(viewController:self, uti: "public.movie") { [weak self] url in
            guard let strongSelf = self else { return }
            
            // Create player and add to player view
            
            let player = AVPlayer(url: url)
            strongSelf.playerView.player = player
        }
        
    }
    
    override func viewDidDisappear() {
        super.viewDidDisappear()
        
        // If already playing, stop & release previous movie
        
        if let player = playerView.player {
            player.pause()
            playerView.player = nil
        }
    }
}

