import { useState, useEffect, useCallback, useMemo } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { ArrowLeft, Loader2, Grid, Film, Megaphone, ShoppingBag, Heart, Eye, MessageCircle, Play, Image } from 'lucide-react';
import api from '../../lib/api';
import PostDetailModal from '../../components/PostDetailModal';
import TweetDetailModal from '../../components/TweetDetailModal';
import PromoteDetailModal from '../../components/PromoteDetailModal';

const fmt = (n = 0) => {
  if (n >= 1_000_000) return (n / 1_000_000).toFixed(1) + 'M';
  if (n >= 1_000) return (n / 1_000).toFixed(1) + 'k';
  return String(n);
};

const getThumb = (item) => {
  const m = item?.media?.[0];
  if (!m) return null;
  if (Array.isArray(m.thumbnails) && m.thumbnails[0]?.fileUrl) return m.thumbnails[0].fileUrl;
  if (Array.isArray(m.thumbnail) && m.thumbnail[0]?.fileUrl) return m.thumbnail[0].fileUrl;
  if (m.thumbnail?.fileUrl) return m.thumbnail.fileUrl;
  if (typeof m.thumbnail === 'string') return m.thumbnail;
  if (m.thumbnail_url) return m.thumbnail_url;
  if (m.media_type !== 'video' && m.type !== 'video') return m.fileUrl || null;
  return null;
};

const isVideoItem = (item) => {
  const m = item?.media?.[0];
  return m?.type === 'video' || m?.media_type === 'video';
};

const getItemType = (item) => {
  if (item.item_type) return item.item_type;
  if (item.ad_title || item.ad_type) return 'ad';
  if (item.products && Array.isArray(item.products)) return 'promote_reel';
  if (item.type === 'reel') return 'reel';
  if (item.type === 'tweet' || item.content) return 'tweet';
  return 'post';
};

const TABS = [
  { key: 'all', label: 'All', icon: Grid },
  { key: 'post', label: 'Posts', icon: Image },
  { key: 'reel', label: 'Reels', icon: Film },
  { key: 'ad', label: 'Ads', icon: Megaphone },
  { key: 'promote_reel', label: 'Promoted', icon: ShoppingBag },
];

