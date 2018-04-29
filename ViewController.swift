import UIKit
import CoreLocation
import AVFoundation



struct place {
    let name : String?
    let id : String?
    let lat: Double?
    let long: Double?
}



var hasConnection = false

var knownLocations = [place]()
var namesInView = [String]()
var sortedNames = [String]()

var locationRecieved = false

var selectedPlace = place(name: nil, id: nil, lat: nil, long: nil)

var lat = Double()
var long = Double()
var lastLat = Double()
var lastLong = Double()

var camera : AVCaptureDevice?

var radius = 250

var selectedVisible = false

class ViewController: UIViewController, CLLocationManagerDelegate, UITableViewDelegate, UITableViewDataSource {
    
    
    var manager : CLLocationManager?
    
    var phoneAngle = Double()
    
    var location = CLLocation()
    
    @IBOutlet weak var cameraView: UIView!
    @IBOutlet weak var myTableView: UITableView!
    
    
    @IBOutlet weak var selectedLabel: UILabel!
    
    @IBOutlet weak var distLabel: UILabel!
    
    @IBOutlet weak var xButton: UIButton!
    
    @IBOutlet weak var changeRadius: UIImageView!
    
    @IBOutlet weak var changeView: UIView!
    
    @IBOutlet weak var radSlider: UISlider!
    
    @IBOutlet weak var radiusLabel: UILabel!
    
    @IBOutlet weak var refreshImage: UIImageView!
    
    
    var tbHeight: CGFloat?
    var deviceWidth: CGFloat?
    var angleImageView: UIImageView?
    
    var session: AVCaptureSession?
    var input: AVCaptureInput?
    var stillImageOutput: AVCapturePhotoOutput?
    var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        manager = CLLocationManager()
        
        tbHeight = myTableView.frame.height
        deviceWidth = self.view.frame.width
        
        manager?.desiredAccuracy = kCLLocationAccuracyBest
        manager?.requestWhenInUseAuthorization()
        manager?.delegate = self
        
        manager?.requestWhenInUseAuthorization()
        
        if CLLocationManager.locationServicesEnabled() {
            manager?.distanceFilter = 4
            manager?.startUpdatingLocation()
            manager?.requestLocation()
        }
        
        if CLLocationManager.headingAvailable() {
            manager?.headingFilter = 0.3
            manager?.startUpdatingHeading()
        }
        
        
        
        getCameraFeed()
        
        angleImageView = UIImageView.init(frame: CGRect(x:0,y: tbHeight! + 90, width: 50, height: 50))
        angleImageView?.alpha = 0
        angleImageView?.backgroundColor = UIColor(red: 1, green: 1, blue: 1, alpha: 0.7)
        angleImageView?.clipsToBounds = true
        angleImageView?.layer.cornerRadius = 15
        
        self.view.addSubview(angleImageView!)
        
        myTableView.delegate = self
        myTableView.dataSource = self
        
        selectedLabel.clipsToBounds = true
        selectedLabel.layer.zPosition = 100.0
        selectedLabel.layer.cornerRadius = 15
        
        distLabel.clipsToBounds = true
        distLabel.layer.zPosition = 100.0
        distLabel.layer.cornerRadius = 15
        
        xButton.clipsToBounds = true
        xButton.layer.zPosition = 100.0
        xButton.layer.cornerRadius = 15
        
        
        changeRadius.layer.cornerRadius = 15
        changeRadius.layer.zPosition = 100.0
        let tap = UITapGestureRecognizer(target: self, action: #selector(self.showRadiusView))
        changeRadius.addGestureRecognizer(tap)
        changeRadius.isUserInteractionEnabled = true
        
        
        refreshImage.layer.cornerRadius = 15
        refreshImage.layer.zPosition = 100.0
        let press = UITapGestureRecognizer(target: self, action: #selector(self.refresh))
        refreshImage.addGestureRecognizer(press)
        refreshImage.isUserInteractionEnabled = true
        
        changeView.layer.cornerRadius = 15
        changeView.layer.zPosition = 100.0
        
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print(error)
    }
    
    @objc func refresh() {
        analyzeSurroundings()
        findPlacesWithinAngle()
        print("refresh")
    }
    
    @objc func showRadiusView() {
        changeView.isUserInteractionEnabled = true
        changeView.alpha = 1.0
    }
    
    @IBAction func sliderMoved(_ sender: Any) {
        radiusLabel.text = "\(Int(radSlider.value))m"
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        let touch = touches.first
        let location = touch?.location(in: changeView)
        if  changeView.alpha == 1 && ((location?.x)! * (location?.y)! <= 0 || Double((location?.y)!) > 120.0 || (location?.x)! > deviceWidth! - 20.0){
            radius = Int(radSlider.value)
            Json.getJson()
            findPlacesWithinAngle()
            changeView.isUserInteractionEnabled = false
            changeView.alpha = 0
        }
    }
    
    func getCameraFeed() {
        session = AVCaptureSession()
        session!.sessionPreset = AVCaptureSession.Preset.photo
        camera = AVCaptureDevice.default(AVCaptureDevice.DeviceType.builtInWideAngleCamera,
                                         for: AVMediaType.video,
                                         position: .back)
        do {
            try camera?.lockForConfiguration()
            camera?.exposureMode = .continuousAutoExposure
            camera?.focusMode = .continuousAutoFocus
            camera?.unlockForConfiguration()
        }
        catch {
        }
        
        var error: NSError?
        do {
            input = try AVCaptureDeviceInput(device: camera!)
        } catch let error1 as NSError {
            error = error1
            input = nil
            print(error!.localizedDescription)
        }
        if error == nil && session!.canAddInput(input!) {
            session!.addInput(input!)
            stillImageOutput = AVCapturePhotoOutput()
            stillImageOutput?.isHighResolutionCaptureEnabled = true
            if session!.canAddOutput(stillImageOutput!) {
                session!.addOutput(stillImageOutput!)
                videoPreviewLayer = AVCaptureVideoPreviewLayer(session: session!)
                videoPreviewLayer!.videoGravity = AVLayerVideoGravity.resizeAspectFill
                videoPreviewLayer!.connection?.videoOrientation = AVCaptureVideoOrientation.portrait
                cameraView.layer.addSublayer(videoPreviewLayer!)
                session!.startRunning()
                videoPreviewLayer!.frame = cameraView.bounds
            }
        }
    }
    
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        phoneAngle = newHeading.magneticHeading * .pi / 180.0
        findPlacesWithinAngle()
        updateLabel()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        location = locations.last!
        lat = location.coordinate.latitude
        long = location.coordinate.longitude
        if !locationRecieved {
            refresh()
            locationRecieved = true
        }
        if location.distance(from: CLLocation(latitude: lastLat, longitude: lastLong)) > Double(radius / 3) {
            Json.getJson()
            lat = lastLat
            long = lastLong
        }
    }
    
    
    func analyzeSurroundings() {
        
        //get current coordinates
        
        location = (manager?.location)!
        long = location.coordinate.longitude as Double
        lat = location.coordinate.latitude as Double
        if lastLong == 0 {
            lastLong = long
            lastLat = lat
        }
        
        Json.getJson()
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        manager?.startUpdatingHeading()
        manager?.startUpdatingLocation()
        locationRecieved = false
        manager?.requestLocation()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        manager?.stopUpdatingHeading()
        manager?.stopUpdatingLocation()
    }
    
