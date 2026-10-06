// Copyright (c) 2018-2026 Jason Morley, Tom Sutcliffe
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

extension Publisher where Failure == Never {

    func debounceOnMain(for dueTime: DispatchQueue.SchedulerTimeType.Stride,
                        _ handler: @escaping @MainActor (Output) -> Void) -> AnyCancellable {
        debounce(for: dueTime, scheduler: DispatchQueue.main)
            .sink { value in
                MainActor.assumeIsolated {
                    handler(value)
                }
            }
    }

    func sinkOnMain(_ handler: @escaping @MainActor (Output) -> Void) -> AnyCancellable {
        receive(on: DispatchQueue.main)
            .sink { value in
                MainActor.assumeIsolated {
                    handler(value)
                }
            }
    }

}
