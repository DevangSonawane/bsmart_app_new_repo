import axios from 'axios';

// Create an Axios instance
const api = axios.create({
	baseURL: 'https://bsmart.asynk.store/api', // Default to localhost:5000 if not set
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
