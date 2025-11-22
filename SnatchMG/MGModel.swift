//
//  MGModel.swift
//  SnatchMG
//
//  Created by Tim on 20.11.25.
//

import Foundation

struct MGModel: Codable {
    init(from manager: MobileGestaltManager) throws {
        let decoder = PropertyListDecoder()
        self = try decoder.decode(MGModel.self, from: manager.plistContent?.content.data(using: .utf8) ?? Data())
    }
    let cacheData: Data
    let cacheExtra: CacheExtra
    let cacheUUID: String
    let cacheVersion: String
    enum CodingKeys: String, CodingKey {
        case cacheData = "CacheData"
        case cacheExtra = "CacheExtra"
        case cacheUUID = "CacheUUID"
        case cacheVersion = "CacheVersion"
    }
}

struct CacheExtra: Codable {
    let artworkTraits: ArtworkTraits?
    let buildVersion: String?
    let productType: String?
    
    let additionalFields: [String: CodableValue]
    
    enum CodingKeys: String, CodingKey {
        case artworkTraits = "oPeik/9e8lQWMszEjbPzng"
        case buildVersion  = "mZfUC7qo4pURNhyMHZ62RQ"
        case productType   = "h9jDsbgj7xIVeIQ8S3/X3Q"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        artworkTraits = try? container.decode(ArtworkTraits.self, forKey: .artworkTraits)
        buildVersion  = try? container.decode(String.self, forKey: .buildVersion)
        productType   = try? container.decode(String.self, forKey: .productType)
        
        // DECODE UNKNOWN KEYS
        let raw = try decoder.container(keyedBy: DynamicCodingKeys.self)
        
        var extras: [String: CodableValue] = [:]
        
        for key in raw.allKeys {
            if CodingKeys(stringValue: key.stringValue) != nil {
                continue
            }
            
            let value = try raw.decode(CodableValue.self, forKey: key)
            extras[key.stringValue] = value
        }
        
        self.additionalFields = extras
    }
    
    struct DynamicCodingKeys: CodingKey {
        var stringValue: String
        init?(stringValue: String) { self.stringValue = stringValue }
        
        var intValue: Int? { nil }
        init?(intValue: Int) { return nil }
    }
}


struct ArtworkTraits: Codable {
    let artworkDeviceIdiom: String
    let artworkDeviceProductDescription: String
    let artworkDeviceScaleFactor: Int
    let artworkDeviceSubType: Int
    let artworkDisplayGamut: String
    let artworkDynamicDisplayMode: String
    let compatibleDeviceFallback: String
    let devicePerformanceMemoryClass: Int
    let graphicsFeatureSetClass: String
    let graphicsFeatureSetFallbacks: String
    
    enum CodingKeys: String, CodingKey {
        case artworkDeviceIdiom = "ArtworkDeviceIdiom"
        case artworkDeviceProductDescription = "ArtworkDeviceProductDescription"
        case artworkDeviceScaleFactor = "ArtworkDeviceScaleFactor"
        case artworkDeviceSubType = "ArtworkDeviceSubType"
        case artworkDisplayGamut = "ArtworkDisplayGamut"
        case artworkDynamicDisplayMode = "ArtworkDynamicDisplayMode"
        case compatibleDeviceFallback = "CompatibleDeviceFallback"
        case devicePerformanceMemoryClass = "DevicePerformanceMemoryClass"
        case graphicsFeatureSetClass = "GraphicsFeatureSetClass"
        case graphicsFeatureSetFallbacks = "GraphicsFeatureSetFallbacks"
    }
}
