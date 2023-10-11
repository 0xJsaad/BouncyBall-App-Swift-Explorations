// Shapes-Mac

import Cocoa
import SpriteKit

class ViewController: NSViewController, AlertPresentationContext {

    var shapeScene: ShapeScene!
    
    let container = NSView()
    let sceneView = SKView(frame: .zero)

    var presentationContext: NSViewController {
        get {
            return self
        }
    }

    override func loadView() {
        container.wantsLayer = true
        container.layer!.backgroundColor = NSColor.lightGray.cgColor
        
        container.translatesAutoresizingMaskIntoConstraints = false
        sceneView.translatesAutoresizingMaskIntoConstraints = false
        
//        container.isMultipleTouchEnabled = true
//        sceneView.isMultipleTouchEnabled = true
        
        container.addSubview(sceneView)

        NSLayoutConstraint.activate([
            sceneView.topAnchor.constraint(equalTo: container.topAnchor),
            sceneView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            sceneView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            sceneView.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        ])
        
        view = container
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        shapeScene = ShapeScene(size: view.bounds.size)
        shapeScene.scaleMode = .aspectFill
        shapeScene.alertDelegate = self

        sceneView.ignoresSiblingOrder = true

        sceneView.presentScene(shapeScene)
        
        sceneView.addTrackingRect(view.bounds, owner: sceneView, userData: nil, assumeInside: true)
    }
        
    override func viewDidAppear() {
        super.viewDidAppear()
        
        setup()
    }
    
    override func viewDidLayout() {
        shapeScene.size = sceneView.bounds.size
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }

}

