//
//  ContentView.swift
//  micromute
//
//  Created by snus on 07.02.2026.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text(L("content_hello_world"))
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
