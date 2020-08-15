//
//  VideoHelper.swift
//  MacVideoNinja
//
//  Created by Steve Sheets on 8/13/20.
//  Copyright © 2020 Steve Sheets. All rights reserved.
//

import Cocoa

class VideoHelper {

    // MARK: Static Functions
    
    public static func selectMedia(viewController: NSViewController, uti: String,  closure: @escaping (URL)-> Void) {
        guard let window = viewController.view.window else { return }
        
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

    public static func saveMedia(viewController: NSViewController, name: String, closure: @escaping (URL)-> Void) {
        guard let window = viewController.view.window else { return }

        // Invoke Save Panel, to locate where merged file will save to.
        
        let aPanel = NSSavePanel()
        
        aPanel.canCreateDirectories = true
        aPanel.showsTagField = false
        aPanel.nameFieldStringValue = name

        aPanel.beginSheetModal(for: window, completionHandler: { num in
            
            // Confirms user select single media
            
            guard num == .OK, let url = aPanel.url  else { return }
            
            // Invoke closure with URL to media
            
            closure(url)
        })
    }
    
}
