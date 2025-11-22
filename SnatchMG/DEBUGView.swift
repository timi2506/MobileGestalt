//
//  DEBUGView.swift
//  SnatchMG
//
//  Created by Tim on 20.11.25.
//

import SwiftUI

struct DEBUGView: View {
    @State var filePath: String = ""
    @State var content = ""
    @State var error: Error?
    var url: URL {
        URL(fileURLWithPath: filePath)
    }
    @State var copyAnswerString = ""
    var body: some View {
        Form {
            Section("FetchAnyFile") {
                if let error {
                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                TextField("FilePath", text: $filePath)
                Button("Fetch") {
                    if let s = try? String(contentsOf: url, encoding: .utf8) {
                        content = s
                    }
                }
                ShareLink(item: MobileGestaltFileWrapper(content: content), preview: SharePreview(url.lastPathComponent)) {
                    HStack {
                        Spacer()
                        Text("Share")
                            .bold()
                        Spacer()
                    }
                    .padding(10)
                }
                if !content.isEmpty {
                    TextEditor(text: $content)
                }
            }
            Section("SMGCopyAnswer") {
                TextField("CopyAnswerString", text: $copyAnswerString)
                Button("Perform Copy as String") {
                    if let string = ValueForMGKeyAsString(copyAnswerString) {
                        copyAnswerString = string
                    }
                }
            }
        }
        .navigationTitle("Debug")
        .toolbarTitleDisplayMode(.inline)
    }
}
