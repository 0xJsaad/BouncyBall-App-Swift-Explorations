/*************************************
 
 Do not modify this file.
 
 *************************************/

import SpriteKit

protocol Point2D {
    var x: CGFloat {get set}
    var y: CGFloat {get set}
    static func from(componentX: Point2D, componentY: Point2D) -> Point2D
}

extension CGPoint: Point2D {
    static func from(componentX: Point2D, componentY: Point2D) -> Point2D {
        return CGPoint(x: componentX.x, y: componentY.y)
    }
}

func -(_ first: CGPoint, _ second: CGPoint) -> CGPoint {
    return CGPoint(x: first.x - second.x, y: first.y - second.y)
}

extension Array where Element: Point2D {
    
    private func firstElement(where sortMethod: ((Element, Element) -> Bool)) -> Element? {
        if self.count == 0 {
            return nil
        } else {
            return self.sorted(by: sortMethod).first!
        }
    }
    
    var minX: Element? {
        return self.firstElement(where: { $0.x < $1.x })
    }
    
    var minY: Element? {
        return self.firstElement(where: { $0.y < $1.y })
    }
    
    var maxX: Element? {
        return self.firstElement(where: { $0.x > $1.x })
    }
    
    var maxY: Element? {
        return self.firstElement(where: { $0.y > $1.y })
    }
    
    func normalized() -> [Element] {
        if self.count > 0 {
            let minPoint = CGPoint(x: self.minX!.x, y: self.minY!.y)
            return self.map { point in
                var normalized = point
                normalized.x -= minPoint.x
                normalized.y -= minPoint.y
                return normalized
            }
        } else {
            return self
        }
    }
}

struct MotionState {
    let position: CGPoint
    let time = Date.timeIntervalSinceReferenceDate
}

struct MotionTracker {
    var initialState: MotionState?
    var motionHistoryLength = 10
    var motionHistory = [MotionState]()
    
    mutating func recordPosition(_ position: CGPoint) {
        let state = MotionState(position: position)
        
        if initialState == nil {
            initialState = state
        }
        
        if motionHistory.count >= 10 {
            motionHistory.removeFirst(motionHistory.count - 10)
        }
        motionHistory.append(state)
    }
    
    var smoothedVelocity: CGVector {
        guard motionHistory.count > 1 else {
            return .zero
        }
        
        var dx = CGFloat(0)
        var dy = CGFloat(0)
        
        let averageVelocity = zip(motionHistory, motionHistory[1...]).reduce(CGFloat(0)) { priorResult, tuple in
            let (state1, state2) = tuple
            dx = state2.position.x - state1.position.x
            dy = state2.position.y - state1.position.y
            return priorResult + (dx * dx + dy * dy) / CGFloat(state2.time - state1.time)
            }.squareRoot() / CGFloat(motionHistory.count)
        
        let magnitude = (dx * dx + dy * dy).squareRoot()
        var velocityVector = CGVector(dx: dx / magnitude, dy: dy / magnitude)
        
        velocityVector.dx *= averageVelocity * 20
        velocityVector.dy *= averageVelocity * 20
        
        return velocityVector
    }
    
    var timeSinceLastMotion: TimeInterval {
        guard let mostRecentState = motionHistory.last else {
            return .infinity
        }
        
        return Date.timeIntervalSinceReferenceDate - mostRecentState.time
    }
}

func linearAngle(_ p1: CGPoint, _ p2: CGPoint) -> CGFloat {
    let diffX = p1.x - p2.x
    let diffY = p1.y - p2.y
    return atan2(diffY, diffX)
}

func distanceBetween(_ p1: CGPoint, _ p2: CGPoint) -> CGFloat {
    let diffX = p1.x - p2.x
    let diffY = p1.y - p2.y
    return sqrt(diffX*diffX + diffY*diffY)
}

extension CGPoint {
//    static let formatter = {
//        let nf = NumberFormatter()
//        nf.maximumFractionDigits = 0
//    }()

    var shortDescription: String {
        return "\(Int(round(x))), \(Int(round(y)))"
    }
}

protocol TrackableNodeInteraction {
    func location(in node: SKNode) -> CGPoint
}

#if os(iOS)

