import { Button, ScrollView } from "react-native"
import { Stack, useNavigation } from "expo-router"
import { useAtom } from "jotai"
import { tintColorAtom } from "../atoms/tintColorAtom"

export default function Page() {
	const [tintColor] = useAtom(tintColorAtom)
	const nav = useNavigation()

	return (
		<>
			<Stack.Screen
				options={{
					title: "About",
					// headerTransparent: true,
					// headerBlurEffect: "systemUltraThinMaterial",
					headerRight: () => (
						<Button
							title="Done"
							onPress={() => nav.goBack()}
							color={tintColor}
						/>
					),
				}}
			/>
			<ScrollView contentInsetAdjustmentBehavior="automatic"></ScrollView>
		</>
	)
}
