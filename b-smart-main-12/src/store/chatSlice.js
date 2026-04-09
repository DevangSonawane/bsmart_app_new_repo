import { createSlice } from '@reduxjs/toolkit';

const initialState = {
  conversations: [],
  activeConversation: null,
  messages: [],
  page: 1,
  hasMore: true,
  isLoadingConversations: false,
  isLoadingMessages: false,
  typingUsers: {},
  unreadCounts: {},
};

const chatSlice = createSlice({
  name: 'chat',
  initialState,
  reducers: {
    setConversations: (state, action) => {
      state.conversations = Array.isArray(action.payload) ? action.payload : [];
      state.unreadCounts = state.conversations.reduce((acc, conversation) => {
        acc[conversation._id] = Number(conversation.unreadCount || 0);
        return acc;
      }, {});
    },
    setActiveConversation: (state, action) => {
      state.activeConversation = action.payload || null;
    },
    setMessages: (state, action) => {
      state.messages = Array.isArray(action.payload) ? action.payload : [];
    },
    appendMessage: (state, action) => {
      if (!action.payload) return;
      const messageId = action.payload._id;
      if (messageId && state.messages.some((message) => message._id === messageId)) {
        state.messages = state.messages.map((message) =>
          message._id === messageId ? { ...message, ...action.payload } : message
        );
        return;
      }
      state.messages.push(action.payload);
    },
    removeMessage: (state, action) => {
      const messageId = typeof action.payload === 'string' ? action.payload : action.payload?.messageId;
      if (!messageId) return;
      state.messages = state.messages.map((message) =>
        message._id === messageId
          ? { ...message, isDeleted: true, deletedAt: action.payload?.deletedAt || new Date().toISOString() }
          : message
      );
    },
    setPage: (state, action) => {
      state.page = action.payload;
    },
    setHasMore: (state, action) => {
      state.hasMore = Boolean(action.payload);
    },
    setIsLoadingConversations: (state, action) => {
      state.isLoadingConversations = Boolean(action.payload);
    },
    setIsLoadingMessages: (state, action) => {
      state.isLoadingMessages = Boolean(action.payload);
    },
    setTypingUser: (state, action) => {
      const { conversationId, userId, isTyping } = action.payload || {};
      if (!conversationId || !userId) return;
      const current = new Set(state.typingUsers[conversationId] || []);
      if (isTyping) current.add(userId);
      else current.delete(userId);
      state.typingUsers[conversationId] = Array.from(current);
    },
    setUnreadCount: (state, action) => {
      const { conversationId, count } = action.payload || {};
      if (!conversationId) return;
      state.unreadCounts[conversationId] = Number(count || 0);
      state.conversations = state.conversations.map((conversation) =>
        conversation._id === conversationId
          ? { ...conversation, unreadCount: Number(count || 0) }
          : conversation
      );
    },
    markConversationRead: (state, action) => {
      const conversationId = action.payload;
      if (!conversationId) return;
      state.unreadCounts[conversationId] = 0;
      state.conversations = state.conversations.map((conversation) =>
        conversation._id === conversationId
          ? { ...conversation, unreadCount: 0 }
          : conversation
      );
    },
    updateLastMessage: (state, action) => {
      const { conversationId, lastMessage, lastMessageAt } = action.payload || {};
      if (!conversationId) return;
      state.conversations = state.conversations
        .map((conversation) =>
          conversation._id === conversationId
            ? {
                ...conversation,
                lastMessage: lastMessage ?? conversation.lastMessage ?? null,
                lastMessageAt: lastMessageAt || lastMessage?.createdAt || conversation.lastMessageAt,
              }
            : conversation
        )
        .sort((a, b) => new Date(b.lastMessageAt || 0) - new Date(a.lastMessageAt || 0));

      if (state.activeConversation?._id === conversationId) {
        state.activeConversation = {
          ...state.activeConversation,
          lastMessage: lastMessage ?? state.activeConversation.lastMessage ?? null,
          lastMessageAt:
            lastMessageAt || lastMessage?.createdAt || state.activeConversation.lastMessageAt,
        };
      }
    },
  },
});

export const {
  setConversations,
  setActiveConversation,
  setMessages,
  appendMessage,
  removeMessage,
  setPage,
  setHasMore,
  setIsLoadingConversations,
  setIsLoadingMessages,
  setTypingUser,
  setUnreadCount,
  markConversationRead,
  updateLastMessage,
} = chatSlice.actions;

export default chatSlice.reducer;
