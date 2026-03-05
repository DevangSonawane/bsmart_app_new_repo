import React, { useState, useRef, useEffect, useCallback } from 'react';
import { Navigate } from 'react-router-dom';
import { useSelector } from 'react-redux';
import {
  Heart, MessageCircle, Send, MoreHorizontal, Music2,
  Volume2, VolumeX, Bookmark, ChevronLeft, Search,
  ShoppingBag, Loader2, UserPlus, UserCheck, X, Smile, Trash2
} from 'lucide-react';

const BASE_URL = 'https://api.bebsmart.in';
const IMAGE_AD_DURATION = 15; // seconds for image ads

// ─── Auth helper ──────────────────────────────────────────────────────────────
const authHeaders = () => {
  const token = localStorage.getItem('token');
  return {
    'Content-Type': 'application/json',
    ...(token ? { Authorization: `Bearer ${token}` } : {}),
  };
};

// ─── Format time ago ──────────────────────────────────────────────────────────
const formatTimeAgo = (dateString) => {
  if (!dateString) return '';
  const date = new Date(dateString);
  if (isNaN(date.getTime())) return '';
  const diff = Math.floor((Date.now() - date) / 1000);
  if (diff < 60) return `${diff}s`;
  if (diff < 3600) return `${Math.floor(diff / 60)}m`;
  if (diff < 86400) return `${Math.floor(diff / 3600)}h`;
  if (diff < 604800) return `${Math.floor(diff / 86400)}d`;
  return `${Math.floor(diff / 604800)}w`;
};

// ─── Avatar ───────────────────────────────────────────────────────────────────
const Avatar = ({ src, username, size = 'md' }) => {
  const dim = size === 'xs' ? 'w-7 h-7 text-[10px]' : size === 'sm' ? 'w-8 h-8 text-xs' : 'w-9 h-9 text-sm';
  return (
    <div className={`${dim} rounded-full overflow-hidden bg-gradient-to-tr from-yellow-400 via-orange-500 to-pink-500 p-[1.5px] flex-shrink-0`}>
      <div className="w-full h-full rounded-full bg-white dark:bg-[#1c1c1e] flex items-center justify-center overflow-hidden">
        {src
          ? <img src={src} alt={username || 'user'} className="w-full h-full object-cover" />
          : <span className="text-gray-800 dark:text-white font-bold">{(username || 'U')[0].toUpperCase()}</span>
        }
      </div>
    </div>
  );
};

// ─── Reply Row ────────────────────────────────────────────────────────────────
const ReplyRow = ({ reply, onLikeReply, onDeleteReply, currentUserId }) => {
  const rId = reply._id || reply.id;
  const rUser = reply.user || reply.users || {};
  const rLiked = reply.is_liked_by_me || false;
  const rLikes = reply.likes_count ?? 0;
  const isOwner = currentUserId && (
    String(rUser._id || rUser.id || '') === String(currentUserId) ||
    String(reply.user_id || '') === String(currentUserId)
  );

  return (
    <div className="flex gap-2.5 py-2 group/reply">
      <Avatar src={rUser.avatar_url} username={rUser.username || rUser.full_name} size="xs" />
      <div className="flex-1 min-w-0">
        <div className="flex items-start justify-between gap-2">
          <div className="flex-1 min-w-0">
            <span className="font-semibold text-gray-900 dark:text-white text-xs mr-1.5">
              {rUser.username || rUser.full_name || 'Unknown'}
            </span>
            <span className="text-gray-600 dark:text-gray-300 text-xs break-words">{reply.text || reply.content}</span>
          </div>
          <button onClick={() => onLikeReply(rId, rLiked)} className="flex flex-col items-center gap-0.5 flex-shrink-0 active:scale-90 transition-transform pt-0.5">
            <Heart size={12} className={rLiked ? 'text-red-500' : 'text-gray-400 dark:text-gray-500 hover:text-gray-600 dark:hover:text-gray-300 transition-colors'} fill={rLiked ? 'currentColor' : 'none'} />
            {rLikes > 0 && <span className={`text-[9px] leading-none ${rLiked ? 'text-red-400' : 'text-gray-400 dark:text-gray-500'}`}>{rLikes}</span>}
          </button>
        </div>
        <div className="flex items-center gap-3 mt-1">
          <span className="text-gray-400 dark:text-gray-500 text-[11px]">{formatTimeAgo(reply.createdAt || reply.created_at)}</span>
          {rLikes > 0 && <span className="text-gray-400 dark:text-gray-500 text-[11px]">{rLikes} likes</span>}
          {isOwner && (
            <button onClick={() => onDeleteReply(rId)} className="text-gray-400 dark:text-gray-500 hover:text-red-500 transition-colors active:scale-90 opacity-0 group-hover/reply:opacity-100 ml-1">
              <Trash2 size={11} />
            </button>
          )}
        </div>
      </div>
    </div>
  );
};

