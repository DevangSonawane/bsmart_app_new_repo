import { useState, useRef, useEffect, useCallback } from 'react';
import { Link } from 'react-router-dom';
import { useSelector } from 'react-redux';
import {
  ArrowLeft, Mail, Ticket, MessageSquare, BookOpen, GraduationCap,
  FileText, Bug, AlertOctagon, UserX, ChevronRight, ChevronDown, ChevronUp,
  Loader2, Check, Send, X, Search, Phone, Clock, CircleDot, CheckCircle2, Trash2, Plus
} from 'lucide-react';
import api from '../../lib/api';

const INPUT_CLS = 'w-full px-3.5 py-2.5 rounded-xl border border-gray-200 dark:border-gray-700 bg-white dark:bg-gray-900 text-sm text-gray-900 dark:text-white outline-none focus:ring-2 focus:ring-[#fa3f5e]/20 focus:border-[#fa3f5e] placeholder-gray-400 dark:placeholder-gray-600 transition-all';

const SectionTitle = ({ title }) => (
  <p className="text-[11px] font-bold text-[#fa3f5e] uppercase tracking-widest mb-2 px-1">{title}</p>
);

const Dropdown = ({ value, onChange, options, placeholder = 'Select' }) => {
  const [open, setOpen] = useState(false);
  const ref = useRef(null);
  useEffect(() => {
    const handler = (e) => { if (ref.current && !ref.current.contains(e.target)) setOpen(false); };
    document.addEventListener('mousedown', handler);
    return () => document.removeEventListener('mousedown', handler);
  }, []);
  return (
    <div ref={ref} className="relative">
      <button type="button" onClick={() => setOpen(o => !o)}
        className="w-full flex items-center justify-between px-3.5 py-2.5 rounded-xl border border-gray-200 dark:border-gray-700 bg-white dark:bg-gray-900 text-sm text-gray-900 dark:text-white hover:border-gray-300 dark:hover:border-gray-600 transition-colors">
        <span className={value ? 'capitalize' : 'text-gray-400'}>{value || placeholder}</span>
        <ChevronDown size={15} className={`text-gray-400 transition-transform duration-200 ${open ? 'rotate-180' : ''}`} />
      </button>
      {open && (
        <div className="absolute z-50 mt-1.5 w-full bg-white dark:bg-[#1c1c1e] border border-gray-200 dark:border-gray-700 rounded-xl shadow-xl overflow-hidden">
          <div className="max-h-52 overflow-y-auto py-1" style={{ scrollbarWidth: 'thin' }}>
            {options.map(opt => (
              <button key={opt.value || opt} type="button"
                onClick={() => { onChange(opt.value || opt); setOpen(false); }}
                className={`w-full text-left px-3.5 py-2.5 text-sm capitalize transition-colors ${
                  (opt.value || opt) === value ? 'bg-[#fa3f5e]/10 text-[#fa3f5e] font-semibold' : 'text-gray-700 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-white/5'
                }`}>
                <div className="flex items-center justify-between">
                  <span>{opt.label || opt}</span>
                  {(opt.value || opt) === value && <Check size={14} className="text-[#fa3f5e]" />}
                </div>
              </button>
            ))}
          </div>
        </div>
      )}
    </div>
  );
};

const Row = ({ icon: Icon, iconBg, iconColor, label, sublabel, onClick, href, badge }) => {
  const inner = (
    <div className="flex items-center justify-between px-4 py-3.5 border-b border-gray-100 dark:border-gray-800 last:border-0 hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors cursor-pointer">
      <div className="flex items-center gap-3 flex-1 min-w-0 pr-3">
        <div className={`w-9 h-9 rounded-full flex items-center justify-center flex-shrink-0 ${iconBg}`}>
          <Icon size={16} className={iconColor} />
        </div>
        <div className="min-w-0">
          <p className="text-sm font-medium text-gray-900 dark:text-white">{label}</p>
          {sublabel && <p className="text-xs text-gray-500 dark:text-gray-400 mt-0.5">{sublabel}</p>}
        </div>
      </div>
      <div className="flex items-center gap-2 flex-shrink-0">
        {badge && (
          <span className="text-[10px] font-bold px-2 py-0.5 rounded-full bg-teal-50 dark:bg-teal-900/20 text-teal-600 dark:text-teal-400 border border-teal-200 dark:border-teal-800">{badge}</span>
        )}
        <ChevronRight size={16} className="text-gray-400" />
      </div>
    </div>
  );
  if (href) return <a href={href} target="_blank" rel="noopener noreferrer">{inner}</a>;
  return <div onClick={onClick} role="button" tabIndex={0}>{inner}</div>;
};

const API_CATEGORIES = [
  { value: 'general', label: 'General' },
  { value: 'account', label: 'Account' },
  { value: 'payment', label: 'Payment' },
  { value: 'technical', label: 'Technical' },
  { value: 'other', label: 'Other' },
];