class NodeInteraction: TrackableNodeInteraction {
    private let touch: UITouch
    
    init(_ touch: UITouch) {
        self.touch = touch
    }
    
    func location(in node: SKNode) -> CGPoint {
        return touch.location(in: node)
    }
}

extension NodeInteraction: Hashable {
    static func == (lhs: NodeInteraction, rhs: NodeInteraction) -> Bool {
        return lhs.touch == rhs.touch
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(touch)
    }
}

#elseif os(macOS)

class NodeInteraction: Hashable, TrackableNodeInteraction {
    var event: NSEvent!
    
    init(_ event: NSEvent?) {
        self.event = event
    }
    
    func location(in node: SKNode) -> CGPoint {
        return event.location(in: node)
    }
    
    static var shared: NodeInteraction = {
        return NodeInteraction(nil)
    }()
    
    static func == (lhs: NodeInteraction, rhs: NodeInteraction) -> Bool {
        return true
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(1)
    }
}

#else

#error("iOS and macOS are the only two targets supported by this API.")

#endif

fileprivate class MultiTouchTracker {
    var motionTracker = MotionTracker()
    
    var smoothedVelocity: CGVector {
        return motionTracker.smoothedVelocity
    }
    
    var timeSinceLastMotion: TimeInterval {
        return motionTracker.timeSinceLastMotion
    }
    
    var interpretableAsTap: Bool = false

    var offset = CGPoint.zero
    
    var originalPinchDistance: CGFloat = 0
    var originalScale: Double = 0
    var originalPinchAngle: CGFloat = 0
    var originalAngle: Double = 0
    
    var shape: Shape!
    var interactions = [NodeInteraction: CGPoint]()
    var touchLimit = 1
    var longPressFired = false
    var tapTimer: Timer?
    var longPressTimer: Timer?
    
    var isTracking: Bool {
        return motionTracker.initialState != nil
    }

    func addInteractions(_ interactions: Set<NodeInteraction>) {
        for interaction in interactions {
            addInteraction(interaction)
        }
    }
    
    func removeInteractions(_ interactions: Set<NodeInteraction>) {
        for interaction in interactions {
            removeInteraction(interaction)
        }
    }
    
//    func addTouch(_ touch: UITouch) {
    func addInteraction(_ interaction: NodeInteraction) {
        guard interactions.count < touchLimit else { return }
        
        let oldCount = interactions.count
        let newCount = interactions.count + 1
        
        let parentLocation = interaction.location(in: shape.node.parent!)
        interactions[interaction] = parentLocation

        // Update offset to new centroid.
        offset = touchCentroid()

//        print("*OFFSET*\n\(offset.shortString)")
                
        if newCount == 1 && oldCount == 0 {
            interpretableAsTap = true
            tapTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: false) { [weak self] _ in
                self?.interpretableAsTap = false
            }
            longPressTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: false) { _ in
                
            }
        } else if newCount == 2 && oldCount == 1 {
            let pinchPoints = interactions.keys.map { $0.location(in: shape.node.parent!) }
            originalPinchDistance = distanceBetween(pinchPoints[0], pinchPoints[1])
//            originalScale = _instance.scale
            originalPinchAngle = linearAngle(pinchPoints[0], pinchPoints[1])
            originalAngle = shape.angle
        }
    }
    
    func removeInteraction(_ interaction: NodeInteraction) {
        guard interactions.keys.contains(interaction) else { return }
        
        interactions[interaction] = nil
        
        if interactions.count == 0 {
            motionTracker = MotionTracker()
        } else {
            // Update offset to new centroid.
            offset = touchCentroid()
        }
    }
    
    func update() {
        guard interactions.count > 0 else { return }
        
        var position = touchCentroid()
        
        // Offset and convert to parent node.
        position.x -= offset.x
        position.y -= offset.y
        position = shape.node.parent!.convert(position, from: shape.node)

        shape.position = position
        motionTracker.recordPosition(position)
    }
    
    func touchCentroid() -> CGPoint {
        return touchCentroid(in: shape.node)
    }
    
    func touchCentroid(in referenceNode: SKNode) -> CGPoint {
        var centroid = CGPoint.zero
        
        for touch in interactions.keys {
            let reference = touch.location(in: referenceNode)
            centroid.x += reference.x
            centroid.y += reference.y
        }
        
        centroid.x /= CGFloat(interactions.count)
        centroid.y /= CGFloat(interactions.count)
                
        return centroid
    }
}

