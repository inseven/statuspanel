import { StreamDataView } from "stream-data-view"

const colorMap: Record<number, number> = {
  0: 0x000000ff, // no color
  1: 0x7fffd4ff, // highlight color
  2: 0xffffffff, // max contrast color
}

export const expand2BPPValues = (img: Uint8Array): Uint8Array => {
  const input = new StreamDataView(img.buffer, true)
  const inputLength = input.getLength()

  const output = new StreamDataView(undefined, true)
  output.resize(inputLength * 4 * 4)

  while (input.getOffset() < inputLength) {
    const byte = input.getNextBytes(1)[0]!

    const pixel0 = (byte >> 0) & 3
    output.setNextUint32(colorMap[pixel0] ?? 0xffffffff)

    const pixel1 = (byte >> 2) & 3
    output.setNextUint32(colorMap[pixel1] ?? 0xffffffff)

    const pixel2 = (byte >> 4) & 3
    output.setNextUint32(colorMap[pixel2] ?? 0xffffffff)

    const pixel3 = (byte >> 6) & 3
    output.setNextUint32(colorMap[pixel3] ?? 0xffffffff)
  }

  return new Uint8Array(output.getBuffer())
}
