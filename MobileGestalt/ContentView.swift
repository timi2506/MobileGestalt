//
//  ContentView.swift
//  MobileGestalt
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
                if let content = mobileGestaltManager.plistContent {
                    CodeEditor(text: .constant(content.content), position: $position, messages: $messages, language: .swift())
                        .environment(\.codeEditorTheme, colorScheme == .dark ? Theme.defaultDark : Theme.defaultLight)
                        .environment(\.codeEditorLayoutConfiguration, CodeEditor.LayoutConfiguration(showMinimap: false, wrapText: true))
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
        }
        .animation(.default, value: mobileGestaltManager.plistContent)
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
        guard let dict = try? String(contentsOf: location, encoding: .utf8) else { throw MobileGestaltFetchingError.unableToLoad }
        plistContent = MobileGestaltFileWrapper(content: dict)
    }
}

enum MobileGestaltFetchingError: LocalizedError {
    case unableToLoad
    var localizedDescription: LocalizedStringKey {
        switch self {
            case .unableToLoad:
                "An Error occured loading the MobileGestalt File to a Dictionary"
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
