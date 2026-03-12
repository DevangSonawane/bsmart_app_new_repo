import React, { useState, useRef, useEffect, useCallback } from 'react';
import {
  Heart, MessageCircle, Send, MoreHorizontal, Music2,
  Volume2, VolumeX, Bookmark, Loader2, X, Trash2
} from 'lucide-react';
import { useSelector } from 'react-redux';
import commentService from '../services/commentService';
import api from '../lib/api';

const BASE_URL = 'https://api.bebsmart.in/api';

const getToken = () => localStorage.getItem('token');
const authHeaders = () => ({
  'Authorization': `Bearer ${getToken()}`,
  'Content-Type': 'application/json',
});

// ─── Helpers ──────────────────────────────────────────────────────────────────
const formatCount = (count) => {
  if (!count && count !== 0) return '0';
  if (count >= 1000000) return `${(count / 1000000).toFixed(1)}M`;
  if (count >= 1000) return `${(count / 1000).toFixed(1)}k`;
  return count.toString();
};

const formatTimeAgo = (dateString) => {
  if (!dateString) return '';
  const date = new Date(dateString);
  if (isNaN(date.getTime())) return '';
  const diff = Math.floor((Date.now() - date) / 1000);
  if (diff < 60) return `${Math.max(0, diff)}s`;
  if (diff < 3600) return `${Math.floor(diff / 60)}m`;
  if (diff < 86400) return `${Math.floor(diff / 3600)}h`;
  if (diff < 604800) return `${Math.floor(diff / 86400)}d`;
  return `${Math.floor(diff / 604800)}w`;
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
            <button onClick={() => setExpanded(false)} className="text-white/60 ml-1.5 hover:text-white transition-colors text-xs font-semibold">less</button>
          )}
        </>
      ) : (
        <>
          {preview}
          <button onClick={() => setExpanded(true)} className="text-white/60 ml-1 hover:text-white transition-colors font-medium">... more</button>
        </>
      )}
    </p>
  );
};

// ─── Follow Button ────────────────────────────────────────────────────────────
const FollowButton = ({ userId, initialFollowing = false }) => {
  const [following, setFollowing] = useState(initialFollowing);
  const [loading, setLoading] = useState(false);

  const handleToggle = async (e) => {
    e.stopPropagation();
    if (loading || !userId) return;
    setLoading(true);
    const wasFollowing = following;
    setFollowing(!wasFollowing);
    try {
      const endpoint = wasFollowing ? `${BASE_URL}/unfollow` : `${BASE_URL}/follow`;
      const res = await fetch(endpoint, {
        method: 'POST',
        headers: authHeaders(),
        body: JSON.stringify({ followedUserId: String(userId) }),
      });
      if (!res.ok) setFollowing(wasFollowing);
    } catch (e) {
      console.error('Follow error:', e);
      setFollowing(wasFollowing);
    } finally {
      setLoading(false);
    }
  };

  return (
    <button
      onClick={handleToggle}
      disabled={loading}
      className={`px-3 py-1 rounded-lg text-[12px] font-semibold transition-all backdrop-blur-sm flex-shrink-0 disabled:opacity-60 ${
        following
          ? 'border border-white/30 bg-white/10 text-white hover:bg-red-500/20 hover:border-red-400/40'
          : 'border border-white/40 bg-white/10 text-white hover:bg-white/25'
      }`}
    >
      {loading ? <Loader2 size={10} className="animate-spin inline" /> : following ? 'Following' : 'Follow'}
    </button>
  );
};

