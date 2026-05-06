import React, { useState, useRef, useEffect, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { useSelector } from 'react-redux';
import {
  Heart, MessageCircle, Send, MoreHorizontal,
  Bookmark, ChevronLeft,
  ShoppingBag, Loader2, UserPlus, UserCheck, X, Trash2,
  ExternalLink, RefreshCw
} from 'lucide-react';
import promoteReelService from '../services/promoteReelService';
import Avatar from '../components/Avatar';

const BASE_URL = 'https://api.bebsmart.in';
const IMAGE_DURATION = 15;

const authHeaders = () => {
  const token = localStorage.getItem('token');
  return { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) };
};

const fmt = (n = 0) => {
  if (n >= 1_000_000) return (n / 1_000_000).toFixed(1) + 'M';
  if (n >= 1_000) return (n / 1_000).toFixed(1) + 'k';
  return String(n);
};

const formatTimeAgo = (d) => {
  if (!d) return '';
  const diff = Math.floor((Date.now() - new Date(d)) / 1000);
  if (diff < 60) return `${diff}s`;
  if (diff < 3600) return `${Math.floor(diff / 60)}m`;
  if (diff < 86400) return `${Math.floor(diff / 3600)}h`;
  return `${Math.floor(diff / 86400)}d`;
};

const getReplyMetaCount = (comment) =>
  comment.reply_count ?? comment.replies_count ?? comment.replyCount ?? 0;

// ─── Reply Row ────────────────────────────────────────────────────────────────
const ReplyRow = ({ reply, onLikeReply, onDeleteReply, onReply, currentUserId }) => {
  const rUser = reply.user || reply.users || (typeof reply.user_id === 'object' ? reply.user_id : {});
  const rLiked = reply.is_liked_by_me || false;
  const rLikes = reply.likes_count ?? 0;
  const rId = reply._id || reply.id;
  const rUserId = rUser._id || rUser.id || reply.user_id;
  const isOwner = currentUserId && String(rUserId || '') === String(currentUserId);

  return (
    <div className="flex gap-2.5 py-2 group/reply">
      <Avatar src={rUser.avatar_url} username={rUser.username || rUser.full_name} size="xs" />
      <div className="flex-1 min-w-0">
        <div className="flex items-start justify-between gap-2">
          <div className="flex-1 min-w-0">
            <span className="font-semibold text-gray-900 dark:text-white text-xs mr-1.5">{rUser.username || rUser.full_name || 'Unknown'}</span>
            <span className="text-gray-600 dark:text-gray-300 text-xs break-words leading-snug">{reply.text || reply.content}</span>
          </div>
          <button onClick={() => onLikeReply(rId, rLiked)} className="flex flex-col items-center gap-0.5 flex-shrink-0 active:scale-90 transition-transform pt-0.5">
            <Heart size={12} className={rLiked ? 'text-red-500' : 'text-gray-400 hover:text-gray-600 transition-colors'} fill={rLiked ? 'currentColor' : 'none'} />
            {rLikes > 0 && <span className={`text-[9px] leading-none ${rLiked ? 'text-red-400' : 'text-gray-400'}`}>{rLikes}</span>}
          </button>
        </div>
        <div className="flex items-center gap-3 mt-1">
          <span className="text-gray-400 text-[11px]">{formatTimeAgo(reply.createdAt || reply.created_at)}</span>
          <button onClick={() => onReply({ id: rId, username: rUser.username || rUser.full_name })} className="text-gray-500 text-[11px] font-semibold hover:text-gray-800 dark:hover:text-white transition-colors">Reply</button>
          {isOwner && (
            <button onClick={() => onDeleteReply(rId)} className="text-gray-400 hover:text-red-500 transition-colors opacity-0 group-hover/reply:opacity-100">
              <Trash2 size={11} />
            </button>
          )}
        </div>
      </div>
    </div>
  );
};

// ─── Comment Row ──────────────────────────────────────────────────────────────
const CommentRow = ({ comment, replies, expanded, onToggleReplies, onReply, onLikeComment, onDeleteComment, onLikeReply, onDeleteReply, currentUserId }) => {
  const commentId = comment._id || comment.id;
  const user = comment.user || comment.users || (typeof comment.user_id === 'object' ? comment.user_id : {});
  const isLiked = comment.is_liked_by_me || false;
  const likesCount = comment.likes_count ?? 0;
  const currentReplies = replies[commentId] || [];
  const replyCount = currentReplies.length > 0 ? currentReplies.length : getReplyMetaCount(comment);
  const userId = user._id || user.id || (typeof comment.user_id === 'string' ? comment.user_id : null);
  const isOwner = currentUserId && String(userId || '') === String(currentUserId);

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
              <Heart size={14} className={isLiked ? 'text-red-500' : 'text-gray-400 hover:text-gray-600 transition-colors'} fill={isLiked ? 'currentColor' : 'none'} />
              {likesCount > 0 && <span className={`text-[10px] leading-none ${isLiked ? 'text-red-400' : 'text-gray-400'}`}>{likesCount}</span>}
            </button>
          </div>
          <div className="flex items-center gap-3 mt-1.5">
            <span className="text-gray-400 text-xs">{formatTimeAgo(comment.createdAt || comment.created_at)}</span>
            {likesCount > 0 && <span className="text-gray-400 text-xs">{fmt(likesCount)} likes</span>}
            <button onClick={() => onReply({ id: commentId, rootCommentId: commentId, username: user.username || user.full_name })} className="text-gray-500 text-xs font-semibold hover:text-gray-800 dark:hover:text-white transition-colors">Reply</button>
            {isOwner && (
              <button onClick={() => onDeleteComment(commentId)} className="text-gray-400 hover:text-red-500 transition-colors opacity-0 group-hover/comment:opacity-100 ml-auto">
                <Trash2 size={12} />
              </button>
            )}
          </div>
          {replyCount > 0 && (
            <button onClick={() => onToggleReplies(commentId)} className="flex items-center gap-2 mt-2 text-xs text-gray-500 hover:text-gray-800 dark:hover:text-white transition-colors">
              <div className="w-5 h-px bg-gray-300 dark:bg-gray-600" />
              <span className="font-semibold">{expanded ? 'Hide replies' : `View all ${replyCount} ${replyCount === 1 ? 'reply' : 'replies'}`}</span>
            </button>
          )}
        </div>
      </div>
      {expanded && (
        <div className="ml-[52px] pr-4 mb-2 border-l border-gray-200 dark:border-white/10 pl-3">
          {currentReplies.length === 0 ? (
            <div className="flex items-center gap-2 py-2"><Loader2 size={12} className="animate-spin text-gray-400" /><span className="text-gray-400 text-xs italic">Loading replies...</span></div>
          ) : (
            currentReplies.map(reply => (
              <ReplyRow key={reply._id || reply.id} reply={reply} onLikeReply={onLikeReply} onDeleteReply={onDeleteReply}
                onReply={(ru) => onReply({ id: reply._id || reply.id, rootCommentId: commentId, username: ru.username })}
                currentUserId={currentUserId} />
            ))
          )}
        </div>
      )}
    </div>
  );
};

