import React, { useState, useEffect, useRef } from 'react';
import { createPortal } from 'react-dom';
import { Link } from 'react-router-dom';
import {
  ArrowLeft, Lock, Clock, ChevronRight, ChevronDown, Loader2, UserCheck, X, Check,
  Eye, MessageCircle, Search, AlertCircle,
} from 'lucide-react';
import api from '../../lib/api';
import {
  getPrivacyStatus, setAccountPrivacy,
  getFollowRequests, acceptFollowRequest, declineFollowRequest,
} from '../../services/followService';

/* ─────────────────────────── constants ────────────────────────── */
const fmt = (n = 0) => {
  if (n >= 1_000_000) return (n / 1_000_000).toFixed(1) + 'M';
  if (n >= 1_000)     return (n / 1_000).toFixed(1) + 'k';
  return String(n);
};

const VIS_OPTIONS = [
  { label: 'Everyone',       value: 'everyone' },
  { label: 'Followers Only', value: 'followers_only' },
  { label: 'Nobody',         value: 'nobody' },
];

const VISIBILITY_FIELDS = [
  { key: 'profile',        label: 'Profile' },
  { key: 'posts',          label: 'Moments' },
  { key: 'stories',        label: 'Glimpses' },
  { key: 'pulse',          label: 'Pulse' },
  { key: 'followers_list', label: 'Followers List' },
  { key: 'following_list', label: 'Following List' },
];

const DISCOVERY_FIELDS = [
  { key: 'allow_search_by_username', label: 'Allow Search by Username' },
  { key: 'allow_search_by_email',    label: 'Allow Search by Email' },
  { key: 'allow_search_by_phone',    label: 'Allow Search by Phone' },
  { key: 'appear_in_suggestions',    label: 'Appear in Suggestions' },
];

const DEFAULT_STATE = {
  profile_visibility: {
    profile: 'everyone', posts: 'everyone', stories: 'everyone',
    pulse: 'everyone', followers_list: 'everyone', following_list: 'everyone',
  },
  activity_status: {
    show_online_status: true, show_last_seen: true, show_read_receipts: true,
  },
  follow_settings: {
    allow_follow_requests: true, auto_approve_follow_requests: false,
  },
  messaging_privacy: 'everyone',
  search_discovery: {
    allow_search_by_username: true, allow_search_by_email: false,
    allow_search_by_phone: false, appear_in_suggestions: true,
  },
};

/* ─────────────────────────── sub-components ───────────────────── */
const SectionTitle = ({ title }) => (
  <p className="text-[11px] font-bold text-[#fa3f5e] uppercase tracking-widest mb-2 px-1">{title}</p>
);

const Toggle = ({ on, onChange }) => (
  <label className="relative inline-flex items-center flex-shrink-0 cursor-pointer">
    <input type="checkbox" checked={on} onChange={onChange} className="sr-only peer" />
    <div className={`w-11 h-6 rounded-full transition-colors duration-200 ${on ? 'bg-[#fa3f5e]' : 'bg-gray-300 dark:bg-gray-700'}`} />
    <div className={`absolute left-0.5 top-0.5 w-5 h-5 bg-white rounded-full shadow transform transition-transform duration-200 ${on ? 'translate-x-5' : 'translate-x-0'}`} />
  </label>
);

const ToggleRow = ({ label, sublabel, on, onChange, disabled }) => (
  <div className="flex items-center justify-between px-4 py-3.5 border-b border-gray-100 dark:border-gray-800 last:border-0">
    <div className="flex-1 min-w-0 pr-3">
      <p className={`text-sm font-medium ${disabled ? 'text-gray-400 dark:text-gray-500' : 'text-gray-900 dark:text-white'}`}>{label}</p>
      {sublabel && <p className="text-xs text-gray-500 dark:text-gray-400 mt-0.5">{sublabel}</p>}
    </div>
    <Toggle on={on} onChange={onChange} />
  </div>
);

