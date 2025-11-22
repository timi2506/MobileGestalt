//
//  ContentUnavailableViewBackport.swift
//  SnatchMG
//
//  Created by Tim on 21.11.25.
//

import SwiftUI

struct ContentUnavailableViewBackport: View {
    init(_ title: LocalizedStringKey, systemImage: String, description: Text? = nil) {
        self.title = title
        self.systemImage = systemImage
        self.description = description
    }
    var title: LocalizedStringKey
    var systemImage: String
    var description: Text?
    var body: some View {
        if #available(macOS 17, *) {
            ContentUnavailableView(title, systemImage: systemImage, description: description)
        } else {
            VStack {
                Image(systemName: systemImage)
                    .font(.system(size: 75))
                    .foregroundStyle(.tertiary)
                    .padding(5)
                Text(title)
                    .font(.system(size: 25))
                    .bold()
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(5)
                if let description {
                    description
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(5)
                }
            }
            .padding(.vertical, 25)
        }
    }
}