const SavedPosts = () => {
  const navigate = useNavigate();
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [activeTab, setActiveTab] = useState('all');
  const [allItems, setAllItems] = useState([]);

  const [selectedPost, setSelectedPost] = useState(null);
  const [selectedTweet, setSelectedTweet] = useState(null);
  const [selectedPromoteReel, setSelectedPromoteReel] = useState(null);

  const fetchSaved = useCallback(async () => {
    setLoading(true);
    setError('');
    try {
      const { data } = await api.get('/saved');
      const items = Array.isArray(data) ? data
        : Array.isArray(data?.items) ? data.items
        : Array.isArray(data?.data) ? data.data
        : Array.isArray(data?.saved) ? data.saved
        : [];
      setAllItems(items);
    } catch (e) {
      setError(e?.response?.data?.message || 'Failed to load saved items.');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { fetchSaved(); }, [fetchSaved]);

  const counts = useMemo(() => {
    const c = { all: 0, post: 0, reel: 0, ad: 0, promote_reel: 0, tweet: 0 };
    allItems.forEach(item => {
      const t = getItemType(item);
      c.all++;
      if (c[t] !== undefined) c[t]++;
      else c.post++;
    });
    return c;
  }, [allItems]);

  const displayItems = useMemo(() => {
    if (activeTab === 'all') return allItems;
    return allItems.filter(item => getItemType(item) === activeTab);
  }, [allItems, activeTab]);

  const handleItemClick = (item) => {
    const id = item._id || item.id;
    const type = getItemType(item);
    const isMobile = window.innerWidth < 768;

    if (type === 'reel') {
      if (isMobile) { navigate(`/reels?id=${id}`); }
      else { setSelectedPost({ ...item, type: 'reel' }); }
      return;
    }
    if (type === 'ad') {
      navigate(`/ads/${id}/details`);
      return;
    }
    if (type === 'promote_reel') {
      if (isMobile) { navigate(`/promote?id=${id}`); }
      else { setSelectedPromoteReel(item); }
      return;
    }
    if (type === 'tweet') {
      if (isMobile) { navigate(`/tweet/${id}`); }
      else { setSelectedTweet(item); }
      return;
    }
    if (isMobile) { navigate(`/post/${id}`); }
    else { setSelectedPost(item); }
  };

  return (
    <div className="min-h-screen bg-gray-50 dark:bg-black pb-24">
      {/* Header */}
      <div className="sticky top-0 bg-white dark:bg-black border-b border-gray-100 dark:border-gray-800 px-4 py-3 flex items-center justify-between z-40">
        <Link to="/settings" className="text-gray-800 dark:text-white p-1">
          <ArrowLeft size={22} />
        </Link>
        <h1 className="text-base font-semibold dark:text-white">Saved</h1>
        <div className="w-6" />
      </div>

      <div className="max-w-4xl mx-auto px-4 pt-4">
        {/* Tabs */}
        <div className="flex gap-2 overflow-x-auto pb-4" style={{ scrollbarWidth: 'none' }}>
          {TABS.map(tab => {
            const Icon = tab.icon;
            const isActive = activeTab === tab.key;
            const count = counts[tab.key] || 0;
            return (
              <button
                key={tab.key}
                onClick={() => setActiveTab(tab.key)}
                className={`flex items-center gap-1.5 px-4 py-2 rounded-full text-xs font-semibold whitespace-nowrap transition-all ${
                  isActive
                    ? 'bg-gray-900 dark:bg-white text-white dark:text-black'
                    : 'bg-white dark:bg-gray-900 text-gray-600 dark:text-gray-400 border border-gray-200 dark:border-gray-700 hover:bg-gray-100 dark:hover:bg-gray-800'
                }`}
              >
                <Icon size={13} />
                {tab.label}
                {!loading && count > 0 && (
                  <span className={`ml-0.5 text-[10px] font-bold ${isActive ? 'text-white/70 dark:text-black/60' : 'text-gray-400'}`}>
                    {count}
                  </span>
                )}
              </button>
            );
          })}
        </div>

        {/* Content */}
        {loading ? (
          <div className="flex flex-col items-center justify-center py-24 gap-3">
            <Loader2 size={28} className="animate-spin text-gray-300 dark:text-gray-700" />
            <span className="text-sm text-gray-400">Loading saved items…</span>
          </div>
        ) : error ? (
          <div className="flex flex-col items-center justify-center py-20 gap-3">
            <p className="text-sm text-red-500">{error}</p>
            <button onClick={fetchSaved} className="text-sm text-blue-500 font-semibold">Retry</button>
          </div>
        ) : displayItems.length === 0 ? (
          <div className="flex flex-col items-center justify-center py-24 gap-4">
            <div className="w-16 h-16 rounded-full bg-gray-100 dark:bg-gray-900 flex items-center justify-center">
              <Grid size={28} className="text-gray-300 dark:text-gray-700" />
            </div>
            <p className="text-base font-semibold text-gray-900 dark:text-white">No saved items</p>
            <p className="text-sm text-gray-400">
              {activeTab === 'all' ? 'Items you save will appear here' : `No saved ${activeTab.replace('_', ' ')}s yet`}
            </p>
          </div>
        ) : (
          <div className="grid grid-cols-3 gap-[2px] bg-gray-200 dark:bg-gray-800 rounded-xl overflow-hidden">
            {displayItems.map((item) => {
              const id = item._id || item.id;
              const thumb = getThumb(item);
              const vid = isVideoItem(item);
              const type = getItemType(item);

              return (
                <div
                  key={id || Math.random()}
                  className="aspect-square bg-gray-100 dark:bg-gray-900 relative group cursor-pointer overflow-hidden"
                  onClick={() => handleItemClick(item)}
                >
                  {/* Type badge */}
                  <div className="absolute top-1.5 left-1.5 z-10">
                    {type === 'ad' && (
                      <span className="text-[8px] font-bold bg-orange-500 text-white px-1.5 py-0.5 rounded-full shadow">AD</span>
                    )}
                    {type === 'promote_reel' && (
                      <span className="text-[8px] font-bold bg-purple-500 text-white px-1.5 py-0.5 rounded-full shadow flex items-center gap-0.5">
                        <ShoppingBag size={8} /> PROMO
                      </span>
                    )}
                  </div>
                  {vid && (
                    <div className="absolute top-1.5 right-1.5 z-10">
                      <Play size={14} className="text-white drop-shadow" fill="white" />
                    </div>
                  )}

                  {/* Thumbnail */}
                  {thumb ? (
                    <img src={thumb} alt="" className="w-full h-full object-cover group-hover:scale-[1.03] transition-transform duration-200" />
                  ) : (
                    <div className="w-full h-full flex items-center justify-center bg-gradient-to-br from-gray-200 to-gray-300 dark:from-gray-800 dark:to-gray-700">
                      {type === 'ad' ? <Megaphone size={24} className="text-gray-400" />
                        : type === 'promote_reel' ? <ShoppingBag size={24} className="text-gray-400" />
                        : type === 'reel' ? <Film size={24} className="text-gray-400" />
                        : <Image size={24} className="text-gray-400" />}
                    </div>
                  )}

                  {/* Hover overlay */}
                  <div className="absolute inset-0 bg-black/40 opacity-0 group-hover:opacity-100 transition-opacity hidden md:flex items-center justify-center gap-4 text-white font-bold text-sm">
                    <div className="flex items-center gap-1.5">
                      <Heart fill="white" size={16} />
                      {fmt(item.likes_count || 0)}
                    </div>
                    <div className="flex items-center gap-1.5">
                      {type === 'ad' ? <Eye size={16} /> : <MessageCircle fill="white" size={16} />}
                      {fmt(type === 'ad' ? (item.views_count || item.unique_views_count || 0) : (item.comments_count || 0))}
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>

      <PostDetailModal
        isOpen={!!selectedPost}
        post={selectedPost}
        onClose={() => setSelectedPost(null)}
      />
      <TweetDetailModal
        isOpen={!!selectedTweet}
        tweet={selectedTweet}
        onClose={() => setSelectedTweet(null)}
      />
      <PromoteDetailModal
        isOpen={!!selectedPromoteReel}
        promoteReel={selectedPromoteReel}
        onClose={() => setSelectedPromoteReel(null)}
      />
    </div>
  );
};

export default SavedPosts;
