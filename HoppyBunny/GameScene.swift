//
//  GameScene.swift
//  HoppyBunny
//
//  Created by 高宇超 on 6/21/16.
//  Copyright (c) 2016 Yuchao. All rights reserved.
//

import SpriteKit

enum GameSceneState {
    case Active, GameOver
}


class GameScene: SKScene, SKPhysicsContactDelegate {
    
    // variables
    static let scrollSpeedCons: CGFloat = 160
    let scrollCloudSpeed: CGFloat = 51
    let scrollMoutnSpeed: CGFloat = 10
    var scrollSpeed: CGFloat = scrollSpeedCons
    
    let fixedDelta: CFTimeInterval = 1.0 / 60.0 // 60 FPS
    var sinceTouch: CFTimeInterval = 0

    let spawnDist: Float = Float(scrollSpeedCons) * 1.4
    var spawnTimer: CFTimeInterval = 0
    var spawnTime: Float = 1.4

    let scoreStr = "Highest Score: "
    var points = 0
    var highScore = 0

    // nodes
    var hero: SKSpriteNode!
    var scrollLayer: SKNode!
    var obstacleLayer: SKNode!
    var scrollCloudLayer: SKNode!
    var scrollMoutnLayer: SKNode!
    var scoreLabel: SKLabelNode!
    var highestScoreLabel: SKLabelNode!
    var buttonStart: MSButtonNode!
    var buttonRestart: MSButtonNode!

    var heroBody: SKPhysicsBody!
    
    // game state
    var gameState: GameSceneState = .GameOver
    
    override func didMoveToView(view: SKView) {
        /* Setup your scene here */
        
        /* Recursive node search for 'hero' (child of referenced node) */
        hero = self.childNodeWithName("//hero") as! SKSpriteNode
        heroBody = hero.physicsBody
        
        buttonStart = self.childNodeWithName("buttonStart") as! MSButtonNode
        buttonRestart = self.childNodeWithName("buttonRestart") as! MSButtonNode
        scoreLabel = self.childNodeWithName("scoreLabel") as! SKLabelNode
        highestScoreLabel = buttonRestart.childNodeWithName("highestScore") as! SKLabelNode

        /* Set reference to scroll layer node */
        scrollLayer = self.childNodeWithName("scrollLayer")
        scrollCloudLayer = self.childNodeWithName("scrollCloud")
        scrollMoutnLayer = self.childNodeWithName("scrollMoutn")
        
        /* Set reference to obstacle layer node */
        obstacleLayer = self.childNodeWithName("obstacleLayer")
        
        physicsWorld.contactDelegate = self
        
        buttonStart.selectedHandler = {
            self.buttonStart.state = .Hidden
            self.gameState = .Active
            self.heroBody?.velocity = CGVectorMake(0, 400)
            self.heroBody?.affectedByGravity = true
            self.scoreLabel.hidden = false
        }
        heroBody?.velocity = CGVectorMake(0, 0)
        heroBody?.affectedByGravity = false

        buttonRestart.selectedHandler = {
            let skView = self.view as SKView!
            let scene = GameScene(fileNamed: "GameScene") as GameScene!
            
            /* Ensure correct aspect mode */
            scene.scaleMode = .AspectFill
            
            /* Restart game scene */
            skView.presentScene(scene)
        }

        // hide restart button
        buttonRestart.state = .Hidden
        scoreLabel.hidden = true
    }
    
    func didBeginContact(contact: SKPhysicsContact) {
        /* Hero touches anything, game over */
        
        if gameState != .Active {
            return
        }
        
        /* Get references to bodies involved in collision //'cause there can only be two objects collided */
        let contactA: SKPhysicsBody = contact.bodyA
        let contactB: SKPhysicsBody = contact.bodyB
        
        /* Get references to the physics body parent nodes */
        let nodeA = contactA.node!
        let nodeB = contactB.node!
        
        /* Did our hero pass through the 'goal'? */
        if nodeA.name == "goal" || nodeB.name == "goal" {
            points += 1
            scoreLabel.text = String(points)
            if scrollSpeed < 240 {
                scrollSpeed = GameScene.scrollSpeedCons + CGFloat(points)
                spawnTime = spawnDist / Float(scrollSpeed)
            }
            
            // goal sound
            let goalSFX = SKAction.playSoundFileNamed("sfx_goal", waitForCompletion: false)
            self.runAction(goalSFX)
            
            return
        }
        
        gameOver()
    }
    
    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        /* Called when a touch begins */
        
        if gameState != .Active {
            return
        }
        
        /* Reset velocity, helps improve response against cumulative falling velocity */
        heroBody?.velocity = CGVectorMake(0, 0)
        
        /* Apply vertical impulse */
        heroBody?.applyImpulse(CGVectorMake(0, 250))
        
        // hop sound
        let flapSFX = SKAction.playSoundFileNamed("sfx_flap", waitForCompletion: false)
        self.runAction(flapSFX)
        
