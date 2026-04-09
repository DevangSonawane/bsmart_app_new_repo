import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { Loader2, Search, X } from 'lucide-react';
import { useSelector } from 'react-redux';
import {
  bulkCheckFollowStatus,
  followUser,
  getFollowers,
  removeFollower,
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

export default function FollowersModal({ isOpen, onClose, userId, isOwnProfile }) {
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

  const loadFollowers = useCallback(async (nextPage = 1, nextSearch = search, replace = false) => {
    if (!userId) return;

    if (replace) setLoading(true);
    else setLoadingMore(true);

    try {
      const response = await getFollowers(userId, {
        search: nextSearch,
        page: nextPage,
        limit: PAGE_LIMIT,
      });

      let nextUsers = Array.isArray(response?.users) ? response.users : [];
      const ids = nextUsers.map((user) => getUserId(user)).filter(Boolean);

      if (ids.length && currentUserId) {
        try {
          const statuses = await bulkCheckFollowStatus(ids);
          const statusMap = new Map((statuses || []).map((item) => [String(item.userId), item]));
          nextUsers = nextUsers.map((user) => ({
            ...user,
            ...(statusMap.get(String(getUserId(user))) || {}),
            isFollowing: statusMap.get(String(getUserId(user)))?.isFollowing ?? Boolean(user.isFollowing),
          }));
        } catch (error) {
          console.error('Failed to load follower statuses:', error);
        }
      }

      setTotal(Number(response?.total || 0));
      setPage(nextPage);
      setHasMore(nextPage * PAGE_LIMIT < Number(response?.total || 0));
      setUsers((prev) => (replace ? nextUsers : [...prev, ...nextUsers]));
    } catch (error) {
      console.error('Failed to load followers:', error);
      if (replace) {
        setUsers([]);
        setHasMore(false);
        setTotal(0);
      }
    } finally {
      setLoading(false);
      setLoadingMore(false);
    }
  }, [currentUserId, search, userId]);

  useEffect(() => {
    if (!isOpen || !userId) return;
    const timeout = setTimeout(() => {
      loadFollowers(1, search, true);
    }, 250);
    return () => clearTimeout(timeout);
  }, [isOpen, loadFollowers, search, userId]);

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
      loadFollowers(page + 1, search, false);
    }
  }, [hasMore, loadFollowers, loading, loadingMore, page, search]);

  const handleFollowBack = async (targetUserId) => {
    if (!targetUserId || actionUserId) return;
    setActionUserId(targetUserId);
    try {
      await followUser(targetUserId);
      setUsers((prev) => prev.map((user) => (
        getUserId(user) === targetUserId ? { ...user, isFollowing: true } : user
      )));
    } catch (error) {
      console.error('Failed to follow user:', error);
    } finally {
      setActionUserId('');
    }
  };

  const handleRemoveFollower = async (followerId) => {
    if (!followerId || actionUserId) return;
    setActionUserId(followerId);
    try {
      await removeFollower(followerId);
      setUsers((prev) => prev.filter((user) => getUserId(user) !== followerId));
      setTotal((prev) => Math.max(0, prev - 1));
    } catch (error) {
      console.error('Failed to remove follower:', error);
    } finally {
      setActionUserId('');
    }
  };

  const emptyLabel = useMemo(() => (
    search.trim() ? 'No followers found for that search.' : 'No followers yet.'
  ), [search]);

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-[120] flex items-end justify-center bg-black/75 backdrop-blur-sm md:items-center" onClick={onClose}>
      <div
        className="flex h-[100dvh] w-full flex-col overflow-hidden rounded-none bg-zinc-900 text-white md:h-[72vh] md:max-h-[720px] md:w-full md:max-w-lg md:rounded-3xl md:border md:border-white/10"
        onClick={(event) => event.stopPropagation()}
      >
        <div className="flex items-center justify-between border-b border-white/10 px-5 py-4">
          <div className="w-10" />
          <h2 className="text-base font-semibold">Followers</h2>
          <button onClick={onClose} className="flex h-10 w-10 items-center justify-center rounded-full text-gray-400 transition hover:bg-white/5 hover:text-white">
            <X size={18} />
          </button>
        </div>

        <div className="border-b border-white/10 px-4 py-3">
          <div className="flex items-center gap-3 rounded-full bg-zinc-800 px-4 py-3 text-sm text-gray-400">
            <Search size={16} />
            <input
              value={search}
              onChange={(event) => setSearch(event.target.value)}
              placeholder="Search"
              className="w-full bg-transparent outline-none placeholder:text-gray-500"
            />
          </div>
        </div>

        <div ref={scrollRef} onScroll={handleScroll} className="flex-1 overflow-y-auto px-2 py-2 [scrollbar-width:none] [-ms-overflow-style:none] [&::-webkit-scrollbar]:hidden">
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
                const showFollowBadge = !user.isFollowing && targetUserId !== currentUserId;

                return (
                  <div key={targetUserId} className="flex items-center gap-3 rounded-2xl px-3 py-3 transition hover:bg-zinc-800/80">
                    <Avatar user={user} />
                    <div className="min-w-0 flex-1">
                      <div className="flex items-center gap-2">
                        <p className="truncate text-sm font-semibold text-white">{getUserName(user)}</p>
                        {showFollowBadge ? (
                          <button
                            onClick={() => handleFollowBack(targetUserId)}
                            disabled={actionUserId === targetUserId}
                            className="rounded-full bg-blue-500/15 px-2 py-0.5 text-[11px] font-semibold text-blue-400 transition hover:bg-blue-500/25 disabled:opacity-60"
                          >
                            Follow
                          </button>
                        ) : null}
                      </div>
                      <p className="truncate text-sm text-gray-400">{getFullName(user)}</p>
                    </div>
                    {isOwnProfile ? (
                      <button
                        onClick={() => handleRemoveFollower(targetUserId)}
                        disabled={actionUserId === targetUserId}
                        className="rounded-full border border-white/10 bg-zinc-800 px-4 py-2 text-sm font-medium text-white transition hover:bg-zinc-700 disabled:opacity-60"
                      >
                        {actionUserId === targetUserId ? 'Removing...' : 'Remove'}
                      </button>
                    ) : null}
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
