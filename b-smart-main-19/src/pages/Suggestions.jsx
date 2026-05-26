import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { ArrowLeft, X } from 'lucide-react';
import { useSelector } from 'react-redux';
import {
  checkFollowStatus,
  followUser,
  unfollowUser,
  cancelFollowRequest,
  FOLLOW_STATUS_CHANGED_EVENT,
} from '../services/followService';

const BASE_URL = 'https://api.bebsmart.in';

const normalizeAssetUrl = (value) => {
  if (!value) return null;
  if (/^http:\/\/api\.bebsmart\.in/i.test(String(value))) return String(value).replace(/^http:\/\//i, 'https://');
  if (String(value).startsWith('http')) return value;
  const normalized = String(value).replace(/^\/+/, '');
  if (normalized.startsWith('uploads/')) return `${BASE_URL}/${normalized}`;
  return `${BASE_URL}/uploads/${normalized}`;
};

const FollowButton = ({ targetUserId }) => {
  const { userObject } = useSelector(s => s.auth);
  const [followState, setFollowState] = useState('not_following');
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    let isMounted = true;
    const loadStatus = async () => {
      const currentUserId = userObject?._id || userObject?.id;
      if (!currentUserId || !targetUserId || String(currentUserId) === String(targetUserId)) {
        return;
      }
      try {
        const status = await checkFollowStatus(targetUserId);
        if (!isMounted) return;
        if (status?.isFollowing || status?.status === 'following') {
          setFollowState('following');
        } else if (status?.isPending || status?.requestPending || status?.requested || status?.status === 'pending') {
          setFollowState('requested');
        } else {
          setFollowState('not_following');
        }
      } catch {
        if (isMounted) setFollowState('not_following');
      }
    };
    loadStatus();
    return () => { isMounted = false; };
  }, [targetUserId, userObject]);

  const handleClick = async (e) => {
    e.stopPropagation();
    if (!userObject || !targetUserId || loading) return;
    const prev = followState;
    setLoading(true);
    try {
      if (followState === 'following') {
        await unfollowUser(targetUserId);
        setFollowState('not_following');
      } else if (followState === 'requested') {
        await cancelFollowRequest(targetUserId);
        setFollowState('not_following');
      } else {
        const result = await followUser(targetUserId);
        if (result?.status === 'pending' || result?.pending || result?.requested || result?.requestPending || result?.isPending) {
          setFollowState('requested');
        } else {
          setFollowState('following');
        }
      }
    } catch {
      setFollowState(prev);
    } finally {
      setLoading(false);
    }
  };

  return (
    <button
      type="button"
      onClick={handleClick}
      disabled={loading}
      className={`px-4 py-1.5 rounded-lg text-sm font-semibold transition-colors ${
        followState === 'following'
          ? 'bg-gray-100 dark:bg-gray-800 text-gray-900 dark:text-white'
          : 'bg-blue-500 text-white hover:bg-blue-600'
      } disabled:opacity-50`}
    >
      {loading ? '...' : followState === 'following' ? 'Following' : followState === 'requested' ? 'Requested' : 'Follow'}
    </button>
  );
};

const Suggestions = () => {
  const navigate = useNavigate();
  const { userObject } = useSelector(s => s.auth);
  const [users, setUsers] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchSuggestions = async () => {
      try {
        const token = localStorage.getItem('token');
        const res = await fetch(`${BASE_URL}/api/suggestions/users`, {
          headers: {
            'Content-Type': 'application/json',
            ...(token ? { Authorization: `Bearer ${token}` } : {}),
          },
        });
        if (res.ok) {
          const data = await res.json();
          setUsers(Array.isArray(data) ? data : data.data || []);
        }
      } catch (e) {
        console.error('Error fetching suggestions:', e);
      } finally {
        setLoading(false);
      }
    };
    fetchSuggestions();
  }, []);

  return (
    <div className="min-h-screen bg-white dark:bg-black">
      {/* Header */}
      <div className="sticky top-0 z-10 flex items-center gap-4 px-4 h-14 bg-white/80 dark:bg-black/80 backdrop-blur-md border-b border-gray-100 dark:border-gray-800">
        <button onClick={() => navigate(-1)} className="p-1 -ml-1 text-gray-900 dark:text-white">
          <ArrowLeft size={24} />
        </button>
        <h1 className="text-xl font-bold text-gray-900 dark:text-white">Suggestions</h1>
      </div>

      <div className="max-w-2xl mx-auto py-2">
        {loading ? (
          <div className="p-4 space-y-4">
            {[1, 2, 3, 4, 5].map(i => (
              <div key={i} className="flex items-center gap-3 animate-pulse">
                <div className="w-12 h-12 rounded-full bg-gray-200 dark:bg-gray-800" />
                <div className="flex-1 space-y-2">
                  <div className="w-32 h-4 bg-gray-200 dark:bg-gray-800 rounded" />
                  <div className="w-24 h-3 bg-gray-100 dark:bg-gray-800 rounded" />
                </div>
                <div className="w-20 h-8 bg-gray-200 dark:bg-gray-800 rounded-lg" />
              </div>
            ))}
          </div>
        ) : (
          <div className="divide-y divide-gray-50 dark:divide-gray-900">
            {users.map((user, i) => {
              const u = user.user || user;
              const userId = u._id || u.id;
              const username = u.username || u.name || 'User';
              const fullName = u.full_name || u.name || username;
              const avatar = normalizeAssetUrl(u.avatar_url || u.avatar || u.profile_picture);
              const reason = u.mutual_friends_count
                ? `${u.mutual_friends_count} mutual connections`
                : u.followed_by ? `Followed by ${u.followed_by}` : 'Suggested for you';

              return (
                <div
                  key={userId || i}
                  onClick={() => navigate(`/profile/${userId}`)}
                  className="flex items-center gap-3 p-4 hover:bg-gray-50 dark:hover:bg-white/[0.02] transition-colors cursor-pointer"
                >
                  <div className="w-12 h-12 rounded-full overflow-hidden bg-gradient-to-br from-pink-400 to-purple-500 flex items-center justify-center shrink-0">
                    {avatar ? (
                      <img src={avatar} alt={username} className="w-full h-full object-cover" />
                    ) : (
                      <span className="text-white font-bold text-lg">{username[0]?.toUpperCase()}</span>
                    )}
                  </div>
                  <div className="flex-1 min-w-0">
                    <p className="text-sm font-bold text-gray-900 dark:text-white truncate">{username}</p>
                    <p className="text-sm text-gray-500 dark:text-gray-400 truncate">{fullName}</p>
                    <p className="text-xs text-gray-400 truncate mt-0.5">{reason}</p>
                  </div>
                  <FollowButton targetUserId={String(userId)} />
                </div>
              );
            })}
            {users.length === 0 && (
              <div className="flex flex-col items-center justify-center py-20 text-gray-500">
                <p>No suggestions available at the moment.</p>
              </div>
            )}
          </div>
        )}
      </div>
    </div>
  );
};

export default Suggestions;
