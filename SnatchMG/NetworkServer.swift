import Vapor
import Network
import Foundation
import Combine
import DeviceKit
import UIKit

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
    @Published var additionalInformation: String?
    
    private init(port: Int) {
        self.port = port
        self.displayName = UserDefaults.standard.string(forKey: "savedDisplayName") ?? Device.current.localizedModel ?? Device.current.name ?? Device.current.systemName ?? "Device"
    }
    
    func start() async throws {
        if app != nil { return }
        
        let app = try await Application.make(.development)
        self.app = app
        
        app.get("status") { req in
            return DeviceInformation(name: self.displayName, description: self.additionalInformation)
        }
        
        app.get("getMobileGestalt") { req -> String in
            try? MobileGestaltManager.shared.fetchMobilegestalt()
            guard let gestalt = MobileGestaltManager.shared.plistContent?.content else {
                throw URLError(.fileDoesNotExist)
            }
            return gestalt
        }
        
        app.get("deviceInfo") { req -> DeviceInformation in
            return DeviceInformation(name: self.displayName, description: self.additionalInformation)
        }
        
        app.http.server.configuration.port = Int(port)
        app.http.server.configuration.hostname = "0.0.0.0"

        // Why 7771? MG (standing for MobileGestalt) is 7771 in ASCII
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

struct DeviceInformation: Content {
    var name: String
    var description: String?
    
    var osVersion: String
    var buildNumber: String
    var kernelVersion: String
    var deviceIdentifier: String
    
    init(name: String, description: String? = nil) {
        self.name = name
        self.description = description
        self.osVersion = DeviceInformation.getOSVersion()
        self.buildNumber = DeviceInformation.getBuildNumber()
        self.kernelVersion = DeviceInformation.getKernelVersion()
        self.deviceIdentifier = DeviceInformation.getDeviceIdentifier()
    }
}

extension DeviceInformation {
    static func getOSVersion() -> String {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
    }
    
    static func getBuildNumber() -> String {
        let path = "/System/Library/CoreServices/SystemVersion.plist"
        guard let dict = NSDictionary(contentsOfFile: path),
              let build = dict["BuildVersion"] as? String else {
            return "unknown"
        }
        return build
    }
    
    static func getKernelVersion() -> String {
        var size = 0
        sysctlbyname("kern.osrelease", nil, &size, nil, 0)
        var str = [CChar](repeating: 0, count: size)
        sysctlbyname("kern.osrelease", &str, &size, nil, 0)
        return String(cString: str)
    }
    
    static func getDeviceIdentifier() -> String {
        var size = 0
        sysctlbyname("hw.machine", nil, &size, nil, 0)
        var str = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.machine", &str, &size, nil, 0)
        return String(cString: str)
    }
}
