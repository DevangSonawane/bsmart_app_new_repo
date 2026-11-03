import api from '../lib/api';

export const getGroupCallHistory = async (page = 1, limit = 20) => {
  const response = await api.get('/group-calls', { params: { page, limit } });
  return response.data;
};

export const getGroupCallById = async (groupCallId) => {
  const response = await api.get(`/group-calls/${groupCallId}`);
  return response.data;
};

// Publishes my local track(s) (from my WebRTC offer) to Cloudflare
// Realtime. `tracks` is [{ mid, kind }]. Returns { success, sdpAnswer }.
export const publishTrack = async (groupCallId, sdpOffer, tracks) => {
  const response = await api.post(`/group-calls/${groupCallId}/webrtc/publish`, { sdpOffer, tracks });
  return response.data;
};

// Pulls one specific joined peer's published track(s) into my session.
// Called once per peer. Returns { success, requiresImmediateRenegotiation, sdpOffer }.
export const pullTrack = async (groupCallId, fromUserId) => {
  const response = await api.post(`/group-calls/${groupCallId}/webrtc/pull`, { fromUserId });
  return response.data;
};

// Answers a renegotiation offer returned by pullTrack().
export const renegotiate = async (groupCallId, sdpAnswer) => {
  const response = await api.put(`/group-calls/${groupCallId}/webrtc/renegotiate`, { sdpAnswer });
  return response.data;
};
