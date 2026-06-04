import React, { useState, useEffect, useCallback, useRef } from 'react';
import StoryViewer from '../components/StoryViewer';
import { Settings, Video, Menu, Grid, Plus, Heart, MessageCircle, Wallet, ArrowLeft, MoreHorizontal, Megaphone, Loader2, Eye, Building2, FileText, Hash, Calendar, Briefcase, Share2, Star, Lock, Twitter, Play, Image, X, ChevronLeft, ChevronRight } from 'lucide-react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import { useDispatch, useSelector } from 'react-redux';
import { supabase } from '../lib/supabase';
import api from '../lib/api';
import PostDetailModal from '../components/PostDetailModal';
import AvatarCropModal from '../components/AvatarCropModal';
import FollowersModal from '../components/FollowersModal';
import FollowingModal from '../components/FollowingModal';
import HighlightsRail from '../components/HighlightsRail';
import TweetDetailModal from '../components/TweetDetailModal';
import PromoteDetailModal from '../components/PromoteDetailModal';
import TweetImageGallery from '../components/TweetImageGallery';
import { setUser } from '../store/authSlice';
import { fetchUserStory } from '../store/storySlice';
import { createOrGetConversation } from '../services/chatService';
import bSmartBanner1 from '../assets/B-smart-banners/1.png';
import bSmartBanner2 from '../assets/B-smart-banners/2.png';
import bSmartBanner3 from '../assets/B-smart-banners/3.png';
import bSmartBanner4 from '../assets/B-smart-banners/4.png';
import bSmartBanner5 from '../assets/B-smart-banners/5.png';
import bSmartBanner6 from '../assets/B-smart-banners/6.png';
import bSmartBanner7 from '../assets/B-smart-banners/7.png';
import bSmartBanner8 from '../assets/B-smart-banners/8.png';
import bSmartBanner9 from '../assets/B-smart-banners/9.png';
import bSmartBanner10 from '../assets/B-smart-banners/10.png';
import bSmartBanner11 from '../assets/B-smart-banners/11.png';
import bSmartBanner12 from '../assets/B-smart-banners/12.png';
import bSmartBanner13 from '../assets/B-smart-banners/13.png';
import bSmartBanner14 from '../assets/B-smart-banners/14.png';
import bSmartBanner15 from '../assets/B-smart-banners/15.png';
import bSmartBanner16 from '../assets/B-smart-banners/16.png';
import bSmartBanner17 from '../assets/B-smart-banners/17.png';
import bSmartBanner18 from '../assets/B-smart-banners/18.png';
import bSmartBanner19 from '../assets/B-smart-banners/19.png';
import {
    checkFollowStatus,
    followUser,
    getFollowCounts,
    unfollowUser,
    cancelFollowRequest,
    FOLLOW_STATUS_CHANGED_EVENT,
} from '../services/followService';

// ─── helpers ──────────────────────────────────────────────────────────────────
const fmt = (n = 0) => {
    if (n >= 1_000_000) return (n / 1_000_000).toFixed(1) + 'M';
    if (n >= 1_000) return (n / 1_000).toFixed(1) + 'k';
    return String(n);
};

const BASE_URL = 'https://api.bebsmart.in';
const FAVORITE_BANNERS = [bSmartBanner1, bSmartBanner2, bSmartBanner3, bSmartBanner4];

const CATEGORY_IMAGES_LIST = [
    bSmartBanner1, bSmartBanner2, bSmartBanner3, bSmartBanner4, bSmartBanner5,
    bSmartBanner6, bSmartBanner7, bSmartBanner8, bSmartBanner9, bSmartBanner10,
    bSmartBanner11, bSmartBanner12, bSmartBanner13, bSmartBanner14, bSmartBanner15,
    bSmartBanner16, bSmartBanner17, bSmartBanner18, bSmartBanner19
];

// ── Ad interest categories — seeded from API, fallback list for offline ───────
const AD_CATEGORIES_FALLBACK = [
    'Accessories','Action Figures','Art Supplies','Baby Products',
    'Beauty & Personal Care','Books','Clothing & Apparel','Electronics',
    'Food & Beverages','Footwear','Gaming','Health & Wellness',
    'Home & Kitchen','Jewellery','Mobile & Tablets','Pet Supplies',
    'Sports & Fitness','Toys','Travel',
];

const getCategoryImage = (categoryName) => {
    const idx = AD_CATEGORIES_FALLBACK.indexOf(categoryName);
    if (idx !== -1) return CATEGORY_IMAGES_LIST[idx];
    return null;
};

// Category → emoji mapping for visual flair
const CATEGORY_EMOJI = {
    'Accessories': '👜', 'Action Figures': '🤖', 'Art Supplies': '🎨',
    'Baby Products': '🍼', 'Beauty & Personal Care': '💄', 'Books': '📚',
    'Clothing & Apparel': '👕', 'Electronics': '💻', 'Food & Beverages': '🍕',
    'Footwear': '👟', 'Gaming': '🎮', 'Health & Wellness': '💪',
    'Home & Kitchen': '🏠', 'Jewellery': '💎', 'Mobile & Tablets': '📱',
    'Pet Supplies': '🐾', 'Sports & Fitness': '⚽', 'Toys': '🧸', 'Travel': '✈️',
};

// ── Add Image Modal ───────────────────────────────────────────────────────────
const AddImageModal = ({ isOpen, onClose }) => {
    const [dragOver, setDragOver] = React.useState(false);
    const [preview, setPreview] = React.useState(null);
    const [fileName, setFileName] = React.useState('');
    const fileInputRef = React.useRef(null);

    React.useEffect(() => {
        if (!isOpen) { setPreview(null); setFileName(''); setDragOver(false); }
    }, [isOpen]);

    const handleFile = (file) => {
        if (!file || !file.type.startsWith('image/')) return;
        setFileName(file.name);
        const reader = new FileReader();
        reader.onload = (e) => setPreview(e.target.result);
        reader.readAsDataURL(file);
    };

    const handleDrop = (e) => {
        e.preventDefault(); setDragOver(false);
        const file = e.dataTransfer.files?.[0];
        if (file) handleFile(file);
    };

    const handlePickFile = React.useCallback(() => { fileInputRef.current?.click(); }, []);

    if (!isOpen) return null;

    return (
        <div className="fixed inset-0 z-[9999] flex items-end sm:items-center justify-center">
            {/* Backdrop */}
            <div className="absolute inset-0 bg-black/50 backdrop-blur-sm" onClick={onClose} />

            {/* Modal */}
            <div className="relative w-full sm:max-w-[420px] bg-white dark:bg-gray-900 rounded-t-3xl sm:rounded-2xl shadow-2xl flex flex-col overflow-hidden">
                {/* Drag handle */}
                <div className="flex justify-center pt-3 pb-1 sm:hidden">
                    <div className="w-10 h-1 rounded-full bg-gray-200 dark:bg-gray-700" />
                </div>

                {/* Header */}
                <div className="flex items-center justify-between px-5 pt-4 pb-3 border-b border-gray-100 dark:border-gray-800">
                    <h2 className="text-[15px] font-bold text-gray-900 dark:text-white tracking-tight">Add Photo</h2>
                    <button onClick={onClose}
                        className="w-8 h-8 flex items-center justify-center rounded-full bg-gray-100 dark:bg-gray-800 text-gray-500 dark:text-gray-400 hover:bg-gray-200 dark:hover:bg-gray-700 transition-colors text-sm font-semibold">
                        ✕
                    </button>
                </div>

                <div className="px-5 py-5 flex flex-col gap-4">
                    {/* Drop zone / preview */}
                    {preview ? (
                        <div className="relative rounded-2xl overflow-hidden border border-gray-200 dark:border-gray-700 bg-gray-50 dark:bg-gray-800">
                            <img src={preview} alt="preview" className="w-full max-h-56 object-cover" />
                            <button
                                onClick={() => { setPreview(null); setFileName(''); }}
                                className="absolute top-2 right-2 w-7 h-7 flex items-center justify-center rounded-full bg-black/60 text-white text-xs hover:bg-black/80 transition-colors">
                                ✕
                            </button>
                            <div className="px-3 py-2 bg-white dark:bg-gray-900 border-t border-gray-100 dark:border-gray-800">
                                <p className="text-xs text-gray-500 dark:text-gray-400 truncate">{fileName}</p>
                            </div>
                        </div>
                    ) : (
                        <div
                            onDragOver={(e) => { e.preventDefault(); setDragOver(true); }}
                            onDragLeave={() => setDragOver(false)}
                            onDrop={handleDrop}
                            onClick={() => fileInputRef.current?.click()}
                            className={`cursor-pointer rounded-2xl border-2 border-dashed flex flex-col items-center justify-center gap-3 py-10 transition-colors ${
                                dragOver
                                    ? 'border-gray-400 bg-gray-50 dark:bg-gray-800'
                                    : 'border-gray-200 dark:border-gray-700 hover:border-gray-400 dark:hover:border-gray-500 bg-gray-50/50 dark:bg-gray-800/40'
                            }`}>
                            {/* Photo icon */}
                            <div className="w-14 h-14 rounded-2xl bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 flex items-center justify-center shadow-sm">
                                <svg width="26" height="26" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" className="text-gray-400">
                                    <rect x="3" y="3" width="18" height="18" rx="3"/>
                                    <circle cx="8.5" cy="8.5" r="1.5"/>
                                    <polyline points="21 15 16 10 5 21"/>
                                </svg>
                            </div>
                            <div className="text-center">
                                <p className="text-sm font-semibold text-gray-700 dark:text-gray-300">
                                    {dragOver ? 'Drop it here' : 'Choose a photo'}
                                </p>
                                <p className="text-xs text-gray-400 dark:text-gray-500 mt-0.5">or drag and drop</p>
                            </div>
                            <span className="text-xs text-gray-400 dark:text-gray-600">PNG, JPG, WEBP · up to 10 MB</span>
                        </div>
                    )}

                    {/* Quick source buttons */}
                    {!preview && (
                        <div className="grid grid-cols-3 gap-2">
                            {[
                                { icon: '📁', label: 'Library', onFile: true },
                                { icon: '📷', label: 'Camera',  onFile: true },
                                { icon: '🔗', label: 'URL',     onFile: false },
                            ].map(({ icon, label, onFile }) => (
                                <button key={label} type="button" onClick={onFile ? handlePickFile : undefined}
                                    className="flex flex-col items-center gap-1.5 py-3 rounded-xl border border-gray-200 dark:border-gray-700 bg-white dark:bg-gray-800 hover:bg-gray-50 dark:hover:bg-gray-700 transition-colors">
                                    <span className="text-xl">{icon}</span>
                                    <span className="text-[11px] font-medium text-gray-600 dark:text-gray-400">{label}</span>
                                </button>
                            ))}
                        </div>
                    )}

                    {/* Hidden file input */}
                    <input ref={fileInputRef} type="file" accept="image/*" className="hidden"
                        onChange={(e) => { const f = e.target.files?.[0]; if (f) handleFile(f); e.target.value = ''; }} />

                    {/* Action buttons */}
                    <div className="flex gap-2.5 pt-1">
                        <button onClick={onClose}
                            className="flex-1 h-11 rounded-xl border border-gray-200 dark:border-gray-700 text-sm font-semibold text-gray-700 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors">
                            Cancel
                        </button>
                        <button disabled={!preview}
                            className="flex-1 h-11 rounded-xl bg-gray-900 dark:bg-white disabled:opacity-30 text-white dark:text-gray-900 text-sm font-bold transition-all hover:bg-gray-700 dark:hover:bg-gray-100">
                            Upload
                        </button>
                    </div>
                </div>
            </div>
        </div>
    );
};

