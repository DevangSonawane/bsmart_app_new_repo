import React, { useState, useEffect, useRef } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { useSelector } from 'react-redux';
import {
  ArrowLeft, Heart, MessageCircle, Send, Bookmark,
  Smile, ChevronLeft, ChevronRight, Trash2, X,
  ShoppingBag, MoreHorizontal, Loader2, VolumeX, Volume2
} from 'lucide-react';
import api from '../lib/api';
import adCommentService from '../services/commentServiceJS';
import ContentReportModal from '../components/ContentReportModal';
import Avatar from '../components/Avatar';

const BASE_URL = 'https://api.bebsmart.in';

// ─── Helpers ───────────────────────────────────────────────────────────────────
const formatTimeAgo = (d) => {
  if (!d) return '';
  const diff = Math.floor((Date.now() - new Date(d).getTime()) / 1000);
  if (diff < 60) return `${diff}s`;
  if (diff < 3600) return `${Math.floor(diff / 60)}m`;
  if (diff < 86400) return `${Math.floor(diff / 3600)}h`;
  if (diff < 604800) return `${Math.floor(diff / 86400)}d`;
  return `${Math.floor(diff / 604800)}w`;
};

const mediaUrl = (ad) => {
  const m = ad?.media?.[0];
  if (!m) return null;
  if (m.fileUrl?.startsWith('http')) return m.fileUrl;
  if (m.fileName) return `${BASE_URL}/uploads/${m.fileName}`;
  return null;
};

const isVideo = (ad) => {
  const m = ad?.media?.[0];
  return m?.type === 'video' || String(m?.fileUrl || m?.fileName || '').match(/\.(mp4|webm|mov|m3u8)$/i);
};

