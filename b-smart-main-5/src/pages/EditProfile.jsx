import React, { useState, useEffect } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { useDispatch, useSelector } from 'react-redux';
import { supabase } from '../lib/supabase';
import { setUser } from '../store/authSlice';
import { ArrowLeft, Camera, Loader2 } from 'lucide-react';

const EditProfile = () => {
  const navigate = useNavigate();
  const dispatch = useDispatch();
  const { userObject } = useSelector((state) => state.auth);
  
  const [loading, setLoading] = useState(false);
  const [uploading, setUploading] = useState(false);
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

  const uploadAvatar = async (event) => {
    try {
      setUploading(true);

      if (!event.target.files || event.target.files.length === 0) {
        throw new Error('You must select an image to upload.');
      }

      const file = event.target.files[0];
      const fileExt = file.name.split('.').pop();
      const fileName = `${Math.random()}.${fileExt}`;
      const filePath = `${userObject.id}/${fileName}`;

      let { error: uploadError } = await supabase.storage
        .from('avatars')
        .upload(filePath, file);

      if (uploadError) {
        throw uploadError;
      }

      const { data: { publicUrl } } = supabase.storage
        .from('avatars')
        .getPublicUrl(filePath);

      setForm(prev => ({ ...prev, avatar_url: publicUrl }));
    } catch (error) {
      alert(error.message);
    } finally {
      setUploading(false);
    }
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setLoading(true);

    try {
      const updates = {
        id: userObject.id,
        full_name: form.full_name,
        username: form.username,
        bio: form.bio,
        phone: form.phone,
        avatar_url: form.avatar_url,
        updated_at: new Date(),
      };

      const { error } = await supabase.from('users').upsert(updates);

      if (error) {
        throw error;
      }

      // Update Redux state
      dispatch(setUser({ ...userObject, ...updates }));
      navigate('/profile');
    } catch (error) {
      alert(error.message);
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
          <div className="relative group cursor-pointer">
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
            
            <label className="absolute inset-0 cursor-pointer" htmlFor="avatar-upload">
              <input
                type="file"
                id="avatar-upload"
                accept="image/*"
                onChange={uploadAvatar}
                disabled={uploading}
                className="hidden"
              />
            </label>
          </div>
          
          <button 
            className="text-insta-pink font-semibold text-sm"
            onClick={() => document.getElementById('avatar-upload').click()}
            disabled={uploading}
          >
            {uploading ? (
              <span className="flex items-center gap-2">
                <Loader2 className="animate-spin" size={14} />
                Uploading...
              </span>
            ) : 'Change Profile Photo'}
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
    </div>
  );
};

export default EditProfile;