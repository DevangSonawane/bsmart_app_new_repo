import React, { useState, useEffect, useCallback } from 'react';
import {
  X, Heart, MessageCircle, Send, MoreHorizontal,
  Smile, ChevronLeft, ChevronRight, Loader2, UserPlus, UserCheck
} from 'lucide-react';
import { useSelector } from 'react-redux';
import { Link } from 'react-router-dom';
import api from '../lib/api';
import tweetCommentService from '../services/tweetCommentService';
import Avatar from './Avatar';
import ContentReportModal from './ContentReportModal';
import ShareContentModal from './ShareContentModal';

const BASE_URL = 'https://api.bebsmart.in';
const fmt = (n = 0) => { if (n >= 1_000_000) return (n/1e6).toFixed(1)+'M'; if (n >= 1_000) return (n/1e3).toFixed(1)+'k'; return String(n); };
const formatDateFull = (d) => { if (!d) return ''; const dt = new Date(d); return isNaN(dt) ? '' : dt.toLocaleDateString('en-US',{month:'long',day:'numeric',year:'numeric'}).toUpperCase(); };
const formatDateRel = (d) => { if (!d) return ''; const s = Math.floor((Date.now()-new Date(d))/1000); if(s<60) return 'Just now'; if(s<3600) return Math.floor(s/60)+'m'; if(s<86400) return Math.floor(s/3600)+'h'; if(s<604800) return Math.floor(s/86400)+'d'; return Math.floor(s/604800)+'w'; };
const resolveUrl = (raw) => { if (!raw) return null; const s = String(raw); if (s.startsWith('http')) return s; return `${BASE_URL}/uploads/${s.replace(/^\/+/,'').replace(/^uploads\//,'')}`; };

const DeleteModal = ({ isOpen, onClose, onConfirm, isDeleting }) => {
  if (!isOpen) return null;
  return (
    <div className="fixed inset-0 z-[70] flex items-center justify-center bg-black/50 backdrop-blur-sm p-4">
      <div className="bg-white dark:bg-gray-900 rounded-xl p-6 w-full max-w-sm shadow-2xl">
        {isDeleting ? (
          <div className="flex flex-col items-center py-8">
            <div className="animate-spin w-12 h-12 border-4 border-gray-200 border-t-red-500 rounded-full mb-4" />
            <p className="text-gray-500 font-medium animate-pulse">Deleting tweet...</p>
          </div>
        ) : (
          <>
            <h3 className="text-lg font-bold text-gray-900 dark:text-white mb-2 text-center">Delete Tweet?</h3>
            <p className="text-gray-500 dark:text-gray-400 text-sm mb-6 text-center">This action cannot be undone.</p>
            <div className="flex gap-3">
              <button onClick={onClose} className="flex-1 px-4 py-2.5 rounded-lg border border-gray-200 dark:border-gray-700 font-medium text-gray-700 dark:text-gray-300">Cancel</button>
              <button onClick={onConfirm} className="flex-1 px-4 py-2.5 rounded-lg bg-red-500 text-white font-medium hover:bg-red-600">Delete</button>
            </div>
          </>
        )}
      </div>
    </div>
  );
};

const FollowButton = ({ targetUserId }) => {
  const { userObject } = useSelector(s => s.auth);
  const [following, setFollowing] = useState(false);
  const [loading, setLoading] = useState(false);
  const handleClick = useCallback(async (e) => {
    e.stopPropagation(); if (!userObject || loading) return;
    const was = following; setFollowing(!was); setLoading(true);
    try { await api.post(was ? '/unfollow' : '/follow', { followedUserId: targetUserId }); }
    catch { setFollowing(was); } finally { setLoading(false); }
  }, [userObject, loading, following, targetUserId]);
  if (!targetUserId) return null;
  return (
    <button onClick={handleClick} disabled={loading} className={`flex items-center gap-1.5 text-xs font-bold px-3 py-1 rounded-full border transition-all ${loading?'opacity-50':''} ${following?'border-gray-300 dark:border-gray-600 text-gray-500':'border-blue-500 text-blue-500 bg-blue-50 dark:bg-blue-500/10'}`}>
      {loading ? <Loader2 size={10} className="animate-spin"/> : following ? <UserCheck size={10}/> : <UserPlus size={10}/>}
      <span>{following ? 'Following' : 'Follow'}</span>
    </button>
  );
};

