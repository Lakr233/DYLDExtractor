//
//  DYLDExtractorApp.swift
//  DYLDExtractor
//
//  Created by Lakr Aream on 2022/6/10.
//

import SwiftUI

let homePage = URL(string: "https://github.com/Lakr233/DYLDExtractor") ?? URL(fileURLWithPath: "/")

@main
struct ExtractorApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(
                    minWidth: 600, idealWidth: 800, maxWidth: .infinity,
                    minHeight: 200, idealHeight: 300, maxHeight: .infinity
                )
        }
        .windowToolbarStyle(UnifiedCompactWindowToolbarStyle())
    }
}
