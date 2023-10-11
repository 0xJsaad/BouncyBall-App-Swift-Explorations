/*************************************
 
 Do not modify this file.
 
 *************************************/

import UIKit
import SpriteKit
import GameplayKit

class ViewController: UIViewController, AlertPresentationContext {
    
    var shapeScene: ShapeScene!
    
    let container = UIView()
    let sceneView = SKView(frame: .zero)
    
    var presentationContext: UIViewController {
        get {
            return self
        }
    }
        
    override func loadView() {
        container.backgroundColor = .lightGray
        
        container.translatesAutoresizingMaskIntoConstraints = false
        sceneView.translatesAutoresizingMaskIntoConstraints = false
        
        container.isMultipleTouchEnabled = true
        sceneView.isMultipleTouchEnabled = true
        
        container.addSubview(sceneView)

        NSLayoutConstraint.activate([
            sceneView.topAnchor.constraint(equalTo: container.safeAreaLayoutGuide.topAnchor),
            sceneView.bottomAnchor.constraint(equalTo: container.safeAreaLayoutGuide.bottomAnchor),
            sceneView.leadingAnchor.constraint(equalTo: container.safeAreaLayoutGuide.leadingAnchor),
            sceneView.trailingAnchor.constraint(equalTo: container.safeAreaLayoutGuide.trailingAnchor)
        ])
        
        view = container
    }
    
    override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge {
        return .bottom
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        shapeScene = ShapeScene(size: view.bounds.size)
        shapeScene.scaleMode = .aspectFill
        shapeScene.alertDelegate = self

        sceneView.ignoresSiblingOrder = true

        sceneView.presentScene(shapeScene)
    }
        
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        setup()
    }
    
    override func viewDidLayoutSubviews() {
        shapeScene.size = sceneView.bounds.size
    }
}
