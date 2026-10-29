import api from '../lib/api';

export const getCallHistory = async (page = 1, limit = 20) => {
  const response = await api.get('/calls', { params: { page, limit } });
  return response.data;
};

export const getCallById = async (callId) => {
  const response = await api.get(`/calls/${callId}`);
  return response.data;
};

export const checkCanCall = async (userId) => {
  const response = await api.get(`/calls/can-call/${userId}`);
  return response.data;
};

// Publishes my local audio track (from my WebRTC offer) to Cloudflare
// Realtime. Returns { success, sdpAnswer }.
export const publishTrack = async (callId, sdpOffer, mid) => {
  const response = await api.post(`/calls/${callId}/webrtc/publish`, { sdpOffer, mid });
  return response.data;
};

// Pulls the other party's published audio track into my session. Returns
// { success, requiresImmediateRenegotiation, sdpOffer }.
export const pullTrack = async (callId) => {
  const response = await api.post(`/calls/${callId}/webrtc/pull`);
  return response.data;
};

// Answers a renegotiation offer returned by pullTrack().
export const renegotiate = async (callId, sdpAnswer) => {
  const response = await api.put(`/calls/${callId}/webrtc/renegotiate`, { sdpAnswer });
  return response.data;
};