/**
 A `Shape` is a two-dimensional object that's placed in a `ShapeScene`.
 
 Shapes can either be polygons (see `PolygonShape`) or ovals (see
 `OvalShape`).
 
 Shapes are:
 
 - Placed in specific locations in the scene.
 - Filled with a color.
 - Optionally outlined with a color.
 
 Shapes may:
 
 - Be in a fixed position or move freely.
 - React to user taps and swipes.
 - Participate in a physics simulation with gravity and collisions.
 - Move independently of the user by performing `Action`s.
 
 */
open class Shape {
        
    internal class TouchResponsiveNode : SKNode {
        weak var container: Shape? {
            get {
                return userData?["container"] as? Shape
            }
            set {
                guard let newValue = newValue else { return }
                userData = ["container" : newValue]
            }
        }
        
        #if os(iOS)
        public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
            let interactions = Set(touches.map { NodeInteraction($0) })
            container?.interactionsBegan(interactions)
        }
        
        public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
            let interactions = Set(touches.map { NodeInteraction($0) })
            container?.interactionsMoved(interactions)
        }
        
        public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
            let interactions = Set(touches.map { NodeInteraction($0) })
            container?.interactionsEnded(interactions)
        }
        
        public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
            let interactions = Set(touches.map { NodeInteraction($0) })
            container?.interactionsCancelled(interactions)
        }
        #elseif os(macOS)
        public override func mouseDown(with event: NSEvent) {
            NodeInteraction.shared.event = event
            container?.interactionsBegan(Set([NodeInteraction.shared]))
        }
        
        public override func mouseDragged(with event: NSEvent) {
            NodeInteraction.shared.event = event
            container?.interactionsMoved(Set([NodeInteraction.shared]))
        }
        
        public override func mouseUp(with event: NSEvent) {
            NodeInteraction.shared.event = event
            container?.interactionsEnded(Set([NodeInteraction.shared]))
        }
        #else
        #error("")
        #endif
        
        public func onCollision(_ other: TouchResponsiveNode) {
            guard let container = container, let otherContainer = other.container else { return }
            
            container.onCollision(otherContainer)
        }
        
    }
    
    internal var node: TouchResponsiveNode
    
    private var touchTracker = MultiTouchTracker()
    internal let shape: SKShapeNode
    private let path: CGPath
    
    private var cachedBody: SKPhysicsBody?
    
    /// The shape's name.
    public var name: String?
    
    private var _onTapped: (() -> Void)?
    private var _onMoving: (() -> Void)?
    private var _onMoved: (() -> Void)?
    private var _onExitedScene: (() -> Void)?
    
    /**
     A function that's called when the user taps a shape.
     
     ### Usage example:
     Declare a function like this:
     ```
     func myTapCallback() {
     ...
     }
     ```
     Then assign it to the property like this:
     ```
     myShape.onTapped = myTapCallback
     ```
     */
    public var onTapped: () -> () {
        get {
            return _onTapped ?? {
                self.shapeScene?.onShapeTapped(self)
            }
        }
        set {
            _onTapped = {
                newValue()
                self.shapeScene?.onShapeTapped(self)
            }
        }
    }

    /**
     A function that's called repeatedly as a shape is being
     dragged by the user.

     ### Usage example:
     Declare a function like this:
     ```
     func myMovingCallback() {
     ...
     }
     ```
     Then assign it to the property like this:
     ```
     myShape.onMoving = myMovingCallback
     ```
     */
    public var onMoving: () -> () {
        get {
            return _onMoving ?? {
                self.shapeScene?.onShapeMoving(self)
            }
        }
        set {
            _onMoving = {
                newValue()
                self.shapeScene?.onShapeMoving(self)
            }
        }
    }
    
    /**
     A function that's called whenever the user finishes dragging
     a shape and lifts their finger.

     ### Usage example:
     Declare a function like this:
     ```
     func myFinishedMovingCallback() {
     ...
     }
     ```
     Then assign it to the property like this:
     ```
     myShape.onMoved = myFinishedMovingCallback
     ```
     */
    public var onMoved: () -> () {
        get {
            return _onMoved ?? {
                self.shapeScene?.onShapeMoved(self)
            }
        }
        set {
            _onMoved = {
                newValue()
                self.shapeScene?.onShapeMoved(self)
            }
        }
    }
    
    public var onExitedScene: () -> () {
        get {
            return _onExitedScene ?? {
                self.shapeScene?.onShapeExited(self)
            }
        }
        set {
            _onExitedScene = {
                newValue()
                self.shapeScene?.onShapeExited(self)
            }
        }
    }

    /**
     A function that's called whenever a physics-based shape collides with another shape or the boundary of the screen.
     
     ### Usage example:
     Declare a function like this:
     ```
     func myCollisionCallback(otherShape: Shape) {
     ...
     }
     ```
     Then assign it to the property like this:
     ```
     myShape.onCollision = myCollisionCallback
     ```
     
     # Arguments passed to the function
     
     &nbsp;&nbsp;&nbsp;&nbsp; shape &nbsp;&nbsp; The other shape that this shape has collided with.
     
     */
    public var onCollision: (Shape) -> () = { _ in }

    private var shapeScene: ShapeScene? {
        return self.node.scene as? ShapeScene
    }

    var isTracking: Bool {
        return touchTracker.isTracking
    }
    
    init(shapeNode: SKShapeNode) {
        shape = shapeNode
        node = TouchResponsiveNode()
        
        var transform = CGAffineTransform(translationX: -shape.frame.width / 2, y: -shape.frame.height / 2)
        let offsetPath = shape.path!.copy(using: &transform)!
        self.path = offsetPath
        
        node.container = self
        touchTracker.shape = self
        touchTracker.touchLimit = 2

        shape.fillColor = .black
        
        node.addChild(shape)
        shape.position = CGPoint(x: -shape.frame.width / 2, y: -shape.frame.height / 2)
        shape.isUserInteractionEnabled = false
        node.isUserInteractionEnabled = true
        shape.lineWidth = 0
    }
    
    public func duplicate() -> Shape {
        let new = Shape(shapeNode: SKShapeNode(path: shape.path!))
        
        new.name = name
        new.fillColor = fillColor
        new.lineColor = lineColor
        new.lineThickness = lineThickness
        new.imageName = imageName
        new.respondsToTouch = respondsToTouch
        new.isImmobile = isImmobile
        new.hasPhysics = hasPhysics
        new.isAffectedByGravity = isAffectedByGravity
        
        return new
    }
    
    /**
     The location of the lower-left corner of the shape.
     */
    public var position: Point {
        get {
            return node.position
        }
        set {
            node.position = newValue
        }
    }
    
    public var angle: Double {
        get {
            return Double(node.zRotation)
        }
        set {
            node.zRotation = CGFloat(newValue)
        }
    }
    
    public var isInScene: Bool {
        guard let scene = shapeScene else { return false }
        
        return shape.frame.offsetBy(dx: node.position.x, dy: node.position.y).intersects(scene.frame)
    }
    
    /**
     Whether the shape reacts to user touches.
     */
    public var respondsToTouch = true {
        didSet {
            node.isUserInteractionEnabled = respondsToTouch
        }
    }
    
    /**
     Whether the shape can be dragged.
     
     The `respondsToTouch` property supersedes this one.
     
     If `respondsToTouch` is true and this property is false,
     the shape can still react to taps but can't be dragged.
     */
    public var isDraggable = true
    
    /**
     Whether the shape moves in response to physics interactions.
     
     If the shape has physics, it will affect other physics-based objects, but will not:
     
     - Move in reaction to collisions with other objects.
     - Be affected by gravity.
     
     A shape that's immobile will still respond to user interaction.
     */
    public var isImmobile = false {
        didSet {
            if isImmobile == true {
                node.physicsBody?.isDynamic = false
                
//                self.physicsBody?.affectedByGravity = false
//                self.physicsBody?.allowsRotation = false
//                self.physicsBody?.pinned = true
            } else {
                node.physicsBody?.isDynamic = true
                
//                self.physicsBody?.affectedByGravity = affectedByGravity
//                self.physicsBody?.allowsRotation = true
//                self.physicsBody?.pinned = false
            }
        }
    }

    /**
     The color of the shape's outline.
     */
    public var lineColor: Color {
        get {
            return Color(wrapped: shape.strokeColor)
        }
        set {
            shape.strokeColor = newValue.platformColor
        }
    }
    
    /**
     The thickness of the shape's outline.
     
     Note that the line extends beyond the physical bounds of the shape,
     so collisions between physics-based shapes will appear to
     overlap a little if the lines are thick.
     */
    public var lineThickness: Double {
        get {
            return Double(shape.lineWidth)
        }
        set {
            shape.lineWidth = CGFloat(newValue)
        }
    }
    
    /**
     The color of the shape.
     */
    public var fillColor: Color {
        get {
            return Color(wrapped: shape.fillColor)
        }
        set {
            shape.fillColor = newValue.platformColor
        }
    }

    var imageName: String = "" {
        didSet {
//            if imageName.count > 0, let contentImage = UIImage(named: imageName) {
//                shape.fillTexture = SKTexture(image: contentImage)
//            } else {
//                shape.fillTexture = nil
//            }
        }
    }
    
    /**
     Whether the shape participates in the physics simulation.
     
     If true, the shape will react to the environment in realistic ways,
     reacting to gravity and collisions with other shapes.
     */
    public var hasPhysics: Bool {
        get {
            return node.physicsBody != nil || cachedBody != nil
        }
        set {
            guard hasPhysics != newValue else { return }
            
            if newValue {
                node.physicsBody = SKPhysicsBody(polygonFrom: path)
                node.physicsBody?.contactTestBitMask = 1
                node.physicsBody?.collisionBitMask = 1
                node.physicsBody?.categoryBitMask = 1
                node.physicsBody?.affectedByGravity = isAffectedByGravity
                node.physicsBody?.isDynamic = true
                node.physicsBody?.allowsRotation = true
            } else {
                node.physicsBody = nil
                cachedBody = nil
            }
        }
    }
    
    public func stopAllMotion() {
        node.physicsBody?.velocity = .zero
        node.physicsBody?.angularVelocity = .zero
    }
    
    public var isImpermeable = true {
        didSet {
            if isImpermeable {
                node.physicsBody?.collisionBitMask = 1
                node.physicsBody?.categoryBitMask = 1
            } else {
                node.physicsBody?.collisionBitMask = 0
                node.physicsBody?.categoryBitMask = 0
            }
        }
    }
    
    /**
     Whether the shape is affected by gravitational force in the physics simulation.
     
     Note that the `hasPhysics` property must be true for this property to have any
     effect.
     */
    public var isAffectedByGravity = true {
        didSet {
            node.physicsBody?.affectedByGravity = isAffectedByGravity
        }
    }
    
    public var mass: Double {
        get {
            return Double(node.physicsBody?.mass ?? 0)
        }
        set {
            node.physicsBody?.mass = CGFloat(newValue)
        }
    }
    
    public var bounciness: Double {
        get {
            return Double(node.physicsBody?.restitution ?? 0)
        }
        set {
            node.physicsBody?.restitution = CGFloat(max(min(newValue, 1), 0))
        }
    }
    
    /**
     Pushes a shape in a given direction with a given strength.
     
     - Parameter direction: The angle of the push in degrees, from 0 to 360, with 0 being straight up.
     - Parameter strength: The strength of the push.

     - Note: The `hasPhysics` property must be true for this method to have any
     effect.
     */
    public func push(inDirection direction: Double, withStrength strength: Double) {
        node.physicsBody?.applyImpulse(CGVector.from(angle: direction, magnitude: strength))
    }
    
    private var fixedInPlacePriorToAction = false
    private func cancelCurrentAction() {
        if node.hasActions() {
            node.removeAllActions()

            self.isImmobile = self.fixedInPlacePriorToAction
        }
    }
    
    private enum RepeatCount {
        case finite(times: Int)
        case infinite
    }
    
    private func prepareAndRun(_ actions: [Action], repeating: RepeatCount, completion: (() -> Void)?) {
        cancelCurrentAction()
        
        fixedInPlacePriorToAction = isImmobile
        
        let disableForPhysics = SKAction.customAction(withDuration: 0) { [unowned self] (_, _) in
            self.isImmobile = true
        }
        
        let enableForPhysics = SKAction.customAction(withDuration: 0) { [unowned node, unowned self] (_, _) in
            node.physicsBody?.velocity = .zero
            self.isImmobile = self.fixedInPlacePriorToAction
        }
        
        let wrappedActions: [SKAction]
        wrappedActions = actions.compactMap { [unowned self] action in
            action.shape = self
            var nodeAction = action.action
            if action.overridesPhysics {
                nodeAction = SKAction.sequence([disableForPhysics, nodeAction, enableForPhysics])
            }
            return nodeAction
        }
        
        let sequence = SKAction.sequence(wrappedActions)
        
        var repeatAction: SKAction
        
        switch repeating {
        case .finite(let times):
            repeatAction = SKAction.repeat(sequence, count: times)
        case .infinite:
            repeatAction = SKAction.repeatForever(sequence)
        }
        
        node.run(repeatAction, completion: completion ?? {})
    }

    /**
     Performs an action on a shape.
     
     - Parameter action: The action to perform.
     
     You can pass in a `MoveAction`, a `PushAction`, or a `WaitAction` to this method. Any
     currently-running actions are cancelled.
     
     - Note: Calling `perform()` multiple times sequentially will not cause the actions to
     run in sequence. To create a sequence of actions, use
     `perform(_ actions: [Action], repeating times: Int)`.
     */
    public func perform(_ action: Action) {
        prepareAndRun([action], repeating: .finite(times: 1), completion: nil)
    }

    /**
     Performs an action on a shape.
     When the action has finished, a completion function is called.
     
     - Parameter action: The action to perform.
     - Parameter completion: The function to run when the action has finished running.

     You can pass in either a `MoveAction` or `PushAction` to this method.
     */
    public func perform(_ action: Action, completion: @escaping () -> Void) {
        prepareAndRun([action], repeating: .finite(times: 1), completion: nil)
    }

    /**
     Performs a series of actions on a shape, repeating the series a given number of times.

     - Parameter actions: The sequence of actions to perform.
     - Parameter repeating: The number of times to repeat.
     
     You can pass in any combination of `MoveAction`s, `PushAction`s, and `WaitAction`s to this method.
     */
    public func perform(_ actions: [Action], repeating times: Int) {
        prepareAndRun(actions, repeating: .finite(times: times), completion: nil)
    }
    
    /**
     Performs a series of actions on a shape, repeating the series a given number of times.
     When the final repetition has finished, a completion function is called.
     
     - Parameter actions: The sequence of actions to perform.
     - Parameter repeating: The number of times to repeat.
     - Parameter completion: The function to run when no more repetitions remain.
     
     You can pass in any combination of `MoveAction`s, `PushAction`s, and `WaitAction`s to this method.
     */
    public func perform(_ actions: [Action], repeating times: Int, completion: @escaping () -> Void) {
        prepareAndRun(actions, repeating: .finite(times: times), completion: completion)
    }
    
    /**
     Performs a series of actions on a shape, repeating the series forever.
     
     - Parameter actions: The sequence of actions to perform.

     You can pass in any combination of `MoveAction`s, `PushAction`s, and `WaitAction`s to this method.
     */
    public func performForever(_ actions: [Action]) {
        prepareAndRun(actions, repeating: .infinite, completion: nil)
    }
    
    /**
     Cancels any running actions.
     */
    public func stopActions() {
        cancelCurrentAction()
    }

    private func prepareForTouchInteraction() {
        if !isImmobile {
            node.physicsBody?.affectedByGravity = false
//            node.physicsBody?.allowsRotation = false
            node.physicsBody?.angularVelocity = 0
            node.physicsBody?.velocity = .zero
        }
    }
    
    private func prepareForCompletedInteractions(interactionsCancelled: Bool) {
        if hasPhysics {
            node.physicsBody = cachedBody
//            node.physicsBody?.isDynamic = true
////            node.physicsBody?.pinned = false
            node.physicsBody?.affectedByGravity = isAffectedByGravity
//            node.physicsBody?.allowsRotation = true
//            node.physicsBody?.collisionBitMask = 1
        }
        
        if !isImmobile && !interactionsCancelled && touchTracker.timeSinceLastMotion < 0.1 {
//            print("\(tracker.smoothedVelocity)")
            var smoothedVelocity = touchTracker.smoothedVelocity
            smoothedVelocity.dx *= cachedBody?.mass ?? 1
            smoothedVelocity.dx *= cachedBody?.mass ?? 1
            node.physicsBody?.applyImpulse(touchTracker.smoothedVelocity)
        }
    }
    
    func filteredInteractions(from interactions: Set<NodeInteraction>) -> Set<NodeInteraction> {
        var passed = Set<NodeInteraction>()
        
        for interaction in interactions {
            let location = interaction.location(in: node)
            if path.contains(location) {
                passed.insert(interaction)
            }
        }
        
        return passed
    }
    
    private func interactionsBegan(_ interactions: Set<NodeInteraction>) {
        let filtered = filteredInteractions(from: interactions)
        guard filtered.count > 0 else { return }
        
        prepareForTouchInteraction()
        
        if self.hasPhysics {
            cachedBody = node.physicsBody
            
//            node.physicsBody?.pinned = true
            
//            node.physicsBody?.isDynamic = false
            
            // Physics-based dragging, but disabling (just) this dragged object from reacting to collisions.
//            node.physicsBody?.collisionBitMask = 0
            
            // Non-physics-based dragging (can't collide properly, but doesn't have problems with effects from other bodies)
            node.physicsBody = SKPhysicsBody.init(edgeChainFrom: path)
        }
        
        touchTracker.addInteractions(filtered)
    }
    
    private func interactionsMoved(_ interactions: Set<NodeInteraction>) {
        guard isDraggable else { return }
        
        guard interactions.count > 0 else { return }
        
        touchTracker.update()
        
//        print("\(tracker.smoothedVelocity)")
        
        onMoving()
    }
    
    private func interactionsEnded(_ interactions: Set<NodeInteraction>) {
        endInteractions(interactions, cancelled: false)
    }
    
    private func interactionsCancelled(_ interactions: Set<NodeInteraction>) {
        endInteractions(interactions, cancelled: true)
    }
    
    private func endInteractions(_ interactions: Set<NodeInteraction>, cancelled: Bool) {
        guard interactions.count > 0 else { return }

        prepareForCompletedInteractions(interactionsCancelled: cancelled)
        
        if !cancelled {
            if touchTracker.interpretableAsTap {
                onTapped()
            } else {
                onMoved()
            }
        }
        
        touchTracker.removeInteractions(interactions)
    }
    
}

