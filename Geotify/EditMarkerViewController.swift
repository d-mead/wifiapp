

import UIKit
import MapKit


protocol EditMarkerViewControllerDelegate {
  func editMarkerViewController(controller: EditMarkerViewController, didAddCoordinate coordinate: CLLocationCoordinate2D, radius: Double, identifier: String, note: String, editing: Geotification, delay: Int, on: Bool)
}


class EditMarkerViewController: UITableViewController, UIPickerViewDelegate, UIPickerViewDataSource, MKMapViewDelegate  {
  
  
  var geotifications: [Geotification] = []
  @IBOutlet var addButton: UIBarButtonItem!
  @IBOutlet var zoomButton: UIBarButtonItem!
  @IBOutlet weak var radiusTextField: UITextField!
  @IBOutlet weak var noteTextField: UITextField!
  @IBOutlet weak var nameTextField: UITextField!
  @IBOutlet weak var mapView: MKMapView!
  let locationManager = CLLocationManager()
  var selectedPin:MKPlacemark? = nil
  var resultSearchController:UISearchController? = nil
  var selectedTime: Int = 0
  var geo: Geotification? = nil
  var reg:MKCoordinateRegion? = nil
  var geoNames: [String] = []
  @IBOutlet var delayPicker: UIPickerView!
  var pickerData: [Int] = [Int]()
  @IBOutlet var onOffSwitch: UISwitch!
  @IBOutlet var deleteButton: UIBarButtonItem!
  @IBOutlet var mapSwitch: UISegmentedControl!
  var type:MKMapType = .standard
  
    
  var delegate: EditMarkerViewControllerDelegate?
  
  override func viewDidLoad() {
    super.viewDidLoad()
    locationManager.delegate = self
    mapView.mapType = type
    if(type == .standard) {
      mapSwitch.selectedSegmentIndex = 0
    } else if(type == .hybrid) {
      mapSwitch.selectedSegmentIndex = 1
    } else {
      mapSwitch.selectedSegmentIndex = 2
    }
    mapView.delegate = self
    mapView.setRegion(reg!, animated: false)
    navigationItem.rightBarButtonItems = [addButton, deleteButton]
    let locationSearchTable = storyboard!.instantiateViewController(withIdentifier: "LocationSearchTable") as! LocationSearchTable
    resultSearchController = UISearchController(searchResultsController: locationSearchTable)
    resultSearchController?.searchResultsUpdater = locationSearchTable
    navigationItem.searchController = resultSearchController
    navigationItem.hidesSearchBarWhenScrolling = false
    let searchBar = resultSearchController!.searchBar
    searchBar.sizeToFit()
    searchBar.placeholder = "Search for places"
    resultSearchController?.hidesNavigationBarDuringPresentation = false
    resultSearchController?.dimsBackgroundDuringPresentation = true
    definesPresentationContext = true
    locationSearchTable.mapView = mapView
    locationSearchTable.handleMapSearchDelegate = self as HandleMapSearch
    noteTextField.text = geo?.name
    radiusTextField.text = String(format:"%.0f", (geo?.radius)!)
    mapView.setRegion(MKCoordinateRegion(center: (geo?.coordinate)!, span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)), animated: true)
    pickerData = [0, 1, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60]
    self.delayPicker.delegate = self
    self.delayPicker.dataSource = self
    searchBar.tintColor = UIColor.white
    searchBar.isTranslucent = false
    searchBar.barStyle = .default
    searchBar.barTintColor = UIColor.white
    delayPicker.selectRow(pickerData.index(of: (geo?.delay)!)!, inComponent: 0, animated: true)
    onOffSwitch.isOn = (geo?.on)!
    selectedTime = (geo?.delay)!
    loadAllGeotifications()
    addRadiusOverlay()
    let viewRegion = MKCoordinateRegionMakeWithDistance(mapView.centerCoordinate, Double(radiusTextField.text!)!*3, Double(radiusTextField.text!)!*3)
    mapView.setRegion(viewRegion, animated: true)
    let tap = UITapGestureRecognizer(target: self.view, action: #selector(nameTextField.endEditing(_:)))
    tap.cancelsTouchesInView = false
    self.view.addGestureRecognizer(tap)
    removeRadiusOverlay(forGeotification: geo!)
  }
  
  func numberOfComponents(in pickerView: UIPickerView) -> Int {
    return 1
  }
  
