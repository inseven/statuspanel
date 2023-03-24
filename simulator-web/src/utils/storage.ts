import { useLocalStorage } from "react-use"

const bufferToString = (buf: Uint8Array) => {
  return String.fromCharCode(...new Uint8Array(buf))
}

const stringToUint8Array = (str: string) => {
  const buf = new ArrayBuffer(str.length)
  const bufView = new Uint8Array(buf)
  for (let i = 0, strLen = str.length; i < strLen; i++) {
    bufView[i] = str.charCodeAt(i)
  }
  return bufView
}

export const useLocalStorageUint8Array = (key: string, initialValue: Uint8Array | undefined) =>
  useLocalStorage<Uint8Array | undefined>(key, initialValue, {
    raw: false,
    serializer: (kpp) => (kpp === undefined ? "undef" : bufferToString(kpp)),
    deserializer: (kpp) => (kpp === "undef" ? undefined : stringToUint8Array(kpp)),
  })
