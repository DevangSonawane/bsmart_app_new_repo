import ServiceIcon from './ServiceIcon';
import React, { useEffect, useState } from 'react';
import { Link, Outlet, useLocation } from 'react-router-dom';
import { useSelector } from 'react-redux';
import { ArrowLeft, LayoutDashboard, ClipboardList, Package, Calendar, UserRound } from 'lucide-react';
import StoreSidebar from './StoreSidebar';
import StoreSubscriptionCard from '../../components/StoreSubscriptionCard';
import listingSubscriptionService from '../../services/listingSubscriptionService';

const MOBILE_NAV_ITEMS = [
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

// Layout for the My Store module — its own sidebar (desktop) / tab bar (mobile),
// separate from the main app Sidebar, the same way the Vendor module has its own layout.
const StoreLayout = () => {
  const location = useLocation();
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
    <div className="min-h-screen bg-gray-50 dark:bg-black">
      <StoreSidebar />

      {/* Mobile top bar + tabs */}
      <div className="md:hidden sticky top-0 z-40 bg-white dark:bg-black border-b border-gray-100 dark:border-gray-800">
        <div className="flex items-center gap-2 px-4 pt-3 pb-1">
          <Link to="/market" className="p-1 -ml-1 text-gray-500 dark:text-gray-400">
            <ArrowLeft size={20} />
          </Link>
          <h1 className="text-base font-bold text-gray-900 dark:text-white">My Store</h1>
        </div>
        <div className="flex overflow-x-auto scrollbar-hide px-2">
          {MOBILE_NAV_ITEMS.map((item) => {
            const Icon = item.icon;
            const active = isActive(item);
            return (
              <Link
                key={item.label}
                to={item.path}
                className={`flex items-center gap-1.5 px-3.5 py-2.5 border-b-2 text-sm font-semibold whitespace-nowrap transition-colors ${
                  active ? 'border-[#fa3f5e] text-gray-900 dark:text-white' : 'border-transparent text-gray-400'
                }`}
              >
                <Icon size={15} /> {item.label}
                {item.label === 'Profile' && trialDays != null && (
                  <span className="ml-0.5 text-[9px] font-bold px-1.5 py-0.5 rounded-full bg-pink-50 dark:bg-pink-900/20 text-[#fa3f5e]">
                    {trialDays}d
                  </span>
                )}
              </Link>
            );
          })}
        </div>
      </div>

      <div className="md:ml-20 pb-16 md:pb-4">
        <div className="max-w-[1280px] ml-auto px-4 md:px-8 pt-4">
          <StoreSubscriptionCard />
        </div>
        <Outlet />
      </div>
    </div>
  );
};

export default StoreLayout;
