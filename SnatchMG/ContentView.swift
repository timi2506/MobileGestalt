//
//  ContentView.swift
//  SnatchMG
//
//  Created by Tim on 16.11.25.
//

import SwiftUI
import Combine
import CodeEditorView
import LanguageSupport
import DeviceKit

struct ContentView: View {
    @StateObject var mobileGestaltManager = MobileGestaltManager.shared
    @State var position: CodeEditor.Position = CodeEditor.Position()
    @State var messages: Set<TextLocated<Message>> = Set()
    @Environment(\.colorScheme) private var colorScheme: ColorScheme
    @State var errorText: Text?
    @StateObject var server = MobileGestaltServer.shared
    @AppStorage("autoStart") var autoStart = false
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    NavigationLink(destination: {
                        Form {
                            Section {
                                HStack {
                                    TextField("Default", text: $server.displayName)
                                    Spacer()
                                    Button(action: {
                                        server.displayName = Device.current.localizedModel ?? Device.current.name ?? Device.current.systemName ?? "Device"
                                        UserDefaults.standard.removeObject(forKey: "savedDisplayName")
                                        try? MobileGestaltManager.shared.fetchMobilegestalt()
                                    }) {
                                        Image(systemName: "arrow.trianglehead.counterclockwise.rotate.90")
                                    }
                                }
                                .disabled(server.isAdvertising)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                            } header: {
                                Text("Device Name")
                            } footer: {
                                if server.isAdvertising {
                                    Text("This cannot be changed until you stop the Server")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Section {
                                HStack {
                                    TextField("Default: 7771", value: $server.port.portLimit, format: .number)
                                        .keyboardType(.numberPad)
                                    Spacer()
                                    Button(action: {
                                        server.port = 7771
                                    }) {
                                        Image(systemName: "arrow.trianglehead.counterclockwise.rotate.90")
                                    }
                                }
                                .disabled(server.isAdvertising)
                            } header: {
                                Text("Server Port")
                            } footer: {
                                if server.isAdvertising {
                                    Text("This cannot be changed until you stop the Server")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Section {
                                HStack {
                                    TextField("For Example: 64GB, PRODUCT RED", text: $server.additionalInformation.emptyNil)
                                }
                            } header: {
                                Text("Additional Information")
                            }
                            VStack(alignment: .leading) {
                                Toggle("Autostart", isOn: $autoStart)
                                Text("Whether to auto-start the Server on App launch")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .formStyle(.grouped)
                        .navigationTitle("Server Configuration")
                        .toolbarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button(action: {
                                    if server.isAdvertising {
                                        Task {
                                            await server.stop()
                                        }
                                    } else {
                                        Task {
                                            do {
                                                try await server.start()
                                            } catch {
                                                print(error.localizedDescription)
                                            }
                                        }
                                    }
                                }) {
                                    Image(systemName: server.isAdvertising ? "stop.fill" : "play.fill")
                                }
                            }
                        }
                        .safeAreaInset(edge: .bottom) {
                            serverBar(true)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 15)
                                        .foregroundStyle(.ultraThinMaterial)
                                )
                                .padding()
                        }
                    }) {
                        serverBar(false)
                            .navigationLinkIndicatorVisibility(.hidden)
                    }
                    .buttonStyle(.plain)
                    Button(action: {
                        if server.isAdvertising {
                            Task {
                                await server.stop()
                            }
                        } else {
                            Task {
                                do {
                                    try await server.start()
                                } catch {
                                    print(error.localizedDescription)
                                }
                            }
                        }
                    }) {
                        Image(systemName: server.isAdvertising ? "stop.fill" : "play.fill")
                            .font(.title)
                    }
                    .buttonStyle(.plain)
                }
                .padding()
// #if DEBUG
//                 NavigationLink("DEBUG") {
//                     DEBUGView()
//                 }
// #endif
                if let content = mobileGestaltManager.plistContent {
                    TabView {
                        if let model = try? MGModel(from: .shared) {
                            Form {
                                Section("CacheData") {
                                    ValueView(model.cacheData)
                                }
                                Section {
                                    HStack {
                                        Text("BuildVersion")
                                        Spacer()
                                        Text(model.cacheExtra.buildVersion ?? "Unknown")
                                            .textSelection(.enabled)
                                            .foregroundStyle(.secondary)
                                    }
                                    HStack {
                                        Text("ProductType")
                                        Spacer()
                                        Text(model.cacheExtra.productType ?? "Unknown")
                                            .textSelection(.enabled)
                                            .foregroundStyle(.secondary)
                                    }
                                    if let artworkTraits = model.cacheExtra.artworkTraits {
                                        ValueView(artworkTraits, customTitle: "ArtworkTraits")
                                    }
                                    ValueView(model.cacheExtra.additionalFields, customTitle: "Additional Fields (\(model.cacheExtra.additionalFields.count.formatted(.number)))")
                                } header: {
                                    Text("CacheExtra")
                                } footer: {
                                    Text("To find a List of the Keys in Additional Fields in readable Format, go to: https://theapplewiki.com/wiki/List_of_MobileGestalt_keys")
                                }

                                Section("CacheUUID") {
                                    ValueView(value: .string(model.cacheUUID))
                                }
                                Section("CacheVersion") {
                                    ValueView(value: .string(model.cacheVersion))
                                }
                            }
                        }
                        CodeEditor(text: .constant(content.content), position: $position, messages: $messages, language: .swift())
                            .environment(\.codeEditorTheme, colorScheme == .dark ? Theme.defaultDark : Theme.defaultLight)
                            .environment(\.codeEditorLayoutConfiguration, CodeEditor.LayoutConfiguration(showMinimap: false, wrapText: true))
                    }
                    .tabViewStyle(.page)
                } else {
                    ContentUnavailableView(errorText == nil ? "Not Loaded" : "An Error occured", systemImage: "xmark", description: errorText?.foregroundStyle(.red))
                        .onAppear {
                            performFetch()
                        }
                }
                HStack(spacing: 0) {
                    Button(action: performFetch) {
                        HStack {
                            Spacer()
                            Text(errorText == nil ? "Fetch" : "Try again")
                                .bold()
                            Spacer()
                        }
                        .padding(10)
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.roundedRectangle(radius: 0))
                    if let content = mobileGestaltManager.plistContent {
                        ShareLink(item: content, preview: SharePreview("com.apple.MobileGestalt.plist")) {
                            HStack {
                                Spacer()
                                Text("Share")
                                    .bold()
                                Spacer()
                            }
                            .padding(10)
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.roundedRectangle(radius: 0))
                    }
                }
            }
            .clipShape(.rect(cornerRadius: 25))
            .padding(5)
            .toolbar {
                ToolbarItem(placement: .keyboard) {
                    Button("Dismiss Keyboard", systemImage: "keyboard.chevron.compact.down") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
            }
        }
        .animation(.default, value: mobileGestaltManager.plistContent)
        .onAppear {
            if autoStart {
                Task {
                    do {
                        try await server.start()
                    } catch {
                        print(error.localizedDescription)
                    }
                }
            }
        }
    }
    func serverBar(_ isInExpanded: Bool) -> some View {
        HStack {
            Circle()
                .frame(width: 10, height: 10)
                .foregroundStyle(server.isAdvertising ? .green : .red)
            VStack(alignment: .leading) {
                Text("Server")
                    .bold()
                HStack {
                    Text("\(String(server.isAdvertising ? "MobileGestalt is advertising over Bonjour as \(server.displayName)" : "Server stopped"))\(isInExpanded ? "" : " • Tap to Configure")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .contentShape(.rect)
    }
    func performFetch() {
        do {
            try mobileGestaltManager.fetchMobilegestalt()
        } catch {
            print(error.localizedDescription)
            let msg = Message(category: .error, length: 100000, summary: "An Error occured", description: AttributedString(error.localizedDescription))
            messages.insert(TextLocated(location: .init(oneBasedLine: 0, column: 0), entity: msg))
            errorText = Text(error.localizedDescription)
        }
    }
    func prettyHexDump(_ data: Data) -> String {
        var output = ""
        let bytes = [UInt8](data)
        
        for i in stride(from: 0, to: bytes.count, by: 16) {
            let chunk = bytes[i..<min(i+16, bytes.count)]
            let hex = chunk.map { String(format: "%02X", $0) }.joined(separator: " ")
            let ascii = chunk.map { $0 >= 32 && $0 < 127 ? String(UnicodeScalar($0)) : "." }.joined()
            output += String(format: "%08X  %-48@  %@\n", i, hex, ascii)
        }
        return output
    }
}

extension Binding where Value == String? {
    var emptyNil: Binding<String> {
        Binding<String>(get: {
            self.wrappedValue ?? ""
        }) { new in
            if new.isEmpty == true {
                self.wrappedValue = nil
            } else {
                self.wrappedValue = new
            }
        }
    }
}

extension Binding where Value == Int {
    var portLimit: Binding<Int> {
        Binding<Int>(
            get: { self.wrappedValue },
            set: { newValue in
                if newValue >= 65535 {
                    self.wrappedValue = 65535
                } else {
                    self.wrappedValue = newValue
                }
            }
        )
    }
}

class MobileGestaltManager: ObservableObject {
    private init() {}
    static let shared = MobileGestaltManager()
    private let plistLocation = URL(fileURLWithPath: "/private/var/containers/Shared/SystemGroup/systemgroup.com.apple.mobilegestaltcache/Library/Caches/com.apple.MobileGestalt.plist", isDirectory: false)
    
    @Published var plistContent: MobileGestaltFileWrapper?
    
    func fetchMobilegestalt() throws {
        try fetchPlist(plistLocation)
    }
    func fetchPlist(_ location: URL) throws {
        do {
            let dict = try String(contentsOf: location, encoding: .utf8)
            plistContent = MobileGestaltFileWrapper(content: dict)
            if UserDefaults.standard.string(forKey: "savedDisplayName") == nil, let data = dict.data(using: .utf8), let decoded = try? PropertyListDecoder().decode(MGModel.self, from: data), let name = decoded.cacheExtra.artworkTraits?.artworkDeviceProductDescription {
                MobileGestaltServer.shared.displayName = name
            }
        } catch {
            throw MobileGestaltFetchingError.unableToLoad(error.localizedDescription)
        }
    }
}

enum MobileGestaltFetchingError: LocalizedError {
    case unableToLoad(_ additionalInfo: String)
    
    var errorDescription: String? {
        switch self {
            case .unableToLoad(let moreInfo):
                return "An error occurred loading the MobileGestalt file to a Dictionary\n\n\(moreInfo)"
        }
    }
    
    var failureReason: String? {
        switch self {
            case .unableToLoad:
                return "MobileGestalt was unable to be loaded"
        }
    }
    
    var helpAnchor: String? {
        switch self {
            case .unableToLoad:
                return "Unknown"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
            case .unableToLoad:
                return "Unknown"
        }
    }
}



#Preview {
    ContentView()
}

// struct MobileGestalt: Codable {
//     var cacheVersion: String
//     var cacheExtra: [String: AnyCodable]
//     var cacheUUID: String
//     var cacheData: Data
//     enum CodingKeys: String, CodingKey {
//         case cacheVersion = "CacheVersion"
//         case cacheExtra = "CacheExtra"
//         case cacheUUID = "CacheUUID"
//         case cacheData = "CacheData "
//     }
// }

import UniformTypeIdentifiers

struct MobileGestaltFileWrapper: Transferable, Equatable {
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .propertyList, exporting: { item in
            let location = URL.temporaryDirectory.appendingPathComponent("com.apple.MobileGestalt.plist", conformingTo: .propertyList)
            try? FileManager.default.removeItem(at: location)
            try item.content.write(to: location, atomically: true, encoding: String.Encoding.utf8)
            return SentTransferredFile(location)
        })
        .suggestedFileName("com.apple.MobileGestalt.plist")
    }
    var content: String
}