//extension Shape : CustomStringConvertible {
//
//    public var description: String {
//        return node.physicsBody?.description ?? "No physics body"
//    }
//
//}

extension Shape : CustomPlaygroundDisplayConvertible {
    public var playgroundDescription: Any {
        return self.shape
    }
}

extension Shape : Equatable {
    public static func == (lhs: Shape, rhs: Shape) -> Bool {
        return lhs.node == rhs.node
    }
}

extension Shape {
    
    internal func physicsSimulated() {
        if isTracking && hasPhysics && !isImmobile {
            node.physicsBody?.affectedByGravity = false
            node.physicsBody?.allowsRotation = false
            node.physicsBody?.angularVelocity = 0
            node.physicsBody?.velocity = .zero
            
//            if tracker.currentPosition != node.position {
//                print("\(self.position.x - tracker.currentPosition.x) - \(self.position.y - tracker.currentPosition.y)")
//                node.position = tracker.currentPosition
//            }
        }
    }
    
}

/**
 An `OvalShape` is a kind of `Shape`. All the methods and properties
 belonging to `Shape` apply to `OvalShape`.
 */
open class OvalShape : Shape {
    
    public init(width: Double, height: Double) {
        let shape = SKShapeNode(ellipseIn: CGRect(x: 0, y: 0, width: width, height: height))
        
        super.init(shapeNode: shape)
    }
    
}

