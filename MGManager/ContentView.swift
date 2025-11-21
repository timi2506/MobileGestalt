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
    @State var selectedSave: MGSave?
    var body: some View {
        NavigationStack {
            List(selection: $selectedSave) {
                if mgSavesManager.saves.isEmpty {
                    HStack {
                        Spacer()
                        ContentUnavailableViewBackport("No Saves", systemImage: "xmark")
                        Spacer()
                    }
                }
                ForEach($mgSavesManager.saves.sorted(by: { $0.wrappedValue.date > $1.wrappedValue.date })) { save in
                    HStack {
                        Image(nsImage: deviceImage(for: save.wrappedValue.deviceInformation?.deviceIdentifier) ?? NSWorkspace.shared.icon(for: .propertyList))
                            .resizable()
                            .scaledToFit()
                            .frame(height: 35)
                        VStack(alignment: .leading) {
                            Text(save.wrappedValue.deviceName)
                                .bold()
                            Text(save.wrappedValue.date, format: .dateTime)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .tag(save.wrappedValue)
                }
                .onDelete { offsets in
                    mgSavesManager.saves.remove(atOffsets: offsets)
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
            .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.propertyList]) { result in
                if let url = try? result.get(), let content = try? String(contentsOf: url, encoding: .utf8) {
                    _ = url.startAccessingSecurityScopedResource()
                    let mgModel: MGModel? = {
                        if let contentData = content.data(using: .utf8), let m = try? PropertyListDecoder().decode(MGModel.self, from: contentData) {
                            return m
                        }
                        return nil
                    }()
                    importItem = ItemToImport(content: content, mgModel: mgModel)
                    url.stopAccessingSecurityScopedResource()
                }
            }
            .sheet(isPresented: $showImporter) {
                NavigationStack {
                    VStack {
                        Text("Available Devices")
                            .bold()
                            .padding()
                        List(selection: $selectedBonjourItems) {
                            if scanner.items.isEmpty {
                                HStack {
                                    Spacer()
                                    ContentUnavailableViewBackport("No Devices found", systemImage: "xmark", description: Text("Please make sure you have enabled the Server in SnatchMG and your Devices are connected to the same WiFi Network. Alternatively you can Select an Existing File using the Select File Button."))
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
                                .tag(item)
                            }
                        }
                        .scrollIndicators(.never)
                        .animation(.default, value: scanner.items)
                        .frame(minHeight: 225)
                    }
                    .listStyle(.inset(alternatesRowBackgrounds: true))
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                showImporter = false
                            }
                            .buttonStyle(.bordered)
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Import") {
                                Task {
                                    let items = selectedBonjourItemsFilter
                                    for item in items {
                                        let mgSave = try await MGSave(from: item)
                                        mgSavesManager.saves.append(mgSave)
                                    }
                                    showImporter = false
                                }
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
                    .onChange(of: scanner.items) { _ in
                        selectedBonjourItems = selectedBonjourItemsFilter
                    }
                }
            }
            .sheet(item: $importItem) { item in
                NavigationStack {
                    VStack {
                        Text("Import File")
                            .bold()
                            .padding()
                        Form {
                            Section("Validation") {
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
                            Section("Details") {
                                TextField("Device Name", text: $importDeviceName)
                                DatePicker("Date", selection: $importDate, displayedComponents: [.date, .hourAndMinute])
                            }
                        }
                        .formStyle(.grouped)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cancel") {
                                    importItem = nil
                                }
                                .buttonStyle(.bordered)
                            }
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Import") {
                                    let save = MGSave(deviceName: importDeviceName, content: item.content, date: importDate)
                                    mgSavesManager.saves.append(save)
                                    importItem = nil
                                    Task {
                                        if let index = mgSavesManager.saves.firstIndex(of: save), let mgModel = item.mgModel, let deviceInfo = await DeviceInformation(from: mgModel) {
                                            mgSavesManager.saves[index].deviceInformation = deviceInfo
                                        }
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(importDeviceName.isEmpty)
                            }
                        }
                        .onAppear {
                            if let name = item.mgModel?.cacheExtra.artworkTraits?.artworkDeviceProductDescription {
                                importDeviceName = name
                            }
                        }
                    }
                }
            }
            .toolbar {
                if let selectedSave {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            mgSavesManager.saves.removeAll(where: {
                                $0.id == selectedSave.id
                            })
                        }
                        .keyboardShortcut(.delete, modifiers: .command)
                    }
                }
                if #available(macOS 26, *) {
                    ToolbarSpacer(placement: .primaryAction)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Add", systemImage: "plus") {
                        showImporter.toggle()
                    }
                }
            }
            .onChange(of: showImporter) { _ in
                if showImporter {
                    scanner.start()
                } else {
                    scanner.stop()
                }
            }
        }
    }
    @State var importDeviceName = ""
    @State var importDate = Date()
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
    var isMobileGestaltForSure: Bool {
        mgModel != nil
    }
    var mgModel: MGModel?
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
            save()
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
    init(deviceName: String, content: String, date: Date) {
        self.deviceName = deviceName
        self.content = content
        self.date = date
    }
    var id = UUID()
    var deviceName: String
    var content: String
    var date: Date
    var deviceInformation: DeviceInformation?
}

#Preview {
    ContentView()
}
