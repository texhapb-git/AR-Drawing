import ARKit

class ViewController: UIViewController {

    // MARK: - Outlets
    
    @IBOutlet var sceneView: ARSCNView!
    
    // MARK: - Properties
    
    private let configuration = ARWorldTrackingConfiguration()
    
    /// Minimum distance between objects
    private let minimumDistance: Float = 0.05
    
    private var enableContinueDrawing: Bool = true
    
    enum ObjectPlacementMode {
        case freeform, plane, image
    }
    
    var objectMode: ObjectPlacementMode = .freeform
    
    /// Arrays of objects
    var objectNodes: [SCNNode] = []
    
    //Arrays of found planes
    var planeNodes: [SCNNode] = []
    
    /// The node selected by user
    var selectedNode: SCNNode?
    
    /// Last node placed by moving
    var lastNode: SCNNode?
    
    // Visualize planes
    var arePlanesHidden = true {
        didSet {
            planeNodes.forEach {
                $0.isHidden = arePlanesHidden
            }
        }
    }
    
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        sceneView.delegate = self
        sceneView.autoenablesDefaultLighting = true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadConfiguration()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
    }
    
    // MARK: - Methods
    
    /// Add object in 20 cm in front of camera
    /// - Parameter node: node of the object to add
    private func addNodeInFront(_ node: SCNNode) {
        
        // Get current camera frame
        guard let frame = sceneView.session.currentFrame else { return }
        
        // Get transform property of camera
        let transform = frame.camera.transform
        
        // Create translation matrix
        var translation = matrix_identity_float4x4
        
        // Translate by -20 cm on z axis
        translation.columns.3.z = -0.2
        
        // Rotate by pi/2 on z axis
        translation.columns.0.x = 0
        translation.columns.1.x = -1
        translation.columns.0.y = 1
        translation.columns.1.y = 0
        
        
        // Assign transform to the node
        node.simdTransform = matrix_multiply(transform, translation)
        
        // Add node to the scene
        addNodeToSceneRoot(node)
    }
    
    private func addNodeToImage(_ node: SCNNode, at point: CGPoint){
        guard let result = sceneView.hitTest(point, options: [:]).first else { return }
        guard result.node.name == "image" else { return }
        
        node.transform = result.node.worldTransform
        node.eulerAngles.x = 0
        
        addNodeToSceneRoot(node)
    }
    
    private func addNode(_ node: SCNNode, to parentNode: SCNNode) {
        
        // Check that object is not too closed to previous object
        if let lastNode = lastNode {
            let lastPosition = lastNode.position
            let newPosition = node.position
            
            let x = lastPosition.x - newPosition.x
            let y = lastPosition.y - newPosition.y
            let z = lastPosition.z - newPosition.z
            
            let distanceSquare = x*x + y*y + z*z
            let minimumDistanceSquare = minimumDistance * minimumDistance

            
            guard enableContinueDrawing && minimumDistanceSquare < distanceSquare else { return }
        }
        
        // Clone the node to create separated copies
        let clonedNode = node.clone()
        
        // Remember objects to undo
        objectNodes.append(clonedNode)
        
        // Remember last object
        lastNode = clonedNode
        
        // Add cloned node to the scene
        parentNode.addChildNode(clonedNode)
        
    }
    
    
    /// Add a node to user's touch location
    /// - Parameters:
    ///   - node: node to be added
    ///   - point: user's point touch the screen
    private func addNode(_ node: SCNNode, at point: CGPoint) {
        
        guard let hitResult = sceneView.hitTest(point, types: .existingPlaneUsingExtent).first else { return }
        guard let anchor = hitResult.anchor as? ARPlaneAnchor, anchor.alignment == .horizontal else { return }
        
        node.simdTransform = hitResult.worldTransform
        addNodeToSceneRoot(node)
        
    }
    
    private func addNodeToSceneRoot(_ node: SCNNode)  {
        addNode(node, to: sceneView.scene.rootNode)
    }
    
    
    private func reloadConfiguration(reset: Bool = false) {
        
        if reset {
            
            // Clear objects
            objectNodes.forEach { $0.removeFromParentNode() }
            objectNodes.removeAll()
            
            planeNodes.forEach { $0.removeFromParentNode() }
            planeNodes.removeAll()
            
            arePlanesHidden = false
        }
        
        let options: ARSession.RunOptions = reset ? .removeExistingAnchors : []
        
        configuration.detectionImages = ARReferenceImage.referenceImages(inGroupNamed: "AR Resources", bundle: nil)
        configuration.planeDetection = .horizontal
        sceneView.session.run(configuration, options: options)
    }
    
    private func processTouches(_ touches: Set<UITouch>){
        
        guard let touch = touches.first, let selectedNode = selectedNode else {
            return
        }
        
        let point = touch.location(in: sceneView)
        
        switch objectMode {
        case .freeform:
            addNodeInFront(selectedNode)
        case .image:
            addNodeToImage(selectedNode, at: point)
        case .plane:
            addNode(selectedNode, at: point)
            break
        }
        
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showOptions" {
            let optionsViewController = segue.destination as! OptionsContainerViewController
            optionsViewController.delegate = self
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        
        lastNode = nil
        self.processTouches(touches)
        
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        
        self.processTouches(touches)
        
    }

    // MARK: - Actions
    
    @IBAction func changeObjectMode(_ sender: UISegmentedControl) {
        switch sender.selectedSegmentIndex {
        case 0:
            objectMode = .freeform
            arePlanesHidden = true
        case 1:
            objectMode = .plane
            arePlanesHidden = false
        case 2:
            objectMode = .image
            arePlanesHidden = true
        default:
            break
        }
    }
    
    
}

