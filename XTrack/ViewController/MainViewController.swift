//
//  MainViewController.swift
//  XTrack
//
//  Created by Matt Versteeg on 8/7/18.
//  Copyright © 2018 Matt Versteeg. All rights reserved.
//

import UIKit
import CoreLocation
import GooglePlaces
import MapKit
import CoreData
import FontAwesome_swift

class MainViewController: UIViewController{
    @IBOutlet weak var map: MKMapView!
    @IBOutlet weak var clearButton: UIButton!
    @IBOutlet weak var centerButton: UIButton!
    
    var points: [TrackedLocation] = []
    private let locationManager = CLLocationManager()
    private var managedContext: NSManagedObjectContext!
    private var locationEntity: NSEntityDescription!
    var geoCoding = false
    
    let LOCATION_OBJECT_NAME = "TrackedLocation"
    let PIN_REUSE = "trackedLocation"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupMap()
        setupLocationServices()
        setupPersistence()
        
        load()
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(appMovedToBackground), name: Notification.Name.UIApplicationWillResignActive, object: nil)
        notificationCenter.addObserver(self, selector: #selector(appMovedToForeground), name: Notification.Name.UIApplicationWillEnterForeground, object: nil)
        
    }
    
    @objc func appMovedToBackground() {
        // TODO Determine if we want updates in this fashion or the more power intensive method always using "UpdatingLocation"
        print("Periodic updates")
        locationManager.stopUpdatingLocation()
        locationManager.startMonitoringSignificantLocationChanges()
    }
    
    @objc func appMovedToForeground(){
        print("High resolution")
        locationManager.stopMonitoringSignificantLocationChanges()
        locationManager.startUpdatingLocation()
    }
    
//    override func viewWillAppear(_ animated: Bool) {
//        super.viewWillAppear(animated)
//
//
//        reloadPins()
//        centerMap(animated: false)
//    }
    
    
    @IBAction func centerPressed(_ sender: Any) {
        centerMap()
    }
    
    @IBAction func clearPressed(_ sender: Any) {
        clearSaved()
    }
    
    func centerMap(animated: Bool = true){
        if let current = locationManager.location?.coordinate{
            map.setCamera(MKMapCamera(lookingAtCenter: current, fromDistance: 5000, pitch: map.camera.pitch, heading: map.camera.heading), animated: false)
        } else{
            print("No current location")
        }
    }
    
    func setupUI(){
        clearButton.setTitle(String.fontAwesomeIcon(name: .trash), for: .normal)
        centerButton.setTitle(String.fontAwesomeIcon(name: .crosshairs), for: .normal)
    }
    
    func setupLocationServices(){
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestAlwaysAuthorization()
        locationManager.distanceFilter = 10
        locationManager.startUpdatingLocation()
        
    }
    
    func setupPersistence(){
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        managedContext = appDelegate.persistentContainer.viewContext
        locationEntity = NSEntityDescription.entity(forEntityName: LOCATION_OBJECT_NAME, in: managedContext)
    }
    
    func setupMap(){
        map.delegate = self
        map.showsUserLocation = true
        map.register(TrackAnnotationView.self, forAnnotationViewWithReuseIdentifier: PIN_REUSE)
    }
    
    func clearSaved(){
        let fetch = NSFetchRequest<NSFetchRequestResult>(entityName: LOCATION_OBJECT_NAME)
        let request = NSBatchDeleteRequest(fetchRequest: fetch)
        if let _ = try? managedContext.execute(request){
            points.removeAll()
            reloadPins()
        } else{
            print("Failed to delete saved locations")
        }
    }
    
    func persistLocation(at latitude: Double, longitude: Double, saveOnComplete: Bool = false){
        let newPoint = TrackedLocation(entity: locationEntity, insertInto: managedContext)
        newPoint.latitude = latitude
        newPoint.longitude = longitude
        points.append(newPoint)
        addPin(for: newPoint)
        if saveOnComplete{
            save()
        }
    }
    
    func save(){
        do {
            try managedContext.save()
        } catch {
            print("Failed saving")
        }
    }
    
    func load(){
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: LOCATION_OBJECT_NAME)
        do {
            let pastLocations = try managedContext.fetch(request)
            for _pl in pastLocations{
                guard let pl = _pl as? TrackedLocation else{
                    print("Failed to load a point from database")
                    continue
                }
                points.append(pl)
            }
            reloadPins()
        } catch {
            print("Failed to fetch past locations")
        }
    }
    
    func reloadPins(){
        map.removeAnnotations(map.annotations)
        print("Have \(points.count) points")
        for point in points{
            addPin(for: point)
        }
    }
    
    func addPin(for point: TrackedLocation){
        let ann = MKPointAnnotation()
        ann.coordinate = point.coordinate
        map.addAnnotation(ann)
    }
}

extension MainViewController: CLLocationManagerDelegate{
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status{
        case .denied:
            print("Denied")
            let controller = UIAlertController(title: "We need to use your location!", message: "Please enable location services and give us permission to use your location in Settings", preferredStyle: .alert)
            controller.addAction(UIAlertAction(title: "Open Settings", style: .default, handler: { (action) in
                guard let settingsUrl = URL(string: UIApplicationOpenSettingsURLString) else {
                    return
                }
                if UIApplication.shared.canOpenURL(settingsUrl) {
                    UIApplication.shared.open(settingsUrl, completionHandler: { (success) in
                        
                    })
                }
            }))
            controller.addAction(UIAlertAction(title: "I don't want the app to work", style: .destructive, handler: nil))
            show(controller, sender: self)
        case .restricted:
            print("Restricted")
        case .notDetermined:
            print("Not determined")
            locationManager.requestAlwaysAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            print("Allowed")
            locationManager.startUpdatingLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        print("Updated location")
        for loc in locations{
            persistLocation(at: loc.coordinate.latitude, longitude: loc.coordinate.longitude)
        }
        save()
        if geoCoding{
            return
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if let error = error as? CLError, error.code == .denied {
            manager.stopMonitoringSignificantLocationChanges()
            return
        }
        // Notify the user of any errors.
    }
    
}

extension MainViewController: MKMapViewDelegate{
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if annotation is MKUserLocation{
            return nil
        }
        let view = mapView.dequeueReusableAnnotationView(withIdentifier: PIN_REUSE, for: annotation)
        view.annotation = annotation
        view.canShowCallout = false
        view.isUserInteractionEnabled = false
        view.image = UIImage(named: "dot")
        return view
    }
    
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        
        if geoCoding{
            return
        }
        guard let ann = view.annotation, ann is MKUserLocation else{
            return
        }
        self.map.userLocation.title = "Loading..."
        self.map.userLocation.subtitle = nil
        print("Geocoding")
        geoCoding = true
        GMSPlacesClient.shared().currentPlace(callback: { (placeLikelihoodList, error) -> Void in
            self.geoCoding = false
            if let error = error {
                self.map.userLocation.title = "Error loading location"
                self.map.userLocation.subtitle = nil
                print("Pick Place error: \(error.localizedDescription)")
                return
            }
            if let place = placeLikelihoodList?.likelihoods.first?.place{
                if place.formattedAddress?.contains(place.name) ?? false{
                    self.map.userLocation.title = place.formattedAddress
                } else{
                    self.map.userLocation.title = place.name
                    self.map.userLocation.subtitle = place.formattedAddress ?? "Unknown Location"
                }
            } else{
                print("No locations found for coordinate")
                self.map.userLocation.title = "Unknown Location"
                self.map.userLocation.subtitle = nil
            }
        })
    }
    
}
