import React, { useState, useRef, useEffect, useCallback } from 'react';
import { Navigate, useNavigate, Link, useSearchParams } from 'react-router-dom';
import { useSelector, useDispatch } from 'react-redux';
import commentService from '../services/commentServiceJS';
import {
  Heart, MessageCircle, Send, MoreHorizontal,
  Volume2, VolumeX, Bookmark, ChevronLeft, Search,
  ShoppingBag, Loader2, UserPlus, UserCheck, X, Smile, Trash2
} from 'lucide-react';
import { fetchWallet, setWalletBalance } from '../store/walletSlice';
import api from '../lib/api';
import ContentReportModal from '../components/ContentReportModal';
import EditContentModal from '../components/EditContentModal';
import OwnerContentOptionsModal from '../components/OwnerContentOptionsModal';

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

const thumbnailUrl = (ad) => {
  const m = ad?.media?.[0];
  if (!m) return null;
  // Use thumbnails[0].fileUrl first, then fallback to thumbnail_url, then fileUrl for images
  if (m.thumbnails?.[0]?.fileUrl) return m.thumbnails[0].fileUrl;
  if (m.thumbnail_url) return m.thumbnail_url;
  if (m.media_type !== 'video' && m.fileUrl) return m.fileUrl;
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
      className={`shrink-0 whitespace-nowrap flex items-center gap-1 px-2.5 py-0.5 rounded-lg text-[11px] font-semibold transition-all
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
const ActionButtons = ({ ad, likedIds, toggleLike, savedIds, toggleSave, mobile = false, onComment, onMore }) => (
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
    <button onClick={() => onMore?.(ad)} className="flex flex-col items-center gap-1">
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
  const walletBalance = useSelector((state) => state.wallet.balance);
  const dispatch = useDispatch();
  const [searchParams, setSearchParams] = useSearchParams();
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

  // ── Search state ────────────────────────────────────────────────────────────
  const [searchOpen, setSearchOpen] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');
  const [searchResults, setSearchResults] = useState([]);
  const [searchLoading, setSearchLoading] = useState(false);
  const [searchDropdownVisible, setSearchDropdownVisible] = useState(false);
  const [hoveredUserId, setHoveredUserId] = useState(null);
  const [userPreviewCache, setUserPreviewCache] = useState({});
  const [userPreviewLoadingId, setUserPreviewLoadingId] = useState(null);
  const searchInputRef = React.useRef(null);
  const searchContainerRef = React.useRef(null);
  const requestedAdFetchRef = useRef('');

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
  const [likeRewardPopup, setLikeRewardPopup] = useState(null); // { amount, isLike } — shown on every like/dislike
  const [reportAd, setReportAd] = useState(null);
  const [editAd, setEditAd] = useState(null);
  const [ownerOptionsAd, setOwnerOptionsAd] = useState(null);

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
  // Track manually paused video (user tapped to pause/resume)
  const [isPausedByUser, setIsPausedByUser] = useState(false);
  const [showCtaButtons, setShowCtaButtons] = useState(false);  // shows after 50% progress

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
    setHoveredUserId(null);
  };

  const handleSearchResultClick = (item) => {
    handleSearchClose();
    if (item._type === 'user') {
      const profilePath = item.role === 'vendor' 
        ? `/vendor/${item._id || item.id}/public` 
        : `/profile/${item._id || item.id}`;
      navigate(profilePath);
      return;
    }
    if (item._type === 'ad') {
      const adId = item._id || item.id;
      if (!adId) return;
      const nextParams = new URLSearchParams(searchParams);
      nextParams.set('ad', adId);
      setSearchParams(nextParams, { replace: true });
    }
  };

  const handleUserHover = useCallback(async (user) => {
    const userId = user?._id || user?.id;
    if (!userId) return;

    setHoveredUserId(userId);
    if (userPreviewCache[userId]) return;

    try {
      setUserPreviewLoadingId(userId);
      const { data } = await api.get(`/users/${userId}`);
      const preview = data?.user || data?.data || data || {};
      setUserPreviewCache((prev) => ({ ...prev, [userId]: preview }));
    } catch (err) {
      console.error('Failed to load user preview', err);
      setUserPreviewCache((prev) => ({
        ...prev,
        [userId]: {
          _id: userId,
          username: user?.username || '',
          full_name: user?.full_name || user?.username || 'User',
          avatar_url: user?.avatar_url || '',
          bio: user?.bio || '',
        }
      }));
    } finally {
      setUserPreviewLoadingId((current) => (current === userId ? null : current));
    }
  }, [userPreviewCache]);
  const handleAdMore = (ad) => {
    const adOwnerId = ad?.user_id?._id || ad?.user_id?.id || ad?.user_id;
    if (currentUserId && adOwnerId && String(currentUserId) === String(adOwnerId)) {
      setOwnerOptionsAd(ad);
      return;
    }
    setReportAd(ad);
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
        // Fetch fresh likes/comments counts for each ad from the API
        const enriched = await Promise.all(
          list.map(async (ad) => {
            try {
              const detail = await fetch(`${BASE_URL}/api/ads/${ad._id}`, { headers: authHeaders() });
              if (detail.ok) {
                const d = await detail.json();
                const fresh = d.ad || d;
                return {
                  ...ad,
                  likes_count: fresh.likes_count ?? ad.likes_count ?? 0,
                  comments_count: fresh.comments_count ?? ad.comments_count ?? 0,
                  views_count: fresh.views_count ?? ad.views_count ?? 0,
                  is_liked_by_me: fresh.is_liked_by_me ?? ad.is_liked_by_me ?? false,
                };
              }
            } catch { /* use original */ }
            return ad;
          })
        );
        setAds(enriched);
        setCurrentIndex(0);
        setProgress(0);
        setShowCtaButtons(false);
        setLikedIds(new Set(enriched.filter(a => a.is_liked_by_me).map(a => a._id)));
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

  useEffect(() => {
    const targetAdId = searchParams.get('ad');
    if (!targetAdId) return;

    const existingIndex = ads.findIndex((ad) => String(ad._id || ad.id) === String(targetAdId));
    if (existingIndex >= 0) {
      setCurrentIndex(existingIndex);
      const nextParams = new URLSearchParams(searchParams);
      nextParams.delete('ad');
      setSearchParams(nextParams, { replace: true });
      return;
    }

    if (loading || requestedAdFetchRef.current === targetAdId) return;
    requestedAdFetchRef.current = targetAdId;

    let cancelled = false;

    const fetchTargetAd = async () => {
      try {
        const { data } = await api.get(`/ads/${targetAdId}`);
        const fetchedAd = data?.ad || data?.data || data || null;
        if (cancelled || !fetchedAd?._id) return;

        setAds((prev) => [fetchedAd, ...prev.filter((ad) => String(ad._id || ad.id) !== String(fetchedAd._id))]);
        setCurrentIndex(0);

        const nextParams = new URLSearchParams(searchParams);
        nextParams.delete('ad');
        setSearchParams(nextParams, { replace: true });
      } catch (err) {
        console.error('Failed to load searched ad', err);
      } finally {
        if (requestedAdFetchRef.current === targetAdId) {
          requestedAdFetchRef.current = '';
        }
      }
    };

    fetchTargetAd();

    return () => {
      cancelled = true;
    };
  }, [ads, loading, searchParams, setSearchParams]);

  // Fetch wallet on mount and every 30s using Redux — keeps balance live across the app
  useEffect(() => {
    dispatch(fetchWallet());
    const interval = setInterval(() => dispatch(fetchWallet()), 30000);
    return () => clearInterval(interval);
  }, [dispatch]);

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
      // Fix: send user.id as string — backend expects { "user": { "id": "..." } }
      const body = { user: { id: currentUserId ? String(currentUserId) : undefined } };
      const res = await fetch(`${BASE_URL}/api/ads/${adId}/view`, {
        method: 'POST',
        headers: authHeaders(),
        body: JSON.stringify(body),
      });
      // Accept 200/201 as success; treat 4xx/5xx as failure but don't crash
      let resData = {};
      try { resData = await res.json(); } catch { /* non-JSON body */ }

      if (!res.ok) {
        // Remove from viewed so it can retry once on next visit
        viewedIdsRef.current.delete(key);
        console.warn(`View API returned ${res.status}:`, resData);
        // Still refresh wallet — some backends credit coins but return non-2xx
        dispatch(fetchWallet());
        setTimeout(() => dispatch(fetchWallet()), 1500);
        return;
      }

      // Parse response — backend may return updated wallet/coins directly
      const directBal =
        resData?.wallet?.balance ??
        resData?.user?.wallet?.balance ??
        resData?.balance ??
        resData?.data?.balance ??
        resData?.coins;
      const coinsRewarded =
        resData?.coins_rewarded ??
        resData?.coins ??
        resData?.reward ??
        resData?.data?.coins_rewarded;

      if (directBal !== undefined && directBal !== null) {
        dispatch(setWalletBalance(directBal));
      } else {
        // Immediately + retry to ensure the credit shows up
        dispatch(fetchWallet());
        setTimeout(() => dispatch(fetchWallet()), 1000);
        setTimeout(() => dispatch(fetchWallet()), 3000);
      }

      // Show only the top coin toast when rewarded is explicitly true.
      const isRewarded = resData?.rewarded === true;
      if (isRewarded) {
        const rewardAmount = (coinsRewarded && Number(coinsRewarded) > 0)
          ? Number(coinsRewarded)
          : (() => {
              const adCoins = adsRef.current.find(a => String(a._id) === String(adId))?.coins_reward;
              return adCoins && Number(adCoins) > 0 ? Number(adCoins) : 10;
            })();
        const toastId = Date.now();
        setCoinToast({ amount: rewardAmount, id: toastId });
        setTimeout(() => setCoinToast(t => t?.id === toastId ? null : t), 3000);
      }
    } catch (err) {
      console.error('View tracking failed:', err);
    }
  }, [currentUserId, dispatch]);

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

  // ── Imperatively play/pause videos when currentIndex or ads list changes ──────
  // autoPlay={isCurrent} only fires on initial mount and is blocked by browsers for
  // unmuted video. We must call .play() imperatively every time the current ad changes,
  // including the very first load when ads arrive from the API (currentIndex stays 0).
  useEffect(() => {
    if (ads.length === 0) return;
    const currentAd = ads[currentIndex];
    if (!currentAd) return;
    const isVideo = currentAd.media?.[0]?.media_type === 'video';

    // Pause all other videos immediately
    Object.entries(videoRefs.current).forEach(([idx, vid]) => {
      if (vid && Number(idx) !== currentIndex && !vid.paused) vid.pause();
    });

    if (!isVideo) return;

    // Don't auto-play if user explicitly paused
    if (isPausedByUser) return;

    // Small delay to ensure the <video> element is in the DOM after React render
    const timer = setTimeout(() => {
      const vid = videoRefs.current[currentIndex];
      if (!vid) return;
      const m = currentAd.media?.[0];
      const start = m?.timing_window?.start ?? m?.video_meta?.selected_start ?? 0;
      vid.currentTime = start > 0 ? start : 0;
      const playPromise = vid.play();
      if (playPromise !== undefined) {
        playPromise.catch(() => {
          // Browser blocked autoplay — user must interact first; silently ignore
        });
      }
    }, 100);

    return () => clearTimeout(timer);
  }, [currentIndex, ads, isPausedByUser]);

  // ── Navigation ───────────────────────────────────────────────────────────────
  const goToIndex = useCallback((index) => {
    if (isAnimatingRef.current) return;
    const next = Math.min(ads.length - 1, Math.max(0, index));
    if (next === currentIndex) return;
    isAnimatingRef.current = true;
    const curVid = videoRefs.current[currentIndex];
    if (curVid) curVid.pause();
    setIsPausedByUser(false); // reset pause state when navigating
    setShowCtaButtons(false); // reset CTA on navigation
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

  // ── Tap to pause / resume video ──────────────────────────────────────────────
  const handleVideoTap = useCallback((index) => {
    const vid = videoRefs.current[index];
    if (!vid) return;
    if (vid.paused) {
      vid.play().catch(() => {});
      setIsPausedByUser(false);
    } else {
      vid.pause();
      setIsPausedByUser(true);
    }
  }, []);
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
        body: JSON.stringify({ user: { id: currentUserId ? String(currentUserId) : undefined } }),
      });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);

      // Parse response for direct wallet update
      let resData = {};
      try { resData = await res.json(); } catch { /* non-JSON */ }

      const directBal =
        resData?.wallet?.balance ??
        resData?.user?.wallet?.balance ??
        resData?.balance ??
        resData?.data?.balance ??
        resData?.coins;

      if (directBal !== undefined && directBal !== null) {
        // Backend returned balance directly — use it
        dispatch(setWalletBalance(directBal));
      } else {
        // Poll wallet: immediately, then at 1s and 3s intervals to catch delayed credits
        dispatch(fetchWallet());
        setTimeout(() => dispatch(fetchWallet()), 1000);
        setTimeout(() => dispatch(fetchWallet()), 3000);
      }

      // Show like/dislike coin reward popup
      const coinsRewarded = resData?.coins_rewarded ?? resData?.reward ?? resData?.coins ?? 10;
      setLikeRewardPopup({ amount: Number(coinsRewarded) || 10, isLike: !isLiked });

    } catch (err) {
      console.error('Like failed:', err);
      // Rollback optimistic update
      setLikedIds(prev => { const s = new Set(prev); isLiked ? s.add(adId) : s.delete(adId); return s; });
      setAds(prev => prev.map(a => a._id === adId
        ? { ...a, likes_count: a.likes_count + (isLiked ? 1 : -1), is_liked_by_me: isLiked }
        : a));
    }
  }, [likedIds, currentUserId, dispatch]);

  // ── Dislike ───────────────────────────────────────────────────────────────────

  const toggleSave = useCallback((adId) => {
    setSavedIds(prev => { const s = new Set(prev); s.has(adId) ? s.delete(adId) : s.add(adId); return s; });
  }, []);

  // ── Ad Click Tracking ─────────────────────────────────────────────────────────
  // Fires POST /api/ads/{id}/click when user clicks the vendor name/profile.
  const trackAdClick = useCallback(async (adId) => {
    if (!adId) return;
    try {
      await fetch(`${BASE_URL}/api/ads/${adId}/click`, {
        method: 'POST',
        headers: authHeaders(),
      });
    } catch (err) {
      console.warn('Ad click tracking failed:', err);
    }
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
    <div className={`flex flex-col dark:bg-black overflow-hidden ${pageHeightClass}`}>

      {/* Desktop top bar */}
      <div className="hidden md:flex items-center gap-2 px-4 py-2 border-b border-gray-200 dark:border-gray-800 shrink-0 relative overflow-visible">
        {/* Back button — hidden when search open */}
        <button
          onClick={() => navigate(-1)}
          className={`p-1.5 hover:bg-gray-100 dark:hover:bg-gray-800 rounded-lg text-gray-500 mr-1 shrink-0 transition-all duration-300 ${searchOpen ? 'opacity-0 w-0 overflow-hidden mr-0 p-0' : 'opacity-100'}`}
        >
          <ChevronLeft size={16} />
        </button>

        {/* Category pills — shrink/hide when search open */}
        <div className={`flex items-center gap-1 overflow-x-auto scrollbar-none transition-all duration-300 ${searchOpen ? 'w-0 opacity-0 overflow-hidden flex-none' : 'flex-1 opacity-100'}`}>
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

        {/* Search — expands to full width */}
        <div ref={searchContainerRef} className={`transition-all duration-300 ease-in-out shrink-0 ${searchOpen ? 'flex-1' : ''}`}>
          {searchOpen ? (
            <div className="flex items-center gap-2 bg-gray-100 dark:bg-gray-800 rounded-full px-4 py-2 w-full">
              <Search size={15} className="text-gray-400 shrink-0" />
              <input
                ref={searchInputRef}
                value={searchQuery}
                onChange={handleSearchInput}
                placeholder="Search ads, users…"
                className="flex-1 bg-transparent text-sm outline-none text-gray-900 dark:text-white placeholder-gray-400"
              />
              {searchLoading
                ? <Loader2 size={14} className="animate-spin text-gray-400 shrink-0" />
                : searchQuery
                  ? <button onClick={() => { setSearchQuery(''); setSearchResults([]); setSearchDropdownVisible(false); searchInputRef.current?.focus(); }}>
                      <X size={14} className="text-gray-400 hover:text-gray-700 dark:hover:text-white" />
                    </button>
                  : null
              }
              <button onClick={handleSearchClose} className="text-xs font-semibold text-gray-500 dark:text-gray-400 hover:text-gray-800 dark:hover:text-white ml-1 shrink-0">
                Cancel
              </button>
            </div>
          ) : (
            <button onClick={handleSearchOpen} className="p-1.5 hover:bg-gray-100 dark:hover:bg-gray-800 rounded-lg text-gray-500 transition-colors">
              <Search size={18} />
            </button>
          )}

          {/* Desktop Search Dropdown */}
          {searchOpen && searchDropdownVisible && (
            <div className="absolute left-0 right-0 top-full mt-1 mx-4 bg-white dark:bg-[#1c1c1e] rounded-2xl shadow-2xl border border-gray-100 dark:border-gray-800 z-50 max-h-96 overflow-y-auto">
              {searchLoading && (
                <div className="flex items-center justify-center py-8 gap-2 text-gray-400">
                  <Loader2 size={16} className="animate-spin" />
                  <span className="text-sm">Searching…</span>
                </div>
              )}
              {!searchLoading && searchResults.length === 0 && searchQuery.trim() && (
                <div className="flex flex-col items-center justify-center py-8 text-gray-400 gap-2">
                  <Search size={20} className="opacity-40" />
                  <span className="text-sm">No results for "{searchQuery}"</span>
                </div>
              )}
              {!searchLoading && searchResults.length > 0 && (
                <>
                  {/* Users */}
                  {searchResults.filter(r => r._type === 'user').length > 0 && (
                    <div>
                      <div className="px-4 py-2 text-[10px] font-bold uppercase tracking-wider text-gray-400 border-b border-gray-50 dark:border-gray-800">People</div>
                      {searchResults.filter(r => r._type === 'user').map(u => {
                        const previewUserId = u._id || u.id;
                        const preview = userPreviewCache[previewUserId];
                        const isPreviewOpen = hoveredUserId === previewUserId;
                        return (
                        <button
                          key={previewUserId}
                          onClick={() => handleSearchResultClick(u)}
                          onMouseEnter={() => handleUserHover(u)}
                          onMouseLeave={() => setHoveredUserId((current) => (current === previewUserId ? null : current))}
                          className="relative w-full flex items-center gap-3 px-4 py-2.5 hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors text-left"
                        >
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
                          {isPreviewOpen && (
                            <div className="absolute left-full top-1/2 ml-4 -translate-y-1/2 w-72 rounded-2xl border border-gray-200 dark:border-gray-700 bg-white/95 dark:bg-[#111317]/95 backdrop-blur-xl shadow-2xl p-4 z-20">
                              <div className="flex items-center gap-3">
                                <Avatar
                                  src={preview?.avatar_url || u.avatar_url}
                                  username={preview?.username || preview?.full_name || u.username || u.full_name}
                                  size="md"
                                />
                                <div className="min-w-0">
                                  <div className="text-sm font-bold text-gray-900 dark:text-white truncate">
                                    {preview?.full_name || u.full_name || u.username}
                                  </div>
                                  <div className="text-xs text-gray-500 dark:text-gray-400 truncate">
                                    @{preview?.username || u.username || 'user'}
                                  </div>
                                </div>
                              </div>
                              <p className="mt-3 text-xs leading-5 text-gray-600 dark:text-gray-300 min-h-[40px]">
                                {userPreviewLoadingId === previewUserId
                                  ? 'Loading preview...'
                                  : preview?.bio || 'No bio added yet.'}
                              </p>
                              <div className="mt-3 flex items-center gap-4 text-xs">
                                <div>
                                  <span className="font-bold text-gray-900 dark:text-white">{fmt(preview?.posts_count || preview?.postsCount || 0)}</span>
                                  <span className="ml-1 text-gray-500 dark:text-gray-400">posts</span>
                                </div>
                                <div>
                                  <span className="font-bold text-gray-900 dark:text-white">{fmt(preview?.followers_count || preview?.followersCount || 0)}</span>
                                  <span className="ml-1 text-gray-500 dark:text-gray-400">followers</span>
                                </div>
                                <div>
                                  <span className="font-bold text-gray-900 dark:text-white">{fmt(preview?.following_count || preview?.followingCount || 0)}</span>
                                  <span className="ml-1 text-gray-500 dark:text-gray-400">following</span>
                                </div>
                              </div>
                            </div>
                          )}
                        </button>
                      )})}
                    </div>
                  )}
                  {/* Ads */}
                  {searchResults.filter(r => r._type === 'ad').length > 0 && (
                    <div>
                      <div className="px-4 py-2 text-[10px] font-bold uppercase tracking-wider text-gray-400 border-b border-gray-50 dark:border-gray-800">Ads</div>
                      {searchResults.filter(r => r._type === 'ad').map(adItem => {
                        const adUser = adItem.user_id || adItem.vendor_id || {};
                        const mediaItem = adItem.media?.[0];
                        const isVideoAd = mediaItem?.media_type === 'video';
                        const thumb = mediaItem?.thumbnails?.[0]?.fileUrl || mediaItem?.thumbnail_url || (!isVideoAd ? mediaItem?.fileUrl : null);
                        const videoSrc = isVideoAd ? mediaItem?.fileUrl : null;
                        return (
                          <button
                            key={adItem._id || adItem.id}
                            onClick={() => handleSearchResultClick(adItem)}
                            className="w-full flex items-center gap-3 px-4 py-2.5 hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors text-left group/adrow"
                          >
                            <div className="w-10 h-10 rounded-xl overflow-hidden bg-gray-200 dark:bg-gray-700 shrink-0 relative">
                              {isVideoAd && videoSrc ? (
                                <video
                                  src={videoSrc}
                                  poster={thumb || undefined}
                                  className="w-full h-full object-cover"
                                  muted
                                  playsInline
                                  preload="metadata"
                                  onMouseEnter={e => {
                                    e.currentTarget.currentTime = 0;
                                    e.currentTarget.play().catch(() => {});
                                  }}
                                  onMouseLeave={e => {
                                    e.currentTarget.pause();
                                    e.currentTarget.currentTime = 0;
                                  }}
                                  onTimeUpdate={e => {
                                    if (e.currentTarget.currentTime >= 5) {
                                      e.currentTarget.pause();
                                      e.currentTarget.currentTime = 0;
                                    }
                                  }}
                                />
                              ) : thumb ? (
                                <img src={thumb} alt="" className="w-full h-full object-cover" />
                              ) : (
                                <div className="w-full h-full flex items-center justify-center text-gray-400"><ShoppingBag size={14} /></div>
                              )}
                            </div>
                            <div className="min-w-0 flex-1">
                              <div className="text-sm font-semibold text-gray-900 dark:text-white truncate">{adItem.caption || adItem.title || 'Ad'}</div>
                              <div className="flex items-center gap-1.5 mt-0.5">
                                {adItem.category && <span className="text-[10px] px-1.5 py-0.5 rounded-full bg-gray-100 dark:bg-gray-700 text-gray-500 dark:text-gray-400 font-medium">{adItem.category}</span>}
                                {typeof adUser === 'object' && adUser.username && <span className="text-[10px] text-gray-400">@{adUser.username}</span>}
                              </div>
                            </div>
                          </button>
                        );
                      })}
                    </div>
                  )}
                </>
              )}
            </div>
          )}
        </div>
      </div>
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
            {/* Mobile Topbar right: Search + Wallet compact */}
            <div className="shrink-0 flex items-center gap-2">
              {/* Search button */}
              <button
                onClick={handleSearchOpen}
                className="w-8 h-8 flex items-center justify-center rounded-full bg-black/40 backdrop-blur-md border border-white/20 active:scale-90 transition-transform"
              >
                <Search size={16} className="text-white" />
              </button>
              {/* Compact wallet pill */}
              <Link to="/wallet" className="flex items-center gap-1 bg-black/40 backdrop-blur-md border border-white/20 rounded-full px-2 py-1">
                <div className="w-4 h-4 rounded-full bg-gradient-to-tr from-yellow-400 via-orange-500 to-pink-500 flex items-center justify-center shrink-0">
                  <svg xmlns="http://www.w3.org/2000/svg" width="9" height="9" viewBox="0 0 24 24" fill="none" stroke="white" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
                    <path d="M21 12V7H5a2 2 0 0 1 0-4h14v4"/><path d="M3 5v14a2 2 0 0 0 2 2h16v-5"/><path d="M18 12a2 2 0 0 0 0 4h4v-4Z"/>
                  </svg>
                </div>
                <span className="text-[11px] font-bold text-white">{walletBalance}</span>
              </Link>
            </div>
          </div>

          {/* Mobile Search overlay — slides in from top when open */}
          {searchOpen && (
            <div className="md:hidden absolute top-0 left-0 right-0 z-50 bg-black/80 backdrop-blur-md px-3 pt-3 pb-3">
              <div className="flex items-center gap-2 bg-white/15 rounded-full px-3 py-2">
                <Search size={15} className="text-white/70 shrink-0" />
                <input
                  ref={searchInputRef}
                  value={searchQuery}
                  onChange={handleSearchInput}
                  placeholder="Search ads, users…"
                  className="flex-1 bg-transparent text-sm outline-none text-white placeholder-white/50"
                  autoFocus
                />
                {searchLoading
                  ? <Loader2 size={14} className="animate-spin text-white/60 shrink-0" />
                  : searchQuery
                    ? <button onClick={() => { setSearchQuery(''); setSearchResults([]); setSearchDropdownVisible(false); }}><X size={14} className="text-white/60" /></button>
                    : null
                }
                <button onClick={handleSearchClose} className="text-xs font-semibold text-white/70 ml-1 shrink-0">Cancel</button>
              </div>
              {/* Mobile search results */}
              {searchDropdownVisible && (
                <div className="mt-2 bg-black/90 rounded-2xl border border-white/10 overflow-hidden max-h-64 overflow-y-auto">
                  {searchLoading && (
                    <div className="flex items-center justify-center py-6 gap-2 text-white/50">
                      <Loader2 size={14} className="animate-spin" />
                      <span className="text-xs">Searching…</span>
                    </div>
                  )}
                  {!searchLoading && searchResults.length === 0 && searchQuery.trim() && (
                    <div className="flex flex-col items-center py-6 gap-1 text-white/40">
                      <Search size={18} className="opacity-40" />
                      <span className="text-xs">No results for "{searchQuery}"</span>
                    </div>
                  )}
                  {!searchLoading && searchResults.map(item => {
                    if (item._type === 'user') return (
                      <button key={item._id || item.id} onClick={() => handleSearchResultClick(item)}
                        className="w-full flex items-center gap-3 px-4 py-2.5 hover:bg-white/10 transition-colors text-left">
                        <div className="w-8 h-8 rounded-full overflow-hidden bg-gradient-to-tr from-yellow-400 via-orange-500 to-pink-500 p-[1.5px] shrink-0">
                          <div className="w-full h-full rounded-full bg-black overflow-hidden flex items-center justify-center">
                            {item.avatar_url
                              ? <img src={item.avatar_url} alt="" className="w-full h-full object-cover" />
                              : <span className="text-[10px] font-bold text-white">{(item.username || '?')[0].toUpperCase()}</span>
                            }
                          </div>
                        </div>
                        <div className="min-w-0">
                          <div className="text-sm font-semibold text-white truncate">{item.full_name || item.username}</div>
                          {item.username && <div className="text-xs text-white/50">@{item.username}</div>}
                        </div>
                      </button>
                    );
                    const mobileMediaItem = item.media?.[0];
                    const isMobileVideoAd = mobileMediaItem?.media_type === 'video';
                    const mobileThumb = mobileMediaItem?.thumbnails?.[0]?.fileUrl || mobileMediaItem?.thumbnail_url || (!isMobileVideoAd ? mobileMediaItem?.fileUrl : null);
                    const mobileVideoSrc = isMobileVideoAd ? mobileMediaItem?.fileUrl : null;
                    return (
                      <button key={item._id} onClick={() => handleSearchResultClick(item)}
                        className="w-full flex items-center gap-3 px-4 py-2.5 hover:bg-white/10 transition-colors text-left group/mobadrow">
                        <div className="w-9 h-9 rounded-xl overflow-hidden bg-white/10 shrink-0 relative">
                          {isMobileVideoAd && mobileVideoSrc ? (
                            <>
                              {mobileThumb && <img src={mobileThumb} alt="" className="w-full h-full object-cover absolute inset-0 group-hover/mobadrow:opacity-0 transition-opacity duration-200" />}
                              <video
                                src={mobileVideoSrc}
                                className="w-full h-full object-cover opacity-0 group-hover/mobadrow:opacity-100 transition-opacity duration-200"
                                muted playsInline preload="none"
                                onMouseEnter={e => { e.currentTarget.currentTime = 0; e.currentTarget.play().catch(() => {}); }}
                                onMouseLeave={e => { e.currentTarget.pause(); e.currentTarget.currentTime = 0; }}
                                onTimeUpdate={e => { if (e.currentTarget.currentTime >= 5) { e.currentTarget.pause(); e.currentTarget.currentTime = 0; } }}
                              />
                              {!mobileThumb && <div className="w-full h-full flex items-center justify-center text-white/40 absolute inset-0 group-hover/mobadrow:opacity-0"><ShoppingBag size={12}/></div>}
                            </>
                          ) : mobileThumb ? (
                            <img src={mobileThumb} alt="" className="w-full h-full object-cover" />
                          ) : (
                            <div className="w-full h-full flex items-center justify-center text-white/40"><ShoppingBag size={12}/></div>
                          )}
                        </div>
                        <div className="min-w-0 flex-1">
                          <div className="text-sm font-semibold text-white truncate">{item.caption || item.title || 'Ad'}</div>
                          {item.category && <span className="text-[10px] text-white/50">{item.category}</span>}
                        </div>
                      </button>
                    );
                  })}
                </div>
              )}
            </div>
          )}


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
                        <div className="w-full h-full relative" onClick={() => isCurrent && handleVideoTap(index)}>
                          <video
                            ref={el => { videoRefs.current[index] = el; }}
                            src={src}
                            className="w-full h-full object-cover"
                            muted={isMuted}
                            playsInline
                            autoPlay={isCurrent}
                            loop={false}
                            onLoadedMetadata={e => {
                              const m = a.media?.[0];
                              const start = m?.timing_window?.start ?? m?.video_meta?.selected_start ?? 0;
                              if (start > 0) e.target.currentTime = start;
                              // Fallback: if this is the current video and it's not playing yet, play it
                              if (isCurrent && e.target.paused && !isPausedByUser) {
                                e.target.play().catch(() => {});
                              }
                            }}
                            onTimeUpdate={e => {
                              if (!isCurrent) return;
                              const vid = e.target;
                              const m = a.media?.[0];
                              const start   = m?.timing_window?.start    ?? m?.video_meta?.selected_start  ?? 0;
                              const end     = m?.timing_window?.end      ?? m?.video_meta?.selected_end    ?? null;
                              const dur     = m?.video_meta?.final_duration ?? null;
                              const ct      = vid.currentTime;

                              // Hit the trim end → mark 100%, record the first complete view, then replay
                              if (end !== null && ct >= end) {
                                setProgress(100);
                                trackView(a._id);
                                // Replay from start
                                vid.currentTime = start > 0 ? start : 0;
                                setProgress(0);
                                setIsPausedByUser(false);
                                vid.play().catch(() => {});
                                return;
                              }

                              // Move progress bar + trigger CTA after 50%
                              let pct = 0;
                              if (dur && dur > 0) {
                                pct = Math.min(((ct - start) / dur) * 100, 100);
                              } else if (vid.duration > 0) {
                                pct = (ct / vid.duration) * 100;
                              }
                              setProgress(pct);
                              if (pct >= 50) setShowCtaButtons(true);
                            }}
                            onEnded={() => {
                              if (!isCurrent) return;
                              setProgress(100);
                              setIsPausedByUser(false);

                              // Record only the first complete watch for this ad in the current session.
                              trackView(a._id);

                              // Replay the video from the beginning
                              const vid = videoRefs.current[index];
                              if (vid) {
                                const m = a.media?.[0];
                                const start = m?.timing_window?.start ?? m?.video_meta?.selected_start ?? 0;
                                vid.currentTime = start > 0 ? start : 0;
                                setProgress(0);
                                vid.play().catch(() => {});
                              }
                            }}
                          />
                          {/* Pause/Play overlay — shows briefly on tap */}
                          {isCurrent && isPausedByUser && (
                            <div className="absolute inset-0 flex items-center justify-center pointer-events-none">
                              <div className="w-16 h-16 rounded-full bg-black/50 backdrop-blur-sm flex items-center justify-center">
                                <svg width="28" height="28" viewBox="0 0 24 24" fill="white">
                                  <path d="M8 5v14l11-7z"/>
                                </svg>
                              </div>
                            </div>
                          )}
                        </div>
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

                      {/* Bottom info — flex column, Vendor info + Caption above, CTA buttons below */}
                      <div className="absolute bottom-0 left-0 w-full z-20 flex flex-col justify-end" style={{ paddingRight: '60px' }}>

                        {/* Vendor + caption + tags */}
                        <div className="px-4 pt-4 pb-2">
                          {/* Vendor row */}
                          <div className="flex items-center gap-2 mb-2 flex-nowrap min-w-0">
                            <button
                              onClick={() => { trackAdClick(a._id); const uid = a.user_id?._id || a.user_id?.id || a.vendor_id?._id; if (uid) navigate(`/vendor/${uid}/public`); }}
                              className="flex items-center gap-2 active:opacity-70 transition-opacity min-w-0 flex-1"
                            >
                              {a.user_id?.avatar_url
                                ? <img src={a.user_id.avatar_url} className="w-8 h-8 rounded-full border border-white/30 object-cover shrink-0" alt="user" />
                                : <div className="w-8 h-8 rounded-full border border-white/30 bg-gradient-to-br from-purple-500 to-pink-500 flex items-center justify-center text-white text-xs font-bold shrink-0">{(a.vendor_id?.business_name || 'A')[0]}</div>
                              }
                              <span className="font-bold text-white text-sm hover:underline decoration-white/60 underline-offset-2 truncate">
                                {a.vendor_id?.business_name || a.user_id?.username}
                              </span>
                            </button>
                            {a.total_budget_coins > 0 && (
                              <div className="shrink-0 flex items-center gap-1 bg-amber-500/20 border border-amber-400/40 rounded-full px-1.5 py-0.5">
                                <CoinIcon size={11} /><span className="text-amber-300 text-[10px] font-bold">{fmt(a.total_budget_coins)}</span>
                              </div>
                            )}
                            <FollowButton userId={a.user_id?._id} mobile />
                          </div>

                          <Caption text={a.caption} />

                          <div className="flex items-center gap-2 flex-wrap mb-2">
                            {a.category && <span className="text-white/70 text-[10px] bg-white/10 px-2 py-0.5 rounded-full">{a.category}</span>}
                            {a.hashtags?.slice(0, 3).map(h => <span key={h} className="text-white/50 text-[10px]">#{h}</span>)}
                          </div>

                          {a.product_offer?.length > 0 && <ProductOffer offer={a.product_offer[0]} />}

                          <div className="flex flex-wrap gap-1.5 mt-2">
                            {a.target_language?.slice(0, 3).map(lang => (
                              <span key={lang} className="flex items-center gap-1 text-[10px] font-medium text-white/80 bg-white/10 backdrop-blur-sm border border-white/15 px-2 py-0.5 rounded-full">
                                <svg width="9" height="9" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round" className="opacity-70"><circle cx="12" cy="12" r="10"/><line x1="2" y1="12" x2="22" y2="12"/><path d="M12 2a15.3 15.3 0 0 1 4 10 15.3 15.3 0 0 1-4 10 15.3 15.3 0 0 1-4-10 15.3 15.3 0 0 1 4-10z"/></svg>
                                {lang}
                              </span>
                            ))}
                            {a.target_language?.length > 3 && <span className="text-[10px] font-medium text-white/60 bg-white/10 px-2 py-0.5 rounded-full">+{a.target_language.length - 3}</span>}
                            {a.target_location?.slice(0, 2).map(loc => (
                              <span key={loc} className="flex items-center gap-1 text-[10px] font-medium text-white/80 bg-white/10 backdrop-blur-sm border border-white/15 px-2 py-0.5 rounded-full">
                                <svg width="9" height="9" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round" className="opacity-70"><path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"/><circle cx="12" cy="10" r="3"/></svg>
                                {loc}
                              </span>
                            ))}
                            {a.target_location?.length > 2 && <span className="text-[10px] font-medium text-white/60 bg-white/10 px-2 py-0.5 rounded-full">+{a.target_location.length - 2} more</span>}
                          </div>
                        </div>

                        {/* CTA Buttons — slide up from bottom, below caption */}
                        <div
                          className="overflow-hidden transition-all duration-500 ease-out"
                          style={{ maxHeight: isCurrent && showCtaButtons ? '100px' : '0px', opacity: isCurrent && showCtaButtons ? 1 : 0 }}
                        >
                          <div className="flex gap-2 px-4 pb-6 pt-2">
                            {/* View Ad Details */}
                            <button
                              onClick={() => { trackAdClick(a._id); navigate(`/ads/${a._id}/details`); }}
                              className="flex-1 flex items-center justify-center gap-1.5 py-2.5 px-3 rounded-2xl bg-black/40 backdrop-blur-md border border-white/25 text-white text-xs font-bold hover:bg-black/60 active:scale-95 transition-all shadow-lg"
                            >
                              <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round"><rect x="2" y="3" width="20" height="14" rx="2"/><line x1="8" y1="21" x2="16" y2="21"/><line x1="12" y1="17" x2="12" y2="21"/></svg>
                              Visit Ad Details
                            </button>
                            {/* CTA based on type */}
                            {a.cta?.type && (() => {
                              const cta = a.cta;
                              const label = cta.type === 'view_site' ? 'Visit Website' : cta.type === 'call_now' ? 'Call Now' : cta.type === 'install_app' ? 'Install App' : cta.type === 'book_now' ? 'Book Now' : cta.type === 'contact_info' ? 'Contact Us' : 'Learn More';
                              const icon = cta.type === 'call_now'
                                ? <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round"><path d="M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07A19.5 19.5 0 0 1 4.69 13a19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 3.6 2h3a2 2 0 0 1 2 1.72 12.84 12.84 0 0 0 .7 2.81 2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45 12.84 12.84 0 0 0 2.81.7A2 2 0 0 1 22 16.92z"/></svg>
                                : <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round"><path d="M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6"/><polyline points="15 3 21 3 21 9"/><line x1="10" y1="14" x2="21" y2="3"/></svg>;
                              const href = cta.type === 'call_now' && cta.phone_number ? `tel:${cta.phone_number}` : cta.url?.trim() || cta.deep_link?.trim() || null;
                              if (!href) return null;
                              return (
                                <a href={href} target={cta.type !== 'call_now' ? '_blank' : '_self'} rel="noopener noreferrer"
                                  onClick={() => trackAdClick(a._id)}
                                  className="flex-1 flex items-center justify-center gap-1.5 py-2.5 px-3 rounded-2xl bg-gradient-to-r from-orange-500 to-pink-600 text-white text-xs font-bold hover:opacity-90 active:scale-95 transition-all shadow-lg">
                                  {icon}{label}
                                </a>
                              );
                            })()}
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
                            onMore={handleAdMore}
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
                onMore={handleAdMore}
              />
            </div>
          )}
        </div>
      </div>

      {/* Nav arrows — visible in both light and dark mode */}
      <div className="hidden md:flex fixed right-5 top-1/2 -translate-y-1/2 z-40 flex-col gap-3">
        <button
          onClick={() => goToIndex(currentIndex - 1)}
          disabled={currentIndex === 0}
          className="w-12 h-12 rounded-full bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 shadow-xl flex items-center justify-center hover:bg-gray-50 dark:hover:bg-gray-700 hover:scale-110 active:scale-95 transition-all disabled:opacity-30 disabled:cursor-not-allowed"
        >
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round"
            className="stroke-gray-800 dark:stroke-white">
            <polyline points="18 15 12 9 6 15" />
          </svg>
        </button>
        <button
          onClick={() => goToIndex(currentIndex + 1)}
          disabled={currentIndex === ads.length - 1}
          className="w-12 h-12 rounded-full bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 shadow-xl flex items-center justify-center hover:bg-gray-50 dark:hover:bg-gray-700 hover:scale-110 active:scale-95 transition-all disabled:opacity-30 disabled:cursor-not-allowed"
        >
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round"
            className="stroke-gray-800 dark:stroke-white">
            <polyline points="6 9 12 15 18 9" />
          </svg>
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
      {false && (
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

      {/* ── View Recorded Popup (rewarded: false) ── */}
      {false && (
        <div className="fixed inset-0 z-[200] flex items-center justify-center pointer-events-none">
          <div
            className="pointer-events-auto bg-white dark:bg-[#1c1c1e] rounded-3xl shadow-2xl px-8 py-7 flex flex-col items-center gap-4 border border-gray-200 dark:border-white/10"
            style={{ animation: 'popupIn 0.4s cubic-bezier(0.22,1,0.36,1) forwards', minWidth: 260 }}
          >
            {/* Eye / view icon */}
            <div className="relative">
              <div className="w-20 h-20 rounded-full bg-gradient-to-br from-gray-400 via-gray-500 to-gray-600 flex items-center justify-center shadow-lg shadow-gray-400/30" style={{ animation: 'coinPulse 0.6s ease-out' }}>
                <svg width="36" height="36" viewBox="0 0 24 24" fill="none" stroke="white" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                  <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/>
                  <circle cx="12" cy="12" r="3"/>
                </svg>
              </div>
              <div className="absolute -top-1 -right-1 w-6 h-6 bg-blue-500 rounded-full flex items-center justify-center shadow-md">
                <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="white" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round"><polyline points="20 6 9 17 4 12"/></svg>
              </div>
            </div>
            <div className="text-center">
              <p className="text-xl font-black text-gray-700 dark:text-gray-200">View Recorded</p>
              {viewRecordedPopup.view_count !== null && (
                <p className="text-gray-500 dark:text-gray-400 text-sm mt-1">
                  Total views: <span className="font-bold text-gray-700 dark:text-gray-200">{viewRecordedPopup.view_count}</span>
                </p>
              )}
              <p className="text-gray-500 dark:text-gray-400 text-xs mt-1.5">No coins rewarded for this view</p>
            </div>
            <button
              onClick={() => setViewRecordedPopup(null)}
              className="w-full bg-gradient-to-r from-gray-500 to-gray-700 text-white font-bold py-2.5 rounded-2xl text-sm hover:opacity-90 active:scale-95 transition-all shadow-md"
            >
              OK
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

      <ContentReportModal
        isOpen={!!reportAd}
        onClose={() => setReportAd(null)}
        contentType="ad"
        contentId={reportAd?._id}
        ownerUsername={reportAd?.vendor_id?.business_name || reportAd?.user_id?.username || ''}
        contentUrl={`${window.location.origin}/ads`}
      />
      <OwnerContentOptionsModal
        isOpen={!!ownerOptionsAd}
        onClose={() => setOwnerOptionsAd(null)}
        item={ownerOptionsAd}
        contentType="ad"
        contentUrl={`${window.location.origin}/ads`}
        onEdit={() => {
          setEditAd(ownerOptionsAd);
          setOwnerOptionsAd(null);
        }}
        onDelete={() => {
          const adToDelete = ownerOptionsAd;
          setOwnerOptionsAd(null);
          if (!adToDelete) return;
          if (!window.confirm('Delete this ad?')) return;
          api.delete(`/ads/${adToDelete._id}`)
            .then(() => {
              setAds((prev) => prev.filter((ad) => ad._id !== adToDelete._id));
            })
            .catch((err) => {
              alert(err?.response?.data?.message || 'Failed to delete ad.');
            });
        }}
        onUpdated={(updated) => {
          const updatedId = updated?._id;
          setAds((prev) => prev.map((ad) => (ad._id === updatedId ? { ...ad, ...updated } : ad)));
        }}
      />
      <EditContentModal
        isOpen={!!editAd}
        onClose={() => setEditAd(null)}
        item={editAd}
        contentType="ad"
        onSaved={(updated) => {
          const updatedId = updated?._id;
          setAds((prev) => prev.map((ad) => (ad._id === updatedId ? { ...ad, ...updated } : ad)));
        }}
      />

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

        @keyframes ctaSlideUp {
          0%   { opacity: 0; transform: translateY(24px) scale(0.95); }
          60%  { transform: translateY(-4px) scale(1.02); }
          100% { opacity: 1; transform: translateY(0) scale(1); }
        }
        .animate-cta-slide-up {
          animation: ctaSlideUp 0.45s cubic-bezier(0.34, 1.56, 0.64, 1) both;
        }
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