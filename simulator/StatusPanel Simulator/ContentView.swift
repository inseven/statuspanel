//
//  ContentView.swift
//  StatusPanel Simulator
//
//  Created by Jason Barrie Morley on 22/02/2023.
//

import SwiftUI

struct Device {

    let width: Int
    let height: Int

    static let v1 = Device(width: 640, height: 384)

}

struct ContentView: View {

    @EnvironmentObject var applicationModel: ApplicationModel

    @State var isHidden = false

    var body: some View {
        ZStack {
            if let image = applicationModel.code {
                Image(nsImage: image)
            }
            if let defaultImage = applicationModel.contents,
               let privacyImage = applicationModel.security {
                if !isHidden {
                    Image(nsImage: defaultImage)
                } else {
                    Image(nsImage: privacyImage)
                }
            }
        }
        .frame(width: CGFloat(Device.v1.width), height: CGFloat(Device.v1.height))
        .background(.white)
        .padding()
        .toolbar {
            ToolbarItem {
                Toggle(isOn: $isHidden) {
                    Label("Refresh", systemImage: "eye.slash.fill")
                }
            }
            ToolbarItem {
                Button {
                    // TODO: This task should be hidden in the model
                    Task {
                        try? await applicationModel.update()
                    }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
