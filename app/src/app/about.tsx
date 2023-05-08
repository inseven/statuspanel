import { Button, Linking, ScrollView } from "react-native"
import { Stack, useNavigation } from "expo-router"
import { useAtom } from "jotai"
import { tintColorAtom } from "../atoms/tintColorAtom"
import { Settings } from "../components/Settings"

export default function Page() {
	const [tintColor] = useAtom(tintColorAtom)
	const nav = useNavigation()

	return (
		<>
			<Stack.Screen
				options={{
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
					<Settings.Section title="Developerts">
						<Settings.Item
							label="Jason Morley"
							onPress={() => Linking.openURL("https://jbmorley.co.uk")}
							linkIcon
						/>
						<Settings.Item
							label="Tom Sutcliffe"
							onPress={() => Linking.openURL("https://github.com/tomsci")}
							linkIcon
						/>
					</Settings.Section>

					<Settings.Section title="Thanks">
						<Settings.Item label="Lukas Fittl" />
						<Settings.Item
							label="Pavlos Vinieratos"
							onPress={() => Linking.openURL("https://github.com/pvinis")}
							linkIcon
						/>
						<Settings.Item label="Sarah Barbour" />
					</Settings.Section>
				</Settings>
			</ScrollView>
		</>
	)
}
