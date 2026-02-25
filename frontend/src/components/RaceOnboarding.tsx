import { useState } from 'react'
import { QRCodeSVG } from 'qrcode.react'
import { motion, AnimatePresence } from 'framer-motion'
import { useMemo } from 'react'
import { Copy, Check, Smartphone } from 'lucide-react'

export default function RaceOnboarding() {
    const [copied, setCopied] = useState(false)

    // Generate dynamic QR code matching React Router expectations
    const boatId = useMemo(() => `SWE-${Math.floor(Math.random() * 9000) + 1000}`, [])
    const inviteUrl = `${window.location.origin}/?view=tracker&boatId=${boatId}&token=tracker123`
    const displayUrl = `${window.location.host}/?view=tracker...`

    const handleCopy = () => {
        navigator.clipboard.writeText(inviteUrl)
        setCopied(true)
        setTimeout(() => setCopied(false), 2000)
    }

    return (
        <div className="flex flex-col items-center gap-6 p-6 text-center">
            <div className="flex items-center gap-3 mb-2">
                <div className="w-10 h-10 rounded-2xl bg-blue-500/20 flex items-center justify-center">
                    <Smartphone size={20} className="text-blue-400" />
                </div>
                <div className="text-left">
                    <h2 className="font-bold text-white text-lg">Sailor QR Onboarding</h2>
                    <p className="text-sm text-white/50">Share this with competitors to join</p>
                </div>
            </div>

            {/* QR Code */}
            <motion.div
                initial={{ opacity: 0, scale: 0.9 }}
                animate={{ opacity: 1, scale: 1 }}
                className="bg-white p-4 rounded-2xl shadow-2xl"
            >
                <QRCodeSVG
                    value={inviteUrl}
                    size={200}
                    bgColor="#ffffff"
                    fgColor="#0a0a0a"
                    level="Q"
                />
            </motion.div>

            {/* URL Display */}
            <div className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-3 flex items-center gap-3">
                <span className="text-white/60 text-xs font-mono truncate flex-1 text-left">{displayUrl}</span>
                <button
                    onClick={handleCopy}
                    className="flex-shrink-0 flex items-center gap-1.5 text-xs font-semibold text-blue-400 hover:text-blue-300 transition-colors"
                >
                    <AnimatePresence mode="wait">
                        {copied ? (
                            <motion.span
                                key="copied"
                                initial={{ opacity: 0, y: -4 }}
                                animate={{ opacity: 1, y: 0 }}
                                exit={{ opacity: 0, y: 4 }}
                                className="flex items-center gap-1 text-green-400"
                            >
                                <Check size={13} /> Copied
                            </motion.span>
                        ) : (
                            <motion.span
                                key="copy"
                                initial={{ opacity: 0, y: -4 }}
                                animate={{ opacity: 1, y: 0 }}
                                exit={{ opacity: 0, y: 4 }}
                                className="flex items-center gap-1"
                            >
                                <Copy size={13} /> Copy
                            </motion.span>
                        )}
                    </AnimatePresence>
                </button>
            </div>

            {/* Instructions */}
            <div className="w-full space-y-2 text-left mt-1">
                {[
                    { step: '1', text: 'Open the Regatta Tracker App on your phone' },
                    { step: '2', text: 'Tap "Scan QR Code" on the home screen' },
                    { step: '3', text: 'Point your camera at the code above' },
                ].map(({ step, text }) => (
                    <div key={step} className="flex items-center gap-3">
                        <span className="w-6 h-6 rounded-full bg-blue-500/20 text-blue-400 text-xs font-bold flex items-center justify-center flex-shrink-0">
                            {step}
                        </span>
                        <span className="text-white/60 text-sm">{text}</span>
                    </div>
                ))}
            </div>
        </div>
    )
}
