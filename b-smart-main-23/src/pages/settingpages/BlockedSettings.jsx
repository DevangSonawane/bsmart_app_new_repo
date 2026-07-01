import React, { useState, useEffect, useCallback } from 'react';
import { Link } from 'react-router-dom';
import {
  ArrowLeft, UserX, ShieldAlert, VolumeX,
  Loader2, AlertCircle, RefreshCw, User, ChevronRight, ChevronDown,
} from 'lucide-react';
import api from '../../lib/api';

const SectionTitle = ({ title }) => (
  <p className="text-[11px] font-bold text-[#fa3f5e] uppercase tracking-widest mb-2 px-1">{title}</p>
);

const EmptyState = ({ icon: Icon, label }) => (
  <div className="flex flex-col items-center py-10 gap-3 text-gray-400 dark:text-gray-600">
    <div className="w-12 h-12 rounded-full bg-gray-100 dark:bg-gray-800 flex items-center justify-center">
      <Icon size={22} />
    </div>
    <p className="text-sm">{label}</p>
  </div>
);

const UserRow = ({ user, actionLabel, actionColor, onAction, loading }) => {
  const name    = user.full_name || user.username || 'Unknown';
  const handle  = user.username ? `@${user.username}` : '';
  const initials = name.slice(0, 1).toUpperCase();

  return (
    <div className="flex items-center gap-3 px-4 py-3 border-b border-gray-100 dark:border-gray-800 last:border-0">
      <div className="w-10 h-10 rounded-full overflow-hidden bg-gradient-to-br from-gray-200 to-gray-300 dark:from-gray-700 dark:to-gray-800 flex-shrink-0 flex items-center justify-center">
        {user.avatar_url
          ? <img src={user.avatar_url} alt={name} className="w-full h-full object-cover" />
          : <span className="text-xs font-bold text-gray-500 dark:text-gray-300">{initials}</span>
        }
      </div>
      <div className="flex-1 min-w-0">
        <p className="text-sm font-semibold text-gray-900 dark:text-white truncate">{name}</p>
        {handle && <p className="text-xs text-gray-400 dark:text-gray-500">{handle}</p>}
      </div>
      <button
        onClick={() => onAction(user._id || user.id)}
        disabled={loading}
        className={`flex-shrink-0 px-3 py-1.5 rounded-xl text-xs font-bold border transition-all disabled:opacity-60 ${actionColor}`}
      >
        {loading ? <Loader2 size={12} className="animate-spin" /> : actionLabel}
      </button>
    </div>
  );
};

const Section = ({ id, title, icon: Icon, iconBg, iconColor, openId, setOpenId, children, badge }) => {
  const open = openId === id;
  return (
    <div className={`bg-white dark:bg-gray-900 rounded-2xl border shadow-sm overflow-hidden transition-all ${open ? 'border-gray-200 dark:border-gray-700' : 'border-gray-100 dark:border-gray-800'}`}>
      <button
        onClick={() => setOpenId(open ? '' : id)}
        className="w-full flex items-center justify-between px-4 py-3.5 hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors"
      >
        <div className="flex items-center gap-3">
          <div className={`w-9 h-9 rounded-full flex items-center justify-center flex-shrink-0 ${iconBg}`}>
            <Icon size={16} className={iconColor} />
          </div>
          <div className="text-left">
            <p className="text-sm font-semibold text-gray-900 dark:text-white">{title}</p>
          </div>
        </div>
        <div className="flex items-center gap-2">
          {badge > 0 && (
            <span className="text-[11px] font-bold bg-[#fa3f5e] text-white min-w-[20px] h-5 rounded-full flex items-center justify-center px-1">
              {badge > 99 ? '99+' : badge}
            </span>
          )}
          <ChevronDown
            size={16}
            className={`text-gray-400 transition-transform duration-200 ${open ? 'rotate-180' : ''}`}
          />
        </div>
      </button>
      {open && (
        <div className="border-t border-gray-100 dark:border-gray-800">
          {children}
        </div>
      )}
    </div>
  );
};

