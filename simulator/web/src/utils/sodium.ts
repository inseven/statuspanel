import _sodium from "libsodium-wrappers"
import { useEffect, useRef, useState } from "react"

const libsodium = async () => {
  await _sodium.ready
  return _sodium
}

export const useSodium = (): undefined | typeof _sodium => {
  const [ready, setReady] = useState(false)
  const sod = useRef<typeof _sodium>()

  useEffect(() => {
    const doIt = async () => {
      await libsodium()
      setReady(true)
      sod.current = _sodium
    }
    void doIt()
  }, [])

  if (!ready) return undefined

  return sod.current
}
