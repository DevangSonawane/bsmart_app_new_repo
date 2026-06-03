import api from '../lib/api';

const promoteReelService = {
  // ── CRUD ─────────────────────────────────────────────────────────────────

  listPromoteReels: async ({ page = 1, limit = 20 } = {}) => {
    const res = await api.get('/promote-reels', { params: { page, limit } });
    return res.data;
  },

  getPromoteReelById: async (id) => {
    const res = await api.get(`/promote-reels/${id}`);
    return res.data;
  },

  createPromoteReel: async (payload) => {
    const res = await api.post('/promote-reels', payload);
    return res.data;
  },

  updatePromoteReel: async (id, payload) => {
    const res = await api.patch(`/promote-reels/${id}`, payload);
    return res.data;
  },

  deletePromoteReel: async (id) => {
    const res = await api.delete(`/promote-reels/${id}`);
    return res.data;
  },

  // ── Like / Unlike ────────────────────────────────────────────────────────

  likePromoteReel: async (id) => {
    const res = await api.post(`/promote-reels/${id}/like`);
    return res.data;
  },

  unlikePromoteReel: async (id) => {
    const res = await api.post(`/promote-reels/${id}/unlike`);
    return res.data;
  },

  getPromoteReelLikes: async (id) => {
    const res = await api.get(`/promote-reels/${id}/likes`);
    return res.data;
  },

  // ── Comments ─────────────────────────────────────────────────────────────

  getComments: async (promoteReelId) => {
    const res = await api.get(`/promote-reels/${promoteReelId}/comments`);
    return res.data;
  },

  addComment: async (promoteReelId, text, parentId = null) => {
    const body = { text };
    if (parentId) body.parent_id = parentId;
    const res = await api.post(`/promote-reels/${promoteReelId}/comments`, body);
    return res.data;
  },

  deleteComment: async (commentId) => {
    const res = await api.delete(`/promote-reels/comments/${commentId}`);
    return res.data;
  },

  // ── Replies ──────────────────────────────────────────────────────────────

  getReplies: async (commentId) => {
    const res = await api.get(`/promote-reels/comments/${commentId}/replies`);
    return res.data;
  },

  deleteReply: async (commentId, replyId) => {
    const res = await api.delete(`/promote-reels/comments/${commentId}/replies/${replyId}`);
    return res.data;
  },

  // ── Comment Like / Unlike ────────────────────────────────────────────────

  likeComment: async (commentId) => {
    const res = await api.post(`/promote-reels/comments/${commentId}/like`);
    return res.data;
  },

  unlikeComment: async (commentId) => {
    const res = await api.post(`/promote-reels/comments/${commentId}/unlike`);
    return res.data;
  },
};

export default promoteReelService;
