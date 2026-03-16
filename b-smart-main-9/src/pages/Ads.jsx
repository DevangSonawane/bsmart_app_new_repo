import React, { useState, useRef, useEffect, useCallback } from 'react';
import { Navigate, useNavigate, Link } from 'react-router-dom';
import { useSelector } from 'react-redux';
import commentService from '../services/commentServiceJS';
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
const ReplyRow = ({ reply, onLikeReply, onDeleteReply, onReply, currentUserId }) => {
  const rId = reply._id || reply.id;
  // Handle various API shapes: reply.user / reply.users / reply.user_id (populated object)
  const rUser = reply.user || reply.users || (typeof reply.user_id === 'object' ? reply.user_id : {});
  const rLiked = reply.is_liked_by_me || false;
  const rLikes = reply.likes_count ?? 0;
  const rUserId = rUser._id || rUser.id || reply.user_id;
  const isOwner = currentUserId && (
    String(rUserId || '') === String(currentUserId) ||
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
            <span className="text-gray-600 dark:text-gray-300 text-xs break-words leading-snug">{reply.text || reply.content}</span>
          </div>
          <button onClick={() => onLikeReply(rId, rLiked)} className="flex flex-col items-center gap-0.5 flex-shrink-0 active:scale-90 transition-transform pt-0.5">
            <Heart size={12} className={rLiked ? 'text-red-500' : 'text-gray-400 dark:text-gray-500 hover:text-gray-600 dark:hover:text-gray-300 transition-colors'} fill={rLiked ? 'currentColor' : 'none'} />
            {rLikes > 0 && <span className={`text-[9px] leading-none ${rLiked ? 'text-red-400' : 'text-gray-400 dark:text-gray-500'}`}>{rLikes}</span>}
          </button>
        </div>
        <div className="flex items-center gap-3 mt-1">
          <span className="text-gray-400 dark:text-gray-500 text-[11px]">{formatTimeAgo(reply.createdAt || reply.created_at)}</span>
          {rLikes > 0 && <span className="text-gray-400 dark:text-gray-500 text-[11px]">{rLikes} likes</span>}
          <button 
            onClick={() => onReply({ id: rId, username: rUser.username || rUser.full_name })} 
            className="text-gray-500 dark:text-gray-400 text-[11px] font-semibold hover:text-gray-800 dark:hover:text-white transition-colors"
          >
            Reply
          </button>
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
// FIX: replies come from parent-level state (replies[commentId]) so they are
// never lost when fetchComments() re-renders the list.
const CommentRow = ({ comment, replies, expanded, onToggleReplies, onReply, onLikeComment, onDeleteComment, onLikeReply, onDeleteReply, currentUserId }) => {
  const commentId = comment._id || comment.id;
  const user = comment.user || comment.users || (typeof comment.user_id === 'object' ? comment.user_id : {});
  const isLiked = comment.is_liked_by_me || false;
  const likesCount = comment.likes_count ?? (Array.isArray(comment.likes) ? comment.likes.length : 0);

  // Use parent replies array; fall back to meta count for the button label
  const currentReplies = replies[commentId] || [];
  const apiReplyCount = getReplyMetaCount(comment);
  const replyCount = currentReplies.length > 0 ? currentReplies.length : apiReplyCount;
  const hasReplies = replyCount > 0;

  const userId = user._id || user.id || (typeof comment.user_id === 'string' ? comment.user_id : null);
  const isOwner = currentUserId && (
    String(userId || '') === String(currentUserId) ||
    String(comment.user_id || '') === String(currentUserId)
  );

  return (
    <div className="group/comment border-b border-gray-100 dark:border-white/5 last:border-b-0 hover:bg-gray-50/70 dark:hover:bg-white/[0.03] transition-colors">
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
            <button onClick={() => onReply({ id: commentId, rootCommentId: commentId, username: user.username || user.full_name })} className="text-gray-500 dark:text-gray-400 text-xs font-semibold hover:text-gray-800 dark:hover:text-white transition-colors">Reply</button>
            {isOwner && (
              <button onClick={() => onDeleteComment(commentId)} className="text-gray-400 dark:text-gray-500 hover:text-red-500 transition-colors active:scale-90 opacity-0 group-hover/comment:opacity-100 ml-auto">
                <Trash2 size={12} />
              </button>
            )}
          </div>
          {/* View / Hide replies button */}
          {hasReplies && (
            <button onClick={() => onToggleReplies(commentId)} className="flex items-center gap-2 mt-2 text-xs text-gray-500 dark:text-gray-400 hover:text-gray-800 dark:hover:text-white transition-colors">
              <div className="w-5 h-px bg-gray-300 dark:bg-gray-600" />
              <span className="font-semibold">
                {expanded
                  ? 'Hide replies'
                  : `View all ${replyCount} ${replyCount === 1 ? 'reply' : 'replies'}`}
              </span>
            </button>
          )}
        </div>
      </div>
      {/* Expanded replies — rendered from parent-level replies state */}
      {expanded && (
        <div className="ml-[52px] pr-4 mb-2 border-l border-gray-200 dark:border-white/10 pl-3">
          {currentReplies.length === 0 ? (
            <div className="flex items-center gap-2 py-2">
              <Loader2 size={12} className="animate-spin text-gray-400" />
              <span className="text-gray-400 text-xs italic">Loading replies...</span>
            </div>
          ) : (
            currentReplies.map(reply => (
              <ReplyRow
                key={reply._id || reply.id}
                reply={reply}
                onLikeReply={onLikeReply}
                onDeleteReply={onDeleteReply}
                onReply={(replyUser) => onReply({ id: reply._id || reply.id, rootCommentId: commentId, username: replyUser.username })}
                currentUserId={currentUserId}
              />
            ))
          )}
        </div>
      )}
    </div>
  );
};

// ─── Comments Content UI ──────────────────────────────────────────────────────
const CommentsContent = ({ comments, replies, expandedComments, onToggleReplies, loading, replyTo, commentText, setCommentText, setReplyTo, handlePostComment, closeComments, handleLikeComment, handleDeleteComment, onLikeReply, onDeleteReply, currentUserId, currentUserAvatar, currentUserName }) => {
  const scrollRef = useRef(null);

  return (
    <div className="flex flex-col h-full bg-white dark:bg-[#262626]">
      {/* Header */}
      <div className="flex items-center justify-between px-4 py-3 border-b border-gray-100 dark:border-white/10 shrink-0">
        <span className="font-bold text-sm dark:text-white">Comments ({comments.length})</span>
        <button onClick={closeComments} className="p-1 hover:bg-gray-100 dark:hover:bg-white/10 rounded-full text-gray-500 dark:text-gray-400">
          <X size={20} />
        </button>
      </div>

      {/* List */}
      <div ref={scrollRef} className="flex-1 overflow-y-auto p-0 scrollbar-none">
        {loading ? (
          <div className="flex justify-center py-8 text-gray-400"><Loader2 className="animate-spin" /></div>
        ) : comments.length === 0 ? (
          <div className="flex flex-col items-center justify-center h-40 text-gray-400 text-sm">
            <MessageCircle size={32} className="mb-2 opacity-50" />
            No comments yet. Be the first!
          </div>
        ) : (
          comments.map(c => {
            const cid = c._id || c.id;
            return (
              <CommentRow
                key={cid}
                comment={c}
                replies={replies}
                expanded={expandedComments[cid]}
                onToggleReplies={onToggleReplies}
                onReply={(user) => setReplyTo({ id: cid, rootCommentId: cid, username: user.username })}
                onLikeComment={handleLikeComment}
                onDeleteComment={handleDeleteComment}
                onLikeReply={onLikeReply}
                onDeleteReply={onDeleteReply}
                currentUserId={currentUserId}
              />
            );
          })
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
        <div className="flex items-center gap-2 bg-gray-100 dark:bg-white/10 rounded-full px-3 py-2">
          <Avatar src={currentUserAvatar} username={currentUserName} size="xs" />
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
};

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

const getReplyMetaCount = (comment) => (
  comment.reply_count ??
  comment.replies_count ??
  comment.replyCount ??
  comment.repliesCount ??
  comment.total_replies ??
  comment.totalReplies ??
  comment.children_count ??
  comment.childrenCount ??
  0
);

const normalizeComments = (payload) => {
  const list = Array.isArray(payload) ? payload : (payload?.comments || payload?.data || []);
  if (!Array.isArray(list)) return [];

  const getId = (item) => item?._id || item?.id;
  const getParentId = (item) => {
    const parent = item?.parent_id ?? item?.parentId;
    if (!parent) return null;
    return typeof parent === 'object' ? (parent._id || parent.id || null) : parent;
  };

  const repliesByParent = new Map();
  const topLevel = [];

  list.forEach((item) => {
    const parentId = getParentId(item);
    if (parentId) {
      const key = String(parentId);
      const arr = repliesByParent.get(key) || [];
      arr.push(item);
      repliesByParent.set(key, arr);
    } else {
      topLevel.push(item);
    }
  });

  const source = topLevel.length > 0 ? topLevel : list;

  return source.map((comment) => {
    const commentId = getId(comment);
    const seededReplies = Array.isArray(comment.replies) ? comment.replies : [];
    const attachedReplies = commentId ? (repliesByParent.get(String(commentId)) || []) : [];
    const merged = [...seededReplies];
    const seen = new Set(seededReplies.map(r => String(getId(r))));

    attachedReplies.forEach((reply) => {
      const rid = String(getId(reply));
      if (!seen.has(rid)) {
        merged.push(reply);
        seen.add(rid);
      }
    });

    const replyCount = Math.max(getReplyMetaCount(comment), merged.length);
    return { ...comment, replies: merged, replies_count: replyCount, reply_count: replyCount };
  });
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

    {/* Dislike */}
  

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

// ─── Caption with "...more" expand ───────────────────────────────────────────
const Caption = ({ text }) => {
  const [expanded, setExpanded] = useState(false);
  if (!text) return null;
  const words = text.trim().split(/\s+/);
  const isLong = words.length > 5;
  const preview = isLong ? words.slice(0, 5).join(' ') : text;

  return (
    <p className="text-white text-sm leading-relaxed mb-2">
      {expanded || !isLong ? (
        <>
          {text}
          {expanded && isLong && (
            <button onClick={() => setExpanded(false)} className="text-white/60 ml-1.5 hover:text-white transition-colors text-xs font-semibold">
              less
            </button>
          )}
        </>
      ) : (
        <>
          {preview}
          <button onClick={() => setExpanded(true)} className="text-white/60 ml-1 hover:text-white transition-colors font-medium">
            ... more
          </button>
        </>
      )}
    </p>
  );
};

// ─── Main Component ────────────────────────────────────────────────────────────
const Ads = ({ feedMode = 'user' }) => {
  const { userObject } = useSelector((state) => state.auth);
  const isVendorUser = userObject?.role === 'vendor';

  const currentUserId = userObject?._id || userObject?.id || null;
  const currentUserAvatar = userObject?.avatar_url || null;
  const currentUserName = userObject?.full_name || userObject?.username || 'You';
  const navigate = useNavigate();
  const pageHeightClass = "h-[calc(100dvh-4rem)] md:h-[calc(100dvh-1rem)]";

  useEffect(() => {
    const prevHtmlOverflow = document.documentElement.style.overflow;
    const prevBodyOverflow = document.body.style.overflow;
    document.documentElement.style.overflow = 'hidden';
    document.body.style.overflow = 'hidden';
    return () => {
      document.documentElement.style.overflow = prevHtmlOverflow;
      document.body.style.overflow = prevBodyOverflow;
    };
  }, []);

  // ── Wallet balance state ─────────────────────────────────────────────────
  const [walletBalance, setWalletBalance] = useState(
    userObject?.wallet?.balance ? Math.floor(Number(userObject.wallet.balance)) : 0
  );

  const fetchWalletBalance = useCallback(async () => {
    try {
      const res = await fetch(`${BASE_URL}/api/wallet`, { headers: authHeaders() });
      if (!res.ok) return;
      const data = await res.json();
      // Handle various backend response shapes
      const bal =
        data?.balance ??
        data?.wallet?.balance ??
        data?.data?.balance ??
        data?.data?.wallet?.balance ??
        data?.user?.wallet?.balance;
      if (bal !== undefined && bal !== null) setWalletBalance(Math.floor(Number(bal)));
    } catch { /* silent */ }
  }, []);

  // ── Search state ────────────────────────────────────────────────────────────
  const [searchOpen, setSearchOpen] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');
  const [searchResults, setSearchResults] = useState([]);
  const [searchLoading, setSearchLoading] = useState(false);
  const [searchDropdownVisible, setSearchDropdownVisible] = useState(false);
  const searchInputRef = React.useRef(null);
  const searchContainerRef = React.useRef(null);

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
  const [coinToast, setCoinToast] = useState(null); // { amount, id }
  // Popup modals for coin rewards
  const [viewRewardPopup, setViewRewardPopup] = useState(null); // { amount } — shown first time only
  const [likeRewardPopup, setLikeRewardPopup] = useState(null); // { amount, isLike } — shown on every like/dislike

  // Track which ad IDs the current user has already viewed this session.
  // Using a ref so it never triggers re-renders and persists across index changes.
  const viewedIdsRef = useRef(null);
  if (viewedIdsRef.current === null) {
    try {
      const stored = sessionStorage.getItem('ads_viewed_ids');
      viewedIdsRef.current = stored ? new Set(JSON.parse(stored)) : new Set();
    } catch {
      viewedIdsRef.current = new Set();
    }
  }

  // Comments state
  const [activeCommentAdId, setActiveCommentAdId] = useState(null);
  const [comments, setComments] = useState([]);
  const [replies, setReplies] = useState({});
  const [expandedComments, setExpandedComments] = useState({});
  const [loadingComments, setLoadingComments] = useState(false);
  const [replyTo, setReplyTo] = useState(null);
  const [commentText, setCommentText] = useState('');
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
        // Store right edge of the action panel so comment popup can anchor to it
        setActionPanelRight(rect.right + 12);
      }
    };
    measure();
    window.addEventListener('resize', measure);
    return () => window.removeEventListener('resize', measure);
  });

  // ── Fetch Ads ────────────────────────────────────────────────────────────────
  // ── Search logic ────────────────────────────────────────────────────────────
  const searchDebounceRef = React.useRef(null);

  const runSearch = useCallback(async (q) => {
    const query = q.trim();
    if (!query) { setSearchResults([]); setSearchDropdownVisible(false); return; }
    setSearchLoading(true);
    try {
      const params = new URLSearchParams({
        q: query,
        status: 'active',
        page: 1,
        limit: 20,
      });
      const res = await fetch(`${BASE_URL}/api/ads/search?${params}`, { headers: authHeaders() });
      const data = await res.json();
      // API may return { ads: [...] } or { data: [...] } or plain array
      const ads = Array.isArray(data) ? data : (data.ads || data.data || data.results || []);
      // Also try to extract user/profile results if the API bundles them
      const users = data.users || data.vendors || [];
      setSearchResults([
        ...users.map(u => ({ _type: 'user', ...u })),
        ...ads.map(a => ({ _type: 'ad', ...a })),
      ]);
      setSearchDropdownVisible(true);
    } catch { setSearchResults([]); }
    finally { setSearchLoading(false); }
  }, []);

  const handleSearchInput = (e) => {
    const q = e.target.value;
    setSearchQuery(q);
    clearTimeout(searchDebounceRef.current);
    if (!q.trim()) { setSearchResults([]); setSearchDropdownVisible(false); return; }
    searchDebounceRef.current = setTimeout(() => runSearch(q), 350);
  };

  const handleSearchOpen = () => {
    setSearchOpen(true);
    setTimeout(() => searchInputRef.current?.focus(), 50);
  };

  const handleSearchClose = () => {
    setSearchOpen(false);
    setSearchQuery('');
    setSearchResults([]);
    setSearchDropdownVisible(false);
  };

  const handleSearchResultClick = (item) => {
    handleSearchClose();
    if (item._type === 'user') {
      navigate(`/profile/${item._id || item.id}`);
    }
    // For ads — just close and let user see feed; or navigate to ad detail if available
  };

  // Close dropdown on outside click
  useEffect(() => {
    const handler = (e) => {
      if (searchContainerRef.current && !searchContainerRef.current.contains(e.target)) {
        setSearchDropdownVisible(false);
      }
    };
    document.addEventListener('mousedown', handler);
    return () => document.removeEventListener('mousedown', handler);
  }, []);

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
  }, []);

  useEffect(() => { fetchAds(activeCategory); }, [activeCategory, fetchAds]);

  const adsRef = useRef(ads);
  useEffect(() => { adsRef.current = ads; }, [ads]);

  // ── Progress / Timer ─────────────────────────────────────────────────────────
  const clearTimers = () => {
    clearInterval(progressIntervalRef.current);
    clearInterval(imageTimerRef.current);
  };

  // ── View Tracking ─────────────────────────────────────────────────────────────
  // Fires POST /api/ads/{id}/view ONLY when the ad is fully watched.
  // For video ads — called when video ends (onEnded).
  // For image ads — called when 15s timer completes (pct >= 100).
  const trackView = useCallback(async (adId) => {
    if (!adId) return;
    const key = String(adId);
    if (viewedIdsRef.current.has(key)) return;

    viewedIdsRef.current.add(key);
    try {
      sessionStorage.setItem('ads_viewed_ids', JSON.stringify([...viewedIdsRef.current]));
    } catch { /* sessionStorage unavailable — in-memory ref still guards */ }

    try {
      const res = await fetch(`${BASE_URL}/api/ads/${adId}/view`, {
        method: 'POST',
        headers: authHeaders(),
        body: JSON.stringify({ user: { id: currentUserId ? String(currentUserId) : '' } }),
      });
      if (!res.ok) {
        viewedIdsRef.current.delete(key);
        throw new Error(`HTTP ${res.status}`);
      }
      // Parse response — backend may return updated wallet/coins directly
      const resData = await res.json().catch(() => ({}));
      const directBal =
        resData?.wallet?.balance ??
        resData?.user?.wallet?.balance ??
        resData?.balance ??
        resData?.data?.balance;
      const coinsRewarded =
        resData?.coins_rewarded ??
        resData?.coins ??
        resData?.reward ??
        resData?.data?.coins_rewarded;
      if (directBal !== undefined) {
        setWalletBalance(Math.floor(Number(directBal)));
      } else {
        // Fallback: poll wallet endpoint (give backend 800ms to settle)
        setTimeout(() => fetchWalletBalance(), 800);
      }
      // Show coin reward POPUP (first-time view only — guard already ensures this runs once)
      const rewardAmount = (coinsRewarded && Number(coinsRewarded) > 0)
        ? Number(coinsRewarded)
        : (() => {
            const adCoins = adsRef.current.find(a => String(a._id) === String(adId))?.coins_reward;
            return adCoins && Number(adCoins) > 0 ? Number(adCoins) : 10;
          })();
      setViewRewardPopup({ amount: rewardAmount });
      // Also keep the small toast as fallback
      const toastId = Date.now();
      setCoinToast({ amount: rewardAmount, id: toastId });
      setTimeout(() => setCoinToast(t => t?.id === toastId ? null : t), 3000);
    } catch (err) {
      console.error('View tracking failed:', err);
    }
  }, [currentUserId, fetchWalletBalance]);

  // tracks ad _id strings that have already received a view API call (never double-fires)
  const viewFiredForAdId = useRef(new Set());

  // ── Image-ad 15s progress timer ──────────────────────────────────────────────
  // Video progress is handled entirely via JSX event props (onTimeUpdate / onEnded).
  useEffect(() => {
    const adsList = adsRef.current;
    if (!adsList.length) return;
    const currentAd = adsList[currentIndex];
    if (!currentAd) return;
    const isVideo = currentAd.media?.[0]?.media_type === 'video';

    // Reset progress bar on every slide change
    setProgress(0);
    clearTimers();

    if (isVideo) return; // video handles its own progress via JSX event handlers

    const startTime = Date.now();
    const totalMs = IMAGE_AD_DURATION * 1000;

    progressIntervalRef.current = setInterval(() => {
      const pct = Math.min(((Date.now() - startTime) / totalMs) * 100, 100);
      setProgress(pct);
      if (pct >= 100) {
        clearInterval(progressIntervalRef.current);
        const adId = String(currentAd._id);
        if (!viewFiredForAdId.current.has(adId)) {
          viewFiredForAdId.current.add(adId);
          trackView(currentAd._id);
        }
        setCurrentIndex(prev => (prev + 1 < adsRef.current.length ? prev + 1 : prev));
      }
    }, 250);

    return () => clearInterval(progressIntervalRef.current);
  }, [currentIndex, trackView]);



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

  // ── Like ─────────────────────────────────────────────────────────────────────
  const toggleLike = useCallback(async (adId) => {
    const isLiked = likedIds.has(adId);

    // Optimistic UI update
    setLikedIds(prev => {
      const s = new Set(prev);
      isLiked ? s.delete(adId) : s.add(adId);
      return s;
    });
    setAds(prev => prev.map(a => a._id === adId
      ? { ...a, likes_count: a.likes_count + (isLiked ? -1 : 1), is_liked_by_me: !isLiked }
      : a));

    try {
      const endpoint = isLiked ? `/api/ads/${adId}/dislike` : `/api/ads/${adId}/like`;
      const res = await fetch(`${BASE_URL}${endpoint}`, {
        method: 'POST',
        headers: authHeaders(),
        body: JSON.stringify({ user: { id: currentUserId ? String(currentUserId) : '' } }),
      });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      // Show like/dislike coin reward popup
      setLikeRewardPopup({ amount: 10, isLike: !isLiked });
    } catch (err) {
      console.error('Like failed:', err);
      // Rollback
      setLikedIds(prev => { const s = new Set(prev); isLiked ? s.add(adId) : s.delete(adId); return s; });
      setAds(prev => prev.map(a => a._id === adId
        ? { ...a, likes_count: a.likes_count + (isLiked ? 1 : -1), is_liked_by_me: isLiked }
        : a));
    }
  }, [likedIds, currentUserId]);

  // ── Dislike ───────────────────────────────────────────────────────────────────

  const toggleSave = useCallback((adId) => {
    setSavedIds(prev => { const s = new Set(prev); s.has(adId) ? s.delete(adId) : s.add(adId); return s; });
  }, []);

  // ── Comments Logic ────────────────────────────────────────────────────────────
  // FIX: mirrors PostDetailModal exactly — replies stored in parent state,
  // auto-loaded for every comment on fetch, never lost on re-render.

  // loadReplies — fetches & stores replies in parent state (keyed by commentId)
  const loadReplies = useCallback(async (commentId) => {
    try {
      const data = await commentService.getReplies(commentId);
      const fetchedReplies = Array.isArray(data) ? data : (data.replies || data.data || []);
      setReplies((prev) => ({ ...prev, [commentId]: fetchedReplies }));
    } catch (error) {
      console.error('Error loading replies:', error);
    }
  }, []);

  // fetchComments — loads all top-level comments AND auto-loads replies for each
  const fetchComments = useCallback(async (adId) => {
    if (!adId) return;
    setLoadingComments(true);
    try {
      const data = await commentService.getComments(adId);
      const normalized = normalizeComments(data);
      setComments(normalized);

      // Auto-load replies for every comment (same as PostDetailModal)
      if (normalized && Array.isArray(normalized)) {
        normalized.forEach((comment) => {
          const commentId = comment._id || comment.id;
          commentService.getReplies(commentId)
            .then((repliesData) => {
              const fetched = Array.isArray(repliesData) ? repliesData : (repliesData.replies || repliesData.data || []);
              if (fetched && fetched.length > 0) {
                setReplies((prev) => ({ ...prev, [commentId]: fetched }));
              }
            })
            .catch((err) => console.error('Error auto-loading replies:', err));
        });
      }
    } catch (e) { console.error(e); }
    finally { setLoadingComments(false); }
  }, []);

  const openComments = useCallback((ad) => {
    setActiveCommentAdId(ad._id);
    setReplies({});
    setExpandedComments({});
    setReplyTo(null);
    setCommentText('');
    fetchComments(ad._id);
  }, [fetchComments]);

  const closeComments = useCallback(() => {
    setActiveCommentAdId(null);
    setComments([]);
    setReplies({});
    setExpandedComments({});
    setReplyTo(null);
    setCommentText('');
  }, []);

  // handlePostComment — identical to PostDetailModal
  const handlePostComment = async () => {
    if (!commentText.trim() || !activeCommentAdId) return;
    const text = commentText.trim();
    const replyInfo = replyTo;
    setCommentText('');
    setReplyTo(null);
    try {
      const parentId = replyInfo ? replyInfo.id : null;
      await commentService.createComment(activeCommentAdId, text, parentId);
      if (replyInfo) {
        // Re-fetch replies for the root comment and keep it expanded
        await loadReplies(replyInfo.rootCommentId);
        setExpandedComments((prev) => ({ ...prev, [replyInfo.rootCommentId]: true }));
      } else {
        // New top-level comment — re-fetch full list so reply counts are correct
        await fetchComments(activeCommentAdId);
        setAds(prev => prev.map(a => a._id === activeCommentAdId
          ? { ...a, comments_count: (a.comments_count || 0) + 1 }
          : a));
      }
    } catch (e) {
      console.error('Post comment error:', e);
      setCommentText(text);
      if (replyInfo) setReplyTo(replyInfo);
    }
  };

  // handleLikeComment — identical to PostDetailModal
  const handleLikeComment = async (commentId, isLiked) => {
    try {
      if (isLiked) {
        await commentService.unlikeComment(commentId);
      } else {
        await commentService.likeComment(commentId);
      }
      fetchComments(activeCommentAdId);
      // Also refresh all currently-loaded replies
      Object.keys(replies).forEach((key) => loadReplies(key));
    } catch (e) { console.error(e); }
  };

  // handleLikeReply — identical to PostDetailModal
  const handleLikeReply = async (replyId, isLikedReply) => {
    try {
      if (isLikedReply) {
        await commentService.unlikeComment(replyId);
      } else {
        await commentService.likeComment(replyId);
      }
      Object.keys(replies).forEach((key) => loadReplies(key));
    } catch (e) { console.error(e); }
  };

  // handleDeleteReply
  const handleDeleteReply = async (replyId) => {
    if (!window.confirm('Are you sure you want to delete this reply?')) return;
    try {
      await commentService.deleteComment(replyId);
      Object.keys(replies).forEach((key) => loadReplies(key));
    } catch (e) { console.error('Delete reply error:', e); }
  };

  // onToggleReplies — load from parent state if not yet fetched
  const onToggleReplies = (commentId) => {
    const isCurrentlyExpanded = expandedComments[commentId];
    if (!isCurrentlyExpanded && (!replies[commentId] || replies[commentId].length === 0)) {
      loadReplies(commentId);
    }
    setExpandedComments((prev) => ({ ...prev, [commentId]: !prev[commentId] }));
  };

  // handleDeleteComment
  const handleDeleteComment = async (commentId) => {
    if (!window.confirm('Are you sure you want to delete this comment?')) return;
    try {
      await commentService.deleteComment(commentId);
      setComments(prev => prev.filter(c => (c._id || c.id) !== commentId));
      setAds(prev => prev.map(a => a._id === activeCommentAdId
        ? { ...a, comments_count: Math.max(0, (a.comments_count || 1) - 1) }
        : a));
    } catch (e) { console.error('Delete comment error:', e); }
  };

  const ad = ads[currentIndex];

  // ─── Render ──────────────────────────────────────────────────────────────────
  if (feedMode === 'user' && isVendorUser) return <Navigate to="/vendor-ads" replace />;

  return (
    <div className={`flex flex-col bg-black overflow-hidden ${pageHeightClass}`}>

      {/* Desktop top bar */}
      <div className="hidden md:flex items-center gap-2 px-4 py-2 border-b border-gray-200 dark:border-gray-800 shrink-0">
        <button onClick={() => navigate(-1)} className="p-1.5 hover:bg-gray-100 dark:hover:bg-gray-800 rounded-lg text-gray-500 mr-1">
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
        {/* Desktop Search */}
        <div ref={searchContainerRef} className="relative ml-4 shrink-0">
          {searchOpen ? (
            <div className="flex items-center gap-2 bg-gray-100 dark:bg-gray-800 rounded-full px-3 py-1.5 w-64">
              <Search size={14} className="text-gray-400 shrink-0" />
              <input
                ref={searchInputRef}
                value={searchQuery}
                onChange={handleSearchInput}
                placeholder="Search ads, users…"
                className="flex-1 bg-transparent text-sm outline-none text-gray-900 dark:text-white placeholder-gray-400"
              />
              {searchLoading
                ? <Loader2 size={14} className="animate-spin text-gray-400 shrink-0" />
                : <button onClick={handleSearchClose}><X size={14} className="text-gray-400 hover:text-gray-700 dark:hover:text-white" /></button>
              }
            </div>
          ) : (
            <button onClick={handleSearchOpen} className="p-1.5 hover:bg-gray-100 dark:hover:bg-gray-800 rounded-lg text-gray-500">
              <Search size={18} />
            </button>
          )}

          {/* Desktop Dropdown */}
          {searchDropdownVisible && searchResults.length > 0 && (
            <div className="absolute right-0 top-full mt-2 w-80 bg-white dark:bg-[#1c1c1e] rounded-2xl shadow-2xl border border-gray-100 dark:border-gray-800 overflow-hidden z-50 max-h-96 overflow-y-auto">
              {/* Users section */}
              {searchResults.filter(r => r._type === 'user').length > 0 && (
                <div>
                  <div className="px-4 py-2 text-[10px] font-bold uppercase tracking-wider text-gray-400 border-b border-gray-50 dark:border-gray-800">People</div>
                  {searchResults.filter(r => r._type === 'user').map(u => (
                    <button key={u._id || u.id} onClick={() => handleSearchResultClick(u)}
                      className="w-full flex items-center gap-3 px-4 py-2.5 hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors text-left">
                      <div className="w-9 h-9 rounded-full overflow-hidden bg-gradient-to-tr from-yellow-400 via-orange-500 to-pink-500 p-[1.5px] shrink-0">
                        <div className="w-full h-full rounded-full bg-white dark:bg-[#1c1c1e] overflow-hidden flex items-center justify-center">
                          {u.avatar_url
                            ? <img src={u.avatar_url} alt="" className="w-full h-full object-cover" />
                            : <span className="text-xs font-bold text-gray-700 dark:text-white">{(u.username || u.full_name || '?')[0].toUpperCase()}</span>
                          }
                        </div>
                      </div>
                      <div className="min-w-0">
                        <div className="text-sm font-semibold text-gray-900 dark:text-white truncate">{u.full_name || u.username}</div>
                        {u.username && <div className="text-xs text-gray-400 truncate">@{u.username}</div>}
                      </div>
                    </button>
                  ))}
                </div>
              )}
              {/* Ads section */}
              {searchResults.filter(r => r._type === 'ad').length > 0 && (
                <div>
                  <div className="px-4 py-2 text-[10px] font-bold uppercase tracking-wider text-gray-400 border-b border-gray-50 dark:border-gray-800">Ads</div>
                  {searchResults.filter(r => r._type === 'ad').map(ad => {
                    const adUser = ad.user_id || ad.vendor_id || {};
                    const thumb = ad.media?.[0]?.fileUrl || ad.media?.[0]?.thumbnail_url;
                    return (
                      <button key={ad._id} onClick={() => handleSearchResultClick(ad)}
                        className="w-full flex items-center gap-3 px-4 py-2.5 hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors text-left">
                        <div className="w-10 h-10 rounded-xl overflow-hidden bg-gray-200 dark:bg-gray-700 shrink-0">
                          {thumb
                            ? <img src={thumb} alt="" className="w-full h-full object-cover" />
                            : <div className="w-full h-full flex items-center justify-center text-gray-400"><ShoppingBag size={14} /></div>
                          }
                        </div>
                        <div className="min-w-0 flex-1">
                          <div className="text-sm font-semibold text-gray-900 dark:text-white truncate">{ad.caption || ad.title || 'Ad'}</div>
                          <div className="flex items-center gap-1.5 mt-0.5">
                            {ad.category && <span className="text-[10px] px-1.5 py-0.5 rounded-full bg-gray-100 dark:bg-gray-700 text-gray-500 dark:text-gray-400 font-medium">{ad.category}</span>}
                            {typeof adUser === 'object' && adUser.username && <span className="text-[10px] text-gray-400">@{adUser.username}</span>}
                          </div>
                        </div>
                      </button>
                    );
                  })}
                </div>
              )}
              {/* No results */}
              {searchResults.length === 0 && !searchLoading && searchQuery.trim() && (
                <div className="flex flex-col items-center justify-center py-8 text-gray-400 gap-2">
                  <Search size={20} className="opacity-40" />
                  <span className="text-sm">No results for "{searchQuery}"</span>
                </div>
              )}
            </div>
          )}
        </div>
      </div>

      {/* Feed */}
      {/* Mobile: black full-screen, card centred and capped at 430px wide */}
      {/* Desktop: white/dark bg, centred phone-card layout */}
      <div className="flex flex-1 min-h-0 overflow-hidden relative">
        <div
          className="flex-1 flex items-center justify-center relative overflow-hidden h-full bg-black md:bg-white dark:bg-black"
          onWheel={handleWheel} onTouchStart={handleTouchStart} onTouchEnd={handleTouchEnd}>

          {/* Mobile top bar — floats over the card */}
          <div className="md:hidden absolute top-0 left-0 right-0 z-30 flex items-center px-3 pt-3 pb-1 gap-3 bg-gradient-to-b from-black/60 to-transparent">
            <button onClick={() => navigate(-1)} className="w-8 h-8 flex items-center justify-center shrink-0">
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
            {/* Mobile Wallet Balance Badge */}
            <Link to="/wallet" className="shrink-0 flex items-center gap-1.5 bg-black/50 backdrop-blur-md border border-white/20 rounded-full px-2.5 py-1.5">
              <div className="w-5 h-5 rounded-full bg-gradient-to-tr from-yellow-400 via-orange-500 to-pink-500 flex items-center justify-center">
                <svg xmlns="http://www.w3.org/2000/svg" width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="white" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
                  <path d="M21 12V7H5a2 2 0 0 1 0-4h14v4"/><path d="M3 5v14a2 2 0 0 0 2 2h16v-5"/><path d="M18 12a2 2 0 0 0 0 4h4v-4Z"/>
                </svg>
              </div>
              <div className="flex flex-col leading-none">
                <span className="text-[9px] text-white/60 font-medium">Balance</span>
                <span className="text-[11px] font-bold text-white">Coins {walletBalance}</span>
              </div>
            </Link>
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
            <div className="
              relative overflow-hidden bg-black
              /* Mobile: full height, capped at 430px wide, centred — Instagram style */
              w-full max-w-[430px] h-full
              /* Desktop: fixed phone card */
              md:w-[360px] md:h-[90vh] md:rounded-2xl md:shadow-2xl
            ">

              {/* ── Progress bar ── */}
              <div className="absolute top-0 left-0 right-0 z-40 h-1 bg-white/20">
                <div className="h-full bg-white transition-none" style={{ width: `${progress}%` }} />
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
                          ref={el => { videoRefs.current[index] = el; }}
                          src={src}
                          className="w-full h-full object-cover"
                          muted={isMuted}
                          playsInline
                          autoPlay={isCurrent}
                          loop={false}
                          onLoadedMetadata={e => {
                            // Seek to trimmed start once metadata (duration) is known
                            if (!isCurrent) return;
                            const m = a.media?.[0];
                            const start = m?.timing_window?.start ?? m?.video_meta?.selected_start ?? 0;
                            if (start > 0) e.target.currentTime = start;
                          }}
                          onTimeUpdate={e => {
                            if (!isCurrent) return;
                            const vid = e.target;
                            const m = a.media?.[0];
                            const start   = m?.timing_window?.start    ?? m?.video_meta?.selected_start  ?? 0;
                            const end     = m?.timing_window?.end      ?? m?.video_meta?.selected_end    ?? null;
                            const dur     = m?.video_meta?.final_duration ?? null;
                            const ct      = vid.currentTime;

                            // Hit the trim end → stop, mark 100%, fire view
                            if (end !== null && ct >= end) {
                              vid.pause();
                              setProgress(100);
                              const key = String(a._id);
                              if (!viewFiredForAdId.current.has(key)) {
                                viewFiredForAdId.current.add(key);
                                trackView(a._id);
                              }
                              return;
                            }

                            // Move progress bar
                            if (dur && dur > 0) {
                              setProgress(Math.min(((ct - start) / dur) * 100, 100));
                            } else if (vid.duration > 0) {
                              setProgress((ct / vid.duration) * 100);
                            }
                          }}
                          onEnded={() => {
                            if (!isCurrent) return;
                            setProgress(100);
                            const key = String(a._id);
                            if (!viewFiredForAdId.current.has(key)) {
                              viewFiredForAdId.current.add(key);
                              trackView(a._id);
                            }
                          }}
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
                          className="absolute bottom-[10px] md:bottom-5 right-[55px] md:right-4 bg-black/50 p-2 rounded-full text-white backdrop-blur-sm hover:bg-black/70 z-20">
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

                      {/* Bottom info — clears bottom nav (64px) on mobile */}
                      <div className="absolute bottom-0 left-0 w-full p-4 md:pb-6 z-20" style={{ paddingRight: '60px' }}>
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

                        <Caption text={a.caption} />

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

                      {/* Mobile right actions — pinned above bottom nav */}
                      {isCurrent && (
                        <div className="md:hidden absolute right-3 bottom-[10px] z-30">
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

          {/* Desktop right actions + nav */}
          {!loading && !error && ad && (
            <div ref={actionPanelRef} className="hidden md:flex flex-col gap-2 ml-4 justify-end h-full md:h-[85vh] pb-4">
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

      {/* Nav arrows */}
      <div className="hidden md:flex fixed right-5 top-1/2 -translate-y-1/2 z-40 flex-col gap-3">
        <button
          onClick={() => goToIndex(currentIndex - 1)}
          disabled={currentIndex === 0}
          className="w-12 h-12 rounded-full dark:bg-white/10 border border-white/20 backdrop-blur-md shadow-2xl flex items-center justify-center hover:bg-white/25 hover:scale-110 active:scale-95 transition-all disabled:opacity-20 disabled:cursor-not-allowed"
        >
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="white" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round"><polyline points="18 15 12 9 6 15" /></svg>
        </button>
        <button
          onClick={() => goToIndex(currentIndex + 1)}
          disabled={currentIndex === ads.length - 1}
          className="w-12 h-12 rounded-full bg-white/10 border border-white/20 backdrop-blur-md shadow-2xl flex items-center justify-center hover:bg-white/25 hover:scale-110 active:scale-95 transition-all disabled:opacity-20 disabled:cursor-not-allowed"
        >
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="white" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round"><polyline points="6 9 12 15 18 9" /></svg>
        </button>
      </div>

      {/* ─── Comments Overlay (Desktop Popup + Mobile Bottom Sheet) ─── */}
      {activeCommentAdId && (
        <>
          {/* Mobile Overlay */}
          <div className="md:hidden fixed inset-0 z-50 bg-black/50 backdrop-blur-sm flex flex-col justify-end">
            {/* Tap backdrop to close */}
            <div className="absolute inset-0" onClick={closeComments} />
            <div
              className="relative w-full bg-white dark:bg-gray-900 rounded-t-2xl flex flex-col shadow-2xl overflow-hidden animate-in slide-in-from-bottom duration-200"
              style={{ height: '72vh', marginBottom: 'max(64px, env(safe-area-inset-bottom, 64px))' }}
            >
              <CommentsContent
                comments={comments}
                replies={replies}
                expandedComments={expandedComments}
                onToggleReplies={onToggleReplies}
                loading={loadingComments}
                replyTo={replyTo}
                commentText={commentText}
                setCommentText={setCommentText}
                setReplyTo={setReplyTo}
                handlePostComment={handlePostComment}
                closeComments={closeComments}
                handleLikeComment={handleLikeComment}
                handleDeleteComment={handleDeleteComment}
                onLikeReply={handleLikeReply}
                onDeleteReply={handleDeleteReply}
                currentUserId={currentUserId}
                currentUserAvatar={currentUserAvatar}
                currentUserName={currentUserName}
              />
            </div>
          </div>

          {/* Desktop Popup — floats to the RIGHT of the action panel, never over the video */}
          <div
            className="hidden md:block fixed z-50"
            style={{
              top: '16%',
              left: `${actionPanelRight}px`,
              transform: 'translateY(-50%)',  
              animation: 'slideInLeft 0.22s cubic-bezier(0.32,0.72,0,1) forwards',
            }}
          >
            {/* Arrow pointing LEFT towards the action buttons */}
            <div style={{ position: 'absolute', left: -10, top: '45%', transform: 'translateY(-50%)', width: 0, height: 0, borderTop: '10px solid transparent', borderBottom: '10px solid transparent', borderRight: '10px solid #262626' }} />
            <div
              className="rounded-2xl shadow-2xl overflow-hidden flex flex-col bg-white dark:bg-[#262626] border border-gray-200 dark:border-white/10"
              style={{ width: 340, height: '78vh', maxHeight: 640 }}
            >
              <CommentsContent
                comments={comments}
                replies={replies}
                expandedComments={expandedComments}
                onToggleReplies={onToggleReplies}
                loading={loadingComments}
                replyTo={replyTo}
                commentText={commentText}
                setCommentText={setCommentText}
                setReplyTo={setReplyTo}
                handlePostComment={handlePostComment}
                closeComments={closeComments}
                handleLikeComment={handleLikeComment}
                handleDeleteComment={handleDeleteComment}
                onLikeReply={handleLikeReply}
                onDeleteReply={handleDeleteReply}
                currentUserId={currentUserId}
                currentUserAvatar={currentUserAvatar}
                currentUserName={currentUserName}
              />
            </div>
          </div>
        </>
      )}

      {/* ── View Reward Popup (first-time watch) ── */}
      {viewRewardPopup && (
        <div className="fixed inset-0 z-[200] flex items-center justify-center pointer-events-none">
          <div
            className="pointer-events-auto bg-white dark:bg-[#1c1c1e] rounded-3xl shadow-2xl px-8 py-7 flex flex-col items-center gap-4 border border-amber-200 dark:border-amber-500/30"
            style={{ animation: 'popupIn 0.4s cubic-bezier(0.22,1,0.36,1) forwards', minWidth: 260 }}
          >
            {/* Coin burst */}
            <div className="relative">
              <div className="w-20 h-20 rounded-full bg-gradient-to-br from-yellow-300 via-amber-400 to-orange-500 flex items-center justify-center shadow-lg shadow-amber-300/50" style={{ animation: 'coinPulse 0.6s ease-out' }}>
                <svg width="44" height="44" viewBox="0 0 24 24" fill="none">
                  <circle cx="12" cy="12" r="10" fill="#FCD34D" stroke="#D97706" strokeWidth="1.5"/>
                  <text x="12" y="16.5" textAnchor="middle" fontSize="11" fontWeight="bold" fill="#7C2D12">B</text>
                </svg>
              </div>
              <div className="absolute -top-1 -right-1 w-6 h-6 bg-green-500 rounded-full flex items-center justify-center shadow-md">
                <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="white" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round"><polyline points="20 6 9 17 4 12"/></svg>
              </div>
            </div>
            <div className="text-center">
              <p className="text-2xl font-black text-amber-500">+{viewRewardPopup.amount} Coins!</p>
              <p className="text-gray-700 dark:text-gray-300 font-semibold text-sm mt-0.5">Earned for watching the full ad</p>
            </div>
            <button
              onClick={() => setViewRewardPopup(null)}
              className="w-full bg-gradient-to-r from-amber-400 to-orange-500 text-white font-bold py-2.5 rounded-2xl text-sm hover:opacity-90 active:scale-95 transition-all shadow-md"
            >
              Awesome! 🎉
            </button>
          </div>
        </div>
      )}

      {/* ── Like / Dislike Coin Popup ── */}
      {likeRewardPopup && (
        <div className="fixed inset-0 z-[200] flex items-center justify-center pointer-events-none">
          <div
            className="pointer-events-auto bg-white dark:bg-[#1c1c1e] rounded-3xl shadow-2xl px-8 py-7 flex flex-col items-center gap-4 border dark:border-white/10"
            style={{ animation: 'popupIn 0.4s cubic-bezier(0.22,1,0.36,1) forwards', minWidth: 260, borderColor: likeRewardPopup.isLike ? '#fca5a5' : '#d1d5db' }}
          >
            <div className={`w-20 h-20 rounded-full flex items-center justify-center shadow-lg ${likeRewardPopup.isLike ? 'bg-gradient-to-br from-red-400 to-pink-500 shadow-red-300/50' : 'bg-gradient-to-br from-gray-400 to-gray-500 shadow-gray-300/40'}`} style={{ animation: 'coinPulse 0.6s ease-out' }}>
              <svg width="40" height="40" viewBox="0 0 24 24" fill={likeRewardPopup.isLike ? 'white' : 'white'} stroke="none">
                {likeRewardPopup.isLike
                  ? <path d="M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z"/>
                  : <><path d="M10 15v4a3 3 0 0 0 3 3l4-9V2H5.72a2 2 0 0 0-2 1.7l-1.38 9a2 2 0 0 0 2 2.3zm7-13h2.67A2.31 2.31 0 0 1 22 4v7a2.31 2.31 0 0 1-2.33 2H17" stroke="white" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" fill="none"/></>
                }
              </svg>
            </div>
            <div className="text-center">
              <p className={`text-2xl font-black ${likeRewardPopup.isLike ? 'text-red-500' : 'text-gray-500'}`}>
                {likeRewardPopup.isLike ? `+${likeRewardPopup.amount}` : `-${likeRewardPopup.amount}`} Coins
              </p>
              <p className="text-gray-700 dark:text-gray-300 font-semibold text-sm mt-0.5">
                {likeRewardPopup.isLike ? 'Thanks for liking! 💖' : 'Dislike recorded'}
              </p>
            </div>
            <button
              onClick={() => setLikeRewardPopup(null)}
              className={`w-full text-white font-bold py-2.5 rounded-2xl text-sm hover:opacity-90 active:scale-95 transition-all shadow-md ${likeRewardPopup.isLike ? 'bg-gradient-to-r from-red-400 to-pink-500' : 'bg-gradient-to-r from-gray-400 to-gray-600'}`}
            >
              Got it!
            </button>
          </div>
        </div>
      )}

      {/* ── Coin Reward Toast ── */}
      {coinToast && (
        <div
          key={coinToast.id}
          className="fixed top-20 left-1/2 z-[100] -translate-x-1/2 flex items-center gap-2 bg-amber-500 text-white px-4 py-2.5 rounded-full shadow-2xl font-bold text-sm animate-bounce"
          style={{ animation: 'coinToastIn 0.4s cubic-bezier(0.22,1,0.36,1) forwards' }}
        >
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none">
            <circle cx="12" cy="12" r="10" fill="#FCD34D" stroke="#D97706" strokeWidth="1.5"/>
            <text x="12" y="16.5" textAnchor="middle" fontSize="11" fontWeight="bold" fill="#7C2D12">B</text>
          </svg>
          +{coinToast.amount} Coins Earned!
        </div>
      )}

      <style>{`
        @keyframes popupIn {
          0%   { opacity: 0; transform: scale(0.7); }
          60%  { transform: scale(1.04); }
          100% { opacity: 1; transform: scale(1); }
        }
        @keyframes coinPulse {
          0%   { transform: scale(0.5); opacity: 0; }
          60%  { transform: scale(1.15); }
          100% { transform: scale(1); opacity: 1; }
        }
        @keyframes slideInRight {
          from { opacity: 0; transform: translateX(16px); }
          to   { opacity: 1; transform: translateX(0); }
        }
        @keyframes coinToastIn {
          0%   { opacity: 0; transform: translateX(-50%) translateY(-12px) scale(0.85); }
          60%  { transform: translateX(-50%) translateY(4px) scale(1.05); }
          100% { opacity: 1; transform: translateX(-50%) translateY(0) scale(1); }
        }
        @keyframes slideInLeft {
          from { opacity: 0; transform: translateX(-16px); }
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