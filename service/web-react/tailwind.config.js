/** @type {import('tailwindcss').Config} */
export default {
  content: ["./index.html", "./src/**/*.{js,ts,jsx,tsx}"],
  theme: {
    extend: {
      fontFamily: {
        "wix-madefor-display": ['"Wix Madefor Display"', "sans-serif"],
      },
    },
  },
  plugins: [],
};
