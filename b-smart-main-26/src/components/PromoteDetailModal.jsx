import { useState, useEffect, useRef, useCallback } from 'react';
import EmojiPicker from 'emoji-picker-react';
import {
  X, Heart, MessageCircle, Send, MoreHorizontal,
  Smile, ChevronLeft, ChevronRight, Trash2,
  Volume2, VolumeX, UserPlus, UserCheck, ShoppingBag,
  Loader2, Zap, Bookmark
} from 'lucide-react';
import { useSelector } from 'react-redux';
import { Link } from 'react-router-dom';
import api from '../lib/api';
import {
  checkFollowStatus, followUser, unfollowUser, cancelFollowRequest,
  FOLLOW_STATUS_CHANGED_EVENT, normalizeFollowStateFromStatus,
} from '../services/followService';
import promoteReelService from '../services/promoteReelService';
import Avatar from './Avatar';
import LocationLink from './LocationLink';
import ShareContentModal from './ShareContentModal';
import ContentReportModal from './ContentReportModal';

const BASE_URL = 'https://api.bebsmart.in';

const fmt = (n = 0) => {
  if (n >= 1_000_000) return (n / 1_000_000).toFixed(1) + 'M';
  if (n >= 1_000) return (n / 1_000).toFixed(1) + 'k';
  return String(n);
};

const formatDateRel = (d) => {
  if (!d) return '';
  const diff = Math.floor((Date.now() - new Date(d)) / 1000);
  if (diff < 60) return 'Just now';
  if (diff < 3600) return `${Math.floor(diff / 60)}m`;
  if (diff < 86400) return `${Math.floor(diff / 3600)}h`;
  if (diff < 604800) return `${Math.floor(diff / 86400)}d`;
  return `${Math.floor(diff / 604800)}w`;
};

const formatDateFull = (d) => {
  if (!d) return '';
  const dt = new Date(d);
  return isNaN(dt.getTime()) ? '' : dt.toLocaleDateString('en-US', { month: 'long', day: 'numeric', year: 'numeric' });
};

