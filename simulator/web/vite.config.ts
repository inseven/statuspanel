import { defineConfig } from "vite"
import react from "@vitejs/plugin-react-swc"
import WindiCSS from "vite-plugin-windicss"

// https://vitejs.dev/config/
export default defineConfig({
  base: "",
  plugins: [react()],
})