// ── Interests Modal ───────────────────────────────────────────────────────────
const InterestsModal = ({ isOpen, onClose, currentInterests = [], categories = AD_CATEGORIES_FALLBACK, onSave, saving }) => {
    const [selected, setSelected] = React.useState([]);

    React.useEffect(() => {
        if (isOpen) setSelected(currentInterests);
    }, [isOpen, currentInterests]);

    const toggle = (cat) =>
        setSelected(prev =>
            prev.includes(cat) ? prev.filter(c => c !== cat) : [...prev, cat]
        );

    if (!isOpen) return null;

    return (
        <div className="fixed inset-0 z-[9999] flex items-end sm:items-center justify-center">
            {/* Backdrop */}
            <div className="absolute inset-0 bg-black/60 backdrop-blur-sm" onClick={onClose} />

            {/* Sheet */}
            <div className="relative w-full sm:max-w-md bg-white dark:bg-gray-950 rounded-t-3xl sm:rounded-2xl shadow-2xl flex flex-col max-h-[85vh] overflow-hidden">
                {/* Handle bar */}
                <div className="flex justify-center pt-3 pb-1 sm:hidden">
                    <div className="w-10 h-1 rounded-full bg-gray-300 dark:bg-gray-700" />
                </div>

                {/* Header */}
                <div className="flex items-center justify-between px-5 py-4 border-b border-gray-100 dark:border-gray-800">
                    <div>
                        <h2 className="text-base font-bold text-gray-900 dark:text-white flex items-center gap-2">
                            Your Interests
                            {saving && <Loader2 size={13} className="animate-spin text-orange-400" />}
                        </h2>
                        <p className="text-xs text-gray-400 mt-0.5">{selected.length} selected · tap to toggle</p>
                    </div>
                    <button onClick={onClose}
                        className="w-8 h-8 flex items-center justify-center rounded-full bg-gray-100 dark:bg-gray-800 text-gray-500 dark:text-gray-400 hover:bg-gray-200 dark:hover:bg-gray-700 transition-colors text-lg font-light">
                        ✕
                    </button>
                </div>

                {/* Categories grid */}
                <div className="flex-1 overflow-y-auto px-4 py-4">
                    <div className="grid grid-cols-2 gap-2.5">
                        {categories.map(cat => {
                            const active = selected.includes(cat);
                            return (
                                <button key={cat} type="button" onClick={() => toggle(cat)}
                                    className={`flex items-center gap-2.5 px-3 py-2.5 rounded-xl border text-left transition-all duration-150 ${
                                        active
                                            ? 'bg-orange-50 dark:bg-orange-900/20 border-orange-400 dark:border-orange-500'
                                            : 'bg-white dark:bg-gray-900 border-gray-200 dark:border-gray-700 hover:border-gray-400 dark:hover:border-gray-500'
                                    }`}>
                                    <span className="text-xl leading-none">{CATEGORY_EMOJI[cat] || '🏷️'}</span>
                                    <span className={`text-xs font-medium leading-tight ${active ? 'text-orange-600 dark:text-orange-400' : 'text-gray-700 dark:text-gray-300'}`}>
                                        {cat}
                                    </span>
                                    {active && (
                                        <span className="ml-auto text-orange-500 text-xs font-bold">✓</span>
                                    )}
                                </button>
                            );
                        })}
                    </div>
                </div>

                {/* Footer */}
                <div className="px-4 py-4 border-t border-gray-100 dark:border-gray-800 flex gap-3">
                    <button onClick={onClose}
                        className="flex-1 h-11 rounded-xl border border-gray-200 dark:border-gray-700 text-sm font-semibold text-gray-700 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors">
                        Cancel
                    </button>
                    <button onClick={() => onSave(selected)} disabled={saving}
                        className="flex-1 h-11 rounded-xl bg-orange-500 hover:bg-orange-600 disabled:opacity-60 text-white text-sm font-bold transition-colors flex items-center justify-center gap-2">
                        {saving && <Loader2 size={15} className="animate-spin" />}
                        {saving ? 'Saving…' : 'Save Interests'}
                    </button>
                </div>
            </div>
        </div>
    );
};

const InterestedSection = ({ isDesktop = false, interests = [], isOwnProfile = false, onAdd }) => {
    const scrollRef = useRef(null);

    const scroll = (direction) => {
        if (scrollRef.current) {
            const { scrollLeft, clientWidth } = scrollRef.current;
            const scrollTo = direction === 'left' ? scrollLeft - clientWidth / 1.5 : scrollLeft + clientWidth / 1.5;
            scrollRef.current.scrollTo({ left: scrollTo, behavior: 'smooth' });
        }
    };

    if (interests.length === 0) {
        return (
            <div className="w-full py-4 text-center">
                <p className="text-sm text-gray-500 dark:text-gray-400 font-medium italic">No interests listed yet.</p>
            </div>
        );
    }

    return (
        <div className="w-full max-w-full overflow-hidden">
            <div className="mb-2.5 flex items-center justify-between">
                <div className="text-[13px] font-bold tracking-tight text-gray-900 dark:text-white">
                    Interested Section
                </div>
                <div className="flex items-center gap-1">
                    {isOwnProfile && onAdd && (
                        <button
                            type="button"
                            onClick={onAdd}
                            className="inline-flex h-6 w-6 items-center justify-center rounded-full bg-blue-500 hover:bg-blue-600 text-white transition shadow-sm"
                            aria-label="Add interest"
                        >
                            <Plus size={12} />
                        </button>
                    )}
                    <button
                        type="button"
                        onClick={() => scroll('left')}
                        className="inline-flex h-6 w-6 items-center justify-center rounded-full bg-gray-100 dark:bg-gray-800 text-gray-900 dark:text-white transition hover:bg-gray-200 dark:hover:bg-gray-700 shadow-sm"
                        aria-label="Previous"
                    >
                        <ChevronLeft size={12} />
                    </button>
                    <button
                        type="button"
                        onClick={() => scroll('right')}
                        className="inline-flex h-6 w-6 items-center justify-center rounded-full bg-gray-100 dark:bg-gray-800 text-gray-900 dark:text-white transition hover:bg-gray-200 dark:hover:bg-gray-700 shadow-sm"
                        aria-label="Next"
                    >
                        <ChevronRight size={12} />
                    </button>
                </div>
            </div>

            <div 
                ref={scrollRef}
                className="flex gap-2 overflow-x-auto scrollbar-none pb-0.5"
                style={{ WebkitOverflowScrolling: 'touch', scrollbarWidth: 'none', msOverflowStyle: 'none' }}
            >
                {interests.map((interest) => {
                    const img = getCategoryImage(interest);
                    return (
                        <div key={interest} className="flex-shrink-0 w-[115px] sm:w-[135px] aspect-[16/9] relative rounded-lg overflow-hidden shadow-sm group border border-gray-100 dark:border-gray-800">
                            {img ? (
                                <img src={img} alt={interest} className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-500" />
                            ) : (
                                <div className="w-full h-full bg-gray-100 dark:bg-gray-900 flex items-center justify-center">
                                    <span className="text-lg">🏷️</span>
                                </div>
                            )}
                            <div className="absolute inset-0 bg-gradient-to-t from-black/85 via-black/20 to-transparent flex items-end p-2">
                                <span className="text-white text-[9px] font-bold truncate leading-tight italic tracking-tight">{interest}</span>
                            </div>
                        </div>
                    );
                })}
            </div>
            <style>{`
                .scrollbar-none::-webkit-scrollbar { display: none; }
            `}</style>
        </div>
    );
};