// MARK: - OptionsViewControllerDelegate

extension ViewController: OptionsViewControllerDelegate {
    
    func enableContinue() {
        dismiss(animated: true)
        enableContinueDrawing.toggle()
    }
    
    
    func objectSelected(node: SCNNode) {
        dismiss(animated: true)
        selectedNode = node
    }
    
    func togglePlaneVisualization() {
        dismiss(animated: true)
        
        if objectMode == .plane {
            arePlanesHidden.toggle()
        }
    }
    
    func undoLastObject() {
        
        if let lastObject = objectNodes.last {
            lastObject.removeFromParentNode()
            objectNodes.removeLast()
        } else {
           dismiss(animated: true)
        }
    }
    
    func resetScene() {
        reloadConfiguration(reset: true)
        dismiss(animated: true)
    }
}

// MARK: - ARSCNViewDelegate
extension ViewController: ARSCNViewDelegate {
    
    func createFloor(with size: CGSize, opacity: CGFloat = 0.4) -> SCNNode {
        
        let plane = SCNPlane(width: size.width, height: size.height )
        plane.firstMaterial?.diffuse.contents = UIColor.green
        
        let planeNode = SCNNode(geometry: plane)
        planeNode.eulerAngles.x -= .pi / 2
        planeNode.opacity = opacity
        
        return planeNode
    }
    
    func updateFloor(for node: SCNNode, anchor: ARPlaneAnchor){
        
        guard let planeNode = node.childNodes.first, let plane = planeNode.geometry as? SCNPlane else {
            print(#line, #function, "Can't find SCNPlane at node \(node)")
            return
        }
        
        // Get plane size
        let extent = anchor.extent
        plane.width = CGFloat(extent.x)
        plane.height = CGFloat(extent.z)
        
        // Position the node in the center
        planeNode.simdPosition = anchor.center
        
    }
    
    func nodeAdded(_ node: SCNNode, for anchor: ARImageAnchor) {
        
        // Put plane above image
        let size = anchor.referenceImage.physicalSize
        let coverNode = createFloor(with: size, opacity: 0.01)
        coverNode.name = "image"
        node.addChildNode(coverNode)
    }
    
    func nodeAdded(_ node: SCNNode, for anchor: ARPlaneAnchor) {
        
        let extent = anchor.extent
        let planeNode = createFloor(with: CGSize(width: CGFloat(extent.x), height: CGFloat(extent.z)))
        planeNode.isHidden = arePlanesHidden
        
        // Add plane node to the list
        planeNodes.append(planeNode)
        
        node.addChildNode(planeNode)
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        
        switch anchor {
        case let imageAnchor as ARImageAnchor:
            nodeAdded(node, for: imageAnchor)
        case let planeAnchor as ARPlaneAnchor:
            nodeAdded(node, for: planeAnchor)
        default:
            print(#line, #function, "Unknown plane \(anchor) is detected")
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        
        switch anchor {
        case is ARImageAnchor:
            break
        case let planeAnchor as ARPlaneAnchor:
            updateFloor(for: node, anchor: planeAnchor)
        default:
            print(#line, #function, "Unknown plane \(anchor) is updated")
        }
    }
    
}
