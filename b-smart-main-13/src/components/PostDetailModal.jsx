import React, { useState, useEffect, useRef, useCallback } from 'react';
import {
  X, Heart, MessageCircle, Send, Bookmark, MoreHorizontal,
  Smile, ChevronLeft, ChevronRight, Trash2,
  Volume2, VolumeX, UserPlus, UserCheck, ShoppingBag, Loader2
} from 'lucide-react';
import { supabase } from '../lib/supabase';
import { useSelector } from 'react-redux';
import { Link } from 'react-router-dom';
import api from '../lib/api';
import postCommentService from '../services/commentService';
import adCommentService from '../services/commentServiceJS';
import ContentReportModal from './ContentReportModal';
import EditContentModal from './EditContentModal';
import OwnerContentOptionsModal from './OwnerContentOptionsModal';

const BASE_URL = 'https://api.bebsmart.in';

const fmt = (n = 0) => {
  if (n >= 1_000_000) return (n / 1_000_000).toFixed(1) + 'M';
  if (n >= 1_000) return (n / 1_000).toFixed(1) + 'k';
  return String(n);
};

const formatDateRel = (dateString) => {
  if (!dateString) return '';
  const diff = Math.floor((Date.now() - new Date(dateString)) / 1000);
  if (diff < 60) return 'Just now';
  if (diff < 3600) return `${Math.floor(diff / 60)}m`;
  if (diff < 86400) return `${Math.floor(diff / 3600)}h`;
  if (diff < 604800) return `${Math.floor(diff / 86400)}d`;
  return `${Math.floor(diff / 604800)}w`;
};

const formatDateFull = (dateString) => {
  if (!dateString) return '';
  const d = new Date(dateString);
  return isNaN(d.getTime()) ? '' : d.toLocaleDateString('en-US', { month: 'long', day: 'numeric', year: 'numeric' });
};

// ── Is Ad helper ───────────────────────────────────────────────────────────────
const isAdItem = (item) => item?.item_type === 'ad' || !!item?.vendor_id;

// ── Ad auth headers ────────────────────────────────────────────────────────────
const adAuthHeaders = () => {
  const token = localStorage.getItem('token');
  return { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) };
};

// ── Coin Icon ──────────────────────────────────────────────────────────────────
const CoinIcon = ({ size = 13 }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none">
    <circle cx="12" cy="12" r="10" fill="#F59E0B" stroke="#D97706" strokeWidth="1.5" />
    <text x="12" y="16.5" textAnchor="middle" fontSize="11" fontWeight="bold" fill="#7C2D12">B</text>
  </svg>
);

// ── Avatar ─────────────────────────────────────────────────────────────────────
const Avatar = ({ src, username, size = 'md' }) => {
  const dim = size === 'sm' ? 'w-8 h-8 text-xs' : 'w-9 h-9 text-sm';
  return (
    <div className={`${dim} rounded-full bg-gradient-to-tr from-yellow-400 via-orange-500 to-pink-500 p-[1.5px] flex-shrink-0`}>
      <div className="w-full h-full rounded-full bg-white dark:bg-black overflow-hidden flex items-center justify-center">
        {src
          ? <img src={src} alt={username || 'user'} className="w-full h-full object-cover" />
          : <span className="font-bold text-gray-800 dark:text-white">{(username || 'U')[0].toUpperCase()}</span>
        }
      </div>
    </div>
  );
};

// ── Shop CTA ───────────────────────────────────────────────────────────────────
const ShopCTA = ({ offer }) => {
  if (!offer) return null;
  const href = offer.link && !['daasda', '', '#'].includes(offer.link) ? offer.link : '#';
  return (
    <a href={href} target="_blank" rel="noopener noreferrer"
      className="flex items-center justify-between gap-2 w-full mt-2 px-3 py-2.5 rounded-xl bg-gray-50 dark:bg-gray-800 hover:bg-gray-100 dark:hover:bg-gray-700 border border-gray-200 dark:border-gray-700 transition-colors">
      <div className="flex items-center gap-2 min-w-0">
        <ShoppingBag size={16} className="text-gray-600 dark:text-gray-300 shrink-0" />
        <div className="min-w-0">
          <p className="text-sm font-semibold text-gray-900 dark:text-white truncate">{offer.title || 'Shop Now'}</p>
          {offer.description && <p className="text-xs text-gray-500 dark:text-gray-400 truncate">{offer.description}</p>}
        </div>
      </div>
      <div className="flex items-center gap-2 shrink-0">
        {offer.price > 0 && <span className="text-sm font-bold text-amber-600 dark:text-amber-400">₹{offer.price.toLocaleString()}</span>}
        <span className="text-xs font-semibold text-white bg-blue-500 hover:bg-blue-600 rounded-full px-3 py-1">Shop</span>
      </div>
    </a>
  );
};

// ── Follow Button ──────────────────────────────────────────────────────────────
const FollowButton = ({ targetUserId }) => {
  const { userObject } = useSelector(s => s.auth);
  const [following, setFollowing] = useState(false);
  const [loading, setLoading] = useState(false);

  const handleClick = useCallback(async (e) => {
    e.stopPropagation();
    if (!userObject || loading) return;
    const was = following;
    setFollowing(!was);
    setLoading(true);
    try {
      await api.post(was ? '/unfollow' : '/follow', { followedUserId: targetUserId });
    } catch {
      setFollowing(was);
    } finally {
      setLoading(false);
    }
  }, [userObject, loading, following, targetUserId]);

  if (!targetUserId) return null;
  return (
    <button onClick={handleClick} disabled={loading}
      className={`flex items-center gap-1.5 text-xs font-bold px-3 py-1 rounded-full border transition-all ${loading ? 'opacity-50' : ''} ${
        following
          ? 'border-gray-300 dark:border-gray-600 text-gray-500 dark:text-gray-400'
          : 'border-blue-500 text-blue-500 bg-blue-50 dark:bg-blue-500/10'
      }`}>
      {loading ? <Loader2 size={10} className="animate-spin" /> : following ? <UserCheck size={10} /> : <UserPlus size={10} />}
      <span>{following ? 'Following' : 'Follow'}</span>
    </button>
  );
};

