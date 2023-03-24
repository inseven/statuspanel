import { forEach, pipe, range, reverse } from "remeda"
import { StreamDataView } from "stream-data-view"

export const decodeBundle = (
  bundle: ArrayBuffer,
  sodiumSealOpen: (imageData: Uint8Array) => Uint8Array
): Array<Uint8Array> => {
  const data = new StreamDataView(bundle, true)
  const marker = data.getNextUint16()

  if (marker !== 0xff00) {
    throw new Error("invalid marker")
  }

  const headerLength = data.getNextUint8()
  const wakeupTime = data.getNextUint16()
  let imageCount = null
  if (headerLength >= 6) {
    imageCount = data.getNextUint8()
  }

  const offsets = []
  if (imageCount === null) {
    offsets.push(0)
  } else {
    pipe(
      range(0, imageCount),
      forEach(() => {
        offsets.push(swap32(data.getNextUint32()))
      })
    )
  }

  const ranges: Array<[number, number]> = []
  pipe(
    offsets,
    reverse,
    forEach.indexed((offset: number, i) => {
      ranges.push([offset, i === 0 ? data.getLength() : ranges[i - 1]![0]])
    }),
    () => ranges.reverse()
  )

  const images: Array<Uint8Array> = []
  ranges.forEach(([start, end]) => {
    const length = end - start
    const imageData = data.getBytes(start, length)
    const im = sodiumSealOpen(imageData)
    images.push(im)
  })

  return images
}

const swap32 = (val: number) =>
  ((val & 0xff) << 24) | ((val & 0xff00) << 8) | ((val >> 8) & 0xff00) | ((val >> 24) & 0xff)
