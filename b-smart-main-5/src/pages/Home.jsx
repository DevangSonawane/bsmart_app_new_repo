import React, { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useSelector } from 'react-redux';
import { ChevronDown, MapPin } from 'lucide-react';
import StoryRail from '../components/StoryRail';
import PostCard from '../components/PostCard';
import PostDetailModal from '../components/PostDetailModal';
import api from '../lib/api';

const LocationBar = () => (
  <div className="sticky top-0 z-10 bg-white dark:bg-black mb-2 border-b border-gray-200 dark:border-gray-800">
    <div className="flex items-center justify-between lg:px-4 lg:py-3 gap-4">

      {/* Logo - Desktop Only */}
      <div className="hidden md:flex items-center gap-1">
        <h1 className="text-2xl font-bold bg-clip-text text-transparent bg-gradient-to-r from-insta-purple via-insta-pink to-insta-orange transition-opacity duration-300" style={{ fontFamily: 'cursive' }}>
          B-Smart
        </h1>
      </div>

      {/* Location Component */}
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

const Home = () => {
  const navigate = useNavigate();
  const { userObject } = useSelector((state) => state.auth);
  const [posts, setPosts] = useState([]);
  const [loading, setLoading] = useState(true);
  const [selectedPost, setSelectedPost] = useState(null);

  const fetchPosts = async () => {
    try {
      const { data } = await api.get('/posts/feed');
      setPosts(data || []);
    } catch (error) {
      console.error('Error fetching posts:', error);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchPosts();
  }, []);

  useEffect(() => {
    console.log('Logged in user:', userObject);
  }, [userObject]);

  const handlePostDeleted = (postId) => {
    setPosts(prevPosts => prevPosts.filter(p => (p._id || p.id) !== postId));
  };

  const handleCommentClick = (post) => {
    if (window.innerWidth < 768) {
      // Handle both _id (new API) and id (legacy)
      navigate(`/post/${post._id || post.id}`);
    } else {
      setSelectedPost(post);
    }
  };



  return (
    <div>
      <LocationBar />

      <StoryRail />
      <div className="pb-4">
        {loading ? (
          <div className="flex justify-center p-8">
            <div className="animate-spin w-8 h-8 border-2 border-gray-300 dark:border-gray-700 border-t-blue-500 rounded-full"></div>
          </div>
        ) : (
          posts.map(post => (
            <PostCard
              key={post._id || post.id}
              post={post}
              onCommentClick={handleCommentClick}
              onDelete={handlePostDeleted}
            />
          ))
        )}
      </div>

      {/* Post Detail Modal */}
      <PostDetailModal
        isOpen={!!selectedPost}
        post={selectedPost}
        onClose={() => setSelectedPost(null)}
      />
    </div>
  );
};

export default Home;
