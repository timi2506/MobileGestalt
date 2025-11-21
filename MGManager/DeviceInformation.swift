//
//  DeviceInformation.swift
//  MGManager
//
//  Created by Tim on 21.11.25.
//

import Foundation

struct DeviceInformation: Codable, Hashable {
    init?(from model: MGModel) async {
        guard let productType = model.cacheExtra.productType, let buildVersion = model.cacheExtra.buildVersion else { return nil }
        do {
            let response = try await IpswDotMeResponse(productType: productType, buildVersion: buildVersion)
            self.name = model.cacheExtra.artworkTraits?.artworkDeviceProductDescription ?? "Unknown Name"
            self.osVersion = response.version
            self.buildNumber = response.buildid
            self.deviceIdentifier = response.identifier
        } catch {
            print(error.localizedDescription)
            return nil
        }
    }
    var name: String
    var description: String?
    
    var osVersion: String
    var buildNumber: String
    var kernelVersion: String?
    var deviceIdentifier: String
}

fileprivate struct IpswDotMeResponse: Decodable {
    init(productType: String, buildVersion: String) async throws {
        let url = URL(string: "https://api.ipsw.me/v4/ipsw/\(productType)/\(buildVersion)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        self = try JSONDecoder().decode(Self.self, from: data)
    }
    let identifier: String
    let version: String
    let buildid: String
}