/* Always-interactive custom dropdown — portal-based to escape overflow:hidden cards */
const DropdownRow = ({ label, value, onChange }) => {
  const [open, setOpen] = useState(false);
  const [dropPos, setDropPos] = useState({ top: 0, left: 0 });
  const btnRef = useRef(null);
  const dropRef = useRef(null);

  useEffect(() => {
    if (!open) return;
    const onMouse = (e) => {
      if (
        btnRef.current && !btnRef.current.contains(e.target) &&
        dropRef.current && !dropRef.current.contains(e.target)
      ) setOpen(false);
    };
    const onScroll = () => setOpen(false);
    document.addEventListener('mousedown', onMouse);
    window.addEventListener('scroll', onScroll, true);
    return () => {
      document.removeEventListener('mousedown', onMouse);
      window.removeEventListener('scroll', onScroll, true);
    };
  }, [open]);

  const handleToggle = () => {
    if (!open && btnRef.current) {
      const rect = btnRef.current.getBoundingClientRect();
      const dropHeight = VIS_OPTIONS.length * 44 + 8;
      const spaceBelow = window.innerHeight - rect.bottom - 8;
      const top = spaceBelow >= dropHeight ? rect.bottom + 6 : rect.top - dropHeight - 6;
      setDropPos({ top, left: rect.right - 154 });
    }
    setOpen(v => !v);
  };

  const current = VIS_OPTIONS.find(o => o.value === value);

  return (
    <div className="flex items-center justify-between px-4 py-3.5 border-b border-gray-100 dark:border-gray-800 last:border-0">
      <p className="text-sm font-medium text-gray-900 dark:text-white flex-1 pr-3">{label}</p>
      <div className="flex-shrink-0">
        <button
          ref={btnRef}
          type="button"
          onClick={handleToggle}
          className="flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-semibold border transition-all bg-[#fa3f5e]/8 border-[#fa3f5e]/25 text-[#fa3f5e] hover:bg-[#fa3f5e]/15 dark:bg-pink-900/20 dark:border-pink-800/30 dark:text-pink-400 min-w-[110px] justify-between"
        >
          <span>{current?.label ?? value}</span>
          <ChevronDown size={11} className={`transition-transform duration-200 flex-shrink-0 ${open ? 'rotate-180' : ''}`} />
        </button>

        {open && createPortal(
          <div
            ref={dropRef}
            style={{ position: 'fixed', top: dropPos.top, left: dropPos.left, zIndex: 9999 }}
            className="bg-white dark:bg-gray-900 border border-gray-100 dark:border-gray-800 rounded-2xl shadow-2xl shadow-black/10 dark:shadow-black/40 overflow-hidden min-w-[154px] py-1"
          >
            {VIS_OPTIONS.map(o => (
              <button
                key={o.value}
                type="button"
                onClick={() => { onChange(o.value); setOpen(false); }}
                className={`w-full flex items-center justify-between px-4 py-2.5 text-sm transition-colors hover:bg-gray-50 dark:hover:bg-gray-800 ${
                  o.value === value
                    ? 'font-semibold text-[#fa3f5e] dark:text-pink-400'
                    : 'font-medium text-gray-700 dark:text-gray-300'
                }`}
              >
                <span>{o.label}</span>
                {o.value === value && <Check size={13} className="flex-shrink-0" />}
              </button>
            ))}
          </div>,
          document.body
        )}
      </div>
    </div>
  );
};

