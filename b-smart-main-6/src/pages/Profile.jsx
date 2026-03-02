import React, { useState, useEffect } from 'react';
import { Settings, Video, Menu, Grid, Plus, Heart, MessageCircle, Wallet, ArrowLeft, MoreHorizontal, Megaphone, TrendingUp, BarChart2, ExternalLink } from 'lucide-react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import { useDispatch, useSelector } from 'react-redux';
import { supabase } from '../lib/supabase';
import api from '../lib/api';
import PostDetailModal from '../components/PostDetailModal';
import AvatarCropModal from '../components/AvatarCropModal';
import { setUser } from '../store/authSlice';

const Profile = () => {
    const navigate = useNavigate();
    const dispatch = useDispatch();
    const { userId } = useParams();
    const { userObject: currentUser } = useSelector((state) => state.auth);

    const [profileUser, setProfileUser] = useState(null);
    const isOwnProfile = !userId || (currentUser && (userId === currentUser.id || userId === currentUser._id));

    const [activeTab, setActiveTab] = useState('all');
    const [userPosts, setUserPosts] = useState([]);
    const [loadingPosts, setLoadingPosts] = useState(true);
    const [selectedPost, setSelectedPost] = useState(null);
    const [showAvatarModal, setShowAvatarModal] = useState(false);

    const allPosts = userPosts;
    const onlyPosts = userPosts.filter(p => p.type !== 'reel' && p.type !== 'ad');
    const onlyReels = userPosts.filter(p => p.type === 'reel');
    const onlyAds = userPosts.filter(p => p.type === 'ad');
    const displayedPosts =
        activeTab === 'reels' ? onlyReels :
        activeTab === 'posts' ? onlyPosts :
        activeTab === 'ads' ? onlyAds :
        allPosts;

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
                    try {
                        const { data, error: supError } = await supabase
                            .from('users').select('*').eq('id', userId).single();
                        if (!supError && data) setProfileUser(data);
                    } catch (e) { console.error(e); }
                }
            }
        };
        fetchProfileUser();
    }, [userId, currentUser, isOwnProfile]);

    const handlePostClick = (post) => {
        const id = post._id || post.id;
        if (window.innerWidth < 768 && id) navigate(`/post/${id}`);
        else setSelectedPost(post);
    };

    useEffect(() => {
        const fetchPosts = async () => {
            const profileUserId = profileUser?._id || profileUser?.id;
            if (!profileUserId) return;
            try {
                setLoadingPosts(true);
                const response = await api.get(`/users/${profileUserId}/posts`);
                setUserPosts(response.data || []);
            } catch (error) {
                console.error('Error fetching posts:', error);
                try {
                    const { data, error: supError } = await supabase
                        .from('posts').select('*').eq('user_id', profileUserId).order('created_at', { ascending: false });
                    if (!supError) setUserPosts(data || []);
                } catch (e) { console.error(e); }
            } finally {
                setLoadingPosts(false);
            }
        };
        fetchPosts();
    }, [profileUser]);

    const getInitials = (name) => {
        if (!name) return 'U';
        return name.split(' ').map((n) => n[0]).join('').toUpperCase().substring(0, 2);
    };

    const handleAvatarSuccess = async (newAvatarUrl) => {
        const userIdToFetch = currentUser?.id || currentUser?._id;
        if (!userIdToFetch) return;
        try {
            const response = await api.get(`/users/${userIdToFetch}`);
            const updatedUser = response.data || { ...currentUser, avatar_url: newAvatarUrl };
            dispatch(setUser(updatedUser));
            setProfileUser(updatedUser);
        } catch {
            const fallback = { ...currentUser, avatar_url: newAvatarUrl };
            dispatch(setUser(fallback));
            setProfileUser(prev => (prev ? { ...prev, avatar_url: newAvatarUrl } : prev));
        }
    };

    const getPostThumbnail = (post) => {
        const media = post.media?.[0];
        if (!media) return 'https://via.placeholder.com/300';
        if (media.type === 'video' && media.thumbnails?.length > 0) {
            const thumbFile = media.thumbnails[0].fileName;
            const baseUrl = media.fileUrl?.split('/uploads/')[0];
            if (baseUrl && thumbFile) return `${baseUrl}/uploads/${thumbFile}`;
        }
        return media.fileUrl || media.image || 'https://via.placeholder.com/300';
    };

    const highlights = [
        { id: 1, title: 'Travel', img: 'https://images.unsplash.com/photo-1469854523086-cc02fe5d8800?w=150&h=150&fit=crop' },
        { id: 2, title: 'Work', img: 'https://images.unsplash.com/photo-1497215728101-856f4ea42174?w=150&h=150&fit=crop' },
        { id: 3, title: 'Life', img: 'https://images.unsplash.com/photo-1511632765486-a01980e01a18?w=150&h=150&fit=crop' },
        { id: 4, title: 'Tech', img: 'https://images.unsplash.com/photo-1519389950473-47ba0277781c?w=150&h=150&fit=crop' },
        { id: 5, title: 'Music', img: 'https://images.unsplash.com/photo-1511379938547-c1f69419868d?w=150&h=150&fit=crop' },
    ];

    if (!profileUser) {
        return (
            <div className="min-h-screen flex items-center justify-center bg-gray-50 dark:bg-black">
                <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-orange-500" />
            </div>
        );
    }

    const VerifiedBadge = () => (
        <svg viewBox="0 0 24 24" fill="currentColor" className="w-5 h-5 text-blue-500 flex-shrink-0">
            <path fillRule="evenodd" d="M8.603 3.799A4.49 4.49 0 0112 2.25c1.357 0 2.573.6 3.397 1.549a4.49 4.49 0 013.498 1.307 4.491 4.491 0 011.307 3.497A4.49 4.49 0 0121.75 12a4.49 4.49 0 01-1.549 3.397 4.491 4.491 0 01-1.307 3.498 4.491 4.491 0 01-3.497 1.307A4.49 4.49 0 0112 21.75a4.49 4.49 0 01-3.397-1.549 4.49 4.49 0 01-3.498-1.306 4.491 4.491 0 01-1.307-3.498A4.49 4.49 0 012.25 12c0-1.357.6-2.573 1.549-3.397a4.49 4.49 0 011.307-3.497 4.49 4.49 0 013.497-1.307zm7.007 6.387a.75.75 0 10-1.22-.872l-3.236 4.53L9.53 12.22a.75.75 0 00-1.06 1.06l2.25 2.25a.75.75 0 001.14-.094l3.75-5.25z" clipRule="evenodd" />
        </svg>
    );

    const tabConfig = [
        { key: 'all',   label: 'All',   icon: <Grid size={22} /> },
        { key: 'posts', label: 'Posts', icon: <Grid size={22} /> },
        { key: 'reels', label: 'Reels', icon: <Video size={22} /> },
        ...(profileUser.role === 'vendor' ? [{ key: 'ads', label: 'Ads', icon: <Megaphone size={22} /> }] : []),
    ];

    const PostGrid = ({ containerClass = '' }) => (
        <div className={`grid grid-cols-3 gap-[1px] bg-gray-200 dark:bg-gray-800 ${containerClass}`}>
            {loadingPosts ? (
                Array(9).fill(null).map((_, i) => (
                    <div key={i} className="aspect-square bg-gray-100 dark:bg-gray-900 animate-pulse" />
                ))
            ) : displayedPosts.length === 0 ? (
                <div className="col-span-3 bg-white dark:bg-black py-14 text-center">
                    <div className="w-16 h-16 border-2 border-gray-300 dark:border-gray-600 rounded-full flex items-center justify-center mx-auto mb-4">
                        {activeTab === 'reels' ? <Video size={30} className="text-gray-300 dark:text-gray-600" />
                            : activeTab === 'ads' ? <Megaphone size={30} className="text-gray-300 dark:text-gray-600" />
                            : <Grid size={30} className="text-gray-300 dark:text-gray-600" />}
                    </div>
                    <h3 className="font-semibold text-base text-gray-900 dark:text-white mb-1">
                        {activeTab === 'reels' ? 'No Reels Yet' : activeTab === 'ads' ? 'No Ads Yet' : 'No Posts Yet'}
                    </h3>
                    <Link to={activeTab === 'ads' ? '/create-ad' : '/create'} className="text-blue-500 text-sm font-semibold mt-1 inline-block">
                        Create now
                    </Link>
                </div>
            ) : (
                displayedPosts.map((post) => (
                    <div
                        key={post._id || post.id}
                        className="aspect-square bg-gray-100 dark:bg-gray-900 relative group cursor-pointer overflow-hidden"
                        onClick={() => handlePostClick(post)}
                    >
                        {post.type === 'reel' && (
                            <div className="absolute top-1.5 right-1.5 z-10">
                                <Video size={15} className="text-white drop-shadow" fill="white" />
                            </div>
                        )}
                        {post.type === 'ad' && (
                            <div className="absolute top-1.5 left-1.5 z-10">
                                <span className="text-[9px] font-bold bg-orange-500 text-white px-1.5 py-0.5 rounded-full">AD</span>
                            </div>
                        )}
                        <img src={getPostThumbnail(post)} alt="Post" className="w-full h-full object-cover group-hover:scale-[1.03] transition-transform duration-200" />
                        <div className="absolute inset-0 bg-black/40 opacity-0 group-hover:opacity-100 transition-opacity hidden md:flex items-center justify-center gap-5 text-white font-bold">
                            <div className="flex items-center gap-1.5"><Heart fill="white" size={18} /> {post.likes_count || 0}</div>
                            <div className="flex items-center gap-1.5"><MessageCircle fill="white" size={18} /> {post.comments_count || 0}</div>
                        </div>
                    </div>
                ))
            )}
        </div>
    );

    return (
        <div className="min-h-screen bg-white dark:bg-black md:bg-gray-50 md:dark:bg-black">

            {/* ═══════ MOBILE ═══════ */}
            <div className="md:hidden">
                {/* Nav Bar */}
                <div className="sticky top-0 bg-white/95 dark:bg-black/95 backdrop-blur-sm border-b border-gray-100 dark:border-gray-800 px-4 py-3 flex justify-between items-center z-40">
                    <div className="flex items-center gap-1 min-w-0">
                        {!isOwnProfile && (
                            <button onClick={() => navigate(-1)} className="mr-2 flex-shrink-0">
                                <ArrowLeft size={24} className="text-gray-900 dark:text-white" />
                            </button>
                        )}
                        <h1 className="text-xl font-bold text-gray-900 dark:text-white flex items-center gap-1.5 truncate">
                            {profileUser.username}
                            <VerifiedBadge />
                        </h1>
                    </div>
                    {isOwnProfile && (
                        <div className="flex items-center gap-4 text-gray-900 dark:text-white flex-shrink-0">
                            <Link to="/create"><Plus size={26} /></Link>
                            <Link to="/settings"><Menu size={26} /></Link>
                        </div>
                    )}
                </div>

                <div className="px-4 pt-4 pb-2">
                    {/* Avatar + Stats */}
                    <div className="flex items-center justify-between mb-4">
                        <div className="relative flex-shrink-0">
                            <div className="w-20 h-20 rounded-full p-[2px] bg-gradient-to-tr from-yellow-400 via-orange-500 to-pink-500">
                                <div className="w-full h-full rounded-full bg-white dark:bg-black p-[2px] overflow-hidden">
                                    {profileUser.avatar_url ? (
                                        <img src={profileUser.avatar_url} alt={profileUser.username} className="w-full h-full object-cover rounded-full" />
                                    ) : (
                                        <div className="w-full h-full bg-gradient-to-tr from-yellow-400 via-orange-500 to-pink-500 flex items-center justify-center text-xl font-bold text-white rounded-full">
                                            {getInitials(profileUser.full_name)}
                                        </div>
                                    )}
                                </div>
                            </div>
                            {isOwnProfile && (
                                <button type="button" onClick={() => setShowAvatarModal(true)}
                                    className="absolute bottom-0 right-0 w-6 h-6 bg-blue-500 text-white rounded-full border-2 border-white dark:border-black flex items-center justify-center shadow">
                                    <Plus size={12} strokeWidth={3} />
                                </button>
                            )}
                        </div>
                        <div className="flex flex-1 justify-around ml-4">
                            {[
                                { val: profileUser.posts_count ?? userPosts.length, label: 'Posts' },
                                { val: profileUser.followers_count || 0, label: 'Followers' },
                                { val: profileUser.following_count || 0, label: 'Following' },
                            ].map(({ val, label }) => (
                                <div key={label} className="flex flex-col items-center">
                                    <span className="font-bold text-base text-gray-900 dark:text-white">{val}</span>
                                    <span className="text-xs text-gray-500 dark:text-gray-400">{label}</span>
                                </div>
                            ))}
                        </div>
                    </div>

                    {/* Bio */}
                    <div className="mb-3">
                        <div className="font-bold text-sm text-gray-900 dark:text-white">{profileUser.full_name}</div>
                        {profileUser.role === 'vendor' && (
                            <span className="inline-block text-[10px] font-semibold bg-orange-100 dark:bg-orange-900/40 text-orange-600 dark:text-orange-400 px-2 py-0.5 rounded-full mt-0.5 mb-0.5">
                                Vendor
                            </span>
                        )}
                        {profileUser.bio ? (
                            <div className="text-sm text-gray-700 dark:text-gray-300 whitespace-pre-wrap">{profileUser.bio}</div>
                        ) : null}
                    </div>

                    {/* Action Buttons */}
                    <div className="flex gap-2 mb-5">
                        {isOwnProfile ? (
                            <>
                                <Link to="/edit-profile" className="flex-1 bg-gray-100 dark:bg-gray-800 hover:bg-gray-200 dark:hover:bg-gray-700 text-gray-900 dark:text-white text-sm font-semibold py-1.5 rounded-lg text-center transition-colors">Edit profile</Link>
                                <Link to="/archive" className="flex-1 bg-gray-100 dark:bg-gray-800 hover:bg-gray-200 dark:hover:bg-gray-700 text-gray-900 dark:text-white text-sm font-semibold py-1.5 rounded-lg text-center transition-colors">View archive</Link>
                                <Link to="/settings" className="bg-gray-100 dark:bg-gray-800 text-gray-900 dark:text-white p-2 rounded-lg">
                                    <Settings size={18} />
                                </Link>
                            </>
                        ) : (
                            <>
                                <button className="flex-1 bg-gradient-to-r from-orange-500 to-pink-500 text-white text-sm font-semibold py-1.5 rounded-lg hover:opacity-90 transition-opacity">Follow</button>
                                <button className="flex-1 bg-gray-100 dark:bg-gray-800 text-gray-900 dark:text-white text-sm font-semibold py-1.5 rounded-lg">Message</button>
                                <button className="bg-gray-100 dark:bg-gray-800 text-gray-900 dark:text-white p-2 rounded-lg"><MoreHorizontal size={18} /></button>
                            </>
                        )}
                    </div>

                    {/* Highlights */}
                    <div className="flex gap-4 overflow-x-auto pb-3 scrollbar-hide">
                        {highlights.map((h) => (
                            <div key={h.id} className="flex flex-col items-center gap-1 flex-shrink-0">
                                <div className="w-16 h-16 rounded-full p-[1.5px] bg-gradient-to-tr from-yellow-400 via-orange-500 to-pink-500">
                                    <div className="w-full h-full rounded-full bg-white dark:bg-black p-0.5 overflow-hidden">
                                        <img src={h.img} alt={h.title} className="w-full h-full rounded-full object-cover" />
                                    </div>
                                </div>
                                <span className="text-[10px] text-gray-900 dark:text-white truncate max-w-[60px] text-center">{h.title}</span>
                            </div>
                        ))}
                        {isOwnProfile && (
                            <div className="flex flex-col items-center gap-1 flex-shrink-0">
                                <div className="w-16 h-16 rounded-full border-2 border-dashed border-gray-300 dark:border-gray-700 flex items-center justify-center">
                                    <Plus size={20} className="text-gray-400" />
                                </div>
                                <span className="text-[10px] text-gray-400">New</span>
                            </div>
                        )}
                    </div>
                </div>

                {/* Vendor Ad Panel (mobile) */}
                

                {/* Mobile Tabs — icon only, Instagram style */}
                <div className="flex border-t border-gray-200 dark:border-gray-800 sticky top-[53px] bg-white dark:bg-black z-30">
                    {tabConfig.map(tab => (
                        <button key={tab.key} onClick={() => setActiveTab(tab.key)}
                            className={`flex-1 py-3 flex justify-center items-center border-b-[2px] transition-all ${
                                activeTab === tab.key
                                    ? 'border-gray-900 dark:border-white text-gray-900 dark:text-white'
                                    : 'border-transparent text-gray-400 dark:text-gray-600'
                            }`}
                        >
                            {tab.icon}
                        </button>
                    ))}
                </div>

                <PostGrid containerClass="pb-24" />
            </div>


            {/* ═══════ DESKTOP ═══════ */}
            <div className="hidden md:block max-w-[935px] mx-auto pt-8 px-4 pb-12">

                {/* Profile Header */}
                <div className="flex gap-16 items-start mb-11 px-4">
                    {/* Avatar */}
                    <div className="relative flex-shrink-0">
                        <div
                            onClick={() => isOwnProfile && setShowAvatarModal(true)}
                            className={`w-[150px] h-[150px] rounded-full p-[3px] bg-gradient-to-tr from-yellow-400 via-orange-500 to-pink-500 transition-opacity ${isOwnProfile ? 'cursor-pointer hover:opacity-90' : ''}`}
                        >
                            <div className="w-full h-full rounded-full bg-white dark:bg-black p-[3px] overflow-hidden">
                                {profileUser.avatar_url ? (
                                    <img src={profileUser.avatar_url} className="w-full h-full rounded-full object-cover" alt="Profile" />
                                ) : (
                                    <div className="w-full h-full bg-gradient-to-tr from-yellow-400 via-orange-500 to-pink-500 flex items-center justify-center text-5xl font-bold text-white rounded-full">
                                        {getInitials(profileUser.full_name || profileUser.username)}
                                    </div>
                                )}
                            </div>
                        </div>
                        {isOwnProfile && (
                            <button type="button" onClick={() => setShowAvatarModal(true)}
                                className="absolute bottom-2 right-2 w-8 h-8 rounded-full bg-blue-500 text-white flex items-center justify-center border-2 border-white dark:border-black shadow-md hover:bg-blue-600 transition-colors">
                                <Plus size={16} strokeWidth={2.5} />
                            </button>
                        )}
                    </div>

                    {/* Info */}
                    <div className="flex flex-col flex-1 pt-1 min-w-0">
                        {/* Username row */}
                        <div className="flex flex-wrap items-center gap-3 mb-4">
                            <h2 className="text-2xl font-light text-gray-900 dark:text-white">{profileUser.username}</h2>
                            <VerifiedBadge />
                            {profileUser.role === 'vendor' && (
                                <span className="text-xs font-semibold bg-orange-100 dark:bg-orange-900/40 text-orange-600 dark:text-orange-400 px-2.5 py-1 rounded-full">Vendor</span>
                            )}
                            {isOwnProfile ? (
                                <>
                                    <Link to="/edit-profile" className="px-4 py-1.5 bg-gray-100 dark:bg-gray-800 hover:bg-gray-200 dark:hover:bg-gray-700 text-gray-900 dark:text-white font-semibold rounded-lg text-sm transition-colors">Edit profile</Link>
                                    <Link to="/archive" className="px-4 py-1.5 bg-gray-100 dark:bg-gray-800 hover:bg-gray-200 dark:hover:bg-gray-700 text-gray-900 dark:text-white font-semibold rounded-lg text-sm transition-colors">View archive</Link>
                                    <Link to="/settings" className="p-2 text-gray-900 dark:text-white hover:bg-gray-100 dark:hover:bg-gray-800 rounded-full transition-colors"><Settings size={22} /></Link>
                                </>
                            ) : (
                                <>
                                    <button className="px-5 py-1.5 bg-gradient-to-r from-orange-500 to-pink-500 text-white font-semibold rounded-lg text-sm hover:opacity-90 transition-opacity">Follow</button>
                                    <button className="px-5 py-1.5 bg-gray-100 dark:bg-gray-800 text-gray-900 dark:text-white font-semibold rounded-lg text-sm">Message</button>
                                    <button className="p-2 text-gray-900 dark:text-white hover:bg-gray-100 dark:hover:bg-gray-800 rounded-full transition-colors"><MoreHorizontal size={22} /></button>
                                </>
                            )}
                        </div>

                        {/* Stats */}
                        <div className="flex gap-8 mb-4">
                            {[
                                { val: profileUser.posts_count ?? userPosts.length, label: 'posts' },
                                { val: profileUser.followers_count || 0, label: 'followers' },
                                { val: profileUser.following_count || 0, label: 'following' },
                            ].map(({ val, label }) => (
                                <span key={label} className="text-sm text-gray-700 dark:text-gray-300">
                                    <span className="font-semibold text-gray-900 dark:text-white">{val}</span> {label}
                                </span>
                            ))}
                        </div>

                        {/* Name + Bio */}
                        <div className="max-w-sm">
                            <div className="font-semibold text-sm text-gray-900 dark:text-white">{profileUser.full_name || profileUser.username}</div>
                            {profileUser.bio && (
                                <div className="text-sm text-gray-700 dark:text-gray-300 whitespace-pre-wrap leading-relaxed mt-0.5">{profileUser.bio}</div>
                            )}
                        </div>
                    </div>
                </div>

                {/* Highlights */}
                <div className="flex gap-7 overflow-x-auto pb-5 scrollbar-hide mb-6 px-4 border-b border-gray-200 dark:border-gray-800">
                    {highlights.map((h) => (
                        <div key={h.id} className="flex flex-col items-center gap-2 flex-shrink-0 cursor-pointer group">
                            <div className="w-[77px] h-[77px] rounded-full p-[1.5px] bg-gradient-to-tr from-yellow-400 via-orange-500 to-pink-500 group-hover:scale-105 transition-transform">
                                <div className="w-full h-full rounded-full bg-white dark:bg-black p-[2px] overflow-hidden">
                                    <img src={h.img} alt={h.title} className="w-full h-full rounded-full object-cover" />
                                </div>
                            </div>
                            <span className="text-xs text-gray-900 dark:text-white text-center truncate max-w-[77px]">{h.title}</span>
                        </div>
                    ))}
                    {isOwnProfile && (
                        <div className="flex flex-col items-center gap-2 flex-shrink-0 cursor-pointer group">
                            <div className="w-[77px] h-[77px] rounded-full border-2 border-dashed border-gray-300 dark:border-gray-700 flex items-center justify-center group-hover:border-gray-400 transition-colors">
                                <Plus size={28} className="text-gray-400" />
                            </div>
                            <span className="text-xs text-gray-500">New</span>
                        </div>
                    )}
                </div>

                {/* Vendor Ad Panel (desktop) */}
             

                {/* Desktop Tabs */}
                <div className="flex justify-center gap-14 border-t border-gray-200 dark:border-gray-800 -mt-px mb-0">
                    {tabConfig.map(tab => (
                        <button key={tab.key} onClick={() => setActiveTab(tab.key)}
                            className={`flex items-center gap-1.5 py-4 border-t-[1px] text-[11px] font-semibold tracking-widest uppercase transition-all ${
                                activeTab === tab.key
                                    ? 'border-gray-900 dark:border-white text-gray-900 dark:text-white'
                                    : 'border-transparent text-gray-400 hover:text-gray-600 dark:hover:text-gray-300'
                            }`}
                        >
                            {React.cloneElement(tab.icon, { size: 12 })} {tab.label}
                        </button>
                    ))}
                </div>

                <PostGrid />

                {/* Floating Wallet */}
                <div className="fixed bottom-8 right-8 z-50 hover:scale-105 transition-transform cursor-pointer">
                    <div className="flex items-center gap-2 bg-white dark:bg-gray-900 rounded-full shadow-xl border border-gray-100 dark:border-gray-800 p-1 pr-4">
                        <div className="w-11 h-11 rounded-full bg-gradient-to-tr from-yellow-400 via-orange-500 to-pink-500 flex items-center justify-center text-white shadow">
                            <Wallet size={20} />
                        </div>
                        <div className="flex flex-col">
                            <span className="text-[10px] text-gray-500 dark:text-gray-400 font-medium uppercase tracking-wider">Balance</span>
                            <span className="text-sm font-bold text-gray-900 dark:text-white">
                                {currentUser?.wallet?.balance ? Math.floor(Number(currentUser.wallet.balance)) : 0} Coins
                            </span>
                        </div>
                    </div>
                </div>
            </div>

            {/* Modals */}
            <PostDetailModal isOpen={!!selectedPost} post={selectedPost} onClose={() => setSelectedPost(null)} />

            <AvatarCropModal
                isOpen={showAvatarModal}
                onClose={() => setShowAvatarModal(false)}
                onSuccess={handleAvatarSuccess}
                currentAvatar={profileUser.avatar_url}
                userName={profileUser.full_name || profileUser.username}
            />
        </div>
    );
};

export default Profile;
