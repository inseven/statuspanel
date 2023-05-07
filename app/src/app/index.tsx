import { ScrollView, Text, TouchableOpacity, View } from "react-native"
import { Link, Stack } from "expo-router"
import Ionicons from "@expo/vector-icons/Ionicons"
import { useAtom } from "jotai"
import { tintColorAtom } from "../tintColorAtom"

export default function Page() {
	const [tintColor] = useAtom(tintColorAtom)

	return (
		<>
			<Stack.Screen
				options={{
					title: "My hme",
					headerLargeTitle: true,
					headerLeft: () => (
						<Link href="/settings" asChild>
							<TouchableOpacity>
								<Ionicons name="cog" size={32} color={tintColor} />
							</TouchableOpacity>
						</Link>
					),
				}}
			/>
			<ScrollView contentInsetAdjustmentBehavior="automatic">
				<Text>Statuspanel</Text>
				<Text>Statuspanel</Text>
				<Text>Statuspanel</Text>
				<Text>Statuspanel</Text>
				<Text>Statuspanel</Text>
				<Text>Statuspanel</Text>
				<Text>Statuspanel</Text>
				<Text>Statuspanel</Text>
				<Text>Statuspanel</Text>
				<Text>Statuspanel</Text>
				<Text>Statuspanel</Text>
				<Text>Statuspanel</Text>
				<Text>Statuspanel</Text>
				<Text>Statuspanel</Text>
				<Text>Statuspanel</Text>
				<Text>Statuspanel</Text>
				<Text>Statuspanel</Text>
				<Text>Statuspanel</Text>
				<Text>Statuspanel</Text>
				<Text>Statuspanel</Text>
				<Text>Statuspanel</Text>
				<Text>Statuspanel</Text>
				<Text>Statuspanel</Text>
				<Text>Statuspanel</Text>
				<Text>Statuspanel</Text>
				<Text>Statuspanel</Text>
				<Text>Statuspanel</Text>
				<Text>Statuspanel</Text>
				<Text>Statuspanel</Text>
				<Text>Statuspanel</Text>
				<Text>Statuspanel</Text>
				<Text>Statuspanel</Text>
				<Text>Statuspanel</Text>
				<Text>Statuspanel</Text>
				<Text>Statuspanel</Text>
				<Text>Statuspanel</Text>
			</ScrollView>
		</>
	)
}