// ─── Comment Row ──────────────────────────────────────────────────────────────
const CommentRow = ({ comment, onReply, onLikeComment, onDeleteComment, currentUserId, registerRefresh }) => {
  const seedReplies = Array.isArray(comment.replies) ? comment.replies : [];
  const [showReplies, setShowReplies] = useState(false);
  const [replies, setReplies] = useState(seedReplies);
  const [loadingReplies, setLoadingReplies] = useState(false);
  const [repliesLoaded, setRepliesLoaded] = useState(seedReplies.length > 0);

  const commentId = comment._id || comment.id;
  const user = comment.user || comment.users || {};
  const isLiked = comment.is_liked_by_me || false;
  const likesCount = comment.likes_count ?? (Array.isArray(comment.likes) ? comment.likes.length : 0);
  const apiReplyCount = comment.reply_count ?? comment.replies_count ?? (Array.isArray(comment.replies) ? comment.replies.length : 0);
  const replyCount = replies.length > 0 ? replies.length : apiReplyCount;
  const hasReplies = replyCount > 0;
  const isOwner = currentUserId && (
    String(user._id || user.id || '') === String(currentUserId) ||
    String(comment.user_id || '') === String(currentUserId)
  );

  const fetchReplies = useCallback(async () => {
    setLoadingReplies(true);
    try {
      const res = await fetch(`${BASE_URL}/api/comments/${commentId}/replies`, { headers: authHeaders() });
      if (res.ok) {
        const data = await res.json();
        setReplies(Array.isArray(data) ? data : (data.replies || data.data || []));
        setRepliesLoaded(true);
      }
    } catch (e) { console.error('Replies fetch error:', e); }
    finally { setLoadingReplies(false); }
  }, [commentId]);

  useEffect(() => {
    if (registerRefresh) {
      registerRefresh(commentId, async () => { await fetchReplies(); setShowReplies(true); });
    }
  }, [commentId, registerRefresh, fetchReplies]);

  const handleToggleReplies = async () => {
    if (showReplies) { setShowReplies(false); return; }
    if (!repliesLoaded) await fetchReplies();
    setShowReplies(true);
  };

  const handleLikeReply = async (replyId, isLikedReply) => {
    const endpoint = isLikedReply ? `${BASE_URL}/api/comments/${replyId}/unlike` : `${BASE_URL}/api/comments/${replyId}/like`;
    setReplies(prev => prev.map(r => {
      if ((r._id || r.id) !== replyId) return r;
      return { ...r, is_liked_by_me: !isLikedReply, likes_count: isLikedReply ? Math.max(0, (r.likes_count || 1) - 1) : (r.likes_count || 0) + 1 };
    }));
    try { await fetch(endpoint, { method: 'POST', headers: authHeaders() }); }
    catch (e) { console.error(e); }
  };

  const handleDeleteReply = async (replyId) => {
    try {
      const res = await fetch(`${BASE_URL}/api/comments/${replyId}`, { method: 'DELETE', headers: authHeaders() });
      if (res.ok) setReplies(prev => prev.filter(r => (r._id || r.id) !== replyId));
    } catch (e) { console.error('Delete reply error:', e); }
  };

  return (
    <div className="group/comment">
      <div className="flex gap-3 py-3 px-4">
        <Avatar src={user.avatar_url} username={user.username || user.full_name} size="sm" />
        <div className="flex-1 min-w-0">
          <div className="flex items-start justify-between gap-2">
            <div className="flex-1 min-w-0">
              <span className="font-semibold text-gray-900 dark:text-white text-sm mr-2">{user.username || user.full_name || 'Unknown'}</span>
              <span className="text-gray-700 dark:text-gray-300 text-sm break-words leading-snug">{comment.text || comment.content}</span>
            </div>
            <button onClick={() => onLikeComment(commentId, isLiked)} className="flex flex-col items-center gap-0.5 flex-shrink-0 active:scale-90 transition-transform pt-0.5">
              <Heart size={14} className={isLiked ? 'text-red-500' : 'text-gray-400 dark:text-gray-500 hover:text-gray-600 dark:hover:text-gray-300 transition-colors'} fill={isLiked ? 'currentColor' : 'none'} />
              {likesCount > 0 && <span className={`text-[10px] leading-none ${isLiked ? 'text-red-400' : 'text-gray-400 dark:text-gray-500'}`}>{likesCount}</span>}
            </button>
          </div>
          <div className="flex items-center gap-3 mt-1.5">
            <span className="text-gray-400 dark:text-gray-500 text-xs">{formatTimeAgo(comment.createdAt || comment.created_at)}</span>
            {likesCount > 0 && <span className="text-gray-400 dark:text-gray-500 text-xs">{fmt(likesCount)} likes</span>}
            <button onClick={() => onReply({ id: commentId, username: user.username || user.full_name })} className="text-gray-500 dark:text-gray-400 text-xs font-semibold hover:text-gray-800 dark:hover:text-white transition-colors">Reply</button>
            {isOwner && (
              <button onClick={() => onDeleteComment(commentId)} className="text-gray-400 dark:text-gray-500 hover:text-red-500 transition-colors active:scale-90 opacity-0 group-hover/comment:opacity-100 ml-auto">
                <Trash2 size={12} />
              </button>
            )}
          </div>
          {hasReplies && (
            <button onClick={handleToggleReplies} disabled={loadingReplies} className="flex items-center gap-2 mt-2 text-xs text-gray-500 dark:text-gray-400 hover:text-gray-800 dark:hover:text-white transition-colors disabled:opacity-60">
              <div className="w-5 h-px bg-gray-300 dark:bg-gray-600" />
              {loadingReplies
                ? <span className="flex items-center gap-1.5"><Loader2 size={11} className="animate-spin" /><span>Loading...</span></span>
                : <span className="font-semibold">{showReplies ? 'Hide replies' : `View all ${replyCount} ${replyCount === 1 ? 'reply' : 'replies'}`}</span>
              }
            </button>
          )}
        </div>
      </div>
      {showReplies && (
        <div className="ml-[52px] pr-4 mb-1">
          {replies.length === 0
            ? <p className="text-gray-400 dark:text-gray-500 text-xs py-2 italic">No replies found.</p>
            : replies.map(reply => (
                <ReplyRow key={reply._id || reply.id} reply={reply} onLikeReply={handleLikeReply} onDeleteReply={handleDeleteReply} currentUserId={currentUserId} />
              ))
          }
        </div>
      )}
    </div>
  );
};

