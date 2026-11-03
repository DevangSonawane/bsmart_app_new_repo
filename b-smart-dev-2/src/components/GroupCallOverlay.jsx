import { forwardRef, useCallback, useEffect, useImperativeHandle, useRef, useState } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import { Mic, MicOff, Phone, PhoneOff, UserPlus, UserRound, Video, VideoOff } from 'lucide-react';
import {
  emitGroupCallDecline,
  emitGroupCallInitiate,
  emitGroupCallInvite,
  emitGroupCallJoin,
  emitGroupCallLeave,
  emitGroupCallTrackPublished,
  initChatSocket,
  removeChatSocketCallbacks,
} from '../socket/chatSocket';
import * as groupCallService from '../services/groupCallService';
import AddCallPeopleModal from './AddCallPeopleModal';
import {
  endGroupCall,
  receiveIncomingGroupCall,
  removeGroupCallParticipant,
  setGroupCallActive,
  setGroupCallError,
  startOutgoingGroupCall,
  upsertGroupCallParticipant,
} from '../store/groupCallSlice';
import {
  RING_INTERVAL_MS,
  playRingChime,
  requestNotificationPermission,
  showIncomingCallNotification,
  startTitleFlash,
  stopTitleFlash,
  waitForIceGatheringComplete,
} from '../utils/callMedia';

// Same STUN-only ICE config as the 1:1 overlay — Cloudflare Realtime's SFU
// is itself the relay, no TURN needed.
const ICE_SERVERS = [{ urls: 'stun:stun.cloudflare.com:3478' }];

// One tile per participant (plus a self-tile). For a video call it's a
// <video>; for voice (or before a peer's camera track has arrived) it
// falls back to an avatar circle. A peer's audio always plays through a
// separate hidden <audio> regardless of call type, mirroring CallOverlay.
function Tile({ name, avatar, isSelf, isVideoCall, micMuted, cameraOff, videoRef, audioRef }) {
  const label = isSelf ? 'You' : (name || 'Unknown');
  return (
    <div className="relative aspect-square overflow-hidden rounded-2xl border border-white/10 bg-white/5 shadow-lg">
      {isVideoCall && !cameraOff && (
        <video ref={videoRef} autoPlay playsInline muted={isSelf} className="h-full w-full object-cover" />
      )}
      {(!isVideoCall || cameraOff) && (
        <div className="flex h-full w-full items-center justify-center bg-gradient-to-br from-white/[0.06] to-transparent">
          {avatar ? (
            <img src={avatar} alt={label} className="h-12 w-12 rounded-full object-cover ring-2 ring-white/10" />
          ) : (
            <div className="flex h-12 w-12 items-center justify-center rounded-full bg-[#7C3AED] text-lg font-bold ring-2 ring-white/10">
              {label.charAt(0).toUpperCase()}
            </div>
          )}
        </div>
      )}
      {!isSelf && <audio ref={audioRef} autoPlay playsInline />}
      <div className="pointer-events-none absolute inset-x-0 bottom-0 h-10 bg-gradient-to-t from-black/60 to-transparent" />
      <span className="absolute bottom-1.5 left-2 flex items-center gap-1 text-[11px] font-medium drop-shadow">
        {label}
        {micMuted && <MicOff size={11} className="text-white/80" />}
      </span>
    </div>
  );
}

