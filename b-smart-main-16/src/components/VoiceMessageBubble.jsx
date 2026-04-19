import React, { useMemo, useRef, useState } from 'react';

const formatDuration = (seconds) => {
  const safeSeconds = Math.max(0, Math.floor(seconds || 0));
  return `${Math.floor(safeSeconds / 60)}:${String(safeSeconds % 60).padStart(2, '0')}`;
};

const WAVEFORM_BARS = [8, 11, 16, 12, 18, 10, 20, 14, 9, 17, 12, 15, 19, 11, 13, 18, 10, 16, 12, 20];

export default function VoiceMessageBubble({ message, isMine }) {
  const [isPlaying, setIsPlaying] = useState(false);
  const [currentTime, setCurrentTime] = useState(0);
  const [durationFromMetadata, setDurationFromMetadata] = useState(0);
  const audioRef = useRef(null);

  const totalDuration = message.audioDuration || durationFromMetadata || 0;
  const progress = totalDuration > 0 ? Math.min(currentTime / totalDuration, 1) : 0;

  const bubbleClass = isMine
    ? 'bg-[#5b5ef4] text-white shadow-[0_10px_26px_rgba(91,94,244,0.28)]'
    : 'bg-[#202020] text-white border border-white/6';

  const bars = useMemo(() => WAVEFORM_BARS, []);

  const togglePlayback = async () => {
    if (!audioRef.current) return;
    if (isPlaying) {
      audioRef.current.pause();
      setIsPlaying(false);
      return;
    }
    try {
      await audioRef.current.play();
      setIsPlaying(true);
    } catch (error) {
      console.error('Voice message playback failed:', error);
    }
  };

  const handleSeek = (event) => {
    if (!audioRef.current || !totalDuration) return;
    const rect = event.currentTarget.getBoundingClientRect();
    const ratio = Math.min(Math.max((event.clientX - rect.left) / rect.width, 0), 1);
    const nextTime = ratio * totalDuration;
    audioRef.current.currentTime = nextTime;
    setCurrentTime(nextTime);
  };

  return (
    <div className={`min-w-[220px] max-w-[280px] rounded-[22px] px-3 py-2.5 ${bubbleClass}`}>
      <audio
        ref={audioRef}
        src={message.mediaUrl}
        preload="metadata"
        onLoadedMetadata={() => {
          const metadataDuration = audioRef.current?.duration || 0;
          if (metadataDuration > 0) setDurationFromMetadata(metadataDuration);
        }}
        onTimeUpdate={() => setCurrentTime(audioRef.current?.currentTime || 0)}
        onEnded={() => {
          setIsPlaying(false);
          setCurrentTime(0);
        }}
        onPause={() => setIsPlaying(false)}
        onPlay={() => setIsPlaying(true)}
      />

      <div className="flex items-center gap-3">
        <button
          type="button"
          onClick={togglePlayback}
          className="flex h-9 w-9 flex-shrink-0 items-center justify-center rounded-full bg-white/18 text-white hover:bg-white/28"
        >
          {isPlaying ? (
            <svg xmlns="http://www.w3.org/2000/svg" className="h-4 w-4" fill="currentColor" viewBox="0 0 24 24"><path d="M6 19h4V5H6v14zm8-14v14h4V5h-4z" /></svg>
          ) : (
            <svg xmlns="http://www.w3.org/2000/svg" className="ml-0.5 h-4 w-4" fill="currentColor" viewBox="0 0 24 24"><path d="M8 5v14l11-7z" /></svg>
          )}
        </button>

        <div className="min-w-0 flex-1">
          <button
            type="button"
            onClick={handleSeek}
            className="flex w-full items-end gap-[3px]"
          >
            {bars.map((height, index) => {
              const active = index / bars.length <= progress;
              return (
                <div
                  key={index}
                  className={`w-[3px] rounded-full transition-colors duration-150 ${active ? 'bg-white' : 'bg-white/30'}`}
                  style={{ height }}
                />
              );
            })}
          </button>
          <div className="mt-1.5 h-[2px] w-full overflow-hidden rounded-full bg-white/12">
            <div
              className="h-full rounded-full bg-white transition-all duration-150"
              style={{ width: `${progress * 100}%` }}
            />
          </div>
        </div>

        <span className="min-w-[36px] flex-shrink-0 text-right font-mono text-[11px] text-white/82">
          {formatDuration(isPlaying ? currentTime : totalDuration)}
        </span>
      </div>
    </div>
  );
}