/**
 A `PolygonShape` is a kind of `Shape`. All the methods and properties
 belonging to `Shape` apply to `PolygonShape`.
 */
open class PolygonShape : Shape {
    
    public init(points: [Point]) {
        let normalizedPoints = points.normalized()
        
        let path = CGMutablePath()
        path.move(to: normalizedPoints.first!)
        for point in normalizedPoints {
            path.addLine(to: point)
        }
        path.closeSubpath()
        
        let shape = SKShapeNode(path: path)
        
        super.init(shapeNode: shape)
    }
    
}

extension CGPoint {
    static var shortStringFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.maximumFractionDigits = 2
        return f
    }()
    
    var shortString: String {
        let x = CGPoint.shortStringFormatter.string(from: NSNumber(value: Double(self.x)))!
        let y = CGPoint.shortStringFormatter.string(from: NSNumber(value: Double(self.y)))!
        return "(\(x), \(y))"
    }
}

extension CGVector {
    static func from(angle: Double, magnitude: Double) -> CGVector {
        return CGVector(dx: cos((angle - 90) * 2 * .pi / 360) * magnitude, dy: -sin((angle - 90) * 2 * .pi / 360) * magnitude)
    }
}

/**
 A description of independent `Shape` movement.
 
 `Action`s can either be `MoveAction`s or `PushAction`s. When you see `Action`
 listed as a type in the API, you can use either one. You shouldn't
 directly create an instance of the `Action` type.
 */