const BlockedSettings = () => {
  const [openId, setOpenId]           = useState('blocked');
  const [blocked, setBlocked]         = useState([]);
  const [restricted, setRestricted]   = useState([]);
  const [muted, setMuted]             = useState([]);
  const [loading, setLoading]         = useState({ blocked: false, restricted: false, muted: false });
  const [actionLoading, setActionLoading] = useState({});
  const [error, setError]             = useState({});

  const setLoad = (key, val) => setLoading(p => ({ ...p, [key]: val }));
  const setErr  = (key, val) => setError(p => ({ ...p, [key]: val }));

  const fetchSection = useCallback(async (key, endpoint, setter) => {
    setLoad(key, true); setErr(key, '');
    try {
      const res = await api.get(endpoint);
      const data = res.data;
      // Backend returns { users: [...] } per spec
      const list = data.users ?? data.data ?? data[key] ?? [];
      setter(Array.isArray(list) ? list : []);
    } catch (e) {
      const msg = e?.response?.data?.message;
      // "User not found" means no records — treat as empty list
      if (e?.response?.status === 404 || msg === 'User not found') {
        setter([]);
      } else {
        setErr(key, msg || `Failed to load ${key} users.`);
      }
    } finally { setLoad(key, false); }
  }, []);

  useEffect(() => {
    if (openId === 'blocked')    fetchSection('blocked',    '/users/blocked',    setBlocked);
    if (openId === 'restricted') fetchSection('restricted', '/users/restricted', setRestricted);
    if (openId === 'muted')      fetchSection('muted',      '/users/muted',      setMuted);
  }, [openId, fetchSection]);

  const handleUnblock = async (userId) => {
    setActionLoading(p => ({ ...p, [userId]: true }));
    try {
      await api.delete(`/users/${userId}/block`);     // DELETE /users/:targetId/block
      setBlocked(p => p.filter(u => (u._id || u.id) !== userId));
    } catch (e) {
      console.error('Unblock failed:', e?.response?.data?.message);
    } finally {
      setActionLoading(p => { const n = { ...p }; delete n[userId]; return n; });
    }
  };

  const handleUnrestrict = async (userId) => {
    setActionLoading(p => ({ ...p, [userId]: true }));
    try {
      await api.delete(`/users/${userId}/restrict`);  // DELETE /users/:targetId/restrict
      setRestricted(p => p.filter(u => (u._id || u.id) !== userId));
    } catch (e) {
      console.error('Unrestrict failed:', e?.response?.data?.message);
    } finally {
      setActionLoading(p => { const n = { ...p }; delete n[userId]; return n; });
    }
  };

  const handleUnmute = async (userId) => {
    setActionLoading(p => ({ ...p, [userId]: true }));
    try {
      await api.delete(`/users/${userId}/mute`);      // DELETE /users/:targetId/mute
      setMuted(p => p.filter(u => (u._id || u.id) !== userId));
    } catch (e) {
      console.error('Unmute failed:', e?.response?.data?.message);
    } finally {
      setActionLoading(p => { const n = { ...p }; delete n[userId]; return n; });
    }
  };

  const ListContent = ({ list, loading: isLoading, error: err, onAction, actionLabel, actionColor, emptyIcon, emptyLabel, onRetry }) => {
    if (isLoading) return (
      <div className="flex items-center justify-center py-10 gap-2 text-gray-400">
        <Loader2 size={18} className="animate-spin" />
        <span className="text-sm">Loading…</span>
      </div>
    );
    if (err) return (
      <div className="flex flex-col items-center py-8 gap-2 text-sm text-red-500 px-4 text-center">
        <AlertCircle size={20} />
        <p>{err}</p>
        <button onClick={onRetry} className="flex items-center gap-1.5 text-xs text-[#fa3f5e] font-semibold mt-1">
          <RefreshCw size={12} /> Retry
        </button>
      </div>
    );
    if (list.length === 0) return <EmptyState icon={emptyIcon} label={emptyLabel} />;
    return (
      <div>
        {list.map(user => (
          <UserRow
            key={user._id || user.id}
            user={user}
            actionLabel={actionLabel}
            actionColor={actionColor}
            onAction={onAction}
            loading={actionLoading[user._id || user.id]}
          />
        ))}
      </div>
    );
  };

  return (
    <div className="min-h-screen bg-gray-50 dark:bg-black pb-24 max-w-[1100px] mx-auto">

      {/* Header */}
      <div className="sticky top-0 bg-white dark:bg-black border-b border-gray-100 dark:border-gray-800 px-4 py-3 flex items-center justify-between z-40">
        <Link to="/settings" className="text-gray-800 dark:text-white p-1"><ArrowLeft size={22} /></Link>
        <h1 className="text-base font-semibold dark:text-white">Blocked & Restricted</h1>
        <div className="w-8" />
      </div>

      <div className="max-w-2xl mx-auto px-4 pt-5 space-y-5">

        {/* ── Blocked Users ──────────────────────────────── */}
        <div>
          <SectionTitle title="Blocked Users" />
          <Section
            id="blocked"
            title="Blocked Users"
            icon={UserX}
            iconBg="bg-red-50 dark:bg-gray-800"
            iconColor="text-red-500"
            openId={openId}
            setOpenId={setOpenId}
            badge={blocked.length}
          >
            <ListContent
              list={blocked}
              loading={loading.blocked}
              error={error.blocked}
              onAction={handleUnblock}
              actionLabel="Unblock"
              actionColor="border-red-200 dark:border-red-800 text-red-500 hover:bg-red-50 dark:hover:bg-red-900/20"
              emptyIcon={UserX}
              emptyLabel="No blocked users"
              onRetry={() => fetchSection('blocked', '/users/blocked', setBlocked)}
            />
          </Section>
          <p className="text-xs text-gray-400 dark:text-gray-500 px-1 mt-2">
            Blocked users cannot see your profile, posts, or contact you.
          </p>
        </div>

        {/* ── Restricted Users ───────────────────────────── */}
        <div>
          <SectionTitle title="Restricted Users" />
          <Section
            id="restricted"
            title="Manage Restricted Users"
            icon={ShieldAlert}
            iconBg="bg-orange-50 dark:bg-gray-800"
            iconColor="text-orange-500"
            openId={openId}
            setOpenId={setOpenId}
            badge={restricted.length}
          >
            <ListContent
              list={restricted}
              loading={loading.restricted}
              error={error.restricted}
              onAction={handleUnrestrict}
              actionLabel="Unrestrict"
              actionColor="border-orange-200 dark:border-orange-800 text-orange-500 hover:bg-orange-50 dark:hover:bg-orange-900/20"
              emptyIcon={ShieldAlert}
              emptyLabel="No restricted users"
              onRetry={() => fetchSection('restricted', '/users/restricted', setRestricted)}
            />
          </Section>
          <p className="text-xs text-gray-400 dark:text-gray-500 px-1 mt-2">
            Restricted users can still see your profile but their interactions are limited.
          </p>
        </div>

        {/* ── Muted Users ────────────────────────────────── */}
        <div>
          <SectionTitle title="Muted Users" />
          <Section
            id="muted"
            title="Manage Muted Accounts"
            icon={VolumeX}
            iconBg="bg-gray-100 dark:bg-gray-800"
            iconColor="text-gray-500 dark:text-gray-400"
            openId={openId}
            setOpenId={setOpenId}
            badge={muted.length}
          >
            <ListContent
              list={muted}
              loading={loading.muted}
              error={error.muted}
              onAction={handleUnmute}
              actionLabel="Unmute"
              actionColor="border-gray-200 dark:border-gray-700 text-gray-600 dark:text-gray-400 hover:bg-gray-100 dark:hover:bg-gray-800"
              emptyIcon={VolumeX}
              emptyLabel="No muted accounts"
              onRetry={() => fetchSection('muted', '/users/muted', setMuted)}
            />
          </Section>
          <p className="text-xs text-gray-400 dark:text-gray-500 px-1 mt-2">
            Muted accounts' posts won't appear in your feed, but they can still interact with you.
          </p>
        </div>

      </div>
    </div>
  );
};

export default BlockedSettings;