/* ─────────────────────────── main component ───────────────────── */
const PrivacySettings = () => {
  const snapshot = useRef(null);
  const [isDirty, setIsDirty] = useState(false);

  const [isPrivate, setIsPrivate]       = useState(false);
  const [pendingCount, setPendingCount] = useState(0);
  const [loadingBase, setLoadingBase]   = useState(true);
  const [toggling, setToggling]         = useState(false);

  const [settings, setSettings]   = useState(DEFAULT_STATE);
  const [saving, setSaving]       = useState(false);
  const [saved, setSaved]         = useState(false);
  const [saveError, setSaveError] = useState('');

  const [requests, setRequests]           = useState([]);
  const [loadingReqs, setLoadingReqs]     = useState(false);
  const [showReqs, setShowReqs]           = useState(false);
  const [actionLoading, setActionLoading] = useState({});

  const [toast, setToast] = useState(null);
  const showToast = (msg, type = 'success') => {
    setToast({ msg, type });
    setTimeout(() => setToast(null), 3000);
  };

  /* ── load ─────────────────────────────────────────────────────── */
  useEffect(() => {
    Promise.allSettled([
      getPrivacyStatus(),
      api.get('/privacy'),
    ]).then(([privRes, settingsRes]) => {
      if (privRes.status === 'fulfilled') {
        setIsPrivate(privRes.value.isPrivate);
        setPendingCount(privRes.value.pendingRequestsCount || 0);
      }
      if (settingsRes.status === 'fulfilled') {
        const d = settingsRes.value.data;
        const loaded = {
          profile_visibility: { ...DEFAULT_STATE.profile_visibility, ...(d.profile_visibility || {}) },
          activity_status:    { ...DEFAULT_STATE.activity_status,    ...(d.activity_status    || {}) },
          follow_settings:    { ...DEFAULT_STATE.follow_settings,    ...(d.follow_settings    || {}) },
          messaging_privacy:  d.messaging_privacy ?? DEFAULT_STATE.messaging_privacy,
          search_discovery:   { ...DEFAULT_STATE.search_discovery,   ...(d.search_discovery   || {}) },
        };
        setSettings(loaded);
        snapshot.current = loaded;
      }
    }).finally(() => setLoadingBase(false));
  }, []);

  /* ── dirty updaters ───────────────────────────────────────────── */
  const mark = () => setIsDirty(true);
  const updVis  = (key, val) => { setSettings(p => ({ ...p, profile_visibility: { ...p.profile_visibility, [key]: val } })); mark(); };
  const updAct  = (key, val) => { setSettings(p => ({ ...p, activity_status:    { ...p.activity_status,    [key]: val } })); mark(); };
  const updFol  = (key, val) => { setSettings(p => ({ ...p, follow_settings:    { ...p.follow_settings,    [key]: val } })); mark(); };
  const updDisc = (key, val) => { setSettings(p => ({ ...p, search_discovery:   { ...p.search_discovery,   [key]: val } })); mark(); };
  const updMsg  = (val)      => { setSettings(p => ({ ...p, messaging_privacy: val })); mark(); };

  /* ── cancel ───────────────────────────────────────────────────── */
  const handleCancel = () => {
    if (snapshot.current) setSettings(snapshot.current);
    setIsDirty(false);
    setSaveError('');
  };

  /* ── save ─────────────────────────────────────────────────────── */
  const handleSave = async () => {
    setSaving(true); setSaveError('');
    try {
      await Promise.all([
        api.patch('/privacy/profile-visibility', settings.profile_visibility),
        api.patch('/privacy/activity-status',    settings.activity_status),
        api.patch('/privacy/follow-settings',    settings.follow_settings),
        api.patch('/privacy/messaging',          { messaging_privacy: settings.messaging_privacy }),
        api.patch('/privacy/search-discovery',   settings.search_discovery),
      ]);
      snapshot.current = { ...settings };
      setIsDirty(false);
      setSaved(true);
      setTimeout(() => setSaved(false), 3000);
      showToast('Privacy settings saved.');
    } catch (e) {
      setSaveError(e?.response?.data?.message || 'Failed to save. Try again.');
    } finally { setSaving(false); }
  };

  /* ── public/private toggle ────────────────────────────────────── */
  const handleTogglePrivacy = async () => {
    if (toggling) return;
    setToggling(true);
    try {
      const result = await setAccountPrivacy(!isPrivate);
      setIsPrivate(result.isPrivate);
      if (!result.isPrivate) { setPendingCount(0); setRequests([]); }
      showToast(result.message || `Account is now ${result.isPrivate ? 'private' : 'public'}`);
    } catch { showToast('Failed to update privacy.', 'error'); }
    finally { setToggling(false); }
  };

  /* ── follow requests ──────────────────────────────────────────── */
  const handleLoadRequests = async () => {
    if (showReqs) { setShowReqs(false); return; }
    setLoadingReqs(true); setShowReqs(true);
    try {
      const data = await getFollowRequests();
      setRequests(data.requests || []);
      setPendingCount(data.count || 0);
    } catch { showToast('Failed to load follow requests.', 'error'); }
    finally { setLoadingReqs(false); }
  };

  const handleAccept = async (reqId) => {
    setActionLoading(p => ({ ...p, [reqId]: 'accept' }));
    try {
      await acceptFollowRequest(reqId);
      setRequests(p => p.filter(r => (r._id || r.id) !== reqId));
      setPendingCount(p => Math.max(0, p - 1));
      showToast('Follow request accepted.');
    } catch { showToast('Failed to accept.', 'error'); }
    finally { setActionLoading(p => { const n = { ...p }; delete n[reqId]; return n; }); }
  };

  const handleDecline = async (reqId) => {
    setActionLoading(p => ({ ...p, [reqId]: 'decline' }));
    try {
      await declineFollowRequest(reqId);
      setRequests(p => p.filter(r => (r._id || r.id) !== reqId));
      setPendingCount(p => Math.max(0, p - 1));
      showToast('Request declined.');
    } catch { showToast('Failed to decline.', 'error'); }
    finally { setActionLoading(p => { const n = { ...p }; delete n[reqId]; return n; }); }
  };

  const getInitials = (name) => (name || 'U').split(' ').map(n => n[0]).join('').toUpperCase().slice(0, 2);

  /* ── render ───────────────────────────────────────────────────── */
  return (
    <div className="min-h-screen bg-gray-50 dark:bg-black pb-10 max-w-[1100px] mx-auto">

      {/* Toast */}
      {toast && (
        <div className={`fixed top-20 right-4 z-[80] rounded-xl border px-4 py-3 text-sm font-semibold shadow-lg ${
          toast.type === 'success'
            ? 'border-green-200 bg-green-50 text-green-700 dark:border-green-800 dark:bg-green-900/20 dark:text-green-400'
            : 'border-red-200 bg-red-50 text-red-700 dark:border-red-800 dark:bg-red-900/20 dark:text-red-400'
        }`}>{toast.msg}</div>
      )}

      {/* Header */}
      <div className="sticky top-0 bg-white dark:bg-black border-b border-gray-100 dark:border-gray-800 px-4 py-3 flex items-center justify-between z-40">
        <Link to="/settings" className="text-gray-800 dark:text-white p-1"><ArrowLeft size={22} /></Link>
        <h1 className="text-base font-semibold dark:text-white">Privacy</h1>
        {isDirty ? (
          <div className="flex items-center gap-2">
            <button
              onClick={handleCancel}
              className="px-3 py-1.5 rounded-full border border-gray-200 dark:border-gray-700 text-gray-600 dark:text-gray-400 text-sm font-semibold hover:bg-gray-50 dark:hover:bg-gray-900 transition-colors"
            >
              Discard
            </button>
            <button
              onClick={handleSave}
              disabled={saving}
              className="px-4 py-1.5 rounded-full bg-[#fa3f5e] text-white text-sm font-bold disabled:opacity-60 flex items-center gap-1.5 hover:opacity-90 transition-opacity"
            >
              {saving ? <><Loader2 size={13} className="animate-spin" /> Saving…</> : saved ? <><Check size={13} /> Saved!</> : 'Save'}
            </button>
          </div>
        ) : (
          <div className="w-8" />
        )}
      </div>

      <div className="max-w-2xl mx-auto px-4 pt-5 space-y-5">

        {saveError && (
          <div className="flex items-center gap-2 px-3 py-2.5 rounded-xl bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 text-red-600 dark:text-red-400 text-sm">
            <AlertCircle size={14} className="shrink-0" /> {saveError}
          </div>
        )}

        {/* ── Account Privacy ─────────────────────────────────────── */}
        <div>
          <SectionTitle title="Account Privacy" />
          <div className="bg-white dark:bg-gray-900 rounded-2xl border border-gray-100 dark:border-gray-800 shadow-sm overflow-hidden">

            <div className="flex items-center justify-between px-4 py-3.5">
              <div className="flex items-center gap-3 flex-1 min-w-0">
                <div className="w-9 h-9 rounded-full bg-pink-50 dark:bg-gray-800 flex items-center justify-center text-[#fa3f5e] flex-shrink-0">
                  <Lock size={18} />
                </div>
                <div className="min-w-0">
                  <p className="text-sm font-semibold text-gray-900 dark:text-white">Private Account</p>
                  <p className="text-xs text-gray-500 dark:text-gray-400">
                    {loadingBase ? 'Loading…' : isPrivate
                      ? 'Only approved followers can see your posts'
                      : 'Anyone can see your posts'}
                  </p>
                </div>
              </div>
              {toggling
                ? <Loader2 size={16} className="animate-spin text-gray-400 flex-shrink-0" />
                : <Toggle on={isPrivate} onChange={handleTogglePrivacy} />
              }
            </div>

            {isPrivate && (
              <>
                <div className="h-px bg-gray-100 dark:bg-gray-800" />
                <button onClick={handleLoadRequests}
                  className="w-full flex items-center justify-between px-4 py-3.5 hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors">
                  <div className="flex items-center gap-3">
                    <div className="w-9 h-9 rounded-full bg-pink-50 dark:bg-gray-800 flex items-center justify-center text-[#fa3f5e] flex-shrink-0">
                      <Clock size={18} />
                    </div>
                    <div className="text-left">
                      <p className="text-sm font-medium text-gray-900 dark:text-white">Follow Requests</p>
                      <p className="text-xs text-gray-500 dark:text-gray-400">
                        {pendingCount > 0 ? `${pendingCount} pending` : 'No pending requests'}
                      </p>
                    </div>
                  </div>
                  <div className="flex items-center gap-2">
                    {pendingCount > 0 && (
                      <span className="text-[11px] font-bold bg-[#fa3f5e] text-white w-5 h-5 rounded-full flex items-center justify-center">
                        {pendingCount > 9 ? '9+' : pendingCount}
                      </span>
                    )}
                    <ChevronRight size={16} className={`text-gray-400 transition-transform ${showReqs ? 'rotate-90' : ''}`} />
                  </div>
                </button>

                {showReqs && (
                  <div className="border-t border-gray-100 dark:border-gray-800">
                    {loadingReqs ? (
                      <div className="flex items-center justify-center py-8 gap-2 text-gray-400">
                        <Loader2 size={16} className="animate-spin" />
                        <span className="text-sm">Loading…</span>
                      </div>
                    ) : requests.length === 0 ? (
                      <div className="flex flex-col items-center py-10 text-center px-4">
                        <div className="w-12 h-12 rounded-full bg-gray-100 dark:bg-gray-800 flex items-center justify-center mb-3">
                          <UserCheck size={22} className="text-gray-400" />
                        </div>
                        <p className="text-sm font-medium text-gray-700 dark:text-gray-300">No pending requests</p>
                      </div>
                    ) : (
                      <div className="divide-y divide-gray-100 dark:divide-gray-800">
                        {requests.map((req) => {
                          const reqId = req._id || req.id;
                          const isActing = actionLoading[reqId];
                          return (
                            <div key={reqId} className="flex items-center gap-3 px-4 py-3">
                              <div className="w-10 h-10 rounded-full overflow-hidden bg-gradient-to-br from-gray-200 to-gray-300 dark:from-gray-700 dark:to-gray-800 flex-shrink-0">
                                {req.profilePicture
                                  ? <img src={req.profilePicture} alt={req.username} className="w-full h-full object-cover" />
                                  : <div className="w-full h-full flex items-center justify-center text-xs font-bold text-gray-500">{getInitials(req.username)}</div>
                                }
                              </div>
                              <div className="flex-1 min-w-0">
                                <p className="font-semibold text-sm text-gray-900 dark:text-white truncate">{req.username}</p>
                                <p className="text-[11px] text-gray-400">{fmt(req.followers_count || 0)} followers</p>
                              </div>
                              <div className="flex items-center gap-1.5 flex-shrink-0">
                                <button onClick={() => handleAccept(reqId)} disabled={!!isActing}
                                  className="px-3 py-1.5 bg-[#fa3f5e] text-white text-xs font-bold rounded-lg hover:opacity-90 disabled:opacity-50 flex items-center gap-1">
                                  {isActing === 'accept' ? <Loader2 size={11} className="animate-spin" /> : <Check size={11} />} Confirm
                                </button>
                                <button onClick={() => handleDecline(reqId)} disabled={!!isActing}
                                  className="px-3 py-1.5 bg-gray-100 dark:bg-gray-800 text-gray-700 dark:text-gray-300 text-xs font-bold rounded-lg hover:bg-gray-200 dark:hover:bg-gray-700 disabled:opacity-50 flex items-center gap-1">
                                  {isActing === 'decline' ? <Loader2 size={11} className="animate-spin" /> : <X size={11} />} Delete
                                </button>
                              </div>
                            </div>
                          );
                        })}
                      </div>
                    )}
                  </div>
                )}
              </>
            )}
          </div>
        </div>

        {/* ── Profile Visibility ──────────────────────────────────── */}
        <div>
          <SectionTitle title="Profile Visibility" />
          <div className="bg-white dark:bg-gray-900 rounded-2xl border border-gray-100 dark:border-gray-800 shadow-sm overflow-hidden">
            <div className="flex items-center gap-3 px-4 pt-3 pb-2 border-b border-gray-100 dark:border-gray-800">
              <Eye size={15} className="text-gray-400 flex-shrink-0" />
              <p className="text-xs text-gray-500 dark:text-gray-400">Choose who can see each section of your profile</p>
            </div>
            {VISIBILITY_FIELDS.map(({ key, label }) => (
              <DropdownRow key={key} label={label}
                value={settings.profile_visibility[key] || 'everyone'}
                onChange={val => updVis(key, val)} />
            ))}
          </div>
        </div>

        {/* ── Activity Status ─────────────────────────────────────── */}
        <div>
          <SectionTitle title="Activity Status" />
          <div className="bg-white dark:bg-gray-900 rounded-2xl border border-gray-100 dark:border-gray-800 shadow-sm overflow-hidden">
            <ToggleRow label="Show Online Status"
              sublabel="Others can see the green dot when you're active"
              on={settings.activity_status.show_online_status}
              onChange={e => updAct('show_online_status', e.target.checked)} />
            <ToggleRow label="Show Last Seen"
              sublabel="Others can see when you were last active"
              on={settings.activity_status.show_last_seen}
              onChange={e => updAct('show_last_seen', e.target.checked)} />
            <ToggleRow label="Show Read Receipts"
              sublabel="Others can see when you've read their messages"
              on={settings.activity_status.show_read_receipts}
              onChange={e => updAct('show_read_receipts', e.target.checked)} />
          </div>
        </div>

        {/* ── Follow Settings ─────────────────────────────────────── */}
        <div>
          <SectionTitle title="Follow Settings" />
          <div className="bg-white dark:bg-gray-900 rounded-2xl border border-gray-100 dark:border-gray-800 shadow-sm overflow-hidden">
            <ToggleRow label="Allow Follow Requests"
              sublabel="Let people send you follow requests"
              on={settings.follow_settings.allow_follow_requests}
              onChange={e => updFol('allow_follow_requests', e.target.checked)} />
            <ToggleRow label="Auto Approve Follow Requests"
              sublabel="Automatically accept all incoming follow requests"
              on={settings.follow_settings.auto_approve_follow_requests}
              onChange={e => updFol('auto_approve_follow_requests', e.target.checked)}
              disabled={!settings.follow_settings.allow_follow_requests} />
          </div>
        </div>

        {/* ── Messaging Privacy ───────────────────────────────────── */}
        <div>
          <SectionTitle title="Messaging Privacy" />
          <div className="bg-white dark:bg-gray-900 rounded-2xl border border-gray-100 dark:border-gray-800 shadow-sm overflow-hidden">
            <div className="flex items-center gap-3 px-4 pt-3 pb-2 border-b border-gray-100 dark:border-gray-800">
              <MessageCircle size={15} className="text-gray-400 flex-shrink-0" />
              <p className="text-xs text-gray-500 dark:text-gray-400">Who can send you direct messages</p>
            </div>
            <DropdownRow label="Allow Messages From"
              value={settings.messaging_privacy}
              onChange={updMsg} />
          </div>
        </div>

        {/* ── Search & Discovery ──────────────────────────────────── */}
        <div>
          <SectionTitle title="Search & Discovery" />
          <div className="bg-white dark:bg-gray-900 rounded-2xl border border-gray-100 dark:border-gray-800 shadow-sm overflow-hidden">
            <div className="flex items-center gap-3 px-4 pt-3 pb-2 border-b border-gray-100 dark:border-gray-800">
              <Search size={15} className="text-gray-400 flex-shrink-0" />
              <p className="text-xs text-gray-500 dark:text-gray-400">Control how other people can find your account</p>
            </div>
            {DISCOVERY_FIELDS.map(({ key, label }) => (
              <ToggleRow key={key} label={label}
                on={settings.search_discovery[key] ?? true}
                onChange={e => updDisc(key, e.target.checked)} />
            ))}
          </div>
        </div>

      </div>


    </div>
  );
};

export default PrivacySettings;
