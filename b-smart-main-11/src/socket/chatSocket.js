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

// Multiple subscribers can listen to the same event
// Key = event name, Value = Set of callback functions
const subscribers = {
  'new-message': new Set(),
  'user-typing': new Set(),
  'user-stop-typing': new Set(),
  'message-seen-update': new Set(),
  'message-removed': new Set(),
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

  // Register callbacks as subscribers
  const callbackMap = {
    onNewMessage: 'new-message',
    onUserTyping: 'user-typing',
    onUserStopTyping: 'user-stop-typing',
    onMessageSeenUpdate: 'message-seen-update',
    onMessageRemoved: 'message-removed',
  };

  Object.entries(callbackMap).forEach(([key, eventName]) => {
    if (typeof callbacks[key] === 'function') {
      subscribers[eventName].add(callbacks[key]);
    }
  });

  // If socket already exists and is connected, just register userId
  if (socket) {
    if (socket.connected && userId) {
      socket.emit('register', userId);
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
    if (userId) socket.emit('register', userId);
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
    onMessageRemoved: 'message-removed',
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
