import { useEffect } from 'react';
import { Link, Outlet, useLocation, useNavigate } from 'react-router-dom';
import {
  ArrowLeft, UserCog, Shield, Lock, Bell, ChevronRight,
  MessageSquare, LayoutGrid, Wallet, UserX,
  Palette, HardDrive, HelpCircle, Scale, Info, LogOut, Bookmark,
} from 'lucide-react';

const SETTINGS_GROUPS = [
  {
    group: 'Account',
    items: [
      { key: 'account',  label: 'Account',  subLabel: 'Profile, username & email',  icon: UserCog,  to: '/settings/account',  iconBg: 'bg-blue-50 dark:bg-gray-800',   iconColor: 'text-blue-500' },
      { key: 'privacy',  label: 'Privacy',  subLabel: 'Account privacy & follow requests', icon: Shield, to: '/settings/privacy', iconBg: 'bg-pink-50 dark:bg-gray-800', iconColor: 'text-[#fa3f5e]' },
      { key: 'security', label: 'Security', subLabel: 'Password & 2FA', icon: Lock, to: '/settings/security', iconBg: 'bg-orange-50 dark:bg-gray-800', iconColor: 'text-orange-500' },
    ],
  },
  {
    group: 'Preferences',
    items: [
      { key: 'notifications', label: 'Notifications',        subLabel: 'Manage your notification preferences', icon: Bell,         to: '/settings/notifications', iconBg: 'bg-purple-50 dark:bg-gray-800', iconColor: 'text-purple-500' },
      { key: 'messaging',     label: 'Messaging',            subLabel: 'Auto download images, videos & documents', icon: MessageSquare, to: '/settings/messaging', iconBg: 'bg-teal-50 dark:bg-gray-800', iconColor: 'text-teal-500' },
      { key: 'content',       label: 'Content Preferences',  subLabel: 'Feed interests, topics & video playback',  icon: LayoutGrid, to: '/settings/content', iconBg: 'bg-indigo-50 dark:bg-gray-800', iconColor: 'text-indigo-500' },
      { key: 'appearance',    label: 'Appearance',            subLabel: 'Theme, font size & motion settings',       icon: Palette, to: '/settings/appearance', iconBg: 'bg-yellow-50 dark:bg-gray-800', iconColor: 'text-yellow-500' },
    ],
  },
  {
    group: 'Storage & Activity',
    items: [
      { key: 'wallet',  label: 'Rewards & Wallet',      subLabel: 'Coins, transactions & wallet history', icon: Wallet,    to: '/wallet',            iconBg: 'bg-orange-50 dark:bg-gray-800', iconColor: 'text-orange-500', external: true },
      { key: 'saved',   label: 'Saved',                   subLabel: 'Moments, bSparks, Spotlights & Boosts', icon: Bookmark,  to: '/settings/saved',   iconBg: 'bg-amber-50 dark:bg-gray-800', iconColor: 'text-amber-500' },
      { key: 'storage', label: 'Storage & Data',         subLabel: 'Cache, data usage & storage breakdown', icon: HardDrive, to: '/settings/storage', iconBg: 'bg-green-50 dark:bg-gray-800', iconColor: 'text-green-500' },
      { key: 'blocked', label: 'Blocked & Restricted',   subLabel: 'Blocked, restricted & muted accounts', icon: UserX,     to: '/settings/blocked', iconBg: 'bg-red-50 dark:bg-gray-800', iconColor: 'text-red-500' },
    ],
  },
  {
    group: 'Support & Legal',
    items: [
      { key: 'help',  label: 'Help & Support',       subLabel: 'Contact support, FAQs & reports',       icon: HelpCircle, to: '/settings/help',  iconBg: 'bg-sky-50 dark:bg-gray-800',   iconColor: 'text-sky-500' },
      { key: 'legal', label: 'Legal & Compliance',   subLabel: 'Terms, privacy, DPDP & data controls', icon: Scale,      to: '/settings/legal', iconBg: 'bg-slate-100 dark:bg-gray-800', iconColor: 'text-slate-500' },
      { key: 'about', label: 'About bSmart',         subLabel: 'App version, company & links',          icon: Info,       to: '/settings/about', iconBg: 'bg-gray-100 dark:bg-gray-800', iconColor: 'text-gray-500' },
    ],
  },
  {
    group: 'Account Actions',
    items: [
      { key: 'account-actions', label: 'Account Actions', subLabel: 'Logout, deactivate or delete account', icon: LogOut, to: '/settings/account-actions', iconBg: 'bg-red-50 dark:bg-gray-800', iconColor: 'text-red-500' },
    ],
  },
];

