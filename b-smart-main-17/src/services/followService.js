import api from '../lib/api';

export const FOLLOW_STATUS_CHANGED_EVENT = 'bsmart:follow-status-changed';

export const normalizeFollowStateFromStatus = (status) => {
  if (status?.isFollowing || status?.status === 'following') return 'following';
  if (status?.isPending || status?.requestPending || status?.requested || status?.status === 'pending') return 'requested';
  return 'not_following';
};

export const emitFollowStatusChanged = ({ userId, state }) => {
  if (!userId || typeof window === 'undefined') return;
  window.dispatchEvent(new CustomEvent(FOLLOW_STATUS_CHANGED_EVENT, {
    detail: { userId: String(userId), state },
  }));
};

// Existing follow APIs

export const checkFollowStatus = async (userId) => {
  const response = await api.get(`/follows/check/${userId}`);
  return response.data;
};

export const bulkCheckFollowStatus = async (userIds) => {
  const response = await api.post('/follows/status/bulk', { userIds });
  return response.data;
};

export const getFollowers = async (userId, { search = '', page = 1, limit = 20 } = {}) => {
  const response = await api.get(`/users/${userId}/followers`, {
    params: { search, page, limit },
  });
  return response.data;
};

export const getFollowing = async (userId, { search = '', page = 1, limit = 20 } = {}) => {
  const response = await api.get(`/users/${userId}/following`, {
    params: { search, page, limit },
  });
  return response.data;
};

export const followUser = async (userId) => {
  const response = await api.post('/follow', { followedUserId: userId });
  emitFollowStatusChanged({
    userId,
    state: normalizeFollowStateFromStatus(response.data),
  });
  return response.data;
};

export const unfollowUser = async (userId) => {
  const response = await api.post('/unfollow', { followedUserId: userId });
  emitFollowStatusChanged({ userId, state: 'not_following' });
  return response.data;
};

export const removeFollower = async (followerId) => {
  const response = await api.delete(`/follow/followers/${followerId}/remove`);
  return response.data;
};

export const getSuggestions = async (limit = 10) => {
  const response = await api.get('/follows/suggestions', {
    params: { limit },
  });
  return response.data;
};

export const getFollowCounts = async (userId) => {
  const response = await api.get(`/users/${userId}/follow-counts`);
  return response.data;
};

// Account Privacy APIs

/**
 * Toggle account between public and private.
 * Private -> Public: all pending follow requests are auto-accepted.
 * Public -> Private: future followers must send a request first.
 */
export const toggleAccountPrivacy = async () => {
  const response = await api.patch('/follow/privacy/toggle');
  return response.data; // { success, isPrivate, message }
};

/**
 * Set account privacy explicitly.
 * @param {boolean} isPrivate - true = private, false = public
 */
export const setAccountPrivacy = async (isPrivate) => {
  const response = await api.patch('/follow/privacy/set', { isPrivate });
  return response.data; // { success, isPrivate, message }
};

/**
 * Get current privacy status.
 * Returns whether account is private and how many follow requests are pending.
 */
export const getPrivacyStatus = async () => {
  const response = await api.get('/follow/privacy/status');
  return response.data; // { isPrivate, pendingRequestsCount }
};

// Follow Request APIs

/**
 * Get all incoming follow requests (for private accounts).
 */
export const getFollowRequests = async () => {
  const response = await api.get('/follow/requests');
  return response.data; // { count, requests: [...] }
};

/**
 * Accept a follow request from a specific user.
 * @param {string} requesterId - ID of the user who sent the request
 */
export const acceptFollowRequest = async (requesterId) => {
  const response = await api.post(`/follow/requests/${requesterId}/accept`);
  return response.data; // { success, message }
};

/**
 * Decline a follow request from a specific user.
 * @param {string} requesterId - ID of the user whose request to decline
 */
export const declineFollowRequest = async (requesterId) => {
  const response = await api.post(`/follow/requests/${requesterId}/decline`);
  return response.data; // { success, message }
};

/**
 * Cancel a follow request you previously sent.
 * @param {string} userId - ID of the user you sent the request to
 */
export const cancelFollowRequest = async (userId) => {
  const response = await api.delete(`/follow/request/${userId}/cancel`);
  emitFollowStatusChanged({ userId, state: 'not_following' });
  return response.data; // { success, message }
};

export default {
  checkFollowStatus,
  bulkCheckFollowStatus,
  getFollowers,
  getFollowing,
  followUser,
  unfollowUser,
  removeFollower,
  getSuggestions,
  getFollowCounts,
  // Privacy
  toggleAccountPrivacy,
  setAccountPrivacy,
  getPrivacyStatus,
  // Follow Requests
  getFollowRequests,
  acceptFollowRequest,
  declineFollowRequest,
  cancelFollowRequest,
};
