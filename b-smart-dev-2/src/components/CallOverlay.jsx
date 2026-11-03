import { forwardRef, useCallback, useEffect, useImperativeHandle, useRef, useState } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import { Maximize2, Mic, MicOff, Minimize2, Phone, PhoneOff, UserPlus, Video, VideoOff } from 'lucide-react';
import {
  emitCallAccept,
  emitCallEnd,
  emitCallEscalateToGroup,
  emitCallInitiate,
  emitCallReject,
  emitCallTrackPublished,
  initChatSocket,
  removeChatSocketCallbacks,
} from '../socket/chatSocket';
import * as callService from '../services/callService';
import AddCallPeopleModal from './AddCallPeopleModal';
import {
  endCall,
  receiveIncomingCall,
  setCallActive,
  setCallConnecting,
  setCallError,
  startOutgoingCall,
} from '../store/callSlice';
import {
  RING_INTERVAL_MS,
  playRingChime,
  requestNotificationPermission,
  showIncomingCallNotification,
  startTitleFlash,
  stopTitleFlash,
  waitForIceGatheringComplete,
} from '../utils/callMedia';

// Cloudflare Realtime's SFU is reachable via a public STUN-only ICE
// candidate — no TURN needed since the SFU itself is the relay endpoint.
const ICE_SERVERS = [{ urls: 'stun:stun.cloudflare.com:3478' }];

