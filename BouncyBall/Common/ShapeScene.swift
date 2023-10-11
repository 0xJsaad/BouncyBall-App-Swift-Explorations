/*************************************
 
 Do not modify this file.
 
 *************************************/

import SpriteKit
import GameplayKit

public typealias Point = CGPoint

#if os(iOS)
public protocol AlertPresentationContext {
    var presentationContext: UIViewController { get }
}
#elseif os(macOS)
public protocol AlertPresentationContext {
    var presentationContext: NSViewController { get }
}
#endif

/**
 A `ShapeScene` displays multiple shapes that the user can interact with.
 */
public class ShapeScene: SKScene, SKPhysicsContactDelegate, SKSceneDelegate {
        
    /**
     A function that's called when the user taps a shape.
     
     ### Usage example:
     Declare a function like this:
     ```
     func myTapCallback(shape: Shape) {
        ...
     }
     ```
     Then assign it to the property like this:
     ```
     myScene.onShapeTapped = myTapCallback
     ```
     
     # Arguments passed to the function
     
     &nbsp;&nbsp;&nbsp;&nbsp; shape &nbsp;&nbsp; The shape that was tapped
     */
    public var onShapeTapped: (Shape) -> () = { _ in }

    /**
     A function that's called repeatedly as a shape is being
     dragged by the user.
     
     ### Usage example:
     Declare a function like this:
     ```
     func myMovingCallback(shape: Shape) {
     ...
     }
     ```
     Then assign it to the property like this:
     ```
     myScene.onShapeMoving = myMovingCallback
     ```
     
     # Arguments passed to the function
     
     &nbsp;&nbsp;&nbsp;&nbsp; shape &nbsp;&nbsp; The shape that's being dragged
     */
    public var onShapeMoving: (Shape) -> () = { _ in }

    /**
     A function that's called whenever the user finishes dragging
     a shape and lifts their finger.
     
     ### Usage example:
     Declare a function like this:
     ```
     func myFinishedMovingCallback(shape: Shape) {
     ...
     }
     ```
     Then assign it to the property like this:
     ```
     myScenee.onShapeMoved = myFinishedMovingCallback
     
     # Arguments passed to the function
     
     &nbsp;&nbsp;&nbsp;&nbsp; shape &nbsp;&nbsp; The shape that has finished moving
     ```
     */
    public var onShapeMoved: (Shape) -> () = { _ in }
    
    /**
     A function that's called whenever a the user taps in an area that
     doesn't contain a shape.
     
     ### Usage example:
     Declare a function like this:
     ```
     func mySceneTapCallback(point: Point) {
     ...
     }
     ```
     Then assign it to the property like this:
     ```
     mySceneckgroundTapped = mySceneTapCallback
     ```

     # Arguments passed to the function
     
     &nbsp;&nbsp;&nbsp;&nbsp; point &nbsp;&nbsp; The location of the tap
     */
    public var onBackgroundTapped: (Point) -> () = { _ in }
    
    /**
     A function that's called whenever two shapes collide.
     
     ### Usage example:
     Declare a function like this:
     ```
     func myCollisionCallback(shape1: Shape, shape2: Shape) {
     ...
     }
     ```
     Then assign it to the property like this:
     ```
     myScene.onShapeCollision = myCollisionCallback
     ```
     
     # Arguments passed to the function
     
     &nbsp;&nbsp;&nbsp;&nbsp; shape1 &nbsp;&nbsp; The first shape
     
     &nbsp;&nbsp;&nbsp;&nbsp; shape2 &nbsp;&nbsp; The second shape
     */
    public var onShapeCollision: (Shape, Shape) -> () = { _, _ in }
        
    public var onShapeExited: (Shape) -> () = { _ in }
    
    /**
     All shapes in the scene.
     */
    public var shapes: [Shape] {
        get {
            return children.compactMap { node in
                return (node as? Shape.TouchResponsiveNode)?.container
            }
        }
    }
    
    /**
     Adds a shape to the scene. The shape may be either a `PolygonShape`
     or an `OvalShape`.
     
     - Parameter shape: The shape to add to the scene
    */
    public func add(_ shape: Shape) {
        scene?.addChild(shape.node)
    }
    
    /**
     Removes a shape from the scene. The shape may be either a `PolygonShape`
     or an `OvalShape`.
     
     - Parameter shape: The shape to remove from the scene
     */
    public func remove(_ shape: Shape) {
        shape.node.removeFromParent()
    }
    
    var width: Double {
        get {
            return Double(frame.width)
        }
    }
    
    var height: Double {
        get {
            return Double(frame.height)
        }
    }

