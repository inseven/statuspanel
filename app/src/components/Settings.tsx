import { View, Text, TouchableOpacity, Switch } from "react-native"
import { Wrap } from "./Wrap"
import Ionicons from "@expo/vector-icons/Ionicons"
import { getChildren, getChildrenByType } from "react-nanny"
import { Children, createContext, useContext } from "react"

export const Settings = ({ children }: Children) => {
	return <View className="mx-3">{children}</View>
}

const SectionContext = createContext({ numberOfItems: 0 })

interface SettingsSectionProps {
	title?: string
}

const Section = ({ title, children }: SettingsSectionProps & Children) => {
	return (
		<View className="my-4">
			{title !== undefined && (
				<Text className="mx-2 mb-1 text-xs text-gray-500">
					{title.toUpperCase()}
				</Text>
			)}
			<SectionContext.Provider
				value={{ numberOfItems: Children.count(children) }}
			>
				{children}
			</SectionContext.Provider>
		</View>
	)
}
Settings.Section = Section

interface SettingsItemProps {
	label: string
	value?: boolean | string
	setValue?: (value: boolean) => void
	onPress?: () => void
	linkIcon?: boolean
}

const Item = ({
	label,
	value,
	setValue,
	onPress,
	linkIcon,
}: SettingsItemProps) => {
	const ctx = useContext(SectionContext)

	let valueComp = null
	switch (true) {
		case linkIcon:
			valueComp = <Ionicons name="link" size={20} />
			break
		case value === undefined:
			valueComp = null
			break
		case typeof value === "boolean":
			valueComp = (
				<Switch
					value={value as boolean}
					onValueChange={(v) => setValue(v)}
					className="my-1"
				/>
			)
			break
		default:
			valueComp = <Text className="text-sm text-gray-500">{value}</Text>
			break
	}

	return (
		<Wrap if={onPress !== undefined}>
			<TouchableOpacity onPress={onPress} className="w-full">
				<Wrap.Content>
					<View className="flex flex-row items-center justify-between rounded-lg bg-white px-3">
						<Text className="my-3 text-sm">
							{label}
							{ctx.numberOfItems}
						</Text>
						{valueComp}
					</View>
				</Wrap.Content>
			</TouchableOpacity>
		</Wrap>
	)
}
Settings.Item = Item
