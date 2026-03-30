/** @type {import('tailwindcss').Config} */
export default {
  darkMode: 'class',
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        'insta-pink': '#d62976',
        'insta-orange': '#fa7e1e',
        'insta-purple': '#962fbf',
        'insta-yellow': '#feda75',
      },
      backgroundImage: {
        'insta-gradient': 'linear-gradient(45deg, #f09433 0%, #e6683c 25%, #dc2743 50%, #cc2366 75%, #bc1888 100%)',
      }
    },
  },
  plugins: [],
}
