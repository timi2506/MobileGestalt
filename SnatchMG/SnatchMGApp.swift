//
//  MobileGestaltApp.swift
//  MobileGestalt
//
//  Created by Tim on 16.11.25.
//

import SwiftUI

@main
struct SnatchMGApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    NotificationCenter.default.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: .main) { _ in
                        Task {
                            await MobileGestaltServer.shared.stop()
                        }
                    }
                }
        }
    }
}
