/** @type {import("prettier").Config} */
const config = {
	plugins: [require.resolve("prettier-plugin-tailwindcss")],
	useTabs: true,
	semi: false,
}

module.exports = config