const STATUS_CONFIG = {
  open:        { label: 'Open',        color: 'text-blue-600 bg-blue-50 dark:bg-blue-900/20 border-blue-200 dark:border-blue-800', icon: CircleDot },
  in_progress: { label: 'In Progress', color: 'text-amber-600 bg-amber-50 dark:bg-amber-900/20 border-amber-200 dark:border-amber-800', icon: Clock },
  resolved:    { label: 'Resolved',    color: 'text-green-600 bg-green-50 dark:bg-green-900/20 border-green-200 dark:border-green-800', icon: CheckCircle2 },
  closed:      { label: 'Closed',      color: 'text-gray-500 bg-gray-50 dark:bg-gray-800 border-gray-200 dark:border-gray-700', icon: X },
};

const timeAgo = (d) => {
  if (!d) return '';
  const diff = Math.floor((Date.now() - new Date(d).getTime()) / 1000);
  if (diff < 60) return 'just now';
  if (diff < 3600) return `${Math.floor(diff / 60)}m ago`;
  if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`;
  if (diff < 604800) return `${Math.floor(diff / 86400)}d ago`;
  return new Date(d).toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' });
};

const StatusBadge = ({ status }) => {
  const cfg = STATUS_CONFIG[status] || STATUS_CONFIG.open;
  const Icon = cfg.icon;
  return (
    <span className={`inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[10px] font-bold border ${cfg.color}`}>
      <Icon size={10} /> {cfg.label}
    </span>
  );
};

// ── Inline Submit Form (shared by Contact Support & Raise Ticket) ─────────
const InlineSubmitForm = ({ onCreated, showNameFields }) => {
  const { userObject } = useSelector(s => s.auth);
  const [form, setForm] = useState({
    name: userObject?.full_name || '',
    email: userObject?.email || '',
    phone: userObject?.phone || userObject?.mobile_number || '',
    subject: '', message: '', category: 'general',
  });
  const [sending, setSending] = useState(false);
  const [sent, setSent] = useState(false);
  const [error, setError] = useState('');
  const upd = (k, v) => setForm(p => ({ ...p, [k]: v }));

  const handleSend = async () => {
    if (showNameFields && !form.name.trim()) { setError('Please enter your name.'); return; }
    if (showNameFields && !form.email.trim()) { setError('Please enter your email.'); return; }
    if (!form.subject.trim() || !form.message.trim()) { setError('Please fill in subject and message.'); return; }
    setSending(true); setError('');
    try {
      const msg = showNameFields
        ? `Name: ${form.name}\nEmail: ${form.email}\nPhone: ${form.phone || 'N/A'}\n\n${form.message}`
        : form.message;
      await api.post('/support-queries', { subject: form.subject, message: msg, category: form.category, app_source: 'bsmart' });
      setSent(true);
      onCreated?.();
    } catch (e) {
      setError(e?.response?.data?.message || 'Failed to send. Try again.');
    } finally { setSending(false); }
  };

  if (sent) return (
    <div className="flex flex-col items-center py-8 gap-3">
      <div className="w-12 h-12 rounded-full bg-green-50 dark:bg-green-900/20 flex items-center justify-center"><Check size={22} className="text-green-500" /></div>
      <p className="text-sm font-bold text-gray-900 dark:text-white">Submitted!</p>
      <button onClick={() => { setSent(false); setForm(p => ({ ...p, subject: '', message: '' })); }}
        className="text-xs text-[#fa3f5e] font-semibold">Submit Another</button>
    </div>
  );

  return (
    <div className="space-y-3">
      {error && <div className="flex items-center gap-2 px-3 py-2 rounded-xl bg-red-50 dark:bg-red-900/20 text-red-600 dark:text-red-400 text-xs"><AlertOctagon size={13} /> {error}</div>}
      {showNameFields && (
        <>
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <div>
              <label className="text-xs font-semibold text-gray-500 dark:text-gray-400 mb-1.5 block">Full Name <span className="text-red-400">*</span></label>
              <input value={form.name} onChange={e => upd('name', e.target.value)} placeholder="Your full name" className={INPUT_CLS} />
            </div>
            <div>
              <label className="text-xs font-semibold text-gray-500 dark:text-gray-400 mb-1.5 block">Email <span className="text-red-400">*</span></label>
              <input value={form.email} onChange={e => upd('email', e.target.value)} placeholder="you@example.com" type="email" className={INPUT_CLS} />
            </div>
          </div>
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <div>
              <label className="text-xs font-semibold text-gray-500 dark:text-gray-400 mb-1.5 block">Phone</label>
              <input value={form.phone} onChange={e => upd('phone', e.target.value)} placeholder="+91 98765 43210" type="tel" className={INPUT_CLS} />
            </div>
            <div>
              <label className="text-xs font-semibold text-gray-500 dark:text-gray-400 mb-1.5 block">Category <span className="text-red-400">*</span></label>
              <Dropdown value={form.category} onChange={v => upd('category', v)} options={API_CATEGORIES} placeholder="Select category" />
            </div>
          </div>
        </>
      )}
      {!showNameFields && (
        <div>
          <label className="text-xs font-semibold text-gray-500 dark:text-gray-400 mb-1.5 block">Category <span className="text-red-400">*</span></label>
          <Dropdown value={form.category} onChange={v => upd('category', v)} options={API_CATEGORIES} placeholder="Select category" />
        </div>
      )}
      <div>
        <label className="text-xs font-semibold text-gray-500 dark:text-gray-400 mb-1.5 block">Subject <span className="text-red-400">*</span></label>
        <input value={form.subject} onChange={e => upd('subject', e.target.value)} placeholder="Brief subject" maxLength={200} className={INPUT_CLS} />
      </div>
      <div>
        <label className="text-xs font-semibold text-gray-500 dark:text-gray-400 mb-1.5 block">Message <span className="text-red-400">*</span></label>
        <textarea value={form.message} onChange={e => upd('message', e.target.value)} rows={3} placeholder="Describe your issue…" maxLength={2000} className={`${INPUT_CLS} resize-none`} />
      </div>
      <button onClick={handleSend} disabled={sending}
        className="w-full py-3 rounded-xl bg-[#fa3f5e] text-white font-bold text-sm flex items-center justify-center gap-2 disabled:opacity-60 hover:opacity-90 transition-opacity">
        {sending ? <><Loader2 size={14} className="animate-spin" /> Sending…</> : <><Send size={14} /> Submit</>}
      </button>
    </div>
  );
};

// ── Queries list + new form panel (used by both Contact Support & Raise Ticket) ──
const QueriesWithFormPanel = ({ onOpenQuery, showNameFields, refreshKey }) => {
  const [queries, setQueries] = useState([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState('all');
  const [showForm, setShowForm] = useState(false);

  const fetchQueries = useCallback(async () => {
    setLoading(true);
    try {
      const params = { limit: 50 };
      if (filter !== 'all') params.status = filter;
      const { data } = await api.get('/support-queries/my', { params });
      setQueries(data?.queries || []);
    } catch { setQueries([]); }
    finally { setLoading(false); }
  }, [filter]);

  useEffect(() => { fetchQueries(); }, [fetchQueries, refreshKey]);

  const handleDelete = async (id, e) => {
    e.stopPropagation();
    try {
      await api.delete(`/support-queries/my/${id}`);
      setQueries(prev => prev.filter(q => q._id !== id));
    } catch { /* silent */ }
  };

  const FILTERS = ['all', 'open', 'in_progress', 'resolved', 'closed'];

  return (
    <div className="p-5 space-y-4">
      {/* Header with + button */}
      <div className="flex items-center justify-between">
        <p className="text-xs font-bold text-gray-400 dark:text-gray-500 uppercase tracking-widest">Your Queries ({queries.length})</p>
        <button onClick={() => setShowForm(f => !f)}
          className={`w-8 h-8 rounded-full flex items-center justify-center transition-all ${showForm ? 'bg-gray-200 dark:bg-gray-700 rotate-45' : 'bg-[#fa3f5e] text-white hover:opacity-90'}`}>
          <Plus size={16} className={showForm ? 'text-gray-600 dark:text-gray-300' : 'text-white'} />
        </button>
      </div>

      {/* Collapsible form */}
      {showForm && (
        <div className="bg-white dark:bg-gray-900 rounded-2xl border border-gray-100 dark:border-gray-800 p-4 shadow-sm">
          <InlineSubmitForm showNameFields={showNameFields} onCreated={() => { setShowForm(false); fetchQueries(); }} />
        </div>
      )}

      {/* Filter tabs */}
      <div className="flex gap-2 overflow-x-auto" style={{ scrollbarWidth: 'none' }}>
        {FILTERS.map(f => (
          <button key={f} onClick={() => setFilter(f)}
            className={`px-3 py-1.5 rounded-full text-[11px] font-bold whitespace-nowrap capitalize transition-all ${
              filter === f ? 'bg-gray-900 dark:bg-white text-white dark:text-black' : 'bg-gray-100 dark:bg-gray-800 text-gray-500 dark:text-gray-400'
            }`}>
            {f === 'all' ? 'All' : f.replace('_', ' ')}
          </button>
        ))}
      </div>

      {/* Query list */}
      {loading ? (
        <div className="flex items-center justify-center py-12"><Loader2 size={24} className="animate-spin text-gray-300" /></div>
      ) : queries.length === 0 ? (
        <div className="text-center py-10">
          <Ticket size={28} className="mx-auto mb-2 text-gray-300 dark:text-gray-700" />
          <p className="text-sm font-semibold text-gray-900 dark:text-white">No queries yet</p>
          <p className="text-xs text-gray-400 mt-1">Tap <span className="text-[#fa3f5e] font-bold">+</span> above to submit one</p>
        </div>
      ) : (
        <div className="space-y-2">
          {queries.map(q => (
            <div key={q._id} onClick={() => onOpenQuery(q._id)}
              className="bg-white dark:bg-gray-900 rounded-xl border border-gray-100 dark:border-gray-800 p-4 hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors cursor-pointer group">
              <div className="flex items-start justify-between gap-3 mb-2">
                <p className="text-sm font-semibold text-gray-900 dark:text-white line-clamp-1 flex-1">{q.subject}</p>
                <div className="flex items-center gap-2 shrink-0">
                  <StatusBadge status={q.status} />
                  <button onClick={(e) => handleDelete(q._id, e)}
                    className="text-gray-300 hover:text-red-500 opacity-0 group-hover:opacity-100 transition-all p-0.5"><Trash2 size={13} /></button>
                </div>
              </div>
              <p className="text-xs text-gray-500 dark:text-gray-400 line-clamp-2 mb-2">{q.message}</p>
              <div className="flex items-center gap-3 text-[10px] text-gray-400">
                <span className="capitalize">{q.category}</span>
                <span>·</span>
                <span>{timeAgo(q.createdAt)}</span>
                {q.replies?.length > 0 && <><span>·</span><span>{q.replies.length} {q.replies.length === 1 ? 'reply' : 'replies'}</span></>}
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
};

const _REMOVED_START = null; // marker
const RaiseTicketForm = ({ onCreated }) => {
  const { userObject } = useSelector(s => s.auth);
  const [form, setForm] = useState({
    name: userObject?.full_name || '',
    email: userObject?.email || '',
    phone: userObject?.phone || userObject?.mobile_number || '',
    subject: '',
    message: '',
    category: 'general',
  });
  const [sending, setSending] = useState(false);
  const [sent, setSent] = useState(false);
  const [error, setError] = useState('');
  const upd = (k, v) => setForm(p => ({ ...p, [k]: v }));

  const handleSubmit = async () => {
    if (!form.name.trim()) { setError('Please enter your name.'); return; }
    if (!form.email.trim()) { setError('Please enter your email.'); return; }
    if (!form.subject.trim() || !form.message.trim()) { setError('Please fill in subject and message.'); return; }
    setSending(true); setError('');
    try {
      await api.post('/support-queries', {
        subject: form.subject,
        message: `Name: ${form.name}\nEmail: ${form.email}\nPhone: ${form.phone || 'N/A'}\n\n${form.message}`,
        category: form.category,
        app_source: 'bsmart',
      });
      setSent(true);
      onCreated?.();
    } catch (e) {
      setError(e?.response?.data?.message || 'Failed to submit. Try again.');
    } finally { setSending(false); }
  };

  if (sent) return (
    <div className="flex flex-col items-center py-8 gap-3">
      <div className="w-12 h-12 rounded-full bg-green-50 dark:bg-green-900/20 flex items-center justify-center"><Check size={22} className="text-green-500" /></div>
      <p className="text-sm font-bold text-gray-900 dark:text-white">Ticket Raised!</p>
      <p className="text-xs text-gray-400 text-center">Track it above in your queries list.</p>
      <button onClick={() => { setSent(false); setForm(p => ({ ...p, subject: '', message: '' })); }}
        className="text-xs text-[#fa3f5e] font-semibold">Raise Another</button>
    </div>
  );

  return (
    <div className="space-y-3">
      {error && <div className="flex items-center gap-2 px-3 py-2 rounded-xl bg-red-50 dark:bg-red-900/20 text-red-600 dark:text-red-400 text-xs"><AlertOctagon size={13} /> {error}</div>}
      <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
        <div>
          <label className="text-xs font-semibold text-gray-500 dark:text-gray-400 mb-1.5 block">Full Name <span className="text-red-400">*</span></label>
          <input value={form.name} onChange={e => upd('name', e.target.value)} placeholder="Your full name" className={INPUT_CLS} />
        </div>
        <div>
          <label className="text-xs font-semibold text-gray-500 dark:text-gray-400 mb-1.5 block">Email <span className="text-red-400">*</span></label>
          <input value={form.email} onChange={e => upd('email', e.target.value)} placeholder="you@example.com" type="email" className={INPUT_CLS} />
        </div>
      </div>
      <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
        <div>
          <label className="text-xs font-semibold text-gray-500 dark:text-gray-400 mb-1.5 block">Phone Number</label>
          <input value={form.phone} onChange={e => upd('phone', e.target.value)} placeholder="+91 98765 43210" type="tel" className={INPUT_CLS} />
        </div>
        <div>
          <label className="text-xs font-semibold text-gray-500 dark:text-gray-400 mb-1.5 block">Category <span className="text-red-400">*</span></label>
          <Dropdown value={form.category} onChange={v => upd('category', v)} options={API_CATEGORIES} placeholder="Select category" />
        </div>
      </div>
      <div>
        <label className="text-xs font-semibold text-gray-500 dark:text-gray-400 mb-1.5 block">Subject <span className="text-red-400">*</span></label>
        <input value={form.subject} onChange={e => upd('subject', e.target.value)} placeholder="Brief subject" maxLength={200} className={INPUT_CLS} />
      </div>
      <div>
        <label className="text-xs font-semibold text-gray-500 dark:text-gray-400 mb-1.5 block">Message <span className="text-red-400">*</span></label>
        <textarea value={form.message} onChange={e => upd('message', e.target.value)} rows={3} placeholder="Tell us about your needs..." maxLength={2000} className={`${INPUT_CLS} resize-none`} />
      </div>
      <button onClick={handleSubmit} disabled={sending}
        className="w-full py-3 rounded-xl bg-[#fa3f5e] text-white font-bold text-sm flex items-center justify-center gap-2 disabled:opacity-60 hover:opacity-90 transition-opacity">
        {sending ? <><Loader2 size={14} className="animate-spin" /> Submitting…</> : <><Send size={14} /> Raise Ticket</>}
      </button>
    </div>
  );
};

const MyQueriesPanel = ({ onOpenQuery }) => {
  const [queries, setQueries] = useState([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState('all');

  const fetchQueries = useCallback(async () => {
    setLoading(true);
    try {
      const params = { limit: 50 };
      if (filter !== 'all') params.status = filter;
      const { data } = await api.get('/support-queries/my', { params });
      setQueries(data?.queries || []);
    } catch { setQueries([]); }
    finally { setLoading(false); }
  }, [filter]);

  useEffect(() => { fetchQueries(); }, [fetchQueries]);

  const handleDelete = async (id, e) => {
    e.stopPropagation();
    try {
      await api.delete(`/support-queries/my/${id}`);
      setQueries(prev => prev.filter(q => q._id !== id));
    } catch { /* silent */ }
  };

  const FILTERS = ['all', 'open', 'in_progress', 'resolved', 'closed'];

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <p className="text-xs font-bold text-gray-400 dark:text-gray-500 uppercase tracking-widest">Your Queries ({queries.length})</p>
      </div>

      <div className="flex gap-2 overflow-x-auto" style={{ scrollbarWidth: 'none' }}>
        {FILTERS.map(f => (
          <button key={f} onClick={() => setFilter(f)}
            className={`px-3 py-1.5 rounded-full text-[11px] font-bold whitespace-nowrap capitalize transition-all ${
              filter === f ? 'bg-gray-900 dark:bg-white text-white dark:text-black' : 'bg-gray-100 dark:bg-gray-800 text-gray-500 dark:text-gray-400'
            }`}>
            {f === 'all' ? 'All' : f.replace('_', ' ')}
          </button>
        ))}
      </div>

      {loading ? (
        <div className="flex items-center justify-center py-16"><Loader2 size={24} className="animate-spin text-gray-300" /></div>
      ) : queries.length === 0 ? (
        <div className="text-center py-10">
          <Ticket size={32} className="mx-auto mb-3 text-gray-300 dark:text-gray-700" />
          <p className="text-sm font-semibold text-gray-900 dark:text-white">No queries</p>
          <p className="text-xs text-gray-400 mt-1">{filter === 'all' ? 'Raise a ticket below to get started' : `No ${filter.replace('_', ' ')} queries`}</p>
        </div>
      ) : (
        <div className="space-y-2">
          {queries.map(q => (
            <div key={q._id} onClick={() => onOpenQuery(q._id)}
              className="bg-white dark:bg-gray-900 rounded-xl border border-gray-100 dark:border-gray-800 p-4 hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors cursor-pointer group">
              <div className="flex items-start justify-between gap-3 mb-2">
                <p className="text-sm font-semibold text-gray-900 dark:text-white line-clamp-1 flex-1">{q.subject}</p>
                <div className="flex items-center gap-2 shrink-0">
                  <StatusBadge status={q.status} />
                  <button onClick={(e) => handleDelete(q._id, e)}
                    className="text-gray-300 hover:text-red-500 opacity-0 group-hover:opacity-100 transition-all p-0.5"><Trash2 size={13} /></button>
                </div>
              </div>
              <p className="text-xs text-gray-500 dark:text-gray-400 line-clamp-2 mb-2">{q.message}</p>
              <div className="flex items-center gap-3 text-[10px] text-gray-400">
                <span className="capitalize">{q.category}</span>
                <span>·</span>
                <span>{timeAgo(q.createdAt)}</span>
                {q.replies?.length > 0 && <><span>·</span><span>{q.replies.length} {q.replies.length === 1 ? 'reply' : 'replies'}</span></>}
              </div>
            </div>
          ))}
        </div>
      )}

    </div>
  );
};

// ── Query Detail with chat-like replies ───────────────────────────────────
const QueryDetailPanel = ({ queryId, onBack }) => {
  const { userObject } = useSelector(s => s.auth);
  const currentUserId = userObject?._id || userObject?.id;
  const [query, setQuery] = useState(null);
  const [loading, setLoading] = useState(true);
  const [replyText, setReplyText] = useState('');
  const [sending, setSending] = useState(false);
  const scrollRef = useRef(null);

  const fetchQuery = useCallback(async () => {
    setLoading(true);
    try {
      const { data } = await api.get(`/support-queries/my/${queryId}`);
      setQuery(data?.query || data);
    } catch { setQuery(null); }
    finally { setLoading(false); }
  }, [queryId]);

  useEffect(() => { fetchQuery(); }, [fetchQuery]);
  useEffect(() => { if (scrollRef.current) scrollRef.current.scrollTop = scrollRef.current.scrollHeight; }, [query?.replies?.length]);

  const handleReply = async () => {
    if (!replyText.trim() || sending) return;
    const text = replyText.trim();
    setSending(true); setReplyText('');
    try {
      const { data } = await api.post(`/support-queries/my/${queryId}/reply`, { message: text });
      setQuery(data?.query || data);
    } catch { setReplyText(text); }
    finally { setSending(false); }
  };

  if (loading) return <div className="flex items-center justify-center py-24"><Loader2 size={24} className="animate-spin text-gray-300" /></div>;
  if (!query) return <div className="text-center py-16 text-gray-400">Query not found</div>;

  const isClosed = query.status === 'closed';

  return (
    <div className="flex flex-col" style={{ height: 'calc(100vh - 120px)' }}>
      {/* Header */}
      <div className="shrink-0 p-4 border-b border-gray-100 dark:border-gray-800 bg-white dark:bg-black">
        <div className="flex items-center justify-between mb-2">
          <StatusBadge status={query.status} />
          <span className="text-[10px] text-gray-400 capitalize">{query.category} · {timeAgo(query.createdAt)}</span>
        </div>
        <p className="text-sm font-bold text-gray-900 dark:text-white">{query.subject}</p>
      </div>

      {/* Messages — flex-1 with flex-col-reverse so content sticks to bottom */}
      <div ref={scrollRef} className="flex-1 overflow-y-auto flex flex-col" style={{ scrollbarWidth: 'thin' }}>
        <div className="mt-auto" />
        <div className="p-4 space-y-3">
          {/* Original message */}
          <div className="flex justify-end">
            <div className="max-w-[75%] bg-[#fa3f5e] text-white rounded-2xl rounded-br-sm px-4 py-2.5 shadow-sm">
              <p className="text-[13px] leading-relaxed">{query.message}</p>
              <p className="text-[10px] text-white/50 mt-1 text-right">{timeAgo(query.createdAt)}</p>
            </div>
          </div>

          {/* Replies */}
          {(query.replies || []).map(reply => {
            const sender = typeof reply.sender_id === 'object' ? reply.sender_id : {};
            const isUser = reply.sender_type === 'user' || String(sender._id || reply.sender_id) === String(currentUserId);
            const senderName = sender.full_name || sender.username || (isUser ? 'You' : reply.sender_type === 'admin' ? 'Admin' : 'Support');
            const avatar = sender.avatar_url;

            return (
              <div key={reply._id} className={`flex ${isUser ? 'justify-end' : 'justify-start'} gap-2`}>
                {!isUser && (
                  <div className="w-7 h-7 rounded-full bg-gray-200 dark:bg-gray-700 flex items-center justify-center shrink-0 mt-auto mb-1">
                    {avatar ? <img src={avatar} className="w-full h-full rounded-full object-cover" alt="" />
                      : <span className="text-[10px] font-bold text-gray-500">{senderName[0]?.toUpperCase()}</span>}
                  </div>
                )}
                <div className={`max-w-[75%] ${isUser ? 'bg-[#fa3f5e] text-white rounded-2xl rounded-br-sm' : 'bg-gray-100 dark:bg-gray-800 text-gray-900 dark:text-white rounded-2xl rounded-bl-sm'} px-4 py-2.5 shadow-sm`}>
                  {!isUser && <p className="text-[10px] font-bold mb-1 capitalize opacity-60">{senderName} · {reply.sender_type}</p>}
                  <p className="text-[13px] leading-relaxed">{reply.message}</p>
                  <p className={`text-[10px] mt-1 text-right ${isUser ? 'text-white/50' : 'text-gray-400'}`}>{timeAgo(reply.createdAt)}</p>
                </div>
              </div>
            );
          })}
        </div>
      </div>

      {/* Reply input — pinned to bottom */}
      {isClosed ? (
        <div className="shrink-0 px-4 py-3 border-t border-gray-100 dark:border-gray-800 bg-white dark:bg-black text-center">
          <p className="text-xs text-gray-400">This query has been closed</p>
        </div>
      ) : (
        <div className="shrink-0 px-4 py-3 border-t border-gray-100 dark:border-gray-800 bg-white dark:bg-black">
          <div className="flex items-center gap-2 bg-gray-100 dark:bg-gray-800 rounded-full px-4 py-2.5">
            <input value={replyText} onChange={e => setReplyText(e.target.value)}
              onKeyDown={e => e.key === 'Enter' && handleReply()}
              placeholder="Type your reply…"
              className="flex-1 bg-transparent border-none outline-none text-sm text-gray-900 dark:text-white placeholder-gray-400" />
            <button onClick={handleReply} disabled={!replyText.trim() || sending}
              className="text-[#fa3f5e] disabled:opacity-40 font-semibold text-sm hover:opacity-80 transition-opacity shrink-0">
              {sending ? <Loader2 size={16} className="animate-spin" /> : <Send size={16} />}
            </button>
          </div>
        </div>
      )}
    </div>
  );
};

// ── FAQs ──────────────────────────────────────────────────────────────────
const FAQ_ITEMS = [
  { q: 'How do I change my username?', a: 'Go to Settings > Account > Edit, then change your username field and save.' },
  { q: 'How do I make my account private?', a: 'Go to Settings > Privacy and toggle "Private Account" on.' },
  { q: 'How do I reset my password?', a: 'Go to Settings > Security > Change Password, or use "Forgot Password" on the login screen.' },
  { q: 'How do I earn coins?', a: 'You earn coins by watching ads, engaging with promoted content, and through daily rewards.' },
  { q: 'How do I create an ad?', a: 'Vendor accounts can create ads via the Create Post modal by selecting the "Ad" type.' },
  { q: 'How do I delete my account?', a: 'Go to Settings > Account Actions > Delete Account. This action is permanent.' },
  { q: 'How do I report content?', a: 'Tap the three dots (⋯) on any post, reel, or ad and select "Report".' },
  { q: 'How do I block a user?', a: 'Go to the user\'s profile, tap the three dots, and select "Block".' },
  { q: 'Why can\'t I see someone\'s posts?', a: 'Their account may be private. Send a follow request.' },
  { q: 'How do I contact support?', a: 'Use "Contact Support" on this page, or email support@bebsmart.in.' },
];

const FAQPanel = () => {
  const [search, setSearch] = useState('');
  const [openIdx, setOpenIdx] = useState(null);
  const filtered = search.trim()
    ? FAQ_ITEMS.filter(f => f.q.toLowerCase().includes(search.toLowerCase()) || f.a.toLowerCase().includes(search.toLowerCase()))
    : FAQ_ITEMS;

  return (
    <div className="p-5 space-y-4">
      <div className="flex items-center gap-3 pb-3 border-b border-gray-100 dark:border-gray-800">
        <div className="w-10 h-10 rounded-full bg-green-50 dark:bg-green-900/20 flex items-center justify-center"><BookOpen size={18} className="text-green-500" /></div>
        <div>
          <p className="text-sm font-bold text-gray-900 dark:text-white">Frequently Asked Questions</p>
          <p className="text-xs text-gray-500 dark:text-gray-400">{FAQ_ITEMS.length} questions</p>
        </div>
      </div>
      <div className="relative">
        <Search size={15} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-gray-400" />
        <input value={search} onChange={e => setSearch(e.target.value)} placeholder="Search FAQs…" className={`${INPUT_CLS} pl-10`} />
      </div>
      {filtered.length === 0 ? (
        <div className="text-center py-10"><p className="text-sm text-gray-400">No FAQs match your search</p></div>
      ) : (
        <div className="space-y-2">
          {filtered.map((faq, i) => {
            const isOpen = openIdx === i;
            return (
              <div key={i} className="bg-white dark:bg-gray-900 rounded-xl border border-gray-100 dark:border-gray-800 overflow-hidden">
                <button onClick={() => setOpenIdx(isOpen ? null : i)} className="w-full flex items-center justify-between px-4 py-3.5 text-left">
                  <span className="text-sm font-medium text-gray-900 dark:text-white pr-3">{faq.q}</span>
                  {isOpen ? <ChevronUp size={16} className="text-gray-400 shrink-0" /> : <ChevronDown size={16} className="text-gray-400 shrink-0" />}
                </button>
                {isOpen && <div className="px-4 pb-4"><p className="text-sm text-gray-600 dark:text-gray-400 leading-relaxed">{faq.a}</p></div>}
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
};

// ── Main Page ─────────────────────────────────────────────────────────────
const HelpSettings = () => {
  const [activePanel, setActivePanel] = useState(null);
  const [activeQueryId, setActiveQueryId] = useState(null);
  const [reportLoading, setReportLoading] = useState({});
  const [reportDone, setReportDone] = useState({});

  const handleReport = async (key) => {
    setReportLoading(p => ({ ...p, [key]: true }));
    try { await api.post('/support-queries', { subject: `Report: ${key}`, message: `User reported a ${key} issue`, category: 'other', app_source: 'bsmart' }); }
    catch { /* silent */ }
    setReportLoading(p => ({ ...p, [key]: false }));
    setReportDone(p => ({ ...p, [key]: true }));
    setTimeout(() => setReportDone(p => { const n = { ...p }; delete n[key]; return n; }), 3000);
  };

  const REPORTS = [
    { key: 'bug', icon: Bug, bg: 'bg-orange-50 dark:bg-orange-900/20', color: 'text-orange-500', label: 'Report a Bug', sublabel: 'Found something broken? Let us know' },
    { key: 'content', icon: AlertOctagon, bg: 'bg-red-50 dark:bg-red-900/20', color: 'text-red-500', label: 'Report Content', sublabel: 'Flag inappropriate or harmful content' },
    { key: 'user', icon: UserX, bg: 'bg-gray-100 dark:bg-gray-800', color: 'text-gray-500', label: 'Report a User', sublabel: 'Report abusive or suspicious accounts' },
  ];

  // Sub-panel: query detail
  if (activeQueryId) {
    return (
      <div className="min-h-screen bg-gray-50 dark:bg-black pb-24">
        <div className="sticky top-0 bg-white dark:bg-black border-b border-gray-100 dark:border-gray-800 px-4 py-3 flex items-center justify-between z-40">
          <button onClick={() => setActiveQueryId(null)} className="text-gray-800 dark:text-white p-1"><ArrowLeft size={22} /></button>
          <h1 className="text-base font-semibold dark:text-white">Query Detail</h1>
          <div className="w-8" />
        </div>
        <div className="max-w-2xl mx-auto">
          <QueryDetailPanel queryId={activeQueryId} onBack={() => setActiveQueryId(null)} />
        </div>
      </div>
    );
  }

  // Sub-panel: contact, ticket, faq
  if (activePanel) {
    const panelTitle = activePanel === 'contact' ? 'Contact Support' : activePanel === 'ticket' ? 'Raise a Ticket' : 'FAQs';
    return (
      <div className="min-h-screen bg-gray-50 dark:bg-black pb-24">
        <div className="sticky top-0 bg-white dark:bg-black border-b border-gray-100 dark:border-gray-800 px-4 py-3 flex items-center justify-between z-40">
          <button onClick={() => setActivePanel(null)} className="text-gray-800 dark:text-white p-1"><ArrowLeft size={22} /></button>
          <h1 className="text-base font-semibold dark:text-white">{panelTitle}</h1>
          <div className="w-8" />
        </div>
        <div className="max-w-2xl mx-auto">
          {activePanel === 'contact' && (
            <QueriesWithFormPanel onOpenQuery={(id) => setActiveQueryId(id)} showNameFields={false} />
          )}
          {activePanel === 'ticket' && (
            <QueriesWithFormPanel onOpenQuery={(id) => setActiveQueryId(id)} showNameFields={true} />
          )}
          {activePanel === 'faq' && <FAQPanel />}
        </div>
      </div>
    );
  }

  // Main help page
  return (
    <div className="min-h-screen bg-gray-50 dark:bg-black pb-24">
      <div className="sticky top-0 bg-white dark:bg-black border-b border-gray-100 dark:border-gray-800 px-4 py-3 flex items-center justify-between z-40">
        <Link to="/settings" className="text-gray-800 dark:text-white p-1"><ArrowLeft size={22} /></Link>
        <h1 className="text-base font-semibold dark:text-white">Help & Support</h1>
        <div className="w-8" />
      </div>

      <div className="max-w-2xl mx-auto px-4 pt-5 space-y-5">
        <div>
          <SectionTitle title="Support" />
          <div className="bg-white dark:bg-gray-900 rounded-2xl border border-gray-100 dark:border-gray-800 shadow-sm overflow-hidden">
            <Row icon={Mail} iconBg="bg-blue-50 dark:bg-blue-900/20" iconColor="text-blue-500"
              label="Contact Support" sublabel="Submit a query & view your tickets" onClick={() => setActivePanel('contact')} />
            <Row icon={Ticket} iconBg="bg-purple-50 dark:bg-purple-900/20" iconColor="text-purple-500"
              label="Raise a Ticket" sublabel="Submit a detailed support request" onClick={() => setActivePanel('ticket')} />
            <Row icon={MessageSquare} iconBg="bg-teal-50 dark:bg-teal-900/20" iconColor="text-teal-500"
              label="Live Chat" sublabel="Chat with our support team in real-time" badge="Coming Soon" />
          </div>
        </div>

        <div>
          <SectionTitle title="Resources" />
          <div className="bg-white dark:bg-gray-900 rounded-2xl border border-gray-100 dark:border-gray-800 shadow-sm overflow-hidden">
            <Row icon={BookOpen} iconBg="bg-green-50 dark:bg-green-900/20" iconColor="text-green-500"
              label="FAQs" sublabel="Answers to the most common questions" onClick={() => setActivePanel('faq')} />
            <Row icon={GraduationCap} iconBg="bg-indigo-50 dark:bg-indigo-900/20" iconColor="text-indigo-500"
              label="Tutorials" sublabel="Step-by-step guides for using bSmart" href="https://bebsmart.in/tutorials" />
            <Row icon={FileText} iconBg="bg-orange-50 dark:bg-orange-900/20" iconColor="text-orange-500"
              label="User Guide" sublabel="Full documentation and feature reference" href="https://bebsmart.in/guide" />
          </div>
        </div>

        <div>
          <SectionTitle title="Quick Contact" />
          <div className="bg-white dark:bg-gray-900 rounded-2xl border border-gray-100 dark:border-gray-800 shadow-sm overflow-hidden">
            <Row icon={Mail} iconBg="bg-sky-50 dark:bg-sky-900/20" iconColor="text-sky-500"
              label="Email" sublabel="support@bebsmart.in" href="mailto:support@bebsmart.in" />
            <Row icon={Phone} iconBg="bg-emerald-50 dark:bg-emerald-900/20" iconColor="text-emerald-500"
              label="Phone" sublabel="+91 80-XXXX-XXXX (Mon–Fri, 10am–6pm)" href="tel:+918000000000" />
          </div>
        </div>

        <div>
          <SectionTitle title="Reports" />
          <div className="bg-white dark:bg-gray-900 rounded-2xl border border-gray-100 dark:border-gray-800 shadow-sm overflow-hidden">
            {REPORTS.map(({ key, icon: Icon, bg, color, label, sublabel }) => (
              <div key={key} className="flex items-center justify-between px-4 py-3.5 border-b border-gray-100 dark:border-gray-800 last:border-0">
                <div className="flex items-center gap-3 flex-1 min-w-0 pr-3">
                  <div className={`w-9 h-9 rounded-full flex items-center justify-center flex-shrink-0 ${bg}`}><Icon size={16} className={color} /></div>
                  <div className="min-w-0">
                    <p className="text-sm font-medium text-gray-900 dark:text-white">{label}</p>
                    <p className="text-xs text-gray-500 dark:text-gray-400 mt-0.5">{sublabel}</p>
                  </div>
                </div>
                <button onClick={() => handleReport(key)} disabled={!!reportLoading[key] || !!reportDone[key]}
                  className="flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-bold border transition-all disabled:opacity-60 border-gray-200 dark:border-gray-700 text-gray-600 dark:text-gray-400 hover:bg-gray-50 dark:hover:bg-gray-800">
                  {reportLoading[key] ? <Loader2 size={12} className="animate-spin" /> : reportDone[key] ? <><Check size={12} className="text-green-500" /> Sent</> : 'Report'}
                </button>
              </div>
            ))}
          </div>
          <p className="text-xs text-gray-400 dark:text-gray-500 px-1 mt-2">All reports are reviewed within 24–48 hours.</p>
        </div>
      </div>
    </div>
  );
};

export default HelpSettings;
