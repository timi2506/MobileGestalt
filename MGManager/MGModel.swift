//
//  MGModel.swift
//  SnatchMG
//
//  Created by Tim on 20.11.25.
//

import Foundation

struct MGModel: Codable {
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
    // TODO: ADD MORE
    enum CodingKeys: String, CodingKey {
        case artworkTraits = "oPeik/9e8lQWMszEjbPzng"
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
