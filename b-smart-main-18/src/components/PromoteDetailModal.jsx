import React, { useState, useEffect, useCallback } from 'react';
import { useSelector } from 'react-redux';
import {
  X, Heart, MessageCircle, Send, Bookmark, MoreHorizontal,
  Volume2, VolumeX, ShoppingBag, ExternalLink, Star, Tag, ChevronRight
} from 'lucide-react';
import promoteReelService from '../services/promoteReelService';
import PromoteCommentSheet from './PromoteCommentSheet';

// ─── Product Card ─────────────────────────────────────────────────────────
const ProductCard = ({ product }) => {
  const discountPct = product.discount_amount && product.product_price
    ? Math.round((product.discount_amount / product.product_price) * 100)
    : 0;
  const finalPrice = product.product_price - (product.discount_amount || 0);

  return (
    <div className="flex-shrink-0 w-44 bg-white dark:bg-white/5 rounded-2xl overflow-hidden border border-gray-100 dark:border-white/10 shadow-sm hover:shadow-md transition-shadow">
      {/* Placeholder image area */}
      <div className="w-full h-28 bg-gradient-to-br from-purple-100 to-pink-100 dark:from-purple-900/30 dark:to-pink-900/30 flex items-center justify-center">
        <ShoppingBag size={28} className="text-purple-400" />
      </div>
      <div className="p-2.5">
        <p className="text-xs font-bold text-gray-900 dark:text-white line-clamp-2 leading-tight mb-1">{product.product_name}</p>
        {product.product_description && (
          <p className="text-[10px] text-gray-500 dark:text-gray-400 line-clamp-2 leading-tight mb-2">{product.product_description}</p>
        )}
        <div className="flex items-center justify-between">
          <div>
            <span className="text-sm font-black text-purple-600 dark:text-purple-400">₹{finalPrice}</span>
            {discountPct > 0 && (
              <div className="flex items-center gap-1 mt-0.5">
                <span className="text-[10px] text-gray-400 line-through">₹{product.product_price}</span>
                <span className="text-[10px] font-bold text-green-500">{discountPct}% off</span>
              </div>
            )}
          </div>
          {product.visit_link && (
            <a
              href={product.visit_link}
              target="_blank"
              rel="noopener noreferrer"
              className="w-7 h-7 rounded-full bg-purple-100 dark:bg-purple-900/40 flex items-center justify-center text-purple-600 dark:text-purple-400 hover:bg-purple-200 dark:hover:bg-purple-800/40 transition-colors"
              onClick={e => e.stopPropagation()}
            >
              <ExternalLink size={12} />
            </a>
          )}
        </div>
      </div>
    </div>
  );
};