public class Action {
    fileprivate var action: SKAction
    
    fileprivate weak var shape: Shape?
    
    fileprivate var overridesPhysics: Bool {
        return false
    }
    
    fileprivate init(_ action: SKAction) {
        self.action = action
    }
}

/**
 Defines the linear movement of a `Shape`.
 
 If a shape is physics-based, it won't react to gravity or collisions while performing
 a `MoveAction`.
 */
public class MoveAction : Action {
    /**
     Creates a `MoveAction` starting from the `Shape`'s current point to the given point, over `duration` seconds.
     
     - Parameter point: The destination of the shape.
     - Parameter duration: The number of seconds before the shape arrives at its destination.
     */
    public init(to point: Point, duration: Double) {
        super.init(SKAction.move(to: point, duration: duration))
    }
    
    /**
     Creates a `MoveAction` starting from the `Shape`'s current position, over `duration` seconds. The destination
     point is calculated by adding the x and y components to the current position.
     
     - Parameter point: The destination of the shape.
     - Parameter duration: The number of seconds before the shape arrives at its destination.
     */
    public init(by point: Point, duration: Double) {
        super.init(SKAction.move(by: CGVector(dx: point.x, dy: point.y), duration: duration))
    }
    
    fileprivate override var overridesPhysics: Bool {
        return true
    }

}

