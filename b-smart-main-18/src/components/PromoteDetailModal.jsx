import React, { useState, useEffect, useRef, useCallback } from 'react';
import {
  X, Heart, MessageCircle, Send, MoreHorizontal,
  Smile, ChevronLeft, ChevronRight, Trash2,
  Volume2, VolumeX, UserPlus, UserCheck, ShoppingBag,
  Loader2, ExternalLink, Zap
} from 'lucide-react';
import { useSelector } from 'react-redux';
import { Link } from 'react-router-dom';
import api from '../lib/api';
import promoteReelService from '../services/promoteReelService';
import Avatar from './Avatar';
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
  const discountPct = product.discount_amount && product.product_price
    ? Math.round((product.discount_amount / product.product_price) * 100) : 0;
  const finalPrice = (product.product_price || 0) - (product.discount_amount || 0);
  const href = product.visit_link && !['', '#'].includes(product.visit_link) ? product.visit_link : null;
  return (
    <div className="flex-shrink-0 w-40 bg-white dark:bg-white/5 rounded-2xl overflow-hidden border border-gray-100 dark:border-white/10 shadow-sm">
      <div className="w-full h-24 bg-gradient-to-br from-orange-50 to-pink-50 dark:from-orange-900/20 dark:to-pink-900/20 flex items-center justify-center">
        {product.promote_img
          ? <img src={toAbsUrl(product.promote_img)} alt={product.product_name} className="w-full h-full object-cover" onError={e => { e.target.style.display = 'none'; }} />
          : <ShoppingBag size={26} className="text-orange-300" />}
      </div>
      <div className="p-2.5">
        <p className="text-xs font-bold text-gray-900 dark:text-white line-clamp-2 leading-tight mb-0.5">{product.product_name}</p>
        {product.product_description && <p className="text-[10px] text-gray-500 dark:text-gray-400 line-clamp-1 mb-1">{product.product_description}</p>}
        <div className="flex items-baseline gap-1 flex-wrap mt-1 mb-2">
          <span className="text-sm font-black text-orange-600 dark:text-orange-400">&#8377;{finalPrice.toLocaleString()}</span>
          {discountPct > 0 && (
            <>
              <span className="text-[10px] text-gray-400 line-through">&#8377;{product.product_price}</span>
              <span className="text-[10px] font-bold text-green-500">{discountPct}% off</span>
            </>
          )}
        </div>
        {href ? (
          <a href={href} target="_blank" rel="noopener noreferrer"
            onClick={e => e.stopPropagation()}
            className="flex items-center justify-center w-full py-1.5 rounded-lg bg-blue-500 text-white text-[10px] font-bold hover:bg-blue-600 active:scale-95 transition-all gap-1">
            <ExternalLink size={9} />
            Visit Website
          </a>
        ) : (
          <div className="w-full py-1.5 rounded-lg bg-gray-100 dark:bg-gray-800 text-gray-400 text-[10px] text-center">No link</div>
        )}
      </div>
    </div>
  );
};

