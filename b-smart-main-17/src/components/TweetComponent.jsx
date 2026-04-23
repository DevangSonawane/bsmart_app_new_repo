import React, { useState, useEffect, useRef, useCallback } from 'react';
import { Link } from 'react-router-dom';
import { Heart, MessageCircle, Share2, Bookmark, Loader2, Smile, X } from 'lucide-react';
import { useSelector } from 'react-redux';
import Avatar from './Avatar'; // Assuming Avatar component exists
import api from '../lib/api';
import tweetCommentService from '../services/tweetCommentService';
import { formatDateFull } from '../lib/utils'; // Assuming a utility for date formatting

const CommentRow = ({ comment, replies, expanded, onToggleReplies, onReply, onLike, onDelete, onLikeReply, onDeleteReply, currentUserId }) => {
  const commentId = comment._id || comment.id;
  const user = comment.user || comment.users;
  const isOwner = currentUserId && (
    (user && (String(user._id) === String(currentUserId) || String(user.id) === String(currentUserId))) ||
    (comment.user_id && String(comment.user_id) === String(currentUserId))
  );

  const isLikedByMe = comment.is_liked_by_me || (comment.likes && Array.isArray(comment.likes) && comment.likes.some(l => {
    if (!currentUserId) return false;
    if (typeof l === 'string') return l === currentUserId;
    return (l.user_id || l._id || l.id) === currentUserId;
  }));

  const likesCount = comment.likes_count || (comment.likes ? comment.likes.length : 0);

  return (
    <div className="flex gap-3 mb-4">
      <Link to={`/profile/${user?.username}`}>
        <Avatar src={user?.avatar_url} username={user?.username} size="sm" />
      </Link>
      <div className="flex-1 text-sm">
        <div className="flex items-center gap-2">
          <Link to={`/profile/${user?.username}`} className="font-semibold dark:text-white hover:underline">
            {user?.full_name || user?.username || 'User'}
          </Link>
          <span className="text-gray-500 dark:text-gray-400 text-xs">
            {formatDateFull(comment.createdAt || comment.created_at)}
          </span>
        </div>
        <p className="dark:text-white text-gray-800 mt-1">{comment.text}</p>
        <div className="flex gap-4 mt-2 text-gray-500 dark:text-gray-400 text-xs">
          <button onClick={() => onLike(commentId, !isLikedByMe)} className="flex items-center gap-1 hover:text-blue-500">
            <Heart size={14} fill={isLikedByMe ? "red" : "none"} stroke={isLikedByMe ? "red" : "currentColor"} />
            <span>{likesCount > 0 ? likesCount : ''}</span>
          </button>
          <button onClick={() => onReply(user)} className="hover:text-blue-500">Reply</button>
          {isOwner && (
            <button onClick={() => onDelete(commentId)} className="hover:text-red-500">Delete</button>
          )}
        </div>

        {comment.reply_count > 0 && (
          <button onClick={() => onToggleReplies(commentId)} className="text-blue-500 text-xs mt-2">
            {expanded ? `Hide replies (${comment.reply_count})` : `View replies (${comment.reply_count})`}
          </button>
        )}

        {expanded && replies[commentId] && replies[commentId].map(reply => (
          <div key={reply._id || reply.id} className="flex gap-3 mt-4 ml-8">
            <Link to={`/profile/${reply.user?.username}`}>
              <Avatar src={reply.user?.avatar_url} username={reply.user?.username} size="xs" />
            </Link>
            <div className="flex-1 text-sm">
              <div className="flex items-center gap-2">
                <Link to={`/profile/${reply.user?.username}`} className="font-semibold dark:text-white hover:underline">
                  {reply.user?.full_name || reply.user?.username || 'User'}
                </Link>
                <span className="text-gray-500 dark:text-gray-400 text-xs">
                  {formatDateFull(reply.createdAt || reply.created_at)}
                </span>
              </div>
              <p className="dark:text-white text-gray-800 mt-1">{reply.text}</p>
              <div className="flex gap-4 mt-2 text-gray-500 dark:text-gray-400 text-xs">
                <button onClick={() => onLikeReply(commentId, reply._id || reply.id, !reply.is_liked_by_me)} className="flex items-center gap-1 hover:text-blue-500">
                  <Heart size={14} fill={reply.is_liked_by_me ? "red" : "none"} stroke={reply.is_liked_by_me ? "red" : "currentColor"} />
                  <span>{reply.likes_count > 0 ? reply.likes_count : ''}</span>
                </button>
                {currentUserId && (reply.user_id === currentUserId || reply.user?._id === currentUserId) && (
                  <button onClick={() => onDeleteReply(commentId, reply._id || reply.id)} className="hover:text-red-500">Delete</button>
                )}
              </div>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
};

const TweetComponent = ({ tweet }) => {
  const { userObject } = useSelector(s => s.auth);
  const currentUserId = userObject?._id || userObject?.id;

  const [isLiked, setIsLiked] = useState(false);
  const [likeCount, setLikeCount] = useState(0);
  const [comments, setComments] = useState([]);
  const [replies, setReplies] = useState({});
  const [expandedComments, setExpandedComments] = useState({});
  const [newComment, setNewComment] = useState('');
  const [replyTo, setReplyTo] = useState(null);
  const [loadingComments, setLoadingComments] = useState(false);
  const [postingComment, setPostingComment] = useState(false);

  const tweetId = tweet?._id || tweet?.id;
  const author = tweet?.author || tweet?.user || {};
  const authorUsername = author.username || 'Unknown';
  const authorFullName = author.full_name || author.name || '';
  const authorAvatar = author.avatar_url || author.profilePicture || '';
  const mediaItems = Array.isArray(tweet?.media) ? tweet.media : [];
  const rawMediaUrl = mediaItems[0]?.fileUrl || mediaItems[0]?.url || mediaItems[0]?.fileName;
  const mediaUrl = rawMediaUrl
    ? (String(rawMediaUrl).startsWith('http')
      ? rawMediaUrl
      : `https://api.bebsmart.in/uploads/${String(rawMediaUrl).replace(/^\/+/, '').replace(/^uploads\//, '')}`)
    : null;

  useEffect(() => {
    if (tweet) {
      setIsLiked(tweet.is_liked_by_me || false);
      setLikeCount(tweet.likes_count || 0);
      fetchComments(tweetId);
    }
  }, [tweet, tweetId]);

  const fetchComments = useCallback(async (id) => {
    if (!id) return;
    setLoadingComments(true);
    try {
      const commentsData = await tweetCommentService.getComments(id);
      const normalizedComments = Array.isArray(commentsData)
        ? commentsData
        : (commentsData?.data || []);
      setComments(normalizedComments);
      // Pre-load replies for all comments
      const newReplies = {};
      const newExpandedComments = {};
      for (const comment of normalizedComments) {
        if (comment.reply_count > 0) {
          const repliesData = await tweetCommentService.getReplies(comment._id || comment.id);
          newReplies[comment._id || comment.id] = Array.isArray(repliesData)
            ? repliesData
            : (repliesData?.data || []);
          newExpandedComments[comment._id || comment.id] = false; // Keep replies collapsed initially
        }
      }
      setReplies(newReplies);
      setExpandedComments(newExpandedComments);
    } catch (error) {
      console.error('Error fetching comments:', error);
    } finally {
      setLoadingComments(false);
    }
  }, []);

  const loadReplies = useCallback(async (commentId) => {
    try {
      const repliesData = await tweetCommentService.getReplies(commentId);
      const normalizedReplies = Array.isArray(repliesData)
        ? repliesData
        : (repliesData?.data || []);
      setReplies(prev => ({ ...prev, [commentId]: normalizedReplies }));
    } catch (error) {
      console.error('Error loading replies:', error);
    }
  }, []);

  const handleLikeTweet = async () => {
    if (!tweetId) return;
    try {
      if (isLiked) {
        await api.delete(`/tweets/${tweetId}/like`);
        setLikeCount(prev => prev - 1);
      } else {
        await api.post(`/tweets/${tweetId}/like`);
        setLikeCount(prev => prev + 1);
      }
      setIsLiked(prev => !prev);
    } catch (error) {
      console.error('Error liking/unliking tweet:', error);
    }
  };

  const handlePostComment = async (e) => {
    e?.preventDefault();
    if (!newComment.trim() || !tweetId || postingComment) return;
    setPostingComment(true);
    try {
      const parentId = replyTo ? replyTo.id : null;
      await tweetCommentService.createComment(tweetId, newComment.trim(), parentId);
      setNewComment('');
      setReplyTo(null);
      await fetchComments(tweetId); // Re-fetch all comments to update counts and display
    } catch (error) {
      console.error('Error posting comment:', error);
    } finally {
      setPostingComment(false);
    }
  };

  const handleLikeComment = async (commentId, like) => {
    try {
      if (like) {
        await tweetCommentService.likeComment(commentId);
      } else {
        await tweetCommentService.unlikeComment(commentId);
      }
      // Optimistically update UI or re-fetch comments
      fetchComments(tweetId);
    } catch (error) {
      console.error('Error liking/unliking comment:', error);
    }
  };

  const handleDeleteComment = async (commentId) => {
    try {
      await tweetCommentService.deleteComment(commentId);
      fetchComments(tweetId);
    } catch (error) {
      console.error('Error deleting comment:', error);
    }
  };

  const handleLikeReply = async (commentId, replyId, like) => {
    try {
      if (like) {
        await tweetCommentService.likeComment(replyId);
      } else {
        await tweetCommentService.unlikeComment(replyId);
      }
      loadReplies(commentId); // Re-fetch replies for the parent comment
    } catch (error) {
      console.error('Error liking/unliking reply:', error);
    }
  };

  const handleDeleteReply = async (commentId, replyId) => {
    try {
      await tweetCommentService.deleteComment(replyId);
      loadReplies(commentId); // Re-fetch replies for the parent comment
    } catch (error) {
      console.error('Error deleting reply:', error);
    }
  };

  const onToggleReplies = (commentId) => {
    const isExpanded = expandedComments[commentId];
    if (!isExpanded && (!replies[commentId] || replies[commentId].length === 0)) {
      loadReplies(commentId);
    }
    setExpandedComments(prev => ({ ...prev, [commentId]: !prev[commentId] }));
  };

  return (
    <div className="bg-white dark:bg-black rounded-lg shadow-sm border border-gray-200 dark:border-gray-800 mb-4">
      <div className="p-4 flex items-start gap-3">
        <Link to={`/profile/${authorUsername}`}>
          <Avatar src={authorAvatar} username={authorUsername} size="md" />
        </Link>
        <div className="flex-1">
          <div className="flex items-center gap-2">
            <Link to={`/profile/${authorUsername}`} className="font-semibold dark:text-white hover:underline">
              {authorFullName || authorUsername}
            </Link>
            <span className="text-gray-500 dark:text-gray-400 text-xs">
              {formatDateFull(tweet.createdAt || tweet.created_at)}
            </span>
          </div>
          <p className="dark:text-white text-gray-800 mt-2">{tweet.content}</p>
          {mediaItems.length > 0 && mediaUrl && (
            <div className="mt-3 overflow-hidden rounded-xl border border-gray-200 dark:border-gray-800">
              <img
                src={mediaUrl}
                alt="Tweet media"
                className="w-full h-auto max-h-[320px] md:max-h-none object-cover"
              />
            </div>
          )}

          <div className="flex items-center gap-4 mt-4 text-gray-500 dark:text-gray-400">
            <button onClick={handleLikeTweet} className="flex items-center gap-1 hover:text-red-500 transition-colors">
              <Heart size={20} fill={isLiked ? "red" : "none"} stroke={isLiked ? "red" : "currentColor"} />
              <span>{likeCount > 0 ? likeCount : ''}</span>
            </button>
            <button className="flex items-center gap-1 hover:text-blue-500 transition-colors">
              <MessageCircle size={20} />
              <span>{comments.length > 0 ? comments.length : ''}</span>
            </button>
            <button className="hover:text-blue-500 transition-colors">
              <Share2 size={20} />
            </button>
            <button className="hover:text-blue-500 transition-colors">
              <Bookmark size={20} />
            </button>
          </div>
        </div>
      </div>

      {/* Comment Section */}
      <div className="border-t border-gray-200 dark:border-gray-800">
        <div className="p-4">
          <h3 className="font-semibold text-lg dark:text-white mb-3">Comments</h3>
          <div className="max-h-[36vh] overflow-y-auto pr-1 md:max-h-none md:overflow-visible md:pr-0">
            {loadingComments ? (
              <div className="flex justify-center py-4">
                <Loader2 size={24} className="animate-spin text-gray-400" />
              </div>
            ) : comments.length === 0 ? (
              <div className="flex flex-col items-center justify-center py-8 text-gray-400 text-sm">
                <MessageCircle size={32} className="mb-2 opacity-40" />
                <p>No comments yet. Be the first!</p>
              </div>
            ) : (
              comments.map(comment => (
                <CommentRow
                  key={comment._id || comment.id}
                  comment={comment}
                  replies={replies}
                  expanded={expandedComments[comment._id || comment.id]}
                  onToggleReplies={onToggleReplies}
                  onReply={(user) => setReplyTo({ id: comment._id || comment.id, rootCommentId: comment._id || comment.id, username: user.username })}
                  onLike={handleLikeComment}
                  onDelete={handleDeleteComment}
                  onLikeReply={handleLikeReply}
                  onDeleteReply={handleDeleteReply}
                  currentUserId={currentUserId}
                />
              ))
            )}
          </div>
        </div>

        {replyTo && (
          <div className="px-3 md:px-4 py-2 bg-gray-50 dark:bg-gray-900 flex justify-between items-center text-xs text-gray-500 dark:text-gray-400 md:mt-4 md:rounded-md">
            <span>Replying to <span className="font-semibold text-blue-500">@{replyTo.username}</span></span>
            <button onClick={() => setReplyTo(null)}><X size={14} /></button>
          </div>
        )}

        <form onSubmit={handlePostComment} className="border-t border-gray-100 dark:border-gray-800 p-3 flex items-center gap-3 md:border-0 md:p-0 md:mt-4">
          <button type="button" className="text-gray-900 dark:text-white hover:opacity-50 shrink-0 md:hidden">
            <Smile size={22} />
          </button>
          <div className="hidden md:block shrink-0">
            <Avatar src={userObject?.avatar_url} username={userObject?.username} size="sm" />
          </div>
          <input
            type="text"
            placeholder={replyTo ? `Reply to @${replyTo.username}...` : 'Add a comment...'}
            className="flex-1 text-sm outline-none text-gray-900 dark:text-white bg-transparent placeholder-gray-400 dark:placeholder-gray-500 md:bg-gray-100 md:dark:bg-gray-900 md:border md:border-gray-300 md:dark:border-gray-700 md:rounded-full md:py-2 md:px-4"
            value={newComment}
            onChange={(e) => setNewComment(e.target.value)}
            disabled={postingComment}
          />
          <button
            type="submit"
            className="text-blue-500 font-semibold text-sm shrink-0 hover:text-blue-700 disabled:opacity-40"
            disabled={!newComment.trim() || postingComment}
          >
            {postingComment ? <Loader2 size={16} className="animate-spin" /> : 'Post'}
          </button>
        </form>
      </div>
    </div>
  );
};

export default TweetComponent;
