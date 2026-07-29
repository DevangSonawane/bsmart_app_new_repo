import React, { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { ArrowLeft, LogOut, PauseCircle, Trash2, Loader2, AlertTriangle } from 'lucide-react';
import { useDispatch } from 'react-redux';
import api from '../../lib/api';

const SectionTitle = ({ title }) => (
  <p className="text-[11px] font-bold text-[#fa3f5e] uppercase tracking-widest mb-2 px-1">{title}</p>
);

const ConfirmDialog = ({ open, onClose, title, description, confirmLabel, confirmClass, onConfirm, loading }) => {
  if (!open) return null;
  return (
    <div className="fixed inset-0 z-[9999] flex items-center justify-center px-4">
      <div className="absolute inset-0 bg-black/50 backdrop-blur-sm" onClick={onClose} />
      <div className="relative w-full max-w-sm bg-white dark:bg-gray-900 rounded-2xl shadow-2xl overflow-hidden">
        <div className="p-6 text-center">
          <div className="w-14 h-14 rounded-full bg-red-50 dark:bg-red-900/20 border-2 border-red-200 dark:border-red-800 flex items-center justify-center mx-auto mb-4">
            <AlertTriangle size={24} className="text-red-500" />
          </div>
          <h3 className="text-base font-bold text-gray-900 dark:text-white mb-1">{title}</h3>
          <p className="text-sm text-gray-500 dark:text-gray-400 leading-relaxed">{description}</p>
        </div>
        <div className="flex border-t border-gray-100 dark:border-gray-800">
          <button
            onClick={onClose}
            className="flex-1 py-3.5 text-sm font-semibold text-gray-700 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors border-r border-gray-100 dark:border-gray-800"
          >
            Cancel
          </button>
          <button
            onClick={onConfirm}
            disabled={loading}
            className={`flex-1 py-3.5 text-sm font-bold flex items-center justify-center gap-2 disabled:opacity-60 ${confirmClass}`}
          >
            {loading && <Loader2 size={14} className="animate-spin" />}
            {confirmLabel}
          </button>
        </div>
      </div>
    </div>
  );
};

const AccountActionsSettings = () => {
  const dispatch   = useDispatch();
  const navigate   = useNavigate();

  const [showLogout,     setShowLogout]     = useState(false);
  const [showDeactivate, setShowDeactivate] = useState(false);
  const [showDelete,     setShowDelete]     = useState(false);
  const [logoutLoading,     setLogoutLoading]     = useState(false);
  const [deactivateLoading, setDeactivateLoading] = useState(false);
  const [deleteLoading,     setDeleteLoading]     = useState(false);

  const handleLogout = async () => {
    setLogoutLoading(true);
    try {
      await api.post('/auth/logout').catch(() => {});
    } finally {
      localStorage.removeItem('token');
      dispatch({ type: 'auth/logout' });
      navigate('/login', { replace: true });
    }
  };

  const handleDeactivate = async () => {
    setDeactivateLoading(true);
    try {
      await api.post('/users/deactivate');
      localStorage.removeItem('token');
      dispatch({ type: 'auth/logout' });
      navigate('/login', { replace: true });
    } catch (e) {
      console.error('Deactivate failed:', e?.response?.data?.message);
      setDeactivateLoading(false);
      setShowDeactivate(false);
    }
  };

  const handleDelete = async () => {
    setDeleteLoading(true);
    try {
      await api.delete('/users/me');
      localStorage.removeItem('token');
      dispatch({ type: 'auth/logout' });
      navigate('/login', { replace: true });
    } catch (e) {
      console.error('Delete failed:', e?.response?.data?.message);
      setDeleteLoading(false);
      setShowDelete(false);
    }
  };

  return (
    <div className="min-h-screen bg-gray-50 dark:bg-black pb-24 max-w-[1100px] mx-auto">

      {/* Header */}
      <div className="sticky top-0 bg-white dark:bg-black border-b border-gray-100 dark:border-gray-800 px-4 py-3 flex items-center justify-between z-40">
        <Link to="/settings" className="text-gray-800 dark:text-white p-1">
          <ArrowLeft size={22} />
        </Link>
        <h1 className="text-base font-semibold dark:text-white">Account Actions</h1>
        <div className="w-8" />
      </div>

      <div className="max-w-2xl mx-auto px-4 pt-5 space-y-5">

        {/* ── Session Controls ── */}
        <div>
          <SectionTitle title="Session Controls" />
          <div className="bg-white dark:bg-gray-900 rounded-2xl border border-gray-100 dark:border-gray-800 shadow-sm overflow-hidden">
            <button
              onClick={() => setShowLogout(true)}
              className="w-full flex items-center gap-3 px-4 py-3.5 hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors"
            >
              <div className="w-9 h-9 rounded-full flex items-center justify-center flex-shrink-0 bg-orange-50 dark:bg-gray-800">
                <LogOut size={16} className="text-orange-500" />
              </div>
              <div className="text-left">
                <p className="text-sm font-medium text-orange-500">Logout</p>
                <p className="text-xs text-gray-500 dark:text-gray-400 mt-0.5">Sign out of your current session</p>
              </div>
            </button>
          </div>
        </div>

        {/* ── Account Controls ── */}
        <div>
          <SectionTitle title="Account Controls" />
          <div className="bg-white dark:bg-gray-900 rounded-2xl border border-gray-100 dark:border-gray-800 shadow-sm overflow-hidden">

            <button
              onClick={() => setShowDeactivate(true)}
              className="w-full flex items-center gap-3 px-4 py-3.5 border-b border-gray-100 dark:border-gray-800 hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors"
            >
              <div className="w-9 h-9 rounded-full flex items-center justify-center flex-shrink-0 bg-yellow-50 dark:bg-gray-800">
                <PauseCircle size={16} className="text-yellow-600" />
              </div>
              <div className="text-left">
                <p className="text-sm font-medium text-yellow-600 dark:text-yellow-500">Deactivate Account</p>
                <p className="text-xs text-gray-500 dark:text-gray-400 mt-0.5">Temporarily hide your profile and content</p>
              </div>
            </button>

            <button
              onClick={() => setShowDelete(true)}
              className="w-full flex items-center gap-3 px-4 py-3.5 hover:bg-red-50 dark:hover:bg-red-900/10 transition-colors"
            >
              <div className="w-9 h-9 rounded-full flex items-center justify-center flex-shrink-0 bg-red-50 dark:bg-gray-800">
                <Trash2 size={16} className="text-red-500" />
              </div>
              <div className="text-left">
                <p className="text-sm font-medium text-red-500">Delete Account Permanently</p>
                <p className="text-xs text-gray-500 dark:text-gray-400 mt-0.5">This action cannot be undone</p>
              </div>
            </button>

          </div>
          <p className="text-xs text-gray-400 dark:text-gray-500 px-1 mt-2">
            Deleting your account will permanently remove all your posts, messages, and data.
          </p>
        </div>

      </div>

      {/* Confirm Logout */}
      <ConfirmDialog
        open={showLogout}
        onClose={() => setShowLogout(false)}
        title="Log out?"
        description="You will be signed out of your current session. You can log back in at any time."
        confirmLabel="Logout"
        confirmClass="text-orange-500 hover:bg-orange-50 dark:hover:bg-orange-900/20"
        onConfirm={handleLogout}
        loading={logoutLoading}
      />

      {/* Confirm Deactivate */}
      <ConfirmDialog
        open={showDeactivate}
        onClose={() => setShowDeactivate(false)}
        title="Deactivate Account?"
        description="Your profile will be hidden and your content won't be visible until you log back in."
        confirmLabel="Deactivate"
        confirmClass="text-yellow-600 hover:bg-yellow-50 dark:hover:bg-yellow-900/20"
        onConfirm={handleDeactivate}
        loading={deactivateLoading}
      />

      {/* Confirm Delete */}
      <ConfirmDialog
        open={showDelete}
        onClose={() => setShowDelete(false)}
        title="Delete Account Permanently?"
        description="All your posts, messages, followers, and account data will be permanently deleted. This cannot be undone."
        confirmLabel="Delete Forever"
        confirmClass="text-red-500 hover:bg-red-50 dark:hover:bg-red-900/20"
        onConfirm={handleDelete}
        loading={deleteLoading}
      />

    </div>
  );
};

export default AccountActionsSettings;