// ── Profile ───────────────────────────────────────────────────────────────────
const Profile = () => {
    const navigate = useNavigate();
    const dispatch = useDispatch();
    const { userId } = useParams();
    const { userObject: currentUser } = useSelector((state) => state.auth);
    const walletBalance = useSelector((state) => state.wallet?.balance ?? 0);

    const [profileUser, setProfileUser] = useState(null);
    const isOwnProfile = !userId || (currentUser && (userId === currentUser.id || userId === currentUser._id));

    const [activeTab, setActiveTab] = useState(null);
    const [userPosts, setUserPosts] = useState([]);
    const [userTweets, setUserTweets] = useState([]);
    const [userPromoteReels, setUserPromoteReels] = useState([]);
    const [loadingPosts, setLoadingPosts] = useState(true);
    const [selectedPost, setSelectedPost] = useState(null);
    const [selectedTweet, setSelectedTweet] = useState(null);
    const [selectedPromoteReel, setSelectedPromoteReel] = useState(null);
    const [selectedAd, setSelectedAd] = useState(null);
    const [showAvatarModal, setShowAvatarModal] = useState(false);
    const [showInterestsModal, setShowInterestsModal] = useState(false);
    const [savingInterests, setSavingInterests] = useState(false);
    const [userInterests, setUserInterests] = useState([]);
    const [availableCategories, setAvailableCategories] = useState(AD_CATEGORIES_FALLBACK);
    const [loadingInterests, setLoadingInterests] = useState(false);
    const [showAddImageModal, setShowAddImageModal] = useState(false);
    const [showInterestsSection, setShowInterestsSection] = useState(false);

    const [userAds, setUserAds] = useState([]);
    const [loadingAds, setLoadingAds] = useState(false);

    // Follow state: null = unknown, 'following', 'requested', 'not_following'
    const [followState, setFollowState] = useState('not_following');
    const [followLoading, setFollowLoading] = useState(false);
    const [messageLoading, setMessageLoading] = useState(false);
    const [vendorInfo, setVendorInfo] = useState(null);
    const [rewardToast, setRewardToast] = useState(null);
    const [followersModalOpen, setFollowersModalOpen] = useState(false);
    const [followingModalOpen, setFollowingModalOpen] = useState(false);
    const [showUserOptionsMenu, setShowUserOptionsMenu] = useState(false);
    const [showStoryViewer, setShowStoryViewer] = useState(false);
    const profileStory = useSelector((state) => state.story?.storyMap?.[profileUser?._id || profileUser?.id]);
    const [notificationEnabled, setNotificationEnabled] = useState(false);
    const [notifLoading, setNotifLoading] = useState(false);
    const [isBioExpanded, setIsBioExpanded] = useState(false);
    const userOptionsMenuRef = useRef(null);

    // Close user options menu when clicking outside
    useEffect(() => {
        if (!showUserOptionsMenu) return;
        const handler = (e) => {
            if (userOptionsMenuRef.current && !userOptionsMenuRef.current.contains(e.target)) {
                setShowUserOptionsMenu(false);
            }
        };
        document.addEventListener('mousedown', handler);
        return () => document.removeEventListener('mousedown', handler);
    }, [showUserOptionsMenu]);

    const profileRewardMsRef = useRef(0);
    const profileRewardTickRef = useRef(null);
    const profileRewardSentRef = useRef(false);

    const onlyPosts = userPosts.filter(p => p.type !== 'reel');
    const onlyReels = userPosts.filter(p => p.type === 'reel');
    const displayedPosts =
        activeTab === 'reels' ? onlyReels :
        activeTab === 'posts' ? onlyPosts :
        activeTab === 'tweets' ? [] :
        activeTab === 'promote_reels' ? [] :
        userPosts;
    const profileTargetUserId = profileUser?._id || profileUser?.id || userId || '';

    // Derived: is the profile private and content hidden from current user?
    const isProfilePrivate = Boolean(profileUser?.isPrivate);
    const isFollowing = followState === 'following';
    const contentLocked = isProfilePrivate && !isOwnProfile && !isFollowing;

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

    // ── Fetch story for this profile ────────────────────────────────────────
    useEffect(() => {
        if (!profileUser) return;
        const uid = profileUser._id || profileUser.id;
        if (!uid) return;
        dispatch(fetchUserStory(uid, {
            avatarUrl: profileUser.avatar_url || '',
            username: profileUser.username || profileUser.full_name || '',
        }));
    }, [profileUser, dispatch]);

    // ── Fetch notification preference status ────────────────────────────────
    useEffect(() => {
        if (!profileTargetUserId || isOwnProfile) return;

        const fetchNotifStatus = async () => {
            try {
                const res = await api.get(`/notification-preferences/users/${profileTargetUserId}/status`);
                setNotificationEnabled(res.data?.enabled || false);
            } catch (err) {
                console.error('Error fetching notification status:', err);
            }
        };
        fetchNotifStatus();
    }, [profileTargetUserId, isOwnProfile]);

    const handleToggleNotifications = async () => {
        if (!profileTargetUserId || notifLoading) return;
        setNotifLoading(true);
        try {
            const res = await api.post(`/notification-preferences/users/${profileTargetUserId}/toggle`);
            setNotificationEnabled(res.data?.enabled || false);
            setRewardToast({
                type: 'success',
                message: `Notifications turned ${res.data?.enabled ? 'on' : 'off'} for this user.`,
            });
        } catch (err) {
            console.error('Error toggling notifications:', err);
            setRewardToast({
                type: 'error',
                message: 'Failed to update notification settings.',
            });
        } finally {
            setNotifLoading(false);
            setShowUserOptionsMenu(false);
        }
    };

    // Set default tab based on role
    useEffect(() => {
        if (profileUser) {
            setActiveTab(profileUser.role === 'vendor' ? 'ads' : 'all');
        }
    }, [profileUser?.role]);

    // Fetch interests from dedicated API endpoint
    useEffect(() => {
        const fetchInterests = async () => {
            const profileUserId = profileUser?._id || profileUser?.id;
            if (!profileUserId) return;
            try {
                setLoadingInterests(true);
                const { data } = await api.get(`/users/${profileUserId}/interests`);
                setUserInterests(data.ad_interests || []);
                if (Array.isArray(data.available_categories) && data.available_categories.length > 0) {
                    setAvailableCategories(data.available_categories);
                }
            } catch (err) {
                console.error('[Profile] Failed to fetch interests:', err);
                // Fallback: use ad_interests from profileUser if already loaded
                setUserInterests(profileUser?.ad_interests || []);
            } finally {
                setLoadingInterests(false);
            }
        };
        fetchInterests();
    }, [profileUser?._id, profileUser?.id]);

    const handleSaveInterests = async (selected) => {
        setSavingInterests(true);
        try {
            const userId = profileUser?._id || profileUser?.id;
            const { data } = await api.post(`/users/${userId}/interests`, { interests: selected });
            // API returns updated ad_interests
            setUserInterests(data.ad_interests || selected);
            if (Array.isArray(data.available_categories) && data.available_categories.length > 0) {
                setAvailableCategories(data.available_categories);
            }
            setShowInterestsModal(false);
        } catch (err) {
            console.error('Failed to save interests:', err);
            alert(err?.response?.data?.message || 'Failed to save interests. Please try again.');
        } finally {
            setSavingInterests(false);
        }
    };

    const handleStarClick = async () => {
        if (showInterestsSection) {
            setShowInterestsSection(false);
            return;
        }

        const profileUserId = profileUser?._id || profileUser?.id;
        if (!profileUserId) return;

        try {
            setLoadingInterests(true);
            const { data } = await api.get(`/users/${profileUserId}/interests`);
            setUserInterests(data.ad_interests || []);
            if (Array.isArray(data.available_categories) && data.available_categories.length > 0) {
                setAvailableCategories(data.available_categories);
            }
            setShowInterestsSection(true);
        } catch (err) {
            console.error('[Profile] Failed to fetch interests:', err);
            setShowInterestsSection(true);
        } finally {
            setLoadingInterests(false);
        }
    };

    useEffect(() => {
        const fetchPosts = async () => {
            const profileUserId = profileUser?._id || profileUser?.id;
            if (!profileUserId) return;
            if (contentLocked) { setLoadingPosts(false); return; }
            try {
                setLoadingPosts(true);
                const response = await api.get(`/users/${profileUserId}/posts`);
                const data = response.data || {};
                // New API returns { posts, promote_reels, tweets }
                if (data.posts !== undefined) {
                    setUserPosts(data.posts || []);
                    setUserTweets(data.tweets || []);
                    setUserPromoteReels(data.promote_reels || []);
                } else {
                    // Fallback: old flat array format
                    setUserPosts(Array.isArray(data) ? data : []);
                }
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
    }, [profileUser, contentLocked]);

    // ── Fetch ads (for vendor profiles) ────────────────────────────────────
    const fetchAds = useCallback(async () => {
        const profileUserId = profileUser?._id || profileUser?.id;
        if (!profileUserId || profileUser?.role !== 'vendor') return;
        setLoadingAds(true);
        try {
            let list = [];
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

    useEffect(() => {
        if (profileUser?.role === 'vendor' && activeTab === 'ads' && userAds.length === 0) {
            fetchAds();
        }
    }, [activeTab, profileUser, fetchAds, userAds.length]);

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

    // ── Follow status: also detect 'requested' state ────────────────────────
    useEffect(() => {
        if (!profileTargetUserId || isOwnProfile) {
            setFollowState('not_following');
            return;
        }

        const loadFollowStatus = async () => {
            try {
                const status = await checkFollowStatus(profileTargetUserId);
                if (status?.isFollowing || status?.status === 'following') {
                    setFollowState('following');
                } else if (
                    status?.isPending
                    || status?.requestPending
                    || status?.requested
                    || status?.status === 'pending'
                ) {
                    setFollowState('requested');
                } else {
                    setFollowState('not_following');
                }
            } catch (error) {
                console.error('Error checking follow status:', error);
                setFollowState('not_following');
            }
        };

        loadFollowStatus();
    }, [isOwnProfile, profileTargetUserId]);

    useEffect(() => {
        if (!profileTargetUserId || isOwnProfile) return undefined;
        const onFollowStatusChanged = (event) => {
            const detail = event?.detail || {};
            if (String(detail.userId || '') !== String(profileTargetUserId)) return;
            if (detail.state === 'following' || detail.state === 'requested' || detail.state === 'not_following') {
                setFollowState(detail.state);
            }
        };
        window.addEventListener(FOLLOW_STATUS_CHANGED_EVENT, onFollowStatusChanged);
        return () => window.removeEventListener(FOLLOW_STATUS_CHANGED_EVENT, onFollowStatusChanged);
    }, [isOwnProfile, profileTargetUserId]);

    const refreshProfileFollowCounts = useCallback(async () => {
        if (!profileTargetUserId) return;
        try {
            const counts = await getFollowCounts(profileTargetUserId);
            setProfileUser((prev) => (
                prev
                    ? {
                        ...prev,
                        followers_count: Number(counts?.followers_count ?? prev.followers_count ?? 0),
                        following_count: Number(counts?.following_count ?? prev.following_count ?? 0),
                    }
                    : prev
            ));
        } catch (error) {
            console.error('Error refreshing follow counts:', error);
        }
    }, [profileTargetUserId]);

    // ── Follow / Unfollow / Request / Cancel ──────────────────────────────
    const handleFollow = async () => {
        if (followLoading) return;
        if (!profileTargetUserId || isOwnProfile) return;
        setFollowLoading(true);
        const prev = followState;
        try {
            if (followState === 'following') {
                await unfollowUser(profileTargetUserId);
                setFollowState('not_following');
                await refreshProfileFollowCounts();
            } else if (followState === 'requested') {
                // Cancel the pending follow request
                await cancelFollowRequest(profileTargetUserId);
                setFollowState('not_following');
            } else {
                // Send follow (may return pending if account is private)
                const result = await followUser(profileTargetUserId);
                if (
                    result?.status === 'pending'
                    || result?.pending
                    || result?.requested
                    || result?.requestPending
                    || result?.isPending
                ) {
                    setFollowState('requested');
                } else {
                    setFollowState('following');
                    await refreshProfileFollowCounts();
                }
            }
        } catch (error) {
            console.error('Error updating follow status:', error);
            setFollowState(prev);
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

    const getAdThumbnail = (ad) => {
        const m = ad.media?.[0];
        if (!m) return null;
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

    const handleShareProfile = async () => {
        const slug = profileUser?._id || profileUser?.id || 'profile';
        const shareUrl = `${window.location.origin}/profile/${slug}`;

        try {
            if (navigator.share) {
                await navigator.share({
                    title: profileUser.full_name || profileUser.username,
                    text: `Check out ${profileUser.username} on B-Smart`,
                    url: shareUrl,
                });
                return;
            }
        } catch {
            return;
        }

        try {
            await navigator.clipboard.writeText(shareUrl);
            setRewardToast({
                type: 'success',
                message: 'Profile link copied to clipboard.',
            });
        } catch {
            setRewardToast({
                type: 'error',
                message: 'Unable to copy profile link.',
            });
        }
    };

    const handleOpenMessages = async () => {
        if (messageLoading) return;

        if (isOwnProfile) {
            navigate('/messages');
            return;
        }

        const participantId = profileUser?._id || profileUser?.id;
        if (!participantId) return;

        setMessageLoading(true);
        try {
            const conversation = await createOrGetConversation(participantId);
            if (conversation?._id) {
                navigate(`/messages/${conversation._id}`, { state: { conversation } });
            } else {
                navigate('/messages');
            }
        } catch (error) {
            console.error('Failed to open conversation:', error);
            navigate('/messages');
        } finally {
            setMessageLoading(false);
        }
    };

    if (!profileUser) {
        return (
            <div className="min-h-screen flex items-center justify-center bg-gray-50 dark:bg-black">
                <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-orange-500" />
            </div>
        );
    }

    // ── Follow button label & style ──────────────────────────────────────────
    const getFollowButtonLabel = () => {
        if (followLoading) return <Loader2 size={14} className="animate-spin" />;
        if (followState === 'following') {
            // Check if they follow back — show "Follow Back" label on their profile when they follow you
            if (profileUser?.followsYouBack) return 'Following';
            return 'Following';
        }
        if (followState === 'requested') return 'Requested';
        // If they follow you but you don't follow them: "Follow Back"
        if (profileUser?.isFollowingYou) return 'Follow Back';
        return 'Follow';
    };

    const getFollowButtonClass = (size = 'md') => {
        const base = size === 'md'
            ? 'px-6 py-2 text-sm font-bold rounded-xl flex items-center justify-center gap-1 transition-all'
            : 'px-10 py-2.5 text-sm font-bold rounded-xl flex items-center gap-1.5 transition-all';

        if (followState === 'requested') {
            return `${base} bg-gray-100 dark:bg-gray-800 text-gray-700 dark:text-gray-200 border border-gray-200 dark:border-gray-700`;
        }
        if (followState === 'following') {
            return `${base} bg-gray-100 dark:bg-gray-800 text-gray-700 dark:text-gray-200 border border-gray-200 dark:border-gray-700`;
        }
        return `${base} bg-gradient-to-r from-orange-500 to-pink-500 text-white shadow-md shadow-pink-500/20 hover:opacity-90 disabled:opacity-60`;
    };

    const VerifiedBadge = () => (
        <svg viewBox="0 0 24 24" fill="currentColor" className="w-5 h-5 text-blue-500 flex-shrink-0">
            <path fillRule="evenodd" d="M8.603 3.799A4.49 4.49 0 0112 2.25c1.357 0 2.573.6 3.397 1.549a4.49 4.49 0 013.498 1.307 4.491 4.491 0 011.307 3.497A4.49 4.49 0 0121.75 12a4.49 4.49 0 01-1.549 3.397 4.491 4.491 0 01-1.307 3.498 4.491 4.491 0 01-3.497 1.307A4.49 4.49 0 0112 21.75a4.49 4.49 0 01-3.397-1.549 4.49 4.49 0 01-3.498-1.306 4.491 4.491 0 01-1.307-3.498A4.49 4.49 0 012.25 12c0-1.357.6-2.573 1.549-3.397a4.49 4.49 0 011.307-3.497 4.49 4.49 0 013.497-1.307zm7.007 6.387a.75.75 0 10-1.22-.872l-3.236 4.53L9.53 12.22a.75.75 0 00-1.06 1.06l2.25 2.25a.75.75 0 001.14-.094l3.75-5.25z" clipRule="evenodd" />
        </svg>
    );

    const ValidationStatusBadge = ({ validated, compact = false }) => (
        <span className={`inline-flex items-center rounded-full font-semibold ${
            compact ? 'px-2 py-0.5 text-[10px]' : 'px-2.5 py-1 text-[11px]'
        } ${
            validated
                ? 'bg-emerald-100 text-emerald-700 dark:bg-emerald-900/30 dark:text-emerald-400'
                : 'bg-amber-100 text-amber-700 dark:bg-amber-900/30 dark:text-amber-400'
        }`}>
            {validated ? 'Validated' : 'Not Validated'}
        </span>
    );

    const isVendor = profileUser.role === 'vendor';
    const vendorValidated = isVendor ? Boolean(profileUser?.validated ?? vendorInfo?.validated) : false;

    const tabConfig = isVendor
        ? [{ key: 'ads', label: 'Ads', icon: <Megaphone size={22} /> }]
        : [
            { key: 'all',            label: 'All',       icon: <Grid size={22} /> },
            { key: 'posts',          label: 'Posts',     icon: <Image size={22} /> },
            { key: 'reels',          label: 'Reels',     icon: <Video size={22} /> },
            { key: 'tweets',         label: 'Tweets',    icon: <MessageCircle size={22} /> },
            { key: 'promote_reels',  label: 'Promoted',  icon: <Megaphone size={22} /> },
          ];

    // ── Private Profile Wall ──────────────────────────────────────────────────
    const PrivateProfileWall = () => (
        <div className="flex flex-col items-center justify-center py-16 px-8 text-center bg-white dark:bg-black">
            <div className="w-16 h-16 rounded-full border-2 border-gray-300 dark:border-gray-600 flex items-center justify-center mb-4">
                <Lock size={28} className="text-gray-400 dark:text-gray-500" />
            </div>
            <h3 className="font-semibold text-base text-gray-900 dark:text-white mb-1">This profile is private</h3>
            <p className="text-sm text-gray-500 dark:text-gray-400">Follow to see their photos and videos.</p>
        </div>
    );

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
        if (contentLocked) return <PrivateProfileWall />;
        if (activeTab === 'ads') return <AdsGrid />;
        if (activeTab === 'tweets') return <TweetsGrid />;
        if (activeTab === 'promote_reels') return <PromoteReelsGrid />;
        return <PostGrid />;
    };
    const renderContentMobile = () => {
        if (activeTab === null) return null;
        if (contentLocked) return <PrivateProfileWall />;
        if (activeTab === 'ads') return <AdsGrid containerClass="" />;
        if (activeTab === 'tweets') return <TweetsGrid containerClass="" />;
        if (activeTab === 'promote_reels') return <PromoteReelsGrid containerClass="" />;
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
                            : activeTab === 'tweets'
                            ? <MessageCircle size={30} className="text-gray-300 dark:text-gray-600" />
                            : <Grid size={30} className="text-gray-300 dark:text-gray-600" />}
                    </div>
                    <h3 className="font-semibold text-base text-gray-900 dark:text-white mb-1">
                        {activeTab === 'reels' ? 'No Reels Yet' : activeTab === 'tweets' ? 'No Tweets Yet' : 'No Posts Yet'}
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


    // ── Tweets Grid ────────────────────────────────────────────────────────────────────────────────
    const TweetsGrid = ({ containerClass = '' }) => (
        <div className={`${containerClass}`}>
            {loadingPosts ? (
                <div className="flex flex-col items-center py-16 gap-3 bg-white dark:bg-black">
                    <Loader2 className="w-7 h-7 animate-spin text-orange-500" />
                    <span className="text-sm text-gray-400">Loading tweets…</span>
                </div>
            ) : userTweets.length === 0 ? (
                <div className="bg-white dark:bg-black py-14 text-center">
                    <div className="w-16 h-16 border-2 border-gray-300 dark:border-gray-600 rounded-full flex items-center justify-center mx-auto mb-4">
                        <MessageCircle size={30} className="text-gray-300 dark:text-gray-600" />
                    </div>
                    <h3 className="font-semibold text-base text-gray-900 dark:text-white mb-1">No Tweets Yet</h3>
                    {isOwnProfile && (
                        <Link to="/tweets" className="text-blue-500 text-sm font-semibold mt-1 inline-block">Create a tweet</Link>
                    )}
                </div>
            ) : (
                <div className="divide-y divide-gray-100 dark:divide-gray-800">
                    {userTweets.map((tweet) => {
                        const tweetId = tweet._id || tweet.id;
                        const mediaItems = Array.isArray(tweet.media) ? tweet.media : [];
                        return (
                            <div key={tweetId}
                                className="flex gap-3 px-4 py-3 bg-white dark:bg-black cursor-pointer hover:bg-gray-50 dark:hover:bg-gray-900/50 transition-colors"
                                onClick={() => setSelectedTweet(tweet)}>
                                {/* Avatar */}
                                <div className="flex-shrink-0 w-10 h-10 rounded-full overflow-hidden bg-gray-200 dark:bg-gray-700">
                                    {tweet.author?.avatar_url ? (
                                        <img src={tweet.author.avatar_url.startsWith('http') ? tweet.author.avatar_url : `${BASE_URL}/uploads/${tweet.author.avatar_url}`}
                                            alt="avatar" className="w-full h-full object-cover" />
                                    ) : (
                                        <div className="w-full h-full flex items-center justify-center text-gray-400 text-sm font-bold">
                                            {(tweet.author?.username || '?')[0].toUpperCase()}
                                        </div>
                                    )}
                                </div>
                                {/* Content */}
                                <div className="flex-1 min-w-0">
                                    <div className="flex items-center gap-1.5 mb-0.5">
                                        <span className="font-semibold text-sm text-gray-900 dark:text-white truncate">
                                            {tweet.author?.full_name || tweet.author?.username || 'User'}
                                        </span>
                                        <span className="text-xs text-gray-400 truncate">@{tweet.author?.username}</span>
                                    </div>
                                    {tweet.content && (
                                        <p className="text-sm text-gray-800 dark:text-gray-200 line-clamp-3 leading-relaxed mb-2">{tweet.content}</p>
                                    )}
                                    {/* Multi-image grid — 2 photos side by side, 3+ stacked */}
                                    {mediaItems.length > 0 && (
                                        <div onClick={e => e.stopPropagation()}>
                                            <TweetImageGallery
                                                mediaItems={mediaItems}
                                                onImageClick={() => setSelectedTweet(tweet)}
                                            />
                                        </div>
                                    )}
                                    <div className="flex items-center gap-4 text-xs text-gray-400 mt-2">
                                        <span className="flex items-center gap-1"><Heart size={13} /> {tweet.likesCount || 0}</span>
                                        <span className="flex items-center gap-1"><MessageCircle size={13} /> {tweet.repliesCount || tweet.commentsCount || 0}</span>
                                        <span className="flex items-center gap-1"><Eye size={13} /> {tweet.viewsCount || 0}</span>
                                    </div>
                                </div>
                            </div>
                        );
                    })}
                </div>
            )}
        </div>
    );

    // ── Promote Reels Grid ─────────────────────────────────────────────────────────────────────────────
    const PromoteReelsGrid = ({ containerClass = '' }) => (
        <div className={`${containerClass}`}>
            {loadingPosts ? (
                <div className="flex flex-col items-center py-16 gap-3 bg-white dark:bg-black">
                    <Loader2 className="w-7 h-7 animate-spin text-orange-500" />
                    <span className="text-sm text-gray-400">Loading promoted reels…</span>
                </div>
            ) : userPromoteReels.length === 0 ? (
                <div className="bg-white dark:bg-black py-14 text-center">
                    <div className="w-16 h-16 border-2 border-gray-300 dark:border-gray-600 rounded-full flex items-center justify-center mx-auto mb-4">
                        <Megaphone size={30} className="text-gray-300 dark:text-gray-600" />
                    </div>
                    <h3 className="font-semibold text-base text-gray-900 dark:text-white mb-1">No Promoted Reels Yet</h3>
                    {isOwnProfile && (
                        <Link to="/promote" className="text-blue-500 text-sm font-semibold mt-1 inline-block">Promote now</Link>
                    )}
                </div>
            ) : (
                <div className="grid grid-cols-3 gap-[1px] bg-gray-200 dark:bg-gray-800">
                    {userPromoteReels.map((reel) => {
                        const reelId = reel._id || reel.id;
                        const firstMedia = reel.media?.[0];
                        const thumbFile = firstMedia?.thumbnail?.fileName || firstMedia?.thumbnails?.[0]?.fileName || firstMedia?.fileName;
                        const thumbUrl = thumbFile
                            ? (thumbFile.startsWith('http') ? thumbFile : `${BASE_URL}/uploads/${thumbFile}`)
                            : null;
                        const isVideo = firstMedia?.type === 'video';
                        return (
                            <div key={reelId}
                                className="aspect-square bg-gray-100 dark:bg-gray-900 relative group cursor-pointer overflow-hidden"
                                onClick={() => setSelectedPromoteReel(reel)}>
                                <div className="absolute top-1.5 left-1.5 z-10">
                                    <span className="text-[9px] font-bold bg-purple-500 text-white px-1.5 py-0.5 rounded-full">PROMO</span>
                                </div>
                                {isVideo && (
                                    <div className="absolute top-1.5 right-1.5 z-10">
                                        <Play size={15} className="text-white drop-shadow" fill="white" />
                                    </div>
                                )}
                                {thumbUrl ? (
                                    <img src={thumbUrl} alt={reel.caption || 'Promoted Reel'}
                                        className="w-full h-full object-cover group-hover:scale-[1.03] transition-transform duration-200" />
                                ) : (
                                    <div className="w-full h-full flex items-center justify-center bg-gradient-to-br from-purple-100 to-pink-100 dark:from-gray-800 dark:to-gray-700">
                                        <Megaphone size={28} className="text-purple-400 dark:text-gray-500" />
                                    </div>
                                )}
                                <div className="absolute inset-0 bg-black/40 opacity-0 group-hover:opacity-100 transition-opacity hidden md:flex items-center justify-center gap-4 text-white font-bold">
                                    <div className="flex items-center gap-1.5"><Heart fill="white" size={16}/> {fmt(reel.likes_count || 0)}</div>
                                    <div className="flex items-center gap-1.5"><Eye size={16}/> {fmt(reel.views_count || 0)}</div>
                                </div>
                            </div>
                        );
                    })}
                </div>
            )}
        </div>
    );

    // ── Follower mutual avatars (small stack shown under username) ────────────
    const MutualFollowers = () => {
        if (!profileUser?.mutual_followers?.length) return null;
        const shown = profileUser.mutual_followers.slice(0, 3);
        const extra = profileUser.mutual_followers_count - shown.length;
        return (
            <div className="flex items-center gap-2 mt-2 mb-1">
                <div className="flex -space-x-2">
                    {shown.map((f, i) => (
                        <div key={i} className="w-5 h-5 rounded-full border-2 border-white dark:border-black overflow-hidden bg-gray-200">
                            {f.avatar_url
                                ? <img src={f.avatar_url} alt="" className="w-full h-full object-cover" />
                                : <div className="w-full h-full bg-gradient-to-br from-orange-300 to-pink-400" />}
                        </div>
                    ))}
                </div>
                <p className="text-xs text-gray-500 dark:text-gray-400">
                    Followed by{' '}
                    {shown.map((f, i) => (
                        <span key={i}>
                            <span className="font-semibold text-gray-700 dark:text-gray-300">{f.username}</span>
                            {i < shown.length - 1 ? ', ' : ''}
                        </span>
                    ))}
                    {extra > 0 && ` and ${extra} more`}
                </p>
            </div>
        );
    };

    return (
        <div className="min-h-screen bg-white dark:bg-black md:bg-gray-50 md:dark:bg-black overflow-x-hidden">
            {rewardToast && (
                <div className={`fixed top-20 right-4 z-[80] rounded-xl border px-4 py-3 text-sm font-semibold shadow-lg animate-in fade-in slide-in-from-right-4 duration-300 ${
                    rewardToast.type === 'success'
                        ? 'border-green-200 bg-green-50 text-green-700 dark:border-green-800 dark:bg-green-900/20 dark:text-green-400'
                        : 'border-red-200 bg-red-50 text-red-700 dark:border-red-800 dark:bg-red-900/20 dark:text-red-400'
                }`}>
                    {rewardToast.message}
                </div>
            )}

            {/* MOBILE */}
            <div className="md:hidden flex flex-col h-[calc(120vh-60px)]">

                <div className="flex-shrink-0 bg-white dark:bg-black">
                    <div className="bg-white/95 dark:bg-black/95 backdrop-blur-sm border-b border-gray-100 dark:border-gray-800 px-4 py-3 flex justify-between items-center">
                        <div className="flex items-center gap-1 min-w-0">
                            <button onClick={() => navigate('/')} className="mr-2 flex-shrink-0">
                                <ArrowLeft size={24} className="text-gray-900 dark:text-white" />
                            </button>
                            <h1 className="truncate text-[18px] font-semibold text-gray-900 dark:text-white">
                                {profileUser.username}
                            </h1>
                            {isVendor && vendorValidated && <VerifiedBadge />}
                        </div>
                        {isOwnProfile && (
                            <div className="flex items-center gap-3 text-gray-900 dark:text-white">
                                <Link to="/create" aria-label="Create"><Plus size={22} /></Link>
                                <Link to="/settings" aria-label="Settings"><Settings size={22} /></Link>
                            </div>
                        )}
                    </div>

                    <div className="px-4 pt-3 pb-2">
                        {/* Avatar + Stats row */}
                        <div className="mb-3 flex items-center gap-4">
                            <div className="relative flex-shrink-0">
                                {/* Orange gradient ring when user has a story */}
                                <div
                                    className={`rounded-full p-[2.5px] ${profileStory ? 'bg-gradient-to-tr from-yellow-400 via-orange-500 to-pink-600' : 'bg-transparent'}`}
                                    onClick={profileStory ? () => setShowStoryViewer(true) : undefined}
                                    style={{ cursor: profileStory ? 'pointer' : 'default' }}
                                >
                                    <div className={`rounded-full p-[2px] ${profileStory ? 'bg-white dark:bg-black' : ''}`}>
                                        <div className="h-[82px] w-[82px] overflow-hidden rounded-full" style={{boxShadow:'0 4px 20px rgba(0,0,0,0.18)'}}>
                                            {profileUser.avatar_url ? (
                                                <img src={profileUser.avatar_url} alt={profileUser.username} className="h-full w-full rounded-full object-cover" />
                                            ) : (
                                                <div className="flex h-full w-full items-center justify-center rounded-full bg-gradient-to-br from-gray-200 to-gray-300 text-xl font-bold text-gray-600 dark:from-gray-700 dark:to-gray-800 dark:text-gray-300">
                                                    {getInitials(profileUser.full_name || profileUser.username)}
                                                </div>
                                            )}
                                        </div>
                                    </div>
                                </div>
                                {isOwnProfile && (
                                    <button
                                        type="button"
                                        onClick={() => setShowAvatarModal(true)}
                                        className="absolute bottom-0 right-0 flex h-6 w-6 items-center justify-center rounded-full border-2 border-white bg-blue-500 text-white shadow dark:border-black"
                                    >
                                        <Plus size={12} strokeWidth={3} />
                                    </button>
                                )}
                            </div>

                            <div className="grid flex-1 grid-cols-3 gap-2 text-center">
                                {[
                                    { val: profileUser.posts_count ?? userPosts.length, label: 'posts' },
                                    { val: profileUser.followers_count || 0, label: 'followers' },
                                    { val: profileUser.following_count || 0, label: 'following' },
                                ].map(({ val, label }) => {
                                    const isFollowers = label === 'followers';
                                    const isFollowingStat = label === 'following';
                                    const handleClick = isFollowers
                                        ? () => setFollowersModalOpen(true)
                                        : isFollowingStat
                                            ? () => setFollowingModalOpen(true)
                                            : undefined;
                                    const content = (
                                        <>
                                            <div className="text-[28px] font-semibold leading-none text-gray-900 dark:text-white">{fmt(val)}</div>
                                            <div className="mt-1 text-[12px] font-medium text-gray-500 dark:text-gray-400">{label}</div>
                                        </>
                                    );
                                    return handleClick ? (
                                        <button key={label} type="button" onClick={handleClick} className="rounded-lg py-1 transition hover:bg-gray-50 dark:hover:bg-gray-900">
                                            {content}
                                        </button>
                                    ) : (
                                        <div key={label} className="rounded-lg py-1">{content}</div>
                                    );
                                })}
                            </div>
                        </div>

                        <div className="mb-3 min-w-0">
                            <div className="text-[18px] font-semibold leading-tight text-gray-900 dark:text-white">{profileUser.full_name || profileUser.username}</div>
                            {profileUser.bio && (
                                <div className="mt-0.5">
                                    <div className={`text-sm text-gray-700 dark:text-gray-300 whitespace-pre-wrap leading-relaxed ${!isBioExpanded ? 'line-clamp-1' : ''}`}>
                                        {profileUser.bio}
                                    </div>
                                    {profileUser.bio.includes('\n') || profileUser.bio.length > 40 ? (
                                        <button
                                            onClick={() => setIsBioExpanded(!isBioExpanded)}
                                            className="mt-0.5 text-[12px] font-bold text-gray-500 hover:underline dark:text-gray-400"
                                        >
                                            {isBioExpanded ? 'Show less' : 'Read more'}
                                        </button>
                                    ) : null}
                                </div>
                            )}
                            <MutualFollowers />
                        </div>

                        {/* Actions row — full width spread */}
                        <div className="mb-4 flex items-center gap-2 w-full">
                                    {isOwnProfile ? (
                                        <>
                                            <Link to="/edit-profile" className="basis-[40%] shrink-0 h-9 inline-flex items-center justify-center bg-gradient-to-r from-orange-400 via-orange-500 to-pink-600 text-white text-sm font-bold rounded-xl shadow-md hover:opacity-95 transition-opacity">
                                                Edit profile
                                            </Link>
                                            <button type="button" onClick={handleShareProfile} className="flex-1 h-9 flex items-center justify-center rounded-xl border border-gray-200 dark:border-gray-800 bg-white dark:bg-black text-gray-900 dark:text-white shadow-sm" aria-label="Share profile">
                                                <Share2 size={18} />
                                            </button>
                                            <button type="button" onClick={handleStarClick}
                                                className={`flex-1 h-9 flex items-center justify-center rounded-xl border shadow-sm transition-all ${showInterestsSection ? 'border-orange-300 bg-orange-50 text-orange-500 dark:border-orange-900/20 dark:text-orange-400' : 'border-gray-200 dark:border-gray-800 bg-white dark:bg-black text-gray-900 dark:text-white'}`}
                                                aria-label="View interests">
                                                <Star size={18} fill={showInterestsSection ? 'currentColor' : 'none'} />
                                            </button>
                                            <button type="button" onClick={handleOpenMessages} className="flex-1 h-9 flex items-center justify-center rounded-xl border border-gray-200 dark:border-gray-800 bg-white dark:bg-black text-gray-900 dark:text-white shadow-sm" aria-label="Chat">
                                                <MessageCircle size={18} />
                                            </button>
                                        </>
                                    ) : (
                                        <>
                                            <button onClick={handleFollow} disabled={followLoading}
                                                className={`basis-[40%] shrink-0 h-9 px-4 text-sm font-bold rounded-xl flex items-center justify-center gap-1 transition-all ${followState === 'following' || followState === 'requested' ? 'bg-gray-100 dark:bg-gray-800 text-gray-700 dark:text-gray-200 border border-gray-200 dark:border-gray-700' : 'bg-gradient-to-r from-orange-500 to-pink-500 text-white shadow-md'}`}>
                                                {getFollowButtonLabel()}
                                            </button>
                                            <button type="button" onClick={handleShareProfile} className="flex-1 h-9 flex items-center justify-center rounded-xl border border-gray-200 dark:border-gray-800 bg-white dark:bg-black text-gray-900 dark:text-white shadow-sm" aria-label="Share profile">
                                                <Share2 size={18} />
                                            </button>
                                            <button type="button" onClick={handleStarClick}
                                                className={`flex-1 h-9 flex items-center justify-center rounded-xl border shadow-sm transition-all ${showInterestsSection ? 'border-orange-300 bg-orange-50 text-orange-500' : 'border-gray-200 dark:border-gray-800 bg-white dark:bg-black text-gray-900 dark:text-white'}`}
                                                aria-label="View interests">
                                                <Star size={18} fill={showInterestsSection ? 'currentColor' : 'none'} />
                                            </button>
                                            <button type="button" onClick={handleOpenMessages} disabled={messageLoading} className="flex-1 h-9 flex items-center justify-center rounded-xl border border-gray-200 dark:border-gray-800 bg-white dark:bg-black text-gray-900 dark:text-white shadow-sm" aria-label="Chat">
                                                <MessageCircle size={18} />
                                            </button>

                                            <div className="relative" ref={userOptionsMenuRef}>
                                                <button 
                                                    type="button" 
                                                    onClick={() => setShowUserOptionsMenu(!showUserOptionsMenu)} 
                                                    className="w-9 h-9 flex items-center justify-center rounded-xl border border-gray-200 dark:border-gray-800 bg-white dark:bg-black text-gray-900 dark:text-white shadow-sm hover:opacity-70 transition-opacity"
                                                >
                                                    <MoreHorizontal size={20} />
                                                </button>
                                                {showUserOptionsMenu && (
                                                    <div className="absolute left-0 top-full mt-1 z-50 bg-white dark:bg-gray-900 border border-gray-100 dark:border-gray-800 rounded-xl shadow-xl overflow-hidden min-w-[180px]">
                                                        <button
                                                            className="w-full flex items-center gap-3 px-4 py-3 text-sm text-red-500 font-semibold hover:bg-red-50 dark:hover:bg-red-900/20 transition-colors"
                                                            onClick={() => { setShowUserOptionsMenu(false); setRewardToast({ type: 'success', message: 'Report submitted successfully.' }); }}
                                                        >
                                                            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M4 15s1-1 4-1 5 2 8 2 4-1 4-1V3s-1 1-4 1-5-2-8-2-4 1-4 1z"/><line x1="4" y1="22" x2="4" y2="15"/></svg>
                                                            Report
                                                        </button>
                                                        <button
                                                            className="w-full flex items-center gap-3 px-4 py-3 text-sm text-gray-700 dark:text-gray-300 font-semibold hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors border-t border-gray-100 dark:border-gray-800 disabled:opacity-50"
                                                            onClick={handleToggleNotifications}
                                                            disabled={notifLoading}
                                                        >
                                                            {notifLoading ? (
                                                                <Loader2 size={16} className="animate-spin" />
                                                            ) : (
                                                                <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9"/><path d="M13.73 21a2 2 0 0 1-3.46 0"/></svg>
                                                            )}
                                                            {notificationEnabled ? 'Turn Off Notifications' : 'Turn On Notifications'}
                                                        </button>
                                                    </div>
                                                )}
                                            </div>
                                        </>
                                    )}
                        </div>

                        {showInterestsSection && (
                            <div className="mb-4">
                                <InterestedSection
                                    interests={userInterests}
                                    isOwnProfile={isOwnProfile}
                                    onAdd={() => setShowInterestsModal(true)}
                                />
                            </div>
                        )}
                        </div>

                        {!contentLocked && (
                            <div className="pb-4">
                                <HighlightsRail
                                    users={profileUser ? [profileUser] : []}
                                    variant="profile"
                                    allowCreate={isOwnProfile}
                                />
                            </div>
                        )}

                        {isVendor && vendorInfo && (
                            <div className="pb-2">
                                <VendorBusinessCard />
                            </div>
                        )}

                    {/* Tabs — only show when not locked */}
                    {!contentLocked && (
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
                    )}
                </div>

                <div className="flex-1 overflow-y-auto">
                    {renderContentMobile()}
                </div>
            </div>


            {/* DESKTOP — two-panel layout */}
            <div className="hidden md:flex h-[calc(100vh-0px)]">

                {/* ── Left Panel: fixed, scrollable if needed ─────────────────── */}
                <div className="w-[40%] shrink-0 flex flex-col border-r border-gray-200 dark:border-gray-800 overflow-y-auto bg-white dark:bg-black px-8 py-10">

                    {/* Avatar */}
                    <div className="flex justify-center mb-5">
                        <div className="relative">
                            {/* Orange gradient ring when user has a story */}
                            <div
                                className={`rounded-full p-[3px] ${profileStory ? 'bg-gradient-to-tr from-yellow-400 via-orange-500 to-pink-600 cursor-pointer' : 'bg-transparent'}`}
                                onClick={profileStory ? () => setShowStoryViewer(true) : isOwnProfile ? () => setShowAvatarModal(true) : undefined}
                            >
                                <div className={`rounded-full p-[2.5px] ${profileStory ? 'bg-white dark:bg-black' : ''}`}>
                                    <div
                                        className={`w-[134px] h-[134px] rounded-full overflow-hidden ${!profileStory && isOwnProfile ? 'cursor-pointer hover:opacity-90' : ''}`}
                                        style={{boxShadow:'0 8px 32px rgba(0,0,0,0.18), 0 2px 8px rgba(0,0,0,0.10)'}}
                                    >
                                        {profileUser.avatar_url ? (
                                            <img src={profileUser.avatar_url} className="w-full h-full rounded-full object-cover" alt="Profile" />
                                        ) : (
                                            <div className="w-full h-full bg-gradient-to-br from-gray-200 to-gray-300 dark:from-gray-700 dark:to-gray-800 flex items-center justify-center text-4xl font-bold text-gray-600 dark:text-gray-300 rounded-full">
                                                {getInitials(profileUser.full_name || profileUser.username)}
                                            </div>
                                        )}
                                    </div>
                                </div>
                            </div>
                            {isOwnProfile && (
                                <button type="button" onClick={() => setShowAvatarModal(true)}
                                    className="absolute bottom-2 right-2 w-8 h-8 rounded-full bg-blue-500 text-white flex items-center justify-center border-2 border-white dark:border-black shadow-md hover:bg-blue-600 transition-colors">
                                    <Plus size={16} strokeWidth={2.5} />
                                </button>
                            )}
                        </div>
                    </div>

                    {/* Username */}
                    <div className="text-center mb-4">
                        <div className="flex items-center justify-center gap-1.5 flex-wrap">
                            <h2 className="text-[22px] font-light text-gray-900 dark:text-white tracking-tight">
                                @{profileUser.username}
                            </h2>
                            {isVendor && vendorValidated && <VerifiedBadge />}
                        </div>
                    </div>

                    {/* Actions row */}
                    <div className="flex items-center justify-center gap-2 mb-5 flex-wrap">
                        {isOwnProfile ? (
                            <>
                                <Link to="/edit-profile" className="px-5 py-2 bg-gradient-to-r from-orange-500 to-pink-500 text-white font-bold rounded-xl text-sm shadow-md hover:opacity-90 transition-opacity">
                                    Edit profile
                                </Link>
                                <button type="button" onClick={handleShareProfile} className="w-10 h-10 flex items-center justify-center rounded-xl border border-gray-200 dark:border-gray-700 text-gray-700 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-900 transition-colors" aria-label="Share">
                                    <Share2 size={17} />
                                </button>
                                <button type="button" onClick={handleStarClick} className={`w-10 h-10 flex items-center justify-center rounded-xl border transition-all ${showInterestsSection ? 'border-orange-300 bg-orange-50 text-orange-500 dark:border-orange-900/20 dark:text-orange-400' : 'border-gray-200 dark:border-gray-700 text-gray-700 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-900'}`} aria-label="View interests">
                                    <Star size={17} fill={showInterestsSection ? 'currentColor' : 'none'} />
                                </button>
                                <button type="button" onClick={handleOpenMessages} className="w-10 h-10 flex items-center justify-center rounded-xl border border-gray-200 dark:border-gray-700 text-gray-700 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-900 transition-colors" aria-label="Message">
                                    <MessageCircle size={17} />
                                </button>
                                <Link to="/settings" className="w-10 h-10 flex items-center justify-center rounded-xl border border-gray-200 dark:border-gray-700 text-gray-700 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-900 transition-colors">
                                    <Settings size={17} />
                                </Link>
                            </>
                        ) : (
                            <>
                                <button onClick={handleFollow} disabled={followLoading} className={getFollowButtonClass('md')}>
                                    {getFollowButtonLabel()}
                                </button>
                                <button type="button" onClick={handleShareProfile} className="w-10 h-10 flex items-center justify-center rounded-xl border border-gray-200 dark:border-gray-700 text-gray-700 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-900 transition-colors" aria-label="Share">
                                    <Share2 size={17} />
                                </button>
                                <button type="button" onClick={handleStarClick} className={`w-10 h-10 flex items-center justify-center rounded-xl border transition-all ${showInterestsSection ? 'border-orange-300 bg-orange-50 text-orange-500' : 'border-gray-200 dark:border-gray-700 text-gray-700 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-900'}`} aria-label="View interests">
                                    <Star size={17} fill={showInterestsSection ? 'currentColor' : 'none'} />
                                </button>
                                <button type="button" onClick={handleOpenMessages} className="w-10 h-10 flex items-center justify-center rounded-xl border border-gray-200 dark:border-gray-700 text-gray-700 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-900 transition-colors" aria-label="Message">
                                    <MessageCircle size={17} />
                                </button>
                                <div className="relative" ref={userOptionsMenuRef}>
                                    <button type="button" onClick={() => setShowUserOptionsMenu(v => !v)} className="w-10 h-10 flex items-center justify-center rounded-xl border border-gray-200 dark:border-gray-700 text-gray-700 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-900 transition-colors">
                                        <MoreHorizontal size={18} />
                                    </button>
                                    {showUserOptionsMenu && (
                                        <div className="absolute left-0 top-full mt-1 z-50 bg-white dark:bg-gray-900 border border-gray-100 dark:border-gray-800 rounded-xl shadow-xl overflow-hidden min-w-[200px]">
                                            <button className="w-full flex items-center gap-3 px-4 py-3 text-sm text-red-500 font-semibold hover:bg-red-50 dark:hover:bg-red-900/20 transition-colors" onClick={() => { setShowUserOptionsMenu(false); setRewardToast({ type: 'success', message: 'Report submitted successfully.' }); }}>
                                                <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M4 15s1-1 4-1 5 2 8 2 4-1 4-1V3s-1 1-4 1-5-2-8-2-4 1-4 1z"/><line x1="4" y1="22" x2="4" y2="15"/></svg>
                                                Report
                                            </button>
                                            <button className="w-full flex items-center gap-3 px-4 py-3 text-sm text-gray-700 dark:text-gray-300 font-semibold hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors border-t border-gray-100 dark:border-gray-800 disabled:opacity-50" onClick={handleToggleNotifications} disabled={notifLoading}>
                                                {notifLoading ? <Loader2 size={16} className="animate-spin" /> : <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9"/><path d="M13.73 21a2 2 0 0 1-3.46 0"/></svg>}
                                                {notificationEnabled ? 'Turn Off Notifications' : 'Turn On Notifications'}
                                            </button>
                                        </div>
                                    )}
                                </div>
                            </>
                        )}
                    </div>

                    {/* Stats */}
                    <div className="flex items-center justify-center gap-6 mb-5 text-sm">
                        <span className="text-center">
                            <span className="block font-bold text-gray-900 dark:text-white text-base">{fmt(profileUser.posts_count ?? userPosts.length)}</span>
                            <span className="text-gray-500 dark:text-gray-400">posts</span>
                        </span>
                        <button type="button" onClick={() => setFollowersModalOpen(true)} className="text-center hover:opacity-70 transition-opacity">
                            <span className="block font-bold text-gray-900 dark:text-white text-base">{fmt(profileUser.followers_count || 0)}</span>
                            <span className="text-gray-500 dark:text-gray-400">followers</span>
                        </button>
                        <button type="button" onClick={() => setFollowingModalOpen(true)} className="text-center hover:opacity-70 transition-opacity">
                            <span className="block font-bold text-gray-900 dark:text-white text-base">{fmt(profileUser.following_count || 0)}</span>
                            <span className="text-gray-500 dark:text-gray-400">following</span>
                        </button>
                    </div>

                    {/* Full name + bio */}
                    <div className="text-center">
                        {(profileUser.full_name || profileUser.username) && (
                            <div className="font-bold text-base text-gray-900 dark:text-white mb-1">
                                {profileUser.full_name || profileUser.username}
                            </div>
                        )}
                        {isVendor && isOwnProfile && (
                            <div className="mb-2 flex justify-center"><ValidationStatusBadge validated={vendorValidated} /></div>
                        )}
                        {profileUser.bio && (
                            <div>
                                <p className={`text-[14px] text-gray-600 dark:text-gray-400 whitespace-pre-wrap leading-relaxed text-left ${!isBioExpanded ? 'line-clamp-3' : ''}`}>
                                    {profileUser.bio}
                                </p>
                                {(profileUser.bio.includes('\n') || profileUser.bio.length > 80) && (
                                    <button onClick={() => setIsBioExpanded(!isBioExpanded)} className="text-[13px] font-bold text-gray-500 dark:text-gray-400 mt-1 hover:underline">
                                        {isBioExpanded ? 'Show less' : 'Read more'}
                                    </button>
                                )}
                            </div>
                        )}
                        <MutualFollowers />
                    </div>

                    {/* Highlights */}
                    {!contentLocked && (
                        <div className="mt-6">
                            <HighlightsRail users={profileUser ? [profileUser] : []} variant="profile" allowCreate={isOwnProfile} />
                        </div>
                    )}

                    {/* Interested section */}
                    {showInterestsSection && (
                        <div className="mt-6">
                            <InterestedSection 
                                isDesktop
                                interests={userInterests} 
                                isOwnProfile={isOwnProfile} 
                                onAdd={() => setShowInterestsModal(true)} 
                            />
                        </div>
                    )}

                    <VendorBusinessCard />

                    {/* Floating Wallet */}
                    <div className="mt-auto pt-6">
                        <Link to="/wallet" className="flex items-center gap-2 bg-gray-50 dark:bg-gray-900 rounded-full border border-gray-100 dark:border-gray-800 p-1 pr-4 hover:scale-[1.02] transition-transform">
                            <div className="w-9 h-9 rounded-full bg-orange-500 flex items-center justify-center text-white shadow">
                                <Wallet size={16} />
                            </div>
                            <div className="flex flex-col">
                                <span className="text-[9px] text-gray-500 dark:text-gray-400 font-medium uppercase tracking-wider">Balance</span>
                                <span className="text-sm font-bold text-gray-900 dark:text-white">{walletBalance} Coins</span>
                            </div>
                        </Link>
                    </div>
                </div>

                {/* ── Right Panel: tabs + scrollable grid ─────────────────────── */}
                <div className="flex-1 flex flex-col min-w-0 overflow-hidden">

                    {/* Tabs */}
                    {!contentLocked && (
                        <div className="flex border-b border-gray-200 dark:border-gray-800 bg-white dark:bg-black shrink-0">
                            {tabConfig.map(tab => (
                                <button key={tab.key} onClick={() => setActiveTab(tab.key)}
                                    className={`flex items-center gap-1.5 px-6 py-4 border-b-[2px] text-[11px] font-semibold tracking-widest uppercase transition-all ${
                                        activeTab === tab.key
                                            ? 'border-gray-900 dark:border-white text-gray-900 dark:text-white'
                                            : 'border-transparent text-gray-400 hover:text-gray-600 dark:hover:text-gray-300'
                                    }`}>
                                    {React.cloneElement(tab.icon, { size: 12 })} {tab.label}
                                </button>
                            ))}
                        </div>
                    )}

                    {/* Grid */}
                    <div className="flex-1 overflow-y-auto">
                        <div className="pb-12">
                            {renderContent()}
                        </div>
                    </div>
                </div>
            </div>

            {/* Modals */}
            <PostDetailModal isOpen={!!selectedPost} post={selectedPost} onClose={() => setSelectedPost(null)} />
            <PostDetailModal isOpen={!!selectedAd} post={selectedAd} onClose={() => setSelectedAd(null)} />
            {selectedTweet && (
                <TweetDetailModal
                    isOpen={!!selectedTweet}
                    tweet={selectedTweet}
                    onClose={() => setSelectedTweet(null)}
                />
            )}
            {selectedPromoteReel && (
                <PromoteDetailModal
                    isOpen={!!selectedPromoteReel}
                    promoteReel={selectedPromoteReel}
                    onClose={() => setSelectedPromoteReel(null)}
                />
            )}
            <InterestsModal
                isOpen={showInterestsModal}
                onClose={() => setShowInterestsModal(false)}
                currentInterests={userInterests}
                categories={availableCategories}
                onSave={handleSaveInterests}
                saving={savingInterests}
            />
            <AddImageModal
                isOpen={showAddImageModal}
                onClose={() => setShowAddImageModal(false)}
            />
            <AvatarCropModal
                isOpen={showAvatarModal}
                onClose={() => setShowAvatarModal(false)}
                onSuccess={handleAvatarSuccess}
                currentAvatar={profileUser.avatar_url}
                userName={profileUser.full_name || profileUser.username}
            />
            <FollowersModal
                isOpen={followersModalOpen}
                onClose={() => setFollowersModalOpen(false)}
                userId={profileTargetUserId}
                isOwnProfile={isOwnProfile}
            />
            <FollowingModal
                isOpen={followingModalOpen}
                onClose={() => setFollowingModalOpen(false)}
                userId={profileTargetUserId}
                isOwnProfile={isOwnProfile}
            />

            {/* Story viewer */}
            {showStoryViewer && profileStory && (
                <StoryViewer
                    initialStoryIndex={0}
                    stories={[profileStory]}
                    onClose={() => setShowStoryViewer(false)}
                />
            )}
        </div>
    );
};


export default Profile;