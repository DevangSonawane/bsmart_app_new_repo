import { createSlice } from '@reduxjs/toolkit';

// status: 'idle' | 'outgoing-ringing' | 'incoming-ringing' | 'active'
// participants: { [userId]: { name, avatar, status: 'invited'|'joined'|'declined'|'missed'|'left' } }
// — unlike callSlice's single `peer`, a group call's roster is keyed by
// user id since it grows/shrinks as people join and leave.
const initialState = {
  status: 'idle',
  groupCallId: null,
  conversationId: null,
  conversationTitle: '',
  conversationAvatar: '',
  callType: 'voice',
  initiator: null, // { id, name, avatar } — who started it, for the incoming-ring banner
  participants: {},
  error: null,
};

const groupCallSlice = createSlice({
  name: 'groupCall',
  initialState,
  reducers: {
    startOutgoingGroupCall: (state, action) => {
      const { groupCallId, conversationId, conversationTitle, conversationAvatar, callType } = action.payload;
      state.status = 'outgoing-ringing';
      state.groupCallId = groupCallId;
      state.conversationId = conversationId;
      state.conversationTitle = conversationTitle || '';
      state.conversationAvatar = conversationAvatar || '';
      state.callType = callType || 'voice';
      state.initiator = null;
      state.participants = {};
      state.error = null;
    },
    receiveIncomingGroupCall: (state, action) => {
      const { groupCallId, conversationId, conversationTitle, conversationAvatar, callType, initiator } = action.payload;
      state.status = 'incoming-ringing';
      state.groupCallId = groupCallId;
      state.conversationId = conversationId;
      state.conversationTitle = conversationTitle || '';
      state.conversationAvatar = conversationAvatar || '';
      state.callType = callType || 'voice';
      state.initiator = initiator || null;
      state.participants = {};
      state.error = null;
    },
    setGroupCallActive: (state, action) => {
      if (state.status === 'idle') return;
      state.status = 'active';
      // Seed the roster with whoever was already joined when I joined.
      (action.payload?.roster || []).forEach((p) => {
        state.participants[p.userId] = { name: p.name, avatar: p.avatar, status: 'joined' };
      });
    },
    upsertGroupCallParticipant: (state, action) => {
      const { userId, name, avatar, status } = action.payload;
      state.participants[userId] = { ...(state.participants[userId] || {}), name, avatar, status };
    },
    removeGroupCallParticipant: (state, action) => {
      delete state.participants[action.payload.userId];
    },
    setGroupCallError: (state, action) => {
      state.error = action.payload || 'Call failed';
    },
    endGroupCall: (state) => {
      state.status = 'idle';
      state.groupCallId = null;
      state.conversationId = null;
      state.initiator = null;
      state.participants = {};
      state.error = null;
    },
  },
});

export const {
  startOutgoingGroupCall,
  receiveIncomingGroupCall,
  setGroupCallActive,
  upsertGroupCallParticipant,
  removeGroupCallParticipant,
  setGroupCallError,
  endGroupCall,
} = groupCallSlice.actions;

export default groupCallSlice.reducer;
