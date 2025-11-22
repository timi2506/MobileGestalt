//
//  MGCopy.swift
//  SnatchMG
//
//  CREDITS GO TO https://github.com/p-x9/swift-mobile-gestalt
//

import Foundation

public func ValueForMGKeyAsString(_ key: String) -> String? {
    if let answer: CFTypeRef = ValueForMGKey(key) {
        switch CFGetTypeID(answer) {
            case CFBooleanGetTypeID():
                if let v = answer as? Bool {
                    return "\(v)"
                }
            case CFNumberGetTypeID():
                if let v = answer as? NSNumber {
                    return "\(v)"
                }
            case CFStringGetTypeID():
                if let v = answer as? String {
                    return v
                }
            default:
                break
        }
        return answer.description
    }
    return nil
}

public func ValueForMGKey(_ key: String) -> CFTypeRef? {
    let gestalt = dlopen("/usr/lib/libMobileGestalt.dylib", RTLD_GLOBAL | RTLD_LAZY)
    typealias MGCopyAnswerFunc = @convention(c) (CFString) -> Optional<Unmanaged<CFTypeRef>>
    let MGCopyAnswer = unsafeBitCast(dlsym(gestalt, "MGCopyAnswer"), to: MGCopyAnswerFunc.self)
    
    return MGCopyAnswer(key as CFString)?.takeRetainedValue()
}
