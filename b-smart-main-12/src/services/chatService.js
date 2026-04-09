import api from '../lib/api';

export const getConversations = async () => {
  const response = await api.get('/chat/conversations');
  return response.data;
};

export const createOrGetConversation = async (participantId) => {
  const response = await api.post('/chat/conversations', { participantId });
  return response.data;
};

export const getMessages = async (conversationId, page = 1, limit = 20) => {
  const response = await api.get(`/chat/conversations/${conversationId}/messages`, {
    params: { page, limit },
  });
  return response.data;
};

export const sendMessage = async (conversationId, payload) => {
  const response = await api.post(`/chat/conversations/${conversationId}/messages`, payload);
  return response.data;
};

export const markMessageSeen = async (messageId) => {
  const response = await api.put(`/chat/messages/${messageId}/seen`);
  return response.data;
};

export const deleteMessage = async (messageId) => {
  const response = await api.delete(`/chat/messages/${messageId}`);
  return response.data;
};

export const uploadChatMedia = async (conversationId, file) => {
  const formData = new FormData();
  formData.append('media', file);

  const response = await api.post(`/chat/conversations/${conversationId}/media`, formData, {
    headers: {
      'Content-Type': 'multipart/form-data',
    },
  });

  return response.data;
};