// ── Delete Modal ───────────────────────────────────────────────────────────────
const DeleteModal = ({ isOpen, onClose, onConfirm, isDeleting }) => {
  if (!isOpen) return null;
  return (
    <div className="fixed inset-0 z-[60] flex items-center justify-center bg-black/50 backdrop-blur-sm p-4">
      <div className="bg-white dark:bg-gray-900 rounded-xl p-6 w-full max-w-sm shadow-2xl border border-gray-100 dark:border-gray-800">
        {isDeleting ? (
          <div className="flex flex-col items-center py-8">
            <div className="animate-spin w-12 h-12 border-4 border-gray-200 border-t-red-500 rounded-full mb-4" />
            <p className="text-gray-500 font-medium animate-pulse">Deleting post...</p>
          </div>
        ) : (
          <>
            <h3 className="text-lg font-bold text-gray-900 dark:text-white mb-2 text-center">Delete Post?</h3>
            <p className="text-gray-500 dark:text-gray-400 text-sm mb-6 text-center">This action cannot be undone.</p>
            <div className="flex gap-3">
              <button onClick={onClose} className="flex-1 px-4 py-2.5 rounded-lg border border-gray-200 dark:border-gray-700 font-medium text-gray-700 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors">Cancel</button>
              <button onClick={onConfirm} className="flex-1 px-4 py-2.5 rounded-lg bg-red-500 text-white font-medium hover:bg-red-600 transition-colors">Delete</button>
            </div>
          </>
        )}
      </div>
    </div>
  );
};

// ── People Tags Overlay ────────────────────────────────────────────────────────
const PeopleTagsOverlay = ({ tags }) => {
  const [showTags, setShowTags] = useState(false);
  useEffect(() => {
    if (tags?.length > 0) {
      const s = setTimeout(() => setShowTags(true), 0);
      const h = setTimeout(() => setShowTags(false), 2600);
      return () => { clearTimeout(s); clearTimeout(h); };
    }
  }, [tags]);
  if (!tags?.length) return null;
  return (
    <>
      <style>{`@keyframes igTagPop{0%{opacity:0;transform:translate(-50%,-50%) scale(.5)}70%{transform:translate(-50%,-50%) scale(1.08)}100%{opacity:1;transform:translate(-50%,-50%) scale(1)}}`}</style>
      <button className="absolute bottom-3 left-3 z-20 w-9 h-9 rounded-full bg-black/55 flex items-center justify-center hover:bg-black/75 transition-all"
        onClick={(e) => { e.stopPropagation(); setShowTags(s => !s); }}>
        <svg width="18" height="18" viewBox="0 0 24 24" fill="white"><path d="M12 12c2.7 0 4.8-2.1 4.8-4.8S14.7 2.4 12 2.4 7.2 4.5 7.2 7.2 9.3 12 12 12zm0 2.4c-3.2 0-9.6 1.6-9.6 4.8v2.4h19.2v-2.4c0-3.2-6.4-4.8-9.6-4.8z" /></svg>
      </button>
      {showTags && tags.map((tag, idx) => {
        const x = Math.min(88, Math.max(12, tag.x));
        const y = Math.min(88, Math.max(12, tag.y));
        const inBottom = y > 55;
        
        const profilePath = tag.role === 'vendor' 
          ? `/vendor/${tag.user_id || ''}/public` 
          : `/profile/${tag.user_id || ''}`;

        return (
          <div key={tag._id || idx} className="absolute z-30 pointer-events-auto"
            style={{ left: `${x}%`, top: `${y}%`, transform: 'translate(-50%,-50%)', animation: `igTagPop 0.28s ${idx * 0.07}s cubic-bezier(0.34,1.56,0.64,1) both` }}>
            <div className="flex flex-col items-center">
              {!inBottom && <div className="w-0 h-0 border-l-[6px] border-l-transparent border-r-[6px] border-r-transparent border-b-[6px] border-b-white/90 -mb-px" />}
              <Link to={profilePath} onClick={e => e.stopPropagation()}
                className="block bg-white/90 text-black text-xs font-bold px-3 py-1.5 rounded-full whitespace-nowrap shadow-xl hover:bg-white">
                @{tag.username}
              </Link>
              {inBottom && <div className="w-0 h-0 border-l-[6px] border-l-transparent border-r-[6px] border-r-transparent border-t-[6px] border-t-white/90 -mt-px" />}
            </div>
          </div>
        );
      })}
    </>
  );
};

