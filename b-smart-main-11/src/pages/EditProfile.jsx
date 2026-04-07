import React, { useState, useEffect } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { useDispatch, useSelector } from 'react-redux';
import api from '../lib/api';
import AvatarCropModal from '../components/AvatarCropModal';
import { fetchMe, setUser } from '../store/authSlice';
import { ArrowLeft, Camera } from 'lucide-react';

const EditProfile = () => {
  const navigate = useNavigate();
  const dispatch = useDispatch();
  const { userObject } = useSelector((state) => state.auth);
  const userId = userObject?._id || userObject?.id || '';
  
  const [loading, setLoading] = useState(false);
  const [showAvatarModal, setShowAvatarModal] = useState(false);
  const [form, setForm] = useState({
    full_name: '',
    username: '',
    bio: '',
    phone: '',
    avatar_url: ''
  });

  useEffect(() => {
    if (userObject) {
      setForm({
        full_name: userObject.full_name || '',
        username: userObject.username || '',
        bio: userObject.bio || '',
        phone: userObject.phone || '',
        avatar_url: userObject.avatar_url || ''
      });
    }
  }, [userObject]);

  const handleChange = (e) => {
    const { name, value } = e.target;
    setForm(prev => ({ ...prev, [name]: value }));
  };

  const handleSubmit = async (e) => {
    if (e?.preventDefault) e.preventDefault();

    if (!userId) {
      alert('User session not found. Please login again.');
      return;
    }

    setLoading(true);

    try {
      const updates = {
        full_name: form.full_name.trim(),
        username: form.username.trim(),
        bio: form.bio,
        phone: form.phone.trim(),
        avatar_url: form.avatar_url,
      };

      const { data } = await api.put(`/users/${userId}`, updates);
      const updatedUser = data?.user || data?.data || data || { ...userObject, ...updates };

      dispatch(setUser({ ...userObject, ...updatedUser }));
      dispatch(fetchMe());
      navigate('/profile');
    } catch (error) {
      alert(error?.response?.data?.message || error.message || 'Failed to update profile.');
    } finally {
      setLoading(false);
    }
  };

  const getInitials = (name) => {
    if (!name) return 'U';
    return name.split(' ').map((n) => n[0]).join('').toUpperCase().substring(0, 2);
  };

  return (
    <div className="min-h-screen bg-gray-50 dark:bg-black pb-20">
      {/* Header */}
      <div className="sticky top-0 bg-white dark:bg-black border-b border-gray-200 dark:border-gray-800 px-4 py-3 flex items-center justify-between z-40">
        <div className="flex items-center gap-3">
          <Link to="/profile" className="text-gray-800 dark:text-white">
            <ArrowLeft size={24} />
          </Link>
          <h1 className="text-lg font-semibold dark:text-white">Edit Profile</h1>
        </div>
        <button 
          onClick={handleSubmit}
          disabled={loading}
          className="text-insta-pink font-semibold disabled:opacity-50"
        >
          {loading ? 'Saving...' : 'Save'}
        </button>
      </div>

      <div className="max-w-xl mx-auto p-4">
        {/* Avatar Section */}
        <div className="flex flex-col items-center mb-8">
          <div className="relative group cursor-pointer" onClick={() => setShowAvatarModal(true)}>
            <div className="w-24 h-24 rounded-full p-[2px] bg-gradient-to-tr from-insta-yellow via-insta-orange to-insta-pink mb-3">
              <div className="w-full h-full rounded-full bg-white dark:bg-black p-[2px] overflow-hidden relative">
                {form.avatar_url ? (
                  <img
                    src={form.avatar_url}
                    className="w-full h-full rounded-full object-cover"
                    alt="Profile"
                  />
                ) : (
                  <div className="w-full h-full bg-gray-100 dark:bg-gray-800 flex items-center justify-center text-2xl font-bold text-gray-500 dark:text-gray-400">
                    {getInitials(form.full_name || form.username)}
                  </div>
                )}
                
                {/* Upload Overlay */}
                <div className="absolute inset-0 bg-black/30 flex items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity">
                  <Camera className="text-white" size={24} />
                </div>
              </div>
            </div>
          </div>
          
          <button 
            className="text-insta-pink font-semibold text-sm"
            onClick={() => setShowAvatarModal(true)}
          >
            Change Profile Photo
          </button>
        </div>

        {/* Form Fields */}
        <form onSubmit={handleSubmit} className="space-y-6">
          <div className="space-y-1">
            <label className="text-sm font-medium text-gray-700 dark:text-gray-300">Name</label>
            <input
              type="text"
              name="full_name"
              value={form.full_name}
              onChange={handleChange}
              placeholder="Your full name"
              className="w-full px-4 py-3 bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-800 rounded-xl focus:outline-none focus:ring-2 focus:ring-insta-pink/20 focus:border-insta-pink transition-all dark:text-white"
            />
          </div>

          <div className="space-y-1">
            <label className="text-sm font-medium text-gray-700 dark:text-gray-300">Username</label>
            <input
              type="text"
              name="username"
              value={form.username}
              onChange={handleChange}
              placeholder="Username"
              className="w-full px-4 py-3 bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-800 rounded-xl focus:outline-none focus:ring-2 focus:ring-insta-pink/20 focus:border-insta-pink transition-all dark:text-white"
            />
          </div>

          <div className="space-y-1">
            <label className="text-sm font-medium text-gray-700 dark:text-gray-300">Bio</label>
            <textarea
              name="bio"
              value={form.bio}
              onChange={handleChange}
              placeholder="Write something about yourself..."
              rows={3}
              className="w-full px-4 py-3 bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-800 rounded-xl focus:outline-none focus:ring-2 focus:ring-insta-pink/20 focus:border-insta-pink transition-all resize-none dark:text-white"
            />
          </div>

          <div className="space-y-1">
            <label className="text-sm font-medium text-gray-700 dark:text-gray-300">Phone</label>
            <input
              type="tel"
              name="phone"
              value={form.phone}
              onChange={handleChange}
              placeholder="Phone number"
              className="w-full px-4 py-3 bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-800 rounded-xl focus:outline-none focus:ring-2 focus:ring-insta-pink/20 focus:border-insta-pink transition-all dark:text-white"
            />
          </div>
        </form>
      </div>

      <AvatarCropModal
        isOpen={showAvatarModal}
        onClose={() => setShowAvatarModal(false)}
        currentAvatar={form.avatar_url}
        userName={form.full_name || form.username}
        onSuccess={(newAvatarUrl) => {
          const safeUrl = newAvatarUrl || form.avatar_url;
          setForm((prev) => ({ ...prev, avatar_url: safeUrl }));
          dispatch(setUser({ ...userObject, avatar_url: safeUrl }));
        }}
      />
    </div>
  );
};

export default EditProfile;
