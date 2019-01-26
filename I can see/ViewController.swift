//
//  ViewController.swift
//  I can see
//
//  Created by Daniel Foldi on 2019. 01. 26..
//  Copyright © 2019. Daniel Foldi. All rights reserved.
//

import UIKit                                                                                    // UIKit is the framework for iOS UI elements, like text views, buttons etc.
import ARKit                                                                                    // ARKit enables AR features, like mapping a point to an object in real world
import Vision                                                                                   // Vision lets us do computer vision stuff, in this case, classify an image
import AVKit                                                                                    // AVKit is used for speech synthesis in this program, it is also responsible of playing back audio and video
import SceneKit                                                                                 // SceneKit is a 3D framework, used to display predictions in "3D"

class ViewController: UIViewController, ARSCNViewDelegate, AVSpeechSynthesizerDelegate {        // Main class implementation, conforms to two protocols which trigger "events"
    
    let textDepth: CGFloat = 0.01                                                               // Specify the depth of the 3D text
    var lastPrediction = ""                                                                     // This variable holds the last prediction
    var lastSpoken = ""                                                                         // This variable holds the last spoken prediction
    
    let vowels: [Character] = ["a", "e", "i", "o", "u"]                                         // This array holds all wovels, used when speaking predictions
    
    let speechSynthesizer = AVSpeechSynthesizer()                                               // This object is used to synthesize speech
    var nodes = [SCNNode]()                                                                     // This array holds all nodes previously placed in the world
    var requests = [VNRequest]()                                                                // This array holds all Vision requests
    
    let dispatchQueue = DispatchQueue(label: "machinelearning")                                 // A separate thread is used for time-consuming methods, like predictions
    
    @IBOutlet weak var mainView: ARSCNView!                                                     // This is the main view used to display the camera input and the placed nodes
    @IBOutlet weak var prediction1Label: UILabel!                                               // This is the label for the most confident prediction
    @IBOutlet weak var prediction2Label: UILabel!                                               // This is the label for the second most confident prediction
    
