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
  //let homeViewController = HomeViewController.self()
  
  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey : Any]? = nil) -> Bool {
    locationManager.delegate = self as CLLocationManagerDelegate
    locationManager.requestAlwaysAuthorization()
    center = UNUserNotificationCenter.current()
    center.requestAuthorization(options: [.alert, .sound]) { (granted, error) in
      // Enable or disable features based on authorization
    }
    //application.registerUserNotificationSettings(UIUserNotificationSettings(types: [.sound, .alert, .badge], categories: nil))
    //UIApplication.shared.cancelAllLocalNotifications()
    
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
    if !isInternetAvailable() {
      Timer.scheduledTimer(timeInterval: 9.0, target: self, selector: #selector(AppDelegate.updateNotification), userInfo: nil, repeats: false)
    
      guard let identif = note(fromRegionIdentifier: region.identifier) else { return } //gets the name of the marker
      print("name: " + identif)
      guard let time = delay(fromRegionIdentifier: region.identifier) else { return } //gets the delay time of the marker
      print("delay: " + String(time))
      guard let on = on(fromRegionIdentifier: region.identifier) else { return } //gets the on/off boolean of the marker
      print("on: " + String(on))
      if on {
        let content = UNMutableNotificationContent()
        content.title = NSString.localizedUserNotificationString(forKey: "Check your wifi", arguments: nil)
        content.body = NSString.localizedUserNotificationString(forKey: identif, arguments: nil)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: (TimeInterval(time*60)), repeats: false)
        let request = UNNotificationRequest(identifier: identif, content: content, trigger: trigger)
    
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