const toAbsUrl = (val) => {
  if (!val) return '';
  const s = String(val);
  if (/^http:\/\/api\.bebsmart\.in/i.test(s)) return s.replace(/^http:\/\//i, 'https://');
  if (s.startsWith('http')) return s;
  const n = s.replace(/^\/+/, '');
  return `${BASE_URL}/${n.startsWith('uploads/') ? n : `uploads/${n}`}`;
};

const DeleteModal = ({ isOpen, onClose, onConfirm, isDeleting }) => {
  if (!isOpen) return null;
  return (
    <div className="fixed inset-0 z-[60] flex items-center justify-center bg-black/50 backdrop-blur-sm p-4">
      <div className="bg-white dark:bg-gray-900 rounded-xl p-6 w-full max-w-sm shadow-2xl border border-gray-100 dark:border-gray-800">
        {isDeleting ? (
          <div className="flex flex-col items-center py-8">
            <div className="animate-spin w-12 h-12 border-4 border-gray-200 border-t-red-500 rounded-full mb-4" />
            <p className="text-gray-500 font-medium animate-pulse">Deleting...</p>
          </div>
        ) : (
          <>
            <h3 className="text-lg font-bold text-gray-900 dark:text-white mb-2 text-center">Delete Promoted Reel?</h3>
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

const ProductCard = ({ product }) => {
  const originalPrice = product.product_price || 0;
  const discount = product.discount_amount || 0;
  const finalPrice = Math.max(0, originalPrice - discount);
  const discountPct = originalPrice && discount
    ? Math.round((discount / originalPrice) * 100) : 0;
  const href = product.visit_link && !['', '#'].includes(product.visit_link) ? product.visit_link : null;
  const rating = product.rating ?? product.product_rating ?? null;

  return (
    <div className="flex-shrink-0 flex flex-row bg-white dark:bg-[#1e1e1e] border border-gray-200 dark:border-gray-700 rounded-2xl overflow-hidden shadow-sm" style={{ width: 220 }}>
      <div className="relative flex-shrink-0 bg-gray-100 dark:bg-gray-800" style={{ width: 82, minHeight: 90 }}>
        {product.promote_img
          ? <img src={toAbsUrl(product.promote_img)} alt={product.product_name} className="w-full h-full object-cover" style={{ minHeight: 90 }} onError={e => { e.target.style.display = 'none'; }} />
          : <div className="w-full h-full flex items-center justify-center" style={{ minHeight: 90 }}><ShoppingBag size={20} className="text-gray-400" /></div>}
        {rating != null && (
          <div className="absolute bottom-1.5 left-1.5 flex items-center gap-0.5 bg-black/60 text-white text-[10px] font-bold px-1.5 py-0.5 rounded-full">
            <span>{rating}</span>
            <svg width="9" height="9" viewBox="0 0 24 24" fill="#FBBF24"><path d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z"/></svg>
          </div>
        )}
      </div>
      <div className="flex flex-col justify-between gap-1.5 p-2.5 flex-1 min-w-0">
        <p className="text-[12px] font-bold text-gray-900 dark:text-white truncate leading-tight">{product.product_name}</p>
        <div className="flex items-center gap-1.5 flex-wrap">
          <span className="text-[13px] font-black text-gray-900 dark:text-white">&#8377;{finalPrice.toLocaleString()}</span>
          {discountPct > 0 && (
            <>
              <span className="text-[11px] text-gray-400 line-through">&#8377;{originalPrice.toLocaleString()}</span>
              <span className="text-[11px] font-semibold text-green-500">{discountPct}% off</span>
            </>
          )}
        </div>
        {href ? (
          <a href={href} target="_blank" rel="noopener noreferrer"
            onClick={e => e.stopPropagation()}
            className="flex items-center justify-center bg-blue-500 hover:bg-blue-600 active:scale-95 text-white text-[11px] font-bold px-2 py-1.5 rounded-lg transition-all w-full">
            Visit Website
          </a>
        ) : (
          <span className="text-[10px] text-gray-400 text-center">No link</span>
        )}
      </div>
    </div>
  );
};

const FollowButton = ({ targetUserId }) => {
  const { userObject } = useSelector(s => s.auth);
  const [followState, setFollowState] = useState('not_following');
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    let isMounted = true;
    if (!userObject || !targetUserId) return;
    if (String(userObject._id || userObject.id) === String(targetUserId)) return;
    checkFollowStatus(targetUserId)
      .then(status => { if (isMounted) setFollowState(normalizeFollowStateFromStatus(status)); })
      .catch(() => {});
    return () => { isMounted = false; };
  }, [targetUserId, userObject]);

  useEffect(() => {
    const handler = (e) => {
      const d = e?.detail || {};
      if (String(d.userId || '') !== String(targetUserId || '')) return;
      if (['following', 'requested', 'not_following'].includes(d.state)) setFollowState(d.state);
    };
    window.addEventListener(FOLLOW_STATUS_CHANGED_EVENT, handler);
    return () => window.removeEventListener(FOLLOW_STATUS_CHANGED_EVENT, handler);
  }, [targetUserId]);

  const handleClick = useCallback(async (e) => {
    e.stopPropagation();
    if (!userObject || loading) return;
    const prev = followState;
    setLoading(true);
    try {
      if (followState === 'following') {
        await unfollowUser(targetUserId);
        setFollowState('not_following');
      } else if (followState === 'requested') {
        await cancelFollowRequest(targetUserId);
        setFollowState('not_following');
      } else {
        const res = await followUser(targetUserId);
        setFollowState(normalizeFollowStateFromStatus(res));
      }
    } catch {
      setFollowState(prev);
    } finally {
      setLoading(false);
    }
  }, [userObject, loading, followState, targetUserId]);

  if (!targetUserId) return null;
  const isFollowing = followState === 'following';
  const isRequested = followState === 'requested';
  return (
    <button onClick={handleClick} disabled={loading}
      className={`flex items-center gap-1.5 text-xs font-bold px-3 py-1 rounded-full border transition-all ${loading ? 'opacity-50' : ''} ${
        isFollowing || isRequested
          ? 'border-gray-300 dark:border-gray-600 text-gray-500 dark:text-gray-400'
          : 'border-blue-500 text-blue-500 bg-blue-50 dark:bg-blue-500/10'
      }`}>
      {loading ? <Loader2 size={10} className="animate-spin" /> : (isFollowing || isRequested) ? <UserCheck size={10} /> : <UserPlus size={10} />}
      <span>{isFollowing ? 'Following' : isRequested ? 'Requested' : 'Follow'}</span>
    </button>
  );
};

const ReplyRow = ({ reply, onLike, onDelete, onReply, currentUserId }) => {
  const user = reply.user || reply.users || (typeof reply.user_id === 'object' ? reply.user_id : {});
  const rId = reply._id || reply.id;
  const isLiked = reply.is_liked_by_me || false;
  const likesCount = reply.likes_count ?? 0;
  const isOwner = currentUserId && (String(user._id || user.id || '') === String(currentUserId) || String(reply.user_id || '') === String(currentUserId));
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

const CommentRow = ({ comment, replies, expanded, onToggleReplies, onReply, onLike, onDelete, onLikeReply, onDeleteReply, currentUserId }) => {
  const cId = comment._id || comment.id;
  const user = comment.user || comment.users || (typeof comment.user_id === 'object' ? comment.user_id : {});
  const isLiked = comment.is_liked_by_me || false;
  const likesCount = comment.likes_count ?? (Array.isArray(comment.likes) ? comment.likes.length : 0);
  const currentReplies = replies[cId] || [];
  const replyCount = currentReplies.length > 0 ? currentReplies.length : (comment.reply_count || 0);
  const hasReplies = replyCount > 0;
  const isOwner = currentUserId && (String(user._id || user.id || '') === String(currentUserId) || String(comment.user_id || '') === String(currentUserId));
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

const ModalMediaPanel = ({ item }) => {
  const mediaItems = Array.isArray(item?.media) && item.media.length > 0 ? item.media : [];
  const [currentIndex, setCurrentIndex] = useState(0);
  const [isPlaying, setIsPlaying] = useState(false);
  const [isMuted, setIsMuted] = useState(true);
  const videoRef = useRef(null);

  useEffect(() => { if (videoRef.current) videoRef.current.muted = isMuted; }, [isMuted]);

  const currentMedia = mediaItems[currentIndex] || {};
  const mediaSrc = (() => {
    if (currentMedia.url && String(currentMedia.url).startsWith('http')) return currentMedia.url;
    return toAbsUrl(currentMedia.fileUrl || currentMedia.fileName);
  })();
  const isVideo = currentMedia.type === 'video' || currentMedia.media_type === 'video'
    || /\.(mp4|mov|webm|ogg|m4v|m3u8)(\?.*)?$/i.test(String(mediaSrc || ''));
  const thumbUrl = (() => {
    const thumbs = currentMedia.thumbnails || currentMedia.thumbnail;
    const first = Array.isArray(thumbs) ? thumbs[0] : thumbs;
    if (!first) return null;
    return toAbsUrl(first.fileUrl || first.fileName);
  })();

  const nextMedia = (e) => { e.stopPropagation(); setCurrentIndex(i => (i + 1) % mediaItems.length); setIsPlaying(false); };
  const prevMedia = (e) => { e.stopPropagation(); setCurrentIndex(i => (i - 1 + mediaItems.length) % mediaItems.length); setIsPlaying(false); };

  if (!mediaItems.length) return (
    <div className="w-full h-full flex items-center justify-center bg-gradient-to-br from-orange-900/40 to-pink-900/40">
      <div className="text-center px-8">
        <Zap size={48} className="text-orange-400 mx-auto mb-3" />
        <p className="text-white font-bold text-lg">Promoted Reel</p>
      </div>
    </div>
  );

  return (
    <div className="relative w-full h-full bg-black flex items-center justify-center group">
      <div className="absolute top-3 left-3 z-30">
        <span className="inline-flex items-center gap-1 bg-gradient-to-r from-orange-500 to-pink-500 text-white text-[10px] font-bold px-2.5 py-1 rounded-full shadow">
          <Zap size={9} /> Promoted
        </span>
      </div>
      {isVideo ? (
        <div className="relative w-full h-full flex items-center justify-center">
          {/* Thumbnail shown until video starts playing — same as PostDetailModal */}
          {thumbUrl && !isPlaying && (
            <img src={thumbUrl} alt="thumbnail" className="absolute inset-0 w-full h-full object-contain" />
          )}
          <video
            ref={videoRef}
            src={mediaSrc}
            className="w-full h-full object-contain"
            autoPlay
            muted={isMuted}
            playsInline
            loop
            onPlay={() => setIsPlaying(true)}
            onPause={() => setIsPlaying(false)}
            onEnded={() => setIsPlaying(false)}
            onLoadedMetadata={(e) => { e.currentTarget.play().catch(() => {}); }}
            onClick={(e) => { e.stopPropagation(); videoRef.current?.paused ? videoRef.current.play().catch(() => {}) : videoRef.current?.pause(); }}
          />
          {!isPlaying && (
            <div className="absolute inset-0 z-10 flex items-center justify-center pointer-events-none">
              <div className="w-16 h-16 rounded-full bg-black/40 flex items-center justify-center">
                <svg className="w-8 h-8 text-white ml-1" fill="currentColor" viewBox="0 0 24 24"><path d="M8 5v14l11-7z" /></svg>
              </div>
            </div>
          )}
          <button onClick={(e) => { e.stopPropagation(); setIsMuted(m => !m); }}
            className="absolute bottom-3 right-3 z-20 w-9 h-9 rounded-full bg-black/60 hover:bg-black/80 text-white flex items-center justify-center transition-all opacity-0 group-hover:opacity-100">
            {isMuted ? <VolumeX size={16} /> : <Volume2 size={16} />}
          </button>
        </div>
      ) : (
        <img src={mediaSrc} alt="content" className="w-full h-full object-contain" />
      )}
      {mediaItems.length > 1 && (
        <>
          <button onClick={prevMedia} className="absolute left-4 top-1/2 -translate-y-1/2 bg-black/50 hover:bg-black/70 text-white p-2 rounded-full opacity-0 group-hover:opacity-100 transition-opacity z-20"><ChevronLeft size={24} /></button>
          <button onClick={nextMedia} className="absolute right-4 top-1/2 -translate-y-1/2 bg-black/50 hover:bg-black/70 text-white p-2 rounded-full opacity-0 group-hover:opacity-100 transition-opacity z-20"><ChevronRight size={24} /></button>
          <div className="absolute bottom-4 left-1/2 -translate-x-1/2 flex gap-1.5 z-10">
            {mediaItems.map((_, idx) => <div key={idx} className={`w-2 h-2 rounded-full transition-all duration-300 ${idx === currentIndex ? 'bg-white scale-110' : 'bg-white/50'}`} />)}
          </div>
        </>
      )}
    </div>
  );
};

const PromoteDetailModal = ({ promoteReel: initialItem, isOpen, onClose }) => {
  const { userObject } = useSelector(s => s.auth);
  const currentUserId = userObject?._id || userObject?.id || null;

  const [item, setItem] = useState(initialItem);
  const id = item?._id || item?.id || item?.promote_reel_id;
  const author = item?.user_id || {};
  const username = author?.username || 'User';
  const fullName = author?.full_name || '';
  const avatar = author?.avatar_url || '';
  const authorId = author?._id || author?.id || (typeof item?.user_id === 'string' ? item?.user_id : null);
  const isOwner = !!(currentUserId && authorId && String(currentUserId) === String(authorId));
  const turnOffCommenting = !!(item?.turn_off_commenting || item?.engagement_controls?.turn_off_commenting);
  const profilePath = `/profile/${authorId}`;
  const products = Array.isArray(item?.products) ? item.products : [];
  const caption = item?.caption || '';

  const [isLiked, setIsLiked] = useState(false);
  const [likeCount, setLikeCount] = useState(0);
  const [likeLoading, setLikeLoading] = useState(false);
  const [isSaved, setIsSaved] = useState(false);
  const [comments, setComments] = useState([]);
  const [replies, setReplies] = useState({});
  const [expandedComments, setExpandedComments] = useState({});
  const [replyTo, setReplyTo] = useState(null);
  const [newComment, setNewComment] = useState('');
  const [loadingComments, setLoadingComments] = useState(false);
  const [productsOpen, setProductsOpen] = useState(false);
  const [showDeleteModal, setShowDeleteModal] = useState(false);
  const [isDeleting, setIsDeleting] = useState(false);
  const [showReportModal, setShowReportModal] = useState(false);
  const [showShareModal, setShowShareModal] = useState(false);
  const [showEmojiPicker, setShowEmojiPicker] = useState(false);
  const emojiPickerRef = useRef(null);

  const loadReplies = useCallback(async (commentId) => {
    try {
      const data = await promoteReelService.getReplies(commentId);
      const fetched = Array.isArray(data) ? data : (data.replies || data.data || []);
      setReplies(prev => ({ ...prev, [commentId]: fetched }));
    } catch { /* ignore */ }
  }, []);

  const fetchComments = useCallback(async (itemId) => {
    if (!itemId) return;
    setLoadingComments(true);
    try {
      const data = await promoteReelService.getComments(itemId);
      const list = Array.isArray(data) ? data : (data.comments || data.data || []);
      setComments(list);
      list.forEach(c => {
        const cId = c._id || c.id;
        promoteReelService.getReplies(cId).then(rData => {
          const fetched = Array.isArray(rData) ? rData : (rData.replies || rData.data || []);
          if (fetched?.length > 0) setReplies(prev => ({ ...prev, [cId]: fetched }));
        }).catch(() => { /* ignore */ });
      });
    } catch { /* ignore */ }
    finally { setLoadingComments(false); }
  }, []);

  useEffect(() => {
    if (isOpen && initialItem) {
      setItem(initialItem);
      setNewComment(''); setReplyTo(null); setReplies({}); setExpandedComments({});
      setIsLiked(initialItem.is_liked_by_me || false);
      setLikeCount(initialItem.likes_count ?? (Array.isArray(initialItem.likes) ? initialItem.likes.length : 0));
      setIsSaved(initialItem.is_saved_by_me || false);
      const rid = initialItem._id || initialItem.promote_reel_id;
      if (rid) {
        promoteReelService.getPromoteReelById(rid)
          .then(res => {
            const normalized = res?.data || res;
            if (normalized?._id) {
              setItem(normalized);
              if (normalized.is_saved_by_me !== undefined) setIsSaved(normalized.is_saved_by_me);
              if (normalized.is_liked_by_me !== undefined) setIsLiked(normalized.is_liked_by_me);
              const freshCount = normalized.likes_count ?? (Array.isArray(normalized.likes) ? normalized.likes.length : undefined);
              if (freshCount !== undefined) setLikeCount(freshCount);
            }
          })
          .catch(() => { /* ignore */ });
        fetchComments(rid);
      }
    }
  }, [isOpen, initialItem, fetchComments]);

  const handlePostComment = async (e) => {
    e?.preventDefault();
    if (!newComment.trim() || !id) return;
    const text = newComment.trim();
    const replyInfo = replyTo;
    setNewComment(''); setReplyTo(null);
    try {
      await promoteReelService.addComment(id, text, replyInfo?.id || null);
      if (replyInfo) {
        await loadReplies(replyInfo.rootCommentId || replyInfo.id);
        setExpandedComments(prev => ({ ...prev, [replyInfo.rootCommentId || replyInfo.id]: true }));
      } else {
        await fetchComments(id);
        setItem(prev => ({ ...prev, comments_count: (prev?.comments_count || 0) + 1 }));
      }
    } catch { setNewComment(text); if (replyInfo) setReplyTo(replyInfo); }
  };

  const handleLikeComment = async (commentId, isLikedArg) => {
    setComments(prev => prev.map(c => {
      if (String(c._id || c.id) !== String(commentId)) return c;
      return { ...c, is_liked_by_me: !isLikedArg, likes_count: (c.likes_count ?? 0) + (isLikedArg ? -1 : 1) };
    }));
    try {
      if (isLikedArg) await promoteReelService.unlikeComment(commentId);
      else await promoteReelService.likeComment(commentId);
    } catch {
      setComments(prev => prev.map(c => {
        if (String(c._id || c.id) !== String(commentId)) return c;
        return { ...c, is_liked_by_me: isLikedArg, likes_count: (c.likes_count ?? 0) + (isLikedArg ? 1 : -1) };
      }));
    }
  };
  const handleLikeReply = async (replyId, isLikedArg) => {
    setReplies(prev => {
      const updated = {};
      for (const [key, arr] of Object.entries(prev)) {
        updated[key] = arr.map(r => {
          if (String(r._id || r.id) !== String(replyId)) return r;
          return { ...r, is_liked_by_me: !isLikedArg, likes_count: (r.likes_count ?? 0) + (isLikedArg ? -1 : 1) };
        });
      }
      return updated;
    });
    try {
      if (isLikedArg) await promoteReelService.unlikeComment(replyId);
      else await promoteReelService.likeComment(replyId);
    } catch {
      setReplies(prev => {
        const updated = {};
        for (const [key, arr] of Object.entries(prev)) {
          updated[key] = arr.map(r => {
            if (String(r._id || r.id) !== String(replyId)) return r;
            return { ...r, is_liked_by_me: isLikedArg, likes_count: (r.likes_count ?? 0) + (isLikedArg ? 1 : -1) };
          });
        }
        return updated;
      });
    }
  };
  const handleDeleteComment = async (commentId) => {
    try {
      await promoteReelService.deleteComment(commentId);
      setComments(prev => prev.filter(c => (c._id || c.id) !== commentId));
      setItem(prev => ({ ...prev, comments_count: Math.max(0, (prev?.comments_count || 1) - 1) }));
    } catch { /* ignore */ }
  };
  const handleDeleteReply = async (replyId) => {
    try {
      await promoteReelService.deleteComment(replyId);
      setReplies(prev => {
        const updated = {};
        for (const [key, arr] of Object.entries(prev)) {
          updated[key] = arr.filter(r => (r._id || r.id) !== replyId);
        }
        return updated;
      });
    } catch { /* ignore */ }
  };
  const onToggleReplies = (commentId) => {
    const isExpanded = expandedComments[commentId];
    if (!isExpanded && (!replies[commentId] || replies[commentId].length === 0)) loadReplies(commentId);
    setExpandedComments(prev => ({ ...prev, [commentId]: !prev[commentId] }));
  };
  // Sync like state with feed (PostCard/PromoteCard)
  useEffect(() => {
    if (!id) return;
    const handler = (e) => {
      const d = e.detail;
      if (String(d.postId) !== String(id)) return;
      if (d.isLiked !== undefined) setIsLiked(d.isLiked);
      if (d.likeCount !== undefined) setLikeCount(d.likeCount);
    };
    window.addEventListener('bsmart:post-state', handler);
    return () => window.removeEventListener('bsmart:post-state', handler);
  }, [id]);

  const handleLike = async () => {
    if (!userObject || !id || likeLoading) return;
    const wasLiked = isLiked;
    const wasCount = likeCount;
    const newLiked = !wasLiked;
    const newCount = newLiked ? wasCount + 1 : Math.max(0, wasCount - 1);
    setIsLiked(newLiked);
    setLikeCount(newCount);
    setLikeLoading(true);
    window.dispatchEvent(new CustomEvent('bsmart:post-state', { detail: { postId: String(id), isLiked: newLiked, likeCount: newCount } }));
    try {
      if (wasLiked) await promoteReelService.unlikePromoteReel(id);
      else await promoteReelService.likePromoteReel(id);
    } catch (err) {
      console.error('[PromoteDetailModal] like/unlike failed — id:', id, 'status:', err?.response?.status, err?.message);
      setIsLiked(wasLiked);
      setLikeCount(wasCount);
      window.dispatchEvent(new CustomEvent('bsmart:post-state', { detail: { postId: String(id), isLiked: wasLiked, likeCount: wasCount } }));
    } finally {
      setLikeLoading(false);
    }
  };
  const handleSave = async () => {
    if (!userObject || !id) return;
    const was = isSaved;
    setIsSaved(!was);
    try {
      const base = `/saved/promote-reels/${id}`;
      await api.post(was ? `${base}/unsave` : base);
    } catch (err) {
      if (err?.response?.status === 409) return; // already in target state; keep optimistic update
      setIsSaved(was);
    }
  };

  const handleDelete = async () => {
    setIsDeleting(true);
    try { await promoteReelService.deletePromoteReel(id); await new Promise(r => setTimeout(r, 800)); onClose(); window.location.reload(); }
    catch { alert('Failed to delete'); setIsDeleting(false); setShowDeleteModal(false); }
  };

  useEffect(() => {
    if (!showEmojiPicker) return;
    const handler = (e) => {
      if (emojiPickerRef.current && !emojiPickerRef.current.contains(e.target)) setShowEmojiPicker(false);
    };
    document.addEventListener('mousedown', handler);
    return () => document.removeEventListener('mousedown', handler);
  }, [showEmojiPicker]);

  // Escape key + outside-click to close
  useEffect(() => {
    if (!isOpen) return;
    const onKey = (e) => { if (e.key === 'Escape') onClose(); };
    document.addEventListener('keydown', onKey);
    return () => document.removeEventListener('keydown', onKey);
  }, [isOpen, onClose]);

  if (!isOpen || !item) return null;

  return (
    <div
      className="fixed inset-0 z-[70] flex items-center justify-center bg-black/60 p-4 md:p-10"
      onClick={onClose}
    >
      <button onClick={onClose} className="absolute top-4 right-4 text-white hover:opacity-75 z-[60]">
        <X size={24} />
      </button>

      <div
        className="bg-white dark:bg-black max-w-[90vw] md:max-w-[1200px] w-full max-h-[90vh] h-full md:h-[85vh] flex flex-col md:flex-row overflow-hidden rounded-md md:rounded-r-xl animate-in fade-in zoom-in duration-200"
        onClick={e => e.stopPropagation()}
      >

        {/* Left: Media */}
        <div className="w-full md:w-[55%] h-[42vh] md:h-full">
          <ModalMediaPanel item={item} />
        </div>

        {/* Right: Details */}
        <div className="flex flex-col w-full md:w-[45%] h-full bg-white dark:bg-black">

          {/* Header */}
          <div className="flex items-center justify-between p-3 md:p-4 border-b border-gray-100 dark:border-gray-800 shrink-0">
            <div className="flex items-center gap-3 min-w-0">
              <Link to={profilePath}><Avatar src={avatar} username={username} /></Link>
              <div className="min-w-0">
                <div className="flex items-center gap-2 flex-wrap">
                  <Link to={profilePath} className="font-semibold text-sm text-gray-900 dark:text-white hover:opacity-70 truncate">{username}</Link>
                  <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full bg-gradient-to-r from-orange-400 to-pink-500 text-white text-[9px] font-bold">
                    <Zap size={8} /> Promoted
                  </span>
                </div>
                {fullName && fullName !== username && <p className="text-xs text-gray-500 truncate">{fullName}</p>}
                {(item.location_data || item.location) && <LocationLink location={item.location_data || item.location} className="text-xs text-gray-400" />}
              </div>
            </div>
            <button
              onClick={() => { if (isOwner) { setShowDeleteModal(true); return; } setShowReportModal(true); }}
              className="text-gray-900 dark:text-white hover:opacity-50 p-1 rounded-full hover:bg-gray-100 dark:hover:bg-gray-800 transition-colors">
              <MoreHorizontal size={20} />
            </button>
          </div>

          <DeleteModal isOpen={showDeleteModal} onClose={() => setShowDeleteModal(false)} onConfirm={handleDelete} isDeleting={isDeleting} />
          <ContentReportModal isOpen={showReportModal} onClose={() => setShowReportModal(false)}
            contentType="promote_reel" contentId={id} ownerUsername={username}
            contentUrl={`${window.location.origin}/promote-reels/${id}`} />

          {/* Scrollable: caption + tags + comments */}
          <div className="flex-1 overflow-y-auto p-3 md:p-4 scrollbar-hide">
            {/* Caption */}
            <div className="flex gap-3 mb-4">
              <Link to={profilePath}><Avatar src={avatar} username={username} size="sm" /></Link>
              <div className="flex-1 text-sm">
                <Link to={profilePath} className="font-semibold mr-2 dark:text-white hover:underline">{username}</Link>
                {caption
                  ? <span className="text-gray-900 dark:text-gray-100 whitespace-pre-wrap">{caption}</span>
                  : <span className="text-gray-400 italic text-xs">No caption</span>}
                <div className="text-gray-400 text-xs mt-1">{formatDateRel(item.createdAt || item.created_at)}</div>
              </div>
            </div>

            {/* Tags */}
            {Array.isArray(item.tags) && item.tags.length > 0 && (
              <div className="flex flex-wrap gap-1.5 mb-4">
                {item.tags.map((t, i) => <span key={i} className="text-sm text-blue-500">#{t}</span>)}
              </div>
            )}

            {/* Comments */}
            {!turnOffCommenting && (
              <>
                <div className="flex items-center gap-2 mb-3 pb-2.5 border-b border-gray-100 dark:border-gray-800">
                  <MessageCircle size={15} className="text-gray-500 dark:text-gray-400" />
                  <span className="font-semibold text-sm text-gray-900 dark:text-white">Comments</span>
                  <span className="text-sm text-gray-400 font-normal">
                    ({item.comments_count ?? comments.length})
                  </span>
                </div>
                {loadingComments ? (
                  <div className="flex justify-center py-4"><Loader2 size={24} className="animate-spin text-gray-400" /></div>
                ) : comments.length > 0 ? (
                  comments.map(comment => (
                    <CommentRow key={comment._id || comment.id} comment={comment} replies={replies}
                      expanded={expandedComments[comment._id || comment.id]}
                      onToggleReplies={onToggleReplies}
                      onReply={(u) => setReplyTo({ id: comment._id || comment.id, rootCommentId: comment._id || comment.id, username: u.username })}
                      onLike={handleLikeComment} onDelete={handleDeleteComment}
                      onLikeReply={handleLikeReply} onDeleteReply={handleDeleteReply}
                      currentUserId={currentUserId} />
                  ))
                ) : (
                  <div className="flex flex-col items-center justify-center py-8 text-gray-400 text-sm">
                    <MessageCircle size={32} className="mb-2 opacity-40" />
                    <p>No comments yet. Be the first!</p>
                  </div>
                )}
              </>
            )}
          </div>

          {/* Footer */}
          <div className="border-t border-gray-100 dark:border-gray-800 bg-white dark:bg-black shrink-0">

            {/* Products — toggle, default closed, smooth slide */}
            {products.length > 0 && (
              <div className="px-3 md:px-4 pt-3">
                {/* Toggle header */}
                <button
                  onClick={() => setProductsOpen(v => !v)}
                  className="flex items-center gap-2 w-full mb-0 group"
                >
                  <ShoppingBag size={13} className="text-orange-500" />
                  <span className="text-xs font-semibold text-gray-700 dark:text-gray-300">Products</span>
                  <span className="text-[10px] text-gray-400">({products.length})</span>
                  {/* Chevron rotates on open */}
                  <svg
                    className="ml-auto text-gray-400 transition-transform duration-300"
                    style={{ transform: productsOpen ? 'rotate(180deg)' : 'rotate(0deg)' }}
                    width="14" height="14" viewBox="0 0 24 24" fill="none"
                    stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round"
                  >
                    <polyline points="6 9 12 15 18 9" />
                  </svg>
                </button>

                {/* Animated slide panel */}
                <div
                  style={{
                    maxHeight: productsOpen ? '220px' : '0px',
                    opacity: productsOpen ? 1 : 0,
                    overflow: 'hidden',
                    transition: 'max-height 0.35s cubic-bezier(0.4,0,0.2,1), opacity 0.25s ease',
                  }}
                >
                  <div
                    className="flex gap-3 pb-2 pt-3"
                    style={{ overflowX: 'auto', scrollbarWidth: 'none', WebkitOverflowScrolling: 'touch' }}
                  >
                    {products.map((p, i) => <ProductCard key={p._id || i} product={p} />)}
                  </div>
                </div>
              </div>
            )}

            <div className="p-3 md:p-4 pb-2">
              <div className="flex justify-between mb-2">
                <div className="flex gap-4">
                  <button onClick={handleLike} disabled={likeLoading} className="hover:opacity-50 transition-opacity active:scale-90 disabled:cursor-not-allowed">
                    <Heart size={24} className={isLiked ? 'fill-red-500 text-red-500' : 'text-gray-900 dark:text-white'} />
                  </button>
                  {!turnOffCommenting && (
                    <button className="hover:opacity-50 transition-opacity">
                      <MessageCircle size={24} className="text-gray-900 dark:text-white" />
                    </button>
                  )}
                  <button type="button" onClick={() => setShowShareModal(true)} className="hover:opacity-50 transition-opacity">
                    <Send size={24} className="text-gray-900 dark:text-white" />
                  </button>
                </div>
                <div className="flex items-center gap-3">
                  {!isOwner && authorId && userObject && <FollowButton targetUserId={String(authorId)} />}
                  <button onClick={handleSave} className="active:scale-90 transition-transform" aria-label={isSaved ? 'Unsave' : 'Save'}>
                    <Bookmark size={24} className={`transition-all duration-200 ${isSaved ? 'fill-black text-black dark:fill-white dark:text-white' : 'text-gray-900 dark:text-white'}`} />
                  </button>
                </div>
              </div>
              <div className="font-semibold text-sm text-gray-900 dark:text-white mb-1">{fmt(likeCount)} likes</div>
              <div className="text-[10px] text-gray-400 uppercase tracking-wide">{formatDateFull(item.createdAt || item.created_at)}</div>
            </div>

            {!turnOffCommenting && replyTo && (
              <div className="px-3 md:px-4 py-2 bg-gray-50 dark:bg-gray-900 flex justify-between items-center text-xs text-gray-500 dark:text-gray-400">
                <span>Replying to <span className="font-semibold text-blue-500">@{replyTo.username}</span></span>
                <button onClick={() => setReplyTo(null)}><X size={14} /></button>
              </div>
            )}

            {!turnOffCommenting && (
              <form onSubmit={handlePostComment} className="border-t border-gray-100 dark:border-gray-800 p-3 md:p-4 flex items-center gap-3">
                <div className="relative shrink-0" ref={emojiPickerRef}>
                  {showEmojiPicker && (
                    <div className="absolute bottom-full left-0 mb-2 z-50">
                      <EmojiPicker
                        theme="auto"
                        onEmojiClick={(ed) => setNewComment(prev => prev + ed.emoji)}
                        lazyLoadEmojis
                        skinTonesDisabled
                        previewConfig={{ showPreview: false }}
                      />
                    </div>
                  )}
                  <button type="button" onClick={() => setShowEmojiPicker(v => !v)}
                    className="text-gray-900 dark:text-white hover:opacity-50">
                    <Smile size={24} />
                  </button>
                </div>
                <input type="text"
                  placeholder={replyTo ? `Reply to @${replyTo.username}...` : 'Add a comment...'}
                  className="flex-1 text-sm outline-none text-gray-900 dark:text-white bg-transparent placeholder-gray-400 dark:placeholder-gray-500"
                  value={newComment} onChange={e => setNewComment(e.target.value)} />
                <button type="submit" disabled={!newComment.trim()}
                  className={`text-blue-500 font-semibold text-sm shrink-0 ${!newComment.trim() ? 'opacity-40' : 'hover:text-blue-700'}`}>
                  Post
                </button>
              </form>
            )}
          </div>
        </div>
      </div>

      <ShareContentModal isOpen={showShareModal} onClose={() => setShowShareModal(false)}
        contentType="promote_reel" contentId={id} />
    </div>
  );
};

export default PromoteDetailModal;