        // subtle rotation
        heroBody?.applyAngularImpulse(2.1)
        
        // reset touch timer
        sinceTouch = 0
    }
    
    override func update(currentTime: CFTimeInterval) {
        /* Called before each frame is rendered */
        
        if gameState != .Active {
            return
        }
        
        buttonStart.state = .Hidden
        
        /* Grab current velocity */
        let velocityY = heroBody?.velocity.dy ?? 0
        
        /* Check and cap vertical velocity */
        if velocityY > 400 {
            heroBody?.velocity.dy = 400
        }
        
        // falling rotation
        if sinceTouch > 0.1 {
            let impluse = -20000 * fixedDelta
            heroBody?.applyAngularImpulse(CGFloat(impluse))
        }
        
        // clamp rotation
        hero.zRotation.clamp(CGFloat(-81).degreesToRadians(), CGFloat(30).degreesToRadians())
        heroBody?.angularVelocity.clamp(-3, 12)
        
        // update last touch timer
        sinceTouch += fixedDelta
        
        // scrolling world
        scrollWorld(scrollLayer, scrollSpeed: scrollSpeed)
        scrollWorld(scrollCloudLayer, scrollSpeed: scrollCloudSpeed)
        scrollWorld(scrollMoutnLayer, scrollSpeed: scrollMoutnSpeed)
        
        // update obstacles
        updateObstacles()
    }
    
    func scrollWorld(scrollLayer: SKNode, scrollSpeed: CGFloat) {
        scrollLayer.position.x -= scrollSpeed * CGFloat(fixedDelta)
        
        /* Loop through scroll layer nodes */
        for layer in scrollLayer.children as! [SKSpriteNode] {
            /* Get ground node position, convert node position to scene space */
            let groundPos = scrollLayer.convertPoint(layer.position, toNode: self)
            
            /* Check if ground sprite has left the scene */
            if groundPos.x <= -layer.size.width / 2 {
                /* Reposition ground sprite to the second starting position */
                let newPos = CGPointMake((self.size.width / 2) + layer.size.width, groundPos.y)
                
                /* Convert new node position back to scroll layer space */
                layer.position = self.convertPoint(newPos, toNode: scrollLayer)
            }
        }
    }
    
    func updateObstacles() {
        /* Update Obstacles */
        obstacleLayer.position.x -= scrollSpeed * CGFloat(fixedDelta)
        
        /* Loop through obstacle layer nodes */
        for obstacle in obstacleLayer.children as! [SKReferenceNode] {
            /* Get obstacle node position, convert node position to scene space */
            let obstaclePos = obstacleLayer.convertPoint(obstacle.position, toNode: self)
            
            /* Check if obstacle has left the scene */
            if obstaclePos.x <= 0 {
                /* Remove obstacle node from obstacle layer */
                obstacle.removeFromParent()
            }
        }
        
        /* Time to add a new obstacle? */
        if spawnTimer >= CFTimeInterval(spawnTime) {
            /* Create a new obstacle reference object using our obstacle resource */
            let resourcePath = NSBundle.mainBundle().pathForResource("Obstacle", ofType: "sks")
            let newObstacle = SKReferenceNode (URL: NSURL (fileURLWithPath: resourcePath!))
            obstacleLayer.addChild(newObstacle)
            
            /* Generate new obstacle position, start just outside screen and with a random y value */
            let rdPos = CGPointMake(352, CGFloat.random(min: 234, max: 382))
            
            /* Convert new node position back to obstacle layer space */
            newObstacle.position = self.convertPoint(rdPos, toNode: obstacleLayer)
            
            // Reset spawn timer
            spawnTimer = 0
        }
        
        spawnTimer += fixedDelta
    }
    
    func gameOver() {
        // stop scrolling
        gameState = .GameOver
        
        /* Stop any new angular velocity being applied */
        heroBody?.allowsRotation = false
        
        /* Reset angular velocity */
        heroBody?.angularVelocity = 0
        
        /* Stop hero flapping animation */
        hero.removeAllActions()
        
        /* Create our hero death action */
        let heroDeath = SKAction.runBlock({
            /* Put our hero face down in the dirt */
            self.hero.zRotation = CGFloat(-90).degreesToRadians()
            
            /* Stop hero from colliding with anything else besides ground */
            self.heroBody?.collisionBitMask = 4
        })
        
        hero.runAction(heroDeath)
        
        /* Load the shake action resource */
        let shakeScene: SKAction = SKAction.init(named: "Shake")!
        
        for node in self.children {
            /* Apply effect each ground node */
            node.runAction(shakeScene)
        }
        
        saveHighScore()
        highestScoreLabel.text = scoreStr + String(highScore.hashValue)
        buttonRestart.state = .Active
    }
    
    func saveHighScore() {
        let defaults = NSUserDefaults.standardUserDefaults()
        highScore = defaults.integerForKey("score")

        highScore = points > highScore ? points : highScore

        defaults.setInteger(highScore, forKey: "score")
    }
    
}
