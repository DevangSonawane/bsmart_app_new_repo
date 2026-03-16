import React, { useEffect, useState, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { useSelector } from 'react-redux';
import { ChevronDown, MapPin } from 'lucide-react';
import StoryRail from '../components/StoryRail';
import PostCard from '../components/PostCard';
import PostDetailModal from '../components/PostDetailModal';
import api from '../lib/api';

const BASE_URL = 'https://api.bebsmart.in';

const normalizeApiArray = (value) => {
  if (Array.isArray(value)) return value;
  if (!value || typeof value !== 'object') return [];
  const candidates = [
    value.data,
    value?.data?.data,
    value.posts,
    value.feed,
    value.items,
    value.results,
    value.ads,
    value?.data?.posts,
    value?.data?.feed,
    value?.data?.items,
    value?.data?.results,
    value?.data?.ads,
    value?.data?.data?.posts,
    value?.data?.data?.feed,
    value?.data?.data?.items,
    value?.data?.data?.results,
    value?.data?.data?.ads,
  ];
  for (const c of candidates) {
    if (Array.isArray(c)) return c;
  }
  return [];
};

const adAuthHeaders = () => {
  const token = localStorage.getItem('token');
  return {
    'Content-Type': 'application/json',
    ...(token ? { Authorization: `Bearer ${token}` } : {}),
  };
};

// ── Location Bar ──────────────────────────────────────────────────────────────
const LocationBar = () => (
  <div className="sticky top-0 z-10 bg-white dark:bg-black mb-2 border-b border-gray-200 dark:border-gray-800">
    <div className="flex items-center justify-between lg:px-4 lg:py-3 gap-4">
      <div className="hidden md:flex items-center gap-1">
        <h1 className="text-2xl font-bold bg-clip-text text-transparent bg-gradient-to-r from-insta-purple via-insta-pink to-insta-orange transition-opacity duration-300" style={{ fontFamily: 'cursive' }}>
          B-Smart
        </h1>
      </div>
      <div className="flex items-center justify-between gap-2 bg-gray-100 dark:bg-gray-900 px-3 py-2 rounded-lg cursor-pointer group hover:bg-gray-200 dark:hover:bg-gray-800 transition-colors w-full md:w-auto md:min-w-[300px]">
        <div className="flex items-center gap-2 flex-1 min-w-0">
          <div className="p-1.5 bg-white dark:bg-black rounded-full shadow-sm shrink-0">
            <MapPin size={14} className="text-red-500" />
          </div>
          <div className="flex flex-col flex-1 min-w-0 text-left">
            <span className="text-sm font-bold text-gray-900 dark:text-white truncate">Plat No.20, 2nd Floor, Shivaram Nivas, Sri...</span>
          </div>
        </div>
        <ChevronDown size={16} className="text-gray-400 group-hover:text-gray-600 dark:text-gray-500 dark:group-hover:text-gray-300 transition-colors shrink-0 ml-2" />
      </div>
    </div>
  </div>
);

// ── Skeleton Loader ───────────────────────────────────────────────────────────
const FeedSkeleton = () => (
  <div className="max-w-[470px] mx-auto">
    {[1, 2, 3].map(i => (
      <div key={i} className="bg-white dark:bg-black mb-4 border-b border-gray-200 dark:border-gray-800 pb-4 md:rounded-lg md:border animate-pulse">
        <div className="flex items-center gap-2.5 p-3">
          <div className="w-9 h-9 rounded-full bg-gray-200 dark:bg-gray-800" />
          <div className="flex flex-col gap-1.5 flex-1">
            <div className="w-32 h-3 rounded-full bg-gray-200 dark:bg-gray-800" />
            <div className="w-20 h-2.5 rounded-full bg-gray-100 dark:bg-gray-800" />
          </div>
        </div>
        <div className="w-full bg-gray-200 dark:bg-gray-800" style={{ height: 300 }} />
        <div className="px-3 pt-3 flex flex-col gap-2">
          <div className="w-16 h-3 rounded-full bg-gray-200 dark:bg-gray-800" />
          <div className="w-48 h-3 rounded-full bg-gray-100 dark:bg-gray-800" />
          <div className="w-32 h-2.5 rounded-full bg-gray-100 dark:bg-gray-800" />
        </div>
      </div>
    ))}
  </div>
);

// ── Merge & interleave posts and ads ──────────────────────────────────────────
// Strategy: insert one ad after every N posts (configurable).
// Falls back to pure posts if no ads available.
const AD_INTERVAL = 4; // show 1 ad after every 4 posts

const buildFeed = (posts, ads) => {
  const safePosts = normalizeApiArray(posts);
  const safeAds = normalizeApiArray(ads);
  if (!safeAds.length) return safePosts;
  const feed = [];
  let adIdx = 0;
  safePosts.forEach((post, i) => {
    feed.push(post);
    // After every AD_INTERVAL posts, insert the next ad (cycle through ads)
    if ((i + 1) % AD_INTERVAL === 0 && adIdx < safeAds.length) {
      feed.push({ ...safeAds[adIdx % safeAds.length], item_type: 'ad' });
      adIdx++;
    }
  });
  return feed;
};

// ── Home ──────────────────────────────────────────────────────────────────────
const Home = () => {
  const navigate = useNavigate();
  const { userObject } = useSelector(s => s.auth);

  const [posts, setPosts] = useState([]);
  const [ads, setAds] = useState([]);
  const [feed, setFeed] = useState([]);
  const [loading, setLoading] = useState(true);
  const [selectedItem, setSelectedItem] = useState(null);

  // ── Fetch posts ──────────────────────────────────────────────────────────
  const fetchPosts = useCallback(async () => {
    try {
      const { data } = await api.get('/posts/feed');
      return normalizeApiArray(data);
    } catch (e) {
      console.error('Error fetching posts:', e);
      return [];
    }
  }, []);

  // ── Fetch ads ─────────────────────────────────────────────────────────────
  const fetchAds = useCallback(async () => {
    try {
      const res = await fetch(`${BASE_URL}/api/ads/feed`, { headers: adAuthHeaders() });
      if (!res.ok) return [];
      const data = await res.json();
      return normalizeApiArray(data);
    } catch (e) {
      console.error('Error fetching ads:', e);
      return [];
    }
  }, []);

  // ── Load everything in parallel ──────────────────────────────────────────
  const loadFeed = useCallback(async () => {
    setLoading(true);
    const [fetchedPosts, fetchedAds] = await Promise.all([fetchPosts(), fetchAds()]);
    setPosts(fetchedPosts);
    setAds(fetchedAds);
    setFeed(buildFeed(fetchedPosts, fetchedAds));
    setLoading(false);
  }, [fetchPosts, fetchAds]);

  useEffect(() => { loadFeed(); }, [loadFeed]);

  // Rebuild feed whenever posts or ads change
  useEffect(() => { setFeed(buildFeed(posts, ads)); }, [posts, ads]);

  // Redirect vendors
  useEffect(() => {
    if (userObject?.role === 'vendor') navigate('/vendor/dashboard');
  }, [userObject, navigate]);

  // ── Handlers ─────────────────────────────────────────────────────────────
  const handlePostDeleted = (postId) => {
    setPosts(prev => prev.filter(p => (p._id || p.id) !== postId));
  };

  const handleCommentClick = (item) => {
    if (window.innerWidth < 768) {
      const id = item._id || item.id;
      // Ads don't have a dedicated mobile detail page — open modal on mobile too
      if (item.item_type === 'ad') {
        setSelectedItem(item);
      } else {
        navigate(`/post/${id}`);
      }
    } else {
      setSelectedItem(item);
    }
  };

  return (
    <div>
      <LocationBar />
      <StoryRail />

      <div className="pb-4">
        {loading ? (
          <FeedSkeleton />
        ) : feed.length === 0 ? (
          <div className="flex flex-col items-center justify-center py-16 text-gray-400">
            <p className="text-lg font-semibold mb-1">Your feed is empty</p>
            <p className="text-sm">Follow people to see their posts here.</p>
          </div>
        ) : (
          feed.map((item, idx) => {
            const key = item._id || item.id || `item-${idx}`;
            return (
              <PostCard
                key={key}
                post={item}
                onCommentClick={handleCommentClick}
                onDelete={handlePostDeleted}
              />
            );
          })
        )}
      </div>

      {/* Unified detail modal — handles both posts and ads */}
      <PostDetailModal
        isOpen={!!selectedItem}
        post={selectedItem}
        onClose={() => setSelectedItem(null)}
      />
    </div>
  );
};

export default Home;
