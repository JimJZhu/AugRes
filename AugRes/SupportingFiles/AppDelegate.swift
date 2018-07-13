//
//  AppDelegate.swift
//  AugRes
//
//  Created by Jim on 2018-07-12.
//  Copyright © 2018 Jim. All rights reserved.
//

import UIKit
import BMSCore
import BluemixAppID
import PlacenoteSDK
import GoogleMaps

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?


    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        LibPlacenote.instance.initialize(apiKey: placenoteAPIKey)

        // Initialize the AppID instance with your tenant ID and region
        // App Id initialization
        // NOTE: Enable Keychain Sharing capability in Xcode
        if let contents = Bundle.main.path(forResource:"BMSCredentials", ofType: "plist"), let dictionary = NSDictionary(contentsOfFile: contents) {
            let region = AppID.REGION_US_SOUTH
            let bmsclient = BMSClient.sharedInstance
            let backendGUID = "fe21ca30-eb39-4d74-856b-151efb35058f"
            bmsclient.initialize(bluemixRegion: region)
            let appid = AppID.sharedInstance
            appid.initialize(tenantId: backendGUID, bluemixRegion: region)
            let appIdAuthorizationManager = AppIDAuthorizationManager(appid:appid)
            bmsclient.authorizationManager = appIdAuthorizationManager
            TokenStorageManager.sharedInstance.initialize(tenantId: backendGUID)
        }
        GMSServices.provideAPIKey("AIzaSyCAnm-_9Xvrn4Lpotk0q1edTJYKihMJu9c")
        return true
    }
    
    func application(_ application: UIApplication, open url: URL, options :[UIApplicationOpenURLOptionsKey : Any]) -> Bool {
        return AppID.sharedInstance.application(application, open: url, options: options)
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }


}