// ─── Comments Panel ───────────────────────────────────────────────────────────
const CommentsContent = ({ comments, replies, expandedComments, onToggleReplies, loading, replyTo, commentText, setCommentText, setReplyTo, handlePostComment, closeComments, handleLikeComment, handleDeleteComment, onLikeReply, onDeleteReply, currentUserId, currentUserAvatar, currentUserName }) => (
  <div className="flex flex-col h-full bg-white dark:bg-[#262626]">
    <div className="flex items-center justify-between px-4 py-3 border-b border-gray-100 dark:border-white/10 shrink-0">
      <span className="font-bold text-sm dark:text-white">Comments ({comments.length})</span>
      <button onClick={closeComments} className="p-1 hover:bg-gray-100 dark:hover:bg-white/10 rounded-full text-gray-500 dark:text-gray-400"><X size={20} /></button>
    </div>
    <div className="flex-1 overflow-y-auto scrollbar-none">
      {loading ? (
        <div className="flex justify-center py-8 text-gray-400"><Loader2 className="animate-spin" /></div>
      ) : comments.length === 0 ? (
        <div className="flex flex-col items-center justify-center h-40 text-gray-400 text-sm"><MessageCircle size={32} className="mb-2 opacity-50" />No comments yet. Be the first!</div>
      ) : (
        comments.map(c => {
          const cid = c._id || c.id;
          return (
            <CommentRow key={cid} comment={c} replies={replies} expanded={expandedComments[cid]}
              onToggleReplies={onToggleReplies}
              onReply={(user) => setReplyTo({ id: cid, rootCommentId: cid, username: user.username })}
              onLikeComment={handleLikeComment} onDeleteComment={handleDeleteComment}
              onLikeReply={onLikeReply} onDeleteReply={onDeleteReply} currentUserId={currentUserId} />
          );
        })
      )}
    </div>
    <div className="p-3 border-t border-gray-100 dark:border-white/10 bg-white dark:bg-[#262626] shrink-0">
      {replyTo && (
        <div className="flex items-center justify-between text-xs text-gray-500 mb-2 px-1">
          <span>Replying to <span className="font-bold text-blue-500">@{replyTo.username}</span></span>
          <button onClick={() => setReplyTo(null)}><X size={12} /></button>
        </div>
      )}
      <div className="flex items-center gap-2 bg-gray-100 dark:bg-white/10 rounded-full px-3 py-2">
        <Avatar src={currentUserAvatar} username={currentUserName} size="xs" />
        <input type="text" placeholder={replyTo ? `Reply to @${replyTo.username}...` : 'Add a comment...'}
          value={commentText} onChange={e => setCommentText(e.target.value)}
          onKeyDown={e => e.key === 'Enter' && handlePostComment()}
          className="flex-1 bg-transparent border-none outline-none text-sm dark:text-white placeholder:text-gray-400" />
        <button onClick={handlePostComment} disabled={!commentText.trim()} className="text-blue-500 disabled:opacity-50 font-semibold text-sm hover:text-blue-600 transition-colors">Post</button>
      </div>
    </div>
  </div>
);

// ─── Follow Button ─────────────────────────────────────────────────────────────
const FollowButton = ({ userId, mobile = false }) => {
  const [followed, setFollowed] = useState(false);
  const [loading, setLoading] = useState(false);
  const toggle = async (e) => {
    e.stopPropagation();
    if (loading || !userId) return;
    setLoading(true);
    const was = followed;
    setFollowed(!was);
    try {
      const res = await fetch(`${BASE_URL}${was ? '/api/unfollow' : '/api/follow'}`, {
        method: 'POST', headers: authHeaders(), body: JSON.stringify({ followedUserId: userId }),
      });
      if (!res.ok) throw new Error();
    } catch { setFollowed(was); }
    finally { setLoading(false); }
  };
  return (
    <button onClick={toggle} disabled={loading}
      className={`shrink-0 whitespace-nowrap flex items-center gap-1 px-2.5 py-0.5 rounded-lg text-[11px] font-semibold transition-all
        ${followed
          ? mobile ? 'border border-white/40 bg-white/20 text-white backdrop-blur-sm' : 'border border-green-500/60 bg-green-500/10 text-green-400'
          : mobile ? 'border border-white/40 bg-white/10 text-white backdrop-blur-sm hover:bg-white/20' : 'border border-blue-500/60 bg-blue-500/10 text-blue-400 hover:bg-blue-500/20'
        } ${loading ? 'opacity-60 cursor-not-allowed' : ''}`}>
      {loading ? <Loader2 size={10} className="animate-spin" /> : followed ? <UserCheck size={11} /> : <UserPlus size={11} />}
      <span>{followed ? 'Following' : 'Follow'}</span>
    </button>
  );
};