// ─── Main Modal ────────────────────────────────────────────────────────────
const PromoteDetailModal = ({ promoteReel, isOpen, onClose, onLikeChange }) => {
  const { userObject } = useSelector(s => s.auth);
  const currentUserId = userObject?._id || userObject?.id;

  const [detail, setDetail] = useState(null);
  const [loading, setLoading] = useState(false);
  const [isMuted, setIsMuted] = useState(true);
  const [liked, setLiked] = useState(false);
  const [likesCount, setLikesCount] = useState(0);
  const [commentCount, setCommentCount] = useState(0);
  const [showComments, setShowComments] = useState(false);
  const [showProducts, setShowProducts] = useState(false);

  const id = promoteReel?._id || promoteReel?.promote_reel_id;

  const load = useCallback(async () => {
    if (!id) return;
    setLoading(true);
    try {
      const data = await promoteReelService.getPromoteReelById(id);
      setDetail(data);
      setLiked(data.is_liked_by_me || false);
      setLikesCount(data.likes_count || 0);
      setCommentCount(data.comments_count || data.commentsCount || 0);
    } catch { setDetail(promoteReel); }
    finally { setLoading(false); }
  }, [id, promoteReel]);

  useEffect(() => {
    if (isOpen) {
      load();
      setShowComments(false);
      setShowProducts(false);
    }
  }, [isOpen, load]);

  const handleLike = async () => {
    try {
      if (liked) {
        await promoteReelService.unlikePromoteReel(id);
        setLiked(false);
        setLikesCount(c => Math.max(0, c - 1));
        onLikeChange?.(id, false);
      } else {
        await promoteReelService.likePromoteReel(id);
        setLiked(true);
        setLikesCount(c => c + 1);
        onLikeChange?.(id, true);
      }
    } catch { /* ignore */ }
  };

  if (!isOpen) return null;

  const d = detail || promoteReel;
  if (!d) return null;

  const user = d.user_id || {};
  const username = user.username || user.full_name || 'User';
  const avatarUrl = user.avatar_url;
  const mediaItem = Array.isArray(d.media) ? d.media[0] : null;
  const videoUrl = mediaItem?.fileUrl || mediaItem?.url;
  const products = d.products || [];

  return (
    <>
      {/* Backdrop */}
      <div className="fixed inset-0 z-[70] bg-black/70 backdrop-blur-sm" onClick={onClose} />

      {/* Modal */}
      <div className="fixed inset-0 z-[71] flex items-center justify-center p-4 md:p-8" onClick={e => e.target === e.currentTarget && onClose()}>
        <div className="w-full max-w-4xl bg-white dark:bg-[#0d0d0d] rounded-3xl overflow-hidden shadow-2xl flex flex-col md:flex-row max-h-[92vh]">

          {/* Left: Video */}
          <div className="relative bg-black flex-shrink-0 w-full md:w-[320px] aspect-[9/16] md:aspect-auto md:h-auto flex items-center justify-center">
            {videoUrl ? (
              <video
                src={videoUrl}
                className="w-full h-full object-cover"
                autoPlay
                loop
                muted={isMuted}
                playsInline
              />
            ) : (
              <div className="w-full h-full bg-gradient-to-br from-purple-900 to-pink-900 flex items-center justify-center">
                <ShoppingBag size={48} className="text-white/30" />
              </div>
            )}

            {/* Gradient overlay */}
            <div className="absolute inset-0 bg-gradient-to-t from-black/60 via-transparent to-black/20 pointer-events-none" />

            {/* Mute */}
            <button
              onClick={() => setIsMuted(!isMuted)}
              className="absolute top-3 right-3 w-8 h-8 rounded-full bg-black/50 backdrop-blur-sm flex items-center justify-center text-white hover:bg-black/70 transition-colors"
            >
              {isMuted ? <VolumeX size={14} /> : <Volume2 size={14} />}
            </button>

            {/* Close (mobile) */}
            <button
              onClick={onClose}
              className="md:hidden absolute top-3 left-3 w-8 h-8 rounded-full bg-black/50 backdrop-blur-sm flex items-center justify-center text-white"
            >
              <X size={14} />
            </button>

            {/* Bottom info overlay */}
            <div className="absolute bottom-0 left-0 right-0 p-4">
              <div className="flex items-center gap-2.5 mb-2">
                <div className="w-9 h-9 rounded-xl bg-gradient-to-br from-purple-500 to-pink-500 flex items-center justify-center overflow-hidden flex-shrink-0">
                  {avatarUrl
                    ? <img src={avatarUrl} alt={username} className="w-full h-full object-cover" />
                    : <span className="text-white text-sm font-bold">{username.charAt(0).toUpperCase()}</span>}
                </div>
                <div>
                  <p className="text-white text-sm font-bold leading-tight">{username}</p>
                  <p className="text-white/60 text-xs">Promoted</p>
                </div>
              </div>
              <p className="text-white/90 text-sm leading-relaxed line-clamp-2">{d.caption}</p>
            </div>
          </div>

          {/* Right: Details */}
          <div className="flex-1 flex flex-col overflow-hidden">
            {/* Header */}
            <div className="flex-shrink-0 flex items-center justify-between px-5 py-4 border-b border-gray-100 dark:border-white/10">
              <div className="flex items-center gap-2.5">
                <div className="w-8 h-8 rounded-full bg-gradient-to-br from-purple-500 to-pink-500 flex items-center justify-center overflow-hidden">
                  {avatarUrl
                    ? <img src={avatarUrl} alt={username} className="w-full h-full object-cover" />
                    : <span className="text-white text-xs font-bold">{username.charAt(0).toUpperCase()}</span>}
                </div>
                <div>
                  <p className="text-sm font-bold text-gray-900 dark:text-white">{username}</p>
                  <div className="flex items-center gap-1 text-[10px] text-gray-400">
                    <Star size={9} className="fill-amber-400 text-amber-400" />
                    <span>Sponsored</span>
                  </div>
                </div>
              </div>
              <div className="flex items-center gap-2">
                <button className="w-8 h-8 rounded-full bg-gray-100 dark:bg-white/10 flex items-center justify-center text-gray-600 dark:text-gray-300 hover:bg-gray-200 dark:hover:bg-white/20 transition-colors">
                  <MoreHorizontal size={16} />
                </button>
                <button
                  onClick={onClose}
                  className="hidden md:flex w-8 h-8 rounded-full bg-gray-100 dark:bg-white/10 items-center justify-center text-gray-600 dark:text-gray-300 hover:bg-gray-200 dark:hover:bg-white/20 transition-colors"
                >
                  <X size={16} />
                </button>
              </div>
            </div>

            {/* Scrollable body */}
            <div className="flex-1 overflow-y-auto px-5 py-4 space-y-5" style={{ scrollbarWidth: 'none' }}>

              {/* Caption */}
              {d.caption && (
                <p className="text-sm text-gray-700 dark:text-gray-200 leading-relaxed">{d.caption}</p>
              )}

              {/* Tags */}
              {Array.isArray(d.tags) && d.tags.length > 0 && (
                <div className="flex flex-wrap gap-1.5">
                  {d.tags.map((tag, i) => (
                    <span key={i} className="inline-flex items-center gap-1 px-2.5 py-1 rounded-full bg-purple-50 dark:bg-purple-900/20 text-purple-600 dark:text-purple-400 text-xs font-medium">
                      <Tag size={9} />
                      {String(tag).startsWith('#') ? tag : `#${tag}`}
                    </span>
                  ))}
                </div>
              )}

              {/* Products section */}
              {products.length > 0 && (
                <div>
                  <button
                    onClick={() => setShowProducts(v => !v)}
                    className="w-full flex items-center justify-between px-4 py-3 rounded-2xl bg-gradient-to-r from-purple-50 to-pink-50 dark:from-purple-950/30 dark:to-pink-950/30 border border-purple-100 dark:border-purple-900/30 mb-3"
                  >
                    <div className="flex items-center gap-2">
                      <ShoppingBag size={16} className="text-purple-500" />
                      <span className="text-sm font-bold text-purple-700 dark:text-purple-300">
                        {products.length} Product{products.length > 1 ? 's' : ''} Featured
                      </span>
                    </div>
                    <ChevronRight size={16} className={`text-purple-400 transition-transform ${showProducts ? 'rotate-90' : ''}`} />
                  </button>

                  {showProducts && (
                    <div className="flex gap-3 overflow-x-auto pb-2" style={{ scrollbarWidth: 'none' }}>
                      {products.map((p, i) => <ProductCard key={i} product={p} />)}
                    </div>
                  )}
                </div>
              )}

              {/* Location */}
              {d.location && (
                <p className="text-xs text-gray-400 flex items-center gap-1">
                  <span>📍</span> {d.location}
                </p>
              )}
            </div>

            {/* Action bar */}
            <div className="flex-shrink-0 flex items-center gap-4 px-5 py-4 border-t border-gray-100 dark:border-white/10">
              <button
                onClick={handleLike}
                className={`flex items-center gap-1.5 transition-colors ${liked ? 'text-red-500' : 'text-gray-400 hover:text-red-400'}`}
              >
                <Heart size={22} className={liked ? 'fill-current' : ''} />
                <span className="text-sm font-semibold">{likesCount > 0 ? likesCount : ''}</span>
              </button>

              <button
                onClick={() => setShowComments(true)}
                className="flex items-center gap-1.5 text-gray-400 hover:text-purple-500 transition-colors"
              >
                <MessageCircle size={22} />
                <span className="text-sm font-semibold">{commentCount > 0 ? commentCount : ''}</span>
              </button>

              <button className="text-gray-400 hover:text-gray-600 dark:hover:text-gray-200 transition-colors">
                <Send size={22} className="-rotate-12" />
              </button>

              <button className="ml-auto text-gray-400 hover:text-gray-600 dark:hover:text-gray-200 transition-colors">
                <Bookmark size={22} />
              </button>
            </div>
          </div>
        </div>
      </div>

      {/* Comment Sheet */}
      <PromoteCommentSheet
        promoteReelId={id}
        isOpen={showComments}
        onClose={() => setShowComments(false)}
        commentCount={commentCount}
        onCommentCountChange={setCommentCount}
      />
    </>
  );
};

export default PromoteDetailModal;
