export const expand2BPPValues = (img: Uint8Array): Uint8Array => {
  const colorMap: Record<number, number> = {
    0: 0x000000ff, // no color
    1: 0x7fffd4ff, // highlight color
    2: 0xffffffff, // max contrast color
  }

  const data = new Uint8Array(img.length * 4 * 4)

  for (let i = 0; i < img.length; i++) {
    const byte = img[i]!
    const pixel0 = (byte >> 0) & 3
    data.set(new Uint8Array(new Uint32Array([colorMap[pixel0] ?? 0xffffffff]).buffer), i * 16)

    const pixel1 = (byte >> 2) & 3
    data.set(new Uint8Array(new Uint32Array([colorMap[pixel1] ?? 0xffffffff]).buffer), i * 16 + 4)

    const pixel2 = (byte >> 4) & 3
    data.set(new Uint8Array(new Uint32Array([colorMap[pixel2] ?? 0xffffffff]).buffer), i * 16 + 8)

    const pixel3 = (byte >> 6) & 3
    data.set(new Uint8Array(new Uint32Array([colorMap[pixel3] ?? 0xffffffff]).buffer), i * 16 + 12)
  }

  return data
}