const NavList = ({ mobile, activeKey }) => (
  <div className={mobile ? 'max-w-2xl mx-auto pt-6 px-4 space-y-6 pb-20' : 'flex-1 overflow-y-auto py-3 px-3 space-y-4'} style={mobile ? undefined : { scrollbarWidth: 'thin' }}>
    {SETTINGS_GROUPS.map(({ group, items }) => (
      <div key={group}>
        <p className={`font-bold text-[#fa3f5e] uppercase tracking-widest ${mobile ? 'text-[11px] mb-2 px-1' : 'text-[10px] mb-1.5 px-2.5'}`}>{group}</p>
        <div className={mobile ? 'space-y-2' : 'space-y-0.5'}>
          {items.map((item) => {
            const Icon = item.icon;
            const isActive = activeKey === item.key;

            if (mobile) {
              return (
                <Link key={item.key} to={item.to}
                  className="flex items-center justify-between p-4 bg-white dark:bg-gray-900 border border-gray-100 dark:border-gray-800 rounded-2xl shadow-sm hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors">
                  <div className="flex items-center gap-4">
                    <div className={`w-10 h-10 rounded-full flex items-center justify-center ${item.iconBg} ${item.iconColor}`}>
                      <Icon size={20} strokeWidth={2.5} />
                    </div>
                    <div className="flex flex-col">
                      <span className="font-medium text-gray-900 dark:text-white">{item.label}</span>
                      <span className="text-xs text-gray-500 dark:text-gray-400">{item.subLabel}</span>
                    </div>
                  </div>
                  <ChevronRight size={18} className="text-gray-400" />
                </Link>
              );
            }

            return (
              <Link key={item.key} to={item.to}
                className={`flex items-center gap-3 px-2.5 py-2 rounded-xl transition-all duration-150 ${
                  isActive
                    ? 'bg-[#fa3f5e]/10 dark:bg-[#fa3f5e]/15'
                    : 'hover:bg-gray-100 dark:hover:bg-gray-800/60'
                }`}>
                <div className={`w-8 h-8 rounded-lg flex items-center justify-center shrink-0 transition-colors ${
                  isActive ? 'bg-[#fa3f5e]/15 dark:bg-[#fa3f5e]/20' : item.iconBg
                }`}>
                  <Icon size={15} strokeWidth={2.5} className={isActive ? 'text-[#fa3f5e]' : item.iconColor} />
                </div>
                <span className={`text-[13px] font-medium transition-colors truncate ${
                  isActive ? 'text-[#fa3f5e]' : 'text-gray-700 dark:text-gray-300'
                }`}>
                  {item.label}
                </span>
              </Link>
            );
          })}
        </div>
      </div>
    ))}
  </div>
);

const Settings = () => {
  const location = useLocation();
  const navigate = useNavigate();
  const isSubRoute = /^\/settings\/.+/.test(location.pathname);
  const activeKey = location.pathname.split('/settings/')[1]?.split('/')[0] || '';

  useEffect(() => {
    if (isSubRoute) return;
    navigate('/settings/account', { replace: true });
  }, [isSubRoute, navigate]);

  return (
    <>
      {/* ── Mobile: nav list OR sub-page ── */}
      <div className="md:hidden max-w-[1100px] mx-auto">
        {isSubRoute ? (
          <Outlet />
        ) : (
          <div className="min-h-screen bg-gray-50 dark:bg-black">
            <div className="sticky top-0 bg-white dark:bg-black border-b border-gray-100 dark:border-gray-800 px-4 py-3 flex justify-between items-center z-40">
              <Link to="/profile" className="text-gray-800 dark:text-white"><ArrowLeft size={24} /></Link>
              <h1 className="text-lg font-semibold dark:text-white">Settings</h1>
              <div className="w-6" />
            </div>
            <NavList mobile activeKey="" />
          </div>
        )}
      </div>

      {/* ── Desktop: side-by-side master-detail ── */}
      <div className="hidden md:flex h-screen bg-gray-50 dark:bg-black max-w-[1300px] ml-auto">

        {/* Left Nav Panel */}
        <div className="w-[30%] shrink-0 flex flex-col border-r border-gray-200 dark:border-gray-800 bg-white dark:bg-black">
          <div className="shrink-0 px-5 py-4 border-b border-gray-100 dark:border-gray-800 flex items-center gap-3">
            <Link to="/profile" className="text-gray-600 dark:text-gray-400 hover:text-gray-900 dark:hover:text-white transition-colors">
              <ArrowLeft size={20} />
            </Link>
            <h1 className="text-[17px] font-bold text-gray-900 dark:text-white">Settings</h1>
          </div>
          <NavList mobile={false} activeKey={activeKey} />
        </div>

        {/* Right Detail Panel */}
        <div className="flex-1 overflow-y-auto">
          <Outlet />
        </div>
      </div>
    </>
  );
};

export default Settings;
