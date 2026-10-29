import { forwardRef, useCallback, useEffect, useImperativeHandle, useRef, useState } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import { Mic, MicOff, Phone, PhoneOff } from 'lucide-react';
import {
  emitCallAccept,
  emitCallEnd,
  emitCallInitiate,
  emitCallReject,
  emitCallTrackPublished,
  initChatSocket,
  removeChatSocketCallbacks,
} from '../socket/chatSocket';
import * as callService from '../services/callService';
import {
  endCall,
  receiveIncomingCall,
  setCallActive,
  setCallConnecting,
  setCallError,
  startOutgoingCall,
} from '../store/callSlice';

// Cloudflare Realtime's SFU is reachable via a public STUN-only ICE
// candidate — no TURN needed since the SFU itself is the relay endpoint.
const ICE_SERVERS = [{ urls: 'stun:stun.cloudflare.com:3478' }];

// Cloudflare's Calls API is a single HTTP round trip per SDP exchange (no
// trickle-ICE signaling channel), so the offer/answer we send it must
// already contain all gathered ICE candidates.
const waitForIceGatheringComplete = (pc, timeoutMs = 3000) => {
  if (pc.iceGatheringState === 'complete') return Promise.resolve();
  return new Promise((resolve) => {
    const onChange = () => {
      if (pc.iceGatheringState === 'complete') {
        pc.removeEventListener('icegatheringstatechange', onChange);
        resolve();
      }
    };
    pc.addEventListener('icegatheringstatechange', onChange);
    setTimeout(resolve, timeoutMs);
  });
};

