import api from '../lib/api';

export const getConversations = async (type = 'normal') => {
  const response = await api.get('/chat/conversations', {
    params: { type },
  });
  return response.data;
};

export const createOrGetConversation = async (participantId) => {
  const response = await api.post('/chat/conversations', { participantId });
  return response.data;
};

export const getOnlineUsers = async (ids = []) => {
  const normalizedIds = Array.isArray(ids) ? ids.filter(Boolean) : [];
  const response = await api.get('/chat/online-users', {
    params: normalizedIds.length ? { ids: normalizedIds.join(',') } : {},
  });
  return response.data;
};

export const createGroupConversation = async (payload) => {
  const response = await api.post('/chat/groups', payload);
  return response.data;
};

export const shareContentToUsers = async (payload) => {
  const response = await api.post('/chat/share', payload);
  return response.data;
};

export const updateGroupConversation = async (conversationId, payload) => {
  const response = await api.patch(`/chat/groups/${conversationId}`, payload);
  return response.data;
};

export const addGroupMember = async (conversationId, userId) => {
  const response = await api.post(`/chat/groups/${conversationId}/members`, { userId });
  return response.data;
};

export const removeGroupMember = async (conversationId, userId) => {
  const response = await api.delete(`/chat/groups/${conversationId}/members/${userId}`);
  return response.data;
};

export const leaveGroupConversation = async (conversationId) => {
  const response = await api.post(`/chat/groups/${conversationId}/leave`);
  return response.data;
};

export const deleteGroupConversationForUser = async (conversationId) => {
  const response = await api.delete(`/chat/groups/${conversationId}/delete`);
  return response.data;
};

export const acceptMessageRequest = async (conversationId) => {
  const response = await api.put(`/chat/conversations/${conversationId}/accept`);
  return response.data;
};

export const declineMessageRequest = async (conversationId) => {
  const response = await api.delete(`/chat/conversations/${conversationId}/decline`);
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

export const addMessageReaction = async (messageId, emoji) => {
  const response = await api.post(`/chat/messages/${messageId}/reaction`, { emoji });
  return response.data;
};

export const removeMessageReaction = async (messageId) => {
  const response = await api.delete(`/chat/messages/${messageId}/reaction`);
  return response.data;
};

export const deleteMessage = async (messageId) => {
  const response = await api.delete(`/chat/messages/${messageId}`);
  return response.data;
};

export const uploadChatMedia = async (conversationId, files) => {
  const formData = new FormData();
  const fileList = Array.isArray(files) ? files : [files];
  fileList.filter(Boolean).forEach((file) => {
    formData.append('media', file);
  });

  const response = await api.post(`/chat/conversations/${conversationId}/media`, formData, {
    headers: {
      'Content-Type': 'multipart/form-data',
    },
  });

  return response.data;
};

export const uploadVoiceMessage = async (conversationId, audioBlob, duration) => {
  const formData = new FormData();
  formData.append('audio', audioBlob, 'voice-message.webm');
  formData.append('duration', String(Math.round(duration)));

  const response = await api.post(`/chat/conversations/${conversationId}/voice`, formData, {
    headers: {
      'Content-Type': 'multipart/form-data',
    },
  });

  return response.data;
};
