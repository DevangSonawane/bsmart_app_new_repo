import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { Loader2, Search, X } from 'lucide-react';
import { useSelector } from 'react-redux';
import {
  bulkCheckFollowStatus,
  followUser,
  getFollowing,
  unfollowUser,
} from '../services/followService';

const PAGE_LIMIT = 20;

const getUserId = (user) => user?._id || user?.id || '';
const getUserName = (user) => user?.username || 'user';
const getFullName = (user) => user?.full_name || user?.name || '';
const getAvatar = (user) => user?.avatar_url || user?.profilePicture || '';

const Avatar = ({ user }) => {
  const avatar = getAvatar(user);
  const label = getUserName(user).charAt(0).toUpperCase() || 'U';

  if (avatar) {
    return <img src={avatar} alt={getUserName(user)} className="h-11 w-11 rounded-full object-cover" />;
  }

  return (
    <div className="flex h-11 w-11 items-center justify-center rounded-full bg-gradient-to-br from-orange-500 to-pink-500 text-sm font-bold text-white">
      {label}
    </div>
  );
};

export default function FollowingModal({ isOpen, onClose, userId, isOwnProfile }) {
  const currentUser = useSelector((state) => state.auth?.userObject);
  const currentUserId = getUserId(currentUser);
  const scrollRef = useRef(null);

  const [search, setSearch] = useState('');
  const [page, setPage] = useState(1);
  const [total, setTotal] = useState(0);
  const [users, setUsers] = useState([]);
  const [hasMore, setHasMore] = useState(true);
  const [loading, setLoading] = useState(false);
  const [loadingMore, setLoadingMore] = useState(false);
  const [actionUserId, setActionUserId] = useState('');

  const loadFollowing = useCallback(async (nextPage = 1, nextSearch = search, replace = false) => {
    if (!userId) return;

    if (replace) setLoading(true);
    else setLoadingMore(true);

    try {
      const response = await getFollowing(userId, {
        search: nextSearch,
        page: nextPage,
        limit: PAGE_LIMIT,
      });

      let nextUsers = (Array.isArray(response?.users) ? response.users : []).map((user) => ({
        ...user,
        isFollowing:
          String(userId) === String(currentUserId) || isOwnProfile
            ? true
            : Boolean(user.isFollowing),
        isFollowedBy: Boolean(user.isFollowedBy),
      }));
      const ids = nextUsers.map((user) => getUserId(user)).filter(Boolean);

      if (ids.length && currentUserId) {
        try {
          const statuses = await bulkCheckFollowStatus(ids);
          const statusMap = new Map((statuses || []).map((item) => [String(item.userId), item]));
          nextUsers = nextUsers.map((user) => ({
            ...user,
            ...(statusMap.get(String(getUserId(user))) || {}),
            isFollowing:
              String(userId) === String(currentUserId) || isOwnProfile
                ? true
                : (statusMap.get(String(getUserId(user)))?.isFollowing ?? Boolean(user.isFollowing)),
            isFollowedBy: statusMap.get(String(getUserId(user)))?.isFollowedBy ?? Boolean(user.isFollowedBy),
          }));
        } catch (error) {
          console.error('Failed to load following statuses:', error);
        }
      }

      setTotal(Number(response?.total || 0));
      setPage(nextPage);
      setHasMore(nextPage * PAGE_LIMIT < Number(response?.total || 0));
      setUsers((prev) => (replace ? nextUsers : [...prev, ...nextUsers]));
    } catch (error) {
      console.error('Failed to load following:', error);
      if (replace) {
        setUsers([]);
        setHasMore(false);
        setTotal(0);
      }
    } finally {
      setLoading(false);
      setLoadingMore(false);
    }
  }, [currentUserId, isOwnProfile, search, userId]);

  useEffect(() => {
    if (!isOpen || !userId) return;
    const timeout = setTimeout(() => {
      loadFollowing(1, search, true);
    }, 250);
    return () => clearTimeout(timeout);
  }, [isOpen, loadFollowing, search, userId]);

  useEffect(() => {
    if (!isOpen) return undefined;
    const onKeyDown = (event) => {
      if (event.key === 'Escape') onClose();
    };
    window.addEventListener('keydown', onKeyDown);
    return () => window.removeEventListener('keydown', onKeyDown);
  }, [isOpen, onClose]);

  const handleScroll = useCallback((event) => {
    const node = event.currentTarget;
    if (!hasMore || loadingMore || loading) return;
    if (node.scrollTop + node.clientHeight >= node.scrollHeight - 120) {
      loadFollowing(page + 1, search, false);
    }
  }, [hasMore, loadFollowing, loading, loadingMore, page, search]);

  const handleToggleFollow = async (targetUserId, isFollowing) => {
    if (!targetUserId || actionUserId) return;
    setActionUserId(targetUserId);
    try {
      if (isFollowing) {
        await unfollowUser(targetUserId);
      } else {
        await followUser(targetUserId);
      }
      setUsers((prev) => prev.map((user) => (
        getUserId(user) === targetUserId ? { ...user, isFollowing: !isFollowing } : user
      )));
    } catch (error) {
      console.error('Failed to update following status:', error);
    } finally {
      setActionUserId('');
    }
  };

  const emptyLabel = useMemo(() => (
    search.trim() ? 'No following users found for that search.' : 'Not following anyone yet.'
  ), [search]);

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-[120] flex items-end justify-center bg-black/80 backdrop-blur-sm md:items-center" onClick={onClose}>
      <div
        className="flex h-[100dvh] w-full flex-col overflow-hidden rounded-none bg-white dark:bg-[#26272b] text-gray-900 dark:text-white md:h-auto md:max-h-[70vh] md:w-full md:max-w-[600px] md:rounded-[28px] md:border border-gray-100 dark:border-white/10"
        onClick={(event) => event.stopPropagation()}
      >
        <div className="flex items-center justify-between border-b border-gray-100 dark:border-white/10 px-5 py-4">
          <div className="w-10" />
          <h2 className="text-[18px] font-semibold">Following</h2>
          <button onClick={onClose} className="flex h-10 w-10 items-center justify-center rounded-full text-gray-400 transition hover:bg-gray-100 dark:hover:bg-white/5 hover:text-gray-900 dark:hover:text-white">
            <X size={20} />
          </button>
        </div>

        <div className="border-b border-gray-100 dark:border-white/10 px-4 py-3">
          <div className="flex items-center gap-3 rounded-xl bg-gray-100 dark:bg-[#34353a] px-4 py-2.5 text-sm text-gray-500 dark:text-gray-400">
            <Search size={16} />
            <input
              value={search}
              onChange={(event) => setSearch(event.target.value)}
              placeholder="Search"
              className="w-full bg-transparent outline-none text-gray-900 dark:text-white placeholder:text-gray-500 dark:placeholder:text-gray-400"
            />
          </div>
        </div>

        <div ref={scrollRef} onScroll={handleScroll} className="flex-1 overflow-y-auto px-0 py-1 [scrollbar-width:none] [-ms-overflow-style:none] [&::-webkit-scrollbar]:hidden">
          {loading ? (
            <div className="flex h-full items-center justify-center">
              <Loader2 size={24} className="animate-spin text-orange-400" />
            </div>
          ) : users.length === 0 ? (
            <div className="flex h-full items-center justify-center px-6 text-center text-sm text-gray-400">
              {emptyLabel}
            </div>
          ) : (
            <>
              {users.map((user) => {
                const targetUserId = getUserId(user);
                const isFollowingUser = Boolean(user.isFollowing);

                return (
                  <div key={targetUserId} className="flex items-center gap-3 px-5 py-3 transition hover:bg-gray-50 dark:hover:bg-white/[0.03]">
                    <Avatar user={user} />
                    <div className="min-w-0 flex-1">
                      <p className="truncate text-[16px] font-semibold leading-5 text-gray-900 dark:text-white">{getUserName(user)}</p>
                      <p className="truncate text-[14px] leading-5 text-gray-500 dark:text-gray-400">{getFullName(user)}</p>
                    </div>
                    <button
                      onClick={() => handleToggleFollow(targetUserId, isFollowingUser)}
                      disabled={actionUserId === targetUserId}
                      className={`min-w-[112px] rounded-xl px-4 py-2 text-[15px] font-semibold transition disabled:opacity-60 ${
                        isFollowingUser
                          ? 'border border-gray-200 dark:border-white/10 bg-gray-100 dark:bg-[#36373b] text-gray-900 dark:text-white hover:bg-gray-200 dark:hover:bg-[#404148]'
                          : 'bg-blue-500 text-white hover:bg-blue-400'
                      }`}
                    >
                      {actionUserId === targetUserId ? 'Updating...' : (isFollowingUser ? 'Following' : 'Follow')}
                    </button>
                  </div>
                );
              })}
              {loadingMore ? (
                <div className="flex justify-center py-4">
                  <Loader2 size={20} className="animate-spin text-orange-400" />
                </div>
              ) : null}
            </>
          )}
        </div>
      </div>
    </div>
  );
}
