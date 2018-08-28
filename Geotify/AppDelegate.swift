
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
  var timerLong: Timer? = nil
  var selectedTime: Int = 0
  var curRegion: CLRegion = CLRegion()
  var left = false
  var center = UNUserNotificationCenter.current()
  var count = 0
  
  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey : Any]? = nil) -> Bool {
    locationManager.delegate = self as CLLocationManagerDelegate
    locationManager.requestAlwaysAuthorization()
    center = UNUserNotificationCenter.current()
    center.requestAuthorization(options: [.alert, .sound]) { (granted, error) in
    }
    print("testing")
    locationManager.allowsBackgroundLocationUpdates = true //allows the app to be continuously updating through continuous location tracking
    locationManager.startUpdatingLocation() //begins updating the user location
    let notificationCenter = NotificationCenter.default //sets up/instantiate the notification center
    notificationCenter.addObserver(self, selector: #selector(appMovedToBackground), name: Notification.Name.UIApplicationWillResignActive, object: nil)
    return true
  }
  
  @objc func appMovedToBackground() {
    //locationManager.stopUpdatingLocation()
    //self.timer?.invalidate()
    print("App moved to background!")
  }
  
  func setTime(selectedTime: Int)
  {
    print("recieved")
    self.selectedTime = selectedTime
    print("AppDel: " + String(self.selectedTime))
  }
  
  //if the user enters the location
  func handleEventEnter(forRegion region: CLRegion!) {
    print("marker location entered")
    if !isInternetAvailable() { //if internet is not avalable at the time
      print("the internet is not connected")
      let geotification = geo(fromRegion: region) //geotification is the geotification that was notified
      if geotification != nil { //if the geotification just found is not null
        //Timer.scheduledTimer(timeInterval: 9.0, target: self, selector: #selector(AppDelegate.updateNotification), userInfo: nil, repeats: false)
        let identif = geotification?.name             ///////
        print("name: " + identif!)                    //
        let time = geotification?.delay               //this portion extracts the data from the found geotification
        print("delay: " + String(describing: time))   //
        let on = geotification?.on                    //
        print("on: " + String(describing: on))        ///////
        if on! { //if the geotificaion is set to on
          //count = time!*6
          //locationManager.startUpdatingLocation()
          DispatchQueue.main.async {
            self.timer = Timer.scheduledTimer(timeInterval: TimeInterval(time!*60-5), target: self, selector: #selector(AppDelegate.updateNotification), userInfo: nil, repeats: false) //sets a timer to update the state of the notification 5 seconds before sending
            //self.timerLong = Timer.scheduledTimer(timeInterval: TimeInterval(self.count*10), target: self, selector: #selector(AppDelegate.updateNotificationLong), userInfo: nil, repeats: false)
          }
          //locationManager.startUpdatingLocation()
          let content = UNMutableNotificationContent()
          content.title = NSString.localizedUserNotificationString(forKey: "Check your wifi", arguments: nil) //body content of the notifcation
          content.body = NSString.localizedUserNotificationString(forKey: identif!, arguments: nil)
          let trigger = UNTimeIntervalNotificationTrigger(timeInterval: (TimeInterval(time!*60+1)), repeats: false) //creates the notification and sets when it will be sent

          let request = UNNotificationRequest(identifier: identif!, content: content, trigger: trigger) //creates the request
          center.add(request) { (error : Error?) in //adds the request for the notification to be sent
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
  func handleEventExit(forRegion region: CLRegion!) { //removes the pending notification if you leave the area
    //locationManager.stopUpdatingLocation()
    print("marker location left")
    guard let identif = note(fromRegionIdentifier: region.identifier) else { return } //gets the name of the marker
    let identifArray = [identif]
    center.removePendingNotificationRequests(withIdentifiers: identifArray)
    count = 0
    print("removed pending notification")
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
      timer?.invalidate()
    }
    /*print("arrived")
    if count > 0 {
      
      printThis(message: "wifi status updating over 2")
      count = count - 1
      print(String(count))
      locationManager.requestLocation()
      DispatchQueue.main.async {
        self.locationManager.startUpdatingLocation()
        //self.timer = Timer.scheduledTimer(timeInterval: 10.0, target: self, selector: #selector(AppDelegate.updateNotification), userInfo: nil, repeats: false)
      }
      if count == 1 {
        print("wifi status updating...1")
        self.timer?.invalidate()
      }
      if count < 2 {
        print("wifi status updating...")
        if isInternetAvailable()
        {
          print("notification removed: wifi connected")
          center.removeAllPendingNotificationRequests()
          //timer?.invalidate()
        }
      }
    } else {
      
      //locationManager.stopUpdatingLocation()
      print("timer hit 0")
    }*/
  }
  
  
  func underOne() {
    print("wifi status updating...1")
    self.timer?.invalidate()
    //locationManager.stopUpdatingLocation()
  }
  
  @objc func updateNotificationLong()
  {
    print("notification time: stoped updating location")
    //locationManager.stopUpdatingLocation()
    self.timerLong?.invalidate() //
  }
  func printThis(message: String)
  {
    print(message)
  }
  
  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard let locValue: CLLocationCoordinate2D = manager.location?.coordinate else { return }
    print("locations = \(locValue.latitude) \(locValue.longitude)")
  }

  
  func geo(fromRegion: CLRegion) -> Geotification? {
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
    
     return isReachable && !needsConnection
  }
}
  


extension AppDelegate: CLLocationManagerDelegate {
  
  //did they enter a region?
  func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
    if region is CLCircularRegion {
      handleEventEnter(forRegion: region)
    }
  }
  
  //did they exit a region?
  func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
    if region is CLCircularRegion {
      handleEventExit(forRegion: region)
    }
  }
  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    print(error)
  }
}
