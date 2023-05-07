import { useAtom } from "jotai"
import { tintColorAtom } from "../tintColorAtom"
import { View, Text } from "react-native"

export const Settings = ({ children }: Children) => {
	return <View className="mx-3">{children}</View>
}

interface SettingsSectionProps {
	title?: string
}

const Section = ({ title, children }: SettingsSectionProps & Children) => {
	return (
		<View>
			<Text className="mx-2 mb-1 text-xs text-gray-500">
				{title.toUpperCase()}
			</Text>
			{children}
		</View>
	)
}
Settings.Section = Section

interface SettingsItemProps {
	label: string
	value?: string
}

const Item = ({ label, value }: SettingsItemProps) => {
	return (
		<View className="flex-row rounded-md bg-white p-3">
			<Text>{label}</Text>
			<Text>{value}</Text>
		</View>
	)
}
Settings.Item = Item
