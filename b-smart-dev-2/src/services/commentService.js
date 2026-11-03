import api from '../lib/api';

const commentService = {
  getComments: async (postId) => {
    const response = await api.get(`/posts/${postId}/comments`);
    return response.data;
  },

  createComment: async (postId, text, parentId = null) => {
    const body = { text };
    if (parentId) {
      body.parent_id = parentId;
    }
    const response = await api.post(`/posts/${postId}/comments`, body);
    return response.data;
  },

  getReplies: async (commentId) => {
    const response = await api.get(`/comments/${commentId}/replies`);
    return response.data;
  },

  likeComment: async (commentId) => {
    const response = await api.post(`/comments/${commentId}/like`);
    return response.data;
  },

  unlikeComment: async (commentId) => {
    const response = await api.post(`/comments/${commentId}/unlike`);
    return response.data;
  }
};

export default commentService;