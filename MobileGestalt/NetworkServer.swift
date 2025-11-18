import Vapor
import Network
import Foundation
import Combine
import DeviceKit

final class MobileGestaltServer: ObservableObject {
    static let shared = MobileGestaltServer(port: 7771)
    
    @Published var port: Int
    private var app: Application?
    @Published var isAdvertising = false
    @Published var displayName: String {
        didSet {
            UserDefaults.standard.set(displayName, forKey: "savedDisplayName")
        }
    }
    
    private init(port: Int) {
        self.port = port
        self.displayName = UserDefaults.standard.string(forKey: "savedDisplayName") ?? Device.current.localizedModel ?? Device.current.name ?? Device.current.systemName ?? "Device"
    }
    
    func start() async throws {
        if app != nil { return }
        
        let app = try await Application.make(.development)
        self.app = app
        
        app.get("status") { req in
            return "OK"
        }
        
        app.get("getMobileGestalt") { req -> String in
            guard let gestalt = MobileGestaltManager.shared.plistContent?.content else {
                throw URLError(.fileDoesNotExist)
            }
            return gestalt
        }
        
        app.http.server.configuration.port = Int(port)
        app.http.server.configuration.hostname = "0.0.0.0"

        // Why 7771? Simple! MG (standing for MobileGestalt) is 7771 in ASCII
        if let port32 = Int32(exactly: port) {
            advertiseBonjour(port: port32)
        } else {
            advertiseBonjour(port: 7771)
        }
        Task.detached {
            try await app.execute()
        }
    }
    
    func stop() async {
        guard let app = app else { return }
        service?.stop()
        service = nil
        isAdvertising = false
        
        try? await app.asyncShutdown()
        
        self.app = nil
    }
    
    private var service: NetService?
    
    private func advertiseBonjour(port: Int32) {
        let realName = displayName.isEmpty ? "Device" : displayName
        service = NetService(domain: "local.", type: "_MobileGestaltServer._tcp.", name: realName, port: port)
        service?.publish()
        isAdvertising = true
    }
    func netService(_ sender: NetService, didNotPublish errorDict: [String : NSNumber]) {
        print("Bonjour failed:", errorDict)
    }

}
