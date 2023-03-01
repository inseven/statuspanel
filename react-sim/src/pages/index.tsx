import { type NextPage } from "next"
import { useSodium } from "../utils/sodium"
import QRCode from "react-qr-code"
import { StreamDataView } from "stream-data-view"
import { forEach, pipe, range, reverse } from "remeda"
import { useLocalStorage } from "react-use"
import { useEffect, useRef, useState } from "react"

const Home: NextPage = () => {
	const sodium = useSodium()
	const [keyPairPub, setKeyPairPub] = useLocalStorageUint8Array(
		"keyPairPub",
		undefined
	)
	const [keyPairPriv, setKeyPairPriv] = useLocalStorageUint8Array(
		"keyPairPriv",
		undefined
	)
	const [images, setImages] = useState<Array<Uint8Array>>([])

	const canvasRef = useRef<HTMLCanvasElement>(null)

	useEffect(() => {
		const canvas = canvasRef.current
		const ctx = canvas?.getContext("2d")
		if (!ctx) return

		ctx.fillStyle = "red"
		ctx.beginPath()
		ctx.arc(50, 100, 20, 0, 2 * Math.PI)
		ctx.fill()
	}, [canvasRef])

	if (sodium === undefined) {
		return <p>waiting for sodium..</p>
	}

	if (keyPairPub === undefined || keyPairPriv === undefined) {
		const kp = sodium.crypto_box_keypair()
		setKeyPairPub(kp.publicKey)
		setKeyPairPriv(kp.privateKey)
		return <p>generating keypair..</p>
	}

	const pubBase64 = sodium.to_base64(
		keyPairPub,
		sodium.base64_variants.ORIGINAL
	)
	const id = "reactidd"
	const url = `statuspanel:r2?id=${id}&pk=${encodeURIComponent(pubBase64)}`

	const update = async () => {
		const ab = await (
			await fetch(`https://api.statuspanel.io/api/v2/${id}`)
		).arrayBuffer()

		const data = new StreamDataView(ab, true)
		const marker = data.getNextUint16()
		if (marker !== 0xff00) {
			console.log("invalid marker")
			return
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
			const im = sodium.crypto_box_seal_open(imageData, keyPairPub, keyPairPriv)
			console.log({ im: createImageBitmap(new Blob([im])) })
			images.push(im)
		})
		setImages(images)
	}

	return (
		<main className="flex min-h-screen flex-col items-center justify-center bg-gradient-to-b from-[#2e026d] to-[#15162c]">
			<div className="container flex flex-col items-center justify-center gap-12 px-4 py-16 ">
				<p className="text-white">{url}</p>
				<QRCode value={url} />
				<button onClick={() => void update()}>update</button>
				{images.map((i, idx) => {
					const width = 100
					const height = 100
					return (
						// eslint-disable-next-line @next/next/no-img-element, jsx-a11y/alt-text
						<img
							key={`${idx}`}
							src={URL.createObjectURL(new Blob([i], { type: "image/png" }))}
						/>
					)
				})}
				<canvas ref={canvasRef} />
			</div>
		</main>
	)
}

export default Home

function swap32(val: number) {
	return (
		((val & 0xff) << 24) |
		((val & 0xff00) << 8) |
		((val >> 8) & 0xff00) |
		((val >> 24) & 0xff)
	)
}

function bufferToString(buf: Uint8Array) {
	return String.fromCharCode(...new Uint8Array(buf))
}

function stringToUint8Array(str: string) {
	const buf = new ArrayBuffer(str.length)
	const bufView = new Uint8Array(buf)
	for (let i = 0, strLen = str.length; i < strLen; i++) {
		bufView[i] = str.charCodeAt(i)
	}
	return bufView
}

const useLocalStorageUint8Array = (
	key: string,
	initialValue: Uint8Array | undefined
) =>
	useLocalStorage<Uint8Array | undefined>(key, initialValue, {
		raw: false,
		serializer: (kpp) => (kpp === undefined ? "undef" : bufferToString(kpp)),
		deserializer: (kpp) =>
			kpp === "undef" ? undefined : stringToUint8Array(kpp),
	})
