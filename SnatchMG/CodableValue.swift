//
//  CodableValue.swift
//  SnatchMG
//
//  Created by Tim on 22.11.25.
//

import SwiftUI

enum CodableValue: Codable, Hashable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case dictionary([String: CodableValue])
    case array([CodableValue])
    case data(Data)
    case null
    
    init(from any: Codable) {
        if let data = try? PropertyListEncoder().encode(any), let finished = try? PropertyListDecoder().decode(CodableValue.self, from: data) {
            self = finished
        } else {
            self = .null
        }
    }
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if container.decodeNil() {
            self = .null
        } else if let v = try? container.decode(String.self) {
            self = .string(v)
        } else if let v = try? container.decode(Int.self) {
            self = .int(v)
        } else if let v = try? container.decode(Double.self) {
            self = .double(v)
        } else if let v = try? container.decode(Bool.self) {
            self = .bool(v)
        } else if let v = try? container.decode([String: CodableValue].self) {
            self = .dictionary(v)
        } else if let v = try? container.decode([CodableValue].self) {
            self = .array(v)
        } else if let v = try? container.decode(Data.self) {
            self = .data(v)
        } else {
            throw DecodingError.typeMismatch(
                CodableValue.self,
                .init(codingPath: decoder.codingPath, debugDescription: "Unsupported value")
            )
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
            case .string(let v): try container.encode(v)
            case .int(let v): try container.encode(v)
            case .double(let v): try container.encode(v)
            case .bool(let v): try container.encode(v)
            case .dictionary(let v): try container.encode(v)
            case .array(let v): try container.encode(v)
            case .data(let v): try container.encode(v)
            case .null: try container.encodeNil()
        }
    }
}

struct ValueView: View {
    init(_ value: Codable, customTitle: String? = nil) {
        self.value = CodableValue(from: value)
        self.customTitle = customTitle
    }
    init(value: CodableValue, customTitle: String? = nil) {
        self.value = value
        self.customTitle = customTitle
    }
    var value: CodableValue
    var customTitle: String?
    @State var searchText = ""
    @State var searchMode: SearchMode = .keys
    @State var showSearch = false
    var body: some View {
        VStack {
            switch value {
                case .string(let string):
                    TextField(string, text: .constant(string), axis: .vertical)
                case .int(let int):
                    TextField(int.formatted(.number), text: .constant(int.formatted(.number)), axis: .vertical)
                case .double(let double):
                    TextField(double.formatted(.number), text: .constant(double.formatted(.number)), axis: .vertical)
                case .bool(let bool):
                    Text(bool ? "true" : "false")
                        .textSelection(.enabled)
                case .dictionary(let dictionary):
                    NavigationLink(customTitle ?? "Dictionary (\(dictionary.keys.count.formatted(.number)) Keys)") {
                        Form {
                            ForEach(dictionary.keys.filter({ key in
                                return searchMode.check(value: key, searchText: searchText, isKey: true)
                            }), id: \.self) { key in
                                let value = dictionary[key] ?? .null
                                if searchMode.check(value: String(describing: value), searchText: searchText, isKey: false) {
                                    Section(key) {
                                        ValueView(value: value, customTitle: key)
                                    }
                                }
                            }
                        }
                        .navigationTitle(customTitle ?? "Dictionary")
                        .searchable(text: $searchText, isPresented: $showSearch)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Menu("Search Options", systemImage: "magnifyingglass") {
                                    Button("Open Search Bar", systemImage: "magnifyingglass") {
                                        showSearch = true
                                    }
                                    Picker("Search Mode", systemImage: "line.3.horizontal.decrease", selection: $searchMode) {
                                        ForEach(SearchMode.allCases) { searchMode in
                                            Text(searchMode.title)
                                                .tag(searchMode)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                }
                            }
                        }
                    }
                case .array(let array):
                    NavigationLink(customTitle ?? "Array (\(array.count.formatted(.number)) Values)") {
                        Form {
                            ForEach(array, id: \.self) { value in
                                ValueView(value: value)
                            }
                        }
                        .navigationTitle(customTitle ?? "Array")
                        .searchable(text: $searchText)
                    }
                case .data(let data):
                    NavigationLink("Data (\(data.description))") {
                        ScrollView {
                            Text(data.base64EncodedString())
                                .textSelection(.enabled)
                        }
                        .padding()
                        .navigationTitle(customTitle ?? "Data")
                    }
                case .null:
                    Text("No Value")
            }
        }
    }
    enum SearchMode: Hashable, CaseIterable, Identifiable {
        case keys
        case values
        case keysAndValues
        var id: Int {
            return self.hashValue
        }
        var title: String {
            switch self {
                case .keys:
                    "Keys only"
                case .values:
                    "Values only"
                case .keysAndValues:
                    "Values and Keys"
            }
        }
        func check(value v: String, searchText s: String, isKey: Bool) -> Bool {
            guard !s.isEmpty else { return true }
            let searchText = s.lowercased()
            let value = v.lowercased()
            switch self {
                case .keys:
                    if isKey {
                        return value.contains(searchText)
                    } else {
                        return true
                    }
                case .values:
                    if !isKey {
                        return value.contains(searchText)
                    } else {
                        return true
                    }
                case .keysAndValues:
                    return value.contains(searchText)
            }
        }
    }
}
