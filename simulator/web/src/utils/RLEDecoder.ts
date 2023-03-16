import { range } from "remeda"
import { StreamDataView } from "stream-data-view"

export const RLEDecoder = (input: Uint8Array) => {
  const data = new StreamDataView(input.buffer, true)
  const dataLength = data.getLength()

  const output = new StreamDataView(undefined, true)
  let offset = 0

  while (data.getOffset() < dataLength) {
    const value = data.getNextUint8()
    if (value === 255) {
      const count = data.getNextUint8()
      const actualValue = data.getNextUint8()
      range(0, count).forEach((i) => {
        output.setUint8(offset, actualValue)
        offset++
      })
    } else {
      output.setUint8(offset, value)
      offset++
    }
  }

  return new Uint8Array(output.getBuffer())
}
