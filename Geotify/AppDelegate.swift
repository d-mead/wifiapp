
import CoreLocation
import UIKit
import SystemConfiguration
import UserNotifications
import Foundation

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
  
  var window: UIWindow?
  
  let locationManager = CLLocationManager()
  var counter = 0
  var timer = Timer()
  var selectedTime: Int = 0
  var curRegion: CLRegion = CLRegion()
  var left = false
  var center = UNUserNotificationCenter.current()
  
  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey : Any]? = nil) -> Bool {
    locationManager.delegate = self as CLLocationManagerDelegate
    locationManager.requestAlwaysAuthorization()
    center = UNUserNotificationCenter.current()
    center.requestAuthorization(options: [.alert, .sound]) { (granted, error) in
      // Enable or disable features based on authorization
    }
    //application.registerUserNotificationSettings(UIUserNotificationSettings(types: [.sound, .alert, .badge], categories: nil))
    //UIApplication.shared.cancelAllLocalNotifications()
    print("testing")
    return true
  }
  
  func setTime(selectedTime: Int)
  {
    print("recieved")
    self.selectedTime = selectedTime
    print("AppDel: " + String(self.selectedTime))
  }
  
  //if the user enters the location
  func handleEventEnter(forRegion region: CLRegion!) {
    print("Geofence Entered")
    print(String(isInternetAvailable()))
    if !isInternetAvailable() {
    print("this far")
      let geotification = geo(fromRegion: region)
      let identif = geotification?.name
      print("name: " + identif!)
      let time = geotification?.delay
      print("delay: " + String(describing: time))
      let on = geotification?.on
      print("on: " + String(describing: on))
      if on! {
        let content = UNMutableNotificationContent()
        content.title = NSString.localizedUserNotificationString(forKey: "Check your wifi", arguments: nil)
        content.body = NSString.localizedUserNotificationString(forKey: identif!, arguments: nil)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: (TimeInterval(time!*60+5)), repeats: false)
        Timer.scheduledTimer(timeInterval: (TimeInterval(time!*60)), target: self, selector: #selector(AppDelegate.updateNotification), userInfo: nil, repeats: false)
        let request = UNNotificationRequest(identifier: identif!, content: content, trigger: trigger)
        
        print("added")
        center.add(request) { (error : Error?) in
          if let theError = error {
            print(theError.localizedDescription)
          }
          print("scheduled")
        }
      }
      else {
        print("marker is off")
      }
      }
  }
  
  //if the user exits the location
  func handleEventExit(forRegion region: CLRegion!) { //removes the pending notification if you leave the area
    print("Geofence Left")
    guard let identif = note(fromRegionIdentifier: region.identifier) else { return } //gets the name of the marker
    let identifArray = [identif]
    
    print("deleted")
    
    center.removePendingNotificationRequests(withIdentifiers: identifArray)
  }
  
  //deletes the notification just before being sent if wifi is connected
  @objc func updateNotification()
  {
    print("wifi rechecked")
    if isInternetAvailable()
    {
      print("notification removed")
      center.removeAllPendingNotificationRequests()
    }
  }
  
  
  //makes a location manager?
  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard let locValue: CLLocationCoordinate2D = manager.location?.coordinate else { return }
    print("locations = \(locValue.latitude) \(locValue.longitude)")
  }
  
  //gets the name of the geotification
  
  func geo(fromRegion: CLRegion) -> Geotification? {
    let savedItems = UserDefaults.standard.array(forKey: PreferencesKeys.savedItems) as? [NSData]
    let geotifications = savedItems?.map { NSKeyedUnarchiver.unarchiveObject(with: $0 as Data) as? Geotification }
    for geo in geotifications! {
      if CLCircularRegion(center: (geo?.coordinate)!, radius: (geo?.radius)!, identifier: (geo?.identifier)!).contains((locationManager.location?.coordinate)!) {
        return geo
      }
    }
    return geotifications?[0]
  }
  
  func note(fromRegionIdentifier identifier: String) -> String? {
    let savedItems = UserDefaults.standard.array(forKey: PreferencesKeys.savedItems) as? [NSData]
    let geotifications = savedItems?.map { NSKeyedUnarchiver.unarchiveObject(with: $0 as Data) as? Geotification }
    let index = geotifications?.index { $0?.identifier == identifier }
    return index != nil ? geotifications?[index!]?.name : nil
  }
  
  func delay(fromRegionIdentifier identifier: String) -> Int? {
    let savedItems = UserDefaults.standard.array(forKey: PreferencesKeys.savedItems) as? [NSData]
    let geotifications = savedItems?.map { NSKeyedUnarchiver.unarchiveObject(with: $0 as Data) as? Geotification }
    let index = geotifications?.index { $0?.identifier == identifier }
    return index != nil ? geotifications?[index!]?.delay : nil
  }
  
  func on(fromRegionIdentifier identifier: String) -> Bool? {
    let savedItems = UserDefaults.standard.array(forKey: PreferencesKeys.savedItems) as? [NSData]
    let geotifications = savedItems?.map { NSKeyedUnarchiver.unarchiveObject(with: $0 as Data) as? Geotification }
    let index = geotifications?.index { $0?.identifier == identifier }
    return index != nil ? geotifications?[index!]?.on : nil
  }
  
  //to check if internet is connected
  func isInternetAvailable() -> Bool
  {
    var zeroAddress = sockaddr_in(sin_len: 0, sin_family: 0, sin_port: 0, sin_addr: in_addr(s_addr: 0), sin_zero: (0, 0, 0, 0, 0, 0, 0, 0))
    zeroAddress.sin_len = UInt8(MemoryLayout.size(ofValue: zeroAddress))
    zeroAddress.sin_family = sa_family_t(AF_INET)
    
    let defaultRouteReachability = withUnsafePointer(to: &zeroAddress) {
      $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {zeroSockAddress in
        SCNetworkReachabilityCreateWithAddress(nil, zeroSockAddress)
      }
    }
    
    var flags: SCNetworkReachabilityFlags = SCNetworkReachabilityFlags(rawValue: 0)
    if SCNetworkReachabilityGetFlags(defaultRouteReachability!, &flags) == false {
      return false
    }
    
     //Only Working for WIFI
     let isReachable = flags == .reachable
     let needsConnection = flags == .connectionRequired
     
     return isReachable && !needsConnection
 
  }
}
  


