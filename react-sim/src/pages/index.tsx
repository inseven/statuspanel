import { type NextPage } from "next"
import Link from "next/link"
import { useSodium } from "../utils/sodium"
import QRCode from "react-qr-code"

const Home: NextPage = () => {
	const sodium = useSodium()

	if (sodium === undefined) {
		return <p>waiting for sodium..</p>
	}

	const keypair = sodium.crypto_box_keypair()

	return (
		<main className="flex min-h-screen flex-col items-center justify-center bg-gradient-to-b from-[#2e026d] to-[#15162c]">
			<div className="container flex flex-col items-center justify-center gap-12 px-4 py-16 ">
				<h1 className="text-5xl font-extrabold tracking-tight text-white sm:text-[5rem]">
					ready {sodium !== undefined ? "yes" : "no"}
					keypair {keypair.publicKey} {keypair.privateKey}
				</h1>
				<QRCode value="hi" />
				<div className="grid grid-cols-1 gap-4 sm:grid-cols-2 md:gap-8">
					<Link
						className="flex max-w-xs flex-col gap-4 rounded-xl bg-white/10 p-4 text-white hover:bg-white/20"
						href="https://create.t3.gg/en/usage/first-steps"
						target="_blank"
					>
						<h3 className="text-2xl font-bold">First Steps →</h3>
					</Link>
					<Link
						className="flex max-w-xs flex-col gap-4 rounded-xl bg-white/10 p-4 text-white hover:bg-white/20"
						href="https://create.t3.gg/en/introduction"
						target="_blank"
					>
						<h3 className="text-2xl font-bold">Documentation →</h3>
						<div className="text-lg">
							Learn more about Create T3 App, the libraries it uses, and how to
							deploy it.
						</div>
					</Link>
				</div>
			</div>
		</main>
	)
}

export default Home
