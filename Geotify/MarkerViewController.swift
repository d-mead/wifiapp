/**
 * Copyright (c) 2016 Razeware LLC
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

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
  
  @IBOutlet weak var mapView: MKMapView!
  
  var geotifications: [Geotification] = []
  var geoNames: [String] = []
  var geoAddress: [String] = []
  let locationManager = CLLocationManager()
  var editingGeo: Geotification? = nil
  @IBOutlet var statusButton: UIBarButtonItem!
  var wifiStatus = "Status: Unknown"
  @IBOutlet var geoTable: UITableView!
  let geocoder = CLGeocoder()
  var placemark: CLPlacemark?
  var city: String?
  var state: String?
  var timer = Timer()
  var timer2 = Timer()
  let delay = 0.5
  var count = 0

  override func viewDidLoad() {
    super.viewDidLoad()
    
    locationManager.delegate = self
    locationManager.requestAlwaysAuthorization()
    loadAllGeotifications()
    for geo in geotifications {
      geo.makeLoc()
    }
    
    if isInternetAvailable() {
      statusButton.title = "Status: Connected"
    } else {
      statusButton.title = "Status: Disconnected"
    }
    geoTable.delegate = self
    geoTable.dataSource = self
    geoTable.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
    mapView.showAnnotations(mapView.annotations, animated: false)
    timer = Timer.scheduledTimer(timeInterval: 5, target: self, selector: #selector(updateGeoTable), userInfo: nil, repeats: false)
    showTable()
    
    /*self.mapView.addAnnotations(mapView.annotations)
    let currentView = mapView.visibleMapRect
    mapView.annotations(in: currentView)*/
    zoomAnnotationsOnMapView()
    showTable()
  }
  
  func zoomAnnotationsOnMapView()
  {
    if (mapView.annotations.count < 2) {
      return
    }
  
  // Step 1: make an MKMapRect that contains all the annotations
    _ = mapView.annotations;
  
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
  
  // Step 2: Calculate the edge padding
  
  /*let edgePadding = UIEdgeInsetsMake(
    CGRectGetMinY(10),
    CGRectGetMinX(10),
    CGRectGetMaxY(20) - CGRectGetMaxY(10),
    CGRectGetMaxX(20) - CGRectGetMaxX(10)
  )*/
    let navigatorHeight = 44
    let constant = 40
    let bottomHeight = 44*4 + CGFloat(navigatorHeight + constant)
    let edgePadding = UIEdgeInsetsMake(
      CGFloat(navigatorHeight + constant),
      CGFloat(constant),
      bottomHeight,
      CGFloat(constant))
  
  // Step 3: Set the map rect
    //mapView.setVisibleMapRect(mapRect: mapRect, edgePadding: edgePadding, animated: true)
    mapView.setVisibleMapRect(mapRect, edgePadding: edgePadding, animated: true)
  }
  
  //MARK: Prepare Segues
  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    if segue.identifier == "addGeotification" {
      let navigationController = segue.destination as! UINavigationController
      let vc = navigationController.viewControllers.first as! AddMarkerViewController
      vc.geoNames = geoNames
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
      vc.delegate = self
    }
  }
  
  
  @objc func updateGeoTable() {
    print("action has started")
    geoTable.reloadData()
    let cells = geoTable.visibleCells as! Array<UITableViewCell>
    for cell in cells {
      if cell.detailTextLabel?.text == "" {
        if count < 5 {
          timer = Timer.scheduledTimer(timeInterval: 5, target: self, selector: #selector(updateGeoTable), userInfo: nil, repeats: false)
          count = count + 1
        }
        break
      }
    }

  }
  
  /*@objc func checkLocs() {
    if geotifications[geotifications.count-1].loc != nil {
      geoTable.reloadData()
    } else {
        timer = Timer.scheduledTimer(timeInterval: 5, target: self, selector: #selector(checkLocs), userInfo: nil, repeats: false)
    }
  }*/
  
  @objc func checkConnection() {
    if isInternetAvailable() {
      statusButton.title = "Status: Connected"
    } else {
      statusButton.title = "Status: Disconnected"
    }
  }
  
  
  // Mark: desiging the cell
  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    var cell = tableView.dequeueReusableCell(withIdentifier: "reuseIdentifier")
    if cell == nil {
      cell = UITableViewCell(style: .value1, reuseIdentifier: "reuseIdentifier")
    }
    cell?.textLabel?.text = geotifications[indexPath.row].name
    cell?.detailTextLabel?.text = geotifications[indexPath.row].loc
    
    //print("designing cell: " + geotifications[indexPath.row].loc!)
    /*var address = geotifications[indexPath.row].loc {
      didSet {
        print("changed")
      }
    }*/
    //cell?.detailTextLabel?.text = address
    cell?.accessoryType = UITableViewCellAccessoryType.disclosureIndicator
    return cell!
  }
  
  func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
    
    if editingStyle == .delete {
      print("begining delete")
      remove(geotification: geotifications[indexPath.row])
      //removeRadiusOverlay(forGeotification: geotifications[indexPath.row])
      //geoTable.deleteRows(at: [indexPath], with: .fade)
      
      print("delete in tableView finished, count: " + String(geotifications.count))
      
    } else if editingStyle == .insert {
      // Not used in our example, but if you were adding a new row, this is where you would do it.
    }
  }
  
  
  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    let i = geoNames.index(of: geotifications[indexPath.row].name)
    editingGeo = geotifications[i!]
    tableView.deselectRow(at: indexPath, animated: true)
    self.performSegue(withIdentifier: "toEdit", sender: self)
  }
  
  func newLocationAvalable() {
    geoTable.reloadData()
    print("update reguest recieved")
  }
  
  @IBAction func statusTapped(_ sender: Any) {
    showHideTable()
  }
  @IBAction func tapped(_ sender: Any) {
    showHideTable()
  }
  
  
  func dist(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Int {
    return 10
  }

  func showTable()
  {
    self.geoTable.isHidden = false
    geoTable.reloadData()
  }
  func hideTable(){
    geoTable.isHidden = true
  }
  func showHideTable(){
    if(geoTable.isHidden) {
      showTable()
    } else {
      hideTable()
    }
  }
  
  func numberOfSectionsInTableView(tableView: UITableView) -> Int {
    // 1
    return 1
  }
  
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    // 2
    return geotifications.count
  }
  
  func getList() -> [Geotification]?
  {
    return geotifications
  }
  
  // MARK: Loading and saving functions
  func loadAllGeotifications() {
    geotifications = []
    guard let savedItems = UserDefaults.standard.array(forKey: PreferencesKeys.savedItems) else { return }
    for savedItem in savedItems {
      guard let geotification = NSKeyedUnarchiver.unarchiveObject(with: savedItem as! Data) as? Geotification else { continue }
      add(geotification: geotification)
      //geoAddress.append(geotification.loc!)
      //print("accessed: " + geotification.loc!)
      addRadiusOverlay(forGeotification: geotification)
    }
  }
  
  func saveAllGeotifications() {
    var items: [Data] = []
    for geotification in geotifications {
      let item = NSKeyedArchiver.archivedData(withRootObject: geotification)
      items.append(item)
    }
    
    UserDefaults.standard.set(items, forKey: PreferencesKeys.savedItems)
  }
  
  // MARK: Functions that update the model/associated views with geotification changes
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
  
  func updateGeotificationsCount() {
    title = "Markers (\(geotifications.count))"
    navigationItem.rightBarButtonItem?.isEnabled = (geotifications.count < 20)
  }
  
  // MARK: Map overlay functions
  func addRadiusOverlay(forGeotification geotification: Geotification) {
    mapView?.add(MKCircle(center: geotification.coordinate, radius: geotification.radius))
  }
  
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
    mapView.zoomToUserLocation()
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
    add(geotification: geotification)
    addRadiusOverlay(forGeotification: geotification)
    saveAllGeotifications()
  }
  
}