extension AppDelegate: CLLocationManagerDelegate {
  
  //did they enter a region?
  func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
    if region is CLCircularRegion {
      handleEventEnter(forRegion: region)
      print("yep")
    }
  }
  
  //did they exit a region?
  func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
    if region is CLCircularRegion {
      handleEventExit(forRegion: region)
    }
  }
  /// TODO: Add somthing so that every few mins maybe it will check if you are in the location using the method requestStateForRegion(_:)
}



//MARK: Old Code
  //was under handleEvent if !internetIsAvalableMethod
// Show an alert if application is active
/*if UIApplication.shared.applicationState == .active {
 guard let message = note(fromRegionIdentifier: region.identifier) else { return }
 window?.rootViewController?.showAlert(withTitle: nil, message: message)
 } else {*/
// Otherwise present a local notification
/*let content = UNMutableNotificationContent()
 content.title = NSString.localizedUserNotificationString(forKey: "Left Area", arguments: nil)
 content.body = NSString.localizedUserNotificationString(forKey: "Wifi",
 arguments: nil)
 let trigger = UNTimeIntervalNotificationTrigger(timeInterval: (10), repeats: false)
 let notification = UNNotificationRequest(identifier: "identif", content: content, trigger: trigger)
 //notification.alertBody = note(fromRegionIdentifier: region.identifier)
 //notification.soundName = "Default"
 //notification.trigger = UNTimeIntervalNotificationTrigger(timeInterval: (10), repeats: false)
 //UIApplication.shared.presentLocalNotificationNow(notification)
 
 let center = UNUserNotificationCenter.current()
 center.add(notification) { (error : Error?) in
 if let theError = error {
 print(theError.localizedDescription)
 
 /*func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
 guard let _: CLLocationCoordinate2D = manager.location?.coordinate else { return }
 }*/
 
 }
 }*/
