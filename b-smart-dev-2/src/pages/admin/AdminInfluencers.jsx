import React, { useEffect, useState } from 'react';
import { AlertCircle, Ban, Loader2, RefreshCw, Search, ShieldCheck } from 'lucide-react';
import adminService from '../../services/adminService';

const LIMIT = 20;
const inputCls = 'rounded-xl border border-gray-200 bg-white px-3 py-2 text-sm text-gray-900 focus:outline-none focus:ring-2 focus:ring-[#fa3f5e]/20 dark:border-gray-800 dark:bg-gray-900 dark:text-white';

export default function AdminInfluencers() {
  const [users, setUsers] = useState([]);
  const [pages, setPages] = useState(1);
  const [page, setPage] = useState(1);
  const [search, setSearch] = useState('');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [busyId, setBusyId] = useState('');
  const [suspendingId, setSuspendingId] = useState('');
  const [reason, setReason] = useState('');

  const load = async () => {
    setLoading(true);
    setError('');
    try {
      const result = await adminService.listInfluencers({ page, limit: LIMIT, search });
      setUsers(result.users);
      setPages(result.pages);
    } catch (err) {
      setError(err?.response?.data?.message || 'Could not load influencers.');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { load(); }, [page, search]);

  const setSuspended = async (user, suspended) => {
    const id = user._id || user.id;
    if (suspended && !reason.trim()) {
      setError('Enter a reason before suspending this influencer.');
      return;
    }
    setBusyId(id);
    setError('');
    try {
      await adminService.setInfluencerSuspended(id, suspended, reason.trim());
      setSuspendingId('');
      setReason('');
      await load();
    } catch (err) {
      setError(err?.response?.data?.message || 'Could not update this influencer.');
    } finally {
      setBusyId('');
    }
  };

  return (
    <div className="max-w-[1450px] ml-auto px-4 md:px-8 pt-6 pb-10">
      <div className="mb-5 flex flex-wrap items-center justify-between gap-3">
        <h1 className="text-2xl font-bold text-gray-900 dark:text-white">Influencers</h1>
        <button type="button" onClick={load} className="inline-flex items-center gap-2 text-xs font-semibold text-[#fa3f5e]">
          <RefreshCw size={14} className={loading ? 'animate-spin' : ''} /> Refresh
        </button>
      </div>

      <div className="relative mb-4 max-w-md">
        <Search size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
        <input aria-label="Search influencers" value={search} onChange={(e) => { setSearch(e.target.value); setPage(1); }} placeholder="Search by username" className={`${inputCls} w-full pl-9`} />
      </div>

      {error && <p role="alert" className="mb-4 flex items-center gap-2 rounded-xl border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-600 dark:border-red-900/50 dark:bg-red-900/20 dark:text-red-300"><AlertCircle size={15} />{error}</p>}

      <div className="overflow-x-auto rounded-2xl border border-gray-100 bg-white shadow-sm dark:border-gray-800 dark:bg-gray-900">
        <table className="w-full min-w-[720px] text-sm">
          <thead>
            <tr className="border-b border-gray-100 text-left text-xs font-medium text-gray-500 dark:border-gray-800 dark:text-gray-400">
              <th className="px-4 py-3.5">Influencer</th>
              <th className="px-4 py-3.5">Store</th>
              <th className="px-4 py-3.5">Status</th>
              <th className="px-4 py-3.5 text-right">Action</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-100 dark:divide-gray-800">
            {loading && <tr><td colSpan={4} className="py-12 text-center text-gray-400"><Loader2 size={18} className="mx-auto animate-spin" /></td></tr>}
            {!loading && users.map((user) => {
              const id = user._id || user.id;
              const profile = user.influencer_profile || {};
              const suspended = !!profile.is_suspended;
              const suspending = suspendingId === id;
              return (
                <tr key={id} className="align-top">
                  <td className="px-4 py-4">
                    <p className="font-semibold text-gray-900 dark:text-white">@{user.username}</p>
                    <p className="text-xs text-gray-400">{user.full_name || ''}</p>
                  </td>
                  <td className="px-4 py-4 text-gray-600 dark:text-gray-300">{profile.store_name || '—'}</td>
                  <td className="px-4 py-4">
                    {suspended ? (
                      <div>
                        <span className="inline-flex rounded-md bg-red-500 px-2 py-1 text-[11px] font-bold text-white">Suspended</span>
                        {profile.suspension_reason && <p className="mt-1 max-w-xs text-xs text-gray-500">{profile.suspension_reason}</p>}
                      </div>
                    ) : (
                      <span className="inline-flex rounded-md bg-green-50 px-2 py-1 text-[11px] font-semibold text-green-600 dark:bg-green-900/20 dark:text-green-400">Active</span>
                    )}
                  </td>
                  <td className="px-4 py-4 text-right">
                    {suspended ? (
                      <button type="button" disabled={busyId === id} onClick={() => setSuspended(user, false)} className="inline-flex items-center gap-1.5 rounded-lg border border-green-200 px-3 py-1.5 text-xs font-bold text-green-600 hover:bg-green-50 disabled:opacity-60 dark:border-green-900/50 dark:hover:bg-green-900/20">
                        <ShieldCheck size={14} /> Restore
                      </button>
                    ) : suspending ? (
                      <div className="flex flex-col items-end gap-2">
                        <input aria-label={`Suspension reason for ${user.username}`} value={reason} onChange={(e) => setReason(e.target.value)} placeholder="Reason" className={`${inputCls} w-56`} />
                        <div className="flex gap-2">
                          <button type="button" onClick={() => { setSuspendingId(''); setReason(''); }} className="rounded-lg px-3 py-1.5 text-xs font-semibold text-gray-500 hover:bg-gray-50 dark:hover:bg-gray-800">Cancel</button>
                          <button type="button" disabled={busyId === id} onClick={() => setSuspended(user, true)} className="rounded-lg bg-red-500 px-3 py-1.5 text-xs font-bold text-white disabled:opacity-60">Confirm suspend</button>
                        </div>
                      </div>
                    ) : (
                      <button type="button" onClick={() => setSuspendingId(id)} className="inline-flex items-center gap-1.5 rounded-lg border border-red-200 px-3 py-1.5 text-xs font-bold text-red-600 hover:bg-red-50 dark:border-red-900/50 dark:hover:bg-red-900/20">
                        <Ban size={14} /> Suspend
                      </button>
                    )}
                  </td>
                </tr>
              );
            })}
            {!loading && !users.length && <tr><td colSpan={4} className="py-14 text-center text-gray-400">No influencers found.</td></tr>}
          </tbody>
        </table>
      </div>

      <div className="mt-3 flex items-center justify-end gap-2">
        <button type="button" disabled={page <= 1} onClick={() => setPage((p) => p - 1)} className="rounded-lg border border-gray-200 px-3 py-1.5 text-xs font-semibold text-gray-600 disabled:opacity-40 dark:border-gray-800 dark:text-gray-300">Prev</button>
        <span className="text-xs text-gray-400">Page {page} of {pages}</span>
        <button type="button" disabled={page >= pages} onClick={() => setPage((p) => p + 1)} className="rounded-lg border border-gray-200 px-3 py-1.5 text-xs font-semibold text-gray-600 disabled:opacity-40 dark:border-gray-800 dark:text-gray-300">Next</button>
      </div>
    </div>
  );
}
