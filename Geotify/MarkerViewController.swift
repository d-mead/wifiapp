import UIKit
import MapKit
import CoreLocation
import Foundation
import SystemConfiguration
import GLKit


struct PreferencesKeys {
  static let savedItems = "savedItems"
}

class MarkerViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
  
  @IBOutlet weak var mapView: MKMapView!            //main map view
  @IBOutlet var activeCounter: UIBarButtonItem!     //counter for active regions
  @IBOutlet var statusButton: UIBarButtonItem!      //hide/show button
  @IBOutlet var geoTable: UITableView!
  
  var geotifications: [Geotification] = []          //list of markers
  var geoNames: [String] = []                       //list of names of markers
  let locationManager = CLLocationManager()
  var editingGeo: Geotification? = nil              //geo being sent to be edited
  var timer = Timer()                               //timer used for the city, state updating in the table
  let delay = 0.5
  var count = 0                                     //counter for the active regions
  @IBOutlet var mapSwitch: UISegmentedControl!
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    locationManager.delegate = self
    locationManager.requestAlwaysAuthorization()
    loadAllGeotifications()
    for geo in geotifications {
      geo.makeLoc()               //makes the city, state location for all the geotifications
    }
    timer = Timer.scheduledTimer(timeInterval: 5, target: self, selector: #selector(updateGeoTable), userInfo: nil, repeats: false)
    
    geoTable.delegate = self
    geoTable.dataSource = self
    geoTable.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
    showTable()
    statusButton.title = "Hide"
    
    mapView.showAnnotations(mapView.annotations, animated: false)
    zoomAnnotationsOnMapView()
  }
  
  
  //called when the user selects a different map type
  @IBAction func mapChanged(_ sender: Any) {
    switch mapSwitch.selectedSegmentIndex {
    case 0:
      mapView.mapType = .standard
    case 1:
      mapView.mapType = .hybrid
    case 2:
      mapView.mapType = .satellite
    default:
      mapView.mapType = .standard
    }
  }
  
  
  //sets the zoom on the map view to encompass all of the annotations
  func zoomAnnotationsOnMapView() {
    if (mapView.annotations.count < 2) {
      return
    }
  
    let firstAnnotation = mapView.annotations[0]
    var minPoint = MKMapPointForCoordinate(firstAnnotation.coordinate)
    var maxPoint = minPoint
    
    for annotation in mapView.annotations {
      let point = MKMapPointForCoordinate(annotation.coordinate)
      if (point.x < minPoint.x)
      {minPoint.x = point.x}
      if (point.y < minPoint.y)
      {minPoint.y = point.y}
      if (point.x > maxPoint.x)
      {maxPoint.x = point.x}
      if (point.y > maxPoint.y)
      {maxPoint.y = point.y}
    }
    if locationManager.location != nil {
      let point = MKMapPointForCoordinate((locationManager.location?.coordinate)!)
      if (point.x < minPoint.x)
      {minPoint.x = point.x}
      if (point.y < minPoint.y)
      {minPoint.y = point.y}
      if (point.x > maxPoint.x)
      {maxPoint.x = point.x}
      if (point.y > maxPoint.y)
      {maxPoint.y = point.y}
    }
    
    let mapRect = MKMapRectMake(minPoint.x, minPoint.y, maxPoint.x - minPoint.x, maxPoint.y - minPoint.y)
  
    let navigatorHeight = 44
    let constant = 40
    let bottomHeight = 44*4 + CGFloat(navigatorHeight + constant)
    let edgePadding = UIEdgeInsetsMake(
      CGFloat(navigatorHeight + constant),
      CGFloat(constant),
      bottomHeight,
      CGFloat(constant))
  
    mapView.setVisibleMapRect(mapRect, edgePadding: edgePadding, animated: true)
  }
  
  
  //preparing segues
  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    if segue.identifier == "addGeotification" {
      let navigationController = segue.destination as! UINavigationController
      let vc = navigationController.viewControllers.first as! AddMarkerViewController
      vc.geoNames = geoNames
      let region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: mapView.centerCoordinate.latitude + (0.23*mapView.region.span.latitudeDelta), longitude: mapView.centerCoordinate.longitude), span: mapView.region.span)
      vc.reg = region
      vc.geotifications = geotifications
      vc.type = mapView.mapType
      vc.delegate = self
    }
    else if segue.identifier == "toEdit" {
      let navigationController = segue.destination as! UINavigationController
      let vc = navigationController.viewControllers.first as! EditMarkerViewController
      removeRadiusOverlay(forGeotification: editingGeo!)
      vc.geo = editingGeo!
      var tempNames = geoNames
      tempNames.index(of: (editingGeo?.name)!).map { tempNames.remove(at: $0) }
      vc.geoNames = tempNames
      let region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: mapView.centerCoordinate.latitude + (0.23*mapView.region.span.latitudeDelta), longitude: mapView.centerCoordinate.longitude), span: mapView.region.span)
      vc.reg = region
      vc.geotifications = geotifications.filter { $0 != editingGeo }
      vc.type = mapView.mapType
      vc.delegate = self
    }
  }
  
  
  //update the geo table
  @objc func updateGeoTable() {
    print("action has started")
    geoTable.reloadData()
    let cells = geoTable.visibleCells
    for cell in cells {
      if cell.detailTextLabel?.text == "" {
        if count < 5 {
          timer = Timer.scheduledTimer(timeInterval: 5, target: self, selector: #selector(updateGeoTable), userInfo: nil, repeats: false)
          count = count + 1
        }
        break
      }
    }
    updateGeotificationsCount()
  }
  
  
  //designing the cells
  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    var cell = tableView.dequeueReusableCell(withIdentifier: "reuseIdentifier")
    if cell == nil {
      cell = UITableViewCell(style: .value1, reuseIdentifier: "reuseIdentifier")
    }
    cell?.textLabel?.text = geotifications[indexPath.row].name
    cell?.detailTextLabel?.text = geotifications[indexPath.row].loc
    cell?.accessoryType = UITableViewCellAccessoryType.disclosureIndicator
    return cell!
  }
  
  //for deleting the rows when swipped on
  func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
    if editingStyle == .delete {
      print("begining delete")
      removeRadiusOverlay(forGeotification: geotifications[indexPath.row])
      remove(geotification: geotifications[indexPath.row])
      
      print("delete in tableView finished, count: " + String(geotifications.count))
      
    } else if editingStyle == .insert {
      // if adding a row
    }
  }
  
  
  //selected a row of the table
  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    let i = geoNames.index(of: geotifications[indexPath.row].name)
    editingGeo = geotifications[i!]
    tableView.deselectRow(at: indexPath, animated: true)
    self.performSegue(withIdentifier: "toEdit", sender: self)
  }
  
  
  //status button tapped
  @IBAction func statusTapped(_ sender: Any) {
    showHideTable()
  }
  
  
  //middle space tapped
  @IBAction func tapped(_ sender: Any) {
    showHideTable()
  }
  
  
  //counter tapped
  @IBAction func counterTapped(_ sender: Any) {
    showHideTable()
  }
  
  //shows the table
  func showTable() {
    statusButton.title = "Hide"
    geoTable.isHidden = false
    geoTable.reloadData()
  }
  
  
  //hides the table
  func hideTable() {
    statusButton.title = "Show"
    geoTable.isHidden = true
  }
  
  
  //shows or hides the table as appropriate
  func showHideTable() {
    if(geoTable.isHidden) {
      showTable()
    } else {
      hideTable()
    }
  }
  
  //number of columns in table
  func numberOfSectionsInTableView(tableView: UITableView) -> Int {
    return 1
  }
  
  //number of rows in table
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return geotifications.count
  }
  
  //retusn the list of Geotifications
  func getList() -> [Geotification]?
  {
    return geotifications
  }
  
  //loading data (geotifications list)
  func loadAllGeotifications() {
    geotifications = []
    guard let savedItems = UserDefaults.standard.array(forKey: PreferencesKeys.savedItems) else { return }
    for savedItem in savedItems {
      guard let geotification = NSKeyedUnarchiver.unarchiveObject(with: savedItem as! Data) as? Geotification else { continue }
      add(geotification: geotification)
      //print("accessed: " + geotification.loc!)
      addRadiusOverlay(forGeotification: geotification)
    }
  }
  
  
  //saving data (geotifications list)
  func saveAllGeotifications() {
    var items: [Data] = []
    for geotification in geotifications {
      let item = NSKeyedArchiver.archivedData(withRootObject: geotification)
      items.append(item)
    }
    
    UserDefaults.standard.set(items, forKey: PreferencesKeys.savedItems)
  }
  
  
  //adds geotification to all appropiate list, counters, view, etc
  func add(geotification: Geotification) {
    geotifications.append(geotification)
    geoNames.append(geotification.name)
    geotification.makeLoc()
    mapView.addAnnotation(geotification)
    addRadiusOverlay(forGeotification: geotification)
    geoTable.reloadData()
    updateGeotificationsCount()
    startMonitoring(geotification: geotification)
    print("new made")
    zoomAnnotationsOnMapView()
    showTable()
  }
  
  
  //removes geotification from all appropiate list, counters, view, etc
  func remove(geotification: Geotification) {
    print("begining remove function, count: " + String(geotifications.count))
    if let indexInArray = geotifications.index(of: geotification) {
      geotifications.remove(at: indexInArray)
      geoNames.remove(at: indexInArray)
    }
    print("remove function's remove complete count: " + String(geotifications.count))
    mapView.removeAnnotation(geotification)
    removeRadiusOverlay(forGeotification: geotification)
    updateGeotificationsCount()
    stopMonitoring(geotification: geotification)
    saveAllGeotifications()
    geoTable.reloadData()
    zoomAnnotationsOnMapView()
  }
  
  //updates the count of geotifications
  func updateGeotificationsCount() {
    var count = 0
    for geo in geotifications {
      if(geo.on)!{
          count += 1
      }
    }
    if(count == 1){
      activeCounter.title = String(describing: count) + " Active Marker"
    }
    else {
      activeCounter.title = String(describing: count) + " Active Markers"
    }
    navigationItem.rightBarButtonItem?.isEnabled = (geotifications.count < 20)
  }
  
  
  //adds a radius overlay for the geotification on the map view
  func addRadiusOverlay(forGeotification geotification: Geotification) {
    mapView?.add(MKCircle(center: geotification.coordinate, radius: geotification.radius))
  }
  
  //
  func removeRadiusOverlay(forGeotification geotification: Geotification) {
    // Find exactly one overlay which has the same coordinates & radius to remove
    guard let overlays = mapView?.overlays else { return }
    for overlay in overlays {
      guard let circleOverlay = overlay as? MKCircle else { continue }
      let coord = circleOverlay.coordinate
      if coord.latitude == geotification.coordinate.latitude && coord.longitude == geotification.coordinate.longitude && circleOverlay.radius == geotification.radius {
        mapView?.remove(circleOverlay)
        break
      }
    }
  }
  
  // MARK: Other mapview functions
  @IBAction func zoomToCurrentLocation(_ sender: Any) {
    if let userLocation = locationManager.location?.coordinate {
      let viewRegion = MKCoordinateRegionMakeWithDistance(userLocation, 250, 250)
      mapView.setRegion(viewRegion, animated: true)
    }
  }
  
}

