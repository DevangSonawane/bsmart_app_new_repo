import ServiceIcon from './ServiceIcon';
import React, { useEffect, useState } from 'react';
import { Link, useLocation } from 'react-router-dom';
import { useSelector } from 'react-redux';
import { LayoutDashboard, ClipboardList, Package, ArrowLeft, Calendar, UserRound } from 'lucide-react';
import bsmartLogo from '../../assets/bsmart.png';
import bsmartIcon from '../../assets/bsmart_logo.png';
import listingSubscriptionService from '../../services/listingSubscriptionService';

const NAV_ITEMS = [
  { icon: LayoutDashboard, label: 'Dashboard', path: '/market/my-store' },
  { icon: UserRound, label: 'Profile', path: '/market/my-store/profile' },
  { icon: Calendar,        label: 'Bookings', path: '/market/my-store/bookings' },
  { icon: ClipboardList,   label: 'Orders',    path: '/market/my-store/orders' },
  { icon: Package,         label: 'Products',  path: '/market/my-store/products', extraActive: ['/market/add-product', '/market/edit-product'] },
  { icon: ServiceIcon,          label: 'Service',  path: '/market/my-store/services', extraActive: ['/market/add-service', '/market/edit-service'] },
];

const trialDaysLeft = (dateStr) => {
  if (!dateStr) return 0;
  const diff = new Date(dateStr).getTime() - Date.now();
  return Math.max(0, Math.ceil(diff / (24 * 60 * 60 * 1000)));
};

// Desktop icon-rail sidebar for the My Store module — same hover-to-expand
// interaction as the app's main Sidebar, scoped to just the store's own pages.
const StoreSidebar = () => {
  const location = useLocation();
  const [isHovered, setIsHovered] = useState(false);
  const currentUser = useSelector((state) => state.auth.userObject);
  const [trialDays, setTrialDays] = useState(null);

  useEffect(() => {
    if (currentUser?.role !== 'influencer') return;
    let active = true;
    listingSubscriptionService.getMyAccountSubscription()
      .then((sub) => {
        if (!active) return;
        setTrialDays(sub?.status === 'trialing' ? trialDaysLeft(sub.trial_ends_at) : null);
      })
      .catch(() => { if (active) setTrialDays(null); });
    return () => { active = false; };
  }, [currentUser?.role]);

  const isActive = (item) =>
    (item.path === '/market/my-store' ? location.pathname === item.path : location.pathname.startsWith(item.path))
    || (item.extraActive || []).some((path) => location.pathname.startsWith(path));

  return (
    <div
      className={`hidden md:flex flex-col fixed left-0 top-0 h-screen bg-white dark:bg-black border-r border-gray-100 dark:border-gray-800 z-50 transition-all duration-300 ease-in-out ${isHovered ? 'w-64' : 'w-20'}`}
      onMouseEnter={() => setIsHovered(true)}
      onMouseLeave={() => setIsHovered(false)}
    >
      <Link to="/" className="h-20 flex-shrink-0 flex items-center px-3 gap-2">
        <img src={bsmartIcon} alt="bs" className="w-9 h-9 flex-shrink-0 object-contain" />
        {isHovered && <img src={bsmartLogo} alt="b_smart" className="h-[70px] w-auto object-contain" />}
      </Link>

      <div className="flex-1 flex flex-col gap-2 px-3">
        {NAV_ITEMS.map((item) => {
          const Icon = item.icon;
          const active = isActive(item);
          return (
            <Link
              key={item.label}
              to={item.path}
              className={`group flex items-center gap-4 p-3 rounded-xl transition-all duration-200 ${
                active
                  ? 'bg-gradient-to-r from-insta-purple via-insta-pink to-insta-orange text-white shadow-md'
                  : 'hover:bg-gray-50 dark:hover:bg-gray-900 text-gray-900 dark:text-white'
              }`}
            >
              <div className="relative min-w-[24px]">
                <Icon
                  size={24}
                  className={`${active ? 'text-white' : 'text-gray-900 dark:text-white'} transition-transform duration-150 group-hover:scale-110`}
                  strokeWidth={active ? 2.5 : 2}
                />
                {item.label === 'Profile' && trialDays != null && (
                  <span
                    aria-label={`Free trial: ${trialDays} day${trialDays === 1 ? '' : 's'} left`}
                    className={`absolute -top-1.5 -right-2 min-w-[16px] h-4 px-1 rounded-full text-[9px] font-bold flex items-center justify-center ${active ? 'bg-white text-[#fa3f5e]' : 'bg-[#fa3f5e] text-white'}`}
                  >
                    {trialDays}
                  </span>
                )}
              </div>
              <span className={`flex-1 flex items-center justify-between text-base font-medium whitespace-nowrap overflow-hidden transition-all duration-300 ${isHovered ? 'opacity-100 w-auto' : 'opacity-0 w-0'} ${active ? 'text-white font-bold' : ''}`}>
                {item.label}
                {item.label === 'Profile' && trialDays != null && (
                  <span className={`ml-2 text-[10px] font-bold px-2 py-0.5 rounded-full ${active ? 'bg-white/20 text-white' : 'bg-pink-50 dark:bg-pink-900/20 text-[#fa3f5e]'}`}>
                    {trialDays}d trial
                  </span>
                )}
              </span>
            </Link>
          );
        })}

        <div className="mt-auto pb-4">
          <Link
            to="/market"
            className="group flex items-center gap-4 p-3 rounded-xl hover:bg-gray-50 dark:hover:bg-gray-900 text-gray-500 dark:text-gray-400 transition-colors"
          >
            <div className="min-w-[24px]"><ArrowLeft size={22} /></div>
            <span className={`text-sm font-medium whitespace-nowrap overflow-hidden transition-all duration-300 ${isHovered ? 'opacity-100 w-auto' : 'opacity-0 w-0'}`}>
              Back to Marketplace
            </span>
          </Link>
        </div>
      </div>
    </div>
  );
};

export default StoreSidebar;