// ─── Comments Content UI ──────────────────────────────────────────────────────
const CommentsContent = ({ comments, loading, replyTo, commentText, setCommentText, setReplyTo, handlePostComment, closeComments, handleLikeComment, handleDeleteComment, registerRefresh }) => (
  <div className="flex flex-col h-full bg-white dark:bg-[#262626]">
    {/* Header */}
    <div className="flex items-center justify-between px-4 py-3 border-b border-gray-100 dark:border-white/10 shrink-0">
      <span className="font-bold text-sm dark:text-white">Comments ({comments.length})</span>
      <button onClick={closeComments} className="p-1 hover:bg-gray-100 dark:hover:bg-white/10 rounded-full text-gray-500 dark:text-gray-400">
        <X size={20} />
      </button>
    </div>

    {/* List */}
    <div className="flex-1 overflow-y-auto p-0 scrollbar-none">
      {loading ? (
        <div className="flex justify-center py-8 text-gray-400"><Loader2 className="animate-spin" /></div>
      ) : comments.length === 0 ? (
        <div className="flex flex-col items-center justify-center h-40 text-gray-400 text-sm">
          <MessageCircle size={32} className="mb-2 opacity-50" />
          No comments yet. Be the first!
        </div>
      ) : (
        comments.map(c => (
          <CommentRow
            key={c._id || c.id}
            comment={c}
            onReply={(user) => setReplyTo({ id: c._id || c.id, rootCommentId: c._id || c.id, username: user.username })}
            onLikeComment={handleLikeComment}
            onDeleteComment={handleDeleteComment}
            currentUserId={null} // Pass user ID if available
            registerRefresh={registerRefresh}
          />
        ))
      )}
    </div>

    {/* Input */}
    <div className="p-3 border-t border-gray-100 dark:border-white/10 bg-white dark:bg-[#262626] shrink-0">
      {replyTo && (
        <div className="flex items-center justify-between text-xs text-gray-500 mb-2 px-1">
          <span>Replying to <span className="font-bold text-blue-500">@{replyTo.username}</span></span>
          <button onClick={() => setReplyTo(null)}><X size={12} /></button>
        </div>
      )}
      <div className="flex items-center gap-2 bg-gray-100 dark:bg-white/10 rounded-full px-4 py-2">
        <input
          type="text"
          placeholder={replyTo ? `Reply to @${replyTo.username}...` : "Add a comment..."}
          value={commentText}
          onChange={e => setCommentText(e.target.value)}
          onKeyDown={e => e.key === 'Enter' && handlePostComment()}
          className="flex-1 bg-transparent border-none outline-none text-sm dark:text-white placeholder:text-gray-400"
        />
        <button
          onClick={handlePostComment}
          disabled={!commentText.trim()}
          className="text-blue-500 disabled:opacity-50 font-semibold text-sm hover:text-blue-600 transition-colors"
        >
          Post
        </button>
      </div>
    </div>
  </div>
);

// ─── Coin Icon ─────────────────────────────────────────────────────────────────
const CoinIcon = ({ size = 14, className = '' }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none" className={className}>
    <circle cx="12" cy="12" r="10" fill="#F59E0B" stroke="#D97706" strokeWidth="1.5" />
    <text x="12" y="16.5" textAnchor="middle" fontSize="11" fontWeight="bold" fill="#7C2D12">B</text>
  </svg>
);

const FALLBACK_CATEGORIES = [
  'All', 'Accessories', 'Action Figures', 'Art Supplies', 'Baby Products',
  'Beauty & Personal Care', 'Books', 'Clothing & Apparel', 'Electronics',
  'Food & Beverages', 'Footwear', 'Gaming', 'Health & Wellness', 'Home & Kitchen',
  'Jewellery', 'Mobile & Tablets', 'Pet Supplies', 'Sports & Fitness', 'Toys', 'Travel',
];

const fmt = (n = 0) => {
  if (n >= 1_000_000) return (n / 1_000_000).toFixed(1) + 'M';
  if (n >= 1_000) return (n / 1_000).toFixed(1) + 'k';
  return String(n);
};

const mediaUrl = (ad) => {
  const m = ad?.media?.[0];
  if (!m) return null;
  if (m.fileUrl && m.fileUrl.startsWith('http')) return m.fileUrl;
  if (m.fileName) return `${BASE_URL}/uploads/${m.fileName}`;
  return null;
};

// ─── Follow Button ─────────────────────────────────────────────────────────────
const FollowButton = ({ userId, mobile = false }) => {
  const [followed, setFollowed] = useState(false);
  const [loading, setLoading] = useState(false);

  const toggle = async (e) => {
    e.stopPropagation();
    if (loading || !userId) return;
    setLoading(true);
    const wasFollowed = followed;
    setFollowed(!wasFollowed);
    try {
      const endpoint = wasFollowed ? '/api/unfollow' : '/api/follow';
      const res = await fetch(`${BASE_URL}${endpoint}`, {
        method: 'POST',
        headers: authHeaders(),
        body: JSON.stringify({ followedUserId: userId }),
      });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
    } catch (err) {
      console.error('Follow toggle failed:', err);
      setFollowed(wasFollowed);
    } finally {
      setLoading(false);
    }
  };

  return (
    <button
      onClick={toggle}
      disabled={loading}
      className={`flex items-center gap-1 px-2.5 py-0.5 rounded-lg text-[11px] font-semibold transition-all
        ${followed
          ? mobile
            ? 'border border-white/40 bg-white/20 text-white backdrop-blur-sm'
            : 'border border-green-500/60 bg-green-500/10 text-green-400'
          : mobile
            ? 'border border-white/40 bg-white/10 text-white backdrop-blur-sm hover:bg-white/20'
            : 'border border-blue-500/60 bg-blue-500/10 text-blue-400 hover:bg-blue-500/20'
        } ${loading ? 'opacity-60 cursor-not-allowed' : ''}`}
    >
      {loading
        ? <Loader2 size={10} className="animate-spin" />
        : followed ? <UserCheck size={11} /> : <UserPlus size={11} />
      }
      <span>{followed ? 'Following' : 'Follow'}</span>
    </button>
  );
};

