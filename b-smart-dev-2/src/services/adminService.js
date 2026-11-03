import api from '../lib/api';

const adminService = {
  listInfluencers: async ({ page = 1, limit = 20, search = '' } = {}) => {
    const { data } = await api.get('/admin/users', { params: { role: 'influencer', page, limit, ...(search ? { search } : {}) } });
    return {
      users: Array.isArray(data?.data) ? data.data : [],
      total: Number(data?.total ?? 0),
      pages: Number(data?.pages ?? 1),
    };
  },
  setInfluencerSuspended: async (userId, suspended, reason = '') => {
    const { data } = await api.patch(`/users/${userId}/suspend-influencer`, { suspended, ...(suspended ? { reason } : {}) });
    return data;
  },
};

export default adminService;