// MARK: AddGeotificationViewControllerDelegate
extension MarkerViewController: AddMarkerViewControllerDelegate {
  
  func addMarkerViewController(controller: AddMarkerViewController, didAddCoordinate coordinate: CLLocationCoordinate2D, radius: Double, identifier: String, note: String, delay: Int, on: Bool) {
    controller.dismiss(animated: true, completion: nil)
    print("yep")
    let geotification = Geotification(coordinate: coordinate, radius: radius, identifier: identifier, name: note, delay: delay, on: on)
    print("new geo's delay: " + String(delay))
    print("new geo's on value: " + String(on))
    geotification.makeLoc()
    print("making loc")
    geotification.delay = delay
    add(geotification: geotification)
    addRadiusOverlay(forGeotification: geotification)
    saveAllGeotifications()
  }
  
}

extension MarkerViewController: EditMarkerViewControllerDelegate {
  
  func editMarkerViewController(controller: EditMarkerViewController, didAddCoordinate coordinate: CLLocationCoordinate2D, radius: Double, identifier: String, note: String, editing: Geotification, delay: Int, on: Bool) {
    controller.dismiss(animated: true, completion: nil)
    if identifier == "-1" {
      remove(geotification: geotifications[geoNames.index(of: (editingGeo?.name)!)!])
    } else {
      stopMonitoring(geotification: editingGeo!)
      removeRadiusOverlay(forGeotification: editingGeo!)
      geoNames[geoNames.index(of: (editingGeo?.name)!)!] = note
      //editingGeo?.makeLoc()
      print("making loc")
      editingGeo?.coordinate = coordinate
      editingGeo?.radius = radius
      editingGeo?.identifier = identifier
      editingGeo?.name = note
      editingGeo?.delay = delay
      editingGeo?.on = on
      addRadiusOverlay(forGeotification: editing)
      editingGeo?.clearLoc()
      geotifications[geoNames.index(of: (editingGeo?.name)!)!].clearLoc()
      geoTable.reloadData()
      editingGeo?.makeLoc()
      mapView.removeAnnotation(geotifications[geoNames.index(of: (editingGeo?.name)!)!])
      mapView.addAnnotation(geotifications[geoNames.index(of: (editingGeo?.name)!)!])
      addRadiusOverlay(forGeotification: editingGeo!)
      timer = Timer.scheduledTimer(timeInterval: 5, target: self, selector: #selector(updateGeoTable), userInfo: nil, repeats: false)
      //geoTable.reloadData()
      updateGeotificationsCount()
      print("edits made")
      startMonitoring(geotification: editingGeo!)
      saveAllGeotifications()
    }
    zoomAnnotationsOnMapView()
  }
  
}

// MARK: - Location Manager Delegate
extension MarkerViewController: CLLocationManagerDelegate {
  func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
    mapView.showsUserLocation = (status == .authorizedAlways)
  }
  func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
    print("Monitoring failed for region with identifier: \(region!.identifier)")
    print(String(describing: error))
    //self.locationManager.startMonitoring(for: region!)
  }
  
  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    print("Location Manager failed with the following error: \(error)")
  }
}

