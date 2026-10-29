import { createSlice } from '@reduxjs/toolkit';

// status: 'idle' | 'outgoing-ringing' | 'incoming-ringing' | 'connecting' | 'active' | 'ended'
const initialState = {
  status: 'idle',
  callId: null,
  callType: 'voice',
  peer: null, // { id, name, avatar }
  error: null,
};

const callSlice = createSlice({
  name: 'call',
  initialState,
  reducers: {
    startOutgoingCall: (state, action) => {
      const { callId, peer, callType } = action.payload;
      state.status = 'outgoing-ringing';
      state.callId = callId;
      state.peer = peer;
      state.callType = callType || 'voice';
      state.error = null;
    },
    receiveIncomingCall: (state, action) => {
      const { callId, peer, callType } = action.payload;
      state.status = 'incoming-ringing';
      state.callId = callId;
      state.peer = peer;
      state.callType = callType || 'voice';
      state.error = null;
    },
    setCallConnecting: (state) => {
      if (state.status === 'idle') return;
      state.status = 'connecting';
    },
    setCallActive: (state) => {
      if (state.status === 'idle') return;
      state.status = 'active';
    },
    setCallError: (state, action) => {
      state.error = action.payload || 'Call failed';
    },
    endCall: (state) => {
      state.status = 'idle';
      state.callId = null;
      state.peer = null;
      state.error = null;
    },
  },
});

export const {
  startOutgoingCall,
  receiveIncomingCall,
  setCallConnecting,
  setCallActive,
  setCallError,
  endCall,
} = callSlice.actions;

export default callSlice.reducer;