const CallOverlay = forwardRef(({ currentUserId, token }, ref) => {
  const dispatch = useDispatch();
  const call = useSelector((state) => state.call);

  const [isMuted, setIsMuted] = useState(false);
  const [cameraOff, setCameraOff] = useState(false);
  const [elapsedSeconds, setElapsedSeconds] = useState(0);
  const [showAddPeople, setShowAddPeople] = useState(false);

  // Default view is a small draggable widget anchored bottom-right; the user
  // can expand it to the classic full-screen call UI and back at any time.
  const [isFullScreen, setIsFullScreen] = useState(false);
  const [dragOffset, setDragOffset] = useState({ x: 0, y: 0 });
  const [isDragging, setIsDragging] = useState(false);
  const [isWidgetHovered, setIsWidgetHovered] = useState(false);
  const dragStateRef = useRef(null);

  const handleDragMove = useCallback((event) => {
    if (!dragStateRef.current) return;
    if (event.cancelable) event.preventDefault();
    const point = event.touches ? event.touches[0] : event;
    const { startX, startY, originX, originY } = dragStateRef.current;
    setDragOffset({ x: originX + (point.clientX - startX), y: originY + (point.clientY - startY) });
  }, []);

  const handleDragEnd = useCallback(() => {
    dragStateRef.current = null;
    setIsDragging(false);
    window.removeEventListener('mousemove', handleDragMove);
    window.removeEventListener('mouseup', handleDragEnd);
    window.removeEventListener('touchmove', handleDragMove);
    window.removeEventListener('touchend', handleDragEnd);
  }, [handleDragMove]);

  const handleDragStart = useCallback((event) => {
    if (isFullScreen || event.target.closest('button')) return;
    const point = event.touches ? event.touches[0] : event;
    dragStateRef.current = { startX: point.clientX, startY: point.clientY, originX: dragOffset.x, originY: dragOffset.y };
    setIsDragging(true);
    window.addEventListener('mousemove', handleDragMove);
    window.addEventListener('mouseup', handleDragEnd);
    window.addEventListener('touchmove', handleDragMove, { passive: false });
    window.addEventListener('touchend', handleDragEnd);
  }, [isFullScreen, dragOffset, handleDragMove, handleDragEnd]);

  useEffect(() => () => handleDragEnd(), [handleDragEnd]);

  // Re-attach any live media streams after switching between the compact
  // widget and full-screen — their audio/video elements are different DOM
  // nodes, so a fresh element needs its srcObject set again.
  useEffect(() => {
    if (remoteAudioRef.current && remoteStreamsRef.current.audio) {
      remoteAudioRef.current.srcObject = remoteStreamsRef.current.audio;
      remoteAudioRef.current.play().catch(() => {});
    }
    if (remoteVideoRef.current && remoteStreamsRef.current.video) {
      remoteVideoRef.current.srcObject = remoteStreamsRef.current.video;
      remoteVideoRef.current.play().catch(() => {});
    }
    if (localVideoRef.current && localStreamRef.current) {
      localVideoRef.current.srcObject = localStreamRef.current;
    }
  }, [isFullScreen]);

  const pcRef = useRef(null);
  const localStreamRef = useRef(null);
  const remoteAudioRef = useRef(null);
  const remoteVideoRef = useRef(null);
  const localVideoRef = useRef(null);
  // Toggling compact <-> full-screen unmounts/remounts the audio/video
  // elements (they live in two different JSX branches), which would drop
  // srcObject on the old node. Cache the live streams so they can be
  // reattached to whichever element is mounted after the switch.
  const remoteStreamsRef = useRef({ audio: null, video: null });
  const hasPublishedRef = useRef(false);
  const hasPulledRef = useRef(false);
  const callIdRef = useRef(null);
  const timerRef = useRef(null);
  // The socket-callback effect below only (re)registers when token/user
  // change, not per-call — so `call` captured inside those closures would
  // go stale. This ref is kept in sync on every render so
  // beginMediaNegotiation can read the *current* call's callType.
  const callRef = useRef(call);
  useEffect(() => { callRef.current = call; }, [call]);

  const audioCtxRef = useRef(null);
  const ringIntervalRef = useRef(null);

  const getAudioContext = useCallback(() => {
    const AudioContextClass = window.AudioContext || window.webkitAudioContext;
    if (!AudioContextClass) return null;
    if (!audioCtxRef.current) audioCtxRef.current = new AudioContextClass();
    return audioCtxRef.current;
  }, []);

  const startRingtone = useCallback(() => {
    if (ringIntervalRef.current) return;
    const ctx = getAudioContext();
    if (!ctx) return;
    playRingChime(ctx);
    ringIntervalRef.current = setInterval(() => playRingChime(ctx), RING_INTERVAL_MS);
  }, [getAudioContext]);

  const stopRingtone = useCallback(() => {
    if (ringIntervalRef.current) {
      clearInterval(ringIntervalRef.current);
      ringIntervalRef.current = null;
    }
  }, []);

  // Browsers block audio that isn't triggered by a user gesture — an
  // incoming-call ring arrives over the socket, not a click. Silently
  // create/resume the AudioContext on the first interaction anywhere on the
  // page so it's already unlocked by the time a real call rings.
  useEffect(() => {
    const unlock = () => {
      const ctx = getAudioContext();
      if (ctx?.state === 'suspended') ctx.resume().catch(() => {});
    };
    window.addEventListener('pointerdown', unlock, { once: true });
    window.addEventListener('keydown', unlock, { once: true });
    return () => {
      window.removeEventListener('pointerdown', unlock);
      window.removeEventListener('keydown', unlock);
    };
  }, [getAudioContext]);

  // Ask once per app load — lets an incoming call show a system notification
  // if this tab is backgrounded when it rings.
  useEffect(() => { requestNotificationPermission(); }, []);

  useEffect(() => {
    if (call.status === 'incoming-ringing') startRingtone();
    else { stopRingtone(); stopTitleFlash(); }
  }, [call.status, startRingtone, stopRingtone]);

  useEffect(() => () => stopRingtone(), [stopRingtone]);

  const cleanupMedia = useCallback(() => {
    if (pcRef.current) {
      pcRef.current.close();
      pcRef.current = null;
    }
    if (localStreamRef.current) {
      localStreamRef.current.getTracks().forEach((t) => t.stop());
      localStreamRef.current = null;
    }
    if (remoteAudioRef.current) remoteAudioRef.current.srcObject = null;
    if (remoteVideoRef.current) remoteVideoRef.current.srcObject = null;
    if (localVideoRef.current) localVideoRef.current.srcObject = null;
    remoteStreamsRef.current = { audio: null, video: null };
    hasPublishedRef.current = false;
    hasPulledRef.current = false;
    if (timerRef.current) {
      clearInterval(timerRef.current);
      timerRef.current = null;
    }
    setElapsedSeconds(0);
    setIsMuted(false);
    setCameraOff(false);
  }, []);

  const endActiveCall = useCallback((reason) => {
    if (callIdRef.current) emitCallEnd(callIdRef.current, reason);
    cleanupMedia();
    dispatch(endCall());
  }, [cleanupMedia, dispatch]);

  // ── WebRTC: publish my track(s), then wait to be told the peer has too ────
  const beginMediaNegotiation = useCallback(async (callId) => {
    const isVideo = callRef.current?.callType === 'video';
    try {
      const stream = await navigator.mediaDevices.getUserMedia(isVideo ? { audio: true, video: true } : { audio: true });
      localStreamRef.current = stream;
      if (isVideo && localVideoRef.current) localVideoRef.current.srcObject = stream;

      const pc = new RTCPeerConnection({ iceServers: ICE_SERVERS });
      pcRef.current = pc;
      pc.ontrack = (event) => {
        console.log(`[Call] ontrack fired — remote ${event.track.kind} received`, event.streams[0]);
        remoteStreamsRef.current[event.track.kind] = event.streams[0];
        const sink = event.track.kind === 'video' ? remoteVideoRef.current : remoteAudioRef.current;
        if (sink) {
          sink.srcObject = event.streams[0];
          sink.play().catch((e) => console.error(`[Call] ${event.track.kind}.play() failed:`, e));
        }
        dispatch(setCallActive());
        if (!timerRef.current) {
          timerRef.current = setInterval(() => setElapsedSeconds((s) => s + 1), 1000);
        }
      };
      pc.oniceconnectionstatechange = () => console.log('[Call] iceConnectionState ->', pc.iceConnectionState);
      pc.onconnectionstatechange = () => console.log('[Call] connectionState ->', pc.connectionState);

      stream.getTracks().forEach((track) => pc.addTrack(track, stream));
      console.log('[Call] got local stream, tracks:', stream.getTracks().map((t) => t.kind));

      const offer = await pc.createOffer();
      await pc.setLocalDescription(offer);
      console.log('[Call] local offer created, gathering ICE…');
      await waitForIceGatheringComplete(pc);
      console.log('[Call] ICE gathering complete, iceGatheringState =', pc.iceGatheringState);

      const tracks = pc.getTransceivers()
        .filter((t) => t.sender?.track)
        .map((t) => ({ mid: t.mid, kind: t.sender.track.kind }));
      console.log('[Call] publishing tracks =', tracks, 'callId =', callId);
      const { sdpAnswer } = await callService.publishTrack(callId, pc.localDescription.sdp, tracks);
      if (!sdpAnswer) throw new Error('No answer from media server');
      await pc.setRemoteDescription({ type: 'answer', sdp: sdpAnswer });
      console.log('[Call] publish succeeded, remote description set');

      hasPublishedRef.current = true;
      emitCallTrackPublished(callId);
      console.log('[Call] emitted call:track-published — waiting for call:peer-ready…');
    } catch (err) {
      console.error('[Call] media negotiation failed:', err);
      dispatch(setCallError(err.message || (isVideo ? 'Could not access camera/microphone' : 'Could not access microphone')));
      endActiveCall('media_error');
    }
  }, [dispatch, endActiveCall]);

  // ── WebRTC: pull the peer's track once both sides have published ──────────
  const pullPeerTrack = useCallback(async (callId) => {
    console.log('[Call] received call:peer-ready, hasPulled =', hasPulledRef.current, 'hasPC =', !!pcRef.current);
    if (hasPulledRef.current || !pcRef.current) return;
    hasPulledRef.current = true;
    try {
      const { requiresImmediateRenegotiation, sdpOffer } = await callService.pullTrack(callId);
      console.log('[Call] pull response: requiresImmediateRenegotiation =', requiresImmediateRenegotiation, 'hasOffer =', !!sdpOffer);
      if (requiresImmediateRenegotiation && sdpOffer) {
        const pc = pcRef.current;
        await pc.setRemoteDescription({ type: 'offer', sdp: sdpOffer });
        const answer = await pc.createAnswer();
        await pc.setLocalDescription(answer);
        await waitForIceGatheringComplete(pc);
        await callService.renegotiate(callId, pc.localDescription.sdp);
        console.log('[Call] renegotiate sent — waiting for ontrack…');
      }
    } catch (err) {
      console.error('[Call] pulling peer track failed:', err);
      dispatch(setCallError(err.message || 'Could not connect audio'));
    }
  }, [dispatch]);

  // ── Socket event handlers ──────────────────────────────────────────────────
  useEffect(() => {
    if (!token) return undefined;

    const callbacks = {
      onCallRinging: ({ callId, callerId, callerName, callerAvatar, callType }) => {
        callIdRef.current = callId;
        dispatch(receiveIncomingCall({
          callId,
          peer: { id: callerId, name: callerName, avatar: callerAvatar },
          callType,
        }));
        showIncomingCallNotification(`${callerName || 'Someone'} is calling you`, callType === 'video' ? 'Incoming video call' : 'Incoming voice call');
        startTitleFlash('📞 Incoming call…');
      },
      onCallAccepted: ({ callId }) => {
        console.log('[Call] socket event call:accepted received — starting negotiation (caller side)');
        dispatch(setCallConnecting());
        beginMediaNegotiation(callId);
      },
      onCallRejected: () => { cleanupMedia(); dispatch(endCall()); },
      onCallMissed: () => { cleanupMedia(); dispatch(endCall()); },
      onCallEnded: () => { cleanupMedia(); dispatch(endCall()); },
      onCallPeerReady: ({ callId }) => { console.log('[Call] socket event call:peer-ready received'); pullPeerTrack(callId); },
      // Either party added someone, turning this into a group call — tear
      // down the 1:1 call here; GroupCallOverlay independently reacts to
      // the same event to take over.
      onCallEscalated: () => { cleanupMedia(); dispatch(endCall()); },
    };

    initChatSocket(token, callbacks, currentUserId);
    return () => removeChatSocketCallbacks(callbacks);
  }, [token, currentUserId, dispatch, beginMediaNegotiation, pullPeerTrack, endActiveCall, cleanupMedia]);

  // call:rejected / call:missed shouldn't re-emit call:end (the call was
  // never answered) — only tear down local state.
  useEffect(() => {
    if (call.status === 'idle') callIdRef.current = null;
    else callIdRef.current = call.callId;
  }, [call.status, call.callId]);

  // Reset the widget back to its default (compact, bottom-right) position
  // and size once a call ends, so the next call doesn't inherit it.
  useEffect(() => {
    if (call.status === 'idle') {
      setIsFullScreen(false);
      setDragOffset({ x: 0, y: 0 });
    }
  }, [call.status]);

  // Auto-dismiss the idle-state error toast (a failed call:initiate never
  // creates a call, so nothing else clears `error` in that state).
  useEffect(() => {
    if (call.status !== 'idle' || !call.error) return undefined;
    const t = setTimeout(() => dispatch(endCall()), 4000);
    return () => clearTimeout(t);
  }, [call.status, call.error, dispatch]);

  useImperativeHandle(ref, () => ({
    startCall: (receiverId, peer, callType = 'voice') => {
      emitCallInitiate(receiverId, callType, (ack) => {
        if (!ack || ack.error) {
          dispatch(setCallError(ack?.error || 'Could not start call'));
          return;
        }
        callIdRef.current = ack.callId;
        dispatch(startOutgoingCall({ callId: ack.callId, peer, callType }));
      });
    },
  }), [dispatch]);

  const handleAccept = () => {
    console.log('[Call] accept clicked — starting negotiation (receiver side)');
    emitCallAccept(call.callId, (ack) => {
      if (!ack || ack.error) {
        dispatch(setCallError(ack?.error || 'Could not accept call'));
        return;
      }
      dispatch(setCallConnecting());
      beginMediaNegotiation(call.callId);
    });
  };

  const handleReject = () => {
    emitCallReject(call.callId, 'declined');
    cleanupMedia();
    dispatch(endCall());
  };

  const handleAddPeople = (selectedUserIds) => {
    if (!selectedUserIds.length) return;
    emitCallEscalateToGroup(call.callId, selectedUserIds, (ack) => {
      if (!ack || ack.error) {
        dispatch(setCallError(ack?.error || 'Could not add people'));
      }
      // On success, cleanup/teardown happens via the call:escalated event
      // (sent to both parties, including me) rather than here directly.
    });
  };

  const toggleMute = () => {
    if (!localStreamRef.current) return;
    const nextMuted = !isMuted;
    localStreamRef.current.getAudioTracks().forEach((t) => { t.enabled = !nextMuted; });
    setIsMuted(nextMuted);
  };

  const toggleCamera = () => {
    if (!localStreamRef.current) return;
    const nextOff = !cameraOff;
    localStreamRef.current.getVideoTracks().forEach((t) => { t.enabled = !nextOff; });
    setCameraOff(nextOff);
  };

  const formatElapsed = (s) => `${String(Math.floor(s / 60)).padStart(2, '0')}:${String(s % 60).padStart(2, '0')}`;

  // A failed call:initiate (e.g. "not registered", "must follow each other")
  // only sets `error` — status stays 'idle' since no call was ever created.
  // Surface it as a brief toast instead of silently doing nothing.
  if (call.status === 'idle') {
    if (!call.error) return null;
    return (
      <div className="fixed left-1/2 top-6 z-50 -translate-x-1/2 rounded-full bg-red-500 px-4 py-2 text-sm font-semibold text-white shadow-lg">
        {call.error}
      </div>
    );
  }

  const peerName = call.peer?.name || 'Unknown';
  const peerAvatar = call.peer?.avatar;
  const isVideoCall = call.callType === 'video';
  const showVideoSurface = isVideoCall && (call.status === 'connecting' || call.status === 'active');
  const isRinging = ['outgoing-ringing', 'incoming-ringing', 'connecting'].includes(call.status);
  const statusLabel = call.status === 'outgoing-ringing' ? (isVideoCall ? 'Calling (video)…' : 'Calling…')
    : call.status === 'incoming-ringing' ? (isVideoCall ? 'Incoming video call' : 'Incoming voice call')
    : call.status === 'connecting' ? 'Connecting…'
    : call.status === 'active' ? formatElapsed(elapsedSeconds)
    : '';

  if (!isFullScreen) {
    const widgetScale = isDragging ? 1 : isWidgetHovered ? 1.03 : 1;
    return (
      <>
        <div
          onMouseDown={handleDragStart}
          onTouchStart={handleDragStart}
          onMouseEnter={() => setIsWidgetHovered(true)}
          onMouseLeave={() => setIsWidgetHovered(false)}
          style={{ transform: `translate(${dragOffset.x}px, ${dragOffset.y}px) scale(${widgetScale})` }}
          className="fixed bottom-6 right-6 z-50 w-72 cursor-grab select-none overflow-hidden rounded-2xl border border-gray-200 bg-white text-gray-900 shadow-2xl transition-transform duration-200 active:cursor-grabbing dark:border-white/10 dark:bg-gradient-to-b dark:from-[#1b1030] dark:via-[#120a22] dark:to-black dark:text-white"
        >
          <audio ref={remoteAudioRef} autoPlay playsInline />

          {isVideoCall && showVideoSurface && (
            <div className="relative h-36 w-full bg-black">
              <video ref={remoteVideoRef} autoPlay playsInline className="h-full w-full object-cover" />
              <video
                ref={localVideoRef}
                autoPlay
                playsInline
                muted
                className={`absolute bottom-2 right-2 h-14 w-10 rounded-lg border border-white/20 object-cover ${cameraOff ? 'hidden' : ''}`}
              />
            </div>
          )}

          <button
            type="button"
            onClick={() => setIsFullScreen(true)}
            aria-label="Full screen"
            className="absolute right-2 top-2 flex h-7 w-7 items-center justify-center rounded-full bg-black/5 text-gray-600 transition hover:bg-black/10 dark:bg-black/40 dark:text-white/80 dark:hover:bg-black/60"
          >
            <Maximize2 size={13} />
          </button>

          <div className="flex items-center gap-3 p-3">
            {(!isVideoCall || !showVideoSurface) && (
              peerAvatar
                ? <img src={peerAvatar} alt={peerName} className="h-11 w-11 shrink-0 rounded-full object-cover" />
                : <div className="flex h-11 w-11 shrink-0 items-center justify-center rounded-full bg-[#7C3AED] text-sm font-bold text-white">{peerName.charAt(0).toUpperCase()}</div>
            )}
            <div className="min-w-0 flex-1">
              <p className="truncate text-sm font-semibold">{peerName}</p>
              <p className="truncate text-xs text-gray-500 dark:text-white/60">{statusLabel}</p>
            </div>
          </div>

          {call.error ? <p className="px-3 pb-1 text-[11px] text-red-500 dark:text-red-400">{call.error}</p> : null}

          <div className="flex items-center justify-center gap-2.5 px-3 pb-3">
            {call.status === 'incoming-ringing' ? (
              <>
                <button onClick={handleReject} aria-label="Decline" className="flex h-11 w-11 items-center justify-center rounded-full bg-red-500 text-white shadow-lg shadow-red-500/30 transition hover:scale-105 active:scale-95">
                  <PhoneOff size={18} />
                </button>
                <button onClick={handleAccept} aria-label="Accept" className="flex h-11 w-11 items-center justify-center rounded-full bg-green-500 text-white shadow-lg shadow-green-500/30 transition hover:scale-105 active:scale-95">
                  <Phone size={18} />
                </button>
              </>
            ) : (
              <>
                {call.status === 'active' && (
                  <button
                    onClick={toggleMute}
                    aria-label={isMuted ? 'Unmute' : 'Mute'}
                    className={`flex h-10 w-10 items-center justify-center rounded-full transition hover:scale-105 active:scale-95 ${isMuted ? 'bg-white text-black ring-1 ring-gray-200' : 'bg-gray-100 text-gray-700 dark:bg-white/10 dark:text-white'}`}
                  >
                    {isMuted ? <MicOff size={16} /> : <Mic size={16} />}
                  </button>
                )}
                {call.status === 'active' && isVideoCall && (
                  <button
                    onClick={toggleCamera}
                    aria-label={cameraOff ? 'Turn camera on' : 'Turn camera off'}
                    className={`flex h-10 w-10 items-center justify-center rounded-full transition hover:scale-105 active:scale-95 ${cameraOff ? 'bg-white text-black ring-1 ring-gray-200' : 'bg-gray-100 text-gray-700 dark:bg-white/10 dark:text-white'}`}
                  >
                    {cameraOff ? <VideoOff size={16} /> : <Video size={16} />}
                  </button>
                )}
                {call.status === 'active' && (
                  <button
                    onClick={() => setShowAddPeople(true)}
                    aria-label="Add people"
                    className="flex h-10 w-10 items-center justify-center rounded-full bg-gray-100 text-gray-700 transition hover:scale-105 active:scale-95 dark:bg-white/10 dark:text-white"
                  >
                    <UserPlus size={16} />
                  </button>
                )}
                <button
                  onClick={() => endActiveCall('hangup')}
                  aria-label="End call"
                  className="flex h-10 w-10 items-center justify-center rounded-full bg-red-500 text-white shadow-lg shadow-red-500/30 transition hover:scale-105 active:scale-95"
                >
                  <PhoneOff size={16} />
                </button>
              </>
            )}
          </div>
        </div>

        <AddCallPeopleModal
          isOpen={showAddPeople}
          onClose={() => setShowAddPeople(false)}
          currentUserId={currentUserId}
          excludeUserIds={[currentUserId, call.peer?.id].filter(Boolean)}
          onConfirm={handleAddPeople}
        />
      </>
    );
  }

  return (
    <div className="fixed inset-0 z-50 flex flex-col overflow-hidden bg-gradient-to-b from-white via-gray-50 to-gray-100 dark:from-[#1b1030] dark:via-[#120a22] dark:to-black">
      <button
        type="button"
        onClick={() => setIsFullScreen(false)}
        aria-label="Minimize"
        className="absolute right-4 top-4 z-20 flex h-9 w-9 items-center justify-center rounded-full bg-black/5 text-gray-700 backdrop-blur-sm transition hover:bg-black/10 dark:bg-white/10 dark:text-white/80 dark:hover:bg-white/20"
      >
        <Minimize2 size={16} />
      </button>
      <audio ref={remoteAudioRef} autoPlay playsInline />

      {isVideoCall && (
        <>
          {/* Connecting shimmer — covered by the video once real frames arrive */}
          {call.status === 'connecting' && (
            <div className="absolute inset-0 animate-pulse bg-gradient-to-br from-[#1a1a2e] via-[#16213e] to-[#0f0f1e]" />
          )}
          <video
            ref={remoteVideoRef}
            autoPlay
            playsInline
            className={`absolute inset-0 h-full w-full object-cover ${showVideoSurface ? '' : 'hidden'}`}
          />
          <video
            ref={localVideoRef}
            autoPlay
            playsInline
            muted
            className={`absolute bottom-28 right-4 z-20 h-36 w-24 rounded-2xl border border-white/15 object-cover shadow-2xl sm:h-44 sm:w-28 ${showVideoSurface && !cameraOff ? '' : 'hidden'}`}
          />
        </>
      )}

      {showVideoSurface && (
        <div className="pointer-events-none absolute inset-x-0 top-0 z-10 h-28 bg-gradient-to-b from-black/60 to-transparent" />
      )}
      {showVideoSurface && (
        <div className="relative z-10 flex items-center gap-2 px-5 pt-5 text-white">
          <span className="truncate text-sm font-semibold drop-shadow-md">{peerName}</span>
          <span className="text-xs text-white/60">·</span>
          <span className="text-xs text-white/70 drop-shadow-md">
            {call.status === 'connecting' ? 'Connecting…' : formatElapsed(elapsedSeconds)}
          </span>
        </div>
      )}

      <div className={`relative z-10 flex flex-1 flex-col items-center justify-center gap-4 px-6 text-gray-900 dark:text-white ${showVideoSurface ? 'pointer-events-none' : ''}`}>
        {!showVideoSurface && (
          <div className="relative flex items-center justify-center">
            {isRinging && (
              <>
                <span className="absolute h-28 w-28 animate-ping rounded-full bg-[#7C3AED]/30" />
                <span className="absolute h-28 w-28 rounded-full bg-[#7C3AED]/10" />
              </>
            )}
            {peerAvatar ? (
              <img src={peerAvatar} alt={peerName} className="relative h-24 w-24 rounded-full object-cover ring-4 ring-black/5 dark:ring-white/10" />
            ) : (
              <div className="relative flex h-24 w-24 items-center justify-center rounded-full bg-[#7C3AED] text-3xl font-bold text-white ring-4 ring-black/5 dark:ring-white/10">
                {peerName.charAt(0).toUpperCase()}
              </div>
            )}
          </div>
        )}
        {!showVideoSurface && <p className="text-xl font-bold">{peerName}</p>}
        {!showVideoSurface && (
          <p className="text-sm text-gray-500 dark:text-gray-300">
            {call.status === 'outgoing-ringing' && (isVideoCall ? 'Calling (video)…' : 'Calling…')}
            {call.status === 'incoming-ringing' && (isVideoCall ? 'Incoming video call' : 'Incoming voice call')}
            {call.status === 'connecting' && 'Connecting…'}
            {call.status === 'active' && formatElapsed(elapsedSeconds)}
          </p>
        )}
        {call.error ? <p className="text-xs text-red-500 dark:text-red-400">{call.error}</p> : null}
      </div>

      <div className="relative z-10 pb-10 pt-8">
        {showVideoSurface && <div className="pointer-events-none absolute inset-x-0 bottom-0 -z-10 h-40 bg-gradient-to-t from-black/70 to-transparent" />}
        <div className="flex items-center justify-center gap-5">
          {call.status === 'incoming-ringing' ? (
            <>
              <button
                onClick={handleReject}
                className="flex h-16 w-16 items-center justify-center rounded-full bg-red-500 text-white shadow-lg shadow-red-500/30 transition hover:scale-105 active:scale-95"
                aria-label="Decline"
              >
                <PhoneOff size={26} />
              </button>
              <button
                onClick={handleAccept}
                className="flex h-16 w-16 items-center justify-center rounded-full bg-green-500 text-white shadow-lg shadow-green-500/30 transition hover:scale-105 active:scale-95"
                aria-label="Accept"
              >
                <Phone size={26} />
              </button>
            </>
          ) : (
            <div className="flex items-center gap-3 rounded-full bg-black/5 px-4 py-3 backdrop-blur-xl dark:bg-white/10">
              {call.status === 'active' ? (
                <button
                  onClick={toggleMute}
                  className={`flex h-14 w-14 items-center justify-center rounded-full transition hover:scale-105 active:scale-95 ${isMuted ? 'bg-white text-black ring-1 ring-gray-200' : 'bg-black/5 text-gray-700 dark:bg-white/10 dark:text-white'}`}
                  aria-label={isMuted ? 'Unmute' : 'Mute'}
                >
                  {isMuted ? <MicOff size={20} /> : <Mic size={20} />}
                </button>
              ) : null}
              {call.status === 'active' && isVideoCall ? (
                <button
                  onClick={toggleCamera}
                  className={`flex h-14 w-14 items-center justify-center rounded-full transition hover:scale-105 active:scale-95 ${cameraOff ? 'bg-white text-black ring-1 ring-gray-200' : 'bg-black/5 text-gray-700 dark:bg-white/10 dark:text-white'}`}
                  aria-label={cameraOff ? 'Turn camera on' : 'Turn camera off'}
                >
                  {cameraOff ? <VideoOff size={20} /> : <Video size={20} />}
                </button>
              ) : null}
              {call.status === 'active' ? (
                <button
                  onClick={() => setShowAddPeople(true)}
                  className="flex h-14 w-14 items-center justify-center rounded-full bg-black/5 text-gray-700 transition hover:scale-105 active:scale-95 dark:bg-white/10 dark:text-white"
                  aria-label="Add people"
                >
                  <UserPlus size={20} />
                </button>
              ) : null}
              <button
                onClick={() => endActiveCall('hangup')}
                className="flex h-14 w-14 items-center justify-center rounded-full bg-red-500 text-white shadow-lg shadow-red-500/30 transition hover:scale-105 active:scale-95"
                aria-label="End call"
              >
                <PhoneOff size={22} />
              </button>
            </div>
          )}
        </div>
      </div>

      <AddCallPeopleModal
        isOpen={showAddPeople}
        onClose={() => setShowAddPeople(false)}
        currentUserId={currentUserId}
        excludeUserIds={[currentUserId, call.peer?.id].filter(Boolean)}
        onConfirm={handleAddPeople}
      />
    </div>
  );
});

CallOverlay.displayName = 'CallOverlay';

export default CallOverlay;
