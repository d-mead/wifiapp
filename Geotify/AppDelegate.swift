
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
  var timer: Timer? = nil
  var timerL: Timer? = nil
  var timerLong: Timer? = nil
  var selectedTime: Int = 0
  var curRegion: CLCircularRegion = CLCircularRegion()
  var left = false
  var center = UNUserNotificationCenter .current()
  var count = 0
  
  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey : Any]? = nil) -> Bool {
    UIApplication.shared.setMinimumBackgroundFetchInterval(3600)
    locationManager.delegate = self as CLLocationManagerDelegate
    locationManager.requestAlwaysAuthorization()
    center = UNUserNotificationCenter.current()
    center.requestAuthorization(options: [.alert, .sound]) { (granted, error) in
    }
    locationManager.allowsBackgroundLocationUpdates = true //allows the app to be continuously updating through continuous location tracking
    locationManager.startUpdatingLocation() //begins updating the user's location
    let notificationCenter = NotificationCenter.default //sets up/instantiates the notification center
    notificationCenter.addObserver(self, selector: #selector(appMovedToBackground), name: Notification.Name.UIApplicationWillResignActive, object: nil)
    return true
  }
  
  @objc func appMovedToBackground() {
    //locationManager.distanceFilter = 200000
    locationManager.stopUpdatingLocation() //begins updating the user's location
    locationManager.startMonitoringSignificantLocationChanges()
    //locationManager.allowsBackgroundLocationUpdates = true
    //locationManager.pausesLocationUpdatesAutomatically = true//****//
    //locationManager.stopUpdatingLocation()          //****//
    // print(isVPNConnected())
    print(isInternetAvailable())
    print("App moved to background!")
  } //CLCircularRegion(center: loc.center, radius: loc.radius, identifier: loc.identifier).contains((locationManager.location?.coordinate)!)
  //Background
  
  
  func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler:
    @escaping (UIBackgroundFetchResult) -> Void) { //checks if the user is in a marked location and is not connected to wifi
    locationManager.requestLocation()
    print("background refresh")
    for loc in locationManager.monitoredRegions {
      if((loc as! CLCircularRegion).contains((locationManager.location?.coordinate)!)) {
        print("user was inside marker during background refresh")
        if(!isInternetAvailable()){
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
  
  //  if moved into background:
  //    stop updating location
  //  if entered the location:
  //    start updating the location
  //  if:
  //    reached the wifi checkpoint:
  //      stop updating location
  //    left the location:
  //      stop updating location
  
  //if the user enters the location
  func handleEventEnter(forRegion region: CLCircularRegion!) {
    
    print("marker location entered")
    if !isInternetAvailable() {                       //if internet is not avalable at the time
      locationManager.distanceFilter = kCLDistanceFilterNone
      //locationManager.allowsBackgroundLocationUpdates = true
      //locationManager.stopMonitoringSignificantLocationChanges()
      locationManager.startUpdatingLocation()
      locationManager.requestLocation()
      print("the internet is not connected")
      let geotification = geo(fromRegion: region)     //geotification is the geotification that was notified
      if geotification != nil {                       //if the geotification just found is not null
        let identif = geotification?.name             ///////
        print("name: " + identif!)                    //
        let time = geotification?.delay               //this portion extracts the data from the found geotification
        print("delay: " + String(describing: time!))   //
        let on = geotification?.on                    //
        print("on: " + String(describing: on))        ///////
        print()
        if on! {                                      //if the geotificaion is set to on
          DispatchQueue.main.async {
            self.timer = Timer.scheduledTimer(timeInterval: TimeInterval(time!*60-5), target: self, selector: #selector(AppDelegate.updateNotification), userInfo: nil, repeats: false)                  //sets a timer to update the state of the notification 5 seconds before sending
            //self.timerL = Timer.scheduledTimer(timeInterval: TimeInterval(time!*60+10), target: self, selector: #selector(AppDelegate.endLocationUpdates), userInfo: nil, repeats: false) //sets timer for the function that will stop the location updates
          }
          let content = UNMutableNotificationContent()
          content.title = NSString.localizedUserNotificationString(forKey: "Check your wifi connection", arguments: nil)       //body content of the notifcation
          if(String(describing: time!) == "1") {
            content.body = NSString.localizedUserNotificationString(forKey: ("It appears you have been at " + identif! + " for " + String(describing: time!) + " minute and are still not connected to wifi"), arguments: nil)
          } else {
            content.body = NSString.localizedUserNotificationString(forKey: ("It appears you have been at " + identif! + " for " + String(describing: time!) + " minutes and are still not connected to wifi"), arguments: nil)
          }
          let trigger = UNTimeIntervalNotificationTrigger(timeInterval: (TimeInterval(time!*60+1)), repeats: false)  //creates the notification and sets when it will be sent
          let request = UNNotificationRequest(identifier: identif!, content: content, trigger: trigger)              //creates the request
          center.add(request) { (error : Error?) in   //adds the request for the notification to be sent
            if let theError = error {
              print(theError.localizedDescription)
            }
            print("notification scheduled")
          }
        }
        else { //if the geotification was not set to on
          print("marker is turned off")
        }
      }
    } else { //if internet was avalable
      print("internet was avalable")
    }
  }
  
  //if the user exits the location
  func handleEventExit(forRegion region: CLCircularRegion!) { //removes the pending notification if you leave the area
    print("marker location left")
    guard let identif = note(fromRegionIdentifier: region.identifier) else { return } //gets the name of the marker
    let identifArray = [identif]
    center.removePendingNotificationRequests(withIdentifiers: identifArray)
    count = 0
    locationManager.stopUpdatingLocation()          //****//
    //locationManager.distanceFilter = 200000
    locationManager.startMonitoringSignificantLocationChanges()
    //locationManager.allowsBackgroundLocationUpdates = false
    print("removed pending notification")
  }
  
  @objc func endLocationUpdates()
  {
    //locationManager.stopUpdatingLocation()
  }
  
  //deletes the notification just before being sent if wifi is connected
  @objc func updateNotification()
  {
    update()
  }
  
  func update()
  {
    print("checking wifi status")
    if isInternetAvailable()
    {
      print("notification removed: wifi connected")
      center.removeAllPendingNotificationRequests()
    }
    //locationManager.allowsBackgroundLocationUpdates = false
    locationManager.stopUpdatingLocation()          //****//
    //locationManager.distanceFilter = 200000
    locationManager.startMonitoringSignificantLocationChanges()
    
  }
  
  
  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard let locValue: CLLocationCoordinate2D = manager.location?.coordinate else { return }
    print("locations = \(locValue.latitude) \(locValue.longitude)")
  }
  
  
  func geo(fromRegion: CLCircularRegion) -> Geotification? {
    let savedItems = UserDefaults.standard.array(forKey: PreferencesKeys.savedItems) as? [NSData]
    let geotifications = savedItems?.map { NSKeyedUnarchiver.unarchiveObject(with: $0 as Data) as? Geotification }
    let index = geotifications?.index { $0?.identifier == fromRegion.identifier }
    return index != nil ? geotifications?[index!] : nil
    
  }
  
  func note(fromRegionIdentifier identifier: String) -> String? {
    let savedItems = UserDefaults.standard.array(forKey: PreferencesKeys.savedItems) as? [NSData]
    let geotifications = savedItems?.map { NSKeyedUnarchiver.unarchiveObject(with: $0 as Data) as? Geotification }
    let index = geotifications?.index { $0?.identifier == identifier }
    return index != nil ? geotifications?[index!]?.name : nil
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

    if isVPNConnected() {
      return true
    }
    return isReachable && !needsConnection
  }
  
  
  func isVPNConnected() -> Bool {
    print("is connected to VPN?")
    let host = "www.example.com"
    guard let reachability = SCNetworkReachabilityCreateWithName(nil, host) else {
      return false
    }
    var flags = SCNetworkReachabilityFlags()
    if SCNetworkReachabilityGetFlags(reachability, &flags) == false {
      return false
    }
    let isOnline = flags.contains(.reachable) && !flags.contains(.connectionRequired)
    if !isOnline {
      return false
    }
    let isMobileNetwork = flags.contains(.isWWAN)
    let isTransientConnection = flags.contains(.transientConnection)
    if isMobileNetwork {
      if let settings = CFNetworkCopySystemProxySettings()?.takeRetainedValue() as? Dictionary<String, Any>,
        let scopes = settings["__SCOPED__"] as? [String:Any] {
        for (key, _) in scopes {
          if key.contains("tap") || key.contains("tun") || key.contains("ppp") {
            print("connected to VPN")
            return true
          }
        }
      }
      print("not connected to VPN")
      return false
    } else {
      return isTransientConnection
    }
  }
  
}



extension AppDelegate: CLLocationManagerDelegate {
  
  //did they enter a region?
  func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLCircularRegion) {
    handleEventEnter(forRegion: region)
  }
  
  //did they exit a region?
  func locationManager(_ manager: CLLocationManager, didExitRegion region: CLCircularRegion) {
    handleEventExit(forRegion: region)
  }
  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    print(error)
  }
}
