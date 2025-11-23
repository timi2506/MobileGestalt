//
//  FilePickerfix.swift
//  MeloNX
//
//  Created by Stossy11 on 03/08/2025.
//

import UIKit
import UniformTypeIdentifiers
import Foundation
import ObjectiveC.runtime
import Security


var shouldAsCopy = false
var hostIdentifier = Bundle.main.bundleIdentifier ?? ""

extension Bundle {
    @objc dynamic var swizzled_bundleIdentifier: String? {
        if self == Bundle.main {
            return hostIdentifier
        } else {
            return self.swizzled_bundleIdentifier
        }
    }
    
    @discardableResult
    static func swizzleBundleIdentifier() -> Bool {
        guard let originalMethod = class_getInstanceMethod(Bundle.self, #selector(getter: Bundle.bundleIdentifier)),
              let swizzledMethod = class_getInstanceMethod(Bundle.self, #selector(getter: Bundle.swizzled_bundleIdentifier)) else {
            return false
        }
        let bundle = Bundle.main.bundleIdentifier
        
        print("Host Identifier: \(hostIdentifier)")
        
        if hostIdentifier != bundle {
            shouldAsCopy = true
            method_exchangeImplementations(originalMethod, swizzledMethod)
            return true
        }
        
        return false
    }
    
}

func getModifiedHostIdentifier(originalHostIdentifier: String) -> String {
    guard let task = SecTaskCreateFromSelf(nil) else {
        return originalHostIdentifier
    }
    
    var error: NSError?
    let appIdRef = SecTaskCopyValueForEntitlement(task, "application-identifier" as NSString, &error)
    releaseSecTask(task)
    
    guard let appId = appIdRef as? String, CFGetTypeID(appIdRef) == CFStringGetTypeID() else {
        return originalHostIdentifier
    }
    
    if let dotRange = appId.range(of: ".") {
        return String(appId[dotRange.upperBound...])
    }
    
    return appId
}


func swizzleInstanceMethod(for cls: AnyClass, original: Selector, swizzled: Selector) {
    guard
        let originalMethod = class_getInstanceMethod(cls, original),
        let swizzledMethod = class_getInstanceMethod(cls, swizzled)
    else { return }
    
    method_exchangeImplementations(originalMethod, swizzledMethod)
}

func swizzleClassMethod(for cls: AnyClass, original: Selector, swizzled: Selector) {
    guard
        let originalMethod = class_getClassMethod(cls, original),
        let swizzledMethod = class_getClassMethod(cls, swizzled)
    else { return }
    
    method_exchangeImplementations(originalMethod, swizzledMethod)
}


extension UIDocumentPickerViewController {
    @objc func hook_initForOpeningContentTypes(_ contentTypes: [UTType], asCopy: Bool) -> UIDocumentPickerViewController {
        var shouldMultiselect = false
        if SnatchMG.shouldAsCopy, contentTypes.count == 1, contentTypes[0] == .folder {
            shouldMultiselect = true
        }
        
        let contentTypesNew: [UTType] = [.item, .folder]
        
        if SnatchMG.shouldAsCopy {
            let picker = self.hook_initForOpeningContentTypes(contentTypesNew, asCopy: true)
            if shouldMultiselect {
                picker.allowsMultipleSelection = true
            }
            return picker
        } else {
            return self.hook_initForOpeningContentTypes(contentTypes, asCopy: asCopy)
        }
    }
    
