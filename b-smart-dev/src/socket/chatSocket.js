import { io } from 'socket.io-client';
import api from '../lib/api';

const SOCKET_URL = (
  import.meta.env.VITE_WS_URL ||
  (api.defaults.baseURL
    ? api.defaults.baseURL.replace(/\/api\/?$/, '')
    : 'http://localhost:5000')
);

let socket = null;
let userId = null;
let authToken = null;

// Multiple subscribers can listen to the same event
// Key = event name, Value = Set of callback functions
//
// Voice/video call signaling (call:*) rides this SAME socket connection —
// the backend registers call handlers on every chat connection (see
// server.js), so a separate io() connection would just be a redundant
// second socket for the same user.
const subscribers = {
  'new-message': new Set(),
  'user-typing': new Set(),
  'user-stop-typing': new Set(),
  'message-seen-update': new Set(),
  'message-reaction-update': new Set(),
  'message-removed': new Set(),
  'group-member-added': new Set(),
  'group-member-removed': new Set(),
  'online-users-updated': new Set(),
  'call:ringing': new Set(),
  'call:accepted': new Set(),
  'call:rejected': new Set(),
  'call:ended': new Set(),
  'call:missed': new Set(),
  'call:peer-ready': new Set(),
};

const attachAllListeners = () => {
  if (!socket) return;
  Object.keys(subscribers).forEach((eventName) => {
    socket.off(eventName);
    socket.on(eventName, (data) => {
      subscribers[eventName].forEach((cb) => {
        try { cb(data); } catch (e) { console.error('[ChatSocket] callback error', e); }
      });
    });
  });
};

// Call this ONCE when the app starts (from Sidebar or main layout)
export const initChatSocket = (token, callbacks = {}, registeredUserId = null) => {
  if (registeredUserId) userId = registeredUserId;
  if (token) authToken = token;

  // Register callbacks as subscribers
  const callbackMap = {
    onNewMessage: 'new-message',
    onUserTyping: 'user-typing',
    onUserStopTyping: 'user-stop-typing',
    onMessageSeenUpdate: 'message-seen-update',
    onMessageReactionUpdate: 'message-reaction-update',
    onMessageRemoved: 'message-removed',
    onGroupMemberAdded: 'group-member-added',
    onGroupMemberRemoved: 'group-member-removed',
    onOnlineUsersUpdated: 'online-users-updated',
    onCallRinging: 'call:ringing',
    onCallAccepted: 'call:accepted',
    onCallRejected: 'call:rejected',
    onCallEnded: 'call:ended',
    onCallMissed: 'call:missed',
    onCallPeerReady: 'call:peer-ready',
  };

  Object.entries(callbackMap).forEach(([key, eventName]) => {
    if (typeof callbacks[key] === 'function') {
      subscribers[eventName].add(callbacks[key]);
    }
  });

  // If socket already exists and is connected, just (re-)register
  if (socket) {
    if (socket.connected && authToken) {
      socket.emit('register', authToken);
    }
    return socket;
  }

  // Create new socket connection
  socket = io(SOCKET_URL, {
    transports: ['websocket', 'polling'],
    reconnection: true,
    reconnectionAttempts: 10,
    reconnectionDelay: 1500,
    timeout: 10000,
    auth: token ? { token } : {},
  });

  attachAllListeners();

  socket.on('connect', () => {
    if (authToken) socket.emit('register', authToken);
  });

  socket.on('connect_error', (error) => {
    console.error('[Chat Socket] Connection error:', error.message);
  });

  socket.on('disconnect', (reason) => {
    console.warn('[Chat Socket] Disconnected:', reason);
  });

  return socket;
};

// Call this to remove specific callbacks (on component unmount)
export const removeChatSocketCallbacks = (callbacks = {}) => {
  const callbackMap = {
    onNewMessage: 'new-message',
    onUserTyping: 'user-typing',
    onUserStopTyping: 'user-stop-typing',
    onMessageSeenUpdate: 'message-seen-update',
    onMessageReactionUpdate: 'message-reaction-update',
    onMessageRemoved: 'message-removed',
    onGroupMemberAdded: 'group-member-added',
    onGroupMemberRemoved: 'group-member-removed',
    onOnlineUsersUpdated: 'online-users-updated',
    onCallRinging: 'call:ringing',
    onCallAccepted: 'call:accepted',
    onCallRejected: 'call:rejected',
    onCallEnded: 'call:ended',
    onCallMissed: 'call:missed',
    onCallPeerReady: 'call:peer-ready',
  };
  Object.entries(callbackMap).forEach(([key, eventName]) => {
    if (typeof callbacks[key] === 'function') {
      subscribers[eventName].delete(callbacks[key]);
    }
  });
};

// Only call this on full app logout
export const disconnectChatSocket = () => {
  if (!socket) return;
  Object.keys(subscribers).forEach((eventName) => {
    subscribers[eventName].clear();
    socket.off(eventName);
  });
  socket.disconnect();
  socket = null;
  userId = null;
  authToken = null;
};

export const joinRoom = (conversationId) => {
  if (socket && conversationId) socket.emit('join-room', conversationId);
};

export const leaveRoom = (conversationId) => {
  if (socket && conversationId) socket.emit('leave-room', conversationId);
};

export const emitSendMessage = (data) => {
  if (socket) socket.emit('send-message', data);
};

export const emitTyping = (conversationId, uid) => {
  if (socket && conversationId && uid)
    socket.emit('typing', { conversationId, userId: uid });
};

export const emitStopTyping = (conversationId, uid) => {
  if (socket && conversationId && uid)
    socket.emit('stop-typing', { conversationId, userId: uid });
};

export const emitMessageSeen = (conversationId, messageId, uid, seenAt = null) => {
  if (socket && conversationId && messageId && uid) {
    socket.emit('message-seen', { conversationId, messageId, userId: uid, seenAt });
  }
};

export const emitMessageDeleted = (conversationId, messageId) => {
  if (socket && conversationId && messageId) {
    socket.emit('message-deleted', { conversationId, messageId });
  }
};

export const emitMessageReactionUpdate = (conversationId, messageId, action, emoji, reactions = [], uid = null) => {
  if (socket && conversationId && messageId) {
    socket.emit('message-reaction-update', {
      conversationId,
      messageId,
      action,
      emoji,
      reactions,
      ...(uid ? { userId: uid } : {}),
    });
  }
};

// ── Voice/video call signaling ───────────────────────────────────────────────
// `ack` is the server's acknowledgement callback (socket.io ack), e.g.
// ({ callId, status, error }) => {...}.
export const emitCallInitiate = (receiverId, callType, ack) => {
  if (socket) socket.emit('call:initiate', { receiverId, callType }, ack);
};

export const emitCallAccept = (callId, ack) => {
  if (socket) socket.emit('call:accept', { callId }, ack);
};

export const emitCallReject = (callId, reason) => {
  if (socket) socket.emit('call:reject', { callId, reason });
};

export const emitCallEnd = (callId, reason) => {
  if (socket) socket.emit('call:end', { callId, reason });
};

// Tells the server I've published my audio track to Cloudflare, so it can
// check whether BOTH sides are ready and tell both to pull.
export const emitCallTrackPublished = (callId) => {
  if (socket) socket.emit('call:track-published', { callId });
};