// ─── Avatar ───────────────────────────────────────────────────────────────────
const Avatar = ({ src, username, size = 'md' }) => {
  const dim =
    size === 'xs' ? 'w-7 h-7 text-[10px]' :
    size === 'sm' ? 'w-8 h-8 text-xs' :
    'w-9 h-9 text-sm';
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

// ─── CommentsUI ───────────────────────────────────────────────────────────────
// Mirrors PostDetailModal comment logic exactly:
//   - uses commentService for all API calls
//   - replies stored in parent-level state { [commentId]: [] }
//   - auto-loads replies for every comment on fetch
//   - expandedComments tracks open/closed state per comment
const CommentsUI = ({ reel, onClose, userObject }) => {
  const reelId = reel?._id || reel?.post_id;
  const currentUserId = userObject?._id || userObject?.id;

  // Same state shape as PostDetailModal
  const [comments, setComments] = useState([]);
  const [replies, setReplies] = useState({});             // { [commentId]: reply[] }
  const [expandedComments, setExpandedComments] = useState({}); // { [commentId]: bool }
  const [replyTo, setReplyTo] = useState(null);           // { id, username }
  const [newComment, setNewComment] = useState('');
  const [isLoadingComments, setIsLoadingComments] = useState(false);
  const [posting, setPosting] = useState(false);

  const inputRef = useRef(null);
  const scrollRef = useRef(null);
  const currentUserAvatar = userObject?.avatar_url || null;
  const currentUserName = userObject?.full_name || userObject?.username || 'You';

  // ── fetchComments — identical to PostDetailModal ───────────────────────────
  const fetchComments = useCallback(async (postId = null) => {
    try {
      const id = postId || reelId;
      if (!id) return;
      const data = await commentService.getComments(id);
      setComments(data || []);
      // Auto-load replies for every comment, same as PostDetailModal
      if (data && Array.isArray(data)) {
        data.forEach((comment) => {
          const commentId = comment._id || comment.id;
          commentService.getReplies(commentId)
            .then((repliesData) => {
              if (repliesData && repliesData.length > 0) {
                setReplies((prev) => ({ ...prev, [commentId]: repliesData }));
              }
            })
            .catch((err) => console.error('Error auto-loading replies:', err));
        });
      }
    } catch (error) {
      console.error('Error fetching comments:', error);
    }
  }, [reelId]);

  // ── loadReplies — identical to PostDetailModal ─────────────────────────────
  const loadReplies = useCallback(async (commentId) => {
    try {
      const data = await commentService.getReplies(commentId);
      setReplies((prev) => ({ ...prev, [commentId]: data }));
    } catch (error) {
      console.error('Error loading replies:', error);
    }
  }, []);

  // ── Initial fetch when reel changes ───────────────────────────────────────
  useEffect(() => {
    if (!reelId) return;
    setIsLoadingComments(true);
    setComments([]);
    setReplies({});
    setExpandedComments({});
    setReplyTo(null);
    setNewComment('');
    fetchComments(reelId).finally(() => setIsLoadingComments(false));
  }, [reelId, fetchComments]);

  useEffect(() => { if (replyTo) inputRef.current?.focus(); }, [replyTo]);

  // ── handlePostComment — identical to PostDetailModal ──────────────────────
  const handlePostComment = async () => {
    if (!newComment.trim() || posting || !userObject) return;
    setPosting(true);
    try {
      const parentId = replyTo ? replyTo.id : null;
      await commentService.createComment(reelId, newComment.trim(), parentId);
      setNewComment('');
      await fetchComments(reelId);
      if (replyTo) {
        await loadReplies(replyTo.id);
        setExpandedComments((prev) => ({ ...prev, [replyTo.id]: true }));
        setReplyTo(null);
      }
    } catch (error) {
      console.error('Error posting comment:', error);
    } finally {
      setPosting(false);
    }
  };

  // ── handleLikeComment — identical to PostDetailModal ──────────────────────
  const handleLikeComment = async (commentId, isLikedByMe) => {
    try {
      if (isLikedByMe) {
        await commentService.unlikeComment(commentId);
      } else {
        await commentService.likeComment(commentId);
      }
      fetchComments(reelId);
      Object.keys(replies).forEach((key) => loadReplies(key));
    } catch (error) {
      console.error('Error liking comment:', error);
    }
  };

  // ── handleDeleteComment — identical to PostDetailModal ────────────────────
  const handleDeleteComment = async (commentId) => {
    if (!window.confirm('Are you sure you want to delete this comment?')) return;
    try {
      await api.delete(`/comments/${commentId}`);
      await fetchComments(reelId);
    } catch (error) {
      console.error('Error deleting comment:', error);
    }
  };

  // ── renderComment — identical logic to PostDetailModal ────────────────────
  const renderComment = (comment, isReply = false) => {
    const commentId = comment._id || comment.id;
    const user = comment.user || comment.users;
    const isLikedByMe = comment.is_liked_by_me || (
      comment.likes && Array.isArray(comment.likes) &&
      comment.likes.some((l) => {
        if (!currentUserId) return false;
        if (typeof l === 'string') return l === currentUserId;
        return (l.user_id || l._id || l.id) === currentUserId;
      })
    );
    const likesCount = comment.likes_count || (comment.likes ? comment.likes.length : 0);
    const hasReplies =
      comment.reply_count > 0 ||
      (replies[commentId] && replies[commentId].length > 0) ||
      (comment.replies && comment.replies.length > 0);
    const isOwner = currentUserId && (
      (user && (String(user._id) === String(currentUserId) || String(user.id) === String(currentUserId))) ||
      (comment.user_id && String(comment.user_id) === String(currentUserId))
    );

    return (
      <div key={commentId} className={`flex gap-3 mb-4 ${isReply ? 'ml-10 pr-4' : 'px-4'}`}>
        {/* Avatar */}
        <div className="w-8 h-8 rounded-full bg-gray-200 dark:bg-gray-700 overflow-hidden shrink-0">
          {user?.avatar_url ? (
            <img src={user.avatar_url} alt={user?.username} className="w-full h-full object-cover" />
          ) : (
            <div className="w-full h-full flex items-center justify-center text-xs font-bold text-gray-700 dark:text-gray-300">
              {user?.username ? user.username.charAt(0).toUpperCase() : 'U'}
            </div>
          )}
        </div>

        {/* Body */}
        <div className="flex-1 text-sm group">
          <div className="flex justify-between items-start gap-2">
            <div className="flex-1 min-w-0">
              <span className="font-semibold mr-1.5 dark:text-white text-gray-900">{user?.username}</span>
              <span className="text-gray-800 dark:text-gray-200 break-words">{comment.text || comment.content}</span>
              <div className="text-gray-400 dark:text-gray-500 text-xs mt-1 flex gap-3 items-center flex-wrap">
                <span>{formatTimeAgo(comment.createdAt || comment.created_at)}</span>
                {likesCount > 0 && <span>{likesCount} {likesCount === 1 ? 'like' : 'likes'}</span>}
                {!isReply && (
                  <button
                    className="font-semibold hover:text-gray-900 dark:hover:text-white transition-colors"
                    onClick={() => setReplyTo({ id: commentId, username: user?.username })}
                  >
                    Reply
                  </button>
                )}
              </div>
            </div>

            {/* Like + Delete */}
            <div className="flex items-center gap-2 shrink-0 pt-0.5">
              <button
                onClick={() => handleLikeComment(commentId, isLikedByMe)}
                className={`transition-colors ${isLikedByMe ? 'text-red-500' : 'text-gray-400 dark:text-gray-500 hover:text-gray-600 dark:hover:text-gray-300'}`}
              >
                <Heart size={12} fill={isLikedByMe ? 'currentColor' : 'none'} />
              </button>
              {isOwner && (
                <button
                  onClick={() => handleDeleteComment(commentId)}
                  className="text-gray-400 dark:text-gray-500 hover:text-red-500 transition-colors opacity-0 group-hover:opacity-100"
                >
                  <Trash2 size={12} />
                </button>
              )}
            </div>
          </div>

          {/* View / Hide replies — only on top-level comments, same as PostDetailModal */}
          {!isReply && hasReplies && (
            <div className="mt-2">
              <button
                className="text-xs text-gray-500 dark:text-gray-400 flex items-center gap-2 hover:text-gray-900 dark:hover:text-white transition-colors"
                onClick={() => {
                  if (!replies[commentId] && !comment.replies) loadReplies(commentId);
                  setExpandedComments((prev) => ({ ...prev, [commentId]: !prev[commentId] }));
                }}
              >
                <div className="w-6 h-px bg-gray-400 dark:bg-gray-600" />
                <span className="font-semibold">
                  {expandedComments[commentId]
                    ? 'Hide replies'
                    : `View replies (${
                        comment.reply_count ||
                        (comment.replies ? comment.replies.length : 0) ||
                        (replies[commentId] ? replies[commentId].length : '')
                      })`
                  }
                </span>
              </button>
            </div>
          )}

          {/* Expanded replies — same as PostDetailModal */}
          {!isReply && expandedComments[commentId] && (replies[commentId] || comment.replies) && (
            <div className="mt-2">
              {(replies[commentId] || comment.replies).map((reply) => renderComment(reply, true))}
            </div>
          )}
        </div>
      </div>
    );
  };

  return (
    <div className="flex flex-col h-full bg-white dark:bg-[#262626]">
      {/* Header */}
      <div className="flex items-center justify-between px-4 py-3 border-b border-gray-100 dark:border-white/10 shrink-0">
        <span className="font-bold text-sm dark:text-white text-gray-900">Comments ({comments.length})</span>
        <button onClick={onClose} className="p-1 hover:bg-gray-100 dark:hover:bg-white/10 rounded-full text-gray-500 dark:text-gray-400 transition-colors">
          <X size={20} />
        </button>
      </div>

      {/* Comments list */}
      <div ref={scrollRef} className="flex-1 overflow-y-auto py-3 scrollbar-none">
        {isLoadingComments ? (
          <div className="flex justify-center py-8 text-gray-400">
            <Loader2 className="animate-spin" />
          </div>
        ) : comments.length === 0 ? (
          <div className="flex flex-col items-center justify-center h-40 text-gray-400 text-sm gap-2">
            <MessageCircle size={32} className="opacity-40" />
            No comments yet. Be the first!
          </div>
        ) : (
          comments.map((comment) => renderComment(comment))
        )}
      </div>

      {/* Input footer */}
      <div className="border-t border-gray-100 dark:border-white/10 bg-white dark:bg-[#262626] shrink-0"
        style={{ paddingBottom: 'env(safe-area-inset-bottom, 0px)' }}
      >
        {replyTo && (
          <div className="flex items-center justify-between text-xs text-gray-500 dark:text-gray-400 px-4 pt-2">
            <span>Replying to <span className="font-bold text-blue-500">@{replyTo.username}</span></span>
            <button onClick={() => setReplyTo(null)} className="hover:text-gray-900 dark:hover:text-white">
              <X size={13} />
            </button>
          </div>
        )}
        <div className="flex items-center gap-2 px-3 py-3">
          <Avatar src={currentUserAvatar} username={currentUserName} size="xs" />
          <div className="flex-1 flex items-center gap-2 bg-gray-100 dark:bg-white/10 rounded-full px-3 py-2">
            <input
              ref={inputRef}
              type="text"
              placeholder={replyTo ? `Reply to @${replyTo.username}...` : 'Add a comment...'}
              className="flex-1 bg-transparent border-none outline-none text-sm dark:text-white text-gray-900 placeholder:text-gray-400"
              value={newComment}
              onChange={(e) => setNewComment(e.target.value)}
              onKeyDown={(e) => e.key === 'Enter' && handlePostComment()}
            />
            <button
              onClick={handlePostComment}
              disabled={!newComment.trim() || posting}
              className="text-blue-500 disabled:opacity-40 font-semibold text-sm hover:text-blue-600 transition-colors shrink-0"
            >
              {posting ? <Loader2 size={14} className="animate-spin" /> : 'Post'}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};

// ─── Desktop Comments Side Panel ──────────────────────────────────────────────
const CommentsPopup = ({ reel, onClose, userObject, anchorRight }) => (
  <div
    className="hidden md:block fixed z-50"
    style={{
      top: '16%',
      left: `${anchorRight}px`,
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
      <CommentsUI reel={reel} onClose={onClose} userObject={userObject} />
    </div>
  </div>
);

// ─── Mobile Bottom Sheet ──────────────────────────────────────────────────────
const CommentsBottomSheet = ({ reel, onClose, userObject }) => (
  <div className="flex flex-col h-full rounded-t-2xl overflow-hidden bg-white dark:bg-[#262626]">
    <div className="flex justify-center pt-3 pb-0 flex-shrink-0">
      <div className="w-10 h-1 rounded-full bg-gray-300 dark:bg-white/25" />
    </div>
    <CommentsUI reel={reel} onClose={onClose} userObject={userObject} />
  </div>
);

// ─── Main Reels Component ─────────────────────────────────────────────────────
const Reels = () => {
  const [reels, setReels] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [currentIndex, setCurrentIndex] = useState(0);
  const [isMuted, setIsMuted] = useState(true);
  const [touchStartY, setTouchStartY] = useState(null);
  const [videoErrors, setVideoErrors] = useState({});
  const [commentsOpen, setCommentsOpen] = useState(false);
  const isAnimatingRef = useRef(false);
  const videoRefs = useRef({});
  const actionPanelRef = useRef(null);
  const [actionPanelRight, setActionPanelRight] = useState(100);

  const { userObject } = useSelector((state) => state.auth);

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
  }, [reels, currentIndex]);

  useEffect(() => {
    const fetchReels = async () => {
      try {
        setLoading(true);
        const res = await fetch(`${BASE_URL}/posts/reels`, { headers: authHeaders() });
        if (!res.ok) throw new Error('Failed to fetch reels');
        const data = await res.json();
        setReels(data);
      } catch (err) { setError(err.message); }
      finally { setLoading(false); }
    };
    fetchReels();
  }, []);

  useEffect(() => {
    Object.entries(videoRefs.current).forEach(([index, video]) => {
      if (!video) return;
      if (parseInt(index) === currentIndex) video.play().catch(() => {});
      else { video.pause(); video.currentTime = 0; }
    });
  }, [currentIndex, reels]);

  const goToIndex = useCallback((index) => {
    if (isAnimatingRef.current) return;
    const next = Math.min(reels.length - 1, Math.max(0, index));
    if (next === currentIndex) return;
    isAnimatingRef.current = true;
    setCurrentIndex(next);
    setCommentsOpen(false);
    setTimeout(() => { isAnimatingRef.current = false; }, 500);
  }, [currentIndex, reels.length]);

  const handleWheel = (e) => {
    if (commentsOpen) return;
    if (Math.abs(e.deltaY) < 20) return;
    goToIndex(e.deltaY > 0 ? currentIndex + 1 : currentIndex - 1);
  };

  const handleKeyDown = useCallback((e) => {
    if (commentsOpen) return;
    if (e.key === 'ArrowDown') goToIndex(currentIndex + 1);
    else if (e.key === 'ArrowUp') goToIndex(currentIndex - 1);
  }, [currentIndex, commentsOpen, goToIndex]);

  useEffect(() => {
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [handleKeyDown]);

  const handleTouchStart = (e) => {
    if (commentsOpen) return;
    if (e.touches?.[0]) setTouchStartY(e.touches[0].clientY);
  };
  const handleTouchEnd = (e) => {
    if (commentsOpen) return;
    if (touchStartY == null || !e.changedTouches?.[0]) return;
    const diff = touchStartY - e.changedTouches[0].clientY;
    if (Math.abs(diff) > 50) goToIndex(currentIndex + (diff > 0 ? 1 : -1));
    setTouchStartY(null);
  };

  const handleLike = async (reelId, isLiked) => {
    const endpoint = isLiked ? `${BASE_URL}/posts/${reelId}/unlike` : `${BASE_URL}/posts/${reelId}/like`;
    setReels(prev => prev.map(r => {
      if ((r._id || r.post_id) !== reelId) return r;
      return { ...r, is_liked_by_me: !isLiked, likes_count: isLiked ? (r.likes_count || 1) - 1 : (r.likes_count || 0) + 1 };
    }));
    try { await fetch(endpoint, { method: 'POST', headers: authHeaders() }); }
    catch {
      setReels(prev => prev.map(r => {
        if ((r._id || r.post_id) !== reelId) return r;
        return { ...r, is_liked_by_me: isLiked, likes_count: isLiked ? (r.likes_count || 0) + 1 : (r.likes_count || 1) - 1 };
      }));
    }
  };

  const handleSave = async (reelId, isSaved) => {
    const endpoint = isSaved ? `${BASE_URL}/posts/${reelId}/unsave` : `${BASE_URL}/posts/${reelId}/save`;
    setReels(prev => prev.map(r => (r._id || r.post_id) === reelId ? { ...r, is_saved_by_me: !isSaved } : r));
    try { await fetch(endpoint, { method: 'POST', headers: authHeaders() }); }
    catch { setReels(prev => prev.map(r => (r._id || r.post_id) === reelId ? { ...r, is_saved_by_me: isSaved } : r)); }
  };

  const handleShare = (reel) => {
    const reelId = reel._id || reel.post_id;
    const url = `${window.location.origin}/reels/${reelId}`;
    if (navigator.share) navigator.share({ title: reel.caption || 'Check this reel!', url }).catch(() => {});
    else navigator.clipboard?.writeText(url);
  };

  const getVideoUrl = (reel) => reel.media?.[0]?.fileUrl || null;
  const getThumbnail = (reel) => reel.media?.[0]?.thumbnail?.fileUrl || reel.user_id?.avatar_url || null;
  const getAspectClass = (reel) => {
    const ratio =
      reel.media?.[0]?.crop?.aspect_ratio ||
      reel.media?.[0]?.aspect_ratio ||
      reel.crop?.aspect_ratio ||
      reel.aspect_ratio;
    if (ratio === '1:1') return 'aspect-[1/1]';
    if (ratio === '16:9') return 'aspect-[16/9]';
    if (ratio === '4:5') return 'aspect-[4/5]';
    return 'aspect-[9/16]';
  };

  if (loading) return (
    <div className="w-full h-screen flex justify-center items-center dark:bg-black bg-white">
      <div className="flex flex-col items-center gap-3">
        <Loader2 size={36} className="text-white animate-spin" />
        <span className="text-white/60 text-sm">Loading reels...</span>
      </div>
    </div>
  );

  if (error) return (
    <div className="w-full h-screen flex justify-center items-center bg-black">
      <div className="flex flex-col items-center gap-4 px-6 text-center">
        <span className="text-white font-semibold">Failed to load reels</span>
        <span className="text-white/50 text-sm">{error}</span>
        <button onClick={() => window.location.reload()} className="px-4 py-2 bg-white text-black rounded-full text-sm font-medium">Try again</button>
      </div>
    </div>
  );

  if (!reels.length) return (
    <div className="w-full h-screen flex justify-center items-center bg-black">
      <span className="text-white/60">No reels found</span>
    </div>
  );

  const currentReel = reels[currentIndex];
  const currentReelId = currentReel?._id || currentReel?.post_id;
  const commentCount = currentReel?.comments_count ?? currentReel?.comments?.length ?? 0;

  return (
    <>
      <div className="w-full lg:h-auto h-screen overflow-hidden flex items-center justify-center">
        <div className="flex items-end justify-center h-full lg:py-2 py-4 gap-4">

          {/* ── Video card ── */}
          <div
            className="relative bg-black flex-shrink-0 overflow-hidden
              w-screen h-screen
              md:w-[380px] md:h-[calc(100vh-2rem)] md:max-h-[760px] md:rounded-2xl
              md:shadow-[0_24px_80px_rgba(0,0,0,0.8)]"
            onWheel={handleWheel}
            onTouchStart={handleTouchStart}
            onTouchEnd={handleTouchEnd}
          >
            <div
              className="h-full w-full transition-transform duration-500 ease-out"
              style={{ transform: `translateY(-${currentIndex * 100}%)` }}
            >
              {reels.map((reel, index) => {
                const reelId = reel._id || reel.post_id;
                const videoUrl = getVideoUrl(reel);
                const thumbnail = getThumbnail(reel);
                const hasError = videoErrors[reelId];
                const aspectClass = getAspectClass(reel);

                return (
                  <div key={reelId || index} className="relative w-full h-full bg-black flex items-center justify-center">
                    <div className={`relative w-full max-h-full ${aspectClass} md:aspect-auto md:w-full md:h-full`}>
                      {videoUrl && !hasError ? (
                        <video
                          ref={el => { videoRefs.current[index] = el; }}
                          src={videoUrl}
                          poster={thumbnail || undefined}
                          className="w-full h-full object-contain"
                          loop muted={isMuted} playsInline
                          onError={() => setVideoErrors(prev => ({ ...prev, [reelId]: true }))}
                        />
                      ) : (
                        <div
                          className="w-full h-full bg-gray-900 flex items-center justify-center"
                          style={thumbnail ? { backgroundImage: `url(${thumbnail})`, backgroundSize: 'contain', backgroundRepeat: 'no-repeat', backgroundPosition: 'center' } : {}}
                        >
                          {!thumbnail && <Music2 size={48} className="text-white/30" />}
                        </div>
                      )}
                    </div>

                    <div className="absolute inset-0 pointer-events-none"
                      style={{ background: 'linear-gradient(to bottom, rgba(0,0,0,0.15) 0%, transparent 30%, transparent 55%, rgba(0,0,0,0.85) 100%)' }}
                    />

                    <button
                      onClick={() => setIsMuted(!isMuted)}
                      className="absolute lg:bottom-5 bottom-14 right-4 bg-black/40 p-2 rounded-full text-white backdrop-blur-sm z-20"
                    >
                      {isMuted ? <VolumeX size={16} /> : <Volume2 size={16} />}
                    </button>

                    {/* Mobile action buttons */}
                    <div className="md:hidden absolute right-3 top-[60%] -translate-y-1/2 flex flex-col gap-6 items-center z-20">
                      <div className="flex flex-col items-center gap-1">
                        <button onClick={() => handleLike(reelId, reel.is_liked_by_me)} className="active:scale-90 transition-transform">
                          <Heart size={27} className={reel.is_liked_by_me ? 'text-red-500' : 'text-white'} style={{ filter: 'drop-shadow(0 1px 3px rgba(0,0,0,0.6))' }} fill={reel.is_liked_by_me ? 'currentColor' : 'none'} />
                        </button>
                        <span className="text-white text-xs font-semibold" style={{ textShadow: '0 1px 3px rgba(0,0,0,0.8)' }}>{formatCount(reel.likes_count)}</span>
                      </div>

                      <div className="flex flex-col items-center gap-1">
                        <button onClick={() => { setCurrentIndex(index); setCommentsOpen(true); }} className="active:scale-90 transition-transform">
                          <MessageCircle size={27} className={commentsOpen && index === currentIndex ? 'text-blue-400' : 'text-white'} style={{ filter: 'drop-shadow(0 1px 3px rgba(0,0,0,0.6))' }} />
                        </button>
                        <span className="text-white text-xs font-semibold" style={{ textShadow: '0 1px 3px rgba(0,0,0,0.8)' }}>{formatCount(reel.comments_count ?? reel.comments?.length ?? 0)}</span>
                      </div>

                      <button onClick={() => handleShare(reel)} className="active:scale-90 transition-transform">
                        <Send size={25} className="text-white -rotate-12" style={{ filter: 'drop-shadow(0 1px 3px rgba(0,0,0,0.6))' }} />
                      </button>

                      <button className="active:scale-90 transition-transform">
                        <MoreHorizontal size={25} className="text-white" style={{ filter: 'drop-shadow(0 1px 3px rgba(0,0,0,0.6))' }} />
                      </button>

                      <div className="w-9 h-9 border-2 border-white/60 rounded-lg overflow-hidden shadow-lg">
                        {reel.user_id?.avatar_url
                          ? <img src={reel.user_id.avatar_url} className="w-full h-full object-cover" alt="" />
                          : <div className="w-full h-full bg-gradient-to-br from-orange-400 to-pink-500 flex items-center justify-center">
                              <span className="text-white text-xs font-bold">{(reel.user_id?.username || 'U')[0].toUpperCase()}</span>
                            </div>
                        }
                      </div>
                    </div>

                    {/* Bottom info */}
                    <div className="absolute lg:bottom-[0%] bottom-[8%] left-0 z-20 px-4 pb-6 pr-16" style={{ maxWidth: 'calc(100% - 56px)' }}>
                      <div className="flex items-center gap-2 mb-2">
                        <div className="w-8 h-8 rounded-full border-2 border-white/50 overflow-hidden flex-shrink-0">
                          {reel.user_id?.avatar_url
                            ? <img src={reel.user_id.avatar_url} className="w-full h-full object-cover" alt="user" />
                            : <div className="w-full h-full bg-gradient-to-br from-orange-400 to-pink-500 flex items-center justify-center">
                                <span className="text-white text-[10px] font-bold">{(reel.user_id?.username || 'U')[0].toUpperCase()}</span>
                              </div>
                          }
                        </div>
                        <span className="font-bold text-white text-sm truncate cursor-pointer" style={{ textShadow: '0 1px 3px rgba(0,0,0,0.8)' }}>
                          {reel.user_id?.username || reel.user_id?.full_name || 'Unknown'}
                        </span>
                        <FollowButton userId={reel.user_id?._id || reel.user_id?.id || reel.user_id} initialFollowing={reel.is_followed_by_me || false} />
                      </div>
                      <Caption text={reel.caption} />
                      {reel.tags?.length > 0 && (
                        <p className="text-white/80 text-xs mb-1.5">{reel.tags.map(t => `#${t}`).join(' ')}</p>
                      )}
                      <div className="flex items-center gap-1.5 text-white/90 text-xs mt-1">
                        <Music2 size={11} className="flex-shrink-0" />
                        <span className="truncate max-w-[180px]" style={{ textShadow: '0 1px 2px rgba(0,0,0,0.8)' }}>
                          Original Audio · {reel.user_id?.username || 'unknown'}
                        </span>
                      </div>
                    </div>
                  </div>
                );
              })}
            </div>
          </div>

          {/* Desktop action buttons */}
          <div ref={actionPanelRef} className="hidden md:flex flex-col gap-5 items-center pb-2 flex-shrink-0">
            <div className="flex flex-col items-center gap-1">
              <button onClick={() => handleLike(currentReelId, currentReel?.is_liked_by_me)} className="w-11 h-11 rounded-full bg-white/10 border border-white/20 backdrop-blur-sm flex items-center justify-center hover:scale-110 active:scale-95 transition-all shadow-lg">
                <Heart size={22} className={currentReel?.is_liked_by_me ? 'text-red-500' : 'text-white'} fill={currentReel?.is_liked_by_me ? 'currentColor' : 'none'} />
              </button>
              <span className="text-xs font-medium text-white">{formatCount(currentReel?.likes_count)}</span>
            </div>

            <div className="flex flex-col items-center gap-1">
              <button
                onClick={() => setCommentsOpen(v => !v)}
                className={`w-11 h-11 rounded-full backdrop-blur-sm border flex items-center justify-center hover:scale-110 active:scale-95 transition-all shadow-lg ${commentsOpen ? 'bg-blue-500 border-blue-400' : 'bg-white/10 border-white/20'}`}
              >
                <MessageCircle size={22} className="text-white" />
              </button>
              <span className="text-xs font-medium text-white">{formatCount(commentCount)}</span>
            </div>

            <button onClick={() => handleShare(currentReel)} className="w-11 h-11 rounded-full bg-white/10 border border-white/20 backdrop-blur-sm flex items-center justify-center hover:scale-110 active:scale-95 transition-all shadow-lg">
              <Send size={22} className="text-white -rotate-12" />
            </button>

            <button onClick={() => handleSave(currentReelId, currentReel?.is_saved_by_me)} className="w-11 h-11 rounded-full bg-white/10 border border-white/20 backdrop-blur-sm flex items-center justify-center hover:scale-110 active:scale-95 transition-all shadow-lg">
              <Bookmark size={22} className="text-white" fill={currentReel?.is_saved_by_me ? 'currentColor' : 'none'} />
            </button>

            <button className="w-11 h-11 rounded-full bg-white/10 border border-white/20 backdrop-blur-sm flex items-center justify-center hover:scale-110 transition-all shadow-lg">
              <MoreHorizontal size={22} className="text-white" />
            </button>

            <div className="w-9 h-9 border-2 border-white/40 rounded-lg overflow-hidden cursor-pointer shadow-lg mt-1">
              {currentReel?.user_id?.avatar_url
                ? <img src={currentReel.user_id.avatar_url} className="w-full h-full object-cover" alt="" />
                : <div className="w-full h-full bg-gradient-to-br from-orange-400 to-pink-500 flex items-center justify-center">
                    <span className="text-white text-xs font-bold">{(currentReel?.user_id?.username || 'U')[0].toUpperCase()}</span>
                  </div>
              }
            </div>
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
            disabled={currentIndex === reels.length - 1}
            className="w-12 h-12 rounded-full bg-white/10 border border-white/20 backdrop-blur-md shadow-2xl flex items-center justify-center hover:bg-white/25 hover:scale-110 active:scale-95 transition-all disabled:opacity-20 disabled:cursor-not-allowed"
          >
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="white" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round"><polyline points="6 9 12 15 18 9" /></svg>
          </button>
        </div>
      </div>

      {/* Desktop comments panel */}
      {commentsOpen && (
        <CommentsPopup reel={currentReel} onClose={() => setCommentsOpen(false)} userObject={userObject} anchorRight={actionPanelRight} />
      )}

      {/* Mobile bottom sheet */}
      {commentsOpen && (
        <div className="md:hidden fixed inset-0 z-50 flex flex-col justify-end">
          <div className="absolute inset-0 bg-black/50 backdrop-blur-[2px]" onClick={() => setCommentsOpen(false)} />
          {/* FIX: pb-16 clears the bottom nav bar (~64px); safe-area covers notched phones */}
          <div
            className="relative z-10 h-[75vh] pb-16"
            style={{
              paddingBottom: 'max(64px, env(safe-area-inset-bottom, 64px))',
              animation: 'slideUpMobile 0.28s cubic-bezier(0.32,0.72,0,1) forwards',
            }}
          >
            <CommentsBottomSheet reel={currentReel} onClose={() => setCommentsOpen(false)} userObject={userObject} />
          </div>
        </div>
      )}

      <style>{`
        @keyframes slideInLeft {
          from { opacity: 0; transform: translateX(-16px); }
          to   { opacity: 1; transform: translateX(0); }
        }
        @keyframes slideInRight {
          from { opacity: 0; transform: translateX(16px); }
          to   { opacity: 1; transform: translateX(0); }
        }
        @keyframes slideUpMobile {
          from { opacity: 0; transform: translateY(40px); }
          to   { opacity: 1; transform: translateY(0); }
        }
      `}</style>
    </>
  );
};

export default Reels;