    private var boundaryNode = SKNode()
    public var hasPhysicsBoundary = false {
        didSet {
            if !oldValue && hasPhysicsBoundary {
                self.addChild(boundaryNode)
            } else {
                boundaryNode.removeFromParent()
            }
        }
    }
    
    private var trackedShapes = [SKNode : Bool]()
        
    func trackShape(_ shape: Shape) {
        guard let shapeNode = (children.filter { node in
            if let _ = (node as? Shape.TouchResponsiveNode) {
                return true
            } else {
                return false
            }
        }.first) else { return }
        
        trackedShapes[shapeNode] = shape.isInScene
    }

    weak var tapTimeout: Timer?
    private var touchLocation = CGPoint.zero

    public override func didMove(to view: SKView) {
        backgroundColor = .white
        physicsWorld.contactDelegate = self
    }
    
    public override func didChangeSize(_ oldSize: CGSize) {
        let physicsBoundary = SKPhysicsBody(edgeLoopFrom: self.frame)
        boundaryNode.physicsBody = physicsBoundary
    }

    func touchDown(atPoint pos : CGPoint) {
        tapTimeout = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false, block: { _ in } )
        touchLocation = pos
    }
    
    func touchMoved(toPoint pos : CGPoint) {
    }
    
    func touchUp(atPoint pos : CGPoint) {
        if tapTimeout != nil {
            if (pos.x - touchLocation.x).magnitude < 10 && (pos.y - touchLocation.y).magnitude < 10 {
                onBackgroundTapped(pos)
            }
        }
    }
    
    public var alertDelegate: AlertPresentationContext?

    #if os(iOS)
    public func presentAlert(text: String, completion: @escaping () -> ()) {
        let alert = UIAlertController(title: nil, message: text, preferredStyle: .alert)
        
        let physicsSpeed = physicsWorld.speed
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
            completion()
            self.physicsWorld.speed = physicsSpeed
        }))
        
        physicsWorld.speed = 0
        alertDelegate?.presentationContext.present(alert, animated: true)
    }
    #elseif os(macOS)
    public func presentAlert(text: String, completion: @escaping () -> ()) {
        let alert = NSAlert()
        alert.messageText = text
        alert.alertStyle = .informational
        
        let physicsSpeed = physicsWorld.speed
        physicsWorld.speed = 0

        alert.runModal()
        completion()
        
        self.physicsWorld.speed = physicsSpeed
    }
    #else

    #error("iOS and macOS are the only two targets supported by this API.")

    #endif

    
    public override func didSimulatePhysics() {
        for child in self.children {
            guard let shape = child as? Shape.TouchResponsiveNode, let tracking = shape.container?.isTracking, tracking else { continue }

            shape.container?.physicsSimulated()
        }
    }
    
    #if os(iOS)
    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches { self.touchDown(atPoint: t.location(in: self)) }
    }
    
    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches { self.touchMoved(toPoint: t.location(in: self)) }
    }
    
    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches { self.touchUp(atPoint: t.location(in: self)) }
    }
    
    public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches { self.touchUp(atPoint: t.location(in: self)) }
    }
    #elseif os(macOS)
    
    #else

    #error("iOS and macOS are the only two targets supported by this API.")

    #endif

    public override func didFinishUpdate() {
        // Called before each frame is rendered
        for node in trackedShapes.keys {
            let shape = (node as! Shape.TouchResponsiveNode).container!
            
            if shape.isInScene != trackedShapes[node] {
                trackedShapes[node] = shape.isInScene
                
                if shape.isInScene == false {
                    shape.onExitedScene()
                }
            }
        }
    }
    
    public func didBegin(_ contact: SKPhysicsContact) {
        guard let a = contact.bodyA.node as? Shape.TouchResponsiveNode,
            let b = contact.bodyB.node as? Shape.TouchResponsiveNode else { return }
//        print("CONTACT \(a.container!.name) - \(b.container!.name)")

        a.onCollision(b)
        b.onCollision(a)
        
        guard let aContainer = a.container, let bContainer = b.container else { return }
        
        onShapeCollision(aContainer, bContainer)
    }
    
}

extension ShapeScene : CustomPlaygroundDisplayConvertible {
    public var playgroundDescription: Any {
        return self.view!
    }
}

//infix operator ^(_ base: Double, _ power: Double) -> Double {
//
//}

extension CGPoint {
    func distance(to other: CGPoint) -> Double {
        let dx = Double(other.x - x)
        let dy = Double(other.y - y)
        return sqrt(dx * dx + dy * dy)
    }
}