  func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
    return pickerData.count
  }
  
  // The data to return for the row and component (column) that's being passed in
  func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
    return String(pickerData[row])
  }
  
  func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
    if(row == 0){
      selectedTime = 0
    } else {
      selectedTime = pickerData[row]
    }
    //appDelegate?.setTime(selectedTime: selectedTime)
    print(selectedTime)
  }
  
  func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView {
    var pickerLabel = view as? UILabel;
    if (pickerLabel == nil)
    {
      pickerLabel = UILabel()
      pickerLabel?.font = UIFont(name: "System", size: 17)
      pickerLabel?.textAlignment = NSTextAlignment.left
    }
    pickerLabel?.font = UIFont(name: "System", size: 17)
    pickerLabel?.text = String(pickerData[row]) + " minutes"
    return pickerLabel!;
  }
  
  
  //
  @IBAction func textFieldEditingChanged(sender: UITextField) {
    addButton.isEnabled = !radiusTextField.text!.isEmpty && !noteTextField.text!.isEmpty
    removeRadiusOverlay()
    addRadiusOverlay()
  }
  //
  @IBAction func onCancel(sender: AnyObject) {
    dismiss(animated: true, completion: nil)
  }
  @IBAction func switchChanged(_ sender: Any) {
    switch mapSwitch.selectedSegmentIndex
    {
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
  
  func removeRadiusOverlay(forGeotification geotification: Geotification) {
    // Find exactly one overlay which has the same coordinates & radius to remove
    guard let overlays = mapView?.overlays else { return }
    for overlay in overlays {
      guard let circleOverlay = overlay as? MKCircle else { continue }
      let coord = circleOverlay.coordinate
      if coord.latitude == geotification.coordinate.latitude && coord.longitude == geotification.coordinate.longitude && circleOverlay.radius == geotification.radius {
        mapView?.remove(circleOverlay)
        print("found")
        break
      }
    }
  }
  
    @IBAction func onDelete(_ sender: Any) {
      let coordinate = mapView.centerCoordinate
      let radius = Double(radiusTextField.text!) ?? 0
      let identifier = "-1"
      let note = noteTextField.text
      let delay = selectedTime
      let on = onOffSwitch.isOn
      if geoNames.contains(note!) {
        let alert = UIAlertController(title: "Name Already in Use", message: "Choose another name", preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: "Okay", style: UIAlertActionStyle.default, handler: nil))
        self.present(alert, animated: true, completion: nil)
      }
      else{
        delegate?.editMarkerViewController(controller: self, didAddCoordinate: coordinate, radius: radius, identifier: identifier, note: note!, editing: Geotification(coordinate: coordinate, radius: radius, identifier: identifier, name: note!, delay: delay, on: on), delay: delay, on: on)
      }
    }
  
  func loadAllGeotifications() {
    for geotification in geotifications {
      print("iterating")
      addRadiusOverlay(forGeotification: geotification)
      mapView.addAnnotation(geotification)
    }
  }
  
  func addRadiusOverlay(forGeotification geotification: Geotification) {
    mapView?.add(MKCircle(center: geotification.coordinate, radius: geotification.radius))
  }
  
  func addRadiusOverlay() {
    if(radiusTextField.text != "") {
      mapView?.add(MKCircle(center: mapView.centerCoordinate, radius: Double(radiusTextField.text!)!))
    }
  }
  
  func removeRadiusOverlay() {
    // Find exactly one overlay which has the same coordinates & radius to remove
    guard let overlays = mapView?.overlays else { return }
    if(overlays.count != 0) {
      mapView.remove(overlays.last!)
    }
  }
  
  func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
    print("tapped")
    let identifier = "myGeotification"
    if annotation is Geotification {
      var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKPinAnnotationView
      if annotationView == nil {
        annotationView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: identifier)
        annotationView?.canShowCallout = true
      }
      return annotationView
    }
    return nil
  }
  
    @IBAction private func onAdd(sender: AnyObject) {
    let coordinate = mapView.centerCoordinate
    let radius = Double(radiusTextField.text!) ?? 0
    let identifier = NSUUID().uuidString
    let note = noteTextField.text
    let delay = selectedTime
    let on = onOffSwitch.isOn
    if geoNames.contains(note!) {
      let alert = UIAlertController(title: "Name Already in Use", message: "Choose another name", preferredStyle: UIAlertControllerStyle.alert)
      alert.addAction(UIAlertAction(title: "Okay", style: UIAlertActionStyle.default, handler: nil))
      self.present(alert, animated: true, completion: nil)
    }
    else{
      delegate?.editMarkerViewController(controller: self, didAddCoordinate: coordinate, radius: radius, identifier: identifier, note: note!, editing: Geotification(coordinate: coordinate, radius: radius, identifier: identifier, name: note!, delay: delay, on: on), delay: delay, on: on)
    }
  }
  
  @IBAction private func onZoomToCurrentLocation(sender: AnyObject) {
    if let userLocation = locationManager.location?.coordinate {
      let viewRegion = MKCoordinateRegionMakeWithDistance(userLocation, Double(radiusTextField.text!)!*3, Double(radiusTextField.text!)!*3)
      mapView.setRegion(viewRegion, animated: true)
    }
  }
  
  func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
    if let overlay = overlay as? MKCircle {
      let circleRenderer = MKCircleRenderer(circle: overlay)
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
    else {
      return MKOverlayRenderer(overlay: overlay)
    }
  }
  
  func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
    removeRadiusOverlay()
    addRadiusOverlay()
  }
  
}



extension EditMarkerViewController: HandleMapSearch {
  func dropPinZoomIn(placemark:MKPlacemark){
    let span = MKCoordinateSpanMake(0.01, 0.01)
    let region = MKCoordinateRegionMake(placemark.coordinate, span)
    mapView.setRegion(region, animated: true)
  }
}

extension EditMarkerViewController: CLLocationManagerDelegate {
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


