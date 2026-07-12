import React, { useState, useEffect, useRef, useCallback } from 'react';
import { useParams, useNavigate, Link } from 'react-router-dom';
import { useSelector } from 'react-redux';
import {
  ArrowLeft, Heart, MessageCircle, Send, Bookmark,
  Smile, ChevronLeft, ChevronRight, Trash2, X,
  ShoppingBag, MoreHorizontal, Loader2, VolumeX, Volume2,
  Zap, UserPlus, UserCheck
} from 'lucide-react';
import api from '../lib/api';
import promoteReelService from '../services/promoteReelService';
import {
  checkFollowStatus, followUser, unfollowUser, cancelFollowRequest,
  FOLLOW_STATUS_CHANGED_EVENT, normalizeFollowStateFromStatus,
} from '../services/followService';
import ContentReportModal from '../components/ContentReportModal';
import Avatar from '../components/Avatar';

const BASE_URL = 'https://api.bebsmart.in';

const formatTimeAgo = (d) => {
  if (!d) return '';
  const diff = Math.floor((Date.now() - new Date(d).getTime()) / 1000);
  if (diff < 60) return `${diff}s`;
  if (diff < 3600) return `${Math.floor(diff / 60)}m`;
  if (diff < 86400) return `${Math.floor(diff / 3600)}h`;
  if (diff < 604800) return `${Math.floor(diff / 86400)}d`;
  return `${Math.floor(diff / 604800)}w`;
};