const GroupCallOverlay = forwardRef(({ currentUserId, token }, ref) => {
  const dispatch = useDispatch();
  const groupCall = useSelector((state) => state.groupCall);

  const [isMuted, setIsMuted] = useState(false);
  const [cameraOff, setCameraOff] = useState(false);
  const [elapsedSeconds, setElapsedSeconds] = useState(0);
  const [showAddPeople, setShowAddPeople] = useState(false);

  const pcRef = useRef(null);
  const localStreamRef = useRef(null);
  const localVideoRef = useRef(null);
  const groupCallIdRef = useRef(null);
  const timerRef = useRef(null);

  // Same staleness problem as CallOverlay's callRef — the socket-callback
  // effect below only (re)registers on token/user change, not per-call.
  const groupCallRef = useRef(groupCall);
  useEffect(() => { groupCallRef.current = groupCall; }, [groupCall]);

  // Per-peer remote media bookkeeping. Tracks can arrive (via ontrack)
  // before or after the tile's DOM node mounts, so both attachTrack() and
  // setTileNode() check/apply the other side — whichever happens second
  // wires the stream up.
  const tileNodesRef = useRef({}); // userId -> { video, audio }
  const remoteStreamsRef = useRef({}); // userId -> { video, audio } MediaStream
  const pulledPeersRef = useRef(new Set());
  const pullChainRef = useRef(Promise.resolve());
  const currentPullingUserIdRef = useRef(null);

  const attachTrack = (userId, track, stream) => {
    if (!remoteStreamsRef.current[userId]) remoteStreamsRef.current[userId] = {};
    remoteStreamsRef.current[userId][track.kind] = stream;
    const el = tileNodesRef.current[userId]?.[track.kind];
    if (el) {
      el.srcObject = stream;
      el.play().catch(() => {});
    }
  };

  const setTileNode = (userId, kind, el) => {
    if (!tileNodesRef.current[userId]) tileNodesRef.current[userId] = {};
    tileNodesRef.current[userId][kind] = el;
    const stream = remoteStreamsRef.current[userId]?.[kind];
    if (el && stream) {
      el.srcObject = stream;
      el.play().catch(() => {});
    }
  };

  // ── Ringtone (incoming call) — same synthesized chime as CallOverlay ──────
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
  useEffect(() => { requestNotificationPermission(); }, []);
  useEffect(() => {
    if (groupCall.status === 'incoming-ringing') startRingtone();
    else { stopRingtone(); stopTitleFlash(); }
  }, [groupCall.status, startRingtone, stopRingtone]);
  useEffect(() => () => stopRingtone(), [stopRingtone]);

  // Call-duration timer — runs for as long as I'm active, regardless of
  // whether anyone else has published yet.
  useEffect(() => {
    if (groupCall.status === 'active' && !timerRef.current) {
      timerRef.current = setInterval(() => setElapsedSeconds((s) => s + 1), 1000);
    } else if (groupCall.status !== 'active' && timerRef.current) {
      clearInterval(timerRef.current);
      timerRef.current = null;
    }
  }, [groupCall.status]);

  const cleanupMedia = useCallback(() => {
    if (pcRef.current) {
      pcRef.current.close();
      pcRef.current = null;
    }
    if (localStreamRef.current) {
      localStreamRef.current.getTracks().forEach((t) => t.stop());
      localStreamRef.current = null;
    }
    if (localVideoRef.current) localVideoRef.current.srcObject = null;
    Object.values(tileNodesRef.current).forEach((refs) => {
      if (refs.video) refs.video.srcObject = null;
      if (refs.audio) refs.audio.srcObject = null;
    });
    tileNodesRef.current = {};
    remoteStreamsRef.current = {};
    pulledPeersRef.current = new Set();
    currentPullingUserIdRef.current = null;
    pullChainRef.current = Promise.resolve();
    if (timerRef.current) {
      clearInterval(timerRef.current);
      timerRef.current = null;
    }
    setElapsedSeconds(0);
    setIsMuted(false);
    setCameraOff(false);
  }, []);

  const leaveActiveCall = useCallback((reason) => {
    if (groupCallIdRef.current) emitGroupCallLeave(groupCallIdRef.current, reason);
    cleanupMedia();
    dispatch(endGroupCall());
  }, [cleanupMedia, dispatch]);

  // Pulls run strictly one at a time — pc.ontrack can't tell us which peer
  // a newly-arrived track belongs to, so we attribute it to "whichever
  // peer we're currently mid-pull for", which only works if pulls never
  // overlap.
  const doPull = useCallback(async (peerUserId) => {
    const groupCallId = groupCallIdRef.current;
    if (!groupCallId || !pcRef.current) return;
    currentPullingUserIdRef.current = peerUserId;
    try {
      const { requiresImmediateRenegotiation, sdpOffer } = await groupCallService.pullTrack(groupCallId, peerUserId);
      if (requiresImmediateRenegotiation && sdpOffer) {
        const pc = pcRef.current;
        await pc.setRemoteDescription({ type: 'offer', sdp: sdpOffer });
        const answer = await pc.createAnswer();
        await pc.setLocalDescription(answer);
        await waitForIceGatheringComplete(pc);
        await groupCallService.renegotiate(groupCallId, pc.localDescription.sdp);
      }
    } finally {
      currentPullingUserIdRef.current = null;
    }
  }, []);

  const enqueuePull = useCallback((peerUserId) => {
    if (pulledPeersRef.current.has(peerUserId)) return;
    pulledPeersRef.current.add(peerUserId);
    pullChainRef.current = pullChainRef.current
      .then(() => doPull(peerUserId))
      .catch((err) => console.error('[GroupCall] pull failed for', peerUserId, err));
  }, [doPull]);

  const beginGroupMediaNegotiation = useCallback(async (groupCallId, initialRoster) => {
    const isVideo = groupCallRef.current?.callType === 'video';
    try {
      const stream = await navigator.mediaDevices.getUserMedia(isVideo ? { audio: true, video: true } : { audio: true });
      localStreamRef.current = stream;
      if (isVideo && localVideoRef.current) localVideoRef.current.srcObject = stream;

      const pc = new RTCPeerConnection({ iceServers: ICE_SERVERS });
      pcRef.current = pc;
      pc.ontrack = (event) => {
        const uid = currentPullingUserIdRef.current;
        if (!uid) return;
        attachTrack(uid, event.track, event.streams[0]);
      };

      stream.getTracks().forEach((track) => pc.addTrack(track, stream));

      const offer = await pc.createOffer();
      await pc.setLocalDescription(offer);
      await waitForIceGatheringComplete(pc);

      const tracks = pc.getTransceivers()
        .filter((t) => t.sender?.track)
        .map((t) => ({ mid: t.mid, kind: t.sender.track.kind }));
      const { sdpAnswer } = await groupCallService.publishTrack(groupCallId, pc.localDescription.sdp, tracks);
      if (!sdpAnswer) throw new Error('No answer from media server');
      await pc.setRemoteDescription({ type: 'answer', sdp: sdpAnswer });

      emitGroupCallTrackPublished(groupCallId);

      (initialRoster || []).forEach((peer) => enqueuePull(peer.userId));
    } catch (err) {
      console.error('[GroupCall] media negotiation failed:', err);
      dispatch(setGroupCallError(err.message || (isVideo ? 'Could not access camera/microphone' : 'Could not access microphone')));
      leaveActiveCall('media_error');
    }
  }, [dispatch, enqueuePull, leaveActiveCall]);

  // ── Socket event handlers ──────────────────────────────────────────────────
  useEffect(() => {
    if (!token) return undefined;

    const callbacks = {
      onGroupCallRinging: ({ groupCallId, conversationId, conversationTitle, conversationAvatar, initiatorId, initiatorName, initiatorAvatar, callType }) => {
        groupCallIdRef.current = groupCallId;
        dispatch(receiveIncomingGroupCall({
          groupCallId, conversationId, conversationTitle, conversationAvatar, callType,
          initiator: { id: initiatorId, name: initiatorName, avatar: initiatorAvatar },
        }));
        showIncomingCallNotification(
          `${initiatorName || 'Someone'} is calling ${conversationTitle ? `"${conversationTitle}"` : 'the group'}`,
          callType === 'video' ? 'Incoming group video call' : 'Incoming group voice call',
        );
        startTitleFlash('📞 Incoming call…');
      },
      onGroupCallParticipantJoined: ({ groupCallId, userId, name, avatar }) => {
        if (String(groupCallId) !== String(groupCallIdRef.current)) return;
        dispatch(upsertGroupCallParticipant({ userId, name, avatar, status: 'joined' }));
      },
      onGroupCallParticipantLeft: ({ groupCallId, userId }) => {
        if (String(groupCallId) !== String(groupCallIdRef.current)) return;
        dispatch(removeGroupCallParticipant({ userId }));
        pulledPeersRef.current.delete(userId);
        delete remoteStreamsRef.current[userId];
        delete tileNodesRef.current[userId];
      },
      onGroupCallPeerReady: ({ groupCallId, fromUserId }) => {
        if (String(groupCallId) !== String(groupCallIdRef.current)) return;
        enqueuePull(fromUserId);
      },
      onGroupCallMissed: ({ groupCallId }) => {
        if (String(groupCallId) !== String(groupCallIdRef.current)) return;
        if (groupCallRef.current?.status === 'incoming-ringing') {
          cleanupMedia();
          dispatch(endGroupCall());
        }
      },
      // Fired on BOTH original parties of a 1:1 call that just got escalated
      // into this group call — this is how they enter it, directly active
      // rather than via the usual ring/join handshake (CallOverlay reacts to
      // the same event independently by tearing down the 1:1 call).
      onCallEscalated: ({ groupCallId, callType }) => {
        groupCallIdRef.current = groupCallId;
        dispatch(startOutgoingGroupCall({
          groupCallId,
          conversationId: null,
          conversationTitle: '',
          conversationAvatar: '',
          callType,
        }));
        dispatch(setGroupCallActive({ roster: [] }));
        beginGroupMediaNegotiation(groupCallId, []);
      },
    };

    initChatSocket(token, callbacks, currentUserId);
    return () => removeChatSocketCallbacks(callbacks);
  }, [token, currentUserId, dispatch, enqueuePull, cleanupMedia, beginGroupMediaNegotiation]);

  useEffect(() => {
    if (groupCall.status === 'idle') groupCallIdRef.current = null;
    else groupCallIdRef.current = groupCall.groupCallId;
  }, [groupCall.status, groupCall.groupCallId]);

  useEffect(() => {
    if (groupCall.status !== 'idle' || !groupCall.error) return undefined;
    const t = setTimeout(() => dispatch(endGroupCall()), 4000);
    return () => clearTimeout(t);
  }, [groupCall.status, groupCall.error, dispatch]);

  useImperativeHandle(ref, () => ({
    // Also doubles as "join" — if a call is already active for this
    // conversation, the server joins me to it instead of starting a new one.
    startGroupCall: (conversationId, callType = 'voice') => {
      emitGroupCallInitiate(conversationId, callType, (ack) => {
        if (!ack || ack.error) {
          dispatch(setGroupCallError(ack?.error || 'Could not start group call'));
          return;
        }
        groupCallIdRef.current = ack.groupCallId;
        dispatch(startOutgoingGroupCall({
          groupCallId: ack.groupCallId,
          conversationId,
          conversationTitle: ack.conversationTitle,
          conversationAvatar: ack.conversationAvatar,
          callType: ack.callType || callType,
        }));
        dispatch(setGroupCallActive({ roster: ack.roster || [] }));
        beginGroupMediaNegotiation(ack.groupCallId, ack.roster || []);
      });
    },
  }), [dispatch, beginGroupMediaNegotiation]);

  const handleAccept = () => {
    emitGroupCallJoin(groupCall.groupCallId, (ack) => {
      if (!ack || ack.error) {
        dispatch(setGroupCallError(ack?.error || 'Could not join call'));
        return;
      }
      dispatch(setGroupCallActive({ roster: ack.roster || [] }));
      beginGroupMediaNegotiation(ack.groupCallId, ack.roster || []);
    });
  };

  const handleDecline = () => {
    emitGroupCallDecline(groupCall.groupCallId);
    cleanupMedia();
    dispatch(endGroupCall());
  };

  const handleAddPeople = (selectedUserIds) => {
    if (!selectedUserIds.length) return;
    emitGroupCallInvite(groupCall.groupCallId, selectedUserIds, (ack) => {
      if (!ack || ack.error) dispatch(setGroupCallError(ack?.error || 'Could not add people'));
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

  if (groupCall.status === 'idle') {
    if (!groupCall.error) return null;
    return (
      <div className="fixed left-1/2 top-6 z-50 -translate-x-1/2 rounded-full bg-red-500 px-4 py-2 text-sm font-semibold text-white shadow-lg">
        {groupCall.error}
      </div>
    );
  }

  const conversationTitle = groupCall.conversationTitle || 'Group call';
  const isVideoCall = groupCall.callType === 'video';
  const joinedParticipants = Object.entries(groupCall.participants).filter(([, p]) => p.status === 'joined');

  if (groupCall.status === 'incoming-ringing') {
    return (
      <div className="fixed inset-0 z-50 flex flex-col items-center justify-center gap-4 bg-gradient-to-b from-[#1b1030] via-[#120a22] to-black text-white">
        <div className="relative flex items-center justify-center">
          <span className="absolute h-28 w-28 animate-ping rounded-full bg-[#7C3AED]/30" />
          <span className="absolute h-28 w-28 rounded-full bg-[#7C3AED]/10" />
          {groupCall.conversationAvatar ? (
            <img src={groupCall.conversationAvatar} alt={conversationTitle} className="relative h-24 w-24 rounded-full object-cover ring-4 ring-white/10" />
          ) : (
            <div className="relative flex h-24 w-24 items-center justify-center rounded-full bg-[#7C3AED] text-3xl font-bold ring-4 ring-white/10">
              {conversationTitle.charAt(0).toUpperCase()}
            </div>
          )}
        </div>
        <p className="text-xl font-bold">{conversationTitle}</p>
        <p className="text-sm text-gray-300">
          {groupCall.initiator?.name || 'Someone'} is starting a {isVideoCall ? 'video' : 'voice'} call
        </p>
        {groupCall.error ? <p className="text-xs text-red-400">{groupCall.error}</p> : null}
        <div className="mt-6 flex items-center gap-5">
          <button
            onClick={handleDecline}
            className="flex h-16 w-16 items-center justify-center rounded-full bg-red-500 shadow-lg shadow-red-500/30 transition hover:scale-105 active:scale-95"
            aria-label="Decline"
          >
            <PhoneOff size={26} />
          </button>
          <button
            onClick={handleAccept}
            className="flex h-16 w-16 items-center justify-center rounded-full bg-green-500 shadow-lg shadow-green-500/30 transition hover:scale-105 active:scale-95"
            aria-label="Join"
          >
            <Phone size={26} />
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="fixed inset-0 z-50 flex flex-col bg-gradient-to-b from-[#1b1030] via-[#120a22] to-black text-white">
      <div className="flex items-center justify-between px-5 pb-3 pt-5">
        <div className="min-w-0">
          <p className="truncate text-sm font-bold drop-shadow">{conversationTitle}</p>
          <p className="text-xs text-white/60">{formatElapsed(elapsedSeconds)} · {joinedParticipants.length + 1} in call</p>
        </div>
        {groupCall.error ? <p className="text-xs text-red-400">{groupCall.error}</p> : null}
      </div>

      <div className="flex-1 overflow-y-auto px-3 pb-3">
        <div className="grid grid-cols-2 gap-2.5 sm:grid-cols-3">
          <Tile isSelf name="You" isVideoCall={isVideoCall} micMuted={isMuted} cameraOff={cameraOff} videoRef={localVideoRef} />
          {joinedParticipants.map(([userId, p]) => (
            <Tile
              key={userId}
              name={p.name}
              avatar={p.avatar}
              isVideoCall={isVideoCall}
              videoRef={(el) => setTileNode(userId, 'video', el)}
              audioRef={(el) => setTileNode(userId, 'audio', el)}
            />
          ))}
          {!joinedParticipants.length && (
            <div className="col-span-full flex flex-col items-center justify-center gap-2 py-10 text-white/50">
              <UserRound size={28} />
              <p className="text-sm">Waiting for others to join…</p>
            </div>
          )}
        </div>
      </div>

      <div className="flex items-center justify-center pb-10 pt-4">
        <div className="flex items-center gap-3 rounded-full bg-white/10 px-4 py-3 backdrop-blur-xl">
          <button
            onClick={toggleMute}
            className={`flex h-14 w-14 items-center justify-center rounded-full transition hover:scale-105 active:scale-95 ${isMuted ? 'bg-white text-black' : 'bg-white/10'}`}
            aria-label={isMuted ? 'Unmute' : 'Mute'}
          >
            {isMuted ? <MicOff size={20} /> : <Mic size={20} />}
          </button>
          {isVideoCall && (
            <button
              onClick={toggleCamera}
              className={`flex h-14 w-14 items-center justify-center rounded-full transition hover:scale-105 active:scale-95 ${cameraOff ? 'bg-white text-black' : 'bg-white/10'}`}
              aria-label={cameraOff ? 'Turn camera on' : 'Turn camera off'}
            >
              {cameraOff ? <VideoOff size={20} /> : <Video size={20} />}
            </button>
          )}
          <button
            onClick={() => setShowAddPeople(true)}
            className="flex h-14 w-14 items-center justify-center rounded-full bg-white/10 transition hover:scale-105 active:scale-95"
            aria-label="Add people"
          >
            <UserPlus size={20} />
          </button>
          <button
            onClick={() => leaveActiveCall('hangup')}
            className="flex h-14 w-14 items-center justify-center rounded-full bg-red-500 shadow-lg shadow-red-500/30 transition hover:scale-105 active:scale-95"
            aria-label="Leave call"
          >
            <PhoneOff size={22} />
          </button>
        </div>
      </div>
      <AddCallPeopleModal
        isOpen={showAddPeople}
        onClose={() => setShowAddPeople(false)}
        currentUserId={currentUserId}
        excludeUserIds={[currentUserId, ...Object.keys(groupCall.participants)]}
        onConfirm={handleAddPeople}
      />
    </div>
  );
});

GroupCallOverlay.displayName = 'GroupCallOverlay';

export default GroupCallOverlay;
