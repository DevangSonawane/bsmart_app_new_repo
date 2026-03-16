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

const WS_BASE      = (import.meta.env.VITE_WS_URL || "wss://api.bebsmart.in");
const POLL_INTERVAL = 30_000;   // poll every 30s when WS is down
const RECONNECT_MS  = 5_000;    // retry WS after 5s

export function useNotificationSocket({ limit = 20, page = 1, typeFilter = "" } = {}) {
  const [notifications, setNotifications] = useState([]);
  const [unreadCount,   setUnreadCount]   = useState(0);
  const [total,         setTotal]         = useState(0);
  const [loading,       setLoading]       = useState(true);
  const [error,         setError]         = useState("");
  const [wsStatus,      setWsStatus]      = useState("connecting"); // connecting | open | closed | polling

  const wsRef        = useRef(null);
  const pollRef      = useRef(null);
  const mountedRef   = useRef(true);
  const reconnectRef = useRef(null);

  // ── Fetch via REST ─────────────────────────────────────────────────────────
  const fetchRest = useCallback(async () => {
    if (!mountedRef.current) return;
    try {
      setLoading(true);
      setError("");
      const params = { page, limit };
      if (typeFilter === "unread")                    params.isRead = false;
      else if (typeFilter && typeFilter !== "all")    params.type   = typeFilter;

      const [listRes, countRes] = await Promise.all([
        api.get("/notifications", { params }),
        api.get("/notifications/unread-count"),
      ]);

      if (!mountedRef.current) return;
      const data = Array.isArray(listRes.data) ? listRes.data
        : listRes.data?.notifications || [];
      setNotifications(data);
      setTotal(listRes.data?.total ?? data.length);
      setUnreadCount(countRes.data?.count ?? countRes.data?.unreadCount ?? 0);
    } catch (e) {
      if (mountedRef.current)
        setError(e?.response?.data?.message || "Failed to load notifications");
    } finally {
      if (mountedRef.current) setLoading(false);
    }
  }, [page, limit, typeFilter]);

  // ── Start polling fallback ─────────────────────────────────────────────────
  const startPolling = useCallback(() => {
    if (pollRef.current) return;
    setWsStatus("polling");
    pollRef.current = setInterval(fetchRest, POLL_INTERVAL);
  }, [fetchRest]);

  const stopPolling = useCallback(() => {
    if (pollRef.current) { clearInterval(pollRef.current); pollRef.current = null; }
  }, []);

  // ── Connect WebSocket ──────────────────────────────────────────────────────
  const connectWs = useCallback(() => {
    if (!mountedRef.current) return;
    const token = localStorage.getItem("token");
    if (!token) { startPolling(); return; }

    try {
      setWsStatus("connecting");
      const ws = new WebSocket(`${WS_BASE}/ws/notifications?token=${encodeURIComponent(token)}`);
      wsRef.current = ws;

      ws.onopen = () => {
        if (!mountedRef.current) return;
        setWsStatus("open");
        stopPolling(); // WS is live — no need to poll
      };

      ws.onmessage = ({ data }) => {
        if (!mountedRef.current) return;
        try {
          const msg = JSON.parse(data);
          handleWsMessage(msg);
        } catch { /* ignore malformed */ }
      };

      ws.onerror = () => { /* handled in onclose */ };

      ws.onclose = () => {
        if (!mountedRef.current) return;
        setWsStatus("closed");
        wsRef.current = null;
        startPolling();                                          // fallback while reconnecting
        reconnectRef.current = setTimeout(connectWs, RECONNECT_MS); // retry
      };
    } catch {
      startPolling(); // WebSocket API not available (e.g. old browser)
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [startPolling, stopPolling]);

  // ── Handle incoming WS message ─────────────────────────────────────────────
  const handleWsMessage = (msg) => {
    switch (msg.type) {
      case "notification_new":
        setNotifications(prev => [msg.data, ...prev.slice(0, limit - 1)]);
        setUnreadCount(c => c + 1);
        setTotal(t => t + 1);
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

  // ── Mount / unmount lifecycle ──────────────────────────────────────────────
  useEffect(() => {
    mountedRef.current = true;
    fetchRest();
    connectWs();
    return () => {
      mountedRef.current = false;
      wsRef.current?.close();
      stopPolling();
      if (reconnectRef.current) clearTimeout(reconnectRef.current);
    };
  }, []); // eslint-disable-line react-hooks/exhaustive-deps

  // Re-fetch when pagination or filter changes
  useEffect(() => { fetchRest(); }, [fetchRest]);

  // ── CRUD actions (optimistic) ──────────────────────────────────────────────
  const markRead = useCallback(async (id) => {
    setNotifications(prev => prev.map(n => n._id === id ? { ...n, isRead: true } : n));
    setUnreadCount(c => Math.max(0, c - 1));
    try { await api.patch(`/notifications/${id}/read`); }
    catch { fetchRest(); }
  }, [fetchRest]);

  const markAllRead = useCallback(async () => {
    setNotifications(prev => prev.map(n => ({ ...n, isRead: true })));
    setUnreadCount(0);
    try { await api.patch("/notifications/mark-all-read"); }
    catch { fetchRest(); }
  }, [fetchRest]);

  const deleteNotif = useCallback(async (id) => {
    const target = notifications.find(n => n._id === id);
    setNotifications(prev => prev.filter(n => n._id !== id));
    setTotal(t => Math.max(0, t - 1));
    if (target && !target.isRead) setUnreadCount(c => Math.max(0, c - 1));
    try { await api.delete(`/notifications/${id}`); }
    catch { fetchRest(); }
  }, [notifications, fetchRest]);

  return {
    notifications, unreadCount, total,
    loading, error, wsStatus,
    markRead, markAllRead, deleteNotif,
    refresh: fetchRest,
  };
}