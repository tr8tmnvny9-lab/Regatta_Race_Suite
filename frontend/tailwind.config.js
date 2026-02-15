/** @type {import('tailwindcss').Config} */
export default {
    content: [
        "./index.html",
        "./src/**/*.{js,ts,jsx,tsx}",
    ],
    theme: {
        extend: {
            colors: {
                'regatta-dark': '#0f172a',    // Slate 900
                'regatta-panel': '#1e293b',   // Slate 800
                'accent-blue': '#3b82f6',     // Blue 500
                'accent-cyan': '#06b6d4',     // Cyan 500
                'accent-red': '#ef4444',      // Red 500
                'accent-green': '#22c55e',    // Green 500
            },
            fontFamily: {
                sans: ['"Inter"', 'sans-serif'],
                mono: ['"JetBrains Mono"', 'monospace'],
            },
            boxShadow: {
                'glow-blue': '0 0 20px rgba(59, 130, 246, 0.5)',
                'glow-red': '0 0 20px rgba(239, 68, 68, 0.5)',
            }
        },
    },
    plugins: [],
}