// ── Reply Row ──────────────────────────────────────────────────────────────────
const ReplyRow = ({ reply, onLike, onDelete, onReply, currentUserId }) => {
  const user = reply.user || reply.users || (typeof reply.user_id === 'object' ? reply.user_id : {});
  const rId = reply._id || reply.id;
  const isLiked = reply.is_liked_by_me || false;
  const likesCount = reply.likes_count ?? 0;
  const isOwner = currentUserId && (
    String(user._id || user.id || '') === String(currentUserId) ||
    String(reply.user_id || '') === String(currentUserId)
  );
  return (
    <div className="flex gap-2.5 py-2 group/reply">
      <Avatar src={user.avatar_url} username={user.username} size="sm" />
      <div className="flex-1 min-w-0">
        <div className="flex items-start justify-between gap-2">
          <div className="flex-1 min-w-0">
            <span className="font-semibold text-gray-900 dark:text-white text-xs mr-1.5">{user.username || user.full_name || 'User'}</span>
            <span className="text-gray-700 dark:text-gray-300 text-xs break-words">{reply.text || reply.content}</span>
          </div>
          <button onClick={() => onLike(rId, isLiked)} className="flex flex-col items-center gap-0.5 flex-shrink-0 pt-0.5">
            <Heart size={12} className={isLiked ? 'text-red-500' : 'text-gray-400 hover:text-gray-600'} fill={isLiked ? 'currentColor' : 'none'} />
            {likesCount > 0 && <span className={`text-[9px] ${isLiked ? 'text-red-400' : 'text-gray-400'}`}>{likesCount}</span>}
          </button>
        </div>
        <div className="flex items-center gap-3 mt-1">
          <span className="text-gray-400 text-[11px]">{formatDateRel(reply.createdAt || reply.created_at)}</span>
          {likesCount > 0 && <span className="text-gray-400 text-[11px]">{likesCount} likes</span>}
          <button onClick={() => onReply({ id: rId, username: user.username || user.full_name })}
            className="text-gray-500 text-[11px] font-semibold hover:text-gray-800 dark:hover:text-white transition-colors">Reply</button>
          {isOwner && (
            <button onClick={() => onDelete(rId)} className="text-gray-400 hover:text-red-500 transition-colors opacity-0 group-hover/reply:opacity-100 ml-auto">
              <Trash2 size={11} />
            </button>
          )}
        </div>
      </div>
    </div>
  );
};

// ── Comment Row ────────────────────────────────────────────────────────────────
const CommentRow = ({ comment, replies, expanded, onToggleReplies, onReply, onLike, onDelete, onLikeReply, onDeleteReply, currentUserId }) => {
  const cId = comment._id || comment.id;
  const user = comment.user || comment.users || (typeof comment.user_id === 'object' ? comment.user_id : {});
  const isLiked = comment.is_liked_by_me || false;
  const likesCount = comment.likes_count ?? (Array.isArray(comment.likes) ? comment.likes.length : 0);
  const currentReplies = replies[cId] || [];
  const replyCount = currentReplies.length > 0 ? currentReplies.length : (comment.reply_count || 0);
  const hasReplies = replyCount > 0;
  const isOwner = currentUserId && (
    String(user._id || user.id || '') === String(currentUserId) ||
    String(comment.user_id || '') === String(currentUserId)
  );
  return (
    <div className="group/comment border-b border-gray-100 dark:border-white/5 last:border-b-0">
      <div className="flex gap-3 py-3">
        <Avatar src={user.avatar_url} username={user.username} size="sm" />
        <div className="flex-1 min-w-0">
          <div className="flex items-start justify-between gap-2">
            <div className="flex-1 min-w-0">
              <span className="font-semibold text-gray-900 dark:text-white text-sm mr-2">{user.username || user.full_name || 'User'}</span>
              <span className="text-gray-700 dark:text-gray-300 text-sm break-words leading-snug">{comment.text || comment.content}</span>
            </div>
            <button onClick={() => onLike(cId, isLiked)} className="flex flex-col items-center gap-0.5 flex-shrink-0 pt-0.5">
              <Heart size={14} className={isLiked ? 'text-red-500' : 'text-gray-400 hover:text-gray-600'} fill={isLiked ? 'currentColor' : 'none'} />
              {likesCount > 0 && <span className={`text-[10px] ${isLiked ? 'text-red-400' : 'text-gray-400'}`}>{likesCount}</span>}
            </button>
          </div>
          <div className="flex items-center gap-3 mt-1.5">
            <span className="text-gray-400 text-xs">{formatDateRel(comment.createdAt || comment.created_at)}</span>
            {likesCount > 0 && <span className="text-gray-400 text-xs">{fmt(likesCount)} likes</span>}
            <button onClick={() => onReply({ id: cId, rootCommentId: cId, username: user.username || user.full_name })}
              className="text-gray-500 dark:text-gray-400 text-xs font-semibold hover:text-gray-800 dark:hover:text-white transition-colors">Reply</button>
            {isOwner && (
              <button onClick={() => onDelete(cId)} className="text-gray-400 hover:text-red-500 transition-colors opacity-0 group-hover/comment:opacity-100 ml-auto">
                <Trash2 size={12} />
              </button>
            )}
          </div>
          {hasReplies && (
            <button onClick={() => onToggleReplies(cId)} className="flex items-center gap-2 mt-2 text-xs text-gray-500 dark:text-gray-400 hover:text-gray-800 dark:hover:text-white transition-colors">
              <div className="w-5 h-px bg-gray-300 dark:bg-gray-600" />
              <span className="font-semibold">{expanded ? 'Hide replies' : `View ${replyCount} ${replyCount === 1 ? 'reply' : 'replies'}`}</span>
            </button>
          )}
        </div>
      </div>
      {expanded && (
        <div className="ml-[52px] pr-4 mb-2 border-l border-gray-200 dark:border-white/10 pl-3">
          {currentReplies.length === 0 ? (
            <div className="flex items-center gap-2 py-2">
              <Loader2 size={12} className="animate-spin text-gray-400" />
              <span className="text-gray-400 text-xs italic">Loading replies...</span>
            </div>
          ) : (
            currentReplies.map(reply => (
              <ReplyRow key={reply._id || reply.id} reply={reply}
                onLike={onLikeReply} onDelete={onDeleteReply}
                onReply={(u) => onReply({ id: reply._id || reply.id, rootCommentId: cId, username: u.username })}
                currentUserId={currentUserId} />
            ))
          )}
        </div>
      )}
    </div>
  );
};

