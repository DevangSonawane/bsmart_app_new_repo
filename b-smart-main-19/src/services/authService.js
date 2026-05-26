import api from '../lib/api';
import { disconnectChatSocket } from '../socket/chatSocket';
import { unregisterPush } from './pushService';

const authService = {
  login: async (credentials) => {
    const response = await api.post('/auth/login', credentials);
    if (response.data.token) {
      localStorage.setItem('token', response.data.token);
      api.defaults.headers.common['Authorization'] = `Bearer ${response.data.token}`;
    }
    return response.data;
  },
  logout: async () => {
    // Clear push tokens on backend before wiping local token
    await unregisterPush().catch(() => {});
    disconnectChatSocket();
    localStorage.removeItem('token');
    delete api.defaults.headers.common['Authorization'];
  },
  getMe: async () => {
    const response = await api.get('/auth/me');
    return response.data;
  },
  setSession: (token) => {
    if (token) {
      localStorage.setItem('token', token);
      api.defaults.headers.common['Authorization'] = `Bearer ${token}`;
    } else {
      localStorage.removeItem('token');
      delete api.defaults.headers.common['Authorization'];
    }
  }
};

export default authService;