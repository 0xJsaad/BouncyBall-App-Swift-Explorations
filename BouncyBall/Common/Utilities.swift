/*************************************

Do not modify this file.

*************************************/

#if os(iOS)
import UIKit

var viewController: ViewController {
    // find the sceneDelgate for the first active scene that is in the foreground.
    let sceneDelgate = UIApplication.shared.connectedScenes
        .filter({$0.activationState == .foregroundActive})
        .compactMap({$0})
        .first?.delegate as? SceneDelegate
    
    // get the window assocaited with that scene
    guard let win = sceneDelgate?.window else {
        fatalError("No active window found")
    }
    
    return win.rootViewController as! ViewController
}

var scene: ShapeScene {
    return viewController.shapeScene
}
#elseif os(macOS)
import Cocoa

var viewController: ViewController {
    return NSApplication.shared.orderedWindows[0].contentViewController! as! ViewController
}

var scene: ShapeScene {
    return viewController.shapeScene
}
#endif
