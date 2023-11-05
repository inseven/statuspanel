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
import { v4 as uuidv4 } from "uuid"

export const App = () => {
  const windowFocused = useWindowFocus()
  const prevWindowFocused = usePreviousDistinct(windowFocused)
  useEffect(() => {
    if (prevWindowFocused === false && windowFocused === true) {
      fetchImages()
    }
  }, [windowFocused, prevWindowFocused])

  const sodium = useSodium()
  const [id, setId] = useLocalStorage("id", uuidv4())
  const [keyPairPub, setKeyPairPub] = useLocalStorageUint8Array("keyPairPub", undefined)
  const [keyPairPriv, setKeyPairPriv] = useLocalStorageUint8Array("keyPairPriv", undefined)

  const [images, setImages] = useState<Array<Uint8Array>>([])
  const [status, setStatus] = useState("Ready")
  const [url, setURL] = useState("")
  const [imageIndex, setImageIndex] = useState<number | null>(null)

  useEffect(() => {
    setImageIndex(images.length === 0 ? null : 0)
  }, [images])

  const cycleImages = () => {
    if (imageIndex === null) return
    setImageIndex((imageIndex + 1) % images.length)
  }

  const reset = () => {
    setId(uuidv4())
    setImageIndex(null)
    setImages([])
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

  useEffect(() => {
    if (sodium === undefined) {
      return
    }

    if (keyPairPub === undefined || keyPairPriv === undefined) {
      const kp = sodium.crypto_box_keypair()
      setKeyPairPriv(kp.privateKey)
      setKeyPairPub(kp.publicKey)
      return
    }

    const pubBase64 = sodium.to_base64(keyPairPub, sodium.base64_variants.ORIGINAL)
    setURL(`statuspanel:r2?id=${id}&pk=${encodeURIComponent(pubBase64)}`)

    fetchImages()

  }, [sodium, keyPairPub, keyPairPriv, id])

  const fetchImages = async () => {
    if (id === undefined || sodium === undefined || keyPairPub === undefined || keyPairPriv == undefined) {
      return
    }
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
    <main>
      <div>

        <div className="screen" style={{width: 640, height: 380}}>
            {imageIndex !== null ? (
              <Canvas width="640px" height="380px" pixels={imagePixels[imageIndex]} />
            ) : (
              <QRCode value={url} />
            )}
        </div>

        <ul>
          <li><button onClick={() => cycleImages()}>Action</button></li>
          <li><button onClick={() => void fetchImages()}>Refresh</button></li>
          <li><button onClick={() => reset()}>Reset</button></li>
        </ul>
        <p>Status: {status}</p>
        <details>
          <summary>Device Information</summary>
          <table>
            <tr>
              <th>Pairing URL</th>
              <td>{url}</td>
            </tr>
            <tr>
              <th>Identifier</th>
              <td>{id}</td>
            </tr>
            <tr>
              <th>Wakeup Time</th>
              <td></td>
            </tr>
          </table>
        </details>
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