    override func viewDidLoad() {                                                               // This method is called any time the view is loaded into memory
        super.viewDidLoad()                                                                     // Let the superclass initialize itself
        
        speechSynthesizer.delegate = self                                                       // Set the speech synthesizers delegate to be this class
        mainView.delegate = self                                                                // Set the delegate of the view to be this class
        mainView.showsStatistics = true                                                         // Enable some debug statistics
        mainView.autoenablesDefaultLighting = true                                              // SceneKit will take care of lighting for us
        let scene = SCNScene()                                                                  // Create a new SCNScene
        mainView.scene = scene                                                                  // Assign it to the current view so we can add nodes later
        
        guard let model = try? VNCoreMLModel(for: Inceptionv3().model) else {                   // Import the model, could be replaced with others or compressed
            fatalError("Failed to initalize model")                                             // If this guarded statement fails, return with a fatal error
        }
        
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.tap(gestureRecognizer:)))  // Create a tap gesture recognizer so the user can add points themselves
        view.addGestureRecognizer(tapGestureRecognizer)                                         // Add this gesture recognizer to the view, so it becomes active
        
        let request = VNCoreMLRequest(model: model, completionHandler: classificationCompletedHandler)  // Create a request to classify image
        request.imageCropAndScaleOption = VNImageCropAndScaleOption.centerCrop                  // Set the scaling method to crop as required
        requests = [request]                                                                    // Add it to the requests array
        
        loopUpdate()                                                                            // Start the machine learning classification loop
        
    }
    
    override func viewWillAppear(_ animated: Bool) {                                            // This method will be called any time the view is about to appear, note that this is different that viewDidLoad
        super.viewWillAppear(animated)                                                          // Let the superclass handle its tasks
        
        let configuration = ARWorldTrackingConfiguration()                                      // Create a new configuration for tracking in AR
        configuration.planeDetection = .horizontal                                              // Set the plane detection method to detect horizontal planes
        mainView.session.run(configuration)                                                     // Start the session of the view
        print("running")
    }
    
    override func viewWillDisappear(_ animated: Bool) {                                         // This method will be called any time the view is about to disappear
        super.viewWillDisappear(animated)                                                       // Let the superclass handle its tasks
        mainView.session.pause()                                                                // Pause the AR session to save battery
        print("paused")
    }
    
    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {           // This method will be called any time a motion of the device has ended
        super.motionEnded(motion, with: event)                                                  // Let the superclass take care of any system-wide actions
        if motion == .motionShake {                                                             // We are looking for the shake motion
            if let last = nodes.last {                                                          // This evaluates true if there is any node in the nodes array
                last.removeFromParentNode()                                                     // We remove the node from the SCNScene
                nodes.removeLast()                                                              // We remove the node from the array
            }
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Release any cached data, images, etc that aren't in use.
    }
    
    override var prefersStatusBarHidden: Bool {                                                 // We can hide the status bar to get the full screen for the camera
        return true                                                                             // Return true to hide it
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {  // This is a delegate method
        // Do something after speaking
    }
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        DispatchQueue.main.async {
            //Update SceneKit here
        }
    }
    
    @objc func tap(gestureRecognizer: UITapGestureRecognizer) {                                 // This is the callback of the tap gesture recognizer
        addNode()                                                                               // Add a node with the latest prediction
    }
    
    
    
    func classificationCompletedHandler(request: VNRequest, error: Error?) {                    // This is the callback for the classification
        if let error = error {                                                                  // We check for an error
            fatalError("Error: \(error.localizedDescription)")                                  // Raise an error
        }
        guard let results = request.results else {                                              // The results can be anything
            print("No results")                                                                 // In this case probably something is wrong with the model
            return                                                                              // We jump the updates
        }
        
        let bestResults = results[0...1].compactMap({$0 as? VNClassificationObservation})       // Make sure the results are of type VNClassificationObservation and only 2 elements
        
        DispatchQueue.main.async {                                                              // UI updates can be done asynchronously, to save frame time
            print("----\n\(bestResults[0].identifier) \(bestResults[0].confidence), \(bestResults[1].identifier) \(bestResults[1].confidence)")  // Print some debug information
            
            self.prediction1Label.text = "\(bestResults[0].identifier) \(bestResults[0].confidence)"  // Set the first label's text
            self.prediction2Label.text = "\(bestResults[1].identifier) \(bestResults[1].confidence)"  // Set the second label's text
            
            self.lastPrediction = bestResults[0].identifier.components(separatedBy: ",")[0]     // This is some data cleaning from the model's response
            if bestResults[0].confidence > 0.6 && !self.speechSynthesizer.isSpeaking && self.lastSpoken != self.lastPrediction {  // We want to be confident enough, not talking, and it's a relatively good filter if we don't speak the same text twice
                let speechUtterance = AVSpeechUtterance(string: "I can see \(self.vowels.contains(self.lastPrediction.first ?? self.vowels[0]) ? "an" : "a") \(self.lastPrediction)")  // Create the text to be spoken
                self.speechSynthesizer.speak(speechUtterance)                                   // Speak the text
                self.lastSpoken = self.lastPrediction                                           // Set the lastSpoken so we won't speak it again
                self.addNode()                                                                  // Automatically add a bubble
            }
        }
    }
    
    func loopUpdate() {                                                                         // We call this function in viewWillAppear
        dispatchQueue.async {                                                                   // CoreML can be run on a separate thread, declared at the top
            self.updateCoreML()                                                                 // Update CoreML
            self.loopUpdate()                                                                   // Call this function again, to form a loop
        }
    }
    
    func updateCoreML() {                                                                       // This is the function that requests CoreML to classify the current image
        let buffer = mainView.session.currentFrame?.capturedImage                               // Get the mainView's image from the camera
        if buffer == nil {                                                                      // Check for any error, for example when no permission is given, or the device does not have a camera
            debugPrint(mainView.session)
            return                                                                              // Skip the rest of the update function
        }
        let image = CIImage(cvImageBuffer: buffer!)                                             // Convert the buffer to CIImage
        let requestHandler = VNImageRequestHandler(ciImage: image, options: [:])                // Create the Vision request handler
        do {                                                                                    // do {} blocks let you call throwing functions
            try requestHandler.perform(requests)                                                // Try to perform the requests
        } catch {                                                                               // If anything goes wrong, this will catch the error
            print(error)                                                                        // Print the error
        }
    }
    
    func addNode() {                                                                            // This function calculates the coordinates for a new bubble that is to be added
        let center = CGPoint(x: mainView.bounds.midX, y: mainView.bounds.midY)                  // Calculate the center coordinates of the view
        
        let hitTest = mainView.hitTest(center, types: [.featurePoint])                          // Hit tests determine what you are looking at
        if let result = hitTest.first {                                                         // This evaluates true if there is something that you hit
            let transform = result.worldTransform                                               // This gives the position relative to the world
            let coords = SCNVector3Make(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)  // Create an SCNVector3 that holds this position
            let node = createBubble(text: lastPrediction)                                       // Create a bubble with the last prediction as text
            mainView.scene.rootNode.addChildNode(node)                                          // Add the bubble to the scene
            nodes.append(node)                                                                  // Append it to the nodes array
            node.position = coords                                                              // Set the position to the previously created vector
        }
    }
    
    func createBubble(text: String) -> SCNNode {                                                // This function creates an SCNNode containing a bubble
        let billboardConstraint = SCNBillboardConstraint()                                      // SCNBillboardConstraints limit the freedom of rotation of an object
        billboardConstraint.freeAxes = .Y                                                       // We only want it to rotate on the Y axis
        
        let bubbleText = SCNText(string: text, extrusionDepth: textDepth)                       // Create an SCNText with the recieved text
        let font = UIFont(name: "Helvetica", size: 0.15)?.withTraits(traits: .traitBold)        // Create a font and set it to bold
        bubbleText.font = font                                                                  // Assign the previously created font
        bubbleText.alignmentMode = CATextLayerAlignmentMode.center.rawValue                     // Center the text
        bubbleText.firstMaterial?.diffuse.contents = UIColor.orange                             // Set the diffuse color to be orange
        bubbleText.firstMaterial?.specular.contents = UIColor.white                             // Set the specular color to be white
        bubbleText.firstMaterial?.isDoubleSided = true                                          // We want the material to be double sided
        bubbleText.chamferRadius = textDepth                                                    // We set a chamfer radius to make it more realistic
        
        let (minBound, maxBound) = bubbleText.boundingBox                                       // This is the bounding box of the SCNText created above
        let bubbleNode = SCNNode(geometry: bubbleText)                                          // Create a node that has the geometry of bubbleText
        bubbleNode.pivot = SCNMatrix4MakeTranslation((maxBound.x - minBound.x) / 2, minBound.y, Float(textDepth) / 2)  // Set the pivot point to the center, and bottom
        bubbleNode.scale = SCNVector3Make(0.2, 0.2, 0.2)                                        // Scale it down
        
        let sphere = SCNSphere(radius: 0.005)                                                   // Create a sphere
        sphere.firstMaterial?.diffuse.contents = UIColor.yellow                                 // Set the diffuse color to yellow
        let sphereNode = SCNNode(geometry: sphere)                                              // Create a node with the sphere as its geometry
        
        let parentNode = SCNNode()                                                              // Create an empty SCNNode
        parentNode.addChildNode(bubbleNode)                                                     // Add the bubble text as a child
        parentNode.addChildNode(sphereNode)                                                     // Add the sphere as a child
        parentNode.constraints = [billboardConstraint]                                          // Apply the constraint
        
        return parentNode                                                                       // Return the created node
    }
}