    func findPlacesWithinAngle() {
        for place in knownLocations {
            var angle = atan((place.long! - long) / (place.lat! - lat))
            
            if place.lat! - lat < 0 {
                angle += .pi
            }
            
            if angle < 0 {
                angle += 2 * .pi
            }
            
            let difference = angle - phoneAngle
            
            if namesInView.contains(place.name!) {
                if !isInView(diff: difference) {
                    let index = namesInView.index(of: place.name!)!
                    namesInView.remove(at: index)
                }
            } else {
                if isInView(diff: difference) {
                    namesInView.append(place.name!)
                }
            }
        }
        sortedNames = namesInView.sorted()
        myTableView.reloadData()
    }
    
    func isInView(diff : Double) -> Bool {
        let difference = abs(diff)
        if difference > 2 * .pi - 0.35  {
            return true
        }
        return difference < 0.35
    }
    
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return max(namesInView.count,1)
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return tbHeight! / CGFloat(max(min(namesInView.count,10),1))
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = myTableView.dequeueReusableCell(withIdentifier: "cell")
        let label = cell?.viewWithTag(1) as! UILabel
        let num = cell?.viewWithTag(2) as! UILabel
        num.text = ""
        label.text = "No Place in Range"
        label.textColor = .gray
        if namesInView.count > 0 {
            num.text = "\(indexPath.row + 1)"
            if namesInView.count > 10 && num.text == "10" {
                num.text = "10+"
            }
            label.text = sortedNames[indexPath.row]
            label.textColor = .white
        }
        if !hasConnection {
            label.text = "No Connection"
        }
        return cell!
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let label = myTableView.cellForRow(at: indexPath)?.viewWithTag(1) as! UILabel
        let title = label.text
        if title != "No Place in Range" {
        for place in knownLocations {
            if place.name == title {
                selectedPlace = place
                selectedVisible = true
                selectedLabel.text = selectedPlace.name
                selectedLabel.alpha = 1.0
                distLabel.alpha = 1.0
                xButton.alpha = 1.0
                angleImageView?.alpha = 1.0
                updateLabel()
                break
            }
        }
        }
    }
    
    func updateLabel() {
        if selectedVisible {
            let distance = Int(round(location.distance(from: CLLocation(latitude: selectedPlace.lat!
                , longitude: selectedPlace.long!))))
            
            var angle = atan((selectedPlace.long! - long) / (selectedPlace.lat! - lat))
            
            if selectedPlace.lat! - lat < 0 {
                angle += .pi
            }
            
            if angle < 0 {
                angle += 2 * .pi
            }
            
            var difference = angle - phoneAngle
            
            let crossesZero = max(angle,phoneAngle) > min(angle,phoneAngle) + .pi
            
            if crossesZero  {
                if max(angle, phoneAngle) == angle {
                    difference -= 2 * .pi
                } else {
                    difference += 2 * .pi
                }
            }
            
            if isInView(diff: difference) {
                let offset = difference / 0.7 * Double(deviceWidth! - 70) + Double(deviceWidth! / 2)
                angleImageView?.transform = CGAffineTransform(translationX: CGFloat(offset) - 25, y: 0)
                angleImageView?.image = UIImage(named: "arrow_down")            } else if difference < 0 {
                angleImageView?.transform = CGAffineTransform(translationX: 10, y: 0)
                angleImageView?.image = UIImage(named: "arrow_left")
            } else {
                angleImageView?.transform = CGAffineTransform(translationX: deviceWidth! - 60, y: 0)
                angleImageView?.image = UIImage(named: "arrow_right")
            }
            
            distLabel.text = "\(distance)m"
            
            
        }
    }
    
    @IBAction func hideLabel(_ sender: Any) {
        selectedVisible = false
        selectedLabel.alpha = 0
        distLabel.alpha = 0
        xButton.alpha = 0
        angleImageView?.alpha = 0
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
}
