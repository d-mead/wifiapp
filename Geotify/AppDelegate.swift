
import CoreLocation
import UIKit
import SystemConfiguration
import UserNotifications
import Foundation


@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
  
  var window: UIWindow?
  
  let locationManager = CLLocationManager()
  //var counter = 0
  var timer: Timer? = nil
  //var timerL: Timer? = nil
  //var timerLong: Timer? = nil
  //var selectedTime: Int = 0
  var curRegion: CLCircularRegion = CLCircularRegion()
  //var left = false
  var center = UNUserNotificationCenter .current()
  //var count = 0
  
  
  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey : Any]? = nil) -> Bool {
    UIApplication.shared.setMinimumBackgroundFetchInterval(3600)
    locationManager.delegate = self as CLLocationManagerDelegate
    locationManager.requestAlwaysAuthorization()
    center = UNUserNotificationCenter.current()
    center.requestAuthorization(options: [.alert, .sound]) { (granted, error) in
    }
    locationManager.allowsBackgroundLocationUpdates = true        //allows the app to be continuously updating through continuous location tracking
    locationManager.startUpdatingLocation()                       //begins updating the user's location
    let notificationCenter = NotificationCenter.default           //sets up/instantiates the notification center
    notificationCenter.addObserver(self, selector: #selector(appMovedToBackground), name: Notification.Name.UIApplicationWillResignActive, object: nil)
                                                                  //calls the method if app moves to background
    return true
  }
  
  
  @objc func appMovedToBackground() {
    //actions performed if the app is sent to the background
    print("Moved to background")
    locationManager.stopUpdatingLocation()                          //stops updating the user's location
    locationManager.startMonitoringSignificantLocationChanges()     //starts monitoring only signifigant location changes
  }
  
  
  func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler:
      @escaping (UIBackgroundFetchResult) -> Void) {
    //method called if the app woken up/ refreshed in the background
    //checks if the user is in a marked location and is not connected to wifi
    locationManager.requestLocation()
    print("Background refresh")
    for loc in locationManager.monitoredRegions {                                         //loops through the motitored regions
      if((loc as! CLCircularRegion).contains((locationManager.location?.coordinate)!)) {  //if the user is in one of the regions
        print("user was inside marker during background refresh")
        if(!isInternetAvailable()){                                                        //if not connected to wifi
          print("internet not avalable duirng background refresh")
          let content = UNMutableNotificationContent()
          content.title = NSString.localizedUserNotificationString(forKey: "Check your wifi connection", arguments: nil)       //body content of the notifcation
          content.body = NSString.localizedUserNotificationString(forKey: ("It appears you are at " + (geo(fromRegion: loc as! CLCircularRegion)?.name)! + " and are not connected to wifi"), arguments: nil)
          let trigger = UNTimeIntervalNotificationTrigger(timeInterval: (TimeInterval(5)), repeats: false)  //creates the notification and sets when it will be sent
          let request = UNNotificationRequest(identifier: (geo(fromRegion: loc as! CLCircularRegion)?.name)!, content: content, trigger: trigger)              //creates the request
          center.add(request) { (error : Error?) in   //adds the request for the notification to be sent
            if let theError = error {
              print(theError.localizedDescription)
            }
            print("notification scheduled")
          }
        }
      }
    }
  }
  
  //if the user enters the location
  func handleEventEnter(forRegion region: CLCircularRegion!) {
    //if the user entered a monitored region
    print("marker location entered")
    if !isInternetAvailable() {                       //if internet is not avalable at the time
      locationManager.distanceFilter = kCLDistanceFilterNone
      //locationManager.allowsBackgroundLocationUpdates = true
      locationManager.stopMonitoringSignificantLocationChanges()
      locationManager.startUpdatingLocation()
      locationManager.requestLocation()
      print("the internet is not connected")
      let geotification = geo(fromRegion: region)     //geotification is the geotification that was notified
      if geotification != nil {                       //if the geotification just found is not null
        let identif = geotification?.name
        print("name: " + identif!)
        let time = geotification?.delay               //this portion extracts the data from the found geotification
        print("delay: " + String(describing: time!))
        let on = geotification?.on
        print("on: " + String(describing: on))
        if on! {                                      //if the geotificaion is set to on
          DispatchQueue.main.async {
            self.timer = Timer.scheduledTimer(timeInterval: TimeInterval(time!*60-5), target: self, selector: #selector(AppDelegate.updateNotification), userInfo: nil, repeats: false)                  //sets a timer to update the state of the notification 5 seconds before sending
          }
          let content = UNMutableNotificationContent()
          content.title = NSString.localizedUserNotificationString(forKey: "Check your wifi connection", arguments: nil)       //body content of the notifcation
          content.body = NSString.localizedUserNotificationString(forKey: ("It appears you have been at " + identif! + " for " + String(describing: time!) + " minutes and are still not connected to wifi"), arguments: nil)
          let trigger = UNTimeIntervalNotificationTrigger(timeInterval: (TimeInterval(time!*60+1)), repeats: false)  //creates the notification and sets when it will be sent
          let request = UNNotificationRequest(identifier: identif!, content: content, trigger: trigger)              //creates the request
          center.add(request) { (error : Error?) in   //adds the request for the notification to be sent
            if let theError = error {
              print(theError.localizedDescription)
            }
            print("notification scheduled")
          }
        }
        else {                          //if the geotification was not set to on
          print("marker is turned off")
        }
      }
    } else {                            //if internet was avalable
      print("internet was avalable")
    }
  }

  
  
  func handleEventExit(forRegion region: CLCircularRegion!) {
    //if the user exits the location
    //removes the pending notification if you leave the area
    print("marker location left")
    guard let identif = note(fromRegionIdentifier: region.identifier) else { return }   //gets the name of the marker
    let identifArray = [identif]
    center.removePendingNotificationRequests(withIdentifiers: identifArray)             //removes the notification
    //count = 0
    locationManager.stopUpdatingLocation()
    locationManager.startMonitoringSignificantLocationChanges()
    print("removed pending notification")
  }
  
  
  
  @objc func updateNotification() {
    //redirects to update
    update()
  }
  
  func update() {
    //deletes the notification just before being sent if wifi is connected
    print("checking wifi status")
    if isInternetAvailable()      //if the user is now connected to wifi
    {
      print("notification removed: wifi connected")
      center.removeAllPendingNotificationRequests()   //removes all pending notifications
    }
    locationManager.stopUpdatingLocation()
    locationManager.startMonitoringSignificantLocationChanges()
  }
  
  
  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    //called whenever new location is recieved
    //guard let locValue: CLLocationCoordinate2D = manager.location?.coordinate else { return }
    //print("locations = \(locValue.latitude) \(locValue.longitude)")
  }

  
  func geo(fromRegion: CLCircularRegion) -> Geotification? {
    //returns the geotification object corresponding to the region parameter
    let savedItems = UserDefaults.standard.array(forKey: PreferencesKeys.savedItems) as? [NSData]
    let geotifications = savedItems?.map { NSKeyedUnarchiver.unarchiveObject(with: $0 as Data) as? Geotification }
    let index = geotifications?.index { $0?.identifier == fromRegion.identifier }
    return index != nil ? geotifications?[index!] : nil
  }
  
  
  func note(fromRegionIdentifier identifier: String) -> String? {
    //returns the note (name) for the geotification corresponding with the region
    let savedItems = UserDefaults.standard.array(forKey: PreferencesKeys.savedItems) as? [NSData]
    let geotifications = savedItems?.map { NSKeyedUnarchiver.unarchiveObject(with: $0 as Data) as? Geotification }
    let index = geotifications?.index { $0?.identifier == identifier }
    return index != nil ? geotifications?[index!]?.name : nil
  }
  
  func isInternetAvailable() -> Bool {
    //check if the user is connected to the internet
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
  
  private func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLCircularRegion) {
    //entered region
    handleEventEnter(forRegion: region)
  }
  
  private func locationManager(_ manager: CLLocationManager, didExitRegion region: CLCircularRegion) {
    //exited region
    handleEventExit(forRegion: region)
  }
  
  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    print(error)
  }
}

