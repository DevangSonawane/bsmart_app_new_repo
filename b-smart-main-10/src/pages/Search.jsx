import React, { useState, useRef, useCallback, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { useSelector } from 'react-redux';
import { Search as SearchIcon, X, ArrowLeft, Loader2, Clock, Heart, MessageCircle, Eye, Play, Image, Clapperboard } from 'lucide-react';
import PostDetailModal from '../components/PostDetailModal';

const BASE_URL = 'https://api.bebsmart.in';

const authHeaders = () => {
  const token = localStorage.getItem('token');
  return { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) };
};

const getMediaUrl = (item) => {
  // Prefer fileUrl from first media object
  const fileUrl = item?.media?.[0]?.fileUrl;
  if (fileUrl) {
    // If already absolute, use as-is; else prefix with BASE_URL/uploads
    if (fileUrl.startsWith('http')) return fileUrl;
    return `${BASE_URL}/uploads/${fileUrl}`;
  }
  // Fallbacks
  return (
    item?.media?.[0]?.thumbnails?.[0]?.fileUrl ||
    item?.media?.[0]?.thumbnail_url ||
    item?.media?.[0]?.url ||
    item?.image_url ||
    item?.thumbnail_url ||
    null
  );
};

const Avatar = ({ src, name, size = 44 }) => (
  <div className="rounded-full overflow-hidden bg-gradient-to-tr from-yellow-400 via-orange-500 to-pink-500 flex-shrink-0" style={{ width: size, height: size, padding: 2 }}>
    <div className="w-full h-full rounded-full bg-white dark:bg-black overflow-hidden flex items-center justify-center">
      {src ? <img src={src} alt="" className="w-full h-full object-cover" />
            : <span className="text-sm font-bold text-gray-700 dark:text-white">{(name || '?')[0].toUpperCase()}</span>}
    </div>
  </div>
);

// ── Post card (2-col grid) ────────────────────────────────────────────────────
const PostCard = ({ post, onClick }) => {
  const thumb = getMediaUrl(post);
  const user = post.user_id || {};
  const username = user.username || post.username || '';
  const avatarUrl = user.avatar_url || post.avatar_url;

  return (
    <button onClick={() => onClick(post)}
      className="group relative aspect-square overflow-hidden rounded-xl bg-gray-100 dark:bg-gray-800 active:opacity-80 transition-opacity w-full">
      {thumb
        ? <img src={thumb} alt="" className="w-full h-full object-cover" />
        : <div className="w-full h-full flex items-center justify-center text-gray-300 dark:text-gray-600">
            <Image size={24} />
          </div>
      }
      {/* Hover overlay */}
      <div className="absolute inset-0 bg-black/50 opacity-0 group-hover:opacity-100 transition-opacity flex flex-col justify-between p-2">
        {/* User */}
        <div className="flex items-center gap-1.5">
          {avatarUrl
            ? <img src={avatarUrl} alt="" className="w-5 h-5 rounded-full object-cover border border-white/50 shrink-0" />
            : <div className="w-5 h-5 rounded-full bg-gradient-to-tr from-orange-400 to-pink-500 shrink-0" />}
          {username && <span className="text-white text-[10px] font-bold truncate">@{username}</span>}
        </div>
        {/* Stats */}
        <div className="flex items-center gap-2">
          <span className="flex items-center gap-0.5 text-white text-[10px] font-semibold">
            <Heart size={9} className="fill-white" /> {post.likes_count ?? 0}
          </span>
          <span className="flex items-center gap-0.5 text-white text-[10px] font-semibold">
            <MessageCircle size={9} className="fill-white" /> {post.comments_count ?? 0}
          </span>
          {post.views_count !== undefined && (
            <span className="flex items-center gap-0.5 text-white text-[10px] font-semibold">
              <Eye size={9} /> {post.views_count}
            </span>
          )}
        </div>
      </div>
    </button>
  );
};