// ─── Delete confirm modal ──────────────────────────────────────────────────────
const DeleteModal = ({ isOpen, onClose, onConfirm, isDeleting }) => {
  if (!isOpen) return null;
  return (
    <div className="fixed inset-0 z-[60] flex items-center justify-center bg-black/50 backdrop-blur-sm p-4">
      <div className="bg-white dark:bg-gray-900 rounded-xl p-6 w-full max-w-sm shadow-2xl border border-gray-100 dark:border-gray-800">
        {isDeleting ? (
          <div className="flex flex-col items-center py-8">
            <Loader2 className="animate-spin w-10 h-10 text-red-500 mb-3" />
            <p className="text-gray-500 font-medium animate-pulse">Deleting comment…</p>
          </div>
        ) : (
          <>
            <h3 className="text-lg font-bold text-gray-900 dark:text-white mb-2 text-center">Delete comment?</h3>
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

// ─── Main Page ─────────────────────────────────────────────────────────────────
const MobileAdsDetail = () => {
  const { adId } = useParams();
  const navigate = useNavigate();
  const { userObject } = useSelector((state) => state.auth);

  const [ad, setAd] = useState(null);
  const [loading, setLoading] = useState(true);

  // media carousel
  const [mediaIndex, setMediaIndex] = useState(0);
  const [isMuted, setIsMuted] = useState(true);

  // like / save
  const [isLiked, setIsLiked] = useState(false);
  const [likeCount, setLikeCount] = useState(0);
  const [isSaved, setIsSaved] = useState(false);

  // comments
  const [comments, setComments] = useState([]);
  const [replies, setReplies] = useState({});
  const [expandedComments, setExpandedComments] = useState({});
  const [commentsLoading, setCommentsLoading] = useState(false);
  const [replyTo, setReplyTo] = useState(null);
  const [newComment, setNewComment] = useState('');

  // modals
  const [showReport, setShowReport] = useState(false);
  const [deleteTarget, setDeleteTarget] = useState(null); // { id, type: 'comment'|'reply' }
  const [isDeleting, setIsDeleting] = useState(false);

  const commentsRef = useRef(null);
  const currentUserId = userObject?._id || userObject?.id;
  const commentingOff = ad?.turn_off_commenting || ad?.engagement_controls?.turn_off_commenting;
  const vendor = ad?.vendor_id;
  const adUser = ad?.user_id;

  // ── Fetch ──────────────────────────────────────────────────────────────────
  useEffect(() => {
    if (adId) fetchAd();
  }, [adId]);

  const fetchAd = async () => {
    setLoading(true);
    try {
      const { data } = await api.get(`/ads/${adId}`);
      const adData = data?.data ?? data;
      setAd(adData);
      setIsLiked(adData?.is_liked_by_me ?? false);
      setLikeCount(adData?.likes_count ?? 0);
      await fetchComments(adId);
    } catch (e) {
      console.error('Failed to fetch ad:', e);
    } finally {
      setLoading(false);
    }
  };

  const fetchComments = async (id = adId) => {
    setCommentsLoading(true);
    try {
      const data = await adCommentService.getComments(id);
      const list = Array.isArray(data) ? data : (data?.comments || data?.data || []);
      setComments(list);
      // Pre-load replies
      list.forEach(c => {
        const cid = c._id || c.id;
        adCommentService.getReplies(cid)
          .then(r => { if (r?.length) setReplies(prev => ({ ...prev, [cid]: r })); })
          .catch(() => {});
      });
    } catch (e) {
      console.error('Failed to fetch comments:', e);
    } finally {
      setCommentsLoading(false);
    }
  };

  const loadReplies = async (commentId) => {
    try {
      const data = await adCommentService.getReplies(commentId);
      setReplies(prev => ({ ...prev, [commentId]: data || [] }));
    } catch (e) {
      console.error('Failed to load replies:', e);
    }
  };

  // ── Like / Save ────────────────────────────────────────────────────────────
  const handleLike = async () => {
    const prev = isLiked;
    setIsLiked(!prev);
    setLikeCount(c => c + (prev ? -1 : 1));
    try {
      await api.post(`/ads/${adId}/${prev ? 'dislike' : 'like'}`);
    } catch (e) {
      setIsLiked(prev);
      setLikeCount(c => c + (prev ? 1 : -1));
    }
  };

  const handleSave = async () => {
    const prev = isSaved;
    setIsSaved(!prev);
    try {
      if (prev) await api.delete(`/saved/ads/${adId}`);
      else await api.post(`/saved/ads/${adId}`);
    } catch (e) {
      setIsSaved(prev);
    }
  };

  // ── Comment like (optimistic) ──────────────────────────────────────────────
  const handleLikeComment = async (commentId, isLikedByMe) => {
    const patch = (arr) => arr.map(c => {
      if (String(c._id || c.id) !== String(commentId)) return c;
      return { ...c, is_liked_by_me: !isLikedByMe, likes_count: (c.likes_count ?? 0) + (isLikedByMe ? -1 : 1) };
    });
    const revert = (arr) => arr.map(c => {
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
      if (isLikedByMe) await adCommentService.unlikeComment(commentId);
      else await adCommentService.likeComment(commentId);
    } catch (e) {
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
    try {
      const parentId = replyTo?.id ?? null;
      await adCommentService.createComment(adId, newComment.trim(), parentId);
      setNewComment('');
      if (replyTo) {
        await loadReplies(replyTo.rootId ?? replyTo.id);
        setExpandedComments(prev => ({ ...prev, [replyTo.rootId ?? replyTo.id]: true }));
        setReplyTo(null);
      } else {
        await fetchComments();
      }
    } catch (e) {
      console.error('Failed to post comment:', e);
    }
  };

  // ── Delete ─────────────────────────────────────────────────────────────────
  const confirmDelete = (id, type) => setDeleteTarget({ id, type });

  const executeDelete = async () => {
    if (!deleteTarget) return;
    setIsDeleting(true);
    try {
      await adCommentService.deleteComment(deleteTarget.id);
      if (deleteTarget.type === 'reply') {
        setReplies(prev => {
          const next = {};
          for (const [k, arr] of Object.entries(prev)) {
            next[k] = arr.filter(r => String(r._id || r.id) !== String(deleteTarget.id));
          }
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

  // ── Media helpers ──────────────────────────────────────────────────────────
  const mediaItems = ad?.media?.length ? ad.media : [];
  const currentMedia = mediaItems[mediaIndex];
  const adIsVideo = currentMedia?.type === 'video' || String(currentMedia?.fileUrl || '').match(/\.(mp4|webm|mov|m3u8)$/i);
  const src = currentMedia?.fileUrl?.startsWith('http')
    ? currentMedia.fileUrl
    : currentMedia?.fileName ? `${BASE_URL}/uploads/${currentMedia.fileName}` : null;

  // ── Comment render ─────────────────────────────────────────────────────────
  const renderComment = (comment, isReply = false) => {
    const cid = comment._id || comment.id;
    const user = (typeof comment.user_id === 'object' ? comment.user_id : null) || comment.user || comment.users || {};
    const userId = user._id || user.id || (typeof comment.user_id === 'string' ? comment.user_id : null);
    const isLikedByMe = comment.is_liked_by_me ?? false;
    const likesCount = comment.likes_count ?? 0;
    const isOwner = currentUserId && String(userId) === String(currentUserId);
    const commentReplies = replies[cid] || [];
    const replyCount = comment.reply_count ?? comment.replies_count ?? commentReplies.length ?? 0;
    const hasReplies = replyCount > 0 || commentReplies.length > 0;

    return (
      <div key={cid} className={`flex gap-3 mb-4 ${isReply ? 'ml-11' : ''}`}>
        <div className="w-8 h-8 rounded-full bg-gray-200 dark:bg-gray-800 overflow-hidden shrink-0">
          {(user?.avatar_url || user?.profile_picture) ? (
            <img src={user.avatar_url || user.profile_picture} alt={user?.username} className="w-full h-full object-cover" />
          ) : (
            <div className="w-full h-full flex items-center justify-center text-xs font-bold text-gray-700 dark:text-gray-300">
              {(user?.username || user?.full_name || 'U')[0].toUpperCase()}
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
                  <button className="font-semibold" onClick={() => setReplyTo({ id: cid, rootId: cid, username: user?.username || user?.full_name })}>
                    Reply
                  </button>
                )}
              </div>
            </div>
            <div className="flex items-center gap-2 shrink-0">
              <button onClick={() => handleLikeComment(cid, isLikedByMe)} className={`flex flex-col items-center gap-0.5 transition-colors ${isLikedByMe ? 'text-red-500' : 'text-gray-400 dark:text-gray-600'}`}>
                <Heart size={12} fill={isLikedByMe ? 'currentColor' : 'none'} />
              </button>
              {isOwner && (
                <button onClick={() => confirmDelete(cid, isReply ? 'reply' : 'comment')} className="text-gray-400 dark:text-gray-600 hover:text-red-500 transition-colors">
                  <Trash2 size={12} />
                </button>
              )}
            </div>
          </div>

          {/* View replies */}
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
                {expandedComments[cid]
                  ? 'Hide replies'
                  : `View ${replyCount > 0 ? replyCount : ''} ${replyCount === 1 ? 'reply' : 'replies'}`}
              </button>
            </div>
          )}

          {/* Nested replies */}
          {!isReply && expandedComments[cid] && commentReplies.length > 0 && (
            <div className="mt-2">
              {commentReplies.map(r => renderComment(r, true))}
            </div>
          )}
        </div>
      </div>
    );
  };

  // ── States ─────────────────────────────────────────────────────────────────
  if (loading) {
    return (
      <div className="min-h-screen bg-white dark:bg-black flex items-center justify-center">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-gray-900 dark:border-white" />
      </div>
    );
  }

  if (!ad) {
    return (
      <div className="min-h-screen bg-white dark:bg-black flex flex-col items-center justify-center p-4">
        <p className="text-gray-500 mb-4">Ad not found</p>
        <button onClick={() => navigate(-1)} className="text-blue-500 font-semibold">Go Back</button>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-white dark:bg-black pb-20 max-w-[1100px] mx-auto">
      {/* ── Header ─────────────────────────────────────────────────────────── */}
      <div className="sticky top-0 bg-white dark:bg-black z-50 px-4 py-3 flex items-center justify-between border-b border-gray-100 dark:border-gray-800">
        <button onClick={() => navigate(-1)} className="text-gray-900 dark:text-white">
          <ArrowLeft size={24} />
        </button>
        <h1 className="text-lg font-bold text-gray-900 dark:text-white">Ad</h1>
        <button onClick={() => setShowReport(true)} className="text-gray-900 dark:text-white p-1">
          <MoreHorizontal size={20} />
        </button>
      </div>

      {/* ── Vendor info ─────────────────────────────────────────────────────── */}
      <div className="px-4 py-3 flex items-center gap-3">
        <div className="w-10 h-10 rounded-full overflow-hidden bg-gradient-to-tr from-orange-400 to-pink-500 flex items-center justify-center shrink-0">
          {adUser?.avatar_url ? (
            <img src={adUser.avatar_url} alt={adUser?.username} className="w-full h-full object-cover" />
          ) : (
            <span className="text-white text-sm font-bold">
              {(vendor?.business_name || adUser?.username || 'A')[0].toUpperCase()}
            </span>
          )}
        </div>
        <div className="flex-1 min-w-0">
          <p className="font-semibold text-sm text-gray-900 dark:text-white leading-tight">
            {vendor?.business_name || adUser?.username || adUser?.full_name || 'Sponsored'}
          </p>
          {ad.category && (
            <div className="flex items-center gap-1 mt-0.5">
              <ShoppingBag size={11} className="text-gray-400" />
              <span className="text-xs text-gray-500 dark:text-gray-400">{ad.category}</span>
            </div>
          )}
        </div>
        <span className="text-[10px] text-gray-400 border border-gray-200 dark:border-gray-700 rounded px-1.5 py-0.5">Sponsored</span>
      </div>

      {/* ── Media ───────────────────────────────────────────────────────────── */}
      {src && (
        <div className="w-full bg-black relative group">
          <div className="aspect-[4/5] w-full flex items-center justify-center bg-black">
            {adIsVideo ? (
              <div className="relative w-full h-full">
                <video
                  src={src}
                  className="w-full h-full object-contain"
                  controls={false}
                  autoPlay
                  muted={isMuted}
                  loop
                  playsInline
                  onClick={() => setIsMuted(m => !m)}
                />
                <button
                  onClick={() => setIsMuted(m => !m)}
                  className="absolute bottom-3 right-3 bg-black/50 rounded-full p-2 text-white"
                >
                  {isMuted ? <VolumeX size={16} /> : <Volume2 size={16} />}
                </button>
              </div>
            ) : (
              <img src={src} alt="Ad media" className="w-full h-full object-contain" />
            )}
          </div>

          {/* Carousel arrows */}
          {mediaItems.length > 1 && (
            <>
              <button
                onClick={() => setMediaIndex(i => Math.max(0, i - 1))}
                className="absolute left-2 top-1/2 -translate-y-1/2 bg-black/50 text-white p-1.5 rounded-full"
              >
                <ChevronLeft size={20} />
              </button>
              <button
                onClick={() => setMediaIndex(i => Math.min(mediaItems.length - 1, i + 1))}
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
            <button onClick={handleLike} className="flex items-center gap-1.5">
              <Heart size={26} className={`transition-colors ${isLiked ? 'fill-red-500 text-red-500' : 'text-gray-900 dark:text-white'}`} />
            </button>
            {!commentingOff && (
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
            <Bookmark size={26} fill={isSaved ? 'currentColor' : 'none'} />
          </button>
        </div>

        {likeCount > 0 && (
          <div className="font-semibold text-sm text-gray-900 dark:text-white mb-1">{likeCount} likes</div>
        )}

        {/* Caption */}
        {(ad.content || ad.caption || ad.description) && (
          <div className="text-sm text-gray-900 dark:text-white mb-1">
            <span className="font-semibold mr-2">{vendor?.business_name || adUser?.username || 'Sponsored'}</span>
            {ad.content || ad.caption || ad.description}
          </div>
        )}
        <div className="text-[10px] text-gray-500 uppercase tracking-wide pt-1">
          {formatTimeAgo(ad.createdAt || ad.created_at)}
        </div>
      </div>

      {/* ── Comments ────────────────────────────────────────────────────────── */}
      {!commentingOff && (
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
            <p className="text-center text-gray-500 text-sm py-4">No comments yet. Be the first!</p>
          )}
        </div>
      )}

      {/* ── Fixed comment input ─────────────────────────────────────────────── */}
      {!commentingOff && (
        <div className="fixed bottom-0 left-0 right-0 border-t border-gray-100 dark:border-gray-800 bg-white dark:bg-black z-40 p-3">
          {replyTo && (
            <div className="px-3 py-2 bg-gray-50 dark:bg-gray-900 flex justify-between items-center text-xs text-gray-500 mb-2 rounded">
              <span>Replying to <span className="font-semibold">{replyTo.username}</span></span>
              <button onClick={() => setReplyTo(null)}><X size={14} /></button>
            </div>
          )}
          <form onSubmit={handlePostComment} className="flex items-center gap-3">
            <button type="button" className="text-gray-900 dark:text-white">
              <Smile size={24} />
            </button>
            <input
              type="text"
              placeholder={replyTo ? `Reply to ${replyTo.username}…` : 'Add a comment…'}
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
      />
      <ContentReportModal
        isOpen={showReport}
        onClose={() => setShowReport(false)}
        contentType="ad"
        contentId={adId}
        ownerUsername={vendor?.business_name || adUser?.username || ''}
        contentUrl={window.location.href}
      />
    </div>
  );
};

export default MobileAdsDetail;
