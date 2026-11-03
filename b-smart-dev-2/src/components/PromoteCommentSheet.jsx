import React, { useState, useEffect, useRef, useCallback } from 'react';
import { useSelector } from 'react-redux';
import {
  X, Heart, Send, ChevronDown, ChevronUp, Trash2, MessageCircle, Loader2
} from 'lucide-react';
import promoteReelService from '../services/promoteReelService';

// ─── Single Comment Row ────────────────────────────────────────────────────
const CommentRow = ({ comment, currentUserId, onDelete, onLike, onReply, isReply = false }) => {
  const [liked, setLiked] = useState(false);
  const [likesCount, setLikesCount] = useState(comment.likes_count || comment.likesCount || 0);
  const [showReplies, setShowReplies] = useState(false);
  const [replies, setReplies] = useState([]);
  const [loadingReplies, setLoadingReplies] = useState(false);

  const authorId = comment.user?.id || comment.user?._id;
  const isOwn = currentUserId && authorId && String(authorId) === String(currentUserId);
  const avatarUrl = comment.user?.avatar_url;
  const username = comment.user?.username || 'user';
  const timeAgo = (ts) => {
    const diff = Date.now() - new Date(ts).getTime();
    const m = Math.floor(diff / 60000);
    if (m < 1) return 'now';
    if (m < 60) return `${m}m`;
    const h = Math.floor(m / 60);
    if (h < 24) return `${h}h`;
    return `${Math.floor(h / 24)}d`;
  };

  const handleLike = async () => {
    try {
      if (liked) {
        await promoteReelService.unlikeComment(comment._id);
        setLiked(false);
        setLikesCount(c => Math.max(0, c - 1));
      } else {
        await promoteReelService.likeComment(comment._id);
        setLiked(true);
        setLikesCount(c => c + 1);
      }
    } catch { /* ignore */ }
  };

  const fetchReplies = async () => {
    if (loadingReplies) return;
    setLoadingReplies(true);
    try {
      const data = await promoteReelService.getReplies(comment._id);
      setReplies(Array.isArray(data) ? data : []);
    } catch { setReplies([]); }
    finally { setLoadingReplies(false); }
  };

  const toggleReplies = () => {
    if (!showReplies && replies.length === 0) fetchReplies();
    setShowReplies(v => !v);
  };

  return (
    <div className={`flex gap-3 ${isReply ? 'ml-10 mt-2' : ''}`}>
      {/* Avatar */}
      <div className="flex-shrink-0 w-8 h-8 rounded-full bg-gradient-to-br from-purple-500 to-pink-500 flex items-center justify-center overflow-hidden">
        {avatarUrl
          ? <img src={avatarUrl} alt={username} className="w-full h-full object-cover" />
          : <span className="text-white text-xs font-bold">{username.charAt(0).toUpperCase()}</span>}
      </div>

      <div className="flex-1 min-w-0">
        <div className="bg-gray-50 dark:bg-white/5 rounded-2xl px-3 py-2">
          <div className="flex items-center justify-between gap-2 mb-0.5">
            <span className="text-xs font-bold text-gray-900 dark:text-white">{username}</span>
            <div className="flex items-center gap-2">
              <span className="text-[10px] text-gray-400">{timeAgo(comment.createdAt || comment.created_at)}</span>
              {isOwn && (
                <button
                  onClick={() => onDelete(comment._id, isReply)}
                  className="text-gray-300 hover:text-red-400 transition-colors"
                >
                  <Trash2 size={11} />
                </button>
              )}
            </div>
          </div>
          <p className="text-sm text-gray-700 dark:text-gray-200 leading-relaxed break-words">{comment.text}</p>
        </div>

        {/* Actions */}
        <div className="flex items-center gap-4 mt-1 px-1">
          <button
            onClick={handleLike}
            className={`flex items-center gap-1 text-xs font-medium transition-colors ${liked ? 'text-red-500' : 'text-gray-400 hover:text-red-400'}`}
          >
            <Heart size={12} className={liked ? 'fill-current' : ''} />
            {likesCount > 0 && <span>{likesCount}</span>}
          </button>

          {!isReply && (
            <button
              onClick={() => onReply(comment)}
              className="text-xs font-medium text-gray-400 hover:text-purple-500 transition-colors"
            >
              Reply
            </button>
          )}

          {!isReply && comment.replies_count > 0 && (
            <button
              onClick={toggleReplies}
              className="text-xs font-medium text-purple-500 hover:text-purple-600 flex items-center gap-1"
            >
              {showReplies ? <ChevronUp size={12} /> : <ChevronDown size={12} />}
              {showReplies ? 'Hide' : `${comment.replies_count} repl${comment.replies_count === 1 ? 'y' : 'ies'}`}
            </button>
          )}
        </div>

        {/* Replies */}
        {!isReply && showReplies && (
          <div className="mt-2 space-y-2">
            {loadingReplies
              ? <div className="flex justify-center py-2"><Loader2 size={14} className="animate-spin text-gray-400" /></div>
              : replies.map(reply => (
                  <CommentRow
                    key={reply._id}
                    comment={reply}
                    currentUserId={currentUserId}
                    onDelete={(replyId) => {
                      promoteReelService.deleteReply(comment._id, replyId)
                        .then(() => setReplies(r => r.filter(x => x._id !== replyId)))
                        .catch(() => {});
                    }}
                    onLike={onLike}
                    onReply={() => {}}
                    isReply
                  />
                ))}
          </div>
        )}
      </div>
    </div>
  );
};

