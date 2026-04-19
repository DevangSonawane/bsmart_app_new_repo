import api from '../lib/api';

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
  return response.data;
};

export const unfollowUser = async (userId) => {
  const response = await api.post('/unfollow', { followedUserId: userId });
  return response.data;
};

export const removeFollower = async (followerId) => {
  const response = await api.delete(`/follows/remove/${followerId}`);
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
};
