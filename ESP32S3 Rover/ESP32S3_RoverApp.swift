//
//  ESP32S3_RoverApp.swift
//  ESP32S3 Rover
//
//  Created by Arunkumar Mourougappane on 10/9/26.
//

import SwiftUI
import CoreData

@main
struct ESP32S3_RoverApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