// ─── Action Buttons ────────────────────────────────────────────────────────────
const ActionButtons = ({ promote, likedIds, toggleLike, savedIds, toggleSave, mobile = false, onComment, onMore }) => (
  <div className="flex flex-col items-center gap-4">
    <button onClick={() => toggleLike(promote._id)} className="flex flex-col items-center gap-1">
      <div className={`w-10 h-10 rounded-full flex items-center justify-center transition-all active:scale-90
        ${mobile ? 'bg-black/30 backdrop-blur-sm' : 'bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-700 shadow-sm hover:bg-gray-50 dark:hover:bg-gray-800'}`}>
        <Heart size={20} className={(likedIds.has(promote._id) || promote.is_liked_by_me) ? 'text-red-500 fill-red-500' : mobile ? 'text-white' : 'text-gray-800 dark:text-white'} />
      </div>
      <span className={`text-xs font-semibold ${mobile ? 'text-white' : 'text-gray-700 dark:text-white'}`}>{fmt(promote.likes_count)}</span>
    </button>

    <button onClick={() => onComment && onComment(promote)} className="flex flex-col items-center gap-1">
      <div className={`w-10 h-10 rounded-full flex items-center justify-center transition-all active:scale-90
        ${mobile ? 'bg-black/30 backdrop-blur-sm' : 'bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-700 shadow-sm hover:bg-gray-50 dark:hover:bg-gray-800'}`}>
        <MessageCircle size={20} className={mobile ? 'text-white' : 'text-gray-800 dark:text-white'} />
      </div>
      <span className={`text-xs font-semibold ${mobile ? 'text-white' : 'text-gray-700 dark:text-white'}`}>{fmt(promote.comments_count)}</span>
    </button>

    <button className="flex flex-col items-center gap-1">
      <div className={`w-10 h-10 rounded-full flex items-center justify-center transition-all active:scale-90
        ${mobile ? 'bg-black/30 backdrop-blur-sm' : 'bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-700 shadow-sm hover:bg-gray-50 dark:hover:bg-gray-800'}`}>
        <Send size={18} className={`-rotate-12 relative left-[-2px] ${mobile ? 'text-white' : 'text-gray-800 dark:text-white'}`} />
      </div>
      <span className={`text-xs font-semibold ${mobile ? 'text-white' : 'text-gray-700 dark:text-white'}`}>Share</span>
    </button>

    <button onClick={() => toggleSave(promote._id)} className="flex flex-col items-center gap-1">
      <div className={`w-10 h-10 rounded-full flex items-center justify-center transition-all active:scale-90
        ${mobile ? 'bg-black/30 backdrop-blur-sm' : 'bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-700 shadow-sm hover:bg-gray-50 dark:hover:bg-gray-800'}`}>
        <Bookmark size={20} className={savedIds.has(promote._id) ? (mobile ? 'text-yellow-400 fill-yellow-400' : 'text-yellow-500 fill-yellow-500') : mobile ? 'text-white' : 'text-gray-800 dark:text-white'} />
      </div>
      <span className={`text-xs font-semibold ${mobile ? 'text-white' : 'text-gray-700 dark:text-white'}`}>Save</span>
    </button>

    <button onClick={() => onMore?.(promote)} className="flex flex-col items-center gap-1">
      <div className={`w-10 h-10 rounded-full flex items-center justify-center transition-all active:scale-90
        ${mobile ? 'bg-black/30 backdrop-blur-sm' : 'bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-700 shadow-sm hover:bg-gray-50 dark:hover:bg-gray-800'}`}>
        <MoreHorizontal size={20} className={mobile ? 'text-white' : 'text-gray-800 dark:text-white'} />
      </div>
    </button>

    <div className={`w-9 h-9 rounded-full border-2 ${mobile ? 'border-white' : 'border-gray-300 dark:border-gray-600'} overflow-hidden shadow-md mt-1`}>
      {promote.user_id?.avatar_url
        ? <img src={promote.user_id.avatar_url} className="w-full h-full object-cover" alt="user" />
        : <div className="w-full h-full bg-gradient-to-br from-purple-500 to-pink-500 flex items-center justify-center text-white text-xs font-bold">
            {(promote.user_id?.username || 'P')[0]}
          </div>
      }
    </div>
  </div>
);

// ─── Caption ──────────────────────────────────────────────────────────────────
const Caption = ({ text }) => {
  const [expanded, setExpanded] = useState(false);
  if (!text) return null;
  const words = text.trim().split(/\s+/);
  const isLong = words.length > 5;
  const preview = isLong ? words.slice(0, 5).join(' ') : text;
  return (
    <p className="text-white text-sm leading-relaxed mb-2">
      {expanded || !isLong ? (
        <>{text}{expanded && isLong && <button onClick={() => setExpanded(false)} className="text-white/60 ml-1.5 hover:text-white font-semibold">less</button>}</>
      ) : (
        <>{preview}<button onClick={() => setExpanded(true)} className="text-white/60 ml-1 hover:text-white font-medium">... more</button></>
      )}
    </p>
  );
};

// ─── Product Strip (bottom overlay) ──────────────────────────────────────────
// ─── HLS Video Player (handles .m3u8 streams via hls.js) ─────────────────────
const HlsVideo = ({ src, thumb, isCurrent, isPaused, onTimeUpdate, onEnded, onClick }) => {
  const videoRef = useRef(null);
  const hlsRef = useRef(null);
  const [ready, setReady] = useState(false);

  useEffect(() => {
    const video = videoRef.current;
    if (!video || !src) return;

    const setupHls = () => {
      if (hlsRef.current) { hlsRef.current.destroy(); hlsRef.current = null; }
      if (window.Hls?.isSupported()) {
        const hls = new window.Hls({ enableWorker: false, startLevel: -1 });
        hlsRef.current = hls;
        hls.loadSource(src);
        hls.attachMedia(video);
        hls.on(window.Hls.Events.MANIFEST_PARSED, () => setReady(true));
        hls.on(window.Hls.Events.ERROR, (_, d) => { if (d?.fatal) console.error('[HLS] fatal', d); });
      } else if (video.canPlayType('application/vnd.apple.mpegurl')) {
        video.src = src;
        setReady(true);
      } else {
        video.src = src;
        setReady(true);
      }
    };

    if (src.includes('.m3u8')) {
      if (window.Hls) { setupHls(); }
      else {
        const s = document.createElement('script');
        s.src = 'https://cdn.jsdelivr.net/npm/hls.js@1.4.12/dist/hls.min.js';
        s.onload = setupHls;
        document.head.appendChild(s);
      }
    } else {
      video.src = src;
      setReady(true);
    }

    return () => { if (hlsRef.current) { hlsRef.current.destroy(); hlsRef.current = null; } };
  }, [src]);

  useEffect(() => {
    const video = videoRef.current;
    if (!video || !ready) return;
    if (isCurrent && !isPaused) {
      video.play().catch(() => {});
    } else {
      video.pause();
      if (!isCurrent) { try { video.currentTime = 0; } catch {} }
    }
  }, [isCurrent, isPaused, ready]);

  return (
    <div className="w-full h-full relative" onClick={onClick}>
      {thumb && !ready && (
        <img src={thumb} alt="thumbnail" className="absolute inset-0 w-full h-full object-cover" />
      )}
      <video
        ref={videoRef}
        className="w-full h-full object-cover"
        muted={false}
        playsInline
        preload="metadata"
        loop
        onTimeUpdate={e => {
          const v = e.target;
          if (v.duration > 0) onTimeUpdate?.((v.currentTime / v.duration) * 100);
        }}
        onEnded={onEnded}
      />
      {isCurrent && isPaused && ready && (
        <div className="absolute inset-0 flex items-center justify-center pointer-events-none">
          <div className="w-16 h-16 rounded-full bg-black/50 backdrop-blur-sm flex items-center justify-center">
            <svg width="28" height="28" viewBox="0 0 24 24" fill="white"><path d="M8 5v14l11-7z"/></svg>
          </div>
        </div>
      )}
    </div>
  );
};

