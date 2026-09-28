import React from 'react';
import { bookingStatus } from '../data/bookingHelpers';

export function CustomerAvatar({ name, large = false }) {
  return <span aria-hidden="true" className={`${large ? 'w-14 h-14 text-lg' : 'w-10 h-10 text-xs'} flex-shrink-0 rounded-full bg-gradient-to-br from-insta-purple/15 to-insta-pink/20 text-[#fa3f5e] flex items-center justify-center font-bold`}>{name.split(' ').map((part) => part[0]).slice(0, 2).join('')}</span>;
}
export function BookingBadge({ status }) {
  const color = status === 'New' || status === 'Proposed' ? 'bg-purple-50 dark:bg-purple-900/20 text-insta-purple' : status === 'Declined' ? 'bg-red-50 dark:bg-red-900/20 text-red-500' : 'bg-green-50 dark:bg-green-900/20 text-green-600 dark:text-green-400';
  return <span className={`inline-flex px-2 py-1 rounded-md text-[10px] font-semibold whitespace-nowrap ${color}`}>{bookingStatus(status)}</span>;
}
