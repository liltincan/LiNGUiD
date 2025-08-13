//
//  LocationVerifier.swift
//  LiNGUiD
//
//  Created by Tahmidul Karim on 8/13/25.
//

import CoreLocation
import FirebaseAuth
import FirebaseFirestore

final class LocationVerifier: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()

    func verifyAndSaveLocation() {
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        } else if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            manager.requestLocation()
        }
    }

    // Called when location is retrieved
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        saveLocationToFirestore(loc)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location verification failed:", error.localizedDescription)
    }

    // Save to Firestore
    private func saveLocationToFirestore(_ loc: CLLocation) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        let geo = GeoPoint(latitude: loc.coordinate.latitude, longitude: loc.coordinate.longitude)
        db.collection("users").document(uid).setData([
            "location": [
                "co-ordinates": geo,
                "verifiedAt": FieldValue.serverTimestamp()
            ]
        ], merge: true)
    }
}
