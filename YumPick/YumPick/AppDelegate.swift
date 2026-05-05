//
//  AppDelegate.swift
//  YumPick
//
//  Created by 석민솔 on 4/28/26.
//

import UIKit
import FirebaseCore
import FirebaseMessaging
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    HomeStoreCache.clear()
    FirebaseApp.configure()
      if #available(iOS 10.0, *) {
          UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { granted, error in
              print("UNUserNotificationCenter Permission granted: \(granted)")
          }
          UNUserNotificationCenter.current().delegate = self
          Messaging.messaging().delegate = self
      }
      application.registerForRemoteNotifications()
    return true
  }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let userInfo = notification.request.content.userInfo
        let roomID = userInfo["room_id"] as? String

        if let roomID, roomID == ChatPushHandler.shared.currentOpenRoomID {
            // 현재 보고 있는 채팅방의 푸시 — 배너/소리 suppress
            Task { @MainActor in
                ChatPushHandler.shared.handle(userInfo: userInfo, isUserTap: false)
            }
            completionHandler([])
        } else {
            Task { @MainActor in
                ChatPushHandler.shared.handle(userInfo: userInfo, isUserTap: false)
            }
            completionHandler([.banner, .list, .sound])
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        Task { @MainActor in
            ChatPushHandler.shared.handle(userInfo: userInfo, isUserTap: true)
        }
        completionHandler()
    }
    
    @objc func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken else { return }
        KeychainManager.shared.save(key: .fcmToken, value: fcmToken)
    }
}
