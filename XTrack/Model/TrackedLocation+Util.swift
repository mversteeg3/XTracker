//
//  TrackedLocation+Util.swift
//  XTrack
//
//  Created by Matt Versteeg on 8/7/18.
//  Copyright © 2018 Matt Versteeg. All rights reserved.
//

import Foundation
import CoreLocation

extension TrackedLocation{
    var coordinate: CLLocationCoordinate2D{
        get{
            return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
        set{
            latitude = newValue.latitude
            longitude = newValue.longitude
        }
    }
}
