import { atomWithStorage, createJSONStorage } from "jotai/utils"
import AsyncStorage from "@react-native-async-storage/async-storage"

const atomStorage = createJSONStorage<any>(() => AsyncStorage)

export const atomWithAsyncStorage = <T>(key: string, initialValue: T) =>
	atomWithStorage<T>(key, initialValue, atomStorage)
