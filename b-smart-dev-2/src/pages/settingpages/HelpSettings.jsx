import { useState, useRef, useEffect, useCallback } from 'react';
import { Link } from 'react-router-dom';
import { useSelector } from 'react-redux';
import {
  ArrowLeft, Mail, Ticket, MessageSquare, BookOpen, GraduationCap,
  FileText, Bug, AlertOctagon, ChevronRight, ChevronDown, ChevronUp,
  Loader2, Check, Send, X, Search, Phone, Clock, CircleDot, CheckCircle2, Trash2, Plus,
  Film, Image as ImageIcon,
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
  const selectedOpt = options.find(opt => (opt.value ?? opt) === value);
  const displayLabel = selectedOpt ? (selectedOpt.label ?? selectedOpt) : value;
  return (
    <div ref={ref} className="relative">
      <button type="button" onClick={() => setOpen(o => !o)}
        className="w-full flex items-center justify-between px-3.5 py-2.5 rounded-xl border border-gray-200 dark:border-gray-700 bg-white dark:bg-gray-900 text-sm text-gray-900 dark:text-white hover:border-gray-300 dark:hover:border-gray-600 transition-colors">
        <span className={value ? (selectedOpt?.label ? '' : 'capitalize') : 'text-gray-400'}>{displayLabel || placeholder}</span>
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

// ── Inline Submit Form (used by Contact Support) ─────────
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

// ── Queries list + new form panel (used by Contact Support) ──
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
const FAQ_CATEGORIES = ['all', 'general', 'account', 'payment', 'member', 'ads', 'other'];

const FAQPanel = () => {
  const [faqs, setFaqs]           = useState([]);
  const [loading, setLoading]     = useState(true);
  const [error, setError]         = useState('');
  const [search, setSearch]       = useState('');
  const [category, setCategory]   = useState('all');
  const [openId, setOpenId]       = useState(null);

  useEffect(() => {
    setLoading(true);
    setError('');
    const params = { app_source: 'member' };
    if (category !== 'all') params.category = category;
    api.get('/faq', { params })
      .then(res => setFaqs(res.data?.data || []))
      .catch(() => setError('Failed to load FAQs. Please try again.'))
      .finally(() => setLoading(false));
  }, [category]);

  const displayed = search.trim()
    ? faqs.filter(f =>
        f.question.toLowerCase().includes(search.toLowerCase()) ||
        f.answer.toLowerCase().includes(search.toLowerCase())
      )
    : faqs;

  return (
    <div className="p-5 space-y-4">
      {/* Header */}
      <div className="flex items-center gap-3 pb-3 border-b border-gray-100 dark:border-gray-800">
        <div className="w-10 h-10 rounded-full bg-green-50 dark:bg-green-900/20 flex items-center justify-center">
          <BookOpen size={18} className="text-green-500" />
        </div>
        <div>
          <p className="text-sm font-bold text-gray-900 dark:text-white">Frequently Asked Questions</p>
          <p className="text-xs text-gray-500 dark:text-gray-400">
            {loading ? 'Loading…' : `${displayed.length} question${displayed.length !== 1 ? 's' : ''}`}
          </p>
        </div>
      </div>

      {/* Search */}
      <div className="relative">
        <Search size={15} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-gray-400" />
        <input value={search} onChange={e => { setSearch(e.target.value); setOpenId(null); }}
          placeholder="Search FAQs…" className={`${INPUT_CLS} pl-10`} />
      </div>

      {/* Category filter tabs */}
      <div className="flex gap-2 overflow-x-auto pb-1" style={{ scrollbarWidth: 'none' }}>
        {FAQ_CATEGORIES.map(cat => (
          <button key={cat} onClick={() => { setCategory(cat); setSearch(''); setOpenId(null); }}
            className={`px-3 py-1.5 rounded-full text-[11px] font-bold whitespace-nowrap capitalize transition-all ${
              category === cat
                ? 'bg-gray-900 dark:bg-white text-white dark:text-black'
                : 'bg-gray-100 dark:bg-gray-800 text-gray-500 dark:text-gray-400 hover:bg-gray-200 dark:hover:bg-gray-700'
            }`}>
            {cat === 'all' ? 'All' : cat}
          </button>
        ))}
      </div>

      {/* Content */}
      {loading ? (
        <div className="flex items-center justify-center py-16">
          <Loader2 size={24} className="animate-spin text-gray-300 dark:text-gray-700" />
        </div>
      ) : error ? (
        <div className="text-center py-10 space-y-2">
          <p className="text-sm text-red-500">{error}</p>
          <button onClick={() => setCategory(c => c)} className="text-xs text-[#fa3f5e] font-semibold">Retry</button>
        </div>
      ) : displayed.length === 0 ? (
        <div className="text-center py-10">
          <p className="text-sm text-gray-400">
            {search.trim() ? 'No FAQs match your search' : 'No FAQs in this category yet'}
          </p>
        </div>
      ) : (
        <div className="space-y-2">
          {displayed.map(faq => {
            const isOpen = openId === faq._id;
            return (
              <div key={faq._id} className="bg-white dark:bg-gray-900 rounded-xl border border-gray-100 dark:border-gray-800 overflow-hidden">
                <button onClick={() => setOpenId(isOpen ? null : faq._id)}
                  className="w-full flex items-center justify-between px-4 py-3.5 text-left">
                  <span className="text-sm font-medium text-gray-900 dark:text-white pr-3">{faq.question}</span>
                  {isOpen
                    ? <ChevronUp size={16} className="text-gray-400 shrink-0" />
                    : <ChevronDown size={16} className="text-gray-400 shrink-0" />}
                </button>
                {isOpen && (
                  <div className="px-4 pb-4">
                    <p className="text-sm text-gray-600 dark:text-gray-400 leading-relaxed">{faq.answer}</p>
                    {faq.category && faq.category !== 'general' && (
                      <span className="inline-block mt-2 text-[10px] font-bold px-2 py-0.5 rounded-full bg-gray-100 dark:bg-gray-800 text-gray-400 capitalize">
                        {faq.category}
                      </span>
                    )}
                  </div>
                )}
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
};

// ── Report a Bug ─────────────────────────────────────────────────────────────
const APP_VERSION = '1.0.0'; // keep in sync with AboutSettings.jsx

const BUG_CATEGORIES = [
  { value: 'app_crash',         label: 'App Crash' },
  { value: 'video_not_playing', label: 'Video Not Playing' },
  { value: 'login_issue',       label: 'Login Issue' },
  { value: 'payment_issue',     label: 'Payment Issue' },
  { value: 'rewards_issue',     label: 'Rewards Issue' },
  { value: 'upload_issue',      label: 'Upload Issue' },
  { value: 'ui_problem',        label: 'UI Problem' },
  { value: 'other',             label: 'Other' },
];

const BUG_STATUS_CONFIG = {
  new:         { label: 'New',         color: 'text-blue-600 bg-blue-50 dark:bg-blue-900/20 border-blue-200 dark:border-blue-800', icon: CircleDot },
  in_progress: { label: 'In Progress', color: 'text-amber-600 bg-amber-50 dark:bg-amber-900/20 border-amber-200 dark:border-amber-800', icon: Clock },
  fixed:       { label: 'Fixed',       color: 'text-green-600 bg-green-50 dark:bg-green-900/20 border-green-200 dark:border-green-800', icon: CheckCircle2 },
  closed:      { label: 'Closed',      color: 'text-gray-500 bg-gray-50 dark:bg-gray-800 border-gray-200 dark:border-gray-700', icon: X },
};

const BugStatusBadge = ({ status }) => {
  const cfg = BUG_STATUS_CONFIG[status] || BUG_STATUS_CONFIG.new;
  const Icon = cfg.icon;
  return (
    <span className={`inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[10px] font-bold border ${cfg.color}`}>
      <Icon size={10} /> {cfg.label}
    </span>
  );
};

// Which browser is running — used as the "device_model" stand-in on desktop,
// where there's no physical device model to report.
const getBrowserLabel = (ua) => {
  if (/edg\//i.test(ua)) return 'Edge';
  if (/opr\//i.test(ua) || /opera/i.test(ua)) return 'Opera';
  if (/chrome\//i.test(ua) && !/edg\//i.test(ua)) return 'Chrome';
  if (/firefox\//i.test(ua)) return 'Firefox';
  if (/safari\//i.test(ua) && !/chrome\//i.test(ua)) return 'Safari';
  return 'Browser';
};

const WINDOWS_VERSION_LABELS = { '10.0': '10/11', '6.3': '8.1', '6.2': '8', '6.1': '7' };

// Best-effort device/environment capture from the browser — no user input needed.
// user_id and time of issue don't need to be sent: the backend attaches the
// authenticated user and a createdAt timestamp automatically.
const getDeviceInfo = () => {
  const ua = navigator.userAgent || '';
  let os_type = '';
  let os_version = '';
  let device_model = '';

  if (/android/i.test(ua)) {
    os_type = 'android';
    const verMatch = ua.match(/Android\s([\d.]+)/i);
    if (verMatch) os_version = verMatch[1];
    const modelMatch = ua.match(/Android[^;]*;\s*([^)]+)\)/i);
    if (modelMatch) device_model = modelMatch[1].split('Build/')[0].trim();
  } else if (/iphone|ipad|ipod/i.test(ua)) {
    os_type = 'ios';
    const verMatch = ua.match(/OS\s([\d_]+)/i);
    if (verMatch) os_version = verMatch[1].replace(/_/g, '.');
    device_model = /ipad/i.test(ua) ? 'iPad' : /ipod/i.test(ua) ? 'iPod' : 'iPhone';
  } else if (/windows/i.test(ua)) {
    os_type = 'windows';
    const verMatch = ua.match(/Windows NT ([\d.]+)/i);
    os_version = verMatch ? (WINDOWS_VERSION_LABELS[verMatch[1]] || verMatch[1]) : '';
    device_model = `${getBrowserLabel(ua)} on Windows`;
  } else if (/mac os x/i.test(ua)) {
    os_type = 'macos';
    const verMatch = ua.match(/Mac OS X ([\d_]+)/i);
    os_version = verMatch ? verMatch[1].replace(/_/g, '.') : '';
    device_model = `${getBrowserLabel(ua)} on Mac`;
  } else if (/linux/i.test(ua)) {
    os_type = 'linux';
    device_model = `${getBrowserLabel(ua)} on Linux`;
  } else if (ua) {
    os_type = 'other';
    device_model = getBrowserLabel(ua);
  }

  let network_type = 'other';
  const conn = navigator.connection || navigator.mozConnection || navigator.webkitConnection;
  if (conn?.type === 'wifi' || conn?.type === 'ethernet') network_type = 'wifi';
  else if (conn?.type === 'cellular' || /^(2g|3g|4g|slow-2g)$/.test(conn?.effectiveType || '')) network_type = 'mobile_data';
  else if (!conn && ['windows', 'macos', 'linux'].includes(os_type)) network_type = 'wifi'; // Network Info API isn't in Firefox/Safari — desktops are usually wifi/ethernet

  return { app_version: APP_VERSION, os_type, os_version, device_model, network_type };
};

// ── Bug report submit form ────────────────────────────────────────────────
const BugReportForm = ({ onCreated }) => {
  const [category, setCategory]       = useState('');
  const [description, setDescription] = useState('');
  const [attachments, setAttachments] = useState([]); // { id, name, type, url, uploading, error }
  const [sending, setSending]         = useState(false);
  const [sent, setSent]               = useState(null); // ticket_id string, or true
  const [error, setError]             = useState('');
  const fileInputRef = useRef(null);

  const handleFiles = async (files) => {
    for (const file of Array.from(files || [])) {
      const id = `${Date.now()}-${Math.random().toString(36).slice(2)}`;
      const isVideo = file.type.startsWith('video/');
      setAttachments(prev => [...prev, { id, name: file.name, type: isVideo ? 'video' : 'image', uploading: true }]);
      try {
        const fd = new FormData();
        fd.append('file', file);
        const res = await api.post('/upload/post', fd, { headers: { 'Content-Type': 'multipart/form-data' } });
        const url = res.data?.media?.url || res.data?.fileUrl || res.data?.url;
        const type = res.data?.media_type === 'video' ? 'video' : 'image';
        setAttachments(prev => prev.map(a => a.id === id ? { ...a, uploading: false, url, type } : a));
      } catch {
        setAttachments(prev => prev.map(a => a.id === id ? { ...a, uploading: false, error: true } : a));
      }
    }
  };

  const removeAttachment = (id) => setAttachments(prev => prev.filter(a => a.id !== id));

  const handleSubmit = async () => {
    if (!category) { setError('Please select a category.'); return; }
    if (!description.trim()) { setError('Please describe the issue.'); return; }
    if (attachments.some(a => a.uploading)) { setError('Please wait for attachments to finish uploading.'); return; }
    setSending(true); setError('');
    try {
      const { data } = await api.post('/bug-reports', {
        category,
        description: description.trim(),
        attachments: attachments.filter(a => a.url).map(a => ({ url: a.url, type: a.type })),
        ...getDeviceInfo(),
      });
      setSent(data?.data?.ticket_id || true);
      onCreated?.();
    } catch (e) {
      setError(e?.response?.data?.message || 'Failed to submit. Try again.');
    } finally { setSending(false); }
  };

  if (sent) return (
    <div className="flex flex-col items-center py-8 gap-3">
      <div className="w-12 h-12 rounded-full bg-green-50 dark:bg-green-900/20 flex items-center justify-center"><Check size={22} className="text-green-500" /></div>
      <p className="text-sm font-bold text-gray-900 dark:text-white">Report Submitted!</p>
      {sent !== true && (
        <p className="text-xs text-gray-400">Ticket ID: <span className="font-mono font-semibold text-gray-600 dark:text-gray-300">{sent}</span></p>
      )}
      <button onClick={() => { setSent(null); setCategory(''); setDescription(''); setAttachments([]); }}
        className="text-xs text-[#fa3f5e] font-semibold">Report Another Issue</button>
    </div>
  );

  return (
    <div className="space-y-3">
      {error && <div className="flex items-center gap-2 px-3 py-2 rounded-xl bg-red-50 dark:bg-red-900/20 text-red-600 dark:text-red-400 text-xs"><AlertOctagon size={13} /> {error}</div>}
      <div>
        <label className="text-xs font-semibold text-gray-500 dark:text-gray-400 mb-1.5 block">Category <span className="text-red-400">*</span></label>
        <Dropdown value={category} onChange={setCategory} options={BUG_CATEGORIES} placeholder="Select issue type" />
      </div>
      <div>
        <label className="text-xs font-semibold text-gray-500 dark:text-gray-400 mb-1.5 block">Description <span className="text-red-400">*</span></label>
        <textarea value={description} onChange={e => setDescription(e.target.value)} rows={4} placeholder="Describe what happened…" maxLength={2000} className={`${INPUT_CLS} resize-none`} />
      </div>
      <div>
        <label className="text-xs font-semibold text-gray-500 dark:text-gray-400 mb-1.5 block">Attachments (optional)</label>
        <input ref={fileInputRef} type="file" accept="image/*,video/*" multiple className="hidden"
          onChange={e => { handleFiles(e.target.files); e.target.value = ''; }} />
        <button type="button" onClick={() => fileInputRef.current?.click()}
          className="w-full flex items-center justify-center gap-2 py-3 rounded-xl border-2 border-dashed border-gray-200 dark:border-gray-700 text-xs font-semibold text-gray-500 dark:text-gray-400 hover:border-[#fa3f5e]/40 hover:text-[#fa3f5e] transition-colors">
          <Plus size={14} /> Add screenshot or screen recording
        </button>
        {attachments.length > 0 && (
          <div className="mt-2 space-y-1.5">
            {attachments.map(a => (
              <div key={a.id} className="flex items-center gap-2 px-3 py-2 rounded-lg bg-gray-50 dark:bg-gray-800/60 text-xs">
                {a.type === 'video' ? <Film size={13} className="text-gray-400 shrink-0" /> : <ImageIcon size={13} className="text-gray-400 shrink-0" />}
                <span className="flex-1 truncate text-gray-600 dark:text-gray-300">{a.name}</span>
                {a.uploading ? <Loader2 size={13} className="animate-spin text-gray-400 shrink-0" />
                  : a.error ? <span className="text-red-400 shrink-0">Failed</span>
                  : <Check size={13} className="text-green-500 shrink-0" />}
                <button type="button" onClick={() => removeAttachment(a.id)} className="text-gray-300 hover:text-red-500 shrink-0"><X size={13} /></button>
              </div>
            ))}
          </div>
        )}
      </div>
      <button onClick={handleSubmit} disabled={sending}
        className="w-full py-3 rounded-xl bg-[#fa3f5e] text-white font-bold text-sm flex items-center justify-center gap-2 disabled:opacity-60 hover:opacity-90 transition-opacity">
        {sending ? <><Loader2 size={14} className="animate-spin" /> Submitting…</> : <><Send size={14} /> Submit Report</>}
      </button>
    </div>
  );
};

// ── Bug reports list + new-form panel (opened as a page, like Contact Support) ──
const BugReportsPanel = () => {
  const [reports, setReports] = useState([]);
  const [loading, setLoading] = useState(true);
  const [showForm, setShowForm] = useState(false);

  const fetchReports = useCallback(async () => {
    setLoading(true);
    try {
      const { data } = await api.get('/bug-reports/my');
      setReports(data?.data || []);
    } catch { setReports([]); }
    finally { setLoading(false); }
  }, []);

  useEffect(() => { fetchReports(); }, [fetchReports]);

  return (
    <div className="p-5 space-y-4">
      <div className="flex items-center justify-between">
        <p className="text-xs font-bold text-gray-400 dark:text-gray-500 uppercase tracking-widest">Your Reports ({reports.length})</p>
        <button onClick={() => setShowForm(f => !f)}
          className={`w-8 h-8 rounded-full flex items-center justify-center transition-all ${showForm ? 'bg-gray-200 dark:bg-gray-700 rotate-45' : 'bg-[#fa3f5e] text-white hover:opacity-90'}`}>
          <Plus size={16} className={showForm ? 'text-gray-600 dark:text-gray-300' : 'text-white'} />
        </button>
      </div>

      {showForm && (
        <div className="bg-white dark:bg-gray-900 rounded-2xl border border-gray-100 dark:border-gray-800 p-4 shadow-sm">
          <BugReportForm onCreated={() => { setShowForm(false); fetchReports(); }} />
        </div>
      )}

      {loading ? (
        <div className="flex items-center justify-center py-12"><Loader2 size={24} className="animate-spin text-gray-300" /></div>
      ) : reports.length === 0 ? (
        <div className="text-center py-10">
          <Bug size={28} className="mx-auto mb-2 text-gray-300 dark:text-gray-700" />
          <p className="text-sm font-semibold text-gray-900 dark:text-white">No reports yet</p>
          <p className="text-xs text-gray-400 mt-1">Tap <span className="text-[#fa3f5e] font-bold">+</span> above to report an issue</p>
        </div>
      ) : (
        <div className="space-y-2">
          {reports.map(r => (
            <div key={r._id} className="bg-white dark:bg-gray-900 rounded-xl border border-gray-100 dark:border-gray-800 p-4">
              <div className="flex items-start justify-between gap-3 mb-2">
                <p className="text-sm font-semibold text-gray-900 dark:text-white capitalize">{(r.category || '').replace(/_/g, ' ')}</p>
                <BugStatusBadge status={r.status} />
              </div>
              <p className="text-xs text-gray-500 dark:text-gray-400 line-clamp-2 mb-2">{r.description}</p>
              <div className="flex items-center gap-3 text-[10px] text-gray-400">
                <span className="font-mono">{r.ticket_id}</span>
                <span>·</span>
                <span>{timeAgo(r.createdAt)}</span>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
};

// ── Report Content — my submitted reports ──────────────────────────────────
const CONTENT_REPORT_STATUS_CONFIG = {
  pending:      { label: 'Pending',      color: 'text-blue-600 bg-blue-50 dark:bg-blue-900/20 border-blue-200 dark:border-blue-800', icon: CircleDot },
  reviewed:     { label: 'Reviewed',     color: 'text-amber-600 bg-amber-50 dark:bg-amber-900/20 border-amber-200 dark:border-amber-800', icon: Clock },
  action_taken: { label: 'Action Taken', color: 'text-green-600 bg-green-50 dark:bg-green-900/20 border-green-200 dark:border-green-800', icon: CheckCircle2 },
  rejected:     { label: 'Rejected',     color: 'text-gray-500 bg-gray-50 dark:bg-gray-800 border-gray-200 dark:border-gray-700', icon: X },
};

const ContentReportStatusBadge = ({ status }) => {
  const cfg = CONTENT_REPORT_STATUS_CONFIG[status] || CONTENT_REPORT_STATUS_CONFIG.pending;
  const Icon = cfg.icon;
  return (
    <span className={`inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[10px] font-bold border ${cfg.color}`}>
      <Icon size={10} /> {cfg.label}
    </span>
  );
};

// ── Content reports list — opened as a page, like Report a Bug ─────────────
const ContentReportsPanel = () => {
  const [reports, setReports] = useState([]);
  const [loading, setLoading] = useState(true);

  const fetchReports = useCallback(async () => {
    setLoading(true);
    try {
      const { data } = await api.get('/content-reports/my');
      setReports(data?.reports || []);
    } catch { setReports([]); }
    finally { setLoading(false); }
  }, []);

  useEffect(() => { fetchReports(); }, [fetchReports]);

  return (
    <div className="p-5 space-y-4">
      <p className="text-xs font-bold text-gray-400 dark:text-gray-500 uppercase tracking-widest">Your Reports ({reports.length})</p>

      {loading ? (
        <div className="flex items-center justify-center py-12"><Loader2 size={24} className="animate-spin text-gray-300" /></div>
      ) : reports.length === 0 ? (
        <div className="text-center py-10">
          <AlertOctagon size={28} className="mx-auto mb-2 text-gray-300 dark:text-gray-700" />
          <p className="text-sm font-semibold text-gray-900 dark:text-white">No reports yet</p>
          <p className="text-xs text-gray-400 mt-1">Content you report will show up here</p>
        </div>
      ) : (
        <div className="space-y-2">
          {reports.map(r => (
            <div key={r._id} className="bg-white dark:bg-gray-900 rounded-xl border border-gray-100 dark:border-gray-800 p-4">
              <div className="flex items-start justify-between gap-3 mb-2">
                <p className="text-sm font-semibold text-gray-900 dark:text-white capitalize">{(r.content_type || '').replace(/_/g, ' ')} · {r.reason}</p>
                <ContentReportStatusBadge status={r.status} />
              </div>

              {r.details && <p className="text-xs text-gray-500 dark:text-gray-400 leading-relaxed mb-2.5">{r.details}</p>}

              {Array.isArray(r.attachments) && r.attachments.length > 0 && (
                <div className="flex gap-2 mb-2.5 overflow-x-auto">
                  {r.attachments.map((att, i) => (
                    <a key={i} href={att.url} target="_blank" rel="noopener noreferrer"
                      className="relative shrink-0 w-20 h-20 rounded-lg overflow-hidden bg-gray-100 dark:bg-gray-800 border border-gray-100 dark:border-gray-800">
                      {att.type === 'video' ? (
                        <>
                          <video src={att.url} className="w-full h-full object-cover" muted />
                          <div className="absolute inset-0 flex items-center justify-center bg-black/30">
                            <Film size={16} className="text-white" />
                          </div>
                        </>
                      ) : (
                        <img src={att.url} alt="Attachment" className="w-full h-full object-cover" />
                      )}
                    </a>
                  ))}
                </div>
              )}

              {r.action_taken && r.action_taken !== 'none' && (
                <div className="flex items-center gap-1.5 mb-2 text-[11px] font-semibold text-green-600 dark:text-green-400">
                  <CheckCircle2 size={12} /> Action taken: {r.action_taken.replace(/_/g, ' ')}
                </div>
              )}

              {r.admin_note && (
                <div className="mb-2.5 px-3 py-2 rounded-lg bg-gray-50 dark:bg-gray-800/60 text-xs text-gray-600 dark:text-gray-300">
                  <span className="font-semibold text-gray-500 dark:text-gray-400">Admin note: </span>{r.admin_note}
                </div>
              )}

              <div className="flex items-center gap-3 text-[10px] text-gray-400">
                <span>Reported {timeAgo(r.createdAt)}</span>
                {r.reviewed_at && <><span>·</span><span>Reviewed {timeAgo(r.reviewed_at)}</span></>}
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
};

// ── Main Page ─────────────────────────────────────────────────────────────
const HelpSettings = () => {
  const [activePanel, setActivePanel] = useState(null);
  const [activeQueryId, setActiveQueryId] = useState(null);

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

  // Sub-panel: contact, bug, content-reports, faq
  if (activePanel) {
    const panelTitle = activePanel === 'contact' ? 'Contact Support'
      : activePanel === 'bug' ? 'Report a Bug'
      : activePanel === 'content-reports' ? 'My Content Reports'
      : 'FAQs';
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
          {activePanel === 'bug' && <BugReportsPanel />}
          {activePanel === 'content-reports' && <ContentReportsPanel />}
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
            <Row icon={Bug} iconBg="bg-orange-50 dark:bg-orange-900/20" iconColor="text-orange-500"
              label="Report a Bug" sublabel="Found something broken? Let us know" onClick={() => setActivePanel('bug')} />
            <Row icon={AlertOctagon} iconBg="bg-rose-50 dark:bg-rose-900/20" iconColor="text-rose-500"
              label="My Content Reports" sublabel="Track posts, reels & ads you've reported" onClick={() => setActivePanel('content-reports')} />
          </div>
          <p className="text-xs text-gray-400 dark:text-gray-500 px-1 mt-2">All reports are reviewed within 24–48 hours.</p>
        </div>
      </div>
    </div>
  );
};

export default HelpSettings;
