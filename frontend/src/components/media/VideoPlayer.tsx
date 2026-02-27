import React from 'react';
import { VideoTrack } from '@livekit/components-react';
import { Track, Participant } from 'livekit-client';
import { CameraOff } from 'lucide-react';

interface VideoPlayerProps {
    participant?: Participant;
    source?: Track.Source;
    fallbackName: string;
    isLive?: boolean;
    debugColor?: string;
}

export default function VideoPlayer({ participant, source = Track.Source.Camera, fallbackName, isLive, debugColor }: VideoPlayerProps) {

    // If we have a real LiveKit participant and they are streaming video:
    const hasVideo = participant?.isCameraEnabled;

    return (
        <div className={`relative w-full h-full flex flex-col items-center justify-center rounded-2xl overflow-hidden bg-[#0A0A0C] border border-white/5 ${debugColor ? `shadow-[inset_0_0_100px_rgba(${debugColor},0.2)]` : ''}`}>

            {hasVideo && participant ? (
                <VideoTrack
                    participant={participant}
                    source={source}
                    className="absolute inset-0 w-full h-full object-cover"
                />
            ) : (
                <div className="flex flex-col items-center justify-center text-white/20">
                    <CameraOff size={48} className="mb-4 opacity-50" />
                    <span className="font-bold tracking-widest uppercase text-sm">{fallbackName}</span>
                    <span className="text-[10px] uppercase tracking-widest mt-2">{participant ? 'Stream Paused' : 'Awaiting Connection'}</span>
                </div>
            )}

            {/* Cinematic Overlays */}
            <div className="absolute top-4 left-4 flex gap-2 z-10">
                {isLive && (
                    <div className="px-2.5 py-1 bg-red-600 rounded flex items-center gap-1.5 text-[10px] font-black uppercase tracking-widest text-white shadow-[0_0_10px_rgba(220,38,38,0.5)]">
                        <div className="w-1.5 h-1.5 bg-white rounded-full animate-pulse" />
                        LIVE
                    </div>
                )}
                <div className="px-2.5 py-1 bg-black/60 backdrop-blur-md border border-white/10 rounded text-[10px] font-bold uppercase text-white tracking-widest shadow-lg">
                    {fallbackName}
                </div>
            </div>

            {/* SRS Score Debug (Optional) */}
            <div className="absolute bottom-4 left-4 px-2.5 py-1 bg-black/60 backdrop-blur-md border border-white/10 rounded text-[10px] font-bold uppercase text-gray-400 tracking-widest shadow-lg">
                SRS: {(Math.random() * 100).toFixed(1)}
            </div>
        </div>
    );
}
