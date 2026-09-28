import ServiceIcon from './ServiceIcon';
import React from 'react';
import { Link, Outlet, useLocation } from 'react-router-dom';
import { ArrowLeft, LayoutDashboard, ClipboardList, Package, Calendar, UserRound } from 'lucide-react';
import StoreSidebar from './StoreSidebar';

const MOBILE_NAV_ITEMS = [
  { icon: LayoutDashboard, label: 'Dashboard', path: '/market/my-store' },
  { icon: UserRound, label: 'Profile', path: '/market/my-store/profile' },
  { icon: Calendar,        label: 'Bookings', path: '/market/my-store/bookings' },
  { icon: ClipboardList,   label: 'Orders',    path: '/market/my-store/orders' },
  { icon: Package,         label: 'Products',  path: '/market/my-store/products' },
  { icon: ServiceIcon,          label: 'Service',  path: '/market/my-store/services' },
];

// Layout for the My Store module — its own sidebar (desktop) / tab bar (mobile),
// separate from the main app Sidebar, the same way the Vendor module has its own layout.
const StoreLayout = () => {
  const location = useLocation();
  const isActive = (path) =>
    path === '/market/my-store' ? location.pathname === path : location.pathname.startsWith(path);

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
            const active = isActive(item.path);
            return (
              <Link
                key={item.label}
                to={item.path}
                className={`flex items-center gap-1.5 px-3.5 py-2.5 border-b-2 text-sm font-semibold whitespace-nowrap transition-colors ${
                  active ? 'border-[#fa3f5e] text-gray-900 dark:text-white' : 'border-transparent text-gray-400'
                }`}
              >
                <Icon size={15} /> {item.label}
              </Link>
            );
          })}
        </div>
      </div>

      <div className="md:ml-20 pb-16 md:pb-4">
        <Outlet />
      </div>
    </div>
  );
};

export default StoreLayout;