// ── Media Panel (left side of modal) ──────────────────────────────────────────
const ModalMediaPanel = ({ post, isAd }) => {
  const mediaItems = post.media?.length > 0 ? post.media : (post.imageUrl ? [{ fileUrl: post.imageUrl }] : []);
  const [currentIndex, setCurrentIndex] = useState(0);
  const [isPlaying, setIsPlaying] = useState(false);
  const [isMuted, setIsMuted] = useState(true);
  const videoRef = useRef(null);

  useEffect(() => { if (videoRef.current) videoRef.current.muted = isMuted; }, [isMuted]);

  const currentItem = mediaItems[currentIndex] || {};
  const isVideo = currentItem.type === 'video' || currentItem.media_type === 'video';

  const getThumbnailUrl = (item) => {
    if (!item) return null;
    if (Array.isArray(item.thumbnails) && item.thumbnails[0]?.fileUrl) return item.thumbnails[0].fileUrl;
    if (Array.isArray(item.thumbnail) && item.thumbnail[0]?.fileUrl) return item.thumbnail[0].fileUrl;
    if (typeof item.thumbnail === 'string') return item.thumbnail;
    return null;
  };

  const getVideoTiming = (item) => {
    const n = v => (typeof v === 'number' && isFinite(v)) ? v : (parseFloat(v) || 0);
    if (item?.video_meta || item?.timing_window) {
      const meta = item.video_meta || {};
      const tw = item.timing_window || {};
      return { start: n(meta.selected_start ?? tw.start ?? 0), end: n(meta.selected_end ?? tw.end ?? 0) };
    }
    const t = item?.timing || {};
    let s = n(t.start ?? 0), e = n(t.end ?? 0);
    const dur = n(item?.videoLength ?? 0);
    if (s < 0) s = 0;
    if (!e && dur > 0) e = dur;
    if (dur > 0 && e > dur) e = dur;
    if (e > 0 && e <= s) e = 0;
    return { start: s, end: e };
  };

  const thumbnailUrl = getThumbnailUrl(currentItem);
  const { start: trimStart, end: trimEnd } = getVideoTiming(currentItem);
  const peopleTags = post.people_tags || [];

  const nextMedia = (e) => { e.stopPropagation(); setCurrentIndex(i => (i + 1) % mediaItems.length); setIsPlaying(false); };
  const prevMedia = (e) => { e.stopPropagation(); setCurrentIndex(i => (i - 1 + mediaItems.length) % mediaItems.length); setIsPlaying(false); };

  if (!mediaItems.length) return (
    <div className="w-full h-full flex items-center justify-center bg-gradient-to-br from-purple-900 to-pink-900">
      <div className="text-center px-8">
        <div className="text-6xl mb-4">🛍️</div>
        <p className="text-white font-bold text-xl">{post.vendor_id?.business_name || 'Sponsored'}</p>
        {post.category && <p className="text-white/70 text-sm mt-1">{post.category}</p>}
      </div>
    </div>
  );

  return (
    <div className="relative w-full h-full bg-black flex items-center justify-center group">
      {/* AD badge */}
      {isAd && (
        <div className="absolute top-3 left-3 z-30">
          <span className="bg-black/60 text-white text-[10px] font-bold px-2 py-1 rounded-full">AD</span>
        </div>
      )}

      {isVideo ? (
        <div className="relative w-full h-full flex items-center justify-center">
          {thumbnailUrl && !isPlaying && (
            <img src={thumbnailUrl} alt="thumbnail" className="absolute inset-0 w-full h-full object-contain" />
          )}
          <video
            ref={videoRef}
            src={currentItem.fileUrl || currentItem.url}
            className="w-full h-full object-contain"
            autoPlay muted={isMuted} playsInline
            data-start={trimStart} data-end={trimEnd}
            onPlay={() => setIsPlaying(true)}
            onPause={() => setIsPlaying(false)}
            onEnded={() => setIsPlaying(false)}
            onLoadedMetadata={(e) => {
              const s = Number(e.currentTarget.dataset.start || 0);
              if (s > 0 && isFinite(s)) e.currentTarget.currentTime = s;
            }}
            onTimeUpdate={(e) => {
              const v = e.currentTarget;
              const s = Number(v.dataset.start || 0);
              const eVal = Number(v.dataset.end || 0);
              if (eVal > 0 && isFinite(eVal) && v.currentTime > eVal) {
                v.currentTime = s > 0 && isFinite(s) ? s : 0;
                v.pause();
              }
            }}
            onClick={(e) => { e.stopPropagation(); videoRef.current?.paused ? videoRef.current.play() : videoRef.current?.pause(); }}
          />
          {!isPlaying && (
            <div className="absolute inset-0 z-10 flex items-center justify-center pointer-events-none">
              <div className="w-16 h-16 rounded-full bg-black/40 flex items-center justify-center">
                <svg className="w-8 h-8 text-white ml-1" fill="currentColor" viewBox="0 0 24 24"><path d="M8 5v14l11-7z" /></svg>
              </div>
            </div>
          )}
          <button onClick={(e) => { e.stopPropagation(); setIsMuted(m => !m); }}
            className="absolute bottom-3 right-3 z-20 w-9 h-9 rounded-full bg-black/60 hover:bg-black/80 text-white flex items-center justify-center transition-all">
            {isMuted ? <VolumeX size={16} /> : <Volume2 size={16} />}
          </button>
          <PeopleTagsOverlay tags={peopleTags} />
        </div>
      ) : (
        <div className="relative w-full h-full flex items-center justify-center">
          <img
            src={currentItem.fileUrl || currentItem.url || currentItem.image}
            alt="Content"
            className="w-full h-full object-contain"
            style={currentItem.image_editing?.filter?.css ? { filter: currentItem.image_editing.filter.css } : {}}
          />
          <PeopleTagsOverlay tags={peopleTags} />
        </div>
      )}

      {/* Carousel arrows */}
      {mediaItems.length > 1 && (
        <>
          <button onClick={prevMedia} className="absolute left-4 top-1/2 -translate-y-1/2 bg-black/50 hover:bg-black/70 text-white p-2 rounded-full opacity-0 group-hover:opacity-100 transition-opacity z-20">
            <ChevronLeft size={24} />
          </button>
          <button onClick={nextMedia} className="absolute right-4 top-1/2 -translate-y-1/2 bg-black/50 hover:bg-black/70 text-white p-2 rounded-full opacity-0 group-hover:opacity-100 transition-opacity z-20">
            <ChevronRight size={24} />
          </button>
          <div className="absolute bottom-4 left-1/2 -translate-x-1/2 flex gap-1.5 z-10">
            {mediaItems.map((_, idx) => (
              <div key={idx} className={`w-2 h-2 rounded-full transition-all duration-300 ${idx === currentIndex ? 'bg-white scale-110' : 'bg-white/50'}`} />
            ))}
          </div>
        </>
      )}
    </div>
  );
};