const CommentRow = ({ comment, onLike, onDelete, onReply, currentUserId }) => {
  const user = comment.user || comment.users || {};
  const isOwner = currentUserId && (String(user._id||user.id)===String(currentUserId)||String(comment.user_id)===String(currentUserId));
  const isLiked = comment.is_liked_by_me;
  const likesCount = comment.likes_count || (comment.likes?.length ?? 0);
  const commentId = comment._id || comment.id;
  return (
    <div className="flex gap-3 mb-4">
      <Link to={`/profile/${user.username}`} className="shrink-0"><Avatar src={user.avatar_url} username={user.username} size="sm" /></Link>
      <div className="flex-1 text-sm">
        <div className="flex items-start justify-between gap-2">
          <div>
            <Link to={`/profile/${user.username}`} className="font-semibold dark:text-white hover:underline mr-1">{user.full_name||user.username||'User'}</Link>
            <span className="text-gray-900 dark:text-gray-100 whitespace-pre-wrap">{comment.text}</span>
          </div>
          <button onClick={() => onLike(commentId, !isLiked)} className="shrink-0 flex flex-col items-center gap-0.5">
            <Heart size={12} fill={isLiked?'red':'none'} stroke={isLiked?'red':'currentColor'} className="text-gray-400"/>
            {likesCount > 0 && <span className="text-[10px] text-gray-400">{likesCount}</span>}
          </button>
        </div>
        <div className="flex items-center gap-3 mt-1 text-[11px] text-gray-400">
          <span>{formatDateRel(comment.createdAt||comment.created_at)}</span>
          <button onClick={() => onReply(user)} className="font-semibold hover:text-gray-600 dark:hover:text-gray-200">Reply</button>
          {isOwner && <button onClick={() => onDelete(commentId)} className="hover:text-red-500">Delete</button>}
        </div>
      </div>
    </div>
  );
};

const TweetMediaPanel = ({ tweet }) => {
  const mediaItems = Array.isArray(tweet?.media) ? tweet.media : [];
  const images = mediaItems.map(item => resolveUrl(item?.fileUrl||item?.url||item?.fileName)).filter(Boolean);
  const [index, setIndex] = useState(0);
  if (!images.length) {
    return (
      <div className="w-full h-full bg-gray-50 dark:bg-[#0a0a0a] flex items-center justify-center p-8">
        <p className="text-gray-700 dark:text-gray-200 text-xl leading-relaxed text-center font-light">{tweet?.content||''}</p>
      </div>
    );
  }
  return (
    <div className="relative w-full h-full bg-black flex items-center justify-center overflow-hidden">
      <img key={index} src={images[index]} alt="Tweet media" className="w-full h-full object-contain"/>
      {images.length > 1 && (
        <>
          <button onClick={() => setIndex(i => (i-1+images.length)%images.length)} className="absolute left-3 top-1/2 -translate-y-1/2 w-8 h-8 rounded-full bg-black/50 flex items-center justify-center text-white hover:bg-black/70"><ChevronLeft size={18}/></button>
          <button onClick={() => setIndex(i => (i+1)%images.length)} className="absolute right-3 top-1/2 -translate-y-1/2 w-8 h-8 rounded-full bg-black/50 flex items-center justify-center text-white hover:bg-black/70"><ChevronRight size={18}/></button>
          <div className="absolute bottom-3 left-1/2 -translate-x-1/2 flex gap-1.5">
            {images.map((_,i) => <button key={i} onClick={() => setIndex(i)} className={`w-1.5 h-1.5 rounded-full transition-all ${i===index?'bg-white':'bg-white/40'}`}/>)}
          </div>
          <div className="absolute top-3 right-3 bg-black/50 text-white text-xs px-2 py-0.5 rounded-full">{index+1}/{images.length}</div>
        </>
      )}
    </div>
  );
};

