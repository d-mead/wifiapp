//
//  HomeViewController.swift
//  Geotify
//
//  Created by David Mead on 4/3/18.
//  Copyright © 2018 Ken Toh. All rights reserved.
//

/*import UIKit
import Foundation
import SystemConfiguration

class HomeViewController: UIViewController, UIPickerViewDelegate, UIPickerViewDataSource {
  
  var status: String = "unknown"
  var stat = 0;
  
  @IBOutlet weak var onOffSwitch: UISwitch!
  @IBOutlet weak var statusLabel: UILabel!
  @IBOutlet weak var toMarkersButton: UIButton!
  @IBOutlet var timePicker: UIPickerView!
  var pickerData: [Int] = [Int]()
  var selectedTime: Int = 0
  var appDelegate:AppDelegate?
  
  override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        statusLabel.text = status
        print("print")
    pickerData = [1, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60]
    self.timePicker.delegate = self
    self.timePicker.dataSource = self
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
  func numberOfComponents(in pickerView: UIPickerView) -> Int {
    return 1
  }
  
  // The number of rows of data
  func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
    return pickerData.count
  }
  
  // The data to return for the row and component (column) that's being passed in
  func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
    return String(pickerData[row])
  }
  
  func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
    if(row == 0){
      selectedTime = 1
    } else {
      selectedTime = pickerData[row]
    }
    appDelegate?.setTime(selectedTime: selectedTime)
    print(selectedTime)
  }
  
  func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView {
    var pickerLabel = view as? UILabel;
    if (pickerLabel == nil)
    {
      pickerLabel = UILabel()
      pickerLabel?.font = UIFont(name: "Montserrat", size: 17)
      pickerLabel?.textAlignment = NSTextAlignment.right
    }
    pickerLabel?.text = String(pickerData[row])
    return pickerLabel!;
  }
  /*func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return 0 // your number of cell here
  }*/
  func getSelectedTime() -> Int
  {
    return selectedTime
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
  
  @IBAction func onOff(_ sender: Any) {
    if onOffSwitch.isOn {
      update();
    }
    else {
      status = "unknown"
      stat = 0
      statusLabel.text = status
    }
  }
  
  func update() {
    if isInternetAvailable() {
      status = "connected"
      stat = 1;
    }
    else {
      status = "disconnected"
      stat = -1;
    }
    statusLabel.text = status
  }
  
  
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}*/
