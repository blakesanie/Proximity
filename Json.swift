import UIKit

class Json {
    
    static func getJson() {
        // key is AIzaSyDT0v_iz2k5BdH5BTz9KrNaOyuKr36_Ya4
        
        let url = URL(string: "https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=\(lat),\(long)&radius=\(radius)&key=AIzaSyDT0v_iz2k5BdH5BTz9KrNaOyuKr36_Ya4")
        
        let task = URLSession.shared.dataTask(with: url!) { (data, response, error) in
            if error != nil {
                print (error!)
            }
            else {
                do {
                    if let data = data {
                        knownLocations = [place]()
                        namesInView = [String]()
                        if selectedPlace.name != nil {
                            knownLocations.append(selectedPlace)
                            namesInView.append(selectedPlace.name!)
                        }
                        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
                        let results = json["results"] as! [AnyObject]
                        for result in results {
                            let name = result["name"]! as! String
                            let location = result["geometry"]! as AnyObject
                            let coords = location["location"]! as AnyObject
                            let placeLong = coords["lng"]! as! Double
                            let placeLat = coords["lat"]! as! Double
                            let placeId = result["place_id"]! as! String
                            
                            hasConnection = true
                            
                            knownLocations.append(place(name: name, id: placeId, lat: placeLat, long: placeLong))
                            print(knownLocations)
                        }
                    }
                } catch {
                    print("Error deserializing JSON: \(error)")
                    hasConnection = false
                }
            }
        }
        task.resume()
    }
}
