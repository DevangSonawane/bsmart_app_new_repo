/**
 * useNotificationSocket
 * ─────────────────────
 * Real-time notifications via WebSocket with automatic REST polling fallback.
 * Works with both native WS and socket.io-style servers.
 *
 * Emits these WS message types from server → client:
 *   { type: "notification_new",     data: <NotifObject> }
 *   { type: "notification_read",    id: string }
 *   { type: "notification_all_read" }
 *   { type: "notification_deleted", id: string }
 *   { type: "unread_count",         count: number }
 */

import { useState, useEffect, useRef, useCallback } from "react";
import api from "../lib/api";
import { emitFollowStatusChanged } from "../services/followService";

const WS_BASE               = (import.meta.env.VITE_WS_URL || "wss://api.bebsmart.in");
const ENABLE_NOTIFICATION_WS = import.meta.env.VITE_ENABLE_NOTIFICATION_WS === "true";
const POLL_INTERVAL          = 30_000;
const RECONNECT_MS           = 5_000;

export function useNotificationSocket({ limit = 20, page = 1, typeFilter = "", filter = "" } = {}) {
  const [notifications, setNotifications] = useState([]);
  const [unreadCount,   setUnreadCount]   = useState(0);
  const [total,         setTotal]         = useState(0);
  const [loading,       setLoading]       = useState(true);
  const [error,         setError]         = useState("");
  const [wsStatus,      setWsStatus]      = useState("connecting");

  const wsRef         = useRef(null);
  const pollRef       = useRef(null);
  const mountedRef    = useRef(true);
  const reconnectRef  = useRef(null);
  // Always holds the latest fetchRest — lets the polling interval stay current
  // even when filter/page/limit change without restarting the interval.
  const fetchRestRef  = useRef(null);

  // ── Fetch via REST ─────────────────────────────────────────────────────────
  const fetchRest = useCallback(async () => {
    if (!mountedRef.current) return;
    try {
      setLoading(true);
      setError("");
      const params = { page, limit };

      if (filter && filter !== "all") {
        // New vendor API: pass filter= query param directly
        // e.g. ?filter=approvals, ?filter=engagement, ?filter=unread …
        params.filter = filter;
      } else if (typeFilter === "unread") {
        params.isRead = false;
      } else if (typeFilter && typeFilter !== "all") {
        params.type = typeFilter;
      }

      const [listRes, countRes] = await Promise.all([
        api.get("/notifications", { params }),
        api.get("/notifications/unread-count"),
      ]);

      if (!mountedRef.current) return;
      const raw  = Array.isArray(listRes.data) ? listRes.data
        : listRes.data?.notifications || [];
      const data = typeFilter === "unread" ? raw.filter(n => !n.isRead) : raw;
      setNotifications(data);
      setTotal(listRes.data?.total ?? data.length);
      setUnreadCount(countRes.data?.count ?? countRes.data?.unreadCount ?? 0);
    } catch (e) {
      if (mountedRef.current)
        setError(e?.response?.data?.message || "Failed to load notifications");
    } finally {
      if (mountedRef.current) setLoading(false);
    }
  }, [page, limit, typeFilter, filter]);

  // Keep the ref in sync — this runs synchronously before effects, so
  // the polling interval always calls the latest version.
  fetchRestRef.current = fetchRest;

  // ── Polling fallback ───────────────────────────────────────────────────────
  // startPolling / connectWs are stable (no fetchRest in deps) because they
  // call fetchRestRef.current() instead of a captured closure copy.
  const stopPolling = useCallback(() => {
    if (pollRef.current) { clearInterval(pollRef.current); pollRef.current = null; }
  }, []);

  const startPolling = useCallback(() => {
    if (pollRef.current) return;
    setWsStatus("polling");
    // Use the ref so every tick picks up the current filter/page.
    pollRef.current = setInterval(() => fetchRestRef.current(), POLL_INTERVAL);
  }, []);                          // stable — no fetchRest dep needed

  // ── Connect WebSocket ──────────────────────────────────────────────────────
  const connectWs = useCallback(() => {
    if (!mountedRef.current) return;
    const token = localStorage.getItem("token");
    if (!token || !ENABLE_NOTIFICATION_WS) { startPolling(); return; }

    try {
      setWsStatus("connecting");
      const ws = new WebSocket(`${WS_BASE}/ws/notifications?token=${encodeURIComponent(token)}`);
      wsRef.current = ws;

      ws.onopen = () => {
        if (!mountedRef.current) return;
        setWsStatus("open");
        stopPolling();
      };

      ws.onmessage = ({ data }) => {
        if (!mountedRef.current) return;
        try { handleWsMessage(JSON.parse(data)); }
        catch { /* ignore malformed */ }
      };

      ws.onerror = () => { /* handled in onclose */ };

      ws.onclose = () => {
        if (!mountedRef.current) return;
        setWsStatus("closed");
        wsRef.current = null;
        startPolling();
        reconnectRef.current = setTimeout(connectWs, RECONNECT_MS);
      };
    } catch {
      startPolling();
    }
  }, [startPolling, stopPolling]);  // both stable → connectWs is stable

  // ── Handle incoming WS message ─────────────────────────────────────────────
  const handleWsMessage = (msg) => {
    switch (msg.type) {
      case "notification_new":
        setNotifications(prev => [msg.data, ...prev.slice(0, limit - 1)]);
        setUnreadCount(c => c + 1);
        setTotal(t => t + 1);
        if (msg?.data?.type === "follow_accepted") {
          const accepterId = msg?.data?.sender?._id || msg?.data?.sender?.id;
          emitFollowStatusChanged({ userId: accepterId, state: "following" });
        }
        break;
      case "notification_read":
        setNotifications(prev => prev.map(n => n._id === msg.id ? { ...n, isRead: true } : n));
        setUnreadCount(c => Math.max(0, c - 1));
        break;
      case "notification_all_read":
        setNotifications(prev => prev.map(n => ({ ...n, isRead: true })));
        setUnreadCount(0);
        break;
      case "notification_deleted":
        setNotifications(prev => prev.filter(n => n._id !== msg.id));
        setTotal(t => Math.max(0, t - 1));
        break;
      case "unread_count":
        setUnreadCount(msg.count ?? 0);
        break;
      default: break;
    }
  };

  // ── Mount / unmount ────────────────────────────────────────────────────────
  useEffect(() => {
    mountedRef.current = true;
    fetchRestRef.current();   // initial load via ref (always current)
    connectWs();
    return () => {
      mountedRef.current = false;
      wsRef.current?.close();
      stopPolling();
      if (reconnectRef.current) clearTimeout(reconnectRef.current);
    };
  }, [connectWs, stopPolling]); // stable deps — runs only on mount/unmount

  // Re-fetch when page, limit, typeFilter, or filter change
  useEffect(() => { fetchRest(); }, [fetchRest]);

  // ── CRUD actions (optimistic) ──────────────────────────────────────────────
  const markRead = useCallback(async (id) => {
    setNotifications(prev => prev.map(n => n._id === id ? { ...n, isRead: true } : n));
    setUnreadCount(c => Math.max(0, c - 1));
    try { await api.patch(`/notifications/${id}/read`); }
    catch { fetchRestRef.current(); }
  }, []);

  const markAllRead = useCallback(async () => {
    setNotifications(prev => prev.map(n => ({ ...n, isRead: true })));
    setUnreadCount(0);
    try { await api.patch("/notifications/mark-all-read"); }
    catch { fetchRestRef.current(); }
  }, []);

  const deleteNotif = useCallback(async (id) => {
    setNotifications(prev => {
      const target = prev.find(n => n._id === id);
      if (target && !target.isRead) setUnreadCount(c => Math.max(0, c - 1));
      return prev.filter(n => n._id !== id);
    });
    setTotal(t => Math.max(0, t - 1));
    try { await api.delete(`/notifications/${id}`); }
    catch { fetchRestRef.current(); }
  }, []);

  return {
    notifications, unreadCount, total,
    loading, error, wsStatus,
    markRead, markAllRead, deleteNotif,
    refresh: fetchRest,
  };
}
