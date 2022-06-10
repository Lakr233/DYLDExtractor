//
//  ContentView.swift
//  DYLDExtractor
//
//  Created by Lakr Aream on 2022/6/10.
//

import Colorful
import Extractor
import SwiftUI

let extractor = DYLDExtractor.shared()

struct ContentView: View {
    @State var currentProgress: Progress? = nil

    var body: some View {
        ZStack {
            contents
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(
            VStack {
                Spacer()
                HStack { info
                    Spacer()
                    Button {
                        NSWorkspace.shared.open(homePage)
                    } label: {
                        Image(systemName: "questionmark.circle")
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding()
            .opacity(0.5)
        )
        .background(
            ColorfulView(colors: [.accentColor], colorCount: 4)
                .opacity(0.25)
        )
        .navigationTitle("Extractor")
        .toolbar {
            ToolbarItem {
                Button {
                    selectCache { beginOperation(with: $0) }
                } label: {
                    Image(systemName: "square.and.arrow.down")
                }
                .disabled(currentProgress != nil)
            }
        }
    }

    var contents: some View {
        Group {
            if let currentProgress = currentProgress {
                VStack(spacing: 15) {
                    ProgressView()
                    ProgressView(
                        value: currentProgress.fractionCompleted,
                        total: 1.0
                    ) {
                        HStack {
                            Text("Please wait... ☕️")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                            Spacer()
                            Text("\(currentProgress.completedUnitCount)/\(currentProgress.totalUnitCount)")
                                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        }
                    }
                }
                .padding()
            } else {
                VStack(spacing: 14) {
                    Image(systemName: "helm")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                    Text("Select your dyld_shared_cache to start.")
                        .font(.headline)
                    Spacer()
                        .frame(height: 14)
                }
            }
        }
    }

    var version: String {
        Bundle
            .main
            .infoDictionary?["CFBundleShortVersionString"]
            as? String
            ?? "undefined"
    }

    var info: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Extractor: \(version)")
            if extractor.bundleWasOverwritten {
                Text("dsc_extractor.bundle: overwritten")
                    .foregroundColor(.red)
            } else {
                Text("dsc_extractor.bundle: \(extractor.currentBundleVersion())")
            }
        }
        .font(.footnote)
    }

    func selectCache(completion: @escaping (URL) -> Void) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if let window = NSApp.keyWindow {
            panel.beginSheetModal(for: window) { response in
                guard response == .OK else { return }
                guard let url = panel.url else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    completion(url)
                }
            }
        }
    }

    func selectOutputDir(withSuggestion: URL, completion: @escaping (URL?) -> Void) {
        let savePanel = NSSavePanel()
        savePanel.directoryURL = withSuggestion
        savePanel.canCreateDirectories = true
        savePanel.showsTagField = false
        savePanel.nameFieldStringValue = withSuggestion.lastPathComponent
        if let window = NSApp.keyWindow {
            savePanel.beginSheetModal(for: window) { resp in
                guard resp == .OK else { return }
                guard let url = savePanel.url else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    try? FileManager.default.removeItem(at: url)
                    completion(url)
                }
            }
        }
    }

    func beginOperation(with cachePath: URL) {
        debugPrint("\(#function) \(cachePath.path)")
        let name = cachePath.lastPathComponent
        let saveSuggest = cachePath
            .deletingLastPathComponent() // delete the file path
            .deletingLastPathComponent() // delete the common dir path
            .appendingPathComponent(name + ".out")
        selectOutputDir(withSuggestion: saveSuggest) { outPath in
            guard let outPath = outPath else {
                return
            }
            beginOperation(withCacheAtPath: cachePath, withOutputAtPath: outPath)
        }
    }

    func beginOperation(withCacheAtPath cachePath: URL, withOutputAtPath outPath: URL) {
        debugPrint("\(#function) \(cachePath.path) -> \(outPath.path)")
        currentProgress = Progress()
        DispatchQueue.global().async {
            let result = extractor.extractWithCache(
                atPath: cachePath.path,
                toDestinationAtPath: outPath.path
            ) { progress in
                DispatchQueue.main.async {
                    currentProgress = progress
                }
            }
            DispatchQueue.main.async {
                complete(withResult: Int(result), outputLocation: outPath)
            }
        }
    }

    func complete(withResult: Int, outputLocation: URL) {
        currentProgress = nil
        let alert = NSAlert()
        alert.messageText = "Program Exited with Code: \(withResult)"
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Show in Finder")
        if let window = NSApp.keyWindow {
            alert.beginSheetModal(for: window) { resp in
                if resp == .alertSecondButtonReturn {
                    NSWorkspace.shared.open(outputLocation)
                }
            }
        } else {
            if alert.runModal() == .alertSecondButtonReturn {
                NSWorkspace.shared.open(outputLocation)
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