const TweetDetailModal = ({ tweet: initialTweet, isOpen, onClose }) => {
  const { userObject } = useSelector(s => s.auth);
  const currentUserId = userObject?._id || userObject?.id;
  const [tweet, setTweet] = useState(initialTweet);
  const [isLiked, setIsLiked] = useState(false);
  const [likeCount, setLikeCount] = useState(0);
  const [comments, setComments] = useState([]);
  const [newComment, setNewComment] = useState('');
  const [replyTo, setReplyTo] = useState(null);
  const [loadingComments, setLoadingComments] = useState(false);
  const [postingComment, setPostingComment] = useState(false);
  const [showDeleteModal, setShowDeleteModal] = useState(false);
  const [isDeleting, setIsDeleting] = useState(false);
  const [showReportModal, setShowReportModal] = useState(false);
  const [showShareModal, setShowShareModal] = useState(false);

  const tweetId = tweet?._id || tweet?.id;
  const author = tweet?.author || tweet?.user || {};
  const username = author.username || 'User';
  const fullName = author.full_name || author.name || '';
  const avatar = author.avatar_url || '';
  const userId = author._id || author.id;
  const isOwner = currentUserId && String(userId) === String(currentUserId);
  const profilePath = `/profile/${username}`;
  const contentText = tweet?.content || tweet?.caption || '';

  const fetchComments = useCallback(async (id) => {
    if (!id) return;
    setLoadingComments(true);
    try { const data = await tweetCommentService.getComments(id); setComments(Array.isArray(data) ? data : (data?.data||[])); }
    catch (e) { console.error(e); } finally { setLoadingComments(false); }
  }, []);

  useEffect(() => {
    if (isOpen && initialTweet) {
      setTweet(initialTweet);
      setIsLiked(initialTweet.is_liked_by_me || false);
      setLikeCount(initialTweet.likes_count || 0);
      setNewComment(''); setReplyTo(null);
      fetchComments(initialTweet._id || initialTweet.id);
      if (initialTweet._id) { api.get(`/tweets/${initialTweet._id}`).then(({data}) => setTweet(data)).catch(()=>{}); }
    }
  }, [isOpen, initialTweet, fetchComments]);

  useEffect(() => {
    if (!isOpen) return;
    const fn = (e) => { if (e.key === 'Escape') onClose(); };
    window.addEventListener('keydown', fn);
    return () => window.removeEventListener('keydown', fn);
  }, [isOpen, onClose]);

  const handleLike = async () => {
    if (!userObject) return;
    const was = isLiked; setIsLiked(!was); setLikeCount(c => !was ? c+1 : Math.max(0,c-1));
    try { await api.post(`/tweets/${tweetId}/${was?'unlike':'like'}`); }
    catch { setIsLiked(was); setLikeCount(c => was ? c+1 : Math.max(0,c-1)); }
  };

  const handlePostComment = async (e) => {
    e?.preventDefault();
    if (!newComment.trim() || !tweetId || postingComment) return;
    const text = newComment.trim(); const ri = replyTo;
    setNewComment(''); setReplyTo(null); setPostingComment(true);
    try { await tweetCommentService.createComment(tweetId, text, ri?.id||null); await fetchComments(tweetId); }
    catch (err) { console.error(err); setNewComment(text); if (ri) setReplyTo(ri); }
    finally { setPostingComment(false); }
  };

  const handleLikeComment = async (commentId, like) => {
    try { like ? await tweetCommentService.unlikeComment(commentId) : await tweetCommentService.likeComment(commentId); fetchComments(tweetId); }
    catch (e) { console.error(e); }
  };

  const handleDeleteComment = async (commentId) => {
    if (!window.confirm('Delete this comment?')) return;
    try { await tweetCommentService.deleteComment(commentId); setComments(prev => prev.filter(c => (c._id||c.id) !== commentId)); }
    catch (e) { console.error(e); }
  };

  const handleDeleteTweet = async () => {
    setIsDeleting(true);
    try { await api.delete(`/tweets/${tweetId}`); await new Promise(r => setTimeout(r,800)); onClose(); window.location.reload(); }
    catch { alert('Failed to delete tweet'); setIsDeleting(false); setShowDeleteModal(false); }
  };

  if (!isOpen || !tweet) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4 md:p-10">
      <button onClick={onClose} className="absolute top-4 right-4 text-white hover:opacity-75 z-[60]"><X size={24}/></button>

      <div className="bg-white dark:bg-black max-w-[90vw] md:max-w-[1100px] w-full max-h-[90vh] h-full md:h-[85vh] flex flex-col md:flex-row overflow-hidden rounded-md md:rounded-r-xl animate-in fade-in zoom-in duration-200">

        {/* Left: Media */}
        <div className="w-full md:w-[55%] h-[42vh] md:h-full bg-black">
          <TweetMediaPanel tweet={tweet}/>
        </div>

        {/* Right: Details */}
        <div className="flex flex-col w-full md:w-[45%] h-full bg-white dark:bg-black border-l border-gray-100 dark:border-gray-800">

          {/* Header */}
          <div className="flex items-center justify-between p-3 md:p-4 border-b border-gray-100 dark:border-gray-800 shrink-0">
            <div className="flex items-center gap-3 min-w-0">
              <Link to={profilePath}><Avatar src={avatar} username={username}/></Link>
              <div className="min-w-0">
                <Link to={profilePath} className="font-semibold text-sm text-gray-900 dark:text-white hover:opacity-70 truncate block">{username}</Link>
                {fullName && fullName !== username && <p className="text-xs text-gray-500 truncate">{fullName}</p>}
              </div>
            </div>
            <button onClick={() => isOwner ? setShowDeleteModal(true) : setShowReportModal(true)} className="text-gray-900 dark:text-white hover:opacity-50 p-1 rounded-full hover:bg-gray-100 dark:hover:bg-gray-800 transition-colors">
              <MoreHorizontal size={20}/>
            </button>
          </div>

          <DeleteModal isOpen={showDeleteModal} onClose={() => setShowDeleteModal(false)} onConfirm={handleDeleteTweet} isDeleting={isDeleting}/>
          <ContentReportModal isOpen={showReportModal} onClose={() => setShowReportModal(false)} contentType="tweet" contentId={tweetId} contentUrl={`${window.location.origin}/post/${tweetId}?type=tweet`}/>

          {/* Scrollable comments */}
          <div className="flex-1 overflow-y-auto p-3 md:p-4 scrollbar-hide">
            {contentText && (
              <div className="flex gap-3 mb-4">
                <Link to={profilePath} className="shrink-0"><Avatar src={avatar} username={username} size="sm"/></Link>
                <div className="flex-1 text-sm">
                  <Link to={profilePath} className="font-semibold mr-2 dark:text-white hover:underline">{username}</Link>
                  <span className="text-gray-900 dark:text-gray-100 whitespace-pre-wrap">{contentText}</span>
                  <p className="text-[10px] text-gray-400 mt-1">{formatDateRel(tweet.createdAt||tweet.created_at)}</p>
                </div>
              </div>
            )}
            {loadingComments ? (
              <div className="flex justify-center py-4"><Loader2 size={24} className="animate-spin text-gray-400"/></div>
            ) : comments.length > 0 ? (
              comments.map(comment => (
                <CommentRow key={comment._id||comment.id} comment={comment} onLike={handleLikeComment} onDelete={handleDeleteComment} onReply={(u) => setReplyTo({id:comment._id||comment.id, username:u.username})} currentUserId={currentUserId}/>
              ))
            ) : (
              <div className="flex flex-col items-center justify-center py-8 text-gray-400 text-sm">
                <MessageCircle size={32} className="mb-2 opacity-40"/>
                <p>No comments yet. Be the first!</p>
              </div>
            )}
          </div>

          {/* Footer */}
          <div className="border-t border-gray-100 dark:border-gray-800 bg-white dark:bg-black shrink-0">
            <div className="p-3 md:p-4 pb-2">
              <div className="flex justify-between mb-2">
                <div className="flex gap-4">
                  <button onClick={handleLike} className="hover:opacity-50 transition-opacity active:scale-90">
                    <Heart size={24} className={isLiked?'fill-red-500 text-red-500':'text-gray-900 dark:text-white'}/>
                  </button>
                  <button className="hover:opacity-50 transition-opacity"><MessageCircle size={24} className="text-gray-900 dark:text-white"/></button>
                  <button onClick={() => setShowShareModal(true)} className="hover:opacity-50 transition-opacity"><Send size={24} className="text-gray-900 dark:text-white"/></button>
                </div>
                <div className="flex items-center gap-3">
                  {!isOwner && userId && userObject && <FollowButton targetUserId={String(userId)}/>}
                </div>
              </div>
              <div className="font-semibold text-sm text-gray-900 dark:text-white mb-1">{fmt(likeCount)} likes</div>
              <div className="text-[10px] text-gray-400 uppercase tracking-wide">{formatDateFull(tweet.createdAt||tweet.created_at)}</div>
            </div>
            {replyTo && (
              <div className="px-3 md:px-4 py-2 bg-gray-50 dark:bg-gray-900 flex justify-between items-center text-xs text-gray-500 dark:text-gray-400">
                <span>Replying to <span className="font-semibold text-blue-500">@{replyTo.username}</span></span>
                <button onClick={() => setReplyTo(null)}><X size={14}/></button>
              </div>
            )}
            <form onSubmit={handlePostComment} className="border-t border-gray-100 dark:border-gray-800 p-3 md:p-4 flex items-center gap-3">
              <button type="button" className="text-gray-900 dark:text-white hover:opacity-50 shrink-0"><Smile size={24}/></button>
              <input type="text" placeholder={replyTo ? `Reply to @${replyTo.username}...` : 'Add a comment...'} className="flex-1 text-sm outline-none text-gray-900 dark:text-white bg-transparent placeholder-gray-400 dark:placeholder-gray-500" value={newComment} onChange={e => setNewComment(e.target.value)} disabled={postingComment}/>
              <button type="submit" disabled={!newComment.trim()||postingComment} className={`text-blue-500 font-semibold text-sm shrink-0 ${!newComment.trim()||postingComment?'opacity-40':'hover:text-blue-700'}`}>
                {postingComment ? <Loader2 size={16} className="animate-spin"/> : 'Post'}
              </button>
            </form>
          </div>
        </div>
      </div>

      <ShareContentModal isOpen={showShareModal} onClose={() => setShowShareModal(false)} contentType="tweet" contentId={tweetId}/>
    </div>
  );
};

export default TweetDetailModal;