// ── Reel card (2-col grid) with hover-to-play ────────────────────────────────
const ReelCard = ({ reel, onClick }) => {
  const videoRef = useRef(null);
  const hoverTimer = useRef(null);
  const [isPlaying, setIsPlaying] = useState(false);
  const thumb = reel?.media?.[0]?.thumbnail?.[0]?.fileUrl || reel?.media?.[0]?.thumbnail_url || null;
  const user = reel.user_id || {};
  const username = user.username || reel.username || '';
  const avatarUrl = user.avatar_url || reel.avatar_url;

  // Determine if the media is a video
  const fileName = reel?.media?.[0]?.fileName || reel?.media?.[0]?.fileUrl || '';
  const isVideo = /\.(mp4|mov|webm|ogg)$/i.test(fileName) || reel?.media?.[0]?.type === 'video';

  const videoSrc = isVideo
    ? (fileName.startsWith('http') ? fileName : `${BASE_URL}/uploads/${reel?.media?.[0]?.fileName || ''}`)
    : null;

  const handleMouseEnter = () => {
    if (!videoRef.current || !videoSrc) return;
    hoverTimer.current = setTimeout(() => {
      videoRef.current.currentTime = 0;
      videoRef.current.play().catch(() => {});
      setIsPlaying(true);
      // Stop after 5 seconds
      setTimeout(() => {
        if (videoRef.current) {
          videoRef.current.pause();
          videoRef.current.currentTime = 0;
        }
        setIsPlaying(false);
      }, 5000);
    }, 200);
  };

  const handleMouseLeave = () => {
    clearTimeout(hoverTimer.current);
    if (videoRef.current) {
      videoRef.current.pause();
      videoRef.current.currentTime = 0;
    }
    setIsPlaying(false);
  };

  return (
    <button
      onClick={() => onClick(reel)}
      onMouseEnter={handleMouseEnter}
      onMouseLeave={handleMouseLeave}
      className="group relative aspect-square overflow-hidden rounded-xl bg-gray-100 dark:bg-gray-800 active:opacity-80 transition-opacity w-full"
    >
      {/* Thumbnail image (always shown when not playing) */}
      {thumb && !isPlaying && (
        <img src={thumb} alt="" className="w-full h-full object-cover" />
      )}

      {/* Video element */}
      {videoSrc && (
        <video
          ref={videoRef}
          src={videoSrc}
          muted
          playsInline
          preload="none"
          className={`absolute inset-0 w-full h-full object-cover transition-opacity duration-300 ${isPlaying ? 'opacity-100' : 'opacity-0'}`}
        />
      )}

      {/* Fallback when no media or not playing */}
      {!thumb && !isPlaying && (
        <div className="w-full h-full flex items-center justify-center text-gray-300 dark:text-gray-600">
          <Clapperboard size={24} />
        </div>
      )}

      {/* Reel badge (top-right) */}
      {!isPlaying && (
        <div className="absolute top-1.5 right-1.5 bg-black/60 rounded-md px-1.5 py-0.5 flex items-center gap-0.5">
          <svg width="8" height="8" viewBox="0 0 24 24" fill="white"><polygon points="5 3 19 12 5 21 5 3"/></svg>
        </div>
      )}

      {/* Playing indicator */}
      {isPlaying && (
        <div className="absolute top-1.5 right-1.5 bg-pink-600 rounded-md px-1.5 py-0.5 flex items-center gap-0.5">
          <span className="text-white text-[8px] font-bold">LIVE</span>
        </div>
      )}

      {/* Hover overlay */}
      <div className="absolute inset-0 bg-black/40 opacity-0 group-hover:opacity-100 transition-opacity flex flex-col justify-between p-2">
        <div className="flex items-center gap-1.5">
          {avatarUrl
            ? <img src={avatarUrl} alt="" className="w-5 h-5 rounded-full object-cover border border-white/50 shrink-0" />
            : <div className="w-5 h-5 rounded-full bg-gradient-to-tr from-orange-400 to-pink-500 shrink-0" />}
          {username && <span className="text-white text-[10px] font-bold truncate">@{username}</span>}
        </div>
        <div className="flex items-center gap-2">
          <span className="flex items-center gap-0.5 text-white text-[10px] font-semibold">
            <Heart size={9} className="fill-white" /> {reel.likes_count ?? 0}
          </span>
          <span className="flex items-center gap-0.5 text-white text-[10px] font-semibold">
            <Eye size={9} /> {reel.views_count ?? 0}
          </span>
        </div>
      </div>

      {/* Center play icon on hover (before playing starts) */}
      {videoSrc && !isPlaying && (
        <div className="absolute inset-0 flex items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity pointer-events-none">
          <div className="w-10 h-10 rounded-full bg-black/50 flex items-center justify-center">
            <Play size={16} fill="white" className="text-white ml-0.5" />
          </div>
        </div>
      )}
    </button>
  );
};

