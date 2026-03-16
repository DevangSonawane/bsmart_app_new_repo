/**
 * socketService.js
 * ─────────────────
 * Singleton Socket.IO connection manager.
 *
 * Your backend uses Socket.IO (not plain WebSocket).
 * This service creates ONE shared socket connection for the entire app,
 * so Sidebar and Notifications page both share the same socket
 * instead of each opening their own connection.
 *
 * Usage:
 *   import socketService from '../services/socketService';
 *   socketService.connect(token);
 *   socketService.on('new_notification', handler);
 *   socketService.off('new_notification', handler);
 *   socketService.disconnect();
 */

import { io } from 'socket.io-client';

const SOCKET_URL = 'https://api.bebsmart.in';

class SocketService {
  constructor() {
    this.socket = null;
    this.listeners = new Map(); // event → Set of handlers
  }

  // Connect using the user's auth token
  connect(token) {
    // Already connected with same token — do nothing
    if (this.socket && this.socket.connected) return;

    // Disconnect any stale socket first
    if (this.socket) {
      this.socket.disconnect();
      this.socket = null;
    }

    this.socket = io(SOCKET_URL, {
      transports: ['websocket', 'polling'], // try websocket first, fall back to polling
      reconnection: true,
      reconnectionAttempts: 10,
      reconnectionDelay: 3000,
      timeout: 10000,
    });

    // Register the user with the server after connecting
    this.socket.on('connect', () => {
      console.log('[Socket] Connected:', this.socket.id);
      if (token) {
        this.socket.emit('register', token);
      }
    });

    this.socket.on('disconnect', (reason) => {
      console.warn('[Socket] Disconnected:', reason);
    });

    this.socket.on('connect_error', (err) => {
      console.error('[Socket] Connection error:', err.message);
    });

    // Re-attach all existing listeners to the new socket
    for (const [event, handlers] of this.listeners.entries()) {
      for (const handler of handlers) {
        this.socket.on(event, handler);
      }
    }
  }

  // Subscribe to a socket event
  on(event, handler) {
    if (!this.listeners.has(event)) {
      this.listeners.set(event, new Set());
    }
    this.listeners.get(event).add(handler);

    // Attach to live socket if already connected
    if (this.socket) {
      this.socket.on(event, handler);
    }
  }

  // Unsubscribe from a socket event
  off(event, handler) {
    if (this.listeners.has(event)) {
      this.listeners.get(event).delete(handler);
    }
    if (this.socket) {
      this.socket.off(event, handler);
    }
  }

  // Emit an event to the server
  emit(event, data) {
    if (this.socket && this.socket.connected) {
      this.socket.emit(event, data);
    }
  }

  // Get current connection status
  isConnected() {
    return this.socket?.connected ?? false;
  }

  // Disconnect socket (call on logout)
  disconnect() {
    if (this.socket) {
      this.socket.disconnect();
      this.socket = null;
    }
    this.listeners.clear();
  }
}

// Export a single shared instance for the whole app
const socketService = new SocketService();
export default socketService;