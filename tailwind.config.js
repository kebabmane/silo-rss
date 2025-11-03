/** @type {import('tailwindcss').Config} */
export default {
  darkMode: 'class',
  content: [
    './app/views/**/*.{erb,html}',
    './app/helpers/**/*.rb',
    './app/assets/javascripts/**/*.js',
    './app/javascript/**/*.{js,jsx,ts,tsx}',
  ],
  theme: {
    extend: {
      colors: {
        // Add any custom colors here if needed
      },
    },
  },
  plugins: [],
}