const toAbsUrl = (val) => {
  if (!val) return '';
  const s = String(val);
  if (/^http:\/\/api\.bebsmart\.in/i.test(s)) return s.replace(/^http:\/\//i, 'https://');
  if (s.startsWith('http')) return s;
  const n = s.replace(/^\/+/, '');
  return `${BASE_URL}/${n.startsWith('uploads/') ? n : `uploads/${n}`}`;
};

// ─── Delete modal ──────────────────────────────────────────────────────────────
const DeleteModal = ({ isOpen, onClose, onConfirm, isDeleting, label = 'comment' }) => {
  if (!isOpen) return null;
  return (
    <div className="fixed inset-0 z-[60] flex items-center justify-center bg-black/50 backdrop-blur-sm p-4">
      <div className="bg-white dark:bg-gray-900 rounded-xl p-6 w-full max-w-sm shadow-2xl border border-gray-100 dark:border-gray-800">
        {isDeleting ? (
          <div className="flex flex-col items-center py-8">
            <Loader2 className="animate-spin w-10 h-10 text-red-500 mb-3" />
            <p className="text-gray-500 font-medium animate-pulse">Deleting…</p>
          </div>
        ) : (
          <>
            <h3 className="text-lg font-bold text-gray-900 dark:text-white mb-2 text-center">Delete {label}?</h3>
            <p className="text-gray-500 text-sm mb-6 text-center">This action cannot be undone.</p>
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

// ─── Product card ──────────────────────────────────────────────────────────────
const ProductCard = ({ product }) => {
  const originalPrice = product.product_price || 0;
  const discount = product.discount_amount || 0;
  const finalPrice = Math.max(0, originalPrice - discount);
  const discountPct = originalPrice && discount ? Math.round((discount / originalPrice) * 100) : 0;
  const href = product.visit_link && !['', '#'].includes(product.visit_link) ? product.visit_link : null;

  return (
    <div className="flex-shrink-0 flex flex-row bg-white dark:bg-[#1e1e1e] border border-gray-200 dark:border-gray-700 rounded-2xl overflow-hidden shadow-sm" style={{ width: 200 }}>
      <div className="relative flex-shrink-0 bg-gray-100 dark:bg-gray-800" style={{ width: 76, minHeight: 90 }}>
        {product.promote_img
          ? <img src={toAbsUrl(product.promote_img)} alt={product.product_name} className="w-full h-full object-cover" style={{ minHeight: 90 }} onError={e => { e.target.style.display = 'none'; }} />
          : <div className="w-full h-full flex items-center justify-center" style={{ minHeight: 90 }}><ShoppingBag size={18} className="text-gray-400" /></div>}
      </div>
      <div className="flex flex-col justify-between gap-1 p-2 flex-1 min-w-0">
        <p className="text-[11px] font-bold text-gray-900 dark:text-white truncate leading-tight">{product.product_name}</p>
        <div className="flex items-center gap-1 flex-wrap">
          <span className="text-[12px] font-black text-gray-900 dark:text-white">₹{finalPrice.toLocaleString()}</span>
          {discountPct > 0 && (
            <>
              <span className="text-[10px] text-gray-400 line-through">₹{originalPrice.toLocaleString()}</span>
              <span className="text-[10px] font-semibold text-green-500">{discountPct}% off</span>
            </>
          )}
        </div>
        {href ? (
          <a href={href} target="_blank" rel="noopener noreferrer" onClick={e => e.stopPropagation()}
            className="flex items-center justify-center bg-blue-500 hover:bg-blue-600 text-white text-[10px] font-bold px-1.5 py-1 rounded-lg transition-all w-full">
            Visit Website
          </a>
        ) : (
          <span className="text-[9px] text-gray-400 text-center">No link</span>
        )}
      </div>
    </div>
  );
};

// ─── Follow button ─────────────────────────────────────────────────────────────
const FollowButton = ({ targetUserId }) => {
  const { userObject } = useSelector(s => s.auth);
  const [followState, setFollowState] = useState('not_following');
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    let mounted = true;
    if (!userObject || !targetUserId) return;
    if (String(userObject._id || userObject.id) === String(targetUserId)) return;
    checkFollowStatus(targetUserId)
      .then(s => { if (mounted) setFollowState(normalizeFollowStateFromStatus(s)); })
      .catch(() => {});
    return () => { mounted = false; };
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
      if (followState === 'following') { await unfollowUser(targetUserId); setFollowState('not_following'); }
      else if (followState === 'requested') { await cancelFollowRequest(targetUserId); setFollowState('not_following'); }
      else { const res = await followUser(targetUserId); setFollowState(normalizeFollowStateFromStatus(res)); }
    } catch { setFollowState(prev); }
    finally { setLoading(false); }
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

// ─── Main Page ─────────────────────────────────────────────────────────────────
const MobilePromoteDetail = () => {
  const { promoteReelId } = useParams();
  const navigate = useNavigate();
  const { userObject } = useSelector((state) => state.auth);

  const [item, setItem] = useState(null);
  const [loading, setLoading] = useState(true);

  // media
  const [mediaIndex, setMediaIndex] = useState(0);
  const [isMuted, setIsMuted] = useState(true);
  const [videoPlaying, setVideoPlaying] = useState(true);
  const videoRef = useRef(null);

  // like / save
  const [isLiked, setIsLiked] = useState(false);
  const [likeCount, setLikeCount] = useState(0);
  const [likeLoading, setLikeLoading] = useState(false);
  const [isSaved, setIsSaved] = useState(false);

  // products
  const [productsOpen, setProductsOpen] = useState(false);

  // comments
  const [comments, setComments] = useState([]);
  const [replies, setReplies] = useState({});
  const [expandedComments, setExpandedComments] = useState({});
  const [commentsLoading, setCommentsLoading] = useState(false);
  const [replyTo, setReplyTo] = useState(null);
  const [newComment, setNewComment] = useState('');

  // modals
  const [showReport, setShowReport] = useState(false);
  const [deleteTarget, setDeleteTarget] = useState(null);
  const [isDeleting, setIsDeleting] = useState(false);

  const commentsRef = useRef(null);
  const currentUserId = userObject?._id || userObject?.id;

  const author = item?.user_id || {};
  const username = author?.username || 'User';
  const fullName = author?.full_name || '';
  const avatar = author?.avatar_url || '';
  const authorId = author?._id || author?.id || (typeof item?.user_id === 'string' ? item?.user_id : null);
  const isOwner = !!(currentUserId && authorId && String(currentUserId) === String(authorId));
  const turnOffCommenting = !!(item?.turn_off_commenting || item?.engagement_controls?.turn_off_commenting);
  const products = Array.isArray(item?.products) ? item.products : [];
  const tags = Array.isArray(item?.tags) ? item.tags : [];
  const caption = item?.caption || '';

  // ── Fetch ──────────────────────────────────────────────────────────────────
  useEffect(() => {
    if (promoteReelId) fetchItem();
  }, [promoteReelId]);

  const fetchItem = async () => {
    setLoading(true);
    try {
      const res = await promoteReelService.getPromoteReelById(promoteReelId);
      const data = res?.data || res;
      setItem(data);
      setIsLiked(data?.is_liked_by_me ?? false);
      setLikeCount(data?.likes_count ?? (Array.isArray(data?.likes) ? data.likes.length : 0));
      setIsSaved(data?.is_saved_by_me ?? false);
      await fetchComments(promoteReelId);
    } catch (e) {
      console.error('Failed to fetch promote reel:', e);
    } finally {
      setLoading(false);
    }
  };

  const fetchComments = useCallback(async (id = promoteReelId) => {
    setCommentsLoading(true);
    try {
      const data = await promoteReelService.getComments(id);
      const list = Array.isArray(data) ? data : (data?.comments || data?.data || []);
      setComments(list);
      list.forEach(c => {
        const cid = c._id || c.id;
        promoteReelService.getReplies(cid)
          .then(r => {
            const fetched = Array.isArray(r) ? r : (r?.replies || r?.data || []);
            if (fetched?.length) setReplies(prev => ({ ...prev, [cid]: fetched }));
          })
          .catch(() => {});
      });
    } catch (e) {
      console.error('Failed to fetch comments:', e);
    } finally {
      setCommentsLoading(false);
    }
  }, [promoteReelId]);

  const loadReplies = async (commentId) => {
    try {
      const data = await promoteReelService.getReplies(commentId);
      const fetched = Array.isArray(data) ? data : (data?.replies || data?.data || []);
      setReplies(prev => ({ ...prev, [commentId]: fetched }));
    } catch (e) {
      console.error('Failed to load replies:', e);
    }
  };

  // ── Like / Save ────────────────────────────────────────────────────────────
  const handleLike = async () => {
    if (!userObject || !promoteReelId || likeLoading) return;
    const wasLiked = isLiked;
    const wasCount = likeCount;
    setIsLiked(!wasLiked);
    setLikeCount(wasLiked ? Math.max(0, wasCount - 1) : wasCount + 1);
    setLikeLoading(true);
    try {
      if (wasLiked) await promoteReelService.unlikePromoteReel(promoteReelId);
      else await promoteReelService.likePromoteReel(promoteReelId);
    } catch {
      setIsLiked(wasLiked);
      setLikeCount(wasCount);
    } finally {
      setLikeLoading(false);
    }
  };

  const handleSave = async () => {
    if (!userObject || !promoteReelId) return;
    const was = isSaved;
    setIsSaved(!was);
    try {
      const base = `/saved/promote-reels/${promoteReelId}`;
      await api.post(was ? `${base}/unsave` : base);
    } catch (err) {
      if (err?.response?.status === 409) return;
      setIsSaved(was);
    }
  };

  // ── Comment like (optimistic) ──────────────────────────────────────────────
  const handleLikeComment = async (commentId, isLikedByMe) => {
    const patch = arr => arr.map(c => {
      if (String(c._id || c.id) !== String(commentId)) return c;
      return { ...c, is_liked_by_me: !isLikedByMe, likes_count: (c.likes_count ?? 0) + (isLikedByMe ? -1 : 1) };
    });
    const revert = arr => arr.map(c => {
      if (String(c._id || c.id) !== String(commentId)) return c;
      return { ...c, is_liked_by_me: isLikedByMe, likes_count: (c.likes_count ?? 0) + (isLikedByMe ? 1 : -1) };
    });
    setComments(prev => patch(prev));
    setReplies(prev => {
      const next = {};
      for (const [k, arr] of Object.entries(prev)) next[k] = patch(arr);
      return next;
    });
    try {
      if (isLikedByMe) await promoteReelService.unlikeComment(commentId);
      else await promoteReelService.likeComment(commentId);
    } catch {
      setComments(prev => revert(prev));
      setReplies(prev => {
        const next = {};
        for (const [k, arr] of Object.entries(prev)) next[k] = revert(arr);
        return next;
      });
    }
  };

  // ── Post comment / reply ───────────────────────────────────────────────────
  const handlePostComment = async (e) => {
    e?.preventDefault();
    if (!newComment.trim()) return;
    const text = newComment.trim();
    const replyInfo = replyTo;
    setNewComment('');
    setReplyTo(null);
    try {
      await promoteReelService.addComment(promoteReelId, text, replyInfo?.id || null);
      if (replyInfo) {
        await loadReplies(replyInfo.rootCommentId || replyInfo.id);
        setExpandedComments(prev => ({ ...prev, [replyInfo.rootCommentId || replyInfo.id]: true }));
      } else {
        await fetchComments();
      }
    } catch {
      setNewComment(text);
      if (replyInfo) setReplyTo(replyInfo);
    }
  };

  // ── Delete ─────────────────────────────────────────────────────────────────
  const executeDelete = async () => {
    if (!deleteTarget) return;
    setIsDeleting(true);
    try {
      await promoteReelService.deleteComment(deleteTarget.id);
      if (deleteTarget.type === 'reply') {
        setReplies(prev => {
          const next = {};
          for (const [k, arr] of Object.entries(prev)) next[k] = arr.filter(r => String(r._id || r.id) !== String(deleteTarget.id));
          return next;
        });
      } else {
        setComments(prev => prev.filter(c => String(c._id || c.id) !== String(deleteTarget.id)));
      }
    } catch (e) {
      console.error('Delete failed:', e);
    } finally {
      setIsDeleting(false);
      setDeleteTarget(null);
    }
  };

  // ── Media ──────────────────────────────────────────────────────────────────
  const mediaItems = Array.isArray(item?.media) && item.media.length > 0 ? item.media : [];
  const currentMedia = mediaItems[mediaIndex] || {};
  const mediaSrc = (() => {
    if (currentMedia.url && String(currentMedia.url).startsWith('http')) return currentMedia.url;
    return toAbsUrl(currentMedia.fileUrl || currentMedia.fileName) || null;
  })();
  const isVideo = currentMedia.type === 'video' || currentMedia.media_type === 'video'
    || /\.(mp4|mov|webm|ogg|m4v|m3u8)(\?.*)?$/i.test(String(mediaSrc || ''));
  const thumbSrc = (() => {
    const thumbs = currentMedia.thumbnails || currentMedia.thumbnail;
    const first = Array.isArray(thumbs) ? thumbs[0] : thumbs;
    if (!first) return null;
    return toAbsUrl(first.fileUrl || first.fileName);
  })();

  // ── Comment render ─────────────────────────────────────────────────────────
  const renderComment = (comment, isReply = false) => {
    const cid = comment._id || comment.id;
    const user = (typeof comment.user_id === 'object' ? comment.user_id : null) || comment.user || comment.users || {};
    const userId = user._id || user.id || (typeof comment.user_id === 'string' ? comment.user_id : null);
    const isLikedByMe = comment.is_liked_by_me ?? false;
    const likesCount = comment.likes_count ?? 0;
    const isCommentOwner = currentUserId && String(userId) === String(currentUserId);
    const commentReplies = replies[cid] || [];
    const replyCount = comment.reply_count ?? comment.replies_count ?? commentReplies.length;
    const hasReplies = replyCount > 0 || commentReplies.length > 0;

    return (
      <div key={cid} className={`flex gap-3 mb-4 ${isReply ? 'ml-11' : ''}`}>
        <div className="w-8 h-8 rounded-full bg-gray-200 dark:bg-gray-800 overflow-hidden shrink-0">
          {(user?.avatar_url || user?.profile_picture) ? (
            <img src={user.avatar_url || user.profile_picture} alt={user?.username} className="w-full h-full object-cover" />
          ) : (
            <div className="w-full h-full flex items-center justify-center text-xs font-bold text-gray-700 dark:text-gray-300">
              {(user?.full_name || user?.username || 'U')[0].toUpperCase()}
            </div>
          )}
        </div>
        <div className="flex-1 text-sm group">
          <div className="flex justify-between items-start">
            <div className="flex-1 min-w-0 pr-2">
              <span className="font-semibold mr-2 text-gray-900 dark:text-white">{user?.full_name || user?.username || 'User'}</span>
              <span className="text-gray-900 dark:text-gray-100 break-words">{comment.text || comment.content || comment.comment}</span>
              <div className="text-gray-500 dark:text-gray-400 text-xs mt-1 flex gap-3 items-center flex-wrap">
                <span>{formatTimeAgo(comment.createdAt || comment.created_at)}</span>
                {likesCount > 0 && <span>{likesCount} {likesCount === 1 ? 'like' : 'likes'}</span>}
                {!isReply && (
                  <button className="font-semibold" onClick={() => setReplyTo({ id: cid, rootCommentId: cid, username: user?.username || user?.full_name })}>
                    Reply
                  </button>
                )}
              </div>
            </div>
            <div className="flex items-center gap-2 shrink-0">
              <button onClick={() => handleLikeComment(cid, isLikedByMe)} className={`flex flex-col items-center gap-0.5 transition-colors ${isLikedByMe ? 'text-red-500' : 'text-gray-400 dark:text-gray-600'}`}>
                <Heart size={12} fill={isLikedByMe ? 'currentColor' : 'none'} />
              </button>
              {isCommentOwner && (
                <button onClick={() => setDeleteTarget({ id: cid, type: isReply ? 'reply' : 'comment' })} className="text-gray-400 dark:text-gray-600 hover:text-red-500 transition-colors">
                  <Trash2 size={12} />
                </button>
              )}
            </div>
          </div>

          {!isReply && hasReplies && (
            <div className="mt-2">
              <button
                className="text-xs text-gray-500 flex items-center gap-2 hover:text-gray-900 dark:hover:text-gray-300"
                onClick={() => {
                  if (!replies[cid]) loadReplies(cid);
                  setExpandedComments(prev => ({ ...prev, [cid]: !prev[cid] }));
                }}
              >
                <div className="w-8 h-px bg-gray-300 dark:bg-gray-700" />
                {expandedComments[cid] ? 'Hide replies' : `View ${replyCount > 0 ? replyCount : ''} ${replyCount === 1 ? 'reply' : 'replies'}`}
              </button>
            </div>
          )}

          {!isReply && expandedComments[cid] && commentReplies.length > 0 && (
            <div className="mt-2">
              {commentReplies.map(r => renderComment(r, true))}
            </div>
          )}
        </div>
      </div>
    );
  };

  // ── Loading / error states ─────────────────────────────────────────────────
  if (loading) {
    return (
      <div className="min-h-screen bg-white dark:bg-black flex items-center justify-center">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-gray-900 dark:border-white" />
      </div>
    );
  }

  if (!item) {
    return (
      <div className="min-h-screen bg-white dark:bg-black flex flex-col items-center justify-center p-4">
        <p className="text-gray-500 mb-4">Promoted reel not found</p>
        <button onClick={() => navigate(-1)} className="text-blue-500 font-semibold">Go Back</button>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-white dark:bg-black pb-20 max-w-[1100px] mx-auto">

      {/* ── Header ──────────────────────────────────────────────────────────── */}
      <div className="sticky top-0 bg-white dark:bg-black z-50 px-4 py-3 flex items-center justify-between border-b border-gray-100 dark:border-gray-800">
        <button onClick={() => navigate(-1)} className="text-gray-900 dark:text-white">
          <ArrowLeft size={24} />
        </button>
        <div className="flex items-center gap-2">
          <span className="inline-flex items-center gap-1 bg-gradient-to-r from-orange-500 to-pink-500 text-white text-[10px] font-bold px-2 py-0.5 rounded-full">
            <Zap size={9} /> Promoted
          </span>
        </div>
        <button onClick={() => setShowReport(true)} className="text-gray-900 dark:text-white p-1">
          <MoreHorizontal size={20} />
        </button>
      </div>

      {/* ── Author header ────────────────────────────────────────────────────── */}
      <div className="px-4 py-3 flex items-center justify-between">
        <div className="flex items-center gap-3">
          <Link to={`/profile/${authorId}`} className="w-10 h-10 rounded-full overflow-hidden bg-gradient-to-tr from-yellow-400 via-orange-500 to-pink-600 flex items-center justify-center shrink-0 p-[2px]">
            <div className="w-full h-full rounded-full overflow-hidden bg-white dark:bg-black">
              {avatar ? (
                <img src={avatar} alt={username} className="w-full h-full object-cover" />
              ) : (
                <div className="w-full h-full flex items-center justify-center text-sm font-bold text-gray-700 dark:text-white">
                  {username[0]?.toUpperCase() || 'U'}
                </div>
              )}
            </div>
          </Link>
          <div className="flex-1 min-w-0">
            <Link to={`/profile/${authorId}`} className="font-semibold text-sm text-gray-900 dark:text-white leading-tight block truncate">
              {username}
            </Link>
            {fullName && fullName !== username && (
              <p className="text-xs text-gray-500 truncate">{fullName}</p>
            )}
          </div>
        </div>
        {!isOwner && authorId && userObject && (
          <FollowButton targetUserId={String(authorId)} />
        )}
      </div>

      {/* ── Media ────────────────────────────────────────────────────────────── */}
      {mediaSrc && (
        <div className="w-full bg-black relative group">
          <div className="aspect-[4/5] w-full flex items-center justify-center bg-black">
            {isVideo ? (
              <div className="relative w-full h-full">
                {thumbSrc && !videoPlaying && (
                  <img src={thumbSrc} alt="thumbnail" className="absolute inset-0 w-full h-full object-contain" />
                )}
                <video
                  ref={videoRef}
                  src={mediaSrc}
                  className="w-full h-full object-contain"
                  autoPlay
                  muted={isMuted}
                  loop
                  playsInline
                  onPlay={() => setVideoPlaying(true)}
                  onPause={() => setVideoPlaying(false)}
                  onClick={() => {
                    if (videoRef.current?.paused) videoRef.current.play().catch(() => {});
                    else videoRef.current?.pause();
                  }}
                />
                {!videoPlaying && (
                  <div className="absolute inset-0 flex items-center justify-center pointer-events-none z-10">
                    <div className="w-14 h-14 rounded-full bg-black/40 flex items-center justify-center">
                      <svg className="w-7 h-7 text-white ml-1" fill="currentColor" viewBox="0 0 24 24"><path d="M8 5v14l11-7z" /></svg>
                    </div>
                  </div>
                )}
                <button
                  onClick={() => setIsMuted(m => !m)}
                  className="absolute bottom-3 right-3 bg-black/50 rounded-full p-2 text-white z-20"
                >
                  {isMuted ? <VolumeX size={16} /> : <Volume2 size={16} />}
                </button>
              </div>
            ) : (
              <img src={mediaSrc} alt="Promoted content" className="w-full h-full object-contain" />
            )}
          </div>

          {mediaItems.length > 1 && (
            <>
              <button
                onClick={() => { setMediaIndex(i => Math.max(0, i - 1)); setVideoPlaying(false); }}
                className="absolute left-2 top-1/2 -translate-y-1/2 bg-black/50 text-white p-1.5 rounded-full"
              >
                <ChevronLeft size={20} />
              </button>
              <button
                onClick={() => { setMediaIndex(i => Math.min(mediaItems.length - 1, i + 1)); setVideoPlaying(false); }}
                className="absolute right-2 top-1/2 -translate-y-1/2 bg-black/50 text-white p-1.5 rounded-full"
              >
                <ChevronRight size={20} />
              </button>
              <div className="absolute bottom-3 left-1/2 -translate-x-1/2 flex gap-1.5">
                {mediaItems.map((_, idx) => (
                  <div key={idx} className={`w-1.5 h-1.5 rounded-full transition-all ${idx === mediaIndex ? 'bg-white scale-110' : 'bg-white/50'}`} />
                ))}
              </div>
            </>
          )}
        </div>
      )}

      {/* ── Action bar ──────────────────────────────────────────────────────── */}
      <div className="px-4 py-3">
        <div className="flex items-center justify-between mb-2">
          <div className="flex items-center gap-4">
            <button onClick={handleLike} disabled={likeLoading} className="flex items-center gap-1.5 disabled:cursor-not-allowed">
              <Heart size={26} className={`transition-colors ${isLiked ? 'fill-red-500 text-red-500' : 'text-gray-900 dark:text-white'}`} />
            </button>
            {!turnOffCommenting && (
              <button
                className="flex items-center gap-1.5"
                onClick={() => commentsRef.current?.scrollIntoView({ behavior: 'smooth', block: 'start' })}
              >
                <MessageCircle size={26} className="text-gray-900 dark:text-white" />
              </button>
            )}
            <button className="text-gray-900 dark:text-white">
              <Send size={26} />
            </button>
          </div>
          <button onClick={handleSave} className="text-gray-900 dark:text-white">
            <Bookmark size={26} className={isSaved ? 'fill-black text-black dark:fill-white dark:text-white' : ''} />
          </button>
        </div>

        {likeCount > 0 && (
          <div className="font-semibold text-sm text-gray-900 dark:text-white mb-1">{likeCount} likes</div>
        )}

        {/* Caption */}
        {caption && (
          <div className="text-sm text-gray-900 dark:text-white mb-1">
            <Link to={`/profile/${authorId}`} className="font-semibold mr-2 hover:opacity-70">{username}</Link>
            <span className="whitespace-pre-wrap">{caption}</span>
          </div>
        )}

        {/* Tags */}
        {tags.length > 0 && (
          <div className="flex flex-wrap gap-1.5 mt-1 mb-1">
            {tags.map((t, i) => <span key={i} className="text-sm text-blue-500">#{t}</span>)}
          </div>
        )}

        <div className="text-[10px] text-gray-500 uppercase tracking-wide pt-1">
          {formatTimeAgo(item.createdAt || item.created_at)}
        </div>
      </div>

      {/* ── Products ─────────────────────────────────────────────────────────── */}
      {products.length > 0 && (
        <div className="px-4 pb-3 border-t border-gray-100 dark:border-gray-800 pt-3">
          <button
            onClick={() => setProductsOpen(v => !v)}
            className="flex items-center gap-2 w-full mb-2 group"
          >
            <ShoppingBag size={14} className="text-orange-500" />
            <span className="text-xs font-semibold text-gray-700 dark:text-gray-300">Products</span>
            <span className="text-[10px] text-gray-400">({products.length})</span>
            <svg
              className="ml-auto text-gray-400 transition-transform duration-300"
              style={{ transform: productsOpen ? 'rotate(180deg)' : 'rotate(0deg)' }}
              width="14" height="14" viewBox="0 0 24 24" fill="none"
              stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round"
            >
              <polyline points="6 9 12 15 18 9" />
            </svg>
          </button>
          <div style={{
            maxHeight: productsOpen ? '200px' : '0px',
            opacity: productsOpen ? 1 : 0,
            overflow: 'hidden',
            transition: 'max-height 0.35s cubic-bezier(0.4,0,0.2,1), opacity 0.25s ease',
          }}>
            <div className="flex gap-3 pb-2 overflow-x-auto" style={{ scrollbarWidth: 'none', WebkitOverflowScrolling: 'touch' }}>
              {products.map((p, i) => <ProductCard key={p._id || i} product={p} />)}
            </div>
          </div>
        </div>
      )}

      {/* ── Comments ─────────────────────────────────────────────────────────── */}
      {!turnOffCommenting && (
        <div ref={commentsRef} className="px-4 pb-20 border-t border-gray-100 dark:border-gray-800 pt-4">
          <h3 className="font-semibold text-gray-900 dark:text-white mb-4">
            Comments {comments.length > 0 ? `(${comments.length})` : ''}
          </h3>

          {commentsLoading ? (
            <div className="flex justify-center py-4">
              <Loader2 className="animate-spin w-6 h-6 text-gray-400" />
            </div>
          ) : comments.length > 0 ? (
            <div className="mb-20">
              {comments.map(c => renderComment(c))}
            </div>
          ) : (
            <div className="flex flex-col items-center justify-center py-8 text-gray-400">
              <MessageCircle size={32} className="mb-2 opacity-40" />
              <p className="text-sm">No comments yet. Be the first!</p>
            </div>
          )}
        </div>
      )}

      {/* ── Fixed comment input ──────────────────────────────────────────────── */}
      {!turnOffCommenting && (
        <div className="fixed bottom-0 left-0 right-0 border-t border-gray-100 dark:border-gray-800 bg-white dark:bg-black z-40 p-3">
          {replyTo && (
            <div className="px-3 py-2 bg-gray-50 dark:bg-gray-900 flex justify-between items-center text-xs text-gray-500 mb-2 rounded">
              <span>Replying to <span className="font-semibold text-blue-500">@{replyTo.username}</span></span>
              <button onClick={() => setReplyTo(null)}><X size={14} /></button>
            </div>
          )}
          <form onSubmit={handlePostComment} className="flex items-center gap-3">
            <button type="button" className="text-gray-900 dark:text-white">
              <Smile size={24} />
            </button>
            <input
              type="text"
              placeholder={replyTo ? `Reply to @${replyTo.username}…` : 'Add a comment…'}
              className="flex-1 text-sm outline-none text-gray-900 dark:text-white bg-transparent placeholder-gray-500"
              value={newComment}
              onChange={e => setNewComment(e.target.value)}
            />
            <button
              type="submit"
              disabled={!newComment.trim()}
              className={`text-blue-500 font-semibold text-sm ${!newComment.trim() ? 'opacity-50' : 'hover:text-blue-700'}`}
            >
              Post
            </button>
          </form>
        </div>
      )}

      {/* ── Modals ──────────────────────────────────────────────────────────── */}
      <DeleteModal
        isOpen={Boolean(deleteTarget)}
        onClose={() => setDeleteTarget(null)}
        onConfirm={executeDelete}
        isDeleting={isDeleting}
        label={deleteTarget?.type === 'reply' ? 'reply' : 'comment'}
      />
      <ContentReportModal
        isOpen={showReport}
        onClose={() => setShowReport(false)}
        contentType="promote_reel"
        contentId={promoteReelId}
        ownerUsername={username}
        contentUrl={window.location.href}
      />
    </div>
  );
};

export default MobilePromoteDetail;
