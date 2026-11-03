import { Phone, PhoneIncoming, PhoneMissed, PhoneOutgoing, Users, Video } from 'lucide-react';
import Avatar from './Avatar';

const formatTime = (dateValue) => {
  if (!dateValue) return '';
  return new Date(dateValue).toLocaleTimeString('en-IN', { hour: 'numeric', minute: '2-digit' });
};

const isSameDay = (a, b) => a.toDateString() === b.toDateString();

const dateGroupLabel = (dateValue) => {
  if (!dateValue) return '';
  const d = new Date(dateValue);
  const today = new Date();
  const yesterday = new Date();
  yesterday.setDate(today.getDate() - 1);
  if (isSameDay(d, today)) return 'Today';
  if (isSameDay(d, yesterday)) return 'Yesterday';
  return d.toLocaleDateString('en-IN', {
    day: 'numeric',
    month: 'long',
    year: d.getFullYear() !== today.getFullYear() ? 'numeric' : undefined,
  });
};

const formatDuration = (seconds) => {
  const total = Math.max(0, Number(seconds) || 0);
  const minutes = Math.floor(total / 60);
  const remainder = total % 60;
  return `${minutes}:${String(remainder).padStart(2, '0')}`;
};

export default function CallHistoryList({ calls, loading, hasMore, onLoadMore, currentUserId, onCallBack, onGroupCallBack, emptyMessage = 'No calls yet.' }) {
  if (loading && !calls.length) {
    return (
      <div className="space-y-1 px-2 pt-2">
        {Array.from({ length: 7 }).map((_, index) => (
          <div key={index} className="flex animate-pulse items-center gap-3 rounded-2xl px-3 py-3">
            <div className="h-9 w-9 rounded-full bg-gray-200 dark:bg-[#1f1f1f]" />
            <div className="flex-1 space-y-2">
              <div className="h-3 w-1/3 rounded bg-gray-200 dark:bg-[#1f1f1f]" />
              <div className="h-3 w-1/4 rounded bg-gray-100 dark:bg-[#161616]" />
            </div>
          </div>
        ))}
      </div>
    );
  }

  if (!calls.length) {
    return (
      <div className="px-5 py-6">
        <p className="text-sm text-gray-500 dark:text-white/55">{emptyMessage}</p>
      </div>
    );
  }

  let lastDateLabel = null;

  return (
    <div className="space-y-1 px-2 pt-2">
      {calls.map((call) => {
        const dateLabel = dateGroupLabel(call.createdAt);
        const showDateHeader = dateLabel !== lastDateLabel;
        lastDateLabel = dateLabel;

        const TypeIcon = call.call_type === 'video' ? Video : Phone;

        let title; let avatar; let DirIcon; let isUnsuccessful; let statusLabel; let onClick;

        if (call.is_group) {
          const conversation = call.conversation_id || {};
          const self = call.participants?.find((p) => String(p.user_id?._id || p.user_id) === String(currentUserId));
          title = conversation.groupName || 'Group call';
          avatar = conversation.groupAvatar || '';
          DirIcon = Users;
          isUnsuccessful = self?.status === 'missed' || self?.status === 'declined';
          statusLabel = self?.status === 'missed'
            ? 'Missed'
            : self?.status === 'declined'
            ? 'Declined'
            : call.started_at && call.ended_at
            ? formatDuration((new Date(call.ended_at) - new Date(call.started_at)) / 1000)
            : 'Group call';
          onClick = () => onGroupCallBack?.(conversation._id || call.conversation_id, call.call_type);
        } else {
          const isOutgoing = String(call.caller_id?._id || call.caller_id) === String(currentUserId);
          const peerUser = isOutgoing ? call.receiver_id : call.caller_id;
          const peerId = peerUser?._id || peerUser;
          title = peerUser?.full_name || peerUser?.username || 'Unknown';
          avatar = peerUser?.avatar_url || '';
          const isMissed = call.status === 'missed' && !isOutgoing;
          DirIcon = isMissed ? PhoneMissed : isOutgoing ? PhoneOutgoing : PhoneIncoming;
          isUnsuccessful = ['missed', 'rejected', 'busy'].includes(call.status);
          statusLabel = call.status === 'missed'
            ? (isOutgoing ? 'No answer' : 'Missed')
            : call.status === 'rejected'
            ? 'Declined'
            : call.status === 'busy'
            ? 'Busy'
            : call.duration_seconds > 0
            ? formatDuration(call.duration_seconds)
            : 'Call';
          onClick = () => onCallBack({ id: peerId, name: title, avatar }, call.call_type);
        }

        return (
          <div key={call._id}>
            {showDateHeader && (
              <p className="px-3 pb-1.5 pt-3 text-[12px] font-bold uppercase tracking-wide text-gray-400 dark:text-white/40 first:pt-1">
                {dateLabel}
              </p>
            )}
            <button
              type="button"
              onClick={onClick}
              className="flex w-full items-center gap-3 rounded-2xl border border-transparent px-3 py-2.5 text-left transition-all hover:bg-gray-50 dark:hover:bg-white/[0.04]"
            >
              <Avatar src={avatar} username={title} size="md" />
              <div className="min-w-0 flex-1">
                <p className="truncate text-[14.5px] font-semibold text-gray-900 dark:text-white">{title}</p>
                <div className={`mt-0.5 flex items-center gap-1 text-[12.5px] ${isUnsuccessful ? 'text-red-500' : 'text-gray-500 dark:text-white/50'}`}>
                  <DirIcon size={13} />
                  <span>{statusLabel}</span>
                </div>
              </div>
              <div className="flex shrink-0 flex-col items-end gap-1.5">
                <span className="text-[12px] text-gray-400 dark:text-white/40">{formatTime(call.createdAt)}</span>
                <TypeIcon size={16} className="text-gray-400 dark:text-white/40" />
              </div>
            </button>
          </div>
        );
      })}
      {hasMore && (
        <button
          type="button"
          onClick={onLoadMore}
          disabled={loading}
          className="w-full py-3 text-center text-sm font-semibold text-[#7C3AED] disabled:opacity-50"
        >
          {loading ? 'Loading…' : 'Load more'}
        </button>
      )}
    </div>
  );
}
