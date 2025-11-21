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
    var body: some View {
        Form {
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
            TextEditor(text: $content)
        }
        .navigationTitle("Debug")
        .toolbarTitleDisplayMode(.inline)
    }
}
