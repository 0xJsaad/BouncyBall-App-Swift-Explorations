import Foundation

/*
The setup() function is called once when the app launches. Without it, your app won't compile.
Use it to set up and start your app.

You can create as many other functions as you want, and declare variables and constants,
at the top level of the file (outside any function). You can't write any other kind of code,
for example if statements and for loops, at the top level; they have to be written inside
of a function.
*/

let ball = OvalShape(width: 40, height: 40)

var barriers: [Shape] = [] // refactorizamos la segunda ronda agregando un arreglo para almacenar los obstaculos
var targets: [Shape] = []

// Agregar un embudo
let funnelPoints = [
    Point(x: 0, y: 50),
    Point(x: 80, y: 50),
    Point(x: 60, y: 0),
    Point(x: 20, y: 0)
]

let funnel = PolygonShape(points: funnelPoints)

fileprivate func setupBall() {
    ball.position = Point(x: 250, y: 400)
    scene.add(ball) // agrega el ball a la escena
    ball.hasPhysics = true // La propiedad hasPhysics participa en la simulación de la física del motor del juego
    ball.fillColor = .blue // Personalizo el color de nuestra pelota con la propiedad fillColor
    ball.onCollision = ballCollided(with:)
    
    ball.isDraggable = false // para e vitar que el usuario pueda arrastrar la pelota
    
    scene.trackShape(ball)
    ball.onExitedScene = ballExitedScene
    ball.onTapped = resetGame
    ball.bounciness = 0.6
}

// he modificado el nombre de la funcion setupBarrier() -> addBarrier()
fileprivate func addBarrier(at position: Point, width: Double, height: Double, angle: Double) {
    // A continuación agrego los parámetros a la función para que pueda especificar el ancho, altura, la posición y el ángulo
    let barrierPoints = [
        Point(x: 0, y: 0),
        Point(x: 0, y: height),
        Point(x: width, y: height),
        Point(x: width, y: 0)
    ]
    
    let barrier = PolygonShape(points: barrierPoints)
    
    barriers.append(barrier)
    
    // Código existente de setupBarrier() a continuación con actualizaciones de position y angle
    barrier.position = position
    barrier.hasPhysics = true
    scene.add(barrier)
    barrier.isImmobile = true
    barrier.fillColor = .brown
    barrier.angle = angle
}

fileprivate func setupFunnel() {
    funnel.position = Point(x: 200, y: scene.height - 25)
    scene.add(funnel)
    funnel.onTapped = dropBall // La propiedad onTapped es una función en donde la funcion dropBall dejará caer la pelota
    funnel.fillColor = .lightGray
    
    funnel.isDraggable = false // con esto evito que el usuario pueda arrastar el embudo
}

// ahora la función cambia de nombre setupTarget() -> addTarget()
func addTarget(at position: Point) {
    let targetPoints = [
        Point(x: 10, y: 0),
        Point(x: 0, y: 10),
        Point(x: 10, y: 20),
        Point(x: 20, y: 10)
    ]
    let target = PolygonShape(points: targetPoints)
    
    targets.append(target)

    // Código existente a la función setupTarget()
    target.position = position
    target.hasPhysics = true
    target.isImmobile = true
    target.isImpermeable = false
    target.fillColor = .yellow
    
    scene.add(target)
    target.name = "target"
    
    target.isDraggable = true
}

// Maneja las colisiones entre la bola y los objetos
func ballCollided(with otherShape: Shape) {
    if otherShape.name != "target" {return}
    otherShape.fillColor = .green
}

func setup() {
    scene.backgroundColor = .darkGray
    setupBall()
    
    /// Agregar un obstáculo a la escena.
    addBarrier(at: Point(x: 200, y: 150), width: 80, height: 25, angle: 0.1)

    // Agrega un embudo a la escena
    setupFunnel()
    
    // Agrego un obstáculo a la escena
    addBarrier(at: Point(x: 200, y: 150), width: 80, height: 25, angle: 0.1)
    addBarrier(at: Point(x: 100, y: 150), width: 30, height: 15, angle: -0.2)
    addBarrier(at: Point(x: 300, y: 150), width: 100, height: 25, angle: 0.03)
    // Agrego un objetivo a la escena
    addTarget(at: Point(x: 133, y: 614))
    addTarget(at: Point(x: 111, y: 474))
    addTarget(at: Point(x: 256, y: 280))
    addTarget(at: Point(x: 151, y: 242))
    addTarget(at: Point(x: 165, y: 40))
    
    resetGame() // para que el juego se inicie sin la pelota en la pantalla
    
    scene.onShapeMoved = printPosition(of:)
}

// Deja caer la pelota al moverla a la posición del embudo.
func dropBall() {
    ball.position = funnel.position
    
    ball.stopAllMotion() // para detener la pelota que se escapa
    // barrier es ahora un elemento de barriers, por cuanto lo recorro con un ciclo y agrego a cada obstaculo la propiedad de false
    for barrier in barriers {
        barrier.isDraggable = false
    }
    for target in targets {
        target.fillColor = .yellow
    }
}

func ballExitedScene() {
    for barrier in barriers {
        barrier.isDraggable = true
    }
    var hitTargets = 0
    for target in targets {
        if target.fillColor == .green {
            hitTargets += 1
        }
    }
    if hitTargets == targets.count {
        scene.presentAlert(text: "🥳 ¡Pentakill! 🎉", completion: alertDismissed)
    }
}
func alertDismissed() {}

// Reestablese el juego al mover la pelota por debajo de la escena
// esto desbloqueará los obstáculos
func resetGame() {
    ball.position = Point(x: 0, y: -80)
}

func printPosition(of shape: Shape)  {
    print(shape.position)
}