extension MarkerViewController: EditMarkerViewControllerDelegate {
  
  func editMarkerViewController(controller: EditMarkerViewController, didAddCoordinate coordinate: CLLocationCoordinate2D, radius: Double, identifier: String, note: String, editing: Geotification, delay: Int, on: Bool) {
    controller.dismiss(animated: true, completion: nil)
    if identifier == "-1" {
      remove(geotification: editingGeo!)
    } else {
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
      print("edits made")
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
        //let removeButton = UIButton(type: .custom)
        //removeButton.frame = CGRect(x: 0, y: 0, width: 23, height: 23)
        //removeButton.setImage(UIImage(named: "DeleteGeotification")!, for: .normal)
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
      circleRenderer.strokeColor = .purple
      circleRenderer.fillColor = UIColor.purple.withAlphaComponent(0.4)
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
  
  func mapView(_: MKMapView, regionDidChangeAnimated: Bool) {
    hideTable()
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

extension CLLocation {
  
  /// Get distance between two points
  ///
  /// - Parameters:
  ///   - from: first point
  ///   - to: second point
  /// - Returns: the distance in meters
  class func distance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> CLLocationDistance {
    let from = CLLocation(latitude: from.latitude, longitude: from.longitude)
    let to = CLLocation(latitude: to.latitude, longitude: to.longitude)
    return from.distance(from: to)
  }
}