    @objc func hook_initWithDocumentTypes(_ contentTypes: [String], inMode mode: UIDocumentPickerMode) -> UIDocumentPickerViewController {
        let asCopy = mode != .import
        return type(of: self).init(forOpeningContentTypes: contentTypes.compactMap { UTType($0) }, asCopy: asCopy)
    }
}


extension UIDocumentBrowserViewController {
    @objc func hook_initForOpeningContentTypes(_ contentTypes: [UTType]) -> UIDocumentBrowserViewController {
        if SnatchMG.shouldAsCopy {
            let newTypes: [UTType] = [.item, .folder]
            return self.hook_initForOpeningContentTypes(newTypes)
        } else {
            return self.hook_initForOpeningContentTypes(contentTypes)
        }
    }
}


extension NSURL {
    @objc func hook_startAccessingSecurityScopedResource() -> Bool {
        _ = self.hook_startAccessingSecurityScopedResource()
        return true
    }
}

@objc class UTTypeHook: NSObject {
    @objc class func hook_typeWithIdentifier(_ identifier: String) -> Any? {
        if let cls = NSClassFromString("UTType") as? NSObject.Type {
            let selector = NSSelectorFromString("typeWithIdentifier:")
            let imp = cls.method(for: selector)
            typealias Func = @convention(c) (AnyObject, Selector, NSString) -> AnyObject?
            let function = unsafeBitCast(imp, to: Func.self)
            if let result = function(cls, selector, identifier as NSString) {
                return result
            }
        }
        return nil
    }
}



@objc class DOCConfiguration2: NSObject {
    @objc func hook_setHostIdentifier(_ ignored: String?) {
        let value = getModifiedHostIdentifier(originalHostIdentifier: "")
        
        if value != "" {
            self.hook_setHostIdentifier(hostIdentifier)
        } else {
            NSLog("Error fetching entitlement:")
            self.hook_setHostIdentifier(ignored)
        }
        
    }
}


@objc public class EarlyInit: NSObject {
    @objc public static func entryPoint() {
        
        if Bundle.swizzleBundleIdentifier() {
            
            
            swizzleInstanceMethod(for: UIDocumentPickerViewController.self,
                                  original: #selector(UIDocumentPickerViewController.init(forOpeningContentTypes:asCopy:)),
                                  swizzled: #selector(UIDocumentPickerViewController.hook_initForOpeningContentTypes(_:asCopy:)))
            
            swizzleInstanceMethod(for: UIDocumentPickerViewController.self,
                                  original: #selector(UIDocumentPickerViewController.init(documentTypes:in:)),
                                  swizzled: #selector(UIDocumentPickerViewController.hook_initWithDocumentTypes(_:inMode:)))
            
            swizzleInstanceMethod(for: NSURL.self,
                                  original: #selector(NSURL.startAccessingSecurityScopedResource),
                                  swizzled: #selector(NSURL.hook_startAccessingSecurityScopedResource))
            
            if let docConfigClass = NSClassFromString("DOCConfiguration") {
                let originalSelector = NSSelectorFromString("setHostIdentifier:")
                let swizzledSelector = #selector(DOCConfiguration2.hook_setHostIdentifier(_:))
                swizzleInstanceMethod(for: docConfigClass,
                                      original: originalSelector,
                                      swizzled: swizzledSelector)
                print("DOCConfiguration.setHostIdentifier: swizzled")
            } else {
                print("DOCConfiguration not found")
            }
            
            
            if let utTypeClass = NSClassFromString("UTType") {
                let originalSelector = NSSelectorFromString("typeWithIdentifier:")
                let swizzledSelector = #selector(UTTypeHook.hook_typeWithIdentifier(_:))
                swizzleClassMethod(for: utTypeClass, original: originalSelector, swizzled: swizzledSelector)
            }
            
            
            swizzleInstanceMethod(for: UIDocumentBrowserViewController.self,
                                  original: #selector(UIDocumentBrowserViewController.init(forOpening:)),
                                  swizzled: #selector(UIDocumentBrowserViewController.hook_initForOpeningContentTypes(_:)))
        }
    }
}

typealias SecTaskRef = OpaquePointer

@_silgen_name("SecTaskCopyValueForEntitlement")
func SecTaskCopyValueForEntitlement(
    _ task: SecTaskRef,
    _ entitlement: NSString,
    _ error: NSErrorPointer
) -> CFTypeRef?

@_silgen_name("SecTaskCopyTeamIdentifier")
func SecTaskCopyTeamIdentifier(
    _ task: SecTaskRef,
    _ error: NSErrorPointer
) -> NSString?

@_silgen_name("SecTaskCreateFromSelf")
func SecTaskCreateFromSelf(
    _ allocator: CFAllocator?
) -> SecTaskRef?

@_silgen_name("CFRelease")
func CFRelease(_ cf: CFTypeRef)

@_silgen_name("SecTaskCopyValuesForEntitlements")
func SecTaskCopyValuesForEntitlements(
    _ task: SecTaskRef,
    _ entitlements: CFArray,
    _ error: UnsafeMutablePointer<Unmanaged<CFError>?>?
) -> CFDictionary?

func releaseSecTask(_ task: SecTaskRef) {
    let cf = unsafeBitCast(task, to: CFTypeRef.self)
    CFRelease(cf)
}
