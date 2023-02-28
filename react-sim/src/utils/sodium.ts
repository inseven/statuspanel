import _sodium from "libsodium-wrappers"
import { useEffect, useRef, useState } from "react"

const libsodium = async () => {
	// eslint-disable-next-line @typescript-eslint/no-unsafe-member-access
	await _sodium.ready
	// eslint-disable-next-line @typescript-eslint/no-unsafe-return
	return _sodium
}

export const useSodium = (): undefined | typeof _sodium => {
	const [ready, setReady] = useState(false)
	const so = useRef<typeof _sodium>()

	useEffect(() => {
		const doIt = async () => {
			await libsodium()
			setReady(true)

			so.current = _sodium
		}
		void doIt()
	}, [])

	if (!ready) return undefined

	return so.current
}
