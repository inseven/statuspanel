// normally just the following is needed, but i want a custom root path, but i want a custom root path
// import "expo-router/entry"

import "@expo/metro-runtime"
import { ExpoRoot } from "expo-router"
import Head from "expo-router/head"
import { renderRootComponent } from "expo-router/src/renderRootComponent"

const ctx = require.context(
	"./src/app",
	true,
	/.*/,
	process.env.EXPO_ROUTER_IMPORT_MODE
)

export const App = () => (
	<Head.Provider>
		<ExpoRoot context={ctx} />
	</Head.Provider>
)

renderRootComponent(App)
