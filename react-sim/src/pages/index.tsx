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
	const [imagePixels, setImagePixels] = useState<Array<Uint8Array>>([])
	const [width, setWidth] = useState(640)

	useEffect(() => {
		if (images.length < 1) return
		console.log("effect")
		const image = images[0]!
		const buffLen = image.length
		const hex = new Array(buffLen)
		for (let i = 0; i < buffLen; i++) {
			hex[i] = ("0" + image[i].toString(16)).slice(-2)
		}
		console.log({ imageL: image.length, image, hex }) // 7070
		const decodedImage = rleDecoder(image)
		console.log({ decodedImageL: decodedImage.length, decodedImage }) // 61222
		const pixels = expand2BPPValues(decodedImage)
		console.log({ HOW: pixels.length })
		setImagePixels([pixels])
	}, [images])

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
			images.push(im)
		})
		setImages(images)
	}

	const draw = (ctx: CanvasRenderingContext2D, frameCount: number) => {
		console.log("draw")
		if (imagePixels.length < 1) return
		const pixels = imagePixels[0]!
		const drawPixel = (
			ctx: CanvasRenderingContext2D,
			onOff: "on" | "off",
			x: number,
			y: number
		) => {
			const size = 1
			ctx.fillStyle = onOff === "on" ? "black" : "white"
			ctx.fillRect(x * size, y * size, size, size)
		}
		ctx.clearRect(0, 0, ctx.canvas.width, ctx.canvas.height)
		ctx.beginPath()
		pixels
			// .filter((x, idx) => idx % 4 === 1)
			.forEach((i, idx) => {
				drawPixel(ctx, i === 0 ? "on" : "off", idx % width, idx / width)
			})
	}

	const pixels = imagePixels[0] ?? [[0]]

	return (
		<main className="flex min-h-screen flex-col items-center justify-center bg-gradient-to-b from-[#2e026d] to-[#15162c]">
			<div className="container flex flex-col items-center justify-center gap-12 px-4 py-16 ">
				<p className="text-white">{url}</p>
				<QRCode value={url} />
				<button onClick={() => void update()}>update</button>
				<p>{width}</p>
				<input
					type="range"
					min={1}
					max={1300}
					value={width}
					onChange={(e) => setWidth(Number(e.target.value))}
				/>
				<Canvas width={width} height="380px" draw={draw} pixels={pixels} />
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

const Canvas = ({
	pixels,
	...restProps
}: {
	draw: (ctx: CanvasRenderingContext2D) => void
}) => {
	const canvasRef = useRef<HTMLCanvasElement>(null)

	useEffect(() => {
		const canvas = canvasRef.current!
		const ctx = canvas.getContext("2d")!

		var mc_imageData = ctx.getImageData(0, 0, 640, 380)
		var mc_px_data = mc_imageData.data

		mc_px_data = new Uint8ClampedArray(pixels)
		mc_imageData.data.set(mc_px_data)
		ctx.putImageData(mc_imageData, 0, 0)
	}, [pixels])

	return <canvas ref={canvasRef} {...restProps} />
}

const rleDecoder = (input: Uint8Array) => {
	const data = new StreamDataView(input.buffer, true)
	const output = new StreamDataView(undefined, true)
	let offset = 0

	let counter = 0
	let done = false
	while (!done) {
		const value = data.getNextUint8()
		if (value === 255) {
			const count = data.getNextUint8()
			const actualValue = data.getNextUint8()
			range(0, count).forEach((i) => {
				output.setUint8(offset, actualValue)
				offset++
			})
			// offset++
		} else {
			output.setUint8(offset, value)
			offset++
		}

		counter++
		if (counter > 4000) done = true
	}
	return new Uint8Array(output.getBuffer())
}

function expand2BPPValues(img: Uint8Array): Uint8Array {
	const colorMap: Record<number, number> = {
		0: 0x000000ff,
		1: 0xffff00ff,
		2: 0xffffffff,
	}

	const data = new Uint8Array(img.length * 4 * 4)

	for (let i = 0; i < img.length; i++) {
		const byte = img[i]!
		const pixel0 = (byte >> 0) & 3
		data.set(
			new Uint8Array(new Uint32Array([colorMap[pixel0] ?? 0xffffffff]).buffer),
			i * 16
		)

		const pixel1 = (byte >> 2) & 3
		data.set(
			new Uint8Array(new Uint32Array([colorMap[pixel1] ?? 0xffffffff]).buffer),
			i * 16 + 4
		)

		const pixel2 = (byte >> 4) & 3
		data.set(
			new Uint8Array(new Uint32Array([colorMap[pixel2] ?? 0xffffffff]).buffer),
			i * 16 + 8
		)

		const pixel3 = (byte >> 6) & 3
		data.set(
			new Uint8Array(new Uint32Array([colorMap[pixel3] ?? 0xffffffff]).buffer),
			i * 16 + 12
		)
	}

	return data
}

// cnt 254
// cur

// 0: "ff" x
// 1: "ff"
// 2: "aa"
// 3: "ff"
// 4: "ff"
// 5: "aa"
// 6: "ff"
// 7: "ff"
// 8: "aa"
// 9: "ff"
// 10: "ff"
// 11: "aa"
// 12: "ff"
// 13: "ff"
// 14: "aa"
// 15: "ff"
// 16: "ff"
// 17: "aa"

// 18: "ff"
// 19: "47" same but 0x47
// 20: "aa"

// 21: "02" just copy paste
// 22: "00" same
// 23: "00"
// 24: "00"
// 25: "80"

// 26: "ff"
// 27: "06"
// 28: "aa"

// 29: "0a"
// 30: "00"
// 31: "ff"
// 32: "04"
// 33: "aa"
// 34: "0a"
// 35: "00"
// 36: "ff"
// 37: "15"
// 38: "aa"
// 39: "00"
