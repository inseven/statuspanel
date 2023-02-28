import { type NextPage } from "next"
import { useSodium } from "../utils/sodium"
import QRCode from "react-qr-code"
import { StreamDataView } from "stream-data-view"
import { forEach, pipe, range, reverse } from "remeda"

const Home: NextPage = () => {
	const sodium = useSodium()

	if (sodium === undefined) {
		return <p>waiting for sodium..</p>
	}

	const keypair = sodium.crypto_box_keypair()
	const pubBase64 = sodium.to_base64(
		keypair.publicKey,
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

		const images = []
		ranges.forEach(([start, end]) => {
			const length = end - start
			const imageData = data.getBytes(start, length)
		})
	}

	return (
		<main className="flex min-h-screen flex-col items-center justify-center bg-gradient-to-b from-[#2e026d] to-[#15162c]">
			<div className="container flex flex-col items-center justify-center gap-12 px-4 py-16 ">
				<p className="text-white">{url}</p>
				<QRCode value={url} />
				<button onClick={() => void update()}>update</button>
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
