import { useAtom } from "jotai"
import { tintColorAtom } from "../tintColorAtom"
import { View, Text } from "react-native"

export const Settings = ({ children }: Children) => {
	return <View>{children}</View>
}

interface SettingsSectionProps {
	title?: string
}

const Section = ({ title, children }: SettingsSectionProps & Children) => {
	return (
		<View>
			<Text style={{ fontSize: 12 }}>{title.toUpperCase()}</Text>
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
		<View>
			<Text>{label}</Text>
			<Text>{value}</Text>
		</View>
	)
}
Settings.Item = Item
