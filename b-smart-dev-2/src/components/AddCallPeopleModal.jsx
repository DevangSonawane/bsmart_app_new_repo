import { useEffect, useMemo, useState } from 'react';
import { Check, X } from 'lucide-react';
import Avatar from './Avatar';
import { getFollowing } from '../services/followService';

const getUserId = (user) => user?._id || user?.id || '';
const getUserName = (user) => user?.full_name || user?.name || user?.username || 'User';

// Multi-select people picker for adding participants to an ongoing call —
// mirrors ChatPage.jsx's GroupCreateModal checkbox/chip pattern, simplified
// for this context (no group name, people added immediately ring rather
// than forming a persistent group chat).
export default function AddCallPeopleModal({ isOpen, onClose, currentUserId, excludeUserIds = [], onConfirm }) {
  const [users, setUsers] = useState([]);
  const [loading, setLoading] = useState(false);
  const [search, setSearch] = useState('');
  const [selectedIds, setSelectedIds] = useState([]);

  useEffect(() => {
    if (!isOpen) {
      setSearch('');
      setSelectedIds([]);
      return undefined;
    }
    if (!currentUserId) return undefined;
    let active = true;
    setLoading(true);
    getFollowing(currentUserId, { page: 1, limit: 100 })
      .then((data) => { if (active) setUsers(Array.isArray(data?.users) ? data.users : []); })
      .catch(() => { if (active) setUsers([]); })
      .finally(() => { if (active) setLoading(false); });
    return () => { active = false; };
  }, [isOpen, currentUserId]);

  const excludeSet = useMemo(() => new Set(excludeUserIds.map(String)), [excludeUserIds]);
  const candidateUsers = useMemo(() => (
    users.filter((user) => !excludeSet.has(String(getUserId(user))))
  ), [users, excludeSet]);
  const filteredUsers = useMemo(() => {
    const query = search.trim().toLowerCase();
    if (!query) return candidateUsers;
    return candidateUsers.filter((user) => (
      [getUserName(user), user?.username].filter(Boolean).some((value) => value.toLowerCase().includes(query))
    ));
  }, [candidateUsers, search]);

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-[140] flex items-center justify-center bg-black/70 px-4 backdrop-blur-sm" onClick={onClose}>
      <div
        className="flex max-h-[80vh] w-full max-w-[480px] flex-col overflow-hidden rounded-[28px] bg-[#24252b] text-white shadow-2xl"
        onClick={(event) => event.stopPropagation()}
      >
        <div className="flex items-center justify-between border-b border-white/10 px-5 py-4">
          <div className="w-8" />
          <p className="text-lg font-bold tracking-tight">Add people</p>
          <button type="button" onClick={onClose} className="rounded-full p-2 text-white/70 transition hover:bg-white/5 hover:text-white">
            <X size={18} />
          </button>
        </div>

        <div className="border-b border-white/10 px-5 py-3">
          <input
            value={search}
            onChange={(event) => setSearch(event.target.value)}
            placeholder="Search people you follow..."
            className="w-full bg-transparent text-sm text-white outline-none placeholder:text-white/35"
          />
        </div>

        <div className="flex-1 overflow-y-auto px-0 pb-3">
          {loading ? (
            <div className="px-4 py-8 text-center text-sm text-white/55">Loading...</div>
          ) : (
            filteredUsers.map((user) => {
              const userId = getUserId(user);
              const selected = selectedIds.includes(userId);
              return (
                <button
                  key={userId}
                  type="button"
                  onClick={() => setSelectedIds((prev) => (
                    selected ? prev.filter((id) => id !== userId) : [...prev, userId]
                  ))}
                  className="flex w-full items-center gap-3 px-5 py-3 text-left transition hover:bg-white/5"
                >
                  <Avatar src={user?.avatar_url} username={getUserName(user)} size="md" />
                  <div className="min-w-0 flex-1">
                    <p className="truncate text-sm font-semibold text-white">{getUserName(user)}</p>
                    <p className="truncate text-xs text-white/60">@{user?.username || 'user'}</p>
                  </div>
                  <span className={`flex h-7 w-7 items-center justify-center rounded-full border text-xs ${
                    selected ? 'border-white bg-white text-[#24252b]' : 'border-white/70 text-transparent'
                  }`}>
                    <Check size={14} />
                  </span>
                </button>
              );
            })
          )}
          {!loading && !filteredUsers.length ? (
            <div className="px-4 py-8 text-center text-sm text-white/55">No one else to add.</div>
          ) : null}
        </div>

        <div className="border-t border-white/10 px-5 py-4">
          <button
            type="button"
            disabled={!selectedIds.length}
            onClick={() => { onConfirm(selectedIds); onClose(); }}
            className="w-full rounded-2xl bg-[#2a2f9f] px-5 py-3 text-sm font-bold text-white transition hover:bg-[#3137b5] disabled:cursor-not-allowed disabled:opacity-50"
          >
            {selectedIds.length ? `Call ${selectedIds.length} ${selectedIds.length === 1 ? 'person' : 'people'}` : 'Select people to add'}
          </button>
        </div>
      </div>
    </div>
  );
}
