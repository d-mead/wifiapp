
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

struct GeoKey {
  static let latitude = "latitude"
  static let longitude = "longitude"
  static let radius = "radius"
  static let identifier = "identifier"
  static let name = "Name"
  static let loc = "loc"
  static let delay = "delay"
  static let on = "on"
  
}

class Geotification: NSObject, NSCoding, MKAnnotation {
  
  var coordinate: CLLocationCoordinate2D
  var radius: CLLocationDistance
  var identifier: String
  var name: String
  let geocoder = CLGeocoder()
  var placemark: CLPlacemark?
  var city: String?
  var state: String?
  var loc: String?
  var delay: Int?
  var on: Bool?
  
  
  var title: String? {
    if name.isEmpty {
      return "No Name"
    }
    return name
  }
  
  var subtitle: String? {
    return "Radius: \(Int(radius)) m"
  }
  
  
  init(coordinate: CLLocationCoordinate2D, radius: CLLocationDistance, identifier: String, name: String, delay: Int, on: Bool) {
    //super.init()
    self.coordinate = coordinate
    self.radius = radius
    self.identifier = identifier
    self.name = name
    self.loc = "loc"
    self.delay = 0
    self.on = true
    self.city = ""
    self.state = ""
    //self.makeLoc()
  }
  
  func makeLoc(){
    print("making the location")
    self.loc = ""
    self.city = ""
    self.state = ""
    self.reverseGeo(cord: coordinate)
    //print("makingLoc")
  }
  
  func clearLoc(){
    self.loc = ""
    self.city = ""
    self.state = ""
  }
  
  func reverseGeo(cord: CLLocationCoordinate2D){
    geocoder.reverseGeocodeLocation(CLLocation(latitude: cord.latitude, longitude: cord.longitude), completionHandler: { (placemarks, error) in
      if error == nil, let placemark = placemarks, !placemark.isEmpty {
        self.placemark = placemark.last
      }
      self.parsePlacemarks(cord: cord)
      
    })
  }
  
  func updateCity() {
    //print("update sent from geotification class")
    //MarkerViewController().newLocationAvalable()
  }
  
  func parsePlacemarks(cord: CLLocationCoordinate2D) {
    if let placemark = placemark {
      if let city = placemark.locality, !city.isEmpty {
        self.city = city
        print("city: " + city)
      }
      if let state = placemark.administrativeArea, !state.isEmpty {
        self.state = state
        print("state: " + state)
      }
      /*if !(city?.isEmpty)! {
        if !(state?.isEmpty)! {
          self.loc = city! + ", " + state!
        }
      } else {*/
      if self.city != "" && self.state != "" {
        self.loc = self.city! + ", " + self.state!
      } else if self.city == "" && self.state == "" {
        self.loc = ""
      } else if self.city == "" {
        self.loc = self.state
      } else {
        self.loc = self.city
      }
      
      //}
        print("location added: " + self.loc!)
      //print("celladdress")
    } else {
    }
    
  }
  
  func getLoc() -> String? {
    return loc
  }
  
  func getName() -> String? {
    return name
  }
  func getCoord() -> String? {
    return String(coordinate.latitude)+", "+String(coordinate.longitude)
  }
  // MARK: NSCoding
  required init?(coder decoder: NSCoder) {
    let latitude = decoder.decodeDouble(forKey: GeoKey.latitude)
    let longitude = decoder.decodeDouble(forKey: GeoKey.longitude)
    coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    radius = decoder.decodeDouble(forKey: GeoKey.radius)
    identifier = decoder.decodeObject(forKey: GeoKey.identifier) as! String
    name = decoder.decodeObject(forKey: GeoKey.name) as! String
    loc = decoder.decodeObject(forKey: GeoKey.loc) as? String
    delay = decoder.decodeObject(forKey: GeoKey.delay) as? Int
    on = decoder.decodeObject(forKey: GeoKey.on) as? Bool
  }
  
  func encode(with coder: NSCoder) {
    coder.encode(coordinate.latitude, forKey: GeoKey.latitude)
    coder.encode(coordinate.longitude, forKey: GeoKey.longitude)
    coder.encode(radius, forKey: GeoKey.radius)
    coder.encode(identifier, forKey: GeoKey.identifier)
    coder.encode(name, forKey: GeoKey.name)
    coder.encode(loc, forKey: GeoKey.loc)
    coder.encode(delay, forKey: GeoKey.delay)
    coder.encode(on, forKey: GeoKey.on)
  }
  
}