const CallOverlay = forwardRef(({ currentUserId, token }, ref) => {
  const dispatch = useDispatch();
  const call = useSelector((state) => state.call);

  const [isMuted, setIsMuted] = useState(false);
  const [elapsedSeconds, setElapsedSeconds] = useState(0);

  const pcRef = useRef(null);
  const localStreamRef = useRef(null);
  const remoteAudioRef = useRef(null);
  const hasPublishedRef = useRef(false);
  const hasPulledRef = useRef(false);
  const callIdRef = useRef(null);
  const timerRef = useRef(null);

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
    hasPublishedRef.current = false;
    hasPulledRef.current = false;
    if (timerRef.current) {
      clearInterval(timerRef.current);
      timerRef.current = null;
    }
    setElapsedSeconds(0);
    setIsMuted(false);
  }, []);

  const endActiveCall = useCallback((reason) => {
    if (callIdRef.current) emitCallEnd(callIdRef.current, reason);
    cleanupMedia();
    dispatch(endCall());
  }, [cleanupMedia, dispatch]);

  // ── WebRTC: publish my audio, then wait to be told the peer has too ───────
  const beginMediaNegotiation = useCallback(async (callId) => {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      localStreamRef.current = stream;

      const pc = new RTCPeerConnection({ iceServers: ICE_SERVERS });
      pcRef.current = pc;
      pc.ontrack = (event) => {
        console.log('[Call] ontrack fired — remote audio received', event.streams[0]);
        if (remoteAudioRef.current) {
          remoteAudioRef.current.srcObject = event.streams[0];
          remoteAudioRef.current.play().catch((e) => console.error('[Call] audio.play() failed:', e));
        }
        dispatch(setCallActive());
        if (!timerRef.current) {
          timerRef.current = setInterval(() => setElapsedSeconds((s) => s + 1), 1000);
        }
      };
      pc.oniceconnectionstatechange = () => console.log('[Call] iceConnectionState ->', pc.iceConnectionState);
      pc.onconnectionstatechange = () => console.log('[Call] connectionState ->', pc.connectionState);

      stream.getAudioTracks().forEach((track) => pc.addTrack(track, stream));
      console.log('[Call] got local mic stream, tracks:', stream.getAudioTracks().length);

      const offer = await pc.createOffer();
      await pc.setLocalDescription(offer);
      console.log('[Call] local offer created, gathering ICE…');
      await waitForIceGatheringComplete(pc);
      console.log('[Call] ICE gathering complete, iceGatheringState =', pc.iceGatheringState);

      const mid = pc.getTransceivers()[0]?.mid ?? '0';
      console.log('[Call] publishing track, mid =', mid, 'callId =', callId);
      const { sdpAnswer } = await callService.publishTrack(callId, pc.localDescription.sdp, mid);
      if (!sdpAnswer) throw new Error('No answer from media server');
      await pc.setRemoteDescription({ type: 'answer', sdp: sdpAnswer });
      console.log('[Call] publish succeeded, remote description set');

      hasPublishedRef.current = true;
      emitCallTrackPublished(callId);
      console.log('[Call] emitted call:track-published — waiting for call:peer-ready…');
    } catch (err) {
      console.error('[Call] media negotiation failed:', err);
      dispatch(setCallError(err.message || 'Could not access microphone'));
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

  const toggleMute = () => {
    if (!localStreamRef.current) return;
    const nextMuted = !isMuted;
    localStreamRef.current.getAudioTracks().forEach((t) => { t.enabled = !nextMuted; });
    setIsMuted(nextMuted);
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

  return (
    <div className="fixed inset-0 z-50 flex flex-col items-center justify-center bg-black/80 backdrop-blur-sm">
      <audio ref={remoteAudioRef} autoPlay playsInline />
      <div className="flex flex-col items-center gap-4 text-white">
        {peerAvatar ? (
          <img src={peerAvatar} alt={peerName} className="h-24 w-24 rounded-full object-cover ring-4 ring-white/10" />
        ) : (
          <div className="flex h-24 w-24 items-center justify-center rounded-full bg-[#7C3AED] text-3xl font-bold ring-4 ring-white/10">
            {peerName.charAt(0).toUpperCase()}
          </div>
        )}
        <p className="text-xl font-bold">{peerName}</p>
        <p className="text-sm text-gray-300">
          {call.status === 'outgoing-ringing' && 'Calling…'}
          {call.status === 'incoming-ringing' && 'Incoming voice call'}
          {call.status === 'connecting' && 'Connecting…'}
          {call.status === 'active' && formatElapsed(elapsedSeconds)}
        </p>
        {call.error ? <p className="text-xs text-red-400">{call.error}</p> : null}

        <div className="mt-6 flex items-center gap-6">
          {call.status === 'incoming-ringing' ? (
            <>
              <button
                onClick={handleReject}
                className="flex h-14 w-14 items-center justify-center rounded-full bg-red-500 transition hover:scale-105 active:scale-95"
                aria-label="Decline"
              >
                <PhoneOff size={24} />
              </button>
              <button
                onClick={handleAccept}
                className="flex h-14 w-14 items-center justify-center rounded-full bg-green-500 transition hover:scale-105 active:scale-95"
                aria-label="Accept"
              >
                <Phone size={24} />
              </button>
            </>
          ) : (
            <>
              {call.status === 'active' ? (
                <button
                  onClick={toggleMute}
                  className={`flex h-14 w-14 items-center justify-center rounded-full transition hover:scale-105 active:scale-95 ${isMuted ? 'bg-white text-black' : 'bg-white/10'}`}
                  aria-label={isMuted ? 'Unmute' : 'Mute'}
                >
                  {isMuted ? <MicOff size={22} /> : <Mic size={22} />}
                </button>
              ) : null}
              <button
                onClick={() => endActiveCall('hangup')}
                className="flex h-14 w-14 items-center justify-center rounded-full bg-red-500 transition hover:scale-105 active:scale-95"
                aria-label="End call"
              >
                <PhoneOff size={24} />
              </button>
            </>
          )}
        </div>
      </div>
    </div>
  );
});

CallOverlay.displayName = 'CallOverlay';

export default CallOverlay;
