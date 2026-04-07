import axios from 'axios';

const API_BASE_URL = import.meta.env.VITE_API_URL || 'https://api.bebsmart.in/api';

// Create an Axios instance
const api = axios.create({
	baseURL: API_BASE_URL,
	headers: {
		'Content-Type': 'application/json',
	},
});

// Add a request interceptor to attach the token
api.interceptors.request.use(
	(config) => {
		const token = localStorage.getItem('token');
		if (token) {
			config.headers.Authorization = `Bearer ${token}`;
		}
		return config;
	},
	(error) => {
		return Promise.reject(error);
	}
);

// Add a response interceptor to handle 401 errors (optional but good practice)
api.interceptors.response.use(
	(response) => response,
	(error) => {
		if (error.response && error.response.status === 401) {
			// Handle unauthorized access (e.g., clear token and redirect to login)
			localStorage.removeItem('token');
			window.location.href = '/login'; // Force redirect
		}
		return Promise.reject(error);
	}
);

export default api;