// ─── Main Component ────────────────────────────────────────────────────────
const PromoteCommentSheet = ({ promoteReelId, isOpen, onClose, commentCount = 0, onCommentCountChange }) => {
  const { userObject } = useSelector(s => s.auth);
  const currentUserId = userObject?._id || userObject?.id;

  const [comments, setComments] = useState([]);
  const [loading, setLoading] = useState(false);
  const [text, setText] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [replyingTo, setReplyingTo] = useState(null); // { _id, user.username }
  const inputRef = useRef(null);
  const listRef = useRef(null);

  const loadComments = useCallback(async () => {
    if (!promoteReelId) return;
    setLoading(true);
    try {
      const data = await promoteReelService.getComments(promoteReelId);
      setComments(Array.isArray(data) ? data : []);
    } catch { setComments([]); }
    finally { setLoading(false); }
  }, [promoteReelId]);

  useEffect(() => {
    if (isOpen) { loadComments(); }
    else { setComments([]); setReplyingTo(null); setText(''); }
  }, [isOpen, loadComments]);

  useEffect(() => {
    if (replyingTo) inputRef.current?.focus();
  }, [replyingTo]);

  const handleSubmit = async () => {
    if (!text.trim() || submitting) return;
    setSubmitting(true);
    try {
      const newComment = await promoteReelService.addComment(
        promoteReelId, text.trim(), replyingTo?._id || null
      );
      if (replyingTo) {
        setComments(prev => prev.map(c =>
          c._id === replyingTo._id
            ? { ...c, replies_count: (c.replies_count || 0) + 1 }
            : c
        ));
      } else {
        setComments(prev => [newComment, ...prev]);
        onCommentCountChange?.(commentCount + 1);
      }
      setText('');
      setReplyingTo(null);
      // Scroll to top to see new comment
      if (!replyingTo) listRef.current?.scrollTo({ top: 0, behavior: 'smooth' });
    } catch { /* ignore */ }
    finally { setSubmitting(false); }
  };

  const handleDelete = async (commentId) => {
    try {
      await promoteReelService.deleteComment(commentId);
      setComments(prev => prev.filter(c => c._id !== commentId));
      onCommentCountChange?.(Math.max(0, commentCount - 1));
    } catch { /* ignore */ }
  };

  if (!isOpen) return null;

  return (
    <>
      {/* Backdrop */}
      <div
        className="fixed inset-0 z-[80] bg-black/40 backdrop-blur-sm"
        onClick={onClose}
      />

      {/* Sheet */}
      <div className="fixed bottom-0 left-0 right-0 z-[81] md:absolute md:bottom-0 md:left-auto md:right-0 md:top-0 md:w-[360px] flex flex-col bg-white dark:bg-[#111] md:rounded-l-3xl rounded-t-3xl shadow-2xl max-h-[85vh] md:max-h-full overflow-hidden">
        {/* Handle / Header */}
        <div className="flex-shrink-0 flex items-center justify-between px-5 pt-4 pb-3 border-b border-gray-100 dark:border-white/10">
          <div className="flex items-center gap-2">
            <MessageCircle size={18} className="text-purple-500" />
            <h3 className="font-bold text-sm text-gray-900 dark:text-white">
              Comments {commentCount > 0 && <span className="text-gray-400">({commentCount})</span>}
            </h3>
          </div>
          <button onClick={onClose} className="w-7 h-7 rounded-full bg-gray-100 dark:bg-white/10 flex items-center justify-center text-gray-500 dark:text-gray-300 hover:bg-gray-200 dark:hover:bg-white/20 transition-colors">
            <X size={14} />
          </button>
        </div>

        {/* Comment List */}
        <div ref={listRef} className="flex-1 overflow-y-auto px-4 py-3 space-y-4" style={{ scrollbarWidth: 'none' }}>
          {loading ? (
            <div className="flex justify-center items-center py-12">
              <Loader2 size={24} className="animate-spin text-purple-400" />
            </div>
          ) : comments.length === 0 ? (
            <div className="flex flex-col items-center justify-center py-12 gap-3">
              <MessageCircle size={36} className="text-gray-200 dark:text-white/10" />
              <p className="text-sm text-gray-400">No comments yet. Be the first!</p>
            </div>
          ) : (
            comments.map(comment => (
              <CommentRow
                key={comment._id}
                comment={comment}
                currentUserId={currentUserId}
                onDelete={handleDelete}
                onLike={() => {}}
                onReply={(c) => setReplyingTo(c)}
              />
            ))
          )}
        </div>

        {/* Reply banner */}
        {replyingTo && (
          <div className="flex-shrink-0 flex items-center justify-between px-4 py-2 bg-purple-50 dark:bg-purple-950/30 border-t border-purple-100 dark:border-purple-900/30">
            <span className="text-xs text-purple-600 dark:text-purple-400 font-medium">
              Replying to @{replyingTo.user?.username || 'user'}
            </span>
            <button onClick={() => setReplyingTo(null)} className="text-purple-400 hover:text-purple-600">
              <X size={14} />
            </button>
          </div>
        )}

        {/* Input */}
        <div className="flex-shrink-0 flex items-center gap-2 px-4 py-3 border-t border-gray-100 dark:border-white/10">
          <div className="w-8 h-8 rounded-full bg-gradient-to-br from-purple-500 to-pink-500 flex items-center justify-center overflow-hidden flex-shrink-0">
            {userObject?.avatar_url
              ? <img src={userObject.avatar_url} alt="" className="w-full h-full object-cover" />
              : <span className="text-white text-xs font-bold">{(userObject?.username || 'U').charAt(0).toUpperCase()}</span>}
          </div>
          <input
            ref={inputRef}
            type="text"
            value={text}
            onChange={e => setText(e.target.value)}
            onKeyDown={e => { if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); handleSubmit(); } }}
            placeholder={replyingTo ? `Reply to @${replyingTo.user?.username}…` : 'Add a comment…'}
            className="flex-1 bg-gray-100 dark:bg-white/5 rounded-full px-4 py-2 text-sm text-gray-900 dark:text-white outline-none placeholder-gray-400 dark:placeholder-gray-500"
          />
          <button
            onClick={handleSubmit}
            disabled={!text.trim() || submitting}
            className="w-8 h-8 rounded-full bg-gradient-to-br from-purple-500 to-pink-500 flex items-center justify-center text-white disabled:opacity-40 transition-opacity flex-shrink-0"
          >
            {submitting ? <Loader2 size={14} className="animate-spin" /> : <Send size={14} />}
          </button>
        </div>
      </div>
    </>
  );
};

export default PromoteCommentSheet;
