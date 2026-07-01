import React, { useState, useEffect, useRef, useCallback } from 'react';
import { useParams, useNavigate, Link } from 'react-router-dom';
import { useSelector } from 'react-redux';
import {
  ArrowLeft, Heart, MessageCircle, Send, MoreHorizontal,
  Smile, ChevronLeft, ChevronRight, Trash2, X,
  Loader2, UserPlus, UserCheck
} from 'lucide-react';
import api from '../lib/api';
import tweetCommentService from '../services/tweetCommentService';
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

const formatDateFull = (d) => {
  if (!d) return '';
  const dt = new Date(d);
  return isNaN(dt.getTime()) ? '' : dt.toLocaleDateString('en-US', { month: 'long', day: 'numeric', year: 'numeric' });
};

const resolveUrl = (raw) => {
  if (!raw) return null;
  const s = String(raw);
  if (s.startsWith('http')) return s;
  return `${BASE_URL}/uploads/${s.replace(/^\/+/, '').replace(/^uploads\//, '')}`;
};

// ─── Delete modal ──────────────────────────────────────────────────────────────
const DeleteModal = ({ isOpen, onClose, onConfirm, isDeleting, label = 'Tweet' }) => {
  if (!isOpen) return null;
  return (
    <div className="fixed inset-0 z-[60] flex items-center justify-center bg-black/50 backdrop-blur-sm p-4">
      <div className="bg-white dark:bg-gray-900 rounded-xl p-6 w-full max-w-sm shadow-2xl border border-gray-100 dark:border-gray-800">
        {isDeleting ? (
          <div className="flex flex-col items-center py-8">
            <Loader2 className="animate-spin w-10 h-10 text-red-500 mb-3" />
            <p className="text-gray-500 font-medium animate-pulse">Deleting {label.toLowerCase()}…</p>
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
const MobileTweetDetail = () => {
  const { tweetId } = useParams();
  const navigate = useNavigate();
  const { userObject } = useSelector(state => state.auth);

  const [tweet, setTweet] = useState(null);
  const [loading, setLoading] = useState(true);

  // like
  const [isLiked, setIsLiked] = useState(false);
  const [likeCount, setLikeCount] = useState(0);

  // media carousel
  const [mediaIndex, setMediaIndex] = useState(0);

  // comments
  const [comments, setComments] = useState([]);
  const [commentsLoading, setCommentsLoading] = useState(false);
  const [postingComment, setPostingComment] = useState(false);
  const [replyTo, setReplyTo] = useState(null);
  const [newComment, setNewComment] = useState('');

  // modals
  const [showReport, setShowReport] = useState(false);
  const [showDeleteTweet, setShowDeleteTweet] = useState(false);
  const [isDeletingTweet, setIsDeletingTweet] = useState(false);
  const [deleteCommentId, setDeleteCommentId] = useState(null);

  const commentsRef = useRef(null);
  const currentUserId = userObject?._id || userObject?.id;

  const author = tweet?.author || tweet?.user || {};
  const username = author?.username || 'User';
  const fullName = author?.full_name || author?.name || '';
  const avatar = author?.avatar_url || '';
  const authorId = author?._id || author?.id;
  const isOwner = !!(currentUserId && authorId && String(currentUserId) === String(authorId));
  const turnOffCommenting = !!(tweet?.turn_off_commenting || tweet?.engagement_controls?.turn_off_commenting);
  const contentText = tweet?.content || tweet?.caption || '';

  // ── Fetch ──────────────────────────────────────────────────────────────────
  useEffect(() => {
    if (tweetId) fetchTweet();
  }, [tweetId]);

  const fetchTweet = async () => {
    setLoading(true);
    try {
      const { data } = await api.get(`/tweets/${tweetId}`);
      setTweet(data);
      setIsLiked(data?.is_liked_by_me ?? false);
      setLikeCount(data?.likes_count ?? 0);
      await fetchComments(tweetId);
    } catch (e) {
      console.error('Failed to fetch tweet:', e);
    } finally {
      setLoading(false);
    }
  };

  const fetchComments = useCallback(async (id = tweetId) => {
    setCommentsLoading(true);
    try {
      const data = await tweetCommentService.getComments(id);
      setComments(Array.isArray(data) ? data : (data?.data || data?.comments || []));
    } catch (e) {
      console.error('Failed to fetch comments:', e);
    } finally {
      setCommentsLoading(false);
    }
  }, [tweetId]);

  // ── Like ───────────────────────────────────────────────────────────────────
  const handleLike = async () => {
    if (!userObject) return;
    const was = isLiked;
    const wasCount = likeCount;
    setIsLiked(!was);
    setLikeCount(was ? Math.max(0, wasCount - 1) : wasCount + 1);
    try {
      await api.post(`/tweets/${tweetId}/${was ? 'unlike' : 'like'}`);
    } catch {
      setIsLiked(was);
      setLikeCount(wasCount);
    }
  };

  // ── Comment like (optimistic) ──────────────────────────────────────────────
  const handleLikeComment = async (commentId, isLikedNow) => {
    setComments(prev => prev.map(c => {
      if (String(c._id || c.id) !== String(commentId)) return c;
      return { ...c, is_liked_by_me: !isLikedNow, likes_count: (c.likes_count ?? 0) + (isLikedNow ? -1 : 1) };
    }));
    try {
      if (isLikedNow) await tweetCommentService.unlikeComment(commentId);
      else await tweetCommentService.likeComment(commentId);
    } catch {
      setComments(prev => prev.map(c => {
        if (String(c._id || c.id) !== String(commentId)) return c;
        return { ...c, is_liked_by_me: isLikedNow, likes_count: (c.likes_count ?? 0) + (isLikedNow ? 1 : -1) };
      }));
    }
  };

  // ── Post comment ───────────────────────────────────────────────────────────
  const handlePostComment = async (e) => {
    e?.preventDefault();
    if (!newComment.trim() || postingComment) return;
    const text = newComment.trim();
    const ri = replyTo;
    setNewComment('');
    setReplyTo(null);
    setPostingComment(true);
    try {
      await tweetCommentService.createComment(tweetId, text, ri?.id || null);
      await fetchComments(tweetId);
    } catch {
      setNewComment(text);
      if (ri) setReplyTo(ri);
    } finally {
      setPostingComment(false);
    }
  };

  // ── Delete comment ─────────────────────────────────────────────────────────
  const executeDeleteComment = async () => {
    if (!deleteCommentId) return;
    try {
      await tweetCommentService.deleteComment(deleteCommentId);
      setComments(prev => prev.filter(c => (c._id || c.id) !== deleteCommentId));
    } catch (e) {
      console.error('Delete comment failed:', e);
    } finally {
      setDeleteCommentId(null);
    }
  };

  // ── Delete tweet ───────────────────────────────────────────────────────────
  const handleDeleteTweet = async () => {
    setIsDeletingTweet(true);
    try {
      await api.delete(`/tweets/${tweetId}`);
      await new Promise(r => setTimeout(r, 800));
      navigate(-1);
    } catch {
      setIsDeletingTweet(false);
      setShowDeleteTweet(false);
    }
  };

  // ── Media ──────────────────────────────────────────────────────────────────
  const mediaItems = Array.isArray(tweet?.media) ? tweet.media : [];
  const images = mediaItems.map(m => resolveUrl(m?.fileUrl || m?.url || m?.fileName)).filter(Boolean);

  // ── Loading / error states ─────────────────────────────────────────────────
  if (loading) {
    return (
      <div className="min-h-screen bg-white dark:bg-black flex items-center justify-center">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-500" />
      </div>
    );
  }

  if (!tweet) {
    return (
      <div className="min-h-screen bg-white dark:bg-black flex flex-col items-center justify-center p-4">
        <p className="text-gray-500 mb-4">Tweet not found</p>
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
        <h1 className="text-lg font-bold text-gray-900 dark:text-white">Tweet</h1>
        <button
          onClick={() => isOwner ? setShowDeleteTweet(true) : setShowReport(true)}
          className="text-gray-900 dark:text-white p-1"
        >
          <MoreHorizontal size={20} />
        </button>
      </div>

      {/* ── Author row ───────────────────────────────────────────────────────── */}
      <div className="px-4 py-3 flex items-center justify-between border-b border-gray-100 dark:border-gray-800">
        <div className="flex items-center gap-3">
          <Link to={`/profile/${username}`} className="shrink-0">
            <Avatar src={avatar} username={username} size="md" />
          </Link>
          <div className="min-w-0">
            <Link to={`/profile/${username}`} className="font-semibold text-sm text-gray-900 dark:text-white block truncate leading-tight hover:opacity-70">
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

      {/* ── Tweet text ───────────────────────────────────────────────────────── */}
      {contentText && (
        <div className="px-4 pt-4 pb-3">
          <p className="text-gray-900 dark:text-white text-[17px] leading-relaxed whitespace-pre-wrap break-words">
            {contentText}
          </p>
        </div>
      )}

      {/* ── Media ────────────────────────────────────────────────────────────── */}
      {images.length > 0 && (
        <div className="w-full bg-black relative">
          <div className="aspect-[4/3] w-full flex items-center justify-center bg-black">
            <img
              src={images[mediaIndex]}
              alt={`Tweet media ${mediaIndex + 1}`}
              className="w-full h-full object-contain"
            />
          </div>
          {images.length > 1 && (
            <>
              <button
                onClick={() => setMediaIndex(i => Math.max(0, i - 1))}
                className="absolute left-2 top-1/2 -translate-y-1/2 w-8 h-8 rounded-full bg-black/50 flex items-center justify-center text-white hover:bg-black/70"
              >
                <ChevronLeft size={18} />
              </button>
              <button
                onClick={() => setMediaIndex(i => Math.min(images.length - 1, i + 1))}
                className="absolute right-2 top-1/2 -translate-y-1/2 w-8 h-8 rounded-full bg-black/50 flex items-center justify-center text-white hover:bg-black/70"
              >
                <ChevronRight size={18} />
              </button>
              <div className="absolute bottom-3 left-1/2 -translate-x-1/2 flex gap-1.5">
                {images.map((_, idx) => (
                  <button
                    key={idx}
                    onClick={() => setMediaIndex(idx)}
                    className={`w-1.5 h-1.5 rounded-full transition-all ${idx === mediaIndex ? 'bg-white scale-110' : 'bg-white/50'}`}
                  />
                ))}
              </div>
              <div className="absolute top-3 right-3 bg-black/50 text-white text-xs px-2 py-0.5 rounded-full">
                {mediaIndex + 1}/{images.length}
              </div>
            </>
          )}
        </div>
      )}

      {/* ── Timestamp + stats ────────────────────────────────────────────────── */}
      <div className="px-4 pt-3 pb-3 border-b border-gray-100 dark:border-gray-800">
        <p className="text-sm text-gray-500 dark:text-gray-400 mb-3">
          {formatDateFull(tweet.createdAt || tweet.created_at)}
        </p>
        {(likeCount > 0 || (tweet.commentsCount || tweet.comments_count || 0) > 0) && (
          <div className="flex items-center gap-4 py-3 border-t border-gray-100 dark:border-gray-800 text-sm text-gray-900 dark:text-white">
            {likeCount > 0 && (
              <span><strong>{likeCount}</strong> <span className="text-gray-500 dark:text-gray-400">Likes</span></span>
            )}
            {(tweet.commentsCount || tweet.comments_count || 0) > 0 && (
              <span><strong>{tweet.commentsCount || tweet.comments_count}</strong> <span className="text-gray-500 dark:text-gray-400">Comments</span></span>
            )}
          </div>
        )}
      </div>

      {/* ── Action bar ──────────────────────────────────────────────────────── */}
      <div className="px-4 py-3 border-b border-gray-100 dark:border-gray-800">
        <div className="flex items-center gap-6">
          <button onClick={handleLike} className="flex items-center gap-2 group">
            <Heart
              size={24}
              className={`transition-colors ${isLiked ? 'fill-red-500 text-red-500' : 'text-gray-500 dark:text-gray-400 group-hover:text-red-400'}`}
            />
            <span className={`text-sm font-medium ${isLiked ? 'text-red-500' : 'text-gray-500 dark:text-gray-400'}`}>Like</span>
          </button>
          {!turnOffCommenting && (
            <button
              onClick={() => commentsRef.current?.scrollIntoView({ behavior: 'smooth', block: 'start' })}
              className="flex items-center gap-2 group"
            >
              <MessageCircle size={24} className="text-gray-500 dark:text-gray-400 group-hover:text-blue-400 transition-colors" />
              <span className="text-sm font-medium text-gray-500 dark:text-gray-400">Reply</span>
            </button>
          )}
          <button className="flex items-center gap-2 group">
            <Send size={24} className="text-gray-500 dark:text-gray-400 group-hover:text-green-400 transition-colors" />
            <span className="text-sm font-medium text-gray-500 dark:text-gray-400">Share</span>
          </button>
        </div>
      </div>

      {/* ── Comments ─────────────────────────────────────────────────────────── */}
      {!turnOffCommenting && (
        <div ref={commentsRef} className="px-4 pt-4 pb-24">
          <h3 className="font-semibold text-gray-900 dark:text-white mb-4 flex items-center gap-2">
            <MessageCircle size={16} className="text-blue-500" />
            Comments {comments.length > 0 ? `(${comments.length})` : ''}
          </h3>

          {commentsLoading ? (
            <div className="flex justify-center py-6">
              <Loader2 className="animate-spin w-6 h-6 text-blue-500" />
            </div>
          ) : comments.length > 0 ? (
            <div className="space-y-0 divide-y divide-gray-100 dark:divide-gray-800">
              {comments.map(comment => {
                const cid = comment._id || comment.id;
                const cUser = comment.user || comment.users || {};
                const cUserId = cUser._id || cUser.id || comment.user_id;
                const isLikedByMe = comment.is_liked_by_me ?? false;
                const likesCount = comment.likes_count ?? (Array.isArray(comment.likes) ? comment.likes.length : 0);
                const isCommentOwner = currentUserId && String(cUserId) === String(currentUserId);

                return (
                  <div key={cid} className="flex gap-3 py-3">
                    <Link to={`/profile/${cUser?.username}`} className="shrink-0">
                      <Avatar src={cUser?.avatar_url} username={cUser?.username} size="sm" />
                    </Link>
                    <div className="flex-1 min-w-0">
                      <div className="flex items-start justify-between gap-2">
                        <div className="flex-1 min-w-0">
                          <Link to={`/profile/${cUser?.username}`} className="font-semibold text-sm text-gray-900 dark:text-white hover:underline mr-1.5">
                            {cUser?.full_name || cUser?.username || 'User'}
                          </Link>
                          <span className="text-sm text-gray-900 dark:text-gray-100 break-words whitespace-pre-wrap">
                            {comment.text || comment.content}
                          </span>
                        </div>
                        <button
                          onClick={() => handleLikeComment(cid, isLikedByMe)}
                          className="shrink-0 flex flex-col items-center gap-0.5 pt-0.5"
                        >
                          <Heart
                            size={14}
                            fill={isLikedByMe ? 'currentColor' : 'none'}
                            className={isLikedByMe ? 'text-red-500' : 'text-gray-400'}
                          />
                          {likesCount > 0 && (
                            <span className={`text-[10px] ${isLikedByMe ? 'text-red-400' : 'text-gray-400'}`}>{likesCount}</span>
                          )}
                        </button>
                      </div>
                      <div className="flex items-center gap-3 mt-1 text-xs text-gray-400">
                        <span>{formatTimeAgo(comment.createdAt || comment.created_at)}</span>
                        <button
                          onClick={() => setReplyTo({ id: cid, username: cUser?.username || cUser?.full_name })}
                          className="font-semibold hover:text-gray-600 dark:hover:text-gray-200 transition-colors"
                        >
                          Reply
                        </button>
                        {isCommentOwner && (
                          <button
                            onClick={() => setDeleteCommentId(cid)}
                            className="hover:text-red-500 transition-colors ml-auto"
                          >
                            <Trash2 size={12} />
                          </button>
                        )}
                      </div>
                    </div>
                  </div>
                );
              })}
            </div>
          ) : (
            <div className="flex flex-col items-center justify-center py-10 text-gray-400">
              <MessageCircle size={32} className="mb-2 opacity-40" />
              <p className="text-sm">No comments yet. Start the conversation!</p>
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
            <button type="button" className="text-gray-500 dark:text-gray-400">
              <Smile size={22} />
            </button>
            <input
              type="text"
              placeholder={replyTo ? `Reply to @${replyTo.username}…` : 'Tweet your reply…'}
              className="flex-1 text-sm outline-none text-gray-900 dark:text-white bg-transparent placeholder-gray-400 dark:placeholder-gray-500"
              value={newComment}
              onChange={e => setNewComment(e.target.value)}
              disabled={postingComment}
            />
            <button
              type="submit"
              disabled={!newComment.trim() || postingComment}
              className={`text-blue-500 font-bold text-sm ${!newComment.trim() || postingComment ? 'opacity-40' : 'hover:text-blue-700'}`}
            >
              {postingComment ? <Loader2 size={16} className="animate-spin" /> : 'Reply'}
            </button>
          </form>
        </div>
      )}

      {/* ── Modals ──────────────────────────────────────────────────────────── */}
      <DeleteModal
        isOpen={showDeleteTweet}
        onClose={() => setShowDeleteTweet(false)}
        onConfirm={handleDeleteTweet}
        isDeleting={isDeletingTweet}
        label="Tweet"
      />
      <DeleteModal
        isOpen={Boolean(deleteCommentId)}
        onClose={() => setDeleteCommentId(null)}
        onConfirm={executeDeleteComment}
        isDeleting={false}
        label="comment"
      />
      <ContentReportModal
        isOpen={showReport}
        onClose={() => setShowReport(false)}
        contentType="tweet"
        contentId={tweetId}
        ownerUsername={username}
        contentUrl={`${window.location.origin}/tweet/${tweetId}`}
      />
    </div>
  );
};

export default MobileTweetDetail;