extension MoveAction : CustomStringConvertible {
    public var description: String {
        return "Move"
    }
}

/**
 Defines a push applied to a physics-based `Shape`.
 
 If a shape isn't physics-based, this action will have no effect.
 */
public class PushAction : Action {
    
    private var direction: Double
    private var strength: Double
    
    override var action: SKAction {
        get {
            guard let shape = shape else { return SKAction() }
            
            return SKAction.run {
                shape.push(inDirection: self.direction, withStrength: self.strength)
            }
        }
        set {}
    }
    /**
     Creates a `PushAction` in a given direction with a given strength.
     
     - Parameter direction: The angle of the push in degrees, from 0 to 360, with 0 being straight up.
     - Parameter strength: The strength of the push.
     */
    public init(direction: Double, strength: Double) {
        self.direction = direction
        self.strength = strength
        super.init(SKAction())
    }
    
}

extension PushAction : CustomStringConvertible {
    public var description: String {
        return "Push"
    }
}

/**
 Defines a pause before executing the following action.
 
 Performing a `WaitAction` via `perform()` and then performing another action via a
 second call to `perform()` will not cause a delay. To delay an action, put a
 `WaitAction` into an array preceding the action you want to delay, and then pass
 the array to `perform()`.
 */
public class WaitAction : Action {
    
    /**
     Creates a `WaitAction` with a specified delay.
     
     - Parameter delay: The number of seconds to wait.
     */
    public init(delay: Double) {
        super.init(SKAction.wait(forDuration: delay))
    }

}

extension WaitAction : CustomStringConvertible {
    public var description: String {
        return "Wait"
    }
}

