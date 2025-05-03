//
//  AppDelegate.swift
//  VoiceRecorder
//
//  Created by  William on 2/6/19.
//  Copyright © 2019 Vasiliy Lada. All rights reserved.
//

import UIKit
import CoreData
import SwiftUI // Import SwiftUI

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?


    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.

        // Create the SwiftUI view that you want to be the root view
        let contentView = MainPage() // Replace ContentView() with the actual name of your SwiftUI view

        // Create a new UIWindow
        window = UIWindow(frame: UIScreen.main.bounds)

        // Create a UIHostingController to embed the SwiftUI view
        window?.rootViewController = UIHostingController(rootView: contentView)

        // Make the window visible
        window?.makeKeyAndVisible()

        return true
    }

}
