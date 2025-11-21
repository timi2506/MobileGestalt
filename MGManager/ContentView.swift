//
//  ContentView.swift
//  MGManager
//
//  Created by Tim on 21.11.25.
//

import SwiftUI
import Combine
import UniformTypeIdentifiers
import Network

struct ContentView: View {
    @StateObject var mgSavesManager = MGSavesManager.shared
    @State var showImporter = false
    @State var showFileImporter = false
    @State var importItem: ItemToImport?
    @StateObject var scanner = BonjourScanner()
    @State var selectedBonjourItems: Set<BonjourItem> = []
    var selectedBonjourItemsFilter: Set<BonjourItem> {
        selectedBonjourItems.filter { item in
            scanner.items.contains(item)
        }
    }
    var body: some View {
        NavigationStack {
            Form {
                HStack {
                    Spacer()
                    if mgSavesManager.saves.isEmpty {
                        ContentUnavailableView("No Saves", systemImage: "xmark")
                    }
                    Spacer()
                }
                ForEach(mgSavesManager.saves) { save in
                    HStack {
                        Image(nsImage: NSWorkspace.shared.icon(for: .propertyList))
                        VStack(alignment: .leading) {
                            Text(save.deviceName)
                                .bold()
                            Text(save.date, format: .dateTime)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
            }
            .formStyle(.grouped)
            .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.propertyList]) { result in
                if let url = try? result.get(), let content = try? String(contentsOf: url, encoding: .utf8) {
                    _ = url.startAccessingSecurityScopedResource()
                    let isMobileGestalt: Bool = {
                        if let contentData = content.data(using: .utf8), let _ = try? PropertyListDecoder().decode(MGModel.self, from: contentData) {
                            return true
                        }
                        return false
                    }()
                    importItem = ItemToImport(content: content, isMobileGestaltForSure: isMobileGestalt)
                    url.stopAccessingSecurityScopedResource()
                }
            }
            .sheet(isPresented: $showImporter) {
                NavigationStack {
                    VStack {
                        HStack {
                            Spacer()
                            Text("Available Devices")
                                .bold()
                            Spacer()
                        }
                        .padding()
                        List(selection: $selectedBonjourItems) {
                            if scanner.items.isEmpty {
                                HStack {
                                    Spacer()
                                    ContentUnavailableView("No Devices found", systemImage: "xmark", description: Text("Please make sure you have enabled the Server in SnatchMG and your Devices are connected to the same WiFi Network"))
                                    Spacer()
                                }
                            }
                            ForEach(scanner.items) { item in
                                HStack {
                                    Image(nsImage: deviceImage(for: item.deviceInformation?.deviceIdentifier) ?? NSImage(named: NSImage.networkName) ?? NSImage())
                                        .resizable()
                                        .scaledToFit()
                                        .frame(height: 35)
                                    VStack(alignment: .leading) {
                                        Text(item.name)
                                            .bold()
                                        Text(item.serverURL.absoluteString)
                                        if let deviceInfo = item.deviceInformation {
                                            Text(deviceInfo.description ?? "iOS \(deviceInfo.osVersion)")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                }
                                .contentShape(.rect)
                                .onKeyPress(.return, action: {
                                    Task {
                                        let save = try await MGSave(from: item)
                                        mgSavesManager.saves.append(save)
                                    }
                                    return .handled
                                })
                                .tag(item)
                            }
                        }
                        .alternatingRowBackgrounds()
                        .scrollIndicators(.never)
                        .animation(.default, value: scanner.items)
                        .frame(minHeight: 225)
                    }
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                showImporter = false
                            }
                            .buttonStyle(.bordered)
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Import") {
                                let items = selectedBonjourItemsFilter
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(selectedBonjourItemsFilter.isEmpty)
                        }
                        ToolbarItem(placement: .automatic) {
                            Button("Select File") {
                                showImporter = false
                                showFileImporter = true
                            }
                        }
                    }
                    .onChange(of: scanner.items) {
                        selectedBonjourItems = selectedBonjourItemsFilter
                    }
                }
            }
            .sheet(item: $importItem) { item in
                NavigationStack {
                    Form {
                        if !item.isMobileGestaltForSure {
                            Text("It's unsure if this File is a valid MobileGestalt File.\nYou might want to check it before adding it, Proceed with caution")
                                .font(.caption)
                                .foregroundStyle(.red)
                        } else {
                            Text("This File looks like a valid MobileGestalt File.")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                    }
                    .formStyle(.grouped)
                    .navigationTitle("Import File")
                }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add", systemImage: "plus") {
                        showImporter.toggle()
                    }
                }
            }
            .onChange(of: showImporter) {
                if showImporter {
                    scanner.start()
                } else {
                    scanner.stop()
                }
            }
        }
    }
}

func deviceImage(for identifier: String?) -> NSImage? {
    guard let identifier else { return nil }
    if identifier.lowercased().starts(with: "iphone") {
        return NSImage(contentsOf: URL(fileURLWithPath: "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/com.apple.iphone-x-1.icns"))
    } else if identifier.lowercased().starts(with: "ipad") {
        return NSImage(contentsOf: URL(fileURLWithPath: "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/com.apple.ipad.icns"))
    } else {
        return nil
    }
}

struct ItemToImport: Identifiable {
    var id = UUID()
    var content: String
    var isMobileGestaltForSure: Bool
}

class MGSavesManager: ObservableObject {
    private init() {
        let savingDirectory = URL.applicationSupportDirectory.appendingPathComponent("snatchMG_saves", conformingTo: .json)
        let decoder = JSONDecoder()
        if let data = try? Data(contentsOf: savingDirectory), let decoded = try? decoder.decode([MGSave].self, from: data) {
            self.saves = decoded
        } else {
            self.saves = []
        }
    }
    static let shared = MGSavesManager()
    @Published var saves: [MGSave] {
        didSet {
            
        }
    }
    func save() {
        let savingDirectory = URL.applicationSupportDirectory.appendingPathComponent("snatchMG_saves", conformingTo: .json)
        if FileManager.default.fileExists(atPath: savingDirectory.path()) {
            try? FileManager.default.removeItem(at: savingDirectory)
        }
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(saves) {
            try? encoded.write(to: savingDirectory, options: .atomic)
        }
    }
}

struct MGSave: Codable, Identifiable, Hashable {
    init(from bonjourItem: BonjourItem) async throws {
        let decoder = JSONDecoder()
        let (mobileGestaltData, mobileGestaltRequestStatus) = try await URLSession.shared.data(for: URLRequest(url: bonjourItem.serverURL.appending(path: "getMobileGestalt")))
        if let mgString = String(data: mobileGestaltData, encoding: .utf8) {
            if (mobileGestaltRequestStatus as? HTTPURLResponse)?.statusCode == 500 {
                throw URLError(.fileDoesNotExist)
            }
            self.content = mgString
        } else {
            throw URLError(.fileDoesNotExist)
        }
        self.deviceName = bonjourItem.name
        self.date = Date()
        if let (deviceInfoData, _) = try? await URLSession.shared.data(from: bonjourItem.serverURL.appending(path: "deviceInfo")), let deviceInfo = try? decoder.decode(DeviceInformation.self, from: deviceInfoData) {
            self.deviceInformation = deviceInfo
        }
    }
    var id = UUID()
    var deviceName: String
    var content: String
    var date: Date
    var deviceInformation: DeviceInformation?
}

struct DeviceInformation: Codable, Hashable {
    var name: String
    var description: String?
    
    var osVersion: String
    var buildNumber: String
    var kernelVersion: String
    var deviceIdentifier: String
}

#Preview {
    ContentView()
}
