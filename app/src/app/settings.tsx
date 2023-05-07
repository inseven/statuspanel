import { Button, ScrollView, Text, View } from "react-native"
import { Stack, useNavigation } from "expo-router"
import { useAtom } from "jotai"
import { tintColorAtom } from "../tintColorAtom"
import { Settings } from "../components/Settings"

export default function Page() {
	const [tintColor] = useAtom(tintColorAtom)
	const nav = useNavigation()

	return (
		<>
			<Stack.Screen
				options={{
					title: "Settings",
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
			<ScrollView contentInsetAdjustmentBehavior="automatic">
				<Settings>
					<Settings.Section title="Status">
						<Settings.Item label="Last Update" value="17:00" />
					</Settings.Section>
				</Settings>
			</ScrollView>
		</>
	)
}