// MARK: - MapView Delegate
extension MarkerViewController: MKMapViewDelegate {
  
  func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
    print("tapped")
    let identifier = "myGeotification"
    if annotation is Geotification {
      var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKPinAnnotationView
      if annotationView == nil {
        annotationView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: identifier)
        annotationView?.canShowCallout = true
        let editButton = UIButton(type: .custom)
        editButton.frame = CGRect(x: 0, y: 0, width: 36, height: 23)
        editButton.setTitle("Edit", for: .normal)
        editButton.setTitleColor(UIColor.blue, for: .normal)
        annotationView?.leftCalloutAccessoryView = editButton
      } else {
        annotationView?.annotation = annotation
      }
      return annotationView
    }
    return nil
  }
  
  
  func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
    if overlay is MKCircle {
      let circleRenderer = MKCircleRenderer(overlay: overlay)
      circleRenderer.lineWidth = 1.0
      let color = UIColor(
        red: 3.0/255.0,
        green: 195.0/255.0,
        blue: 119.0/255.0,
        alpha: CGFloat(1.0)
      )
      let colorLight = UIColor(
        red: 3.0/255.0,
        green: 195.0/255.0,
        blue: 119.0/255.0,
        alpha: CGFloat(0.4)
      )
      circleRenderer.strokeColor = color
      circleRenderer.fillColor = colorLight
      return circleRenderer
    }
    return MKOverlayRenderer(overlay: overlay)
  }
  
  //MARK: Annotation is tapped
  func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
    //move to the edit screen
    let i = geoNames.index(of: view.annotation!.title as! String)
    editingGeo = geotifications[i!]
    let pin = view.annotation
    mapView.deselectAnnotation(pin, animated: false)
    self.performSegue(withIdentifier: "toEdit", sender: self)
  }
  
  func region(withGeotification geotification: Geotification) -> CLCircularRegion {
    let region = CLCircularRegion(center: geotification.coordinate, radius: geotification.radius, identifier: geotification.identifier)
    return region
  }
  
  func startMonitoring(geotification: Geotification) {
    if !CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) {
      showAlert(withTitle:"Error", message: "Geofencing is not supported on this device!")
      return
    }
    if CLLocationManager.authorizationStatus() != .authorizedAlways {
      showAlert(withTitle: "Warning", message: "Your marker is saved but will only be activated once you grant this app permission to access this device's location")
    }
    let region = self.region(withGeotification: geotification)
    locationManager.startMonitoring(for: region)
  }
  
  func stopMonitoring(geotification: Geotification) {
    for region in locationManager.monitoredRegions {
      guard let circularRegion = region as? CLCircularRegion, circularRegion.identifier == geotification.identifier else { continue }
      locationManager.stopMonitoring(for: circularRegion)
    }
  }
  
  func mapView(_: MKMapView, regionWillChangeAnimated: Bool) {
    //hideTable()
  }

  
  func isInternetAvailable() -> Bool
  {
    var zeroAddress = sockaddr_in()
    zeroAddress.sin_len = UInt8(MemoryLayout.size(ofValue: zeroAddress))
    zeroAddress.sin_family = sa_family_t(AF_INET)
    
    let defaultRouteReachability = withUnsafePointer(to: &zeroAddress) {
      $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {zeroSockAddress in
        SCNetworkReachabilityCreateWithAddress(nil, zeroSockAddress)
      }
    }
    
    var flags = SCNetworkReachabilityFlags()
    if !SCNetworkReachabilityGetFlags(defaultRouteReachability!, &flags) {
      return false
    }
    let isReachable = flags.contains(.reachable)
    let needsConnection = flags.contains(.connectionRequired)
    return (isReachable && !needsConnection)
  }
  
}



