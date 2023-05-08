import { Button, ScrollView } from "react-native"
import { Stack, useNavigation, useRouter } from "expo-router"
import { useAtom } from "jotai"
import { Settings } from "../components/Settings"
import { tintColorAtom } from "../atoms/tintColorAtom"
import { showDebugInfoAtom } from "../atoms/showDebugInfo"

export default function Page() {
	const [tintColor] = useAtom(tintColorAtom)
	const [showDebugInfo, setShowDebugInfo] = useAtom(showDebugInfoAtom)
	const nav = useNavigation()
	const router = useRouter()

	return (
		<>
			<Stack.Screen
				options={{
					title: "Settings",
					headerTransparent: true,
					headerBlurEffect: "systemMaterial",
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
					<Settings.Section title="Debug">
						<Settings.Item
							label="Show Debug Information"
							value={showDebugInfo}
							setValue={setShowDebugInfo}
						/>
					</Settings.Section>
					<Settings.Section>
						<Settings.Item
							label="About StatusPanel..."
							onPress={() => router.push("/about")}
						/>
					</Settings.Section>
				</Settings>
			</ScrollView>
		</>
	)
}
