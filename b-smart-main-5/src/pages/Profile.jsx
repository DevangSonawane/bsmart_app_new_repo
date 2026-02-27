import React, { useState, useEffect } from 'react';
import { Settings, Video, Menu, Grid, Bookmark, Plus, Heart, MessageCircle, Wallet, ArrowLeft, MoreHorizontal } from 'lucide-react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import { useSelector } from 'react-redux';
import { supabase } from '../lib/supabase';
import api from '../lib/api';
import PostDetailModal from '../components/PostDetailModal';

const Profile = () => {
    const navigate = useNavigate();
    const { userId } = useParams();
    const { userObject: currentUser } = useSelector((state) => state.auth);

    // If userId is provided, we are viewing someone else's profile.
    // Otherwise, we are viewing our own profile (currentUser).
    const [profileUser, setProfileUser] = useState(null);
    const isOwnProfile = !userId || (currentUser && userId === currentUser.id);

    const [activeTab, setActiveTab] = useState('grid');
    const [userPosts, setUserPosts] = useState([]);
    const [loadingPosts, setLoadingPosts] = useState(true);
    const [selectedPost, setSelectedPost] = useState(null);

    // Fetch Profile User Data
    useEffect(() => {
        const fetchProfileUser = async () => {
            if (isOwnProfile) {
                setProfileUser(currentUser);
            } else {
                try {
                    const response = await api.get(`/users/${userId}`);
                    setProfileUser(response.data);
                } catch (error) {
                    console.error('Error fetching user profile:', error);
                    // Fallback to Supabase if API fails (optional, but good for stability)
                    try {
                        const { data, error: supError } = await supabase
                            .from('users')
                            .select('*')
                            .eq('id', userId)
                            .single();
                        if (!supError && data) setProfileUser(data);
                    } catch (e) { console.error(e); }
                }
            }
        };

        fetchProfileUser();
    }, [userId, currentUser, isOwnProfile]);

    const handlePostClick = (post) => {
        const id = post._id || post.id;
        if (window.innerWidth < 768 && id) {
            navigate(`/post/${id}`);
        } else {
            setSelectedPost(post);
        }
    };

    useEffect(() => {
        const fetchPosts = async () => {
            if (profileUser?.id) {
                try {
                    setLoadingPosts(true);
                    // Use API to fetch user posts
                    const response = await api.get(`/users/${profileUser.id}/posts`);
                    setUserPosts(response.data || []);
                } catch (error) {
                    console.error('Error fetching posts:', error);
                    // Fallback to Supabase
                    try {
                        const { data, error: supError } = await supabase
                            .from('posts')
                            .select('*')
                            .eq('user_id', profileUser.id)
                            .order('created_at', { ascending: false });
                        if (!supError) setUserPosts(data || []);
                    } catch (e) { console.error(e); }
                } finally {
                    setLoadingPosts(false);
                }
            }
        };

        fetchPosts();
    }, [profileUser]);

    const getInitials = (name) => {
        if (!name) return 'U';
        return name.split(' ').map((n) => n[0]).join('').toUpperCase().substring(0, 2);
    };

    // Mock Data
    const highlights = [
        { id: 1, title: 'Travel', img: 'https://images.unsplash.com/photo-1469854523086-cc02fe5d8800?w=150&h=150&fit=crop' },
        { id: 2, title: 'Work', img: 'https://images.unsplash.com/photo-1497215728101-856f4ea42174?w=150&h=150&fit=crop' },
        { id: 3, title: 'Life', img: 'https://images.unsplash.com/photo-1511632765486-a01980e01a18?w=150&h=150&fit=crop' },
        { id: 4, title: 'Tech', img: 'https://images.unsplash.com/photo-1519389950473-47ba0277781c?w=150&h=150&fit=crop' },
        { id: 5, title: 'Music', img: 'https://images.unsplash.com/photo-1511379938547-c1f69419868d?w=150&h=150&fit=crop' },
    ];

    if (!profileUser) {
        return (
            <div className="min-h-screen flex items-center justify-center bg-gray-50">
                <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-insta-pink"></div>
            </div>
        );
    }

    const VerifiedBadge = () => (
        <svg viewBox="0 0 24 24" fill="currentColor" className="w-5 h-5 text-blue-500 ml-1">
            <path fillRule="evenodd" d="M8.603 3.799A4.49 4.49 0 0112 2.25c1.357 0 2.573.6 3.397 1.549a4.49 4.49 0 013.498 1.307 4.491 4.491 0 011.307 3.497A4.49 4.49 0 0121.75 12a4.49 4.49 0 01-1.549 3.397 4.491 4.491 0 01-1.307 3.498 4.491 4.491 0 01-3.497 1.307A4.49 4.49 0 0112 21.75a4.49 4.49 0 01-3.397-1.549 4.49 4.49 0 01-3.498-1.306 4.491 4.491 0 01-1.307-3.498A4.49 4.49 0 012.25 12c0-1.357.6-2.573 1.549-3.397a4.49 4.49 0 011.307-3.497 4.49 4.49 0 013.497-1.307zm7.007 6.387a.75.75 0 10-1.22-.872l-3.236 4.53L9.53 12.22a.75.75 0 00-1.06 1.06l2.25 2.25a.75.75 0 001.14-.094l3.75-5.25z" clipRule="evenodd" />
        </svg>
    );

    return (
        <div className="min-h-screen bg-white dark:bg-black md:bg-gray-50 md:dark:bg-black">

            {/* ================= MOBILE VIEW (md:hidden) ================= */}
            <div className="md:hidden">
                <div className="sticky top-0 bg-white/95 dark:bg-black/95 backdrop-blur-sm border-b border-gray-100 dark:border-gray-800 px-4 py-3 flex justify-between items-center z-40">
                    <div className="flex items-center gap-1">
                        {!isOwnProfile && (
                            <button onClick={() => navigate(-1)} className="mr-2">
                                <ArrowLeft size={24} className="text-gray-900 dark:text-white" />
                            </button>
                        )}
                        <h1 className="text-xl font-bold text-gray-900 dark:text-white flex items-center gap-1">
                            {profileUser.username}
                            <VerifiedBadge />
                        </h1>
                    </div>
                    {isOwnProfile && (
                        <div className="flex items-center gap-4 text-gray-900 dark:text-white">
                            <Link to="/create"><Plus size={26} /></Link>
                            <Link to="/settings"><Menu size={26} /></Link>
                        </div>
                    )}
                </div>

                <div className="px-4 pt-4 pb-2">
                    {/* Profile Info Row */}
                    <div className="flex items-center justify-between mb-4">
                        {/* Avatar */}
                        <div className="relative">
                            <div className="w-20 h-20 rounded-full p-[2px] bg-gradient-to-tr from-insta-yellow via-insta-orange to-insta-pink">
                                <div className="w-full h-full rounded-full bg-white dark:bg-black p-[2px] overflow-hidden">
                                    {profileUser.avatar_url ? (
                                        <img
                                            src={profileUser.avatar_url}
                                            alt={profileUser.username}
                                            className="w-full h-full object-cover"
                                        />
                                    ) : (
                                        <div className="w-full h-full bg-gradient-to-tr from-insta-yellow via-insta-orange to-insta-pink flex items-center justify-center text-2xl font-bold text-white">
                                            {getInitials(profileUser.full_name)}
                                        </div>
                                    )}
                                </div>
                            </div>
                            {isOwnProfile && (
                                <Link to="/create" className="absolute bottom-0 right-0 bg-blue-500 text-white p-1 rounded-full border-2 border-white dark:border-black">
                                    <Plus size={14} strokeWidth={3} />
                                </Link>
                            )}
                        </div>

                        {/* Stats */}
                        <div className="flex flex-1 justify-around ml-4">
                            <div className="flex flex-col items-center">
                                <span className="font-bold text-lg text-gray-900 dark:text-white">{userPosts.length}</span>
                                <span className="text-sm text-gray-500 dark:text-gray-400">Posts</span>
                            </div>
                            <div className="flex flex-col items-center">
                                <span className="font-bold text-lg text-gray-900 dark:text-white">{profileUser.followers_count || 0}</span>
                                <span className="text-sm text-gray-500 dark:text-gray-400">Followers</span>
                            </div>
                            <div className="flex flex-col items-center">
                                <span className="font-bold text-lg text-gray-900 dark:text-white">{profileUser.following_count || 0}</span>
                                <span className="text-sm text-gray-500 dark:text-gray-400">Following</span>
                            </div>
                        </div>
                    </div>

                    {/* Bio */}
                    <div className="mb-4">
                        <div className="font-bold text-sm text-gray-900 dark:text-white">{profileUser.full_name}</div>
                        <div className="text-sm text-gray-700 dark:text-gray-300 whitespace-pre-wrap">{profileUser.bio || 'No bio yet.'}</div>
                    </div>

                    {/* Actions */}
                    <div className="flex gap-2 mb-6">
                        {isOwnProfile ? (
                            <>
                                <Link to="/edit-profile" className="flex-1 bg-gray-100 dark:bg-gray-800 hover:bg-gray-200 dark:hover:bg-gray-700 text-gray-900 dark:text-white text-sm font-semibold py-1.5 rounded-md text-center">
                                    Edit profile
                                </Link>
                                <button className="flex-1 bg-gray-100 dark:bg-gray-800 hover:bg-gray-200 dark:hover:bg-gray-700 text-gray-900 dark:text-white text-sm font-semibold py-1.5 rounded-md">
                                    Share profile
                                </button>
                            </>
                        ) : (
                            <>
                                <button className="flex-1 bg-gradient-to-tr from-insta-yellow via-insta-orange to-insta-pink hover:opacity-90 text-white text-sm font-semibold py-1.5 rounded-md transition-opacity">
                                    Follow
                                </button>
                                <button className="flex-1 bg-gray-100 dark:bg-gray-800 hover:bg-gray-200 dark:hover:bg-gray-700 text-gray-900 dark:text-white text-sm font-semibold py-1.5 rounded-md">
                                    Message
                                </button>
                            </>
                        )}
                        {isOwnProfile && (
                            <button className="bg-gray-100 dark:bg-gray-800 hover:bg-gray-200 dark:hover:bg-gray-700 p-1.5 rounded-md text-gray-900 dark:text-white">
                                <Link to="/settings">
                                    <Settings size={20} />
                                </Link>
                            </button>
                        )}
                    </div>

                    {/* Highlights */}
                    <div className="flex gap-4 overflow-x-auto pb-4 scrollbar-hide mb-2">
                        {highlights.map((highlight) => (
                            <div key={highlight.id} className="flex flex-col items-center gap-1 flex-shrink-0">
                                <div className="w-16 h-16 rounded-full p-[1px] border border-gray-200 dark:border-gray-800 bg-white dark:bg-black">
                                    <div className="w-full h-full rounded-full bg-gray-100 dark:bg-gray-900 p-0.5 overflow-hidden">
                                        <img src={highlight.img} alt={highlight.title} className="w-full h-full rounded-full object-cover" />
                                    </div>
                                </div>
                                <span className="text-xs text-gray-900 dark:text-white">{highlight.title}</span>
                            </div>
                        ))}
                        <div className="flex flex-col items-center gap-1 flex-shrink-0">
                            <div className="w-16 h-16 rounded-full border border-gray-300 dark:border-gray-700 flex items-center justify-center">
                                <Plus size={24} className="text-gray-800 dark:text-white" />
                            </div>
                            <span className="text-xs text-gray-900 dark:text-white">New</span>
                        </div>
                    </div>
                </div>

                {/* Tabs */}
                <div className="flex border-t border-gray-200 dark:border-gray-800 sticky top-[53px] bg-white dark:bg-black z-30">
                    <button
                        onClick={() => setActiveTab('grid')}
                        className={`flex-1 py-3 flex justify-center items-center border-b-[1.5px] ${activeTab === 'grid' ? 'border-insta-pink text-insta-pink' : 'border-transparent text-gray-400'}`}
                    >
                        <Grid size={24} />
                    </button>
                    <button
                        onClick={() => setActiveTab('reels')}
                        className={`flex-1 py-3 flex justify-center items-center border-b-[1.5px] ${activeTab === 'reels' ? 'border-insta-pink text-insta-pink' : 'border-transparent text-gray-400'}`}
                    >
                        <Video size={24} />
                    </button>
                    <button
                        onClick={() => setActiveTab('tagged')}
                        className={`flex-1 py-3 flex justify-center items-center border-b-[1.5px] ${activeTab === 'tagged' ? 'border-insta-pink text-insta-pink' : 'border-transparent text-gray-400'}`}
                    >
                        <Bookmark size={24} />
                    </button>
                </div>

                {/* Content Grid */}
                <div className="grid grid-cols-3 gap-0.5 pb-20">
                    {loadingPosts ? (
                        Array(9).fill(null).map((_, i) => (
                            <div key={i} className="aspect-square bg-gray-200 dark:bg-gray-800 animate-pulse" />
                        ))
                    ) : userPosts.length === 0 ? (
                        <div className="col-span-3 py-12 text-center text-gray-500 dark:text-gray-400 text-sm">
                            <div className="w-16 h-16 border-2 border-gray-300 dark:border-gray-700 rounded-full flex items-center justify-center mx-auto mb-4">
                                <Grid size={32} className="text-gray-300 dark:text-gray-600" />
                            </div>
                            <h3 className="font-semibold text-lg text-gray-900 dark:text-white mb-1">No Posts Yet</h3>
                            <p>When you share photos, they will appear on your profile.</p>
                            <Link to="/create" className="text-blue-500 font-semibold mt-4 inline-block">Share your first photo</Link>
                        </div>
                    ) : (
                        userPosts.map((post) => (
                            <div
                                key={post.id}
                                className="aspect-square bg-gray-100 dark:bg-gray-900 relative group cursor-pointer"
                                onClick={() => handlePostClick(post)}
                            >
                                <img
                                    src={post.media?.[0]?.fileUrl || post.media?.[0]?.image || 'https://via.placeholder.com/300'}
                                    alt="Post"
                                    className="w-full h-full object-cover"
                                />
                            </div>
                        ))
                    )}
                </div>
            </div>


            {/* ================= DESKTOP VIEW (hidden md:block) ================= */}
            <div className="hidden md:block max-w-4xl mx-auto pt-8 px-4 pb-12 relative">

                {/* Profile Header */}
                <div className="flex gap-16 items-start mb-12 px-8">
                    {/* Avatar - Left */}
                    <div className="flex-shrink-0">
                        <div className="w-[160px] h-[160px] rounded-full p-[2px] bg-gradient-to-tr from-insta-yellow via-insta-orange to-insta-pink cursor-pointer hover:scale-105 transition-transform">
                            <div className="w-full h-full rounded-full bg-white dark:bg-black p-[3px] overflow-hidden">
                                {profileUser.avatar_url ? (
                                    <img src={profileUser.avatar_url} className="w-full h-full rounded-full object-cover" alt="Profile" />
                                ) : (
                                    <div className="w-full h-full bg-gradient-to-tr from-insta-yellow via-insta-orange to-insta-pink flex items-center justify-center text-5xl font-bold text-white">
                                        {getInitials(profileUser.full_name || profileUser.username)}
                                    </div>
                                )}
                            </div>
                        </div>
                    </div>

                    {/* Info - Right */}
                    <div className="flex flex-col flex-1 pt-2">

                        {/* Row 1: Username & Verified */}
                        <div className="flex items-center gap-4 mb-3">
                            <h2 className="text-xl font-medium text-gray-900 dark:text-white">{profileUser.username}</h2>
                            <VerifiedBadge />
                            {/* Settings / More (Optional, can be added if needed) */}
                        </div>

                        {/* Row 2: Full Name */}
                        <div className="font-semibold text-gray-900 dark:text-white mb-2">{profileUser.full_name || profileUser.username}</div>

                        {/* Row 3: Stats */}
                        <div className="flex gap-10 text-base mb-4">
                            <span className="dark:text-gray-300"><span className="font-semibold text-gray-900 dark:text-white">{userPosts.length}</span> posts</span>
                            <span className="dark:text-gray-300"><span className="font-semibold text-gray-900 dark:text-white">{profileUser.followers_count || 0}</span> followers</span>
                            <span className="dark:text-gray-300"><span className="font-semibold text-gray-900 dark:text-white">{profileUser.following_count || 0}</span> following</span>
                        </div>

                        {/* Row 4: Bio */}
                        <div className="text-gray-900 dark:text-gray-300 whitespace-pre-wrap mb-6 max-w-lg leading-relaxed">
                            {profileUser.bio || 'Digital creator\nGaming 🎮 | Coding | Tech enthusiast'}
                        </div>

                        {/* Row 5: Action Buttons */}
                        <div className="flex gap-3 items-center">
                            {isOwnProfile ? (
                                <>
                                    <Link to="/edit-profile" className="px-6 py-1.5 bg-gradient-to-r from-insta-purple via-insta-pink to-insta-orange text-white font-semibold rounded-lg text-sm transition-opacity hover:opacity-90 min-w-[120px] text-center">
                                        Edit Profile
                                    </Link>
                                    <Link to="/archive" className="px-6 py-1.5 bg-gradient-to-r from-insta-purple via-insta-pink to-insta-orange text-white font-semibold rounded-lg text-sm transition-opacity hover:opacity-90 min-w-[120px] text-center">
                                        View archive
                                    </Link>
                                    <Link to="/settings" className="p-2 text-gray-900 dark:text-white hover:bg-gray-100 dark:hover:bg-gray-800 rounded-full transition-colors ml-1">
                                        <Settings size={24} />
                                    </Link>
                                </>
                            ) : (
                                <>
                                    <button className="px-6 py-1.5 bg-gradient-to-tr from-insta-yellow via-insta-orange to-insta-pink hover:opacity-90 text-white font-semibold rounded-lg text-sm transition-opacity min-w-[120px]">
                                        Follow
                                    </button>
                                    <button className="px-6 py-1.5 bg-gray-100 dark:bg-gray-800 hover:bg-gray-200 dark:hover:bg-gray-700 text-gray-900 dark:text-white font-semibold rounded-lg text-sm transition-colors min-w-[120px]">
                                        Message
                                    </button>
                                    <button className="p-2 text-gray-900 dark:text-white hover:bg-gray-100 dark:hover:bg-gray-800 rounded-full transition-colors ml-1">
                                        <MoreHorizontal size={24} />
                                    </button>
                                </>
                            )}
                        </div>

                    </div>
                </div>

                {/* Highlights */}
                <div className="flex gap-8 overflow-x-auto pb-6 scrollbar-hide mb-8 px-8 border-b border-gray-100 dark:border-gray-800">
                    {highlights.map((highlight) => (
                        <div key={highlight.id} className="flex flex-col items-center gap-2 flex-shrink-0 cursor-pointer group">
                            <div className="w-20 h-20 rounded-full p-[1px] border border-gray-200 dark:border-gray-800 bg-white dark:bg-black group-hover:scale-105 transition-transform">
                                <div className="w-full h-full rounded-full bg-gray-100 dark:bg-gray-900 p-1 overflow-hidden">
                                    <img src={highlight.img} alt={highlight.title} className="w-full h-full rounded-full object-cover" />
                                </div>
                            </div>
                            <span className="text-xs font-medium text-gray-900 dark:text-white">{highlight.title}</span>
                        </div>
                    ))}
                    <div className="flex flex-col items-center gap-2 flex-shrink-0 cursor-pointer group">
                        <div className="w-20 h-20 rounded-full border border-gray-300 dark:border-gray-700 flex items-center justify-center group-hover:bg-gray-50 dark:group-hover:bg-gray-900 transition-colors">
                            <Plus size={32} className="text-gray-400 dark:text-gray-500" />
                        </div>
                        <span className="text-xs font-medium text-gray-900 dark:text-white">New</span>
                    </div>
                </div>

                {/* Desktop Tabs */}
                <div className="flex justify-center gap-16 border-t border-gray-200 dark:border-gray-800 mb-4 -mt-[1px]">
                    <button
                        onClick={() => setActiveTab('grid')}
                        className={`flex items-center gap-2 py-4 border-t-[1px] text-xs font-semibold tracking-wide uppercase ${activeTab === 'grid' ? 'border-gray-900 dark:border-white text-gray-900 dark:text-white' : 'border-transparent text-gray-400 hover:text-gray-600 dark:hover:text-gray-300'} transition-all`}
                    >
                        <Grid size={12} /> Posts
                    </button>
                    <button
                        onClick={() => setActiveTab('reels')}
                        className={`flex items-center gap-2 py-4 border-t-[1px] text-xs font-semibold tracking-wide uppercase ${activeTab === 'reels' ? 'border-gray-900 dark:border-white text-gray-900 dark:text-white' : 'border-transparent text-gray-400 hover:text-gray-600 dark:hover:text-gray-300'} transition-all`}
                    >
                        <Video size={12} /> Reels
                    </button>
                    <button
                        onClick={() => setActiveTab('saved')}
                        className={`flex items-center gap-2 py-4 border-t-[1px] text-xs font-semibold tracking-wide uppercase ${activeTab === 'saved' ? 'border-gray-900 dark:border-white text-gray-900 dark:text-white' : 'border-transparent text-gray-400 hover:text-gray-600 dark:hover:text-gray-300'} transition-all`}
                    >
                        <Bookmark size={12} /> Saved
                    </button>
                    <button
                        onClick={() => setActiveTab('tagged')}
                        className={`flex items-center gap-2 py-4 border-t-[1px] text-xs font-semibold tracking-wide uppercase ${activeTab === 'tagged' ? 'border-gray-900 dark:border-white text-gray-900 dark:text-white' : 'border-transparent text-gray-400 hover:text-gray-600 dark:hover:text-gray-300'} transition-all`}
                    >
                        <div className="border border-current rounded-[3px] p-[1px]"><Plus size={8} className="rotate-45" /></div> Tagged
                    </button>
                </div>

                {/* Content Grid */}
                <div className="grid grid-cols-3 gap-6">
                    {loadingPosts ? (
                        Array(9).fill(null).map((_, i) => (
                            <div key={i} className="aspect-square bg-gray-200 dark:bg-gray-800 animate-pulse" />
                        ))
                    ) : userPosts.length === 0 ? (
                        <div className="col-span-3 py-16 text-center text-gray-500 dark:text-gray-400">
                            <div className="w-20 h-20 border-2 border-gray-300 dark:border-gray-700 rounded-full flex items-center justify-center mx-auto mb-6">
                                <Grid size={40} className="text-gray-300 dark:text-gray-600" />
                            </div>
                            <h3 className="font-bold text-2xl text-gray-900 dark:text-white mb-2">Share Photos</h3>
                            <p className="mb-6">When you share photos, they will appear on your profile.</p>
                            <Link to="/create" className="text-blue-500 font-semibold hover:text-blue-700">Share your first photo</Link>
                        </div>
                    ) : (
                        userPosts.map((post) => (
                            <div
                                key={post._id || post.id}
                                className="aspect-square bg-gray-100 dark:bg-gray-900 relative group cursor-pointer overflow-hidden"
                                onClick={() => handlePostClick(post)}
                            >
                                <img
                                    src={post.media?.[0]?.fileUrl || post.media?.[0]?.image || 'https://via.placeholder.com/300'}
                                    alt="Post"
                                    className="w-full h-full object-cover"
                                />
                                <div className="absolute inset-0 bg-black/40 opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center gap-6 text-white font-bold">
                                    <div className="flex items-center gap-2"><Heart fill="white" size={20} /> {0}</div>
                                    <div className="flex items-center gap-2"><MessageCircle fill="white" size={20} /> {0}</div>
                                </div>
                            </div>
                        ))
                    )}
                </div>

                {/* Floating Wallet Button */}
                <div className="fixed bottom-8 right-8 z-50 animate-fade-in hover:scale-105 transition-transform cursor-pointer">
                    <div className="flex items-center gap-2 bg-white dark:bg-gray-900 rounded-full shadow-xl border border-gray-100 dark:border-gray-800 p-1 pr-4">
                        <div className="w-12 h-12 rounded-full bg-gradient-to-tr from-insta-yellow via-insta-orange to-insta-pink flex items-center justify-center text-white shadow-md">
                            <Wallet size={24} />
                        </div>
                        <div className="flex flex-col">
                            <span className="text-xs text-gray-500 dark:text-gray-400 font-medium uppercase tracking-wider">Balance</span>
                            <span className="text-base font-bold text-gray-900 dark:text-white">Coins {currentUser?.wallet?.balance ? Math.floor(Number(currentUser.wallet.balance)) : 0}</span>
                        </div>
                    </div>
                </div>

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

export default Profile;