// ─── Action Buttons ────────────────────────────────────────────────────────────
const ActionButtons = ({ ad, likedIds, toggleLike, savedIds, toggleSave, mobile = false, onComment }) => (
  <div className="flex flex-col items-center gap-4">
    {/* Like */}
    <button onClick={() => toggleLike(ad._id)} className="flex flex-col items-center gap-1">
      <div className={`w-10 h-10 rounded-full flex items-center justify-center transition-all active:scale-90
        ${mobile ? 'bg-black/30 backdrop-blur-sm' : 'bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-700 shadow-sm hover:bg-gray-50 dark:hover:bg-gray-800'}`}>
        <Heart size={20} className={(likedIds.has(ad._id) || ad.is_liked_by_me)
          ? 'text-red-500 fill-red-500'
          : mobile ? 'text-white' : 'text-gray-800 dark:text-white'} />
      </div>
      <span className={`text-xs font-semibold ${mobile ? 'text-white' : 'text-gray-700 dark:text-white'}`}>
        {fmt(ad.likes_count)}
      </span>
    </button>

    {/* Comment */}
    <button onClick={() => onComment && onComment(ad)} className="flex flex-col items-center gap-1">
      <div className={`w-10 h-10 rounded-full flex items-center justify-center transition-all active:scale-90
        ${mobile ? 'bg-black/30 backdrop-blur-sm' : 'bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-700 shadow-sm hover:bg-gray-50 dark:hover:bg-gray-800'}`}>
        <MessageCircle size={20} className={mobile ? 'text-white' : 'text-gray-800 dark:text-white'} />
      </div>
      <span className={`text-xs font-semibold ${mobile ? 'text-white' : 'text-gray-700 dark:text-white'}`}>
        {fmt(ad.comments_count)}
      </span>
    </button>

    {/* Share */}
    <button className="flex flex-col items-center gap-1">
      <div className={`w-10 h-10 rounded-full flex items-center justify-center transition-all active:scale-90
        ${mobile ? 'bg-black/30 backdrop-blur-sm' : 'bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-700 shadow-sm hover:bg-gray-50 dark:hover:bg-gray-800'}`}>
        <Send size={18} className={`-rotate-12 relative left-[-2px] ${mobile ? 'text-white' : 'text-gray-800 dark:text-white'}`} />
      </div>
      <span className={`text-xs font-semibold ${mobile ? 'text-white' : 'text-gray-700 dark:text-white'}`}>Share</span>
    </button>

    {/* Save */}
    <button onClick={() => toggleSave(ad._id)} className="flex flex-col items-center gap-1">
      <div className={`w-10 h-10 rounded-full flex items-center justify-center transition-all active:scale-90
        ${mobile ? 'bg-black/30 backdrop-blur-sm' : 'bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-700 shadow-sm hover:bg-gray-50 dark:hover:bg-gray-800'}`}>
        <Bookmark size={20} className={savedIds.has(ad._id)
          ? (mobile ? 'text-yellow-400 fill-yellow-400' : 'text-yellow-500 fill-yellow-500')
          : mobile ? 'text-white' : 'text-gray-800 dark:text-white'} />
      </div>
      <span className={`text-xs font-semibold ${mobile ? 'text-white' : 'text-gray-700 dark:text-white'}`}>Save</span>
    </button>

    {/* More */}
    <button className="flex flex-col items-center gap-1">
      <div className={`w-10 h-10 rounded-full flex items-center justify-center transition-all active:scale-90
        ${mobile ? 'bg-black/30 backdrop-blur-sm' : 'bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-700 shadow-sm hover:bg-gray-50 dark:hover:bg-gray-800'}`}>
        <MoreHorizontal size={20} className={mobile ? 'text-white' : 'text-gray-800 dark:text-white'} />
      </div>
    </button>

    {/* Avatar disc */}
    <div className={`w-9 h-9 rounded-full border-2 ${mobile ? 'border-white' : 'border-gray-300 dark:border-gray-600'} overflow-hidden shadow-md mt-1`}>
      {ad.user_id?.avatar_url
        ? <img src={ad.user_id.avatar_url} className="w-full h-full object-cover" alt="user" />
        : <div className="w-full h-full bg-gradient-to-br from-purple-500 to-pink-500 flex items-center justify-center text-white text-xs font-bold">
            {(ad.vendor_id?.business_name || 'A')[0]}
          </div>
      }
    </div>
  </div>
);

// ─── Product Offer ─────────────────────────────────────────────────────────────
const ProductOffer = ({ offer }) => {
  if (!offer) return null;
  const href = offer.link && !['daasda', '', '#'].includes(offer.link) ? offer.link : '#';
  return (
    <a href={href} target="_blank" rel="noopener noreferrer"
      className="flex items-center gap-2 bg-white/10 backdrop-blur-md border border-white/20 rounded-xl px-3 py-2 mt-2 hover:bg-white/20 transition-colors">
      <ShoppingBag size={14} className="text-white shrink-0" />
      <div className="flex-1 min-w-0">
        <p className="text-white text-xs font-semibold truncate">{offer.title}</p>
        {offer.description && <p className="text-white/60 text-[10px] truncate">{offer.description}</p>}
      </div>
      {offer.price > 0 && (
        <span className="text-amber-300 text-xs font-bold shrink-0">Rs.{offer.price.toLocaleString()}</span>
      )}
    </a>
  );
};

