//
//  GITHERBApp.swift
//  GITHERB
//
//  Created by 밀가루 on 7/22/24.
//

import SwiftUI
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    FirebaseApp.configure()

    return true
  }
}

@main
struct GITHERBApp: App {
    var body: some Scene {
        WindowGroup {
            AuthContentView()
        }
    }
}
