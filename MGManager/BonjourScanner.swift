//
//  BonjourScanner.swift
//  MGManager
//
//  Created by Tim on 21.11.25.
//

import SwiftUI
import Combine
import Network

final class BonjourScanner: NSObject, ObservableObject {
    @Published var items: [BonjourItem] = []
    
    private let browser = NetServiceBrowser()
    private var activeServices: [NetService] = []

    override init() {
        super.init()
        browser.delegate = self
        browser.includesPeerToPeer = true
    }
    
    func start() {
        items.removeAll()
        browser.searchForServices(ofType: "_MobileGestaltServer._tcp", inDomain: "local.")
    }
    
    func stop() {
        browser.stop()
        activeServices.removeAll()
    }
}

extension BonjourScanner: NetServiceBrowserDelegate {
    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        service.delegate = self
        activeServices.append(service)
        service.resolve(withTimeout: 3.0)
    }
    
    func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        items.removeAll { $0.name == service.name }
    }
}
extension BonjourScanner: NetServiceDelegate {
    func netServiceDidResolveAddress(_ sender: NetService) {
        guard let host = sender.hostName else { return }
        let port = sender.port
        print(sender)
        var components = URLComponents()
        components.scheme = "http"
        components.host = host
        components.port = port
        
        guard let url = components.url else { return }
        
        let item = BonjourItem(
            name: sender.name,
            serverURL: url
        )
        
        DispatchQueue.main.async {
            self.items.removeAll { $0.name == sender.name }
            self.items.append(item)
            Task {
                if let (deviceInfoData, _) = try? await URLSession.shared.data(from: item.serverURL.appending(path: "deviceInfo")), let decoded = try? JSONDecoder().decode(DeviceInformation.self, from: deviceInfoData) {
                    if let index = self.items.firstIndex(of: item) {
                        self.items[index].deviceInformation = decoded
                        print("Updated Icon")
                    }
                }
            }
        }
    }
}


struct BonjourItem: Identifiable, Hashable {
    var id: String {
        serverURL.absoluteString + name + deviceInformation.debugDescription
    }
    let name: String
    let serverURL: URL
    var deviceInformation: DeviceInformation?
}