const FollowButton = ({ targetUserId }) => {
  const { userObject } = useSelector(s => s.auth);
  const [following, setFollowing] = useState(false);
  const [loading, setLoading] = useState(false);
  useEffect(() => {
    if (!userObject || !targetUserId) return;
    api.get(`/follow/status/${targetUserId}`).then(({ data }) => {
      setFollowing(data?.isFollowing || data?.status === 'following' || false);
    }).catch(() => {});
  }, [targetUserId, userObject]);
  const handleClick = useCallback(async (e) => {
    e.stopPropagation();
    if (!userObject || loading) return;
    const was = following;
    setFollowing(!was); setLoading(true);
    try { await api.post(was ? '/unfollow' : '/follow', { followedUserId: targetUserId }); }
    catch { setFollowing(was); }
    finally { setLoading(false); }
  }, [userObject, loading, following, targetUserId]);
  if (!targetUserId) return null;
  return (
    <button onClick={handleClick} disabled={loading}
      className={`flex items-center gap-1.5 text-xs font-bold px-3 py-1 rounded-full border transition-all ${loading ? 'opacity-50' : ''} ${following ? 'border-gray-300 dark:border-gray-600 text-gray-500 dark:text-gray-400' : 'border-blue-500 text-blue-500 bg-blue-50 dark:bg-blue-500/10'}`}>
      {loading ? <Loader2 size={10} className="animate-spin" /> : following ? <UserCheck size={10} /> : <UserPlus size={10} />}
      <span>{following ? 'Following' : 'Follow'}</span>
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

const ModalMediaPanel = ({ item, isOpen }) => {
  const mediaItems = Array.isArray(item?.media) && item.media.length > 0 ? item.media : [];
  const [currentIndex, setCurrentIndex] = useState(0);
  const [isPlaying, setIsPlaying] = useState(false);
  const [isMuted, setIsMuted] = useState(true);
  const [videoReady, setVideoReady] = useState(false);
  const videoRef = useRef(null);
  const containerRef = useRef(null);
  const isVisibleRef = useRef(false);

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
  const showThumb = thumbUrl && !videoReady;

  // Auto-play via IntersectionObserver when modal is open
  useEffect(() => {
    if (!isVideo || !isOpen) return;
    const vid = videoRef.current;
    if (!vid) return;
    // Small delay to let modal render
    const t = setTimeout(() => { vid.play().catch(() => {}); }, 200);
    return () => clearTimeout(t);
  }, [isVideo, isOpen, mediaSrc]);

  const nextMedia = (e) => { e.stopPropagation(); setCurrentIndex(i => (i + 1) % mediaItems.length); setIsPlaying(false); setVideoReady(false); };
  const prevMedia = (e) => { e.stopPropagation(); setCurrentIndex(i => (i - 1 + mediaItems.length) % mediaItems.length); setIsPlaying(false); setVideoReady(false); };

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
        <div ref={containerRef} className="relative w-full h-full flex items-center justify-center">
          {/* Thumbnail until video ready */}
          {thumbUrl && (
            <img src={thumbUrl} alt="thumbnail"
              className="absolute inset-0 w-full h-full object-contain"
              style={{ display: showThumb ? 'block' : 'none' }} />
          )}
          <video
            ref={videoRef}
            key={`${mediaSrc}-${currentIndex}`}
            src={mediaSrc}
            className="w-full h-full object-contain"
            style={{ display: videoReady ? 'block' : 'none' }}
            muted={isMuted}
            playsInline
            loop
            poster={thumbUrl || undefined}
            onLoadedMetadata={(e) => {
              setVideoReady(true);
              e.currentTarget.play().catch(() => {});
            }}
            onCanPlay={() => setVideoReady(true)}
            onPlay={() => setIsPlaying(true)}
            onPause={() => setIsPlaying(false)}
            onEnded={() => setIsPlaying(false)}
            onClick={(e) => { e.stopPropagation(); videoRef.current?.paused ? videoRef.current.play().catch(()=>{}) : videoRef.current?.pause(); }}
          />
          {/* Play overlay */}
          {!isPlaying && videoReady && (
            <div className="absolute inset-0 z-10 flex items-center justify-center pointer-events-none">
              <div className="w-16 h-16 rounded-full bg-black/40 flex items-center justify-center">
                <svg className="w-8 h-8 text-white ml-1" fill="currentColor" viewBox="0 0 24 24"><path d="M8 5v14l11-7z" /></svg>
              </div>
            </div>
          )}
          {/* Loading spinner */}
          {!videoReady && (
            <div className="absolute inset-0 z-10 flex items-center justify-center">
              <div className="w-10 h-10 border-4 border-white/30 border-t-white rounded-full animate-spin" />
            </div>
          )}
          <button onClick={(e) => { e.stopPropagation(); if (videoRef.current) videoRef.current.muted = !isMuted; setIsMuted(m => !m); }}
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
  const id = item?._id || item?.promote_reel_id;
  const author = item?.user_id || {};
  const username = author?.username || 'User';
  const fullName = author?.full_name || '';
  const avatar = author?.avatar_url || '';
  const authorId = author?._id || author?.id || (typeof item?.user_id === 'string' ? item?.user_id : null);
  const isOwner = !!(currentUserId && authorId && String(currentUserId) === String(authorId));
  const profilePath = `/profile/${authorId}`;
  const products = Array.isArray(item?.products) ? item.products : [];
  const caption = item?.caption || '';

  const [isLiked, setIsLiked] = useState(false);
  const [likeCount, setLikeCount] = useState(0);
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

  const loadReplies = useCallback(async (commentId) => {
    try {
      const data = await promoteReelService.getReplies(commentId);
      const fetched = Array.isArray(data) ? data : (data.replies || data.data || []);
      setReplies(prev => ({ ...prev, [commentId]: fetched }));
    } catch {}
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
        }).catch(() => {});
      });
    } catch {}
    finally { setLoadingComments(false); }
  }, []);

  useEffect(() => {
    if (isOpen && initialItem) {
      setItem(initialItem);
      setNewComment(''); setReplyTo(null); setReplies({}); setExpandedComments({});
      setIsLiked(initialItem.is_liked_by_me || false);
      setLikeCount(initialItem.likes_count ?? (Array.isArray(initialItem.likes) ? initialItem.likes.length : 0));
      const rid = initialItem._id || initialItem.promote_reel_id;
      if (rid) {
        promoteReelService.getPromoteReelById(rid).then(data => setItem(data)).catch(() => {});
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
    try { isLikedArg ? await promoteReelService.unlikeComment(commentId) : await promoteReelService.likeComment(commentId); fetchComments(id); } catch {}
  };
  const handleLikeReply = async (replyId, isLikedArg) => {
    try { isLikedArg ? await promoteReelService.unlikeComment(replyId) : await promoteReelService.likeComment(replyId); Object.keys(replies).forEach(key => loadReplies(key)); } catch {}
  };
  const handleDeleteComment = async (commentId) => {
    if (!window.confirm('Delete this comment?')) return;
    try { await promoteReelService.deleteComment(commentId); setComments(prev => prev.filter(c => (c._id || c.id) !== commentId)); setItem(prev => ({ ...prev, comments_count: Math.max(0, (prev?.comments_count || 1) - 1) })); } catch {}
  };
  const handleDeleteReply = async (replyId) => {
    if (!window.confirm('Delete this reply?')) return;
    try { await promoteReelService.deleteComment(replyId); Object.keys(replies).forEach(key => loadReplies(key)); } catch {}
  };
  const onToggleReplies = (commentId) => {
    const isExpanded = expandedComments[commentId];
    if (!isExpanded && (!replies[commentId] || replies[commentId].length === 0)) loadReplies(commentId);
    setExpandedComments(prev => ({ ...prev, [commentId]: !prev[commentId] }));
  };
  const handleLike = async () => {
    if (!userObject || !id) return;
    const wasLiked = isLiked;
    setIsLiked(!wasLiked); setLikeCount(c => !wasLiked ? c + 1 : Math.max(0, c - 1));
    try { wasLiked ? await promoteReelService.unlikePromoteReel(id) : await promoteReelService.likePromoteReel(id); }
    catch { setIsLiked(wasLiked); setLikeCount(c => wasLiked ? c + 1 : Math.max(0, c - 1)); }
  };
  const handleDelete = async () => {
    setIsDeleting(true);
    try { await promoteReelService.deletePromoteReel(id); await new Promise(r => setTimeout(r, 800)); onClose(); window.location.reload(); }
    catch { alert('Failed to delete'); setIsDeleting(false); setShowDeleteModal(false); }
  };

  if (!isOpen || !item) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4 md:p-10">
      <button onClick={onClose} className="absolute top-4 right-4 text-white hover:opacity-75 z-[60]">
        <X size={24} />
      </button>

      <div className="bg-white dark:bg-black max-w-[90vw] md:max-w-[1200px] w-full max-h-[90vh] h-full md:h-[85vh] flex flex-col md:flex-row overflow-hidden rounded-md md:rounded-r-xl animate-in fade-in zoom-in duration-200">

        {/* Left: Media */}
        <div className="w-full md:w-[55%] h-[42vh] md:h-full">
          <ModalMediaPanel item={item} isOpen={isOpen} />
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
                {item.location && <p className="text-xs text-gray-400">{item.location}</p>}
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
                  <button onClick={handleLike} className="hover:opacity-50 transition-opacity active:scale-90">
                    <Heart size={24} className={isLiked ? 'fill-red-500 text-red-500' : 'text-gray-900 dark:text-white'} />
                  </button>
                  <button className="hover:opacity-50 transition-opacity">
                    <MessageCircle size={24} className="text-gray-900 dark:text-white" />
                  </button>
                  <button type="button" onClick={() => setShowShareModal(true)} className="hover:opacity-50 transition-opacity">
                    <Send size={24} className="text-gray-900 dark:text-white" />
                  </button>
                </div>
                <div className="flex items-center gap-3">
                  {!isOwner && authorId && userObject && <FollowButton targetUserId={String(authorId)} />}
                </div>
              </div>
              <div className="font-semibold text-sm text-gray-900 dark:text-white mb-1">{fmt(likeCount)} likes</div>
              <div className="text-[10px] text-gray-400 uppercase tracking-wide">{formatDateFull(item.createdAt || item.created_at)}</div>
            </div>

            {replyTo && (
              <div className="px-3 md:px-4 py-2 bg-gray-50 dark:bg-gray-900 flex justify-between items-center text-xs text-gray-500 dark:text-gray-400">
                <span>Replying to <span className="font-semibold text-blue-500">@{replyTo.username}</span></span>
                <button onClick={() => setReplyTo(null)}><X size={14} /></button>
              </div>
            )}

            <form onSubmit={handlePostComment} className="border-t border-gray-100 dark:border-gray-800 p-3 md:p-4 flex items-center gap-3">
              <button type="button" className="text-gray-900 dark:text-white hover:opacity-50 shrink-0"><Smile size={24} /></button>
              <input type="text"
                placeholder={replyTo ? `Reply to @${replyTo.username}...` : 'Add a comment...'}
                className="flex-1 text-sm outline-none text-gray-900 dark:text-white bg-transparent placeholder-gray-400 dark:placeholder-gray-500"
                value={newComment} onChange={e => setNewComment(e.target.value)} />
              <button type="submit" disabled={!newComment.trim()}
                className={`text-blue-500 font-semibold text-sm shrink-0 ${!newComment.trim() ? 'opacity-40' : 'hover:text-blue-700'}`}>
                Post
              </button>
            </form>
          </div>
        </div>
      </div>

      <ShareContentModal isOpen={showShareModal} onClose={() => setShowShareModal(false)}
        contentType="promote_reel" contentId={id} />
    </div>
  );
};

export default PromoteDetailModal;