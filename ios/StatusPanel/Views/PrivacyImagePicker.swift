// Copyright (c) 2018-2023 Jason Morley, Tom Sutcliffe
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import Combine
import PhotosUI
import SwiftUI

struct PrivacyImagePicker<Content: View>: View {

    class Model: ObservableObject {

        @Binding var image: String?

        @Published var selection: PhotosPickerItem? = nil
        @Published var error: Error? = nil

        private var cancellables: [AnyCancellable] = []

        init(image: Binding<String?>) {
            _image = image
        }

        func start() {
            $selection
                .compactMap { $0 }
                .sink { selection in
                    selection.loadTransferable(type: Data.self) { [weak self] result in
                        guard let self else { return }
                        switch result {
                        case .success(let optionalData):
                            guard let data = optionalData else {
                                DispatchQueue.main.sync {
                                    self.error = StatusPanelError.invalidImage
                                }
                                return
                            }
                            do {
                                let filename = try PrivacyImageManager.writePrivacyImage(data)
                                let previousImage = DispatchQueue.main.sync {
                                    let previousImage = self.image
                                    self.image = filename
                                    return previousImage
                                }
                                if let previousImage {
                                    try PrivacyImageManager.removePrivacyImage(previousImage)
                                }
                            } catch {
                                DispatchQueue.main.sync {
                                    self.error = error
                                }
                            }
                        case .failure(let error):
                            DispatchQueue.main.sync {
                                self.error = error
                            }
                        }
                    }
                }
                .store(in: &cancellables)
        }

    }

    @StateObject var model: Model
    let content: () -> Content

    init(image: Binding<String?>, @ViewBuilder _ content: @escaping () -> Content) {
        _model = StateObject(wrappedValue: Model(image: image))
        self.content = content
    }

    var body: some View {
        VStack {
            PhotosPicker(selection: $model.selection, matching: .images, photoLibrary: .shared()) {
                content()
            }
        }
        .presents($model.error)
        .onAppear {
            model.start()
        }
    }

}