// ─── Main Component ────────────────────────────────────────────────────────────
const Ads = ({ feedMode = 'user' }) => {
  const { userObject } = useSelector((state) => state.auth);
  const isVendorUser = userObject?.role === 'vendor';

  const [categories] = useState(FALLBACK_CATEGORIES);
  const [activeCategory, setActiveCategory] = useState('All');
  const [ads, setAds] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [currentIndex, setCurrentIndex] = useState(0);
  const [isMuted, setIsMuted] = useState(true);
  const [touchStartY, setTouchStartY] = useState(null);
  const [progress, setProgress] = useState(0);
  const [likedIds, setLikedIds] = useState(new Set());
  const [savedIds, setSavedIds] = useState(new Set());

  // Comments state
  const [activeCommentAdId, setActiveCommentAdId] = useState(null);
  const [comments, setComments] = useState([]);
  const [loadingComments, setLoadingComments] = useState(false);
  const [replyTo, setReplyTo] = useState(null);
  const [commentText, setCommentText] = useState('');
  const refreshRepliesMap = useRef({});
  const actionPanelRef = useRef(null);
  const [actionPanelRight, setActionPanelRight] = useState(100);

  const isAnimatingRef = useRef(false);
  const videoRefs = useRef({});
  const progressIntervalRef = useRef(null);
  const imageTimerRef = useRef(null);

  // Measure action-panel position so comment popup arrow aligns correctly
  useEffect(() => {
    const measure = () => {
      if (actionPanelRef.current) {
        const rect = actionPanelRef.current.getBoundingClientRect();
        setActionPanelRight(window.innerWidth - rect.left + 10);
      }
    };
    measure();
    window.addEventListener('resize', measure);
    return () => window.removeEventListener('resize', measure);
  });

  // ── Fetch Ads ────────────────────────────────────────────────────────────────
  const fetchAds = useCallback(async (category = 'All') => {
    setLoading(true);
    setError(null);
    try {
      // Use the same feed for vendors for now to ensure they see ads
      // TODO: Implement specific vendor feed endpoints if required (e.g. /api/ads/vendor/feed)
      const paths = ['/api/ads/feed'];

      let lastStatus = 0;
      for (const path of paths) {
        const url = category === 'All'
          ? `${BASE_URL}${path}`
          : `${BASE_URL}${path}?category=${encodeURIComponent(category)}`;

        const res = await fetch(url, { headers: authHeaders() });
        lastStatus = res.status;
        if (!res.ok) continue;

        const data = await res.json();
        const list = Array.isArray(data) ? data : (data.data || data.ads || []);
        setAds(list);
        setCurrentIndex(0);
        setProgress(0);
        setLikedIds(new Set(list.filter(a => a.is_liked_by_me).map(a => a._id)));
        return;
      }
      throw new Error(`HTTP ${lastStatus || 0}`);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }, [feedMode]);

  useEffect(() => { fetchAds(activeCategory); }, [activeCategory, fetchAds]);

  // ── Progress / Timer ─────────────────────────────────────────────────────────
  const clearTimers = () => {
    clearInterval(progressIntervalRef.current);
    clearInterval(imageTimerRef.current);
  };

  useEffect(() => {
    if (!ads.length) return;
    clearTimers();

    const currentAd = ads[currentIndex];
    if (!currentAd) return;

    const isVideo = currentAd.media?.[0]?.media_type === 'video';

    if (isVideo) {
      // Track actual video playback
      const vid = videoRefs.current[currentIndex];
      if (!vid) return;
      vid.currentTime = 0;
      setProgress(0);
      vid.play().catch(() => {});
      progressIntervalRef.current = setInterval(() => {
        if (vid.duration) setProgress((vid.currentTime / vid.duration) * 100);
      }, 100);
    } else {
      // 15-second countdown for images
      setProgress(0);
      const startTime = Date.now();
      const totalMs = IMAGE_AD_DURATION * 1000;

      imageTimerRef.current = setInterval(() => {
        const elapsed = Date.now() - startTime;
        const pct = Math.min((elapsed / totalMs) * 100, 100);
        setProgress(pct);
        if (pct >= 100) {
          clearInterval(imageTimerRef.current);
          // Auto-advance
          setCurrentIndex(prev => (prev + 1 < ads.length ? prev + 1 : prev));
        }
      }, 100);
    }

    return () => clearTimers();
  }, [currentIndex, ads]);

  // ── Navigation ───────────────────────────────────────────────────────────────
  const goToIndex = useCallback((index) => {
    if (isAnimatingRef.current) return;
    const next = Math.min(ads.length - 1, Math.max(0, index));
    if (next === currentIndex) return;
    isAnimatingRef.current = true;
    const curVid = videoRefs.current[currentIndex];
    if (curVid) curVid.pause();
    setCurrentIndex(next);
    setTimeout(() => { isAnimatingRef.current = false; }, 500);
  }, [currentIndex, ads.length]);

  useEffect(() => {
    const onKey = (e) => {
      if (e.key === 'ArrowDown') goToIndex(currentIndex + 1);
      else if (e.key === 'ArrowUp') goToIndex(currentIndex - 1);
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [goToIndex, currentIndex]);

  const handleWheel = useCallback((e) => {
    if (Math.abs(e.deltaY) < 30) return;
    e.deltaY > 0 ? goToIndex(currentIndex + 1) : goToIndex(currentIndex - 1);
  }, [goToIndex, currentIndex]);

  const handleTouchStart = (e) => setTouchStartY(e.touches[0].clientY);
  const handleTouchEnd = (e) => {
    if (touchStartY === null) return;
    const diff = touchStartY - e.changedTouches[0].clientY;
    if (Math.abs(diff) > 50) diff > 0 ? goToIndex(currentIndex + 1) : goToIndex(currentIndex - 1);
    setTouchStartY(null);
  };

  // ── Like / Unlike ────────────────────────────────────────────────────────────
  const toggleLike = useCallback(async (adId) => {
    const isLiked = likedIds.has(adId);
    setLikedIds(prev => { const s = new Set(prev); isLiked ? s.delete(adId) : s.add(adId); return s; });
    setAds(prev => prev.map(a => a._id === adId
      ? { ...a, likes_count: a.likes_count + (isLiked ? -1 : 1), is_liked_by_me: !isLiked } : a));
    try {
      const endpoint = isLiked ? `/api/ads/${adId}/dislike` : `/api/ads/${adId}/like`;
      const res = await fetch(`${BASE_URL}${endpoint}`, { method: 'POST', headers: authHeaders() });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
    } catch (err) {
      console.error('Like failed:', err);
      setLikedIds(prev => { const s = new Set(prev); isLiked ? s.add(adId) : s.delete(adId); return s; });
      setAds(prev => prev.map(a => a._id === adId
        ? { ...a, likes_count: a.likes_count + (isLiked ? 1 : -1), is_liked_by_me: isLiked } : a));
    }
  }, [likedIds]);

  const toggleSave = useCallback((adId) => {
    setSavedIds(prev => { const s = new Set(prev); s.has(adId) ? s.delete(adId) : s.add(adId); return s; });
  }, []);

  // ── Comments Logic ──────────────────────────────────────────────────────────
  const fetchComments = useCallback(async (adId) => {
    if (!adId) return;
    setLoadingComments(true);
    try {
      const res = await fetch(`${BASE_URL}/api/posts/${adId}/comments`, { headers: authHeaders() });
      if (res.ok) {
        const data = await res.json();
        setComments(Array.isArray(data) ? data : (data.comments || data.data || []));
      }
    } catch (e) { console.error(e); }
    finally { setLoadingComments(false); }
  }, []);

  const openComments = useCallback((ad) => {
    setActiveCommentAdId(ad._id);
    fetchComments(ad._id);
  }, [fetchComments]);

  const closeComments = useCallback(() => {
    setActiveCommentAdId(null);
    setComments([]);
    setReplyTo(null);
    setCommentText('');
  }, []);

  const handlePostComment = async () => {
    if (!commentText.trim() || !activeCommentAdId) return;
    try {
      const endpoint = replyTo
        ? `${BASE_URL}/api/comments/${replyTo.id}/reply`
        : `${BASE_URL}/api/posts/${activeCommentAdId}/comment`;

      const res = await fetch(endpoint, {
        method: 'POST',
        headers: authHeaders(),
        body: JSON.stringify({ text: commentText })
      });

      if (res.ok) {
        const newComment = await res.json();
        setCommentText('');
        setReplyTo(null);

        if (replyTo) {
          if (refreshRepliesMap.current[replyTo.rootCommentId]) {
            refreshRepliesMap.current[replyTo.rootCommentId]();
          }
        } else {
          setComments(prev => [newComment, ...prev]);
          setAds(prev => prev.map(a => a._id === activeCommentAdId ? { ...a, comments_count: (a.comments_count || 0) + 1 } : a));
        }
      }
    } catch (e) { console.error('Post comment error:', e); }
  };

  const handleLikeComment = async (commentId, isLiked) => {
    const endpoint = isLiked ? `${BASE_URL}/api/comments/${commentId}/unlike` : `${BASE_URL}/api/comments/${commentId}/like`;
    setComments(prev => prev.map(c => {
      if ((c._id || c.id) !== commentId) return c;
      return { ...c, is_liked_by_me: !isLiked, likes_count: isLiked ? Math.max(0, (c.likes_count || 1) - 1) : (c.likes_count || 0) + 1 };
    }));
    try { await fetch(endpoint, { method: 'POST', headers: authHeaders() }); }
    catch (e) { console.error(e); }
  };

  const handleDeleteComment = async (commentId) => {
    try {
      const res = await fetch(`${BASE_URL}/api/comments/${commentId}`, { method: 'DELETE', headers: authHeaders() });
      if (res.ok) {
        setComments(prev => prev.filter(c => (c._id || c.id) !== commentId));
        setAds(prev => prev.map(a => a._id === activeCommentAdId ? { ...a, comments_count: Math.max(0, (a.comments_count || 1) - 1) } : a));
      }
    } catch (e) { console.error('Delete comment error:', e); }
  };

  const registerRefresh = useCallback((commentId, fn) => {
    refreshRepliesMap.current[commentId] = fn;
  }, []);

  const ad = ads[currentIndex];

  // ─── Render ──────────────────────────────────────────────────────────────────
  if (feedMode === 'user' && isVendorUser) return <Navigate to="/vendor-ads" replace />;

  return (
    <div className="flex flex-col bg-white dark:bg-black overflow-hidden">

      {/* Desktop top bar */}
      <div className="hidden md:flex items-center gap-2 px-4 py-2 border-b border-gray-200 dark:border-gray-800 shrink-0">
        <button className="p-1.5 hover:bg-gray-100 dark:hover:bg-gray-800 rounded-lg text-gray-500 mr-1">
          <ChevronLeft size={16} />
        </button>
        <div className="flex items-center gap-1 overflow-x-auto scrollbar-none flex-1">
          {categories.map(cat => (
            <button key={cat} onClick={() => setActiveCategory(cat)}
              className={`px-3 py-1 rounded-full text-xs font-semibold whitespace-nowrap transition-all
                ${activeCategory === cat
                  ? 'bg-gray-900 dark:bg-white text-white dark:text-black'
                  : 'text-gray-500 dark:text-gray-400 hover:bg-gray-100 dark:hover:bg-gray-800'}`}>
              {cat}
            </button>
          ))}
        </div>
        <button className="p-1.5 hover:bg-gray-100 dark:hover:bg-gray-800 rounded-lg text-gray-500 ml-4 shrink-0">
          <Search size={18} />
        </button>
      </div>

      {/* Feed */}
      <div className="flex flex-1 min-h-0 overflow-hidden relative mt-[5px]">
        <div className="flex-1 flex items-center justify-center relative overflow-hidden h-full"
          onWheel={handleWheel} onTouchStart={handleTouchStart} onTouchEnd={handleTouchEnd}>

          {/* Mobile top bar */}
          <div className="md:hidden absolute top-0 left-0 right-0 z-30 flex items-center px-3 pt-3 pb-1 gap-3 bg-gradient-to-b from-black/60 to-transparent">
            <button className="w-8 h-8 flex items-center justify-center shrink-0">
              <ChevronLeft size={22} className="text-white" />
            </button>
            <div className="flex-1 flex items-center gap-2 overflow-x-auto scrollbar-none mask-linear-fade">
              {categories.map(cat => (
                <button key={cat} onClick={() => setActiveCategory(cat)}
                  className={`px-3 py-1 rounded-full text-[13px] font-semibold whitespace-nowrap border transition-all
                    ${activeCategory === cat
                      ? 'bg-white text-black border-white'
                      : 'text-white/90 border-white/20 bg-black/30 backdrop-blur-md'}`}>
                  {cat}
                </button>
              ))}
            </div>
            <button className="w-8 h-8 flex items-center justify-center shrink-0">
              <Search size={20} className="text-white" />
            </button>
          </div>

          {/* Loading */}
          {loading && (
            <div className="flex flex-col items-center gap-3 text-gray-400">
              <Loader2 size={32} className="animate-spin" />
              <span className="text-sm">Loading ads…</span>
            </div>
          )}

          {/* Error */}
          {!loading && error && (
            <div className="flex flex-col items-center gap-3 text-center px-6">
              <p className="text-red-400 font-semibold">Failed to load ads</p>
              <p className="text-gray-500 text-sm">{error}</p>
              <button onClick={() => fetchAds(activeCategory)}
                className="px-4 py-2 bg-gray-900 dark:bg-white text-white dark:text-black rounded-full text-sm font-semibold">
                Retry
              </button>
            </div>
          )}

          {/* Empty */}
          {!loading && !error && ads.length === 0 && (
            <p className="text-gray-400 text-sm">No ads found for this category.</p>
          )}

          {/* Carousel */}
          {!loading && !error && ads.length > 0 && (
            <div className="relative w-full h-full md:w-[360px] md:h-[90vh] overflow-hidden md:rounded-2xl md:shadow-2xl bg-black">

              {/* ── Progress bar ── */}
              <div className="absolute top-0 left-0 right-0 z-40 h-1 bg-white/20">
                <div className="h-full bg-white" style={{ width: `${progress}%`, transition: 'width 0.1s linear' }} />
              </div>

              {/* Slides */}
              <div className="h-full w-full transition-transform duration-500 ease-out"
                style={{ transform: `translateY(-${currentIndex * 100}%)` }}>

                {ads.map((a, index) => {
                  const src = mediaUrl(a);
                  const isVideo = a.media?.[0]?.media_type === 'video';
                  const isCurrent = index === currentIndex;

                  return (
                    <div key={a._id} className="relative w-full bg-black flex items-center justify-center"
                      style={{ height: '100%', minHeight: '100%' }}>

                      {/* Media */}
                      {isVideo ? (
                        <video
                          ref={el => videoRefs.current[index] = el}
                          src={src}
                          className="w-full h-full object-cover"
                          loop muted={isMuted} playsInline autoPlay={isCurrent}
                        />
                      ) : src ? (
                        <img src={src} className="w-full h-full object-cover"
                          alt={a.caption || a.vendor_id?.business_name || 'Ad'}
                          style={a.media?.[0]?.image_editing?.filter?.css
                            ? { filter: a.media[0].image_editing.filter.css } : {}} />
                      ) : (
                        <div className="w-full h-full flex items-center justify-center bg-gradient-to-br from-purple-900 to-pink-900">
                          <div className="text-center px-6">
                            <div className="text-5xl mb-3">🛍️</div>
                            <p className="text-white font-bold text-lg">{a.vendor_id?.business_name}</p>
                            <p className="text-white/70 text-sm mt-1">{a.category}</p>
                          </div>
                        </div>
                      )}

                      {/* Gradient */}
                      <div className="absolute inset-0 bg-gradient-to-b from-black/30 via-transparent to-black/80 pointer-events-none" />

                      {/* Mute btn — video only */}
                      {isVideo && isCurrent && (
                        <button onClick={() => setIsMuted(m => !m)}
                          className="absolute lg:right-4 lg:bottom-5 bottom-[80px] right-[60px] bg-black/50 p-2 rounded-full text-white backdrop-blur-sm hover:bg-black/70 z-20">
                          {isMuted ? <VolumeX size={16} /> : <Volume2 size={16} />}
                        </button>
                      )}

                      {/* Coins badge */}
                      {a.coins_reward > 0 && (
                        <div className="absolute top-10 left-3 z-20 flex items-center gap-1 bg-amber-500/80 backdrop-blur-sm rounded-full px-2 py-1">
                          <CoinIcon size={12} />
                          <span className="text-white text-[10px] font-bold">+{a.coins_reward}</span>
                        </div>
                      )}

                      {/* Bottom info */}
                      <div className="absolute bottom-0 left-0 w-full p-4 pb-20 md:pb-6 z-20">
                        {/* Vendor row */}
                        <div className="flex items-center gap-2 mb-2 flex-wrap">
                          {a.user_id?.avatar_url
                            ? <img src={a.user_id.avatar_url} className="w-8 h-8 rounded-full border border-white/30 object-cover shrink-0" alt="user" />
                            : <div className="w-8 h-8 rounded-full border border-white/30 bg-gradient-to-br from-purple-500 to-pink-500 flex items-center justify-center text-white text-xs font-bold shrink-0">
                                {(a.vendor_id?.business_name || 'A')[0]}
                              </div>
                          }
                          <span className="font-bold text-white text-sm">
                            {a.vendor_id?.business_name || a.user_id?.username}
                          </span>
                          {a.total_budget_coins > 0 && (
                            <div className="flex items-center gap-1 bg-amber-500/20 border border-amber-400/40 rounded-full px-1.5 py-0.5">
                              <CoinIcon size={11} />
                              <span className="text-amber-300 text-[10px] font-bold">{fmt(a.total_budget_coins)}</span>
                            </div>
                          )}
                          {/* Follow button */}
                          <FollowButton userId={a.user_id?._id} mobile />
                        </div>

                        {a.caption && (
                          <p className="text-white text-sm leading-relaxed mb-1.5 line-clamp-2">{a.caption}</p>
                        )}

                        <div className="flex items-center gap-2 flex-wrap mb-1">
                          <span className="text-white/60 text-[10px]">{a.category}</span>
                          {a.hashtags?.slice(0, 3).map(h => (
                            <span key={h} className="text-white/50 text-[10px]">#{h}</span>
                          ))}
                        </div>

                        {a.product_offer?.length > 0 && <ProductOffer offer={a.product_offer[0]} />}

                        <div className="flex items-center gap-1.5 text-white/70 text-xs mt-1.5">
                          <Music2 size={11} />
                          <div className="overflow-hidden w-36">
                            <span className="whitespace-nowrap" style={{ animation: 'marquee 6s linear infinite' }}>
                              {a.target_location?.join(', ') || 'Global'} · {a.target_language?.join(', ') || 'All Languages'}
                            </span>
                          </div>
                        </div>
                      </div>

                      {/* Mobile right actions */}
                      {isCurrent && (
                        <div className="md:hidden absolute right-3 bottom-[80px] z-30">
                          <ActionButtons
                            ad={a}
                            mobile
                            likedIds={likedIds}
                            toggleLike={toggleLike}
                            savedIds={savedIds}
                            toggleSave={toggleSave}
                            onComment={openComments}
                          />
                        </div>
                      )}
                    </div>
                  );
                })}
              </div>
            </div>
          )}

          {/* Desktop right actions */}
          {!loading && !error && ad && (
            <div ref={actionPanelRef} className="hidden md:flex flex-col gap-1 ml-4 justify-end h-full md:h-[85vh] pb-4">
              <ActionButtons
                ad={ad}
                likedIds={likedIds}
                toggleLike={toggleLike}
                savedIds={savedIds}
                toggleSave={toggleSave}
                onComment={openComments}
              />
            </div>
          )}
        </div>
      </div>

      {/* ─── Comments Overlay (Desktop Popup + Mobile Bottom Sheet) ─── */}
      {activeCommentAdId && (
        <>
          {/* Mobile Overlay */}
          <div className="md:hidden absolute inset-0 z-50 bg-black/50 backdrop-blur-sm flex items-end">
            <div className="w-full h-[70vh] bg-white dark:bg-gray-900 rounded-t-2xl flex flex-col shadow-2xl overflow-hidden animate-in slide-in-from-bottom duration-200">
              <CommentsContent
                comments={comments}
                loading={loadingComments}
                replyTo={replyTo}
                commentText={commentText}
                setCommentText={setCommentText}
                setReplyTo={setReplyTo}
                handlePostComment={handlePostComment}
                closeComments={closeComments}
                handleLikeComment={handleLikeComment}
                handleDeleteComment={handleDeleteComment}
                registerRefresh={registerRefresh}
              />
            </div>
          </div>

          {/* Desktop Popup (positioned relative to action panel) */}
          <div className="hidden md:flex fixed z-50" style={{ top: '50%', right: `${actionPanelRight}px`, transform: 'translateY(-50%)', alignItems: 'center' }}>
            {/* Popup content */}
            <div
              className="rounded-2xl shadow-2xl overflow-hidden flex flex-col bg-white dark:bg-[#262626] border border-gray-200 dark:border-white/10"
              style={{ width: 340, height: '78vh', maxHeight: 640, animation: 'slideInRight 0.22s cubic-bezier(0.32,0.72,0,1) forwards' }}
            >
              <CommentsContent
                comments={comments}
                loading={loadingComments}
                replyTo={replyTo}
                commentText={commentText}
                setCommentText={setCommentText}
                setReplyTo={setReplyTo}
                handlePostComment={handlePostComment}
                closeComments={closeComments}
                handleLikeComment={handleLikeComment}
                handleDeleteComment={handleDeleteComment}
                registerRefresh={registerRefresh}
              />
            </div>
            {/* Arrow pointing right (towards buttons) */}
            <div className="flex-shrink-0" style={{ width: 0, height: 0, borderTop: '10px solid transparent', borderBottom: '10px solid transparent', borderLeft: '10px solid white' }} />
          </div>
        </>
      )}

      <style>{`
        @keyframes slideInRight {
          from { opacity: 0; transform: translateX(16px); }
          to   { opacity: 1; transform: translateX(0); }
        }
        @keyframes marquee { 0% { transform: translateX(0); } 100% { transform: translateX(-100%); } }

        .scrollbar-none::-webkit-scrollbar { display: none; }
        .scrollbar-none { -ms-overflow-style: none; scrollbar-width: none; }
        .mask-linear-fade {
          -webkit-mask-image: linear-gradient(to right, transparent 0%, black 5%, black 95%, transparent 100%);
          mask-image: linear-gradient(to right, transparent 0%, black 5%, black 95%, transparent 100%);
        }
      `}</style>
    </div>
  );
};

export default Ads;