// ─── Product Cards ────────────────────────────────────────────────────────────
const ProductCards = ({ products }) => {
  const [open, setOpen] = useState(true);

  if (!products || products.length === 0) return null;

  return (
    <div className="mt-1">
      {/* Toggle button — pill style, not arrow */}
      <button
        onClick={e => { e.stopPropagation(); setOpen(v => !v); }}
        className="flex items-center gap-1.5 mb-2 bg-black/30 backdrop-blur-sm border border-white/20 rounded-full px-3 py-1 active:scale-95 transition-all"
      >
        <ShoppingBag size={11} className="text-white" />
        <span className="text-white text-[11px] font-semibold">
          {open ? 'Hide Products' : `${products.length} Product${products.length > 1 ? 's' : ''}`}
        </span>
      </button>

      {/* Slide transition wrapper */}
      <div
        style={{
          maxHeight: open ? '200px' : '0px',
          opacity: open ? 1 : 0,
          overflow: 'hidden',
          transition: 'max-height 0.35s cubic-bezier(0.4,0,0.2,1), opacity 0.25s ease',
        }}
        onClick={e => e.stopPropagation()}
      >
        <div
          className="flex  gap-2 pb-1"
          style={{ overflowX: 'auto', scrollbarWidth: 'none', WebkitOverflowScrolling: 'touch' }}
        >
          {products.map((p, i) => {
            const finalPrice = Math.max(0, (p.product_price || 0) - (p.discount_amount || 0));
            const discountPct = p.product_price && p.discount_amount
              ? Math.round((p.discount_amount / p.product_price) * 100) : 0;

            return (
              <div
                key={i}
                className="flex-shrink-0 w-[200px] bg-white rounded-2xl overflow-hidden shadow-xl flex flex-row"
              >
                {/* LEFT — square image */}
                <div className="w-[70px] h-full bg-gray-100 self-stretch overflow-hidden">
                  {p.promote_img
                    ? <img src={p.promote_img} alt={p.product_name} className="w-full h-full object-cover" />
                    : <div className="w-full h-full flex items-center justify-center bg-gray-100">
                        <ShoppingBag size={20} className="text-gray-300" />
                      </div>
                  }
                </div>

                {/* RIGHT — info */}
                <div className="flex-1 px-2.5 py-2 flex flex-col gap-0.5 min-w-0">
                  {/* Name + description */}
                  <p className="text-gray-900 text-[11px] font-bold line-clamp-2 leading-tight">{p.product_name}</p>
                  {p.product_description && (
                    <p className="text-gray-400 text-[9px] line-clamp-1 leading-tight">{p.product_description}</p>
                  )}

                  {/* Price row */}
                  <div className="flex items-baseline gap-1 flex-wrap mt-0.5">
                    <span className="text-gray-900 text-[12px] font-black">₹{finalPrice}</span>
                    {discountPct > 0 && (
                      <>
                        <span className="text-gray-400 text-[9px] line-through">₹{p.product_price}</span>
                        <span className="text-green-600 text-[9px] font-bold">{discountPct}% off</span>
                      </>
                    )}
                  </div>

                  {/* Add to Cart button */}
                  {p.visit_link ? (
                    <a
                      href={p.visit_link}
                      target="_blank"
                      rel="noopener noreferrer"
                      onClick={e => e.stopPropagation()}
                      className="mt-1.5 flex items-center justify-center w-full py-1.5 rounded-lg bg-blue-500 text-white text-[10px] font-bold hover:bg-blue-600 active:scale-95 transition-all"
                    >
                      Add to Cart
                    </a>
                  ) : (
                    <div className="mt-1.5 w-full py-1.5 rounded-lg bg-gray-100 text-gray-400 text-[10px] text-center">
                      No link
                    </div>
                  )}
                </div>
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
};

// ─── Main Page ─────────────────────────────────────────────────────────────────
const Promote = () => {
  const { userObject } = useSelector(s => s.auth);
  const currentUserId = userObject?._id || userObject?.id || null;
  const currentUserAvatar = userObject?.avatar_url || null;
  const currentUserName = userObject?.full_name || userObject?.username || 'You';
  const navigate = useNavigate();
  const pageHeightClass = 'h-[calc(100dvh-4rem)] md:h-[calc(100dvh-1rem)]';

  useEffect(() => {
    const prevH = document.documentElement.style.overflow;
    const prevB = document.body.style.overflow;
    document.documentElement.style.overflow = 'hidden';
    document.body.style.overflow = 'hidden';
    return () => { document.documentElement.style.overflow = prevH; document.body.style.overflow = prevB; };
  }, []);

  const [promotes, setPromotes] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [currentIndex, setCurrentIndex] = useState(0);
  const [isPausedByUser, setIsPausedByUser] = useState(false);
  const [touchStartY, setTouchStartY] = useState(null);
  const [progress, setProgress] = useState(0);
  const [likedIds, setLikedIds] = useState(new Set());
  const [savedIds, setSavedIds] = useState(new Set());
  const [page, setPage] = useState(1);
  const [hasMore, setHasMore] = useState(true);

  // Comments state — mirrors Ads.jsx exactly
  const [activeCommentId, setActiveCommentId] = useState(null);
  const [comments, setComments] = useState([]);
  const [replies, setReplies] = useState({});
  const [expandedComments, setExpandedComments] = useState({});
  const [loadingComments, setLoadingComments] = useState(false);
  const [replyTo, setReplyTo] = useState(null);
  const [commentText, setCommentText] = useState('');

  const isAnimatingRef = useRef(false);
  const videoRefs = useRef({});
  const progressIntervalRef = useRef(null);
  const actionPanelRef = useRef(null);
  const [actionPanelRight, setActionPanelRight] = useState(100);

  // Measure action panel
  useEffect(() => {
    const measure = () => {
      if (actionPanelRef.current) {
        const rect = actionPanelRef.current.getBoundingClientRect();
        setActionPanelRight(rect.right + 12);
      }
    };
    measure();
    window.addEventListener('resize', measure);
    return () => window.removeEventListener('resize', measure);
  });

  // ── Fetch ────────────────────────────────────────────────────────────────────
  const fetchPromotes = useCallback(async (pg = 1, append = false) => {
    if (pg === 1) setLoading(true);
    setError(null);
    try {
      const res = await promoteReelService.listPromoteReels({ page: pg, limit: 10 });
      // API returns { page, limit, data: [...] } or plain array
      const items = Array.isArray(res?.data) ? res.data : (Array.isArray(res) ? res : []);
      if (append) {
        setPromotes(prev => [...prev, ...items]);
      } else {
        setPromotes(items);
        setCurrentIndex(0);
        setProgress(0);
        setLikedIds(new Set(items.filter(p => p.is_liked_by_me).map(p => p._id)));
      }
      setHasMore(items.length === 10);
    } catch (err) {
      setError(err.message || 'Failed to load');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { fetchPromotes(1); }, [fetchPromotes]);

  // Load more near end
  useEffect(() => {
    if (!hasMore || loading) return;
    if (promotes.length > 0 && currentIndex >= promotes.length - 3) {
      const next = page + 1;
      setPage(next);
      fetchPromotes(next, true);
    }
  }, [currentIndex, promotes.length, hasMore, loading, page, fetchPromotes]);

  // ── Progress bar (image promotes) ────────────────────────────────────────────
  useEffect(() => {
    const promote = promotes[currentIndex];
    if (!promote) return;
    const isVideo = promote.media?.[0]?.type === 'video';
    setProgress(0);
    clearInterval(progressIntervalRef.current);
    if (isVideo) return;

    const startTime = Date.now();
    const totalMs = IMAGE_DURATION * 1000;
    progressIntervalRef.current = setInterval(() => {
      const pct = Math.min(((Date.now() - startTime) / totalMs) * 100, 100);
      setProgress(pct);
      if (pct >= 100) {
        clearInterval(progressIntervalRef.current);
        setCurrentIndex(prev => prev + 1 < promotes.length ? prev + 1 : prev);
      }
    }, 250);
    return () => clearInterval(progressIntervalRef.current);
  }, [currentIndex, promotes]);

  // ── Play/pause videos ────────────────────────────────────────────────────────
  useEffect(() => {
    if (!promotes.length) return;
    Object.entries(videoRefs.current).forEach(([idx, vid]) => {
      if (vid && Number(idx) !== currentIndex) { vid.pause(); try { vid.currentTime = 0; } catch {} }
    });
    const promote = promotes[currentIndex];
    if (!promote?.media?.[0]?.type === 'video') return;
    if (isPausedByUser) return;
    let rafId;
    let attempts = 0;
    const tryPlay = () => {
      const vid = videoRefs.current[currentIndex];
      if (!vid) return;
      const promise = vid.play();
      if (promise) promise.catch(() => { if (attempts < 5) { attempts++; rafId = requestAnimationFrame(tryPlay); } });
    };
    rafId = requestAnimationFrame(tryPlay);
    return () => cancelAnimationFrame(rafId);
  }, [currentIndex, promotes, isPausedByUser]);

  // ── Navigation ────────────────────────────────────────────────────────────────
  const goToIndex = useCallback((index) => {
    if (isAnimatingRef.current) return;
    const next = Math.min(promotes.length - 1, Math.max(0, index));
    if (next === currentIndex) return;
    isAnimatingRef.current = true;
    const curVid = videoRefs.current[currentIndex];
    if (curVid) curVid.pause();
    setIsPausedByUser(false);
    setCurrentIndex(next);
    setTimeout(() => { isAnimatingRef.current = false; }, 500);
  }, [currentIndex, promotes.length]);

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

  const handleVideoTap = useCallback((index) => {
    const vid = videoRefs.current[index];
    if (!vid) return;
    if (vid.paused) { vid.play().catch(() => {}); setIsPausedByUser(false); }
    else { vid.pause(); setIsPausedByUser(true); }
  }, []);

  // ── Like / Save ───────────────────────────────────────────────────────────────
  const toggleLike = useCallback(async (id) => {
    const isLiked = likedIds.has(id);
    setLikedIds(prev => { const s = new Set(prev); isLiked ? s.delete(id) : s.add(id); return s; });
    setPromotes(prev => prev.map(p => p._id === id ? { ...p, likes_count: (p.likes_count || 0) + (isLiked ? -1 : 1), is_liked_by_me: !isLiked } : p));
    try {
      if (isLiked) await promoteReelService.unlikePromoteReel(id);
      else await promoteReelService.likePromoteReel(id);
    } catch {
      setLikedIds(prev => { const s = new Set(prev); isLiked ? s.add(id) : s.delete(id); return s; });
      setPromotes(prev => prev.map(p => p._id === id ? { ...p, likes_count: (p.likes_count || 0) + (isLiked ? 1 : -1), is_liked_by_me: isLiked } : p));
    }
  }, [likedIds]);

  const toggleSave = useCallback((id) => {
    setSavedIds(prev => { const s = new Set(prev); s.has(id) ? s.delete(id) : s.add(id); return s; });
  }, []);

  // ── Comments (mirrors Ads.jsx) ────────────────────────────────────────────────
  const loadReplies = useCallback(async (commentId) => {
    try {
      const data = await promoteReelService.getReplies(commentId);
      const fetched = Array.isArray(data) ? data : (data.replies || data.data || []);
      setReplies(prev => ({ ...prev, [commentId]: fetched }));
    } catch {}
  }, []);

  const fetchComments = useCallback(async (promoteId) => {
    if (!promoteId) return;
    setLoadingComments(true);
    try {
      const data = await promoteReelService.getComments(promoteId);
      const list = Array.isArray(data) ? data : (data.comments || data.data || []);
      setComments(list);
      list.forEach(comment => {
        const cid = comment._id || comment.id;
        promoteReelService.getReplies(cid)
          .then(r => { const f = Array.isArray(r) ? r : (r.replies || r.data || []); if (f.length > 0) setReplies(prev => ({ ...prev, [cid]: f })); })
          .catch(() => {});
      });
    } catch {}
    finally { setLoadingComments(false); }
  }, []);

  const openComments = useCallback((promote) => {
    setActiveCommentId(promote._id);
    setReplies({}); setExpandedComments({}); setReplyTo(null); setCommentText('');
    fetchComments(promote._id);
  }, [fetchComments]);

  const closeComments = useCallback(() => {
    setActiveCommentId(null); setComments([]); setReplies({}); setExpandedComments({}); setReplyTo(null); setCommentText('');
  }, []);

  const handlePostComment = async () => {
    if (!commentText.trim() || !activeCommentId) return;
    const text = commentText.trim();
    const ri = replyTo;
    setCommentText(''); setReplyTo(null);
    try {
      await promoteReelService.addComment(activeCommentId, text, ri?.id || null);
      if (ri) {
        await loadReplies(ri.rootCommentId);
        setExpandedComments(prev => ({ ...prev, [ri.rootCommentId]: true }));
      } else {
        await fetchComments(activeCommentId);
        setPromotes(prev => prev.map(p => p._id === activeCommentId ? { ...p, comments_count: (p.comments_count || 0) + 1 } : p));
      }
    } catch { setCommentText(text); if (ri) setReplyTo(ri); }
  };

  const handleLikeComment = async (commentId, isLiked) => {
    try {
      if (isLiked) await promoteReelService.unlikeComment(commentId);
      else await promoteReelService.likeComment(commentId);
      fetchComments(activeCommentId);
      Object.keys(replies).forEach(k => loadReplies(k));
    } catch {}
  };

  const handleLikeReply = async (replyId, isLiked) => {
    try {
      if (isLiked) await promoteReelService.unlikeComment(replyId);
      else await promoteReelService.likeComment(replyId);
      Object.keys(replies).forEach(k => loadReplies(k));
    } catch {}
  };

  const handleDeleteReply = async (replyId) => {
    if (!window.confirm('Delete this reply?')) return;
    try {
      await promoteReelService.deleteComment(replyId);
      Object.keys(replies).forEach(k => loadReplies(k));
    } catch {}
  };

  const onToggleReplies = (commentId) => {
    if (!expandedComments[commentId] && (!replies[commentId] || replies[commentId].length === 0)) loadReplies(commentId);
    setExpandedComments(prev => ({ ...prev, [commentId]: !prev[commentId] }));
  };

  const handleDeleteComment = async (commentId) => {
    if (!window.confirm('Delete this comment?')) return;
    try {
      await promoteReelService.deleteComment(commentId);
      setComments(prev => prev.filter(c => (c._id || c.id) !== commentId));
      setPromotes(prev => prev.map(p => p._id === activeCommentId ? { ...p, comments_count: Math.max(0, (p.comments_count || 1) - 1) } : p));
    } catch {}
  };

  const promote = promotes[currentIndex];

  // ── Render ────────────────────────────────────────────────────────────────────
  return (
    <div className={`flex flex-col dark:bg-black overflow-hidden ${pageHeightClass}`}>
       <div className="shrink-0 relative flex items-center px-3 py-2.5 md:px-4 md:py-3 border-b border-gray-200 dark:border-white/10 bg-white dark:bg-black">
                <button onClick={() => navigate(-1)} className="w-9 h-9 flex items-center justify-center rounded-full hover:bg-gray-100 dark:hover:bg-white/10 text-gray-900 dark:text-white transition-colors">
                  <ChevronLeft size={22} />
                </button>
                <div className="absolute left-1/2 -translate-x-1/2 text-gray-900 dark:text-white font-bold text-sm md:text-base">
                  Promote
                </div>
                <div className="w-9 h-9" />
              </div>
    
      <div className="flex flex-1 min-h-0 overflow-hidden relative">
        <div className="flex-1 flex items-center justify-center relative overflow-hidden h-full bg-black md:bg-white dark:bg-black"
          onWheel={handleWheel} onTouchStart={handleTouchStart} onTouchEnd={handleTouchEnd}>

          {/* Mobile top bar */}
          <div className="md:hidden absolute top-0 left-0 right-0 z-30 flex items-center px-3 pt-3 pb-1 gap-3 bg-gradient-to-b from-black/60 to-transparent">
            <button onClick={() => navigate(-1)} className="w-8 h-8 flex items-center justify-center shrink-0">
              <ChevronLeft size={22} className="text-white" />
            </button>
            <div className="flex items-center gap-1.5">
              <ShoppingBag size={16} className="text-white" />
              <span className="font-bold text-white text-sm">Promote</span>
            </div>
          </div>

          {/* Loading */}
          {loading && (
            <div className="flex flex-col items-center gap-3 text-gray-400">
              <Loader2 size={32} className="animate-spin" />
              <span className="text-sm">Loading promote reels…</span>
            </div>
          )}

          {/* Error */}
          {!loading && error && (
            <div className="flex flex-col items-center gap-3 text-center px-6">
              <p className="text-red-400 font-semibold">Failed to load</p>
              <button onClick={() => fetchPromotes(1)} className="flex items-center gap-2 px-4 py-2 bg-gray-900 dark:bg-white text-white dark:text-black rounded-full text-sm font-semibold">
                <RefreshCw size={14} /> Retry
              </button>
            </div>
          )}

          {/* Empty */}
          {!loading && !error && promotes.length === 0 && (
            <div className="flex flex-col items-center gap-3 text-center px-8">
              <ShoppingBag size={48} className="text-gray-200 dark:text-white/10" />
              <p className="text-lg font-bold text-gray-900 dark:text-white">No Promote Reels</p>
              <p className="text-sm text-gray-400">Be the first to share a promoted reel!</p>
            </div>
          )}

          {/* Carousel */}
          {!loading && !error && promotes.length > 0 && (
            <div className="relative overflow-hidden bg-black w-full max-w-[430px] h-full md:w-[360px] md:h-[90vh] md:rounded-2xl md:shadow-2xl">

              {/* Progress bar — white track, white fill, red dot on hover; click/drag to scrub */}
              <div className="absolute bottom-0 left-0 right-0 z-40 px-1.5 pb-1 group/progress select-none">
                <div
                  className="relative h-[4px] w-full rounded-full bg-white/25 cursor-pointer"
                  onClick={(e) => {
                    const rect = e.currentTarget.getBoundingClientRect();
                    const pct = Math.min(1, Math.max(0, (e.clientX - rect.left) / rect.width));
                    const vid = videoRefs.current[currentIndex];
                    if (vid && vid.duration > 0) { vid.currentTime = pct * vid.duration; setProgress(pct * 100); }
                  }}
                  onMouseDown={(e) => {
                    e.preventDefault();
                    const bar = e.currentTarget;
                    const scrub = (ev) => {
                      const rect = bar.getBoundingClientRect();
                      const pct = Math.min(1, Math.max(0, (ev.clientX - rect.left) / rect.width));
                      const vid = videoRefs.current[currentIndex];
                      if (vid && vid.duration > 0) { vid.currentTime = pct * vid.duration; setProgress(pct * 100); }
                    };
                    const up = () => { document.removeEventListener('mousemove', scrub); document.removeEventListener('mouseup', up); };
                    document.addEventListener('mousemove', scrub);
                    document.addEventListener('mouseup', up);
                  }}
                >
                  {/* Fill — white */}
                  <div className="absolute left-0 top-0 h-full rounded-full bg-white transition-none" style={{ width: `${progress}%` }} />
                  {/* Dot — invisible normally, red on hover */}
                  <div
                    className="absolute top-1/2 h-[14px] w-[14px] -translate-y-1/2 rounded-full bg-white opacity-0 group-hover/progress:opacity-100 group-hover/progress:bg-[#ff0033] shadow-[0_0_0_2px_rgba(0,0,0,0.4)] transition-all duration-150 pointer-events-none"
                    style={{ left: `calc(${progress}% - 7px)` }}
                  />
                </div>
              </div>

              {/* Slides */}
              <div className="h-full w-full transition-transform duration-500 ease-out"
                style={{ transform: `translateY(-${currentIndex * 100}%)`, willChange: 'transform' }}>

                {promotes.map((p, index) => {
                  const mediaItem = Array.isArray(p.media) ? p.media[0] : null;
                  const src = mediaItem?.fileUrl || mediaItem?.url || (mediaItem?.fileName ? `${BASE_URL}/uploads/${mediaItem.fileName}` : null);
                  const isVideo = mediaItem?.type === 'video' || src?.includes('.m3u8');
                  // thumbnail: from thumbnails[] or thumbnail[]
                  const thumbItem = mediaItem?.thumbnails?.[0] || (Array.isArray(mediaItem?.thumbnail) ? mediaItem.thumbnail[0] : mediaItem?.thumbnail);
                  const thumbSrc = thumbItem?.fileUrl || (thumbItem?.fileName ? `${BASE_URL}/uploads/${thumbItem.fileName}` : null);
                  const isCurrent = index === currentIndex;
                  const user = p.user_id || {};
                  const username = user.username || user.full_name || 'User';

                  return (
                    <div key={p._id || index} className="relative w-full bg-black flex items-center justify-center" style={{ height: '100%', minHeight: '100%' }}>

                      {isVideo ? (
                        <HlsVideo
                          src={src}
                          thumb={thumbSrc}
                          isCurrent={isCurrent}
                          isPaused={isCurrent && isPausedByUser}
                          onTimeUpdate={(pct) => { if (isCurrent) setProgress(pct); }}
                          onEnded={() => {
                            if (!isCurrent) return;
                            setProgress(0);
                            setIsPausedByUser(false);
                            const vid = videoRefs.current[index];
                            if (vid) { vid.currentTime = 0; vid.play().catch(() => {}); }
                          }}
                          onClick={() => {
                            if (!isCurrent) return;
                            const vid = videoRefs.current[index];
                            if (!vid) return;
                            if (vid.paused) { vid.play().catch(() => {}); setIsPausedByUser(false); }
                            else { vid.pause(); setIsPausedByUser(true); }
                          }}
                        />
                      ) : src ? (
                        <img src={src} className="w-full h-full object-cover" alt={p.caption || 'Promote'} />
                      ) : (
                        <div className="w-full h-full flex items-center justify-center bg-gradient-to-br from-purple-900 to-pink-900">
                          <div className="text-center px-6">
                            <div className="text-5xl mb-3">🛍️</div>
                            <p className="text-white font-bold text-lg">{username}</p>
                          </div>
                        </div>
                      )}

                      {/* Gradient */}
                      <div className="absolute inset-0 bg-gradient-to-b from-black/30 via-transparent to-black/80 pointer-events-none" />

                      {/* Bottom info */}
                      <div className="absolute bottom-0 left-0 w-full z-20 flex flex-col justify-end lg:pr-0 pr-[60px]" >
                        <div className="px-4 pt-4 pb-2">
                          {/* User row */}
                          <div className="flex items-center gap-2 mb-2 flex-nowrap min-w-0">
                            <div className="flex items-center gap-2 flex-1 min-w-0">
                              {user.avatar_url
                                ? <img src={user.avatar_url} className="w-8 h-8 rounded-full border border-white/30 object-cover shrink-0" alt="user" />
                                : <div className="w-8 h-8 rounded-full border border-white/30 bg-gradient-to-br from-purple-500 to-pink-500 flex items-center justify-center text-white text-xs font-bold shrink-0">{username[0]}</div>
                              }
                              <span className="font-bold text-white text-sm truncate">{username}</span>
                            </div>
                            <FollowButton userId={user._id || user.id} mobile />
                          </div>

                          <Caption text={p.caption} />

                          {/* Tags */}
                          {Array.isArray(p.tags) && p.tags.length > 0 && (
                            <div className="flex flex-wrap gap-1 mb-2">
                              {p.tags.slice(0, 3).map((tag, ti) => (
                                <span key={ti} className="text-white/60 text-[10px]">#{tag}</span>
                              ))}
                            </div>
                          )}

                          {/* Products — always open */}
                          <ProductCards products={p.products} />
                        </div>

                      </div>

                      {/* Mobile right actions */}
                      {isCurrent && (
                        <div className="md:hidden absolute right-3 bottom-[10px] z-30">
                          <ActionButtons promote={p} mobile likedIds={likedIds} toggleLike={toggleLike} savedIds={savedIds} toggleSave={toggleSave} onComment={openComments} />
                        </div>
                      )}
                    </div>
                  );
                })}
              </div>
            </div>
          )}

          {/* Desktop right actions */}
          {!loading && !error && promote && (
            <div ref={actionPanelRef} className="hidden md:flex flex-col gap-2 ml-4 justify-end h-full md:h-[85vh] pb-4">
              <ActionButtons promote={promote} likedIds={likedIds} toggleLike={toggleLike} savedIds={savedIds} toggleSave={toggleSave} onComment={openComments} />
            </div>
          )}
        </div>
      </div>

      {/* Desktop nav arrows */}
      <div className="hidden md:flex fixed right-5 top-1/2 -translate-y-1/2 z-40 flex-col gap-3">
        <button onClick={() => goToIndex(currentIndex - 1)} disabled={currentIndex === 0}
          className="w-12 h-12 rounded-full bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 shadow-xl flex items-center justify-center hover:bg-gray-50 dark:hover:bg-gray-700 hover:scale-110 active:scale-95 transition-all disabled:opacity-30 disabled:cursor-not-allowed">
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round" className="stroke-gray-800 dark:stroke-white"><polyline points="18 15 12 9 6 15" /></svg>
        </button>
        <button onClick={() => goToIndex(currentIndex + 1)} disabled={currentIndex === promotes.length - 1}
          className="w-12 h-12 rounded-full bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 shadow-xl flex items-center justify-center hover:bg-gray-50 dark:hover:bg-gray-700 hover:scale-110 active:scale-95 transition-all disabled:opacity-30 disabled:cursor-not-allowed">
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round" className="stroke-gray-800 dark:stroke-white"><polyline points="6 9 12 15 18 9" /></svg>
        </button>
      </div>

      {/* Comments Overlay — identical structure to Ads.jsx */}
      {activeCommentId && (
        <>
          {/* Mobile */}
          <div className="md:hidden fixed inset-0 z-50 bg-black/50 backdrop-blur-sm flex flex-col justify-end">
            <div className="absolute inset-0" onClick={closeComments} />
            <div className="relative w-full bg-white dark:bg-gray-900 rounded-t-2xl flex flex-col shadow-2xl overflow-hidden animate-in slide-in-from-bottom duration-200"
              style={{ height: '72vh', marginBottom: 'max(64px, env(safe-area-inset-bottom, 64px))' }}>
              <CommentsContent comments={comments} replies={replies} expandedComments={expandedComments}
                onToggleReplies={onToggleReplies} loading={loadingComments} replyTo={replyTo}
                commentText={commentText} setCommentText={setCommentText} setReplyTo={setReplyTo}
                handlePostComment={handlePostComment} closeComments={closeComments}
                handleLikeComment={handleLikeComment} handleDeleteComment={handleDeleteComment}
                onLikeReply={handleLikeReply} onDeleteReply={handleDeleteReply}
                currentUserId={currentUserId} currentUserAvatar={currentUserAvatar} currentUserName={currentUserName} />
            </div>
          </div>

          {/* Desktop popup — right of action panel */}
          <div className="hidden md:block fixed z-50"
            style={{ top: '16%', left: `${actionPanelRight}px`, transform: 'translateY(-50%)', animation: 'slideInLeft 0.22s cubic-bezier(0.32,0.72,0,1) forwards' }}>
            <div style={{ position: 'absolute', left: -10, top: '45%', transform: 'translateY(-50%)', width: 0, height: 0, borderTop: '10px solid transparent', borderBottom: '10px solid transparent', borderRight: '10px solid #262626' }} />
            <div className="rounded-2xl shadow-2xl overflow-hidden flex flex-col bg-white dark:bg-[#262626] border border-gray-200 dark:border-white/10"
              style={{ width: 340, height: '78vh', maxHeight: 640 }}>
              <CommentsContent comments={comments} replies={replies} expandedComments={expandedComments}
                onToggleReplies={onToggleReplies} loading={loadingComments} replyTo={replyTo}
                commentText={commentText} setCommentText={setCommentText} setReplyTo={setReplyTo}
                handlePostComment={handlePostComment} closeComments={closeComments}
                handleLikeComment={handleLikeComment} handleDeleteComment={handleDeleteComment}
                onLikeReply={handleLikeReply} onDeleteReply={handleDeleteReply}
                currentUserId={currentUserId} currentUserAvatar={currentUserAvatar} currentUserName={currentUserName} />
            </div>
          </div>
        </>
      )}

      <style>{`
        @keyframes slideInLeft { from { opacity: 0; transform: translateX(-16px); } to { opacity: 1; transform: translateX(0); } }
        .scrollbar-none::-webkit-scrollbar { display: none; }
        .scrollbar-none { -ms-overflow-style: none; scrollbar-width: none; }
      `}</style>
    </div>
  );
};

export default Promote;