// ── Load More Button ──────────────────────────────────────────────────────────
const LoadMoreBtn = ({ loading, onClick, hasMore }) => {
  if (!hasMore) return null;
  return (
    <button
      onClick={onClick}
      disabled={loading}
      className="w-full py-3 rounded-2xl border border-gray-200 dark:border-gray-800 text-sm font-semibold text-gray-600 dark:text-gray-400 hover:bg-gray-50 dark:hover:bg-gray-900 transition-colors flex items-center justify-center gap-2 disabled:opacity-60 mt-2"
    >
      {loading ? <><Loader2 size={14} className="animate-spin" /> Loading more…</> : 'Load more'}
    </button>
  );
};

export default function SearchPage() {
  const navigate = useNavigate();
  const { userObject } = useSelector((state) => state.auth);
  const userId = userObject?._id || userObject?.id;
  const inputRef = useRef(null);
  const debounceRef = useRef(null);

  const [query, setQuery]           = useState('');
  const [loading, setLoading]       = useState(false);
  const [historyLoading, setHistoryLoading] = useState(false);
  const [results, setResults]       = useState(null);
  const [history, setHistory]       = useState([]);
  const [selectedPost, setSelectedPost] = useState(null);
  const [activeTab, setActiveTab]   = useState('all');

  // ── Pagination state ─────────────────────────────────────────────────────────
  const [userLimit, setUserLimit]     = useState(10);
  const [postLimit, setPostLimit]     = useState(10);
  const [reelLimit, setReelLimit]     = useState(10);
  const [loadingMore, setLoadingMore] = useState({ users: false, posts: false, reels: false });
  const [totals, setTotals]           = useState({ users: 0, posts: 0, reels: 0 });

  const loadHistory = useCallback(async () => {
    if (!userId) return;
    setHistoryLoading(true);
    try {
      const res = await fetch(`${BASE_URL}/api/search/history/${userId}`, { headers: authHeaders() });
      if (res.ok) {
        const data = await res.json();
        setHistory(Array.isArray(data) ? data : (data.history || data.data || []));
      }
    } catch { } finally { setHistoryLoading(false); }
  }, [userId]);

  useEffect(() => { loadHistory(); }, [loadHistory]);

  const clearAllHistory = async () => {
    if (!userId) return;
    try {
      await fetch(`${BASE_URL}/api/search/history/${userId}`, { method: 'DELETE', headers: authHeaders() });
      setHistory([]);
    } catch { }
  };

  const deleteHistoryItem = async (historyId, e) => {
    e.stopPropagation();
    try {
      await fetch(`${BASE_URL}/api/search/history/${userId}/${historyId}`, { method: 'DELETE', headers: authHeaders() });
      setHistory(prev => prev.filter(h => (h._id || h.id) !== historyId));
    } catch { }
  };

  // ── Core search ──────────────────────────────────────────────────────────────
  const runSearch = useCallback(async (q, { uLimit = 10, pLimit = 10, rLimit = 10, append = false } = {}) => {
    const trimmed = q.trim();
    if (!trimmed) { setResults(null); return; }
    if (!append) setLoading(true);
    try {
      const maxLimit = Math.max(uLimit, pLimit, rLimit);
      const res = await fetch(`${BASE_URL}/api/search?q=${encodeURIComponent(trimmed)}&limit=${maxLimit}`, { headers: authHeaders() });
      if (res.ok) {
        const data = await res.json();
        const r = data.results || {};
        const users = r.users || [];
        const posts = r.posts || [];
        const reels = r.reels || [];

        setTotals({
          users: data.totals?.users ?? users.length,
          posts: data.totals?.posts ?? posts.length,
          reels: data.totals?.reels ?? reels.length,
        });

        if (append) {
          setResults(prev => ({
            users: users.slice(0, uLimit),
            posts: posts.slice(0, pLimit),
            reels: reels.slice(0, rLimit),
          }));
        } else {
          setResults({
            users: users.slice(0, uLimit),
            posts: posts.slice(0, pLimit),
            reels: reels.slice(0, rLimit),
          });
        }
      } else { setResults({ users: [], posts: [], reels: [] }); }
    } catch { setResults({ users: [], posts: [], reels: [] }); }
    finally { setLoading(false); setLoadingMore({ users: false, posts: false, reels: false }); }
  }, []);

  const handleInput = (e) => {
    const q = e.target.value;
    setQuery(q);
    setActiveTab('all');
    setUserLimit(10); setPostLimit(10); setReelLimit(10);
    clearTimeout(debounceRef.current);
    if (!q.trim()) { setResults(null); return; }
    debounceRef.current = setTimeout(() => runSearch(q), 350);
  };

  const handleHistoryClick = (item) => {
    const q = typeof item === 'string' ? item : (item.query || item.keyword || item.text || '');
    if (!q) return;
    setQuery(q);
    setActiveTab('all');
    setUserLimit(10); setPostLimit(10); setReelLimit(10);
    runSearch(q);
  };

  // ── Load More handlers ───────────────────────────────────────────────────────
  const loadMoreUsers = async () => {
    const newLimit = userLimit + 10;
    setUserLimit(newLimit);
    setLoadingMore(p => ({ ...p, users: true }));
    await runSearch(query, { uLimit: newLimit, pLimit: postLimit, rLimit: reelLimit, append: true });
  };

  const loadMorePosts = async () => {
    const newLimit = postLimit + 10;
    setPostLimit(newLimit);
    setLoadingMore(p => ({ ...p, posts: true }));
    await runSearch(query, { uLimit: userLimit, pLimit: newLimit, rLimit: reelLimit, append: true });
  };

  const loadMoreReels = async () => {
    const newLimit = reelLimit + 10;
    setReelLimit(newLimit);
    setLoadingMore(p => ({ ...p, reels: true }));
    await runSearch(query, { uLimit: userLimit, pLimit: postLimit, rLimit: newLimit, append: true });
  };

  // ── Derived data ─────────────────────────────────────────────────────────────
  const filteredUsers = (!results || activeTab === 'posts' || activeTab === 'reels') ? [] : (results?.users || []);
  const filteredPosts = (!results || activeTab === 'people' || activeTab === 'reels') ? [] : (results?.posts || []);
  const filteredReels = (!results || activeTab === 'people' || activeTab === 'posts') ? [] : (results?.reels || []);
  const hasResults    = results && (results.users.length + results.posts.length + results.reels.length) > 0;

  const tabs = [
    { key: 'all',    label: 'All' },
    { key: 'people', label: `People${results ? ` (${results.users.length})` : ''}` },
    { key: 'posts',  label: `Posts${results ? ` (${results.posts.length})` : ''}` },
    { key: 'reels',  label: `Reels${results ? ` (${results.reels.length})` : ''}` },
  ];

  const hasMoreUsers = results && results.users.length >= userLimit;
  const hasMorePosts = results && results.posts.length >= postLimit;
  const hasMoreReels = results && results.reels.length >= reelLimit;

  return (
    <>
      <div className="min-h-screen bg-white dark:bg-black flex flex-col">

        {/* Search bar */}
        <div className="sticky top-0 z-40 bg-white dark:bg-black border-b border-gray-100 dark:border-gray-800 px-3 py-2.5 flex items-center gap-2">
          <button onClick={() => navigate(-1)} className="p-1.5 -ml-1 flex-shrink-0 rounded-full hover:bg-gray-100 dark:hover:bg-gray-800 transition-colors">
            <ArrowLeft size={22} className="text-gray-900 dark:text-white" />
          </button>
          <div className="flex-1 flex items-center gap-2 bg-gray-100 dark:bg-[#1c1c1e] rounded-2xl px-4 py-2.5">
            <SearchIcon size={16} className="text-gray-400 shrink-0" />
            <input
              ref={inputRef}
              value={query}
              onChange={handleInput}
              onKeyDown={e => e.key === 'Enter' && runSearch(query)}
              placeholder="Search"
              autoFocus
              className="flex-1 bg-transparent text-sm outline-none text-gray-900 dark:text-white placeholder-gray-400"
            />
            {loading
              ? <Loader2 size={14} className="animate-spin text-gray-400 shrink-0" />
              : query
                ? <button onClick={() => { setQuery(''); setResults(null); setActiveTab('all'); inputRef.current?.focus(); }}
                    className="w-5 h-5 rounded-full bg-gray-400 dark:bg-gray-600 flex items-center justify-center shrink-0">
                    <X size={10} color="white" strokeWidth={3} />
                  </button>
                : null
            }
          </div>
        </div>

        {/* Filter tabs */}
        {results && hasResults && (
          <div className="flex gap-1.5 px-3 py-2 border-b border-gray-100 dark:border-gray-800 overflow-x-auto scrollbar-none">
            {tabs.map(tab => (
              <button key={tab.key} onClick={() => setActiveTab(tab.key)}
                className={`px-3.5 py-1.5 rounded-full text-xs font-semibold whitespace-nowrap transition-all ${
                  activeTab === tab.key
                    ? 'bg-gray-900 dark:bg-white text-white dark:text-black shadow-sm'
                    : 'bg-gray-100 dark:bg-gray-800 text-gray-600 dark:text-gray-400 hover:bg-gray-200 dark:hover:bg-gray-700'
                }`}>
                {tab.label}
              </button>
            ))}
          </div>
        )}

        {/* Body */}
        <div className="flex-1 overflow-y-auto pb-[80px]">

          {/* History */}
          {!query.trim() && (
            <>
              {historyLoading ? (
                <div className="flex items-center justify-center py-16">
                  <Loader2 size={22} className="animate-spin text-gray-300 dark:text-gray-700" />
                </div>
              ) : history.length > 0 ? (
                <>
                  <div className="flex items-center justify-between px-4 pt-5 pb-3">
                    <span className="text-base font-bold text-gray-900 dark:text-white">Recent</span>
                    <button onClick={clearAllHistory} className="text-xs font-semibold text-[#fa3f5e] hover:opacity-80 transition-opacity">Clear all</button>
                  </div>
                  {history.map((item) => {
                    const hId  = item._id || item.id;
                    const label = typeof item === 'string' ? item : (item.query || item.keyword || item.text || '');
                    if (!label) return null;
                    return (
                      <div key={hId || label} onClick={() => handleHistoryClick(item)}
                        className="flex items-center gap-3 px-4 py-3 hover:bg-gray-50 dark:hover:bg-white/5 active:bg-gray-100 dark:active:bg-white/10 transition-colors cursor-pointer">
                        <div className="w-10 h-10 rounded-full bg-gray-100 dark:bg-gray-800 flex items-center justify-center shrink-0">
                          <Clock size={18} className="text-gray-400" />
                        </div>
                        <span className="flex-1 text-sm text-gray-900 dark:text-white">{label}</span>
                        {hId && (
                          <button onClick={(e) => deleteHistoryItem(hId, e)}
                            className="p-1.5 text-gray-400 hover:text-gray-700 dark:hover:text-white rounded-full hover:bg-gray-100 dark:hover:bg-gray-800 transition-colors">
                            <X size={14} />
                          </button>
                        )}
                      </div>
                    );
                  })}
                </>
              ) : (
                <div className="flex flex-col items-center justify-center py-24 gap-3">
                  <SearchIcon size={44} className="text-gray-200 dark:text-gray-800" />
                  <p className="text-sm font-medium text-gray-400 dark:text-gray-600">No recent searches.</p>
                </div>
              )}
            </>
          )}

          {/* Loading skeleton */}
          {loading && (
            <div className="px-4 pt-6 space-y-4">
              {[1, 2, 3, 4].map(i => (
                <div key={i} className="flex items-center gap-3 animate-pulse">
                  <div className="w-11 h-11 rounded-full bg-gray-200 dark:bg-gray-800 shrink-0" />
                  <div className="flex-1 space-y-2">
                    <div className="h-3 bg-gray-200 dark:bg-gray-800 rounded-full w-2/3" />
                    <div className="h-2.5 bg-gray-100 dark:bg-gray-900 rounded-full w-1/3" />
                  </div>
                </div>
              ))}
            </div>
          )}

          {/* No results */}
          {query.trim() && !loading && results && !hasResults && (
            <div className="flex flex-col items-center justify-center py-20 gap-3 text-gray-400">
              <SearchIcon size={36} className="opacity-20" />
              <p className="text-base font-semibold text-gray-500 dark:text-gray-400">No results for "{query}"</p>
              <p className="text-xs text-gray-400 dark:text-gray-600">Try a different keyword</p>
            </div>
          )}

          {/* ── People ── */}
          {!loading && filteredUsers.length > 0 && (
            <section className="px-4">
              <div className="flex items-center gap-2 pt-5 pb-2">
                <p className="text-[11px] font-black uppercase tracking-wider text-gray-400 dark:text-gray-500">People</p>
                <span className="text-[10px] font-bold text-gray-400 dark:text-gray-600">· {results.users.length}</span>
              </div>
              {filteredUsers.map(u => (
                <button key={u._id} onClick={() => navigate(`/profile/${u.username || u._id}`)}
                  className="w-full flex items-center gap-3 py-3 hover:bg-gray-50 dark:hover:bg-white/5 active:bg-gray-100 dark:active:bg-white/10 transition-colors text-left rounded-xl px-2">
                  <Avatar src={u.avatar_url} name={u.username || u.full_name} size={44} />
                  <div className="min-w-0 flex-1">
                    <p className="text-sm font-semibold text-gray-900 dark:text-white truncate">{u.full_name || u.username}</p>
                    <p className="text-xs text-gray-500 dark:text-gray-400 truncate">
                      @{u.username}{u.location ? ` · ${u.location}` : ''}
                    </p>
                    {u.bio && <p className="text-xs text-gray-400 dark:text-gray-500 truncate mt-0.5">{u.bio}</p>}
                  </div>
                  {u.role && (
                    <span className={`text-[10px] font-bold px-2 py-0.5 rounded-full shrink-0 ${
                      u.role === 'vendor'
                        ? 'bg-orange-100 dark:bg-orange-900/30 text-orange-600 dark:text-orange-400'
                        : 'bg-gray-100 dark:bg-gray-800 text-gray-500 dark:text-gray-400'
                    }`}>
                      {u.role === 'vendor' ? 'Vendor' : 'Member'}
                    </span>
                  )}
                </button>
              ))}
              <LoadMoreBtn loading={loadingMore.users} hasMore={hasMoreUsers} onClick={loadMoreUsers} />
            </section>
          )}

          {/* ── Posts — 2-col grid ── */}
          {!loading && filteredPosts.length > 0 && (
            <section className="px-3">
              <div className="flex items-center gap-2 pt-5 pb-3 px-1">
                <p className="text-[11px] font-black uppercase tracking-wider text-gray-400 dark:text-gray-500">Posts</p>
                <span className="text-[10px] font-bold text-gray-400 dark:text-gray-600">· {results.posts.length}</span>
              </div>
              <div className="grid grid-cols-2 gap-2">
                {filteredPosts.map(post => (
                  <PostCard key={post._id} post={post} onClick={setSelectedPost} />
                ))}
              </div>
              <LoadMoreBtn loading={loadingMore.posts} hasMore={hasMorePosts} onClick={loadMorePosts} />
            </section>
          )}

          {/* ── Reels — 2-col grid with hover-to-play ── */}
          {!loading && filteredReels.length > 0 && (
            <section className="px-3 pb-4">
              <div className="flex items-center gap-2 pt-5 pb-3 px-1">
                <p className="text-[11px] font-black uppercase tracking-wider text-gray-400 dark:text-gray-500">Reels</p>
                <span className="text-[10px] font-bold text-gray-400 dark:text-gray-600">· {results.reels.length}</span>
              </div>
              <div className="grid grid-cols-2 gap-2">
                {filteredReels.map(reel => (
                  <ReelCard key={reel._id} reel={reel} onClick={(r) => navigate(`/reels?id=${r._id}`)} />
                ))}
              </div>
              <LoadMoreBtn loading={loadingMore.reels} hasMore={hasMoreReels} onClick={loadMoreReels} />
            </section>
          )}

        </div>
      </div>

      <PostDetailModal
        isOpen={!!selectedPost}
        post={selectedPost}
        onClose={() => setSelectedPost(null)}
      />
    </>
  );
}