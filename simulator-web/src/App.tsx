import { useEffect, useMemo, useState } from "react"
import useWindowFocus from "use-window-focus"
import QRCode from "react-qr-code"
import { map, pipe } from "remeda"
import { Canvas } from "./Canvas"
import { decodeBundle } from "./utils/decodeBundle"
import { expand2BPPValues } from "./utils/expand2BPP"
import { useSodium } from "./utils/sodium"
import { useLocalStorageUint8Array } from "./utils/storage"
import { RLEDecoder } from "./utils/RLEDecoder"
import { useLocalStorage, usePrevious, usePreviousDistinct } from "react-use"

export const App = () => {
  const windowFocused = useWindowFocus()
  const prevWindowFocused = usePreviousDistinct(windowFocused)
  useEffect(() => {
    if (prevWindowFocused === false && windowFocused === true) {
      fetchImages()
    }
  }, [windowFocused, prevWindowFocused])

  const sodium = useSodium()
  const [id, setId] = useLocalStorage("id", "reactsim")
  const [keyPairPub, setKeyPairPub] = useLocalStorageUint8Array("keyPairPub", undefined)
  const [keyPairPriv, setKeyPairPriv] = useLocalStorageUint8Array("keyPairPriv", undefined)

  const [images, setImages] = useState<Array<Uint8Array>>([])
  const [status, setStatus] = useState("Ready")
  const [imageIndex, setImageIndex] = useState<number | null>(null)

  useEffect(() => {
    setImageIndex(images.length === 0 ? null : 0)
  }, [images])

  const cycleImages = () => {
    if (imageIndex === null) return
    setImageIndex((imageIndex + 1) % images.length)
  }

  const imagePixels = useMemo(() => {
    if (images.length === 0) return []

    return pipe(
      images,
      tap(() => setStatus("RLE decoding..")),
      map(RLEDecoder),
      tap(() => setStatus("Expanding to BPP..")),
      map(expand2BPPValues),
      tap(() => setStatus("Ready")),
    )
  }, [images])

  if (sodium === undefined) {
    return <p>Waiting for sodium..</p>
  }

  if (keyPairPub === undefined || keyPairPriv === undefined) {
    const kp = sodium.crypto_box_keypair()
    setKeyPairPriv(kp.privateKey)
    setKeyPairPub(kp.publicKey)
    return <p>Generating keypair..</p>
  }

  if (id === undefined) {
    return <p>should never happen. types are wrong.</p>
  }

  const pubBase64 = sodium.to_base64(keyPairPub, sodium.base64_variants.ORIGINAL)
  const url = `statuspanel:r2?id=${id}&pk=${encodeURIComponent(pubBase64)}`

  const fetchImages = async () => {
    setStatus("Fetching bundle..")
    const bundle = await (
      await fetch(`https://api.statuspanel.io/api/v3/status/${id}`)
    ).arrayBuffer()

    setStatus("Decoding bundle..")
    const resultingImages = decodeBundle(bundle, (imageData) =>
      sodium.crypto_box_seal_open(imageData, keyPairPub, keyPairPriv),
    )

    setImages(resultingImages)
  }

  return (
    <main className="flex min-h-screen flex-col items-center bg-gray-900 text-white">
      <div className="container flex flex-col items-center justify-center gap-8 px-4 py-16">
        <div className="flex flex-row gap-2">
          <input className="text-black" value={id} onChange={(e) => void setId(e.target.value)} />
          <p className={id.length === 8 ? `text-green-500` : `text-red-500`}>{id.length} chars</p>
        </div>
        <div className="p-[4px] bg-white">
          <QRCode value={url} />
        </div>
        <p>{url}</p>
        <button onClick={() => void fetchImages()}>Fetch bundle</button>
        <p>Status: {status}</p>
        <button onClick={() => cycleImages()}>Cycle images</button>
        {imageIndex !== null && (
          <Canvas width="640px" height="380px" pixels={imagePixels[imageIndex]} />
        )}
      </div>
    </main>
  )
}

const tap =
  <T,>(fn: () => void) =>
  (x: T) => {
    fn()
    return x
  }
