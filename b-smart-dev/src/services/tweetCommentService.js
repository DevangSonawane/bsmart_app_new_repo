import api from '../lib/api';

const tweetCommentService = {
  getComments: async (tweetId) => {
    const response = await api.get(`/tweets/${tweetId}/comments`);
    return response.data;
  },

  createComment: async (tweetId, text, parentId = null) => {
    const body = { text };
    if (parentId) {
      body.parent_id = parentId;
    }
    const response = await api.post(`/tweets/${tweetId}/comments`, body);
    return response.data;
  },

  getReplies: async (commentId) => {
    const response = await api.get(`/tweets/comments/${commentId}/replies`);
    return response.data;
  },

  likeComment: async (commentId) => {
    const response = await api.post(`/tweets/comments/${commentId}/like`);
    return response.data;
  },

  unlikeComment: async (commentId) => {
    const response = await api.post(`/tweets/comments/${commentId}/unlike`);
    return response.data;
  },

  deleteComment: async (commentId) => {
    const response = await api.delete(`/tweets/comments/${commentId}`);
    return response.data;
  },
};

export default tweetCommentService;