// ── Main Modal Component ───────────────────────────────────────────────────────
const PostDetailModal = ({ post: initialPost, isOpen, onClose }) => {
  const { userObject } = useSelector(s => s.auth);
  const [post, setPost] = useState(initialPost);
  const isAd = isAdItem(initialPost);

  // Pick the right comment service based on type
  const cs = isAd ? adCommentService : postCommentService;

  // Author info
  const user = post?.user_id || post?.users || post?.user || {};
  const vendor = post?.vendor_id || {};
  const username = user.username || vendor.business_name || post?.username || 'User';
  const fullName = (vendor.business_name && vendor.business_name !== username) ? vendor.business_name : (user.full_name || '');
  const avatar = user.avatar_url || post?.userAvatar || '';
  const userId = user._id || user.id || (typeof post?.user_id === 'string' ? post.user_id : null);
  const postId = post?._id || post?.id;

  const currentUserId = userObject?._id || userObject?.id || null;
  const isPostOwner = !isAd && currentUserId && userId && String(currentUserId) === String(userId);

  // Like/save state
  const [isLiked, setIsLiked] = useState(false);
  const [likeCount, setLikeCount] = useState(0);
  const [isDisliked, setIsDisliked] = useState(false);
  const [isSaved, setIsSaved] = useState(false);

  // Comments
  const [comments, setComments] = useState([]);
  const [replies, setReplies] = useState({});
  const [expandedComments, setExpandedComments] = useState({});
  const [replyTo, setReplyTo] = useState(null);
  const [newComment, setNewComment] = useState('');
  const [loadingComments, setLoadingComments] = useState(false);

  // Post options
  const [showOptions, setShowOptions] = useState(false);
  const [showDeleteModal, setShowDeleteModal] = useState(false);
  const [showEditModal, setShowEditModal] = useState(false);
  const [isDeleting, setIsDeleting] = useState(false);
  const [showReportModal, setShowReportModal] = useState(false);

  // ── Init on open ────────────────────────────────────────────────────────────


  // ── Comments ────────────────────────────────────────────────────────────────
  const loadReplies = useCallback(async (commentId) => {
    try {
      const data = await cs.getReplies(commentId);
      const fetched = Array.isArray(data) ? data : (data.replies || data.data || []);
      setReplies(prev => ({ ...prev, [commentId]: fetched }));
    } catch (e) { console.error('Load replies:', e); }
  }, [cs]);



  const fetchComments = useCallback(async (id) => {
    if (!id) return;
    setLoadingComments(true);
    try {
      const data = await cs.getComments(id);
      const list = Array.isArray(data) ? data : (data.comments || data.data || []);
      setComments(list);
      list.forEach(comment => {
        const cId = comment._id || comment.id;
        cs.getReplies(cId)
          .then(rData => {
            const fetched = Array.isArray(rData) ? rData : (rData.replies || rData.data || []);
            if (fetched?.length > 0) setReplies(prev => ({ ...prev, [cId]: fetched }));
          })
          .catch(() => {});
      });
    } catch (e) { console.error('Fetch comments:', e); }
    finally { setLoadingComments(false); }
  }, [cs]);

  useEffect(() => {
    if (isOpen && initialPost) {
      setPost(initialPost);
      setNewComment('');
      setReplyTo(null);
      setReplies({});
      setExpandedComments({});
      setShowOptions(false);

      // Set likes
      if (typeof initialPost.is_liked_by_me !== 'undefined') {
        setIsLiked(initialPost.is_liked_by_me);
        setLikeCount(initialPost.likes_count || 0);
      } else if (Array.isArray(initialPost.likes)) {
        const myId = currentUserId;
        setIsLiked(myId ? initialPost.likes.some(l =>
          typeof l === 'string' ? String(l) === String(myId) : String(l.user_id || l._id || l.id) === String(myId)
        ) : false);
        setLikeCount(initialPost.likes.length);
      }
      setIsDisliked(false);
      setIsSaved(initialPost.is_saved_by_me || false);

      // Fetch fresh post data (posts only) + comments
      if (!isAd && initialPost._id) {
        api.get(`/posts/${initialPost._id}`)
          .then(({ data }) => { setPost(data); })
          .catch(() => {});
      }
      fetchComments(initialPost._id || initialPost.id);
    }
  }, [isOpen, initialPost, currentUserId, isAd, fetchComments]);

  const handlePostComment = async (e) => {
    e?.preventDefault();
    if (!newComment.trim() || !postId) return;
    const text = newComment.trim();
    const replyInfo = replyTo;
    setNewComment('');
    setReplyTo(null);
    try {
      await cs.createComment(postId, text, replyInfo?.id || null);
      if (replyInfo) {
        await loadReplies(replyInfo.rootCommentId || replyInfo.id);
        setExpandedComments(prev => ({ ...prev, [replyInfo.rootCommentId || replyInfo.id]: true }));
      } else {
        await fetchComments(postId);
        setPost(prev => ({ ...prev, comments_count: (prev.comments_count || 0) + 1 }));
      }
    } catch (e) {
      console.error('Post comment:', e);
      setNewComment(text);
      if (replyInfo) setReplyTo(replyInfo);
    }
  };

  const handleLikeComment = async (commentId, isLikedArg) => {
    try {
      isLikedArg ? await cs.unlikeComment(commentId) : await cs.likeComment(commentId);
      fetchComments(postId);
      Object.keys(replies).forEach(key => loadReplies(key));
    } catch (e) { console.error(e); }
  };

  const handleLikeReply = async (replyId, isLikedArg) => {
    try {
      isLikedArg ? await cs.unlikeComment(replyId) : await cs.likeComment(replyId);
      Object.keys(replies).forEach(key => loadReplies(key));
    } catch (e) { console.error(e); }
  };

  const handleDeleteComment = async (commentId) => {
    if (!window.confirm('Delete this comment?')) return;
    try {
      if (isAd) {
        await adCommentService.deleteComment(commentId);
      } else {
        await api.delete(`/comments/${commentId}`);
      }
      setComments(prev => prev.filter(c => (c._id || c.id) !== commentId));
      setPost(prev => ({ ...prev, comments_count: Math.max(0, (prev.comments_count || 1) - 1) }));
    } catch (e) { console.error(e); }
  };

  const handleDeleteReply = async (replyId) => {
    if (!window.confirm('Delete this reply?')) return;
    try {
      if (isAd) {
        await adCommentService.deleteComment(replyId);
      } else {
        await api.delete(`/comments/${replyId}`);
      }
      Object.keys(replies).forEach(key => loadReplies(key));
    } catch (e) { console.error(e); }
  };

  const onToggleReplies = (commentId) => {
    const isExpanded = expandedComments[commentId];
    if (!isExpanded && (!replies[commentId] || replies[commentId].length === 0)) {
      loadReplies(commentId);
    }
    setExpandedComments(prev => ({ ...prev, [commentId]: !prev[commentId] }));
  };

  // ── Like / Dislike post ─────────────────────────────────────────────────────
  const handleLike = async () => {
    if (!userObject) return;
    const wasLiked = isLiked;
    const wasDisliked = isDisliked;
    setIsLiked(!wasLiked);
    setLikeCount(c => !wasLiked ? c + 1 : Math.max(0, c - 1));
    if (!wasLiked && wasDisliked) setIsDisliked(false);
    try {
      if (isAd) {
        const ep = wasLiked ? `/api/ads/${postId}/dislike` : `/api/ads/${postId}/like`;
        await fetch(`${BASE_URL}${ep}`, { method: 'POST', headers: adAuthHeaders(), body: JSON.stringify({ user: { id: String(currentUserId || '') } }) });
      } else if (post._id) {
        await api.post(`/posts/${postId}/${wasLiked ? 'unlike' : 'like'}`);
      } else {
        const likes = post.likes || [];
        const updated = wasLiked ? likes.filter(l => l.user_id !== userObject.id) : [...likes, { user_id: userObject.id }];
        await supabase.from('posts').update({ likes: updated }).eq('id', post.id);
        setPost(prev => ({ ...prev, likes: updated, is_liked_by_me: !wasLiked }));
      }
    } catch {
      setIsLiked(wasLiked);
      setLikeCount(c => wasLiked ? c + 1 : Math.max(0, c - 1));
      if (!wasLiked && wasDisliked) setIsDisliked(wasDisliked);
    }
  };

  // ── Delete post ─────────────────────────────────────────────────────────────
  const handleDeletePost = async () => {
    setIsDeleting(true);
    try {
      await api.delete(isAd ? `/ads/${postId}` : `/posts/${postId}`);
      await new Promise(r => setTimeout(r, 1000));
      onClose();
      window.location.reload();
    } catch {
      alert('Failed to delete post');
      setIsDeleting(false);
      setShowDeleteModal(false);
    }
  };

  if (!isOpen || !post) return null;

  const offer = isAd ? (post.product_offer?.[0] || null) : null;
  const reportContentType = isAd ? 'ad' : (post.type === 'reel' ? 'reel' : 'post');
  const reportContentUrl = isAd
    ? `${window.location.origin}/ads`
    : post.type === 'reel'
      ? `${window.location.origin}/reels/${postId}`
      : `${window.location.origin}/posts/${postId}`;

  const profilePath = isAd ? `/vendor/${userId}/public` : `/profile/${userId}`;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4 md:p-10">
      <button onClick={onClose} className="absolute top-4 right-4 text-white hover:opacity-75 z-[60]">
        <X size={24} />
      </button>

      <div className="bg-white dark:bg-black max-w-[90vw] md:max-w-[1200px] w-full max-h-[90vh] h-full md:h-[85vh] flex flex-col md:flex-row overflow-hidden rounded-md md:rounded-r-xl animate-in fade-in zoom-in duration-200">

        {/* ── Left: Media ──────────────────────────────────────────────────── */}
        <div className="w-full md:w-[55%] h-[42vh] md:h-full">
          <ModalMediaPanel post={post} isAd={isAd} />
        </div>

        {/* ── Right: Details ───────────────────────────────────────────────── */}
        <div className="flex flex-col w-full md:w-[45%] h-full bg-white dark:bg-black">

          {/* Header */}
          <div className="flex items-center justify-between p-3 md:p-4 border-b border-gray-100 dark:border-gray-800 shrink-0">
            <div className="flex items-center gap-3 min-w-0">
              <Link to={profilePath}>
                <Avatar src={avatar} username={username} />
              </Link>
              <div className="min-w-0">
                <div className="flex items-center gap-2 flex-wrap">
                  <Link to={profilePath} className="font-semibold text-sm text-gray-900 dark:text-white hover:opacity-70 truncate">
                    {username}
                  </Link>
                  {isAd && <span className="text-[10px] text-gray-400">Sponsored</span>}
                </div>
                {fullName && fullName !== username && (
                  <p className="text-xs text-gray-500 truncate">{fullName}</p>
                )}
                {!isAd && post.location && <p className="text-xs text-gray-400">{post.location}</p>}
                {isAd && post.location && <p className="text-xs text-gray-400">{post.location}</p>}
              </div>
            </div>

            <div className="flex items-center gap-2 shrink-0">
              <button
                onClick={() => {
                  if (isPostOwner) {
                    setShowOptions(true);
                    return;
                  }
                  setShowReportModal(true);
                }}
                className="text-gray-900 dark:text-white hover:opacity-50 p-1 rounded-full hover:bg-gray-100 dark:hover:bg-gray-800 transition-colors"
              >
                <MoreHorizontal size={20} />
              </button>
            </div>
          </div>

          <DeleteModal isOpen={showDeleteModal} onClose={() => setShowDeleteModal(false)} onConfirm={handleDeletePost} isDeleting={isDeleting} />
          <OwnerContentOptionsModal
            isOpen={showOptions && isPostOwner}
            onClose={() => setShowOptions(false)}
            item={post}
            contentType={isAd ? 'ad' : (post.type === 'reel' ? 'reel' : 'post')}
            contentUrl={reportContentUrl}
            onEdit={() => {
              setShowOptions(false);
              setShowEditModal(true);
            }}
            onDelete={() => {
              setShowOptions(false);
              setShowDeleteModal(true);
            }}
            onUpdated={(updated) => setPost(updated)}
          />
          <EditContentModal
            isOpen={showEditModal}
            onClose={() => setShowEditModal(false)}
            item={post}
            contentType={isAd ? 'ad' : (post.type === 'reel' ? 'reel' : 'post')}
            onSaved={(updated) => setPost(updated)}
          />
          <ContentReportModal
            isOpen={showReportModal}
            onClose={() => setShowReportModal(false)}
            contentType={reportContentType}
            contentId={postId}
            ownerUsername={username}
            contentUrl={reportContentUrl}
          />

          {/* Scrollable: post info + comments */}
          <div className="flex-1 overflow-y-auto p-3 md:p-4 scrollbar-hide">

            {/* Caption block */}
            <div className="flex gap-3 mb-4">
              <Link to={profilePath}>
                <Avatar src={avatar} username={username} size="sm" />
              </Link>
              <div className="flex-1 text-sm">
                <Link to={profilePath} className="font-semibold mr-2 dark:text-white hover:underline">{username}</Link>
                {post.caption ? (
                  <span className="text-gray-900 dark:text-gray-100 whitespace-pre-wrap">{post.caption}</span>
                ) : (
                  <span className="text-gray-400 italic text-xs">No caption</span>
                )}
                <div className="text-gray-400 text-xs mt-1">{formatDateRel(post.createdAt || post.created_at)}</div>
              </div>
            </div>

            {/* Ad: extra info */}
            {isAd && (
              <div className="mb-4 pb-4 border-b border-gray-100 dark:border-gray-800">
                {/* Category + budget */}
                <div className="flex items-center gap-2 flex-wrap mb-2">
                  {post.category && (
                    <span className="text-[10px] font-semibold text-blue-600 dark:text-blue-400 bg-blue-50 dark:bg-blue-500/10 border border-blue-100 dark:border-blue-500/20 rounded-full px-2 py-0.5">
                      {post.category}
                    </span>
                  )}
                  {post.total_budget_coins > 0 && (
                    <div className="flex items-center gap-1 bg-amber-50 dark:bg-amber-500/10 border border-amber-200 dark:border-amber-500/30 rounded-full px-2 py-0.5">
                      <CoinIcon size={11} />
                      <span className="text-amber-600 dark:text-amber-400 text-[10px] font-bold">{fmt(post.total_budget_coins)} coins budget</span>
                    </div>
                  )}
                </div>

                {/* Hashtags */}
                {post.hashtags?.length > 0 && (
                  <div className="flex flex-wrap gap-1.5 mb-2">
                    {post.hashtags.map((h, i) => <span key={i} className="text-sm text-blue-500">#{h}</span>)}
                  </div>
                )}

                {/* Shop CTA */}
                {offer && <ShopCTA offer={offer} />}

                {/* Stats */}
                {(post.views_count > 0 || post.unique_views_count > 0) && (
                  <div className="flex items-center gap-4 mt-3 text-xs text-gray-400">
                    {post.views_count > 0 && <span>{fmt(post.views_count)} views</span>}
                    {post.unique_views_count > 0 && <span>{fmt(post.unique_views_count)} unique</span>}
                    {post.completed_views_count > 0 && <span>{fmt(post.completed_views_count)} completed</span>}
                  </div>
                )}

                {/* Target */}
                {(post.target_location?.length > 0 || post.target_language?.length > 0) && (
                  <div className="mt-2 text-[11px] text-gray-400 space-y-0.5">
                    {post.target_location?.length > 0 && <p>📍 {post.target_location.join(', ')}</p>}
                    {post.target_language?.length > 0 && <p>🌐 {post.target_language.join(', ')}</p>}
                  </div>
                )}
              </div>
            )}

            {/* Comments */}
            {loadingComments ? (
              <div className="flex justify-center py-4">
                <Loader2 size={24} className="animate-spin text-gray-400" />
              </div>
            ) : comments.length > 0 ? (
              comments.map(comment => (
                <CommentRow
                  key={comment._id || comment.id}
                  comment={comment}
                  replies={replies}
                  expanded={expandedComments[comment._id || comment.id]}
                  onToggleReplies={onToggleReplies}
                  onReply={(u) => setReplyTo({ id: comment._id || comment.id, rootCommentId: comment._id || comment.id, username: u.username })}
                  onLike={handleLikeComment}
                  onDelete={handleDeleteComment}
                  onLikeReply={handleLikeReply}
                  onDeleteReply={handleDeleteReply}
                  currentUserId={currentUserId}
                />
              ))
            ) : (
              <div className="flex flex-col items-center justify-center py-8 text-gray-400 text-sm">
                <MessageCircle size={32} className="mb-2 opacity-40" />
                <p>No comments yet. Be the first!</p>
              </div>
            )}
          </div>

          {/* Footer: actions + comment input */}
          <div className="border-t border-gray-100 dark:border-gray-800 bg-white dark:bg-black shrink-0">
            <div className="p-3 md:p-4 pb-2">
              <div className="flex justify-between mb-2">
                <div className="flex gap-4">
                  <button onClick={handleLike} className="hover:opacity-50 transition-opacity active:scale-90">
                    <Heart size={24} className={isLiked ? 'fill-red-500 text-red-500' : 'text-gray-900 dark:text-white'} />
                  </button>
                  <button className="hover:opacity-50 transition-opacity">
                    <MessageCircle size={24} className="text-gray-900 dark:text-white" />
                  </button>
                  <button className="hover:opacity-50 transition-opacity">
                    <Send size={24} className="text-gray-900 dark:text-white" />
                  </button>
                </div>
                <div className="flex items-center gap-3">
                  {/* Follow — beside save for both ads and non-owner posts */}
                  {!isPostOwner && userId && userObject && (
                    <FollowButton targetUserId={String(userId)} />
                  )}
                  <button onClick={() => setIsSaved(s => !s)} className="hover:opacity-50 transition-opacity active:scale-90">
                    <Bookmark size={24} className={isSaved ? 'fill-black text-black dark:fill-white dark:text-white' : 'text-gray-900 dark:text-white'} />
                  </button>
                </div>
              </div>

              {/* Like count */}
              {!post.engagement_controls?.hide_likes_count && (
                <div className="font-semibold text-sm text-gray-900 dark:text-white mb-1">{fmt(likeCount)} likes</div>
              )}
              <div className="text-[10px] text-gray-400 uppercase tracking-wide">{formatDateFull(post.createdAt || post.created_at)}</div>
            </div>

            {/* Reply banner */}
            {replyTo && (
              <div className="px-3 md:px-4 py-2 bg-gray-50 dark:bg-gray-900 flex justify-between items-center text-xs text-gray-500 dark:text-gray-400">
                <span>Replying to <span className="font-semibold text-blue-500">@{replyTo.username}</span></span>
                <button onClick={() => setReplyTo(null)}><X size={14} /></button>
              </div>
            )}

            {/* Comment input */}
            <form onSubmit={handlePostComment} className="border-t border-gray-100 dark:border-gray-800 p-3 md:p-4 flex items-center gap-3">
              <button type="button" className="text-gray-900 dark:text-white hover:opacity-50 shrink-0">
                <Smile size={24} />
              </button>
              <input
                type="text"
                placeholder={replyTo ? `Reply to @${replyTo.username}...` : 'Add a comment...'}
                className="flex-1 text-sm outline-none text-gray-900 dark:text-white bg-transparent placeholder-gray-400 dark:placeholder-gray-500"
                value={newComment}
                onChange={e => setNewComment(e.target.value)}
              />
              <button type="submit" disabled={!newComment.trim()}
                className={`text-blue-500 font-semibold text-sm shrink-0 ${!newComment.trim() ? 'opacity-40' : 'hover:text-blue-700'}`}>
                Post
              </button>
            </form>
          </div>
        </div>
      </div>
    </div>
  );
};

export default PostDetailModal;


