import api from '../lib/api';

const commentService = {
  // ── Get all comments for an ad ──────────────────────────────────────────────
  getComments: async (adId) => {
    const response = await api.get(`/ads/${adId}/comments`);
    return response.data;
  },

  // ── Post a new comment or reply ─────────────────────────────────────────────
  // Pass parentId when replying to an existing comment
  createComment: async (adId, text, parentId = null) => {
    const body = { text };
    if (parentId) {
      body.parent_id = parentId;
    }
    const response = await api.post(`/ads/${adId}/comments`, body);
    return response.data;
  },

  // ── Get replies for a specific comment ──────────────────────────────────────
  // ── Get replies for a specific comment ──────────────────────────────────────
  getReplies: async (commentId) => {
    const response = await api.get(`/ads/comments/${commentId}/replies`);
    return response.data;
  },

  // ── Like a comment ──────────────────────────────────────────────────────────
  likeComment: async (commentId) => {
    const response = await api.post(`/ads/comments/${commentId}/like`);
    return response.data;
  },

  // ── Unlike a comment ────────────────────────────────────────────────────────
  unlikeComment: async (commentId) => {
    const response = await api.post(`/ads/comments/${commentId}/unlike`);
    return response.data;
  },

  deleteComment: async (commentId) => {
    const response = await api.delete(`/ads/comments/${commentId}`);
    return response.data;
  },
};

export default commentService;
