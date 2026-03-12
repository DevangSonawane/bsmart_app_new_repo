import { useState } from "react";
import { Lock, ShieldCheck, Monitor, UserPlus, UserCog, Mail, MessageSquare } from "lucide-react";

const Toggle = ({ checked, onChange }) => (
  <label className="relative inline-flex items-center cursor-pointer">
    <input type="checkbox" checked={checked} onChange={onChange} className="sr-only peer" />
    <div className="w-11 h-6 rounded-full bg-gray-300 dark:bg-gray-700 peer-checked:bg-pink-600 transition-colors" />
    <div className="absolute left-0.5 top-0.5 w-5 h-5 bg-white rounded-full shadow transform transition-transform peer-checked:translate-x-5" />
  </label>
);

export default function Settings() {
  const [passwords, setPasswords] = useState({ current: "", newPass: "", confirm: "" });
  const [twoFA, setTwoFA] = useState(false);
  const [emailAlerts, setEmailAlerts] = useState(true);
  const [smsAlerts, setSmsAlerts] = useState(false);
  const [subUserEmail, setSubUserEmail] = useState("");
  const [role, setRole] = useState("viewer");

  return (
    <div className="min-h-screen bg-gray-50 dark:bg-black font-sans transition-colors duration-300">
      <div className="max-w-7xl mx-auto p-6 md:p-8 space-y-8">
        <div>
          <h1 className="text-3xl md:text-4xl font-extrabold tracking-tight mb-2">
            <span className="bg-clip-text text-transparent bg-gradient-to-r from-orange-500 via-red-500 to-pink-600">
              Settings
            </span>
          </h1>
          <p className="text-gray-500 dark:text-gray-400">Manage account security, permissions, and communications.</p>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          <div className="p-6 rounded-2xl bg-white dark:bg-gray-900 border border-gray-100 dark:border-gray-800">
            <div className="flex items-center gap-3 mb-4">
              <div className="p-2 rounded-lg bg-blue-50 text-blue-600 dark:bg-blue-900/20 dark:text-blue-400">
                <Lock className="w-4 h-4" />
              </div>
              <h3 className="text-lg font-bold text-gray-900 dark:text-white">Change Password</h3>
            </div>
            <div className="space-y-3">
              <input
                type="password"
                value={passwords.current}
                onChange={e => setPasswords({ ...passwords, current: e.target.value })}
                placeholder="Current Password"
                className="w-full px-4 py-2.5 rounded-xl border border-gray-200 dark:border-gray-800 bg-white dark:bg-gray-900 text-sm outline-none focus:ring-2 focus:ring-blue-500/20"
              />
              <input
                type="password"
                value={passwords.newPass}
                onChange={e => setPasswords({ ...passwords, newPass: e.target.value })}
                placeholder="New Password"
                className="w-full px-4 py-2.5 rounded-xl border border-gray-200 dark:border-gray-800 bg-white dark:bg-gray-900 text-sm outline-none focus:ring-2 focus:ring-blue-500/20"
              />
              <input
                type="password"
                value={passwords.confirm}
                onChange={e => setPasswords({ ...passwords, confirm: e.target.value })}
                placeholder="Confirm New Password"
                className="w-full px-4 py-2.5 rounded-xl border border-gray-200 dark:border-gray-800 bg-white dark:bg-gray-900 text-sm outline-none focus:ring-2 focus:ring-blue-500/20"
              />
              <button className="w-full mt-2 py-2.5 rounded-xl bg-gradient-to-r from-purple-600 to-pink-600 text-white font-bold hover:opacity-90 transition-opacity shadow-lg shadow-pink-500/20">
                Update Password
              </button>
            </div>
          </div>

          <div className="p-6 rounded-2xl bg-white dark:bg-gray-900 border border-gray-100 dark:border-gray-800">
            <div className="flex items-center gap-3 mb-4">
              <div className="p-2 rounded-lg bg-emerald-50 text-emerald-600 dark:bg-emerald-900/20 dark:text-emerald-400">
                <ShieldCheck className="w-4 h-4" />
              </div>
              <h3 className="text-lg font-bold text-gray-900 dark:text-white">Two-Factor Authentication</h3>
            </div>
            <div className="flex items-center justify-between p-4 rounded-xl bg-gray-50 dark:bg-gray-800">
              <div>
                <div className="font-semibold text-gray-900 dark:text-white">Enable 2FA</div>
                <div className="text-sm text-gray-500">Add an extra layer of security to your account.</div>
              </div>
              <Toggle checked={twoFA} onChange={e => setTwoFA(e.target.checked)} />
            </div>
            <div className="mt-3 text-xs text-gray-500">Use an authenticator app to complete setup.</div>
          </div>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          <div className="p-6 rounded-2xl bg-white dark:bg-gray-900 border border-gray-100 dark:border-gray-800">
            <div className="flex items-center gap-3 mb-4">
              <div className="p-2 rounded-lg bg-purple-50 text-purple-600 dark:bg-purple-900/20 dark:text-purple-400">
                <UserPlus className="w-4 h-4" />
              </div>
              <h3 className="text-lg font-bold text-gray-900 dark:text-white">Add Sub Users</h3>
            </div>
            <div className="flex gap-2">
              <input
                type="email"
                value={subUserEmail}
                onChange={e => setSubUserEmail(e.target.value)}
                placeholder="user@company.com"
                className="flex-1 px-4 py-2.5 rounded-xl border border-gray-200 dark:border-gray-800 bg-white dark:bg-gray-900 text-sm outline-none focus:ring-2 focus:ring-blue-500/20"
              />
              <button className="px-4 py-2.5 rounded-xl border border-gray-200 dark:border-gray-800 font-bold hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors">
                Invite
              </button>
            </div>
            <div className="mt-6">
              <div className="text-xs font-bold text-gray-500 uppercase tracking-wider mb-2">Assign Role</div>
              <div className="grid grid-cols-3 gap-3">
                {["viewer", "editor", "admin"].map(r => (
                  <button
                    key={r}
                    onClick={() => setRole(r)}
                    className={`p-3 rounded-xl border text-sm font-semibold capitalize ${role === r ? "border-black dark:border-white bg-gray-50 dark:bg-gray-800" : "border-gray-200 dark:border-gray-800 hover:bg-gray-50 dark:hover:bg-gray-800"}`}
                  >
                    {r}
                  </button>
                ))}
              </div>
            </div>
          </div>

          <div className="p-6 rounded-2xl bg-white dark:bg-gray-900 border border-gray-100 dark:border-gray-800">
            <div className="flex items-center gap-3 mb-4">
              <div className="p-2 rounded-lg bg-amber-50 text-amber-600 dark:bg-amber-900/20 dark:text-amber-400">
                <UserCog className="w-4 h-4" />
              </div>
              <h3 className="text-lg font-bold text-gray-900 dark:text-white">Communication Preferences</h3>
            </div>
            <div className="space-y-3">
              <div className="flex items-center justify-between p-4 rounded-xl bg-gray-50 dark:bg-gray-800">
                <div className="flex items-center gap-3">
                  <Mail className="w-4 h-4 text-gray-500" />
                  <div>
                    <div className="font-semibold text-gray-900 dark:text-white">Email Alerts</div>
                    <div className="text-xs text-gray-500">Receive updates and campaign notifications.</div>
                  </div>
                </div>
                <Toggle checked={emailAlerts} onChange={e => setEmailAlerts(e.target.checked)} />
              </div>
              <div className="flex items-center justify-between p-4 rounded-xl bg-gray-50 dark:bg-gray-800">
                <div className="flex items-center gap-3">
                  <MessageSquare className="w-4 h-4 text-gray-500" />
                  <div>
                    <div className="font-semibold text-gray-900 dark:text-white">SMS Alerts</div>
                    <div className="text-xs text-gray-500">Get important notifications on your phone.</div>
                  </div>
                </div>
                <Toggle checked={smsAlerts} onChange={e => setSmsAlerts(e.target.checked)} />
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
