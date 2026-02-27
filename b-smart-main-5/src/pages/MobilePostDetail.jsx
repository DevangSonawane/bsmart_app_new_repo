import React, { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { supabase } from '../lib/supabase';
import { useSelector } from 'react-redux';
import { ArrowLeft, MoreHorizontal, Heart, MessageCircle, Send, Bookmark, Smile, ChevronLeft, ChevronRight, Trash2, X, Edit } from 'lucide-react';
import api from '../lib/api';
import commentService from '../services/commentService';

const DeleteModal = ({ isOpen, onClose, onConfirm, isDeleting }) => {
    if (!isOpen) return null;
    return (
        <div className="fixed inset-0 z-[60] flex items-center justify-center bg-black/50 backdrop-blur-sm animate-fade-in p-4">
            <div className="bg-white dark:bg-gray-900 rounded-xl p-6 w-full max-w-sm shadow-2xl border border-gray-100 dark:border-gray-800 transform transition-all scale-100">
                {isDeleting ? (
                    <div className="flex flex-col items-center justify-center py-8">
                        <div className="animate-spin w-12 h-12 border-4 border-gray-200 border-t-red-500 rounded-full mb-4"></div>
                        <p className="text-gray-500 dark:text-gray-400 font-medium animate-pulse">Deleting post...</p>
                    </div>
                ) : (
                    <>
                        <h3 className="text-lg font-bold text-gray-900 dark:text-white mb-2 text-center">Delete Post?</h3>
                        <p className="text-gray-500 dark:text-gray-400 text-sm mb-6 text-center">
                            Are you sure you want to delete this post? This action cannot be undone.
                        </p>
                        <div className="flex gap-3">
                            <button
                                onClick={onClose}
                                className="flex-1 px-4 py-2.5 rounded-lg border border-gray-200 dark:border-gray-700 font-medium text-gray-700 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors"
                            >
                                Cancel
                            </button>
                            <button
                                onClick={onConfirm}
                                className="flex-1 px-4 py-2.5 rounded-lg bg-red-500 text-white font-medium hover:bg-red-600 transition-colors shadow-lg shadow-red-500/20"
                            >
                                Delete
                            </button>
                        </div>
                    </>
                )}
            </div>
        </div>
    );
};

const MobilePostDetail = () => {
    const { postId } = useParams();
    const navigate = useNavigate();
    const { userObject } = useSelector((state) => state.auth);

    const [post, setPost] = useState(null);
    const [comments, setComments] = useState([]);
    const [replies, setReplies] = useState({}); // Map of commentId -> replies array
    const [expandedComments, setExpandedComments] = useState({});
    const [replyTo, setReplyTo] = useState(null); // { id, username }
    const [newComment, setNewComment] = useState('');
    const [isLoadingComments, setIsLoadingComments] = useState(false);
    const [isLiked, setIsLiked] = useState(false);
    const [likeCount, setLikeCount] = useState(0);
    const [postUser, setPostUser] = useState(null);
    const [currentImageIndex, setCurrentImageIndex] = useState(0);
    const [loading, setLoading] = useState(true);
    const [showOptions, setShowOptions] = useState(false);
    const [showDeleteModal, setShowDeleteModal] = useState(false);
    const [isDeleting, setIsDeleting] = useState(false);

    // Check if current user is the post owner
    const isPostOwner = userObject && post && (
        (userObject.id && (post.user_id || post.user?.id) && String(userObject.id) === String(post.user_id || post.user?.id)) ||
        (userObject._id && (post.user_id || post.user?._id) && String(userObject._id) === String(post.user_id || post.user?._id))
    );

    useEffect(() => {
        if (postId) {
            fetchPostDetails();
        }
    }, [postId]);

    // Update local state when post data changes
    useEffect(() => {
        if (post) {
            // Check for likes array first
            if (post.likes && Array.isArray(post.likes)) {
                const userId = userObject ? (userObject._id || userObject.id) : null;
                const userLiked = userId ? post.likes.some(like => {
                    // Handle string IDs
                    if (typeof like === 'string') return String(like) === String(userId);
                    // Handle object IDs
                    const likeId = like.user_id || like._id || like.id;
                    const likeUserId = like.user ? (like.user._id || like.user.id) : null;
                    return String(likeId) === String(userId) || String(likeUserId) === String(userId);
                }) : false;

                setIsLiked(userLiked);
                setLikeCount(post.likes.length);
            } else if (typeof post.is_liked_by_me !== 'undefined') {
                setIsLiked(post.is_liked_by_me);
                setLikeCount(post.likes_count || 0);
            } else {
                const likes = post.likes || [];
                const userLiked = userObject ? likes.some(like => like.user_id === userObject.id) : false;
                setIsLiked(userLiked);
                setLikeCount(likes.length);
            }
        }
    }, [post, userObject]);

    const fetchPostDetails = async () => {
        setLoading(true);
        setIsLoadingComments(true);
        try {
            const response = await api.get(`/posts/${postId}`);
            const fullPost = response.data;

            setPost(fullPost);

            // Fetch comments using service
            await fetchComments(postId);

            // Handle user
            const user = fullPost.user || fullPost.users || fullPost.user_id;
            if (typeof user === 'object') {
                setPostUser(user);
            } else {
                const { data } = await supabase
                    .from('users')
                    .select('*')
                    .eq('id', user)
                    .single();
                setPostUser(data);
            }

        } catch (error) {
            console.error('Error fetching post details:', error);
            // Fallback not implemented for mobile view specifically, could add if needed
        } finally {
            setLoading(false);
            setIsLoadingComments(false);
        }
    };

    const fetchComments = async (id = postId) => {
        try {
            const data = await commentService.getComments(id);
            setComments(data || []);

            // Fetch replies for all comments to check for nested content
            if (data && Array.isArray(data)) {
                data.forEach(comment => {
                    const commentId = comment._id || comment.id;
                    commentService.getReplies(commentId)
                        .then(repliesData => {
                            if (repliesData && repliesData.length > 0) {
                                setReplies(prev => ({ ...prev, [commentId]: repliesData }));
                            }
                        })
                        .catch(err => console.error('Error auto-loading replies:', err));
                });
            }
        } catch (error) {
            console.error('Error fetching comments:', error);
        }
    };

    const loadReplies = async (commentId) => {
        try {
            const data = await commentService.getReplies(commentId);
            setReplies(prev => ({ ...prev, [commentId]: data }));
        } catch (error) {
            console.error('Error loading replies:', error);
        }
    };

    const handleLikeComment = async (commentId, isLikedByMe) => {
        try {
            if (isLikedByMe) {
                await commentService.unlikeComment(commentId);
            } else {
                await commentService.likeComment(commentId);
            }
            // Refresh to update counts/status
            fetchComments();
            // If it's a reply, refresh replies
            Object.keys(replies).forEach(key => loadReplies(key));
        } catch (error) {
            console.error('Error liking comment:', error);
        }
    };

    const handlePostComment = async (e) => {
        e.preventDefault();
        if (!newComment.trim() || !userObject) return;

        try {
            const parentId = replyTo ? replyTo.id : null;

            await commentService.createComment(postId, newComment.trim(), parentId);

            setNewComment('');

            // Refresh comments
            await fetchComments(postId);

            // If replied to a comment, refresh its replies and ensure expanded
            if (replyTo) {
                await loadReplies(replyTo.id);
                setExpandedComments(prev => ({ ...prev, [replyTo.id]: true }));
                setReplyTo(null);
            }
        } catch (error) {
            console.error('Error posting comment:', error);
        }
    };

    const handleLike = async () => {
        if (!userObject) return;

        const likes = post.likes || [];
        let newLikes;
        let newIsLiked;

        if (isLiked) {
            newLikes = likes.filter(like => {
                const likeId = like.user_id || like._id || like.id;
                const userId = userObject._id || userObject.id;
                return String(likeId) !== String(userId);
            });
            newIsLiked = false;
        } else {
            newLikes = [...likes, { user_id: userObject.id || userObject._id, like: true }];
            newIsLiked = true;
        }

        setIsLiked(newIsLiked);
        setLikeCount(newLikes.length);

        try {
            if (post._id) {
                if (newIsLiked) {
                    await api.post(`/posts/${post._id}/like`);
                } else {
                    await api.post(`/posts/${post._id}/unlike`);
                }
            } else {
                const { error } = await supabase
                    .from('posts')
                    .update({ likes: newLikes })
                    .eq('id', post.id);

                if (error) throw error;
            }

            // Update local post reference
            const updatedPost = { ...post, likes: newLikes };
            if (typeof post.is_liked_by_me !== 'undefined') {
                updatedPost.is_liked_by_me = newIsLiked;
                updatedPost.likes_count = newLikes.length;
            }
            setPost(updatedPost);

        } catch (error) {
            console.error('Error updating like count:', error);
            // Revert on error
            setIsLiked(!newIsLiked);
            setLikeCount(likes.length);
        }
    };

    const handleDeleteComment = async (commentId) => {
        if (!window.confirm('Are you sure you want to delete this comment?')) return;
        try {
            await api.delete(`/comments/${commentId}`);
            await fetchComments();
        } catch (error) {
            console.error('Error deleting comment:', error);
        }
    };

    const handleDeletePost = async () => {
        setIsDeleting(true);
        try {
            const id = post._id || post.id;
            const token = localStorage.getItem('token');
            await api.delete(`/posts/${id}`, {
                headers: { Authorization: `Bearer ${token}` }
            });
            // Wait a bit
            await new Promise(resolve => setTimeout(resolve, 1000));
            navigate(-1); // Go back
        } catch (error) {
            console.error('Error deleting post:', error);
            alert('Failed to delete post');
            setIsDeleting(false);
            setShowDeleteModal(false);
        }
    };

    // Format date relative (simple version)
    const formatDate = (dateString) => {
        if (!dateString) return '';
        const date = new Date(dateString);
        if (isNaN(date.getTime())) return '';

        const now = new Date();
        const diffInSeconds = Math.floor((now - date) / 1000);

        if (diffInSeconds < 60) return `${Math.max(0, diffInSeconds)}s`;
        if (diffInSeconds < 3600) return `${Math.floor(diffInSeconds / 60)}m`;
        if (diffInSeconds < 86400) return `${Math.floor(diffInSeconds / 3600)}h`;
        if (diffInSeconds < 604800) return `${Math.floor(diffInSeconds / 86400)}d`;
        return `${Math.floor(diffInSeconds / 604800)}w`;
    };

    const renderComment = (comment, isReply = false) => {
        const commentId = comment._id || comment.id;
        const user = comment.user || comment.users;
        const userId = userObject ? (userObject._id || userObject.id) : null;

        // Check if liked by me
        const isLikedByMe = comment.is_liked_by_me || (comment.likes && Array.isArray(comment.likes) && comment.likes.some(l => {
            if (!userId) return false;
            if (typeof l === 'string') return l === userId;
            return (l.user_id || l._id || l.id) === userId;
        }));

        const likesCount = comment.likes_count || (comment.likes ? comment.likes.length : 0);

        // Check for replies
        const hasReplies = comment.reply_count > 0 || (replies[commentId] && replies[commentId].length > 0) || (comment.replies && comment.replies.length > 0);

        const isOwner = userId && (
            (user && (String(user._id) === String(userId) || String(user.id) === String(userId))) ||
            (comment.user_id && String(comment.user_id) === String(userId))
        );

        return (
            <div key={commentId} className={`flex gap-3 mb-4 ${isReply ? 'ml-12' : ''}`}>
                <div className="w-8 h-8 rounded-full bg-gray-200 dark:bg-gray-800 overflow-hidden shrink-0">
                    {user?.avatar_url ? (
                        <img
                            src={user.avatar_url}
                            alt={user?.username}
                            className="w-full h-full object-cover"
                        />
                    ) : (
                        <div className="w-full h-full flex items-center justify-center text-xs font-bold text-gray-700 dark:text-gray-300">
                            {user?.username ? user.username.charAt(0).toUpperCase() : 'U'}
                        </div>
                    )}
                </div>
                <div className="flex-1 text-sm group">
                    <div className="flex justify-between items-start">
                        <div>
                            <span className="font-semibold mr-2 dark:text-white">{user?.username}</span>
                            <span className="text-gray-900 dark:text-gray-100">{comment.text || comment.content}</span>
                            <div className="text-gray-500 dark:text-gray-400 text-xs mt-1 flex gap-3 items-center">
                                <span>{formatDate(comment.createdAt || comment.created_at)}</span>
                                {likesCount > 0 && <span>{likesCount} likes</span>}
                                <button
                                    className="font-semibold hover:text-gray-900 dark:hover:text-gray-300"
                                    onClick={() => setReplyTo({ id: commentId, username: user?.username })}
                                >
                                    Reply
                                </button>
                            </div>
                        </div>
                        <div className="flex items-center gap-2">
                            <button
                                onClick={() => handleLikeComment(commentId, isLikedByMe)}
                                className={`${isLikedByMe ? 'text-red-500' : 'text-gray-400 dark:text-gray-600 hover:text-gray-600 dark:hover:text-gray-400'} transition-colors flex items-center gap-1`}
                            >
                                <Heart size={12} fill={isLikedByMe ? "currentColor" : "none"} />
                            </button>
                            {isOwner && (
                                <button
                                    onClick={() => handleDeleteComment(commentId)}
                                    className="text-gray-400 dark:text-gray-600 hover:text-red-500 dark:hover:text-red-400 transition-colors"
                                    title="Delete comment"
                                >
                                    <Trash2 size={12} />
                                </button>
                            )}
                        </div>
                    </div>

                    {/* View Replies Button */}
                    {!isReply && hasReplies && (
                        <div className="mt-2">
                            <button
                                className="text-xs text-gray-500 flex items-center gap-2 hover:text-gray-900 dark:hover:text-gray-300"
                                onClick={() => {
                                    if (!replies[commentId] && !comment.replies) {
                                        loadReplies(commentId);
                                    }
                                    setExpandedComments(prev => ({ ...prev, [commentId]: !prev[commentId] }));
                                }}
                            >
                                <div className="w-8 h-[1px] bg-gray-300"></div>
                                {expandedComments[commentId] ? 'Hide replies' : `View replies (${comment.reply_count || (comment.replies ? comment.replies.length : 0) || (replies[commentId] ? replies[commentId].length : '')})`}
                            </button>
                        </div>
                    )}

                    {/* Render Replies */}
                    {!isReply && expandedComments[commentId] && (replies[commentId] || comment.replies) && (
                        <div className="mt-2">
                            {(replies[commentId] || comment.replies).map(reply => renderComment(reply, true))}
                        </div>
                    )}
                </div>
            </div>
        );
    };

    if (loading) {
        return (
            <div className="min-h-screen bg-white dark:bg-black flex items-center justify-center">
                <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-gray-900 dark:border-white"></div>
            </div>
        );
    }

    if (!post) {
        return (
            <div className="min-h-screen bg-white dark:bg-black flex flex-col items-center justify-center p-4">
                <p className="text-gray-500 mb-4">Post not found</p>
                <button onClick={() => navigate(-1)} className="text-blue-500 font-semibold">Go Back</button>
            </div>
        );
    }

    const mediaItems = post.media && post.media.length > 0
        ? post.media
        : (post.imageUrl ? [{ fileUrl: post.imageUrl, type: 'image' }] : []);

    const getVideoTiming = (item) => {
        if (!item) return { start: 0, end: 0 };
        const toNumber = (v) => {
            if (typeof v === 'number' && isFinite(v)) return v;
            if (typeof v === 'string') {
                const n = parseFloat(v);
                return isFinite(n) ? n : 0;
            }
            return 0;
        };
        const timing = item.timing || {};
        let start = toNumber(timing.start ?? item["finalLength-start"]);
        let end = toNumber(timing.end ?? item["finallength-end"]);
        const duration = toNumber(item.videoLength ?? item.totalLenght ?? item.duration);
        if (start < 0) start = 0;
        if ((!end || end <= 0) && duration > 0) end = duration;
        if (duration > 0 && end > duration) end = duration;
        if (end > 0 && end <= start) end = 0;
        return { start, end };
    };

    const getAspectClass = (item) => {
        const ratio = item && item.crop && item.crop.aspect_ratio ? item.crop.aspect_ratio : '4:5';
        if (ratio === '1:1') return 'aspect-[1/1]';
        if (ratio === '16:9') return 'aspect-[16/9]';
        if (ratio === '9:16') return 'aspect-[9/16]';
        return 'aspect-[4/5]';
    };

    const nextImage = (e) => {
        e.stopPropagation();
        setCurrentImageIndex((prev) => (prev === mediaItems.length - 1 ? 0 : prev + 1));
    };

    const prevImage = (e) => {
        e.stopPropagation();
        setCurrentImageIndex((prev) => (prev === 0 ? mediaItems.length - 1 : prev - 1));
    };

    return (
        <div className="min-h-screen bg-white dark:bg-black pb-20">
            {/* Top Bar */}
            <div className="sticky top-0 bg-white dark:bg-black z-50 px-4 py-3 flex items-center justify-between border-b border-gray-100 dark:border-gray-800">
                <button onClick={() => navigate(-1)} className="text-gray-900 dark:text-white">
                    <ArrowLeft size={24} />
                </button>
                <h1 className="text-lg font-bold text-gray-900 dark:text-white">Post</h1>
                <div className="w-6"></div> {/* Spacer for centering */}
            </div>

            {/* User Header */}
            <div className="px-4 py-3 flex items-center justify-between">
                <div className="flex items-center gap-3">
                    <div className="w-10 h-10 rounded-full p-[2px] bg-gradient-to-tr from-insta-yellow via-insta-orange to-insta-pink">
                        <div className="w-full h-full rounded-full bg-white dark:bg-black p-[2px] overflow-hidden">
                            {postUser?.avatar_url ? (
                                <img
                                    src={postUser.avatar_url}
                                    alt={postUser?.username}
                                    className="w-full h-full rounded-full object-cover"
                                />
                            ) : (
                                <div className="w-full h-full rounded-full bg-gradient-to-tr from-insta-yellow via-insta-orange to-insta-pink flex items-center justify-center text-xs font-bold text-white">
                                    {postUser?.username ? postUser.username.charAt(0).toUpperCase() : 'U'}
                                </div>
                            )}
                        </div>
                    </div>
                    <div className="flex flex-col">
                        <span className="font-semibold text-sm text-gray-900 dark:text-white leading-tight">
                            {postUser?.username || 'User'}
                        </span>
                        {post.location && (
                            <span className="text-xs text-gray-500 dark:text-gray-400 leading-tight">{post.location}</span>
                        )}
                    </div>
                </div>
                <div className="relative">
                    {isPostOwner && (
                        <button
                            onClick={() => setShowOptions(!showOptions)}
                            className="text-gray-900 dark:text-white p-1 hover:bg-gray-100 dark:hover:bg-gray-800 rounded-full transition-colors"
                        >
                            <MoreHorizontal size={20} />
                        </button>
                    )}

                    {showOptions && isPostOwner && (
                        <div className="absolute right-0 top-full mt-1 w-48 bg-white dark:bg-[#262626] rounded-xl shadow-xl border border-gray-100 dark:border-gray-800 py-1 z-50 animate-fade-in">
                            <button
                                className="w-full px-4 py-2.5 text-left text-sm text-gray-700 dark:text-gray-200 hover:bg-gray-50 dark:hover:bg-gray-800 flex items-center gap-2 transition-colors"
                                onClick={() => {
                                    setShowOptions(false);
                                    alert('Edit functionality coming soon');
                                }}
                            >
                                <Edit size={16} />
                                <span>Edit Post</span>
                            </button>
                            <button
                                className="w-full px-4 py-2.5 text-left text-sm text-red-500 hover:bg-red-50 dark:hover:bg-red-900/20 flex items-center gap-2 transition-colors border-t border-gray-50 dark:border-gray-800"
                                onClick={() => {
                                    setShowOptions(false);
                                    setShowDeleteModal(true);
                                }}
                            >
                                <Trash2 size={16} />
                                <span>Delete Post</span>
                            </button>
                        </div>
                    )}
                </div>
            </div>

            <DeleteModal
                isOpen={showDeleteModal}
                onClose={() => setShowDeleteModal(false)}
                onConfirm={handleDeletePost}
                isDeleting={isDeleting}
            />

            {/* Image/Media */}
            <div className="w-full bg-black relative group">
                <div className={`${getAspectClass(mediaItems[currentImageIndex])} w-full flex items-center justify-center bg-black`}>
                    {mediaItems.length > 0 ? (
                        <>
                            {mediaItems[currentImageIndex].type === 'video' ? (
                                (() => {
                                    const { start, end } = getVideoTiming(mediaItems[currentImageIndex]);
                                    return (
                                        <video
                                            src={mediaItems[currentImageIndex].fileUrl || mediaItems[currentImageIndex].url}
                                            className="w-full h-full object-contain"
                                            controls
                                            autoPlay
                                            muted
                                            data-start={start}
                                            data-end={end}
                                            onLoadedMetadata={(e) => {
                                                const s = Number(e.currentTarget.dataset.start || 0);
                                                if (s > 0 && isFinite(s)) {
                                                    e.currentTarget.currentTime = s;
                                                }
                                            }}
                                            onTimeUpdate={(e) => {
                                                const v = e.currentTarget;
                                                const s = Number(v.dataset.start || 0);
                                                const endVal = Number(v.dataset.end || 0);
                                                if (endVal > 0 && isFinite(endVal) && v.currentTime > endVal) {
                                                    if (s > 0 && isFinite(s)) {
                                                        v.currentTime = s;
                                                    } else {
                                                        v.currentTime = endVal;
                                                    }
                                                    v.pause();
                                                }
                                            }}
                                        />
                                    );
                                })()
                            ) : (
                                <img
                                    src={mediaItems[currentImageIndex].fileUrl || mediaItems[currentImageIndex].url || mediaItems[currentImageIndex].image}
                                    alt={`Post content ${currentImageIndex + 1}`}
                                    className="w-full h-full object-contain"
                                />
                            )}
                        </>
                    ) : (
                        <div className="text-gray-500">No media available</div>
                    )}
                </div>

                {/* Navigation Arrows */}
                {mediaItems.length > 1 && (
                    <>
                        <button
                            onClick={prevImage}
                            className="absolute left-2 top-1/2 -translate-y-1/2 bg-black/50 hover:bg-black/70 text-white p-1.5 rounded-full opacity-70 hover:opacity-100 transition-opacity duration-200"
                        >
                            <ChevronLeft size={20} />
                        </button>
                        <button
                            onClick={nextImage}
                            className="absolute right-2 top-1/2 -translate-y-1/2 bg-black/50 hover:bg-black/70 text-white p-1.5 rounded-full opacity-70 hover:opacity-100 transition-opacity duration-200"
                        >
                            <ChevronRight size={20} />
                        </button>

                        {/* Dots Pagination */}
                        <div className="absolute bottom-4 left-1/2 -translate-x-1/2 flex gap-1.5">
                            {mediaItems.map((_, idx) => (
                                <div
                                    key={idx}
                                    className={`w-1.5 h-1.5 rounded-full transition-all duration-300 ${idx === currentImageIndex ? 'bg-white scale-110' : 'bg-white/50'
                                        }`}
                                />
                            ))}
                        </div>
                    </>
                )}
            </div>

            {/* Actions */}
            <div className="px-4 py-3">
                <div className="flex items-center justify-between mb-3">
                    <div className="flex items-center gap-4">
                        <button onClick={handleLike} className="flex items-center gap-1.5 group">
                            <Heart
                                size={26}
                                className={`transition-colors ${isLiked ? 'fill-red-500 text-red-500' : 'text-gray-900 dark:text-white group-hover:text-gray-600 dark:group-hover:text-gray-300'}`}
                            />
                        </button>

                        <button className="flex items-center gap-1.5 group">
                            <MessageCircle size={26} className="text-gray-900 dark:text-white group-hover:text-gray-600 dark:group-hover:text-gray-300 flip-horizontal" />
                        </button>

                        <button className="text-gray-900 dark:text-white hover:text-gray-600 dark:hover:text-gray-300">
                            <Send size={26} />
                        </button>
                    </div>

                    <button className="text-gray-900 dark:text-white hover:text-gray-600 dark:hover:text-gray-300">
                        <Bookmark size={26} />
                    </button>
                </div>

                <div className="font-semibold text-sm text-gray-900 dark:text-white mb-1">
                    {likeCount} likes
                </div>

                {/* Caption */}
                <div className="space-y-1 mb-2">
                    <div className="text-sm text-gray-900 dark:text-white">
                        <span className="font-semibold mr-2">{postUser?.username}</span>
                        {post.caption}
                    </div>
                    <div className="text-[10px] text-gray-500 dark:text-gray-400 uppercase tracking-wide pt-1">
                        {formatDate(post.created_at)}
                    </div>
                </div>
            </div>

            {/* Comments Section */}
            <div className="px-4 pb-20 border-t border-gray-100 dark:border-gray-800 pt-4">
                <h3 className="font-semibold text-gray-900 dark:text-white mb-4">Comments</h3>

                {isLoadingComments ? (
                    <div className="flex justify-center py-4">
                        <div className="animate-spin w-6 h-6 border-2 border-gray-300 dark:border-gray-700 border-t-blue-500 rounded-full"></div>
                    </div>
                ) : comments.length > 0 ? (
                    <div className="mb-20">
                        {comments.map((comment) => renderComment(comment))}
                    </div>
                ) : (
                    <div className="text-center text-gray-500 dark:text-gray-400 text-sm py-4">
                        No comments yet. Be the first to comment!
                    </div>
                )}
            </div>

            {/* Fixed Bottom Input Area */}
            <div className="fixed bottom-0 left-0 right-0 border-t border-gray-100 dark:border-gray-800 bg-white dark:bg-black z-40 p-3 md:p-4">
                {replyTo && (
                    <div className="px-3 py-2 bg-gray-50 dark:bg-gray-900 flex justify-between items-center text-xs text-gray-500 dark:text-gray-400 mb-2 rounded">
                        <span>Replying to <span className="font-semibold">{replyTo.username}</span></span>
                        <button onClick={() => setReplyTo(null)} className="hover:text-gray-900 dark:hover:text-gray-200">
                            <X size={14} />
                        </button>
                    </div>
                )}
                <form onSubmit={handlePostComment} className="flex items-center gap-3">
                    <button type="button" className="text-gray-900 dark:text-white hover:opacity-50">
                        <Smile size={24} />
                    </button>
                    <input
                        type="text"
                        placeholder={replyTo ? `Reply to ${replyTo.username}...` : "Add a comment..."}
                        className="flex-1 text-sm outline-none text-gray-900 dark:text-white bg-transparent placeholder-gray-500 dark:placeholder-gray-400"
                        value={newComment}
                        onChange={(e) => setNewComment(e.target.value)}
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
        </div>
    );
};

export default MobilePostDetail;
