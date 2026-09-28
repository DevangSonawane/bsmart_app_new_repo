import React, { useEffect, useMemo, useRef, useState } from 'react';

const MAX_DURATION_SECONDS = 300;

const formatDuration = (seconds) => {
  const safeSeconds = Math.max(0, Math.floor(seconds || 0));
  const minutes = Math.floor(safeSeconds / 60);
  return `${minutes}:${String(safeSeconds % 60).padStart(2, '0')}`;
};

const WAVEFORM_BARS = [8, 11, 16, 12, 18, 10, 20, 14, 9, 17, 12, 15, 19, 11, 13, 18, 10, 16, 12, 20, 13, 9, 15, 18];

const RecorderWaveform = ({ progress = 0, animated = false }) => (
  <div className="flex flex-1 items-center gap-[3px]">
    {WAVEFORM_BARS.map((height, index) => {
      const active = index / WAVEFORM_BARS.length <= progress;
      return (
        <div
          key={index}
          className={`w-[3px] rounded-full transition-all duration-200 ${active ? 'bg-white' : 'bg-white/30'} ${animated && active ? 'animate-pulse' : ''}`}
          style={{ height }}
        />
      );
    })}
  </div>
);

export default function VoiceRecorder({ onSend, onCancel, onStateChange, disabled }) {
  const [state, setState] = useState('idle');
  const [duration, setDuration] = useState(0);
  const [isPlaying, setIsPlaying] = useState(false);
  const [playbackTime, setPlaybackTime] = useState(0);
  const [audioBlobUrl, setAudioBlobUrl] = useState('');
  const [audioBlob, setAudioBlob] = useState(null);

  const mediaRecorderRef = useRef(null);
  const chunksRef = useRef([]);
  const tickIntervalRef = useRef(null);
  const recordStartTimeRef = useRef(0);
  const audioRef = useRef(null);
  const streamRef = useRef(null);
  const cancelledRef = useRef(false);

  const progress = useMemo(
    () => Math.min(duration / MAX_DURATION_SECONDS, 1),
    [duration]
  );

  const cleanupStream = () => {
    if (streamRef.current) {
      streamRef.current.getTracks().forEach((track) => track.stop());
      streamRef.current = null;
    }
  };

  const clearTicker = () => {
    if (tickIntervalRef.current) {
      clearInterval(tickIntervalRef.current);
      tickIntervalRef.current = null;
    }
  };

  useEffect(() => {
    onStateChange?.(state !== 'idle');
  }, [onStateChange, state]);

  useEffect(() => () => {
    clearTicker();
    cleanupStream();
    if (audioBlobUrl) URL.revokeObjectURL(audioBlobUrl);
  }, [audioBlobUrl]);

  const resetRecorder = ({ notifyCancel = false } = {}) => {
    clearTicker();
    cleanupStream();
    if (audioRef.current) {
      audioRef.current.pause();
      audioRef.current.currentTime = 0;
    }
    if (audioBlobUrl) URL.revokeObjectURL(audioBlobUrl);
    mediaRecorderRef.current = null;
    chunksRef.current = [];
    cancelledRef.current = false;
    setAudioBlob(null);
    setAudioBlobUrl('');
    setDuration(0);
    setPlaybackTime(0);
    setIsPlaying(false);
    setState('idle');
    if (notifyCancel) onCancel?.();
  };

  const stopRecording = () => {
    clearTicker();
    const recorder = mediaRecorderRef.current;
    if (recorder && recorder.state !== 'inactive') {
      recorder.stop();
    }
  };

  const cancelRecording = () => {
    cancelledRef.current = true;
    const recorder = mediaRecorderRef.current;
    clearTicker();
    if (audioRef.current) {
      audioRef.current.pause();
    }
    if (recorder && recorder.state !== 'inactive') {
      recorder.stop();
    } else {
      resetRecorder({ notifyCancel: true });
    }
  };

  const startRecording = async () => {
    if (disabled) return;
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      streamRef.current = stream;
      chunksRef.current = [];
      cancelledRef.current = false;

      const mimeType = MediaRecorder.isTypeSupported('audio/webm;codecs=opus')
        ? 'audio/webm;codecs=opus'
        : 'audio/webm';

      const recorder = new MediaRecorder(stream, { mimeType });
      mediaRecorderRef.current = recorder;

      recorder.ondataavailable = (event) => {
        if (event.data.size > 0) chunksRef.current.push(event.data);
      };

      recorder.onstop = () => {
        cleanupStream();
        if (cancelledRef.current) {
          resetRecorder({ notifyCancel: true });
          return;
        }

        const finalDuration = Math.max(
          1,
          Math.round((Date.now() - recordStartTimeRef.current) / 1000)
        );
        const blob = new Blob(chunksRef.current, { type: 'audio/webm' });
        const url = URL.createObjectURL(blob);
        setAudioBlob(blob);
        setAudioBlobUrl(url);
        setDuration(finalDuration);
        setPlaybackTime(0);
        setIsPlaying(false);
        setState('preview');
      };

      recorder.start(250);
      recordStartTimeRef.current = Date.now();
      setDuration(0);
      setPlaybackTime(0);
      setState('recording');

      tickIntervalRef.current = setInterval(() => {
        const elapsedSeconds = Math.floor((Date.now() - recordStartTimeRef.current) / 1000);
        setDuration(elapsedSeconds);
        if (elapsedSeconds >= MAX_DURATION_SECONDS) {
          stopRecording();
        }
      }, 250);
    } catch (error) {
      console.error('Microphone access denied:', error);
      alert('Microphone permission is required to send voice messages.');
    }
  };

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
      console.error('Audio preview playback failed:', error);
    }
  };

  const handlePreviewSeek = (event) => {
    if (!audioRef.current || !duration) return;
    const rect = event.currentTarget.getBoundingClientRect();
    const ratio = Math.min(Math.max((event.clientX - rect.left) / rect.width, 0), 1);
    const nextTime = ratio * duration;
    audioRef.current.currentTime = nextTime;
    setPlaybackTime(nextTime);
  };

  const handleSend = async () => {
    if (!audioBlob) return;
    await onSend(audioBlob, duration);
    resetRecorder();
  };

  if (state === 'idle') {
    return (
      <button
        type="button"
        onClick={startRecording}
        disabled={disabled}
        className="rounded-full p-2 text-gray-500 transition-colors hover:bg-gray-100 hover:text-gray-900 dark:text-gray-400 dark:hover:bg-white/5 dark:hover:text-white disabled:opacity-40"
        title="Send voice message"
      >
        <svg xmlns="http://www.w3.org/2000/svg" className="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.8}>
          <path strokeLinecap="round" strokeLinejoin="round" d="M12 1a3 3 0 0 0-3 3v8a3 3 0 0 0 6 0V4a3 3 0 0 0-3-3z" />
          <path strokeLinecap="round" strokeLinejoin="round" d="M19 10a7 7 0 0 1-14 0M12 19v4M8 23h8" />
        </svg>
      </button>
    );
  }

  if (state === 'recording') {
    return (
      <div className="relative flex w-full items-center gap-3 overflow-hidden rounded-[30px] border border-white/10 bg-[linear-gradient(135deg,#17181c_0%,#20222b_52%,#272b38_100%)] px-3 py-3 text-white shadow-[0_16px_40px_rgba(0,0,0,0.34)]">
        <div className="pointer-events-none absolute inset-0 bg-[radial-gradient(circle_at_left,rgba(250,92,92,0.14),transparent_26%),radial-gradient(circle_at_right,rgba(99,102,241,0.16),transparent_30%)]" />
        <div className="pointer-events-none absolute inset-y-0 left-[76px] w-px bg-white/8" />

        <button
          type="button"
          onClick={cancelRecording}
          className="relative z-10 flex h-8 w-8 flex-shrink-0 items-center justify-center rounded-full border border-white/12 bg-white/8 text-white/88 transition hover:bg-white/14"
        >
          <svg xmlns="http://www.w3.org/2000/svg" className="h-3.5 w-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.3}>
            <path strokeLinecap="round" strokeLinejoin="round" d="M6 18L18 6M6 6l12 12" />
          </svg>
        </button>

        <div className="relative z-10 flex min-w-0 flex-1 items-center gap-4">
          <div className="flex min-w-[86px] flex-col justify-center">
            <span className="text-[9px] font-semibold uppercase tracking-[0.28em] text-white/45">
              Recording
            </span>
            <div className="mt-1 flex items-center gap-2">
              <div className="h-2.5 w-2.5 flex-shrink-0 rounded-full bg-[#ff6b6b] shadow-[0_0_0_4px_rgba(255,107,107,0.18)] animate-pulse" />
              <span className="font-mono text-sm font-semibold tracking-[0.22em] text-white">
                {formatDuration(duration)}
              </span>
            </div>
          </div>

          <div className="min-w-0 flex-1">
            
            <div className="h-[4px] overflow-hidden rounded-full bg-white/10">
              <div
                className="h-full rounded-full bg-[linear-gradient(90deg,#ff7b72_0%,#8b8fff_100%)] transition-all duration-200"
                style={{ width: `${progress * 100}%` }}
              />
            </div>
          </div>
        </div>

        <button
          type="button"
          onClick={stopRecording}
          className="relative z-10 flex h-11 w-11 flex-shrink-0 items-center justify-center rounded-full bg-white text-[#202330] shadow-[0_10px_20px_rgba(255,255,255,0.16)] transition hover:scale-[1.03] hover:bg-white/92"
        >
          <div className="h-3.5 w-3.5 rounded-[4px] bg-current" />
        </button>
      </div>
    );
  }

  return (
    <div className="flex w-full items-center gap-2">
      {audioBlobUrl ? (
        <audio
          ref={audioRef}
          src={audioBlobUrl}
          onTimeUpdate={() => setPlaybackTime(audioRef.current?.currentTime || 0)}
          onEnded={() => {
            setIsPlaying(false);
            setPlaybackTime(0);
          }}
        />
      ) : null}

      <button
        type="button"
        onClick={cancelRecording}
        className="flex h-9 w-9 flex-shrink-0 items-center justify-center rounded-full border border-white/10 bg-[#161616] text-white/70 hover:text-white hover:bg-[#1d1d1d]"
      >
        <svg xmlns="http://www.w3.org/2000/svg" className="h-4.5 w-4.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.1}>
          <path strokeLinecap="round" strokeLinejoin="round" d="M6 18L18 6M6 6l12 12" />
        </svg>
      </button>

      <div className="flex flex-1 items-center gap-3 rounded-[24px] bg-[#5b5ef4] px-3 py-2.5 shadow-[0_10px_30px_rgba(91,94,244,0.28)]">
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

        <button
          type="button"
          onClick={handlePreviewSeek}
          className="flex min-w-0 flex-1 items-center gap-[3px]"
        >
          <RecorderWaveform
            progress={duration > 0 ? Math.min((isPlaying ? playbackTime : 0) / duration, 1) : 0}
            animated={isPlaying}
          />
        </button>

        <span className="min-w-[38px] flex-shrink-0 font-mono text-xs font-semibold tracking-[0.12em] text-white/92">
          {formatDuration(isPlaying ? playbackTime : duration)}
        </span>
      </div>

      <button
        type="button"
        onClick={handleSend}
        className="flex h-10 w-10 flex-shrink-0 items-center justify-center rounded-full bg-[#5b5ef4] text-white shadow-[0_10px_24px_rgba(91,94,244,0.32)] hover:bg-[#4c4fe2]"
      >
        <svg xmlns="http://www.w3.org/2000/svg" className="ml-0.5 h-4.5 w-4.5" fill="currentColor" viewBox="0 0 24 24">
          <path d="M2.01 21L23 12 2.01 3 2 10l15 2-15 2z" />
        </svg>
      </button>
    </div>
  );
}
