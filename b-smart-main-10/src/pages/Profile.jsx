import React, { useState, useEffect, useCallback, useRef } from 'react';
import { Settings, Video, Menu, Grid, Plus, Heart, MessageCircle, Wallet, ArrowLeft, MoreHorizontal, Megaphone, Loader2, Eye, Building2, FileText, Hash, Calendar, Briefcase } from 'lucide-react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import { useDispatch, useSelector } from 'react-redux';
import { supabase } from '../lib/supabase';
import api from '../lib/api';
import PostDetailModal from '../components/PostDetailModal';
import AvatarCropModal from '../components/AvatarCropModal';
import { setUser } from '../store/authSlice';

// ─── helpers ──────────────────────────────────────────────────────────────────
const fmt = (n = 0) => {
    if (n >= 1_000_000) return (n / 1_000_000).toFixed(1) + 'M';
    if (n >= 1_000) return (n / 1_000).toFixed(1) + 'k';
    return String(n);
};

const BASE_URL = 'https://api.bebsmart.in';

const Profile = () => {
    const navigate = useNavigate();
    const dispatch = useDispatch();
    const { userId } = useParams();
    const { userObject: currentUser } = useSelector((state) => state.auth);
    // Read wallet from Redux wallet slice (kept live by Layout.jsx)
    const walletBalance = useSelector((state) => state.wallet?.balance ?? 0);

    const [profileUser, setProfileUser] = useState(null);
    const isOwnProfile = !userId || (currentUser && (userId === currentUser.id || userId === currentUser._id));

    const [activeTab, setActiveTab] = useState(null); // initialized after profileUser loads
    const [userPosts, setUserPosts] = useState([]);
    const [loadingPosts, setLoadingPosts] = useState(true);
    const [selectedPost, setSelectedPost] = useState(null);
    const [selectedAd, setSelectedAd] = useState(null);
    const [showAvatarModal, setShowAvatarModal] = useState(false);

    // Vendor-specific state
    const [userAds, setUserAds] = useState([]);
    const [loadingAds, setLoadingAds] = useState(false);
    const [followed, setFollowed] = useState(false);
    const [followLoading, setFollowLoading] = useState(false);
    const [vendorInfo, setVendorInfo] = useState(null);
    const [rewardToast, setRewardToast] = useState(null);

    const profileRewardMsRef = useRef(0);
    const profileRewardTickRef = useRef(null);
    const profileRewardSentRef = useRef(false);

    const onlyPosts = userPosts.filter(p => p.type !== 'reel');
    const onlyReels = userPosts.filter(p => p.type === 'reel');
    const displayedPosts =
        activeTab === 'reels' ? onlyReels :
        activeTab === 'posts' ? onlyPosts :
        userPosts;

    // ── Fetch profile user ──────────────────────────────────────────────────
    useEffect(() => {
        const fetchProfileUser = async () => {
            if (isOwnProfile) {
                setProfileUser(currentUser);
            } else {
                try {
                    const response = await api.get(`/users/${userId}`);
                    setProfileUser(response.data?.user || response.data);
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

    // Set default tab based on role
    useEffect(() => {
        if (profileUser) {
            setActiveTab(profileUser.role === 'vendor' ? 'ads' : 'all');
        }
    }, [profileUser?.role]);
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

    // ── Fetch ads (for vendor profiles) ────────────────────────────────────
    const fetchAds = useCallback(async () => {
        const profileUserId = profileUser?._id || profileUser?.id;
        if (!profileUserId || profileUser?.role !== 'vendor') return;
        setLoadingAds(true);
        try {
            let list = [];
            // Try multiple endpoints to get this vendor's ads
            const attempts = [
                () => api.get(`/ads`, { params: { vendor_id: profileUserId, status: 'active', limit: 50 } }),
                () => api.get(`/ads/feed`, { params: { vendor_id: profileUserId, limit: 50 } }),
                () => api.get(`/users/${profileUserId}/ads`),
                () => api.get(`/vendors/${profileUserId}/ads`),
            ];
            for (const attempt of attempts) {
                try {
                    const res = await attempt();
                    const data = res?.data;
                    list = Array.isArray(data) ? data : (data?.ads || data?.data || []);
                    if (list.length > 0) break;
                } catch { /* try next */ }
            }
            setUserAds(list);
        } catch (e) {
            console.error('Error fetching vendor ads:', e);
        } finally {
            setLoadingAds(false);
        }
    }, [profileUser]);

    // Auto-fetch ads when we know it's a vendor and the ads tab is opened
    useEffect(() => {
        if (profileUser?.role === 'vendor' && activeTab === 'ads' && userAds.length === 0) {
            fetchAds();
        }
    }, [activeTab, profileUser, fetchAds, userAds.length]);

    // Also pre-fetch ads right after profile loads (so the count shows)
    useEffect(() => {
        if (profileUser?.role === 'vendor') {
            fetchAds();
        }
    }, [profileUser?.role, profileUser?._id, profileUser?.id]); // eslint-disable-line

    // ── Fetch vendor business info ───────────────────────────────────────────
    useEffect(() => {
        const fetchVendorInfo = async () => {
            const profileUserId = profileUser?._id || profileUser?.id;
            if (!profileUserId || profileUser?.role !== 'vendor') return;
            try {
                const res = await api.get(`/vendors/${profileUserId}`);
                const data = res?.data;
                setVendorInfo(data?.vendor || data?.business || data || null);
            } catch (e) {
                console.error('Error fetching vendor info:', e);
            }
        };
        fetchVendorInfo();
    }, [profileUser?._id, profileUser?.id, profileUser?.role]); // eslint-disable-line
    const handleFollow = async () => {
        if (followLoading) return;
        setFollowLoading(true);
        const was = followed;
        setFollowed(!was);
        try {
            const endpoint = was ? '/unfollow' : '/follow';
            await api.post(endpoint, { followedUserId: profileUser?._id || profileUser?.id });
        } catch {
            setFollowed(was);
        } finally {
            setFollowLoading(false);
        }
    };

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

    useEffect(() => {
        if (!rewardToast) return undefined;
        const timer = setTimeout(() => setRewardToast(null), 3500);
        return () => clearTimeout(timer);
    }, [rewardToast]);

    useEffect(() => {
        const profileUserId = profileUser?._id || profileUser?.id;
        const isEligible =
            Boolean(profileUserId) &&
            profileUser?.role === 'vendor' &&
            currentUser?.role === 'member' &&
            !isOwnProfile;

        profileRewardMsRef.current = 0;
        profileRewardTickRef.current = null;
        profileRewardSentRef.current = false;

        if (!isEligible) return undefined;

        const sendReward = async () => {
            if (profileRewardSentRef.current) return;
            profileRewardSentRef.current = true;
            try {
                const res = await api.post(`/vendors/profile/${profileUserId}/viewProfile`);
                const coins = Number(res?.data?.coins_earned || 10);
                setRewardToast({
                    type: 'success',
                    message: `You earned ${coins} coins for viewing this vendor profile.`,
                });
            } catch (error) {
                const message = error?.response?.data?.message || '';
                if (error?.response?.status === 429) return;
                profileRewardSentRef.current = false;
                setRewardToast({
                    type: 'error',
                    message: message || 'Unable to process vendor profile reward.',
                });
            }
        };

        const syncElapsed = () => {
            if (document.visibilityState !== 'visible') {
                profileRewardTickRef.current = null;
                return;
            }
            const now = Date.now();
            if (profileRewardTickRef.current == null) {
                profileRewardTickRef.current = now;
                return;
            }
            profileRewardMsRef.current += now - profileRewardTickRef.current;
            profileRewardTickRef.current = now;

            if (profileRewardMsRef.current >= 180000) {
                sendReward();
            }
        };

        const handleVisibilityChange = () => {
            if (document.visibilityState === 'visible') {
                profileRewardTickRef.current = Date.now();
            } else {
                syncElapsed();
            }
        };

        handleVisibilityChange();
        const interval = setInterval(syncElapsed, 1000);
        document.addEventListener('visibilitychange', handleVisibilityChange);

        return () => {
            clearInterval(interval);
            document.removeEventListener('visibilitychange', handleVisibilityChange);
        };
    }, [profileUser?._id, profileUser?.id, profileUser?.role, currentUser?.role, isOwnProfile]);

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

    // Get thumbnail for ad
    const getAdThumbnail = (ad) => {
        const m = ad.media?.[0];
        if (!m) return null;
        // For video ads prefer the thumbnail image
        if (m.media_type === 'video' && m.thumbnails?.length > 0) {
            const t = m.thumbnails[0];
            if (t.fileUrl && t.fileUrl.startsWith('http')) return t.fileUrl;
            if (t.fileName) return `${BASE_URL}/uploads/${t.fileName}`;
        }
        if (m.fileUrl && m.fileUrl.startsWith('http')) return m.fileUrl;
        if (m.fileName) return `${BASE_URL}/uploads/${m.fileName}`;
        return null;
    };

    const handlePostClick = (post) => {
        const id = post._id || post.id;
        if (window.innerWidth < 768 && id) navigate(`/post/${id}`);
        else setSelectedPost(post);
    };




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

    const isVendor = profileUser.role === 'vendor';

    const tabConfig = isVendor
        ? [{ key: 'ads', label: 'Ads', icon: <Megaphone size={22} /> }]
        : [
            { key: 'all',   label: 'All',   icon: <Grid size={22} /> },
            { key: 'posts', label: 'Posts', icon: <Grid size={22} /> },
            { key: 'reels', label: 'Reels', icon: <Video size={22} /> },
          ];

    // ── Vendor Business Info Card ─────────────────────────────────────────────
    const VendorBusinessCard = () => {
        if (!isVendor || !vendorInfo) return null;
        const fields = [
            { icon: <Building2 size={15} className="text-orange-500 flex-shrink-0" />, label: 'Company', value: vendorInfo.company_name || vendorInfo.registered_name },
            { icon: <FileText size={15} className="text-orange-500 flex-shrink-0" />, label: 'Registered As', value: vendorInfo.registered_name },
            { icon: <Briefcase size={15} className="text-orange-500 flex-shrink-0" />, label: 'Industry', value: vendorInfo.industry },
            { icon: <Hash size={15} className="text-orange-500 flex-shrink-0" />, label: 'Reg. Number', value: vendorInfo.registration_number },
            { icon: <Hash size={15} className="text-orange-500 flex-shrink-0" />, label: 'Tax ID', value: vendorInfo.tax_id },
            { icon: <Calendar size={15} className="text-orange-500 flex-shrink-0" />, label: 'Est. Year', value: vendorInfo.year_established },
            { icon: <Briefcase size={15} className="text-orange-500 flex-shrink-0" />, label: 'Company Type', value: vendorInfo.company_type },
        ].filter(f => f.value);

        return (
            <div className="bg-gradient-to-br from-orange-50 to-amber-50 dark:from-gray-900 dark:to-gray-800 border border-orange-100 dark:border-orange-900/30 rounded-2xl p-5 mb-6">
                <div className="flex items-center gap-2 mb-4">
                    <div className="w-8 h-8 rounded-lg bg-gradient-to-tr from-orange-400 to-pink-500 flex items-center justify-center shadow-sm">
                        <Building2 size={16} className="text-white" />
                    </div>
                    <h3 className="font-bold text-gray-900 dark:text-white text-sm">Business Information</h3>
                </div>
                <div className="grid grid-cols-2 gap-3">
                    {fields.map(({ icon, label, value }) => (
                        <div key={label} className="flex items-start gap-2 bg-white dark:bg-gray-800/60 rounded-xl px-3 py-2.5 shadow-sm">
                            {icon}
                            <div className="min-w-0">
                                <p className="text-[10px] font-semibold text-gray-400 dark:text-gray-500 uppercase tracking-wider">{label}</p>
                                <p className="text-sm font-semibold text-gray-900 dark:text-white truncate">{value}</p>
                            </div>
                        </div>
                    ))}
                </div>
            </div>
        );
    };

    const renderContent = () => {
        if (activeTab === null) return null;
        if (activeTab === 'ads') return <AdsGrid />;
        return <PostGrid />;
    };
    const renderContentMobile = () => {
        if (activeTab === null) return null;
        if (activeTab === 'ads') return <AdsGrid containerClass="" />;
        return <PostGrid containerClass="" />;
    };

    const AdsGrid = ({ containerClass = '' }) => (
        <div className={`${containerClass}`}>
            {loadingAds ? (
                <div className="col-span-3 flex flex-col items-center py-16 gap-3 bg-white dark:bg-black">
                    <Loader2 className="w-7 h-7 animate-spin text-orange-500" />
                    <span className="text-sm text-gray-400">Loading ads…</span>
                </div>
            ) : userAds.length === 0 ? (
                <div className="col-span-3 bg-white dark:bg-black py-14 text-center">
                    <div className="w-16 h-16 border-2 border-gray-300 dark:border-gray-600 rounded-full flex items-center justify-center mx-auto mb-4">
                        <Megaphone size={30} className="text-gray-300 dark:text-gray-600" />
                    </div>
                    <h3 className="font-semibold text-base text-gray-900 dark:text-white mb-1">No Ads Yet</h3>
                    {isOwnProfile && (
                        <Link to="/create-ad" className="text-blue-500 text-sm font-semibold mt-1 inline-block">Create ad now</Link>
                    )}
                </div>
            ) : (
                <div className="grid grid-cols-3 gap-[1px] bg-gray-200 dark:bg-gray-800">
                    {userAds.map((ad) => {
                        const thumb = getAdThumbnail(ad);
                        const isVideo = ad.media?.[0]?.media_type === 'video';
                        return (
                            <div key={ad._id || ad.id}
                                className="aspect-square bg-gray-100 dark:bg-gray-900 relative group cursor-pointer overflow-hidden"
                                onClick={() => setSelectedAd({ ...ad, item_type: 'ad' })}>
                                {/* Active badge */}
                                {ad.status === 'active' && (
                                    <div className="absolute top-1.5 left-1.5 z-10">
                                        <span className="text-[9px] font-bold bg-orange-500 text-white px-1.5 py-0.5 rounded-full">AD</span>
                                    </div>
                                )}
                                {isVideo && (
                                    <div className="absolute top-1.5 right-1.5 z-10">
                                        <Video size={15} className="text-white drop-shadow" fill="white" />
                                    </div>
                                )}
                                {thumb ? (
                                    <img src={thumb} alt={ad.caption || 'Ad'} className="w-full h-full object-cover group-hover:scale-[1.03] transition-transform duration-200" />
                                ) : (
                                    <div className="w-full h-full flex items-center justify-center bg-gradient-to-br from-orange-100 to-pink-100 dark:from-gray-800 dark:to-gray-700">
                                        <Megaphone size={28} className="text-orange-400 dark:text-gray-500" />
                                    </div>
                                )}
                                {/* Hover overlay */}
                                <div className="absolute inset-0 bg-black/40 opacity-0 group-hover:opacity-100 transition-opacity hidden md:flex items-center justify-center gap-4 text-white font-bold">
                                    <div className="flex items-center gap-1.5"><Heart fill="white" size={16}/> {fmt(ad.likes_count || 0)}</div>
                                    <div className="flex items-center gap-1.5"><Eye size={16}/> {fmt(ad.views_count || ad.unique_views_count || 0)}</div>
                                </div>
                            </div>
                        );
                    })}
                </div>
            )}
        </div>
    );

    // ── Posts Grid ────────────────────────────────────────────────────────────
    const PostGrid = ({ containerClass = '' }) => (
        <div className={`grid grid-cols-3 gap-[1px] bg-gray-200 dark:bg-gray-800 ${containerClass}`}>
            {loadingPosts ? (
                Array(9).fill(null).map((_, i) => (
                    <div key={i} className="aspect-square bg-gray-100 dark:bg-gray-900 animate-pulse" />
                ))
            ) : displayedPosts.length === 0 ? (
                <div className="col-span-3 bg-white dark:bg-black py-14 text-center">
                    <div className="w-16 h-16 border-2 border-gray-300 dark:border-gray-600 rounded-full flex items-center justify-center mx-auto mb-4">
                        {activeTab === 'reels'
                            ? <Video size={30} className="text-gray-300 dark:text-gray-600" />
                            : <Grid size={30} className="text-gray-300 dark:text-gray-600" />}
                    </div>
                    <h3 className="font-semibold text-base text-gray-900 dark:text-white mb-1">
                        {activeTab === 'reels' ? 'No Reels Yet' : 'No Posts Yet'}
                    </h3>
                    {isOwnProfile && (
                        <Link to="/create" className="text-blue-500 text-sm font-semibold mt-1 inline-block">Create now</Link>
                    )}
                </div>
            ) : (
                displayedPosts.map((post) => (
                    <div key={post._id || post.id}
                        className="aspect-square bg-gray-100 dark:bg-gray-900 relative group cursor-pointer overflow-hidden"
                        onClick={() => handlePostClick(post)}>
                        {post.type === 'reel' && (
                            <div className="absolute top-1.5 right-1.5 z-10">
                                <Video size={15} className="text-white drop-shadow" fill="white" />
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
            {rewardToast && (
                <div className={`fixed top-20 left-1/2 z-[80] -translate-x-1/2 rounded-xl border px-4 py-3 text-sm font-semibold shadow-lg ${
                    rewardToast.type === 'success'
                        ? 'border-green-200 bg-green-50 text-green-700 dark:border-green-800 dark:bg-green-900/20 dark:text-green-400'
                        : 'border-red-200 bg-red-50 text-red-700 dark:border-red-800 dark:bg-red-900/20 dark:text-red-400'
                }`}>
                    {rewardToast.message}
                </div>
            )}

            {/* ═══════ MOBILE ═══════ */}
            <div className="md:hidden flex flex-col h-[calc(120vh-60px)]">

                {/* ── Fixed header block (username bar + profile info + tabs) ── */}
                <div className="flex-shrink-0 bg-white dark:bg-black">
                    {/* Nav Bar */}
                    <div className="bg-white/95 dark:bg-black/95 backdrop-blur-sm border-b border-gray-100 dark:border-gray-800 px-4 py-3 flex justify-between items-center">
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
                                    ...(isVendor ? [{ val: userAds.length, label: 'Ads' }] : []),
                                ].map(({ val, label }) => (
                                    <div key={label} className="flex flex-col items-center">
                                        <span className="font-bold text-base text-gray-900 dark:text-white">{fmt(val)}</span>
                                        <span className="text-xs text-gray-500 dark:text-gray-400">{label}</span>
                                    </div>
                                ))}
                            </div>
                        </div>

                        {/* Bio */}
                        <div className="mb-3">
                            <div className="font-bold text-sm text-gray-900 dark:text-white">{profileUser.full_name}</div>
                            {isVendor && (
                                <span className="inline-block text-[10px] font-semibold bg-orange-100 dark:bg-orange-900/40 text-orange-600 dark:text-orange-400 px-2 py-0.5 rounded-full mt-0.5 mb-0.5">
                                    Vendor
                                </span>
                            )}
                            {profileUser.bio && (
                                <div className="text-sm text-gray-700 dark:text-gray-300 whitespace-pre-wrap">{profileUser.bio}</div>
                            )}
                        </div>

                        {/* Action Buttons */}
                        <div className="flex gap-2 mb-4">
                            {isOwnProfile ? (
                                <>
                                    <Link to="/edit-profile" className="flex-1 bg-gray-100 dark:bg-gray-800 hover:bg-gray-200 dark:hover:bg-gray-700 text-gray-900 dark:text-white text-sm font-semibold py-1.5 rounded-lg text-center transition-colors">Edit profile</Link>
                                    <Link to={isVendor ? '/vendor/profile' : '/archive'} className="flex-1 bg-gray-100 dark:bg-gray-800 hover:bg-gray-200 dark:hover:bg-gray-700 text-gray-900 dark:text-white text-sm font-semibold py-1.5 rounded-lg text-center transition-colors">
                                        {isVendor ? 'Business Profile' : 'View archive'}
                                    </Link>
                                    <Link to="/settings" className="bg-gray-100 dark:bg-gray-800 text-gray-900 dark:text-white p-2 rounded-lg">
                                        <Settings size={18} />
                                    </Link>
                                </>
                            ) : (
                                <>
                                    <button onClick={handleFollow} disabled={followLoading}
                                        className="flex-1 bg-gradient-to-r from-orange-500 to-pink-500 text-white text-sm font-semibold py-1.5 rounded-lg hover:opacity-90 transition-opacity disabled:opacity-60 flex items-center justify-center gap-1">
                                        {followLoading && <Loader2 size={12} className="animate-spin" />}
                                        {followed ? 'Following' : 'Follow'}
                                    </button>
                                    <button className="flex-1 bg-gray-100 dark:bg-gray-800 text-gray-900 dark:text-white text-sm font-semibold py-1.5 rounded-lg">Message</button>
                                    <button className="bg-gray-100 dark:bg-gray-800 text-gray-900 dark:text-white p-2 rounded-lg"><MoreHorizontal size={18} /></button>
                                </>
                            )}
                        </div>

                        {/* Vendor Business Info (mobile) */}
                        {isVendor && vendorInfo && (
                            <div className="pb-2">
                                <VendorBusinessCard />
                            </div>
                        )}
                    </div>

                    {/* Tabs — fixed, never scroll away */}
                    <div className="flex border-t border-b border-gray-200 dark:border-gray-800 bg-white dark:bg-black">
                        {tabConfig.map(tab => (
                            <button key={tab.key} onClick={() => setActiveTab(tab.key)}
                                className={`flex-1 py-3 flex justify-center items-center border-b-[2px] transition-all ${
                                    activeTab === tab.key
                                        ? 'border-gray-900 dark:border-white text-gray-900 dark:text-white'
                                        : 'border-transparent text-gray-400 dark:text-gray-600'
                                }`}>
                                {tab.icon}
                            </button>
                        ))}
                    </div>
                </div>

                {/* ── Scrollable grid only ── */}
                <div className="flex-1 overflow-y-auto">
                    {renderContentMobile()}
                </div>
            </div>


            {/* ═══════ DESKTOP ═══════ */}
            <div className="hidden md:flex flex-col h-[calc(100vh-0px)]">

                {/* Static header — doesn't scroll */}
                <div className="flex-shrink-0 max-w-[935px] mx-auto w-full pt-8 px-8">

                    {/* Profile Header */}
                    <div className="flex gap-16 items-start mb-11 px-4">
                        {/* Avatar */}
                        <div className="relative flex-shrink-0">
                            <div
                                onClick={() => isOwnProfile && setShowAvatarModal(true)}
                                className={`w-[150px] h-[150px] rounded-full p-[3px] bg-gradient-to-tr from-yellow-400 via-orange-500 to-pink-500 transition-opacity ${isOwnProfile ? 'cursor-pointer hover:opacity-90' : ''}`}>
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
                            <div className="flex flex-wrap items-center gap-3 mb-4">
                                <h2 className="text-2xl font-light text-gray-900 dark:text-white">{profileUser.username}</h2>
                                <VerifiedBadge />
                                {isVendor && (
                                    <span className="text-xs font-semibold bg-orange-100 dark:bg-orange-900/40 text-orange-600 dark:text-orange-400 px-2.5 py-1 rounded-full">Vendor</span>
                                )}
                                {isOwnProfile ? (
                                    <>
                                        <Link to="/edit-profile" className="px-4 py-1.5 bg-gray-100 dark:bg-gray-800 hover:bg-gray-200 dark:hover:bg-gray-700 text-gray-900 dark:text-white font-semibold rounded-lg text-sm transition-colors">Edit profile</Link>
                                        {isVendor && <Link to="/vendor/profile" className="px-4 py-1.5 bg-gray-100 dark:bg-gray-800 hover:bg-gray-200 dark:hover:bg-gray-700 text-gray-900 dark:text-white font-semibold rounded-lg text-sm transition-colors">Business Profile</Link>}
                                        <Link to="/settings" className="p-2 text-gray-900 dark:text-white hover:bg-gray-100 dark:hover:bg-gray-800 rounded-full transition-colors"><Settings size={22} /></Link>
                                    </>
                                ) : (
                                    <>
                                        <button onClick={handleFollow} disabled={followLoading}
                                            className="px-5 py-1.5 bg-gradient-to-r from-orange-500 to-pink-500 text-white font-semibold rounded-lg text-sm hover:opacity-90 transition-opacity disabled:opacity-60 flex items-center gap-1">
                                            {followLoading && <Loader2 size={12} className="animate-spin" />}
                                            {followed ? 'Following' : 'Follow'}
                                        </button>
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
                                    ...(isVendor ? [{ val: userAds.length, label: 'ads' }] : []),
                                ].map(({ val, label }) => (
                                    <span key={label} className="text-sm text-gray-700 dark:text-gray-300">
                                        <span className="font-semibold text-gray-900 dark:text-white">{fmt(val)}</span> {label}
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

                    {/* Vendor Business Info */}
                    <VendorBusinessCard />

                    {/* Desktop Tabs — fixed, never scroll away */}
                    <div className="flex justify-center gap-14 border-t border-gray-200 dark:border-gray-800 -mt-px">
                        {tabConfig.map(tab => (
                            <button key={tab.key} onClick={() => setActiveTab(tab.key)}
                                className={`flex items-center gap-1.5 py-4 border-t-[1px] text-[11px] font-semibold tracking-widest uppercase transition-all ${
                                    activeTab === tab.key
                                        ? 'border-gray-900 dark:border-white text-gray-900 dark:text-white'
                                        : 'border-transparent text-gray-400 hover:text-gray-600 dark:hover:text-gray-300'
                                }`}>
                                {React.cloneElement(tab.icon, { size: 12 })} {tab.label}
                            </button>
                        ))}
                    </div>
                </div>

                {/* Scrollable grid only */}
                <div className="flex-1 overflow-y-auto">
                    <div className="max-w-[935px] mx-auto px-4 pb-12">
                        {renderContent()}
                    </div>
                </div>

                {/* Floating Wallet */}
                <div className="fixed bottom-8 right-8 z-50 hover:scale-105 transition-transform cursor-pointer">
                    <Link to="/wallet" className="flex items-center gap-2 bg-white dark:bg-gray-900 rounded-full shadow-xl border border-gray-100 dark:border-gray-800 p-1 pr-4">
                        <div className="w-11 h-11 rounded-full bg-gradient-to-tr from-yellow-400 via-orange-500 to-pink-500 flex items-center justify-center text-white shadow">
                            <Wallet size={20} />
                        </div>
                        <div className="flex flex-col">
                            <span className="text-[10px] text-gray-500 dark:text-gray-400 font-medium uppercase tracking-wider">Balance</span>
                            <span className="text-sm font-bold text-gray-900 dark:text-white">{walletBalance} Coins</span>
                        </div>
                    </Link>
                </div>
            </div>

            {/* Modals */}
            <PostDetailModal isOpen={!!selectedPost} post={selectedPost} onClose={() => setSelectedPost(null)} />
            <PostDetailModal isOpen={!!selectedAd} post={selectedAd} onClose={() => setSelectedAd(null)} />
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