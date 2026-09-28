import React, { useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { useSelector } from 'react-redux';
import { AreaChart, Area, XAxis, YAxis, Tooltip, ResponsiveContainer, CartesianGrid } from 'recharts';
import {
  Eye, Briefcase, Package, Calendar, ShoppingBag, Plus,
  CheckCircle2, ChevronRight, Star, UserCog, CreditCard, MessageCircle,
} from 'lucide-react';
import { Dropdown } from '../../components/productForm/ProductFormFields';
import { MOCK_ORDERS } from '../data/mockOrders';
import { MOCK_BOOKINGS } from '../data/mockBookings';
import { SEED_SERVICES } from '../data/mockServices';

// Deterministic mock daily-earnings series for the "This month" sparkline stat card.
const EARNINGS_DATA = Array.from({ length: 31 }, (_, i) => {
  const day = i + 1;
  const trend = 380 + day * 24;
  const wave = Math.sin(day / 3) * 130;
  return { day, label: `May ${day}`, value: Math.max(50, Math.round(trend + wave)) };
});
const THIS_MONTH_TOTAL = EARNINGS_DATA[EARNINGS_DATA.length - 1].value;

// ── Earnings overview chart: mock series per selectable period ─────────────
const MONTH_NAMES = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const PERIOD_OPTIONS = ['This week', 'This month', 'Last 3 months', 'This year'];
const PERIOD_CONFIG = {
  'This week':      { points: 7,  trendStep: 60,  waveAmp: 40,  waveDiv: 1.2, xInterval: 0, label: (i) => `Day ${i + 1}` },
  'This month':     { points: 31, trendStep: 24,  waveAmp: 130, waveDiv: 3,   xInterval: 4, label: (i) => `May ${i + 1}` },
  'Last 3 months':  { points: 12, trendStep: 180, waveAmp: 260, waveDiv: 1.6, xInterval: 1, label: (i) => `Wk ${i + 1}` },
  'This year':      { points: 12, trendStep: 640, waveAmp: 900, waveDiv: 1.4, xInterval: 0, label: (i) => MONTH_NAMES[i] },
};
const buildEarningsSeries = (period) => {
  const cfg = PERIOD_CONFIG[period];
  return Array.from({ length: cfg.points }, (_, i) => {
    const trend = 380 + i * cfg.trendStep;
    const wave = Math.sin(i / cfg.waveDiv) * cfg.waveAmp;
    return { label: cfg.label(i), value: Math.max(50, Math.round(trend + wave)) };
  });
};

const StatCard = ({ icon: Icon, label, value, sub, accent, sparkline, to }) => {
  const Component = to ? Link : 'div';

  return (
  <Component
    {...(to ? { to, 'aria-label': `View ${label.toLowerCase()}` } : {})}
    className={`bg-white dark:bg-gray-900 border border-gray-100 dark:border-gray-800 rounded-2xl p-4 shadow-sm min-w-0 ${to ? 'block transition-colors hover:border-[#fa3f5e] dark:hover:border-[#fa3f5e] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#fa3f5e] focus-visible:ring-offset-2 dark:focus-visible:ring-offset-black' : ''}`}
  >
    <div className="flex items-center gap-2 mb-2">
      {Icon && (
        <div className={`w-8 h-8 rounded-lg flex items-center justify-center flex-shrink-0 ${accent}`}>
          <Icon size={15} />
        </div>
      )}
      <p className="text-xs text-gray-500 dark:text-gray-400 truncate">{label}</p>
    </div>
    <p className="text-xl font-bold text-gray-900 dark:text-white">{value}</p>
    {sub && <p className="text-[11px] text-gray-400 dark:text-gray-500 mt-0.5">{sub}</p>}
    {sparkline && (
      <div className="h-8 -mx-1 mt-1">
        <ResponsiveContainer width="100%" height="100%">
          <AreaChart data={EARNINGS_DATA}>
            <defs>
              <linearGradient id="sparkFill" x1="0" y1="0" x2="0" y2="1">
                <stop offset="0%" stopColor="#fa3f5e" stopOpacity={0.25} />
                <stop offset="100%" stopColor="#fa3f5e" stopOpacity={0} />
              </linearGradient>
            </defs>
            <Area type="monotone" dataKey="value" stroke="#fa3f5e" strokeWidth={2} fill="url(#sparkFill)" />
          </AreaChart>
        </ResponsiveContainer>
      </div>
    )}
  </Component>
  );
};

const HealthItem = ({ icon: Icon, title, sub, done }) => (
  <div className="flex items-center gap-3 py-2.5">
    <div className="w-9 h-9 rounded-lg bg-gray-50 dark:bg-gray-800 flex items-center justify-center flex-shrink-0 text-gray-500 dark:text-gray-400">
      <Icon size={16} />
    </div>
    <div className="min-w-0 flex-1">
      <p className="text-sm font-medium text-gray-900 dark:text-white truncate">{title}</p>
      <p className="text-xs text-gray-400 dark:text-gray-500 truncate">{sub}</p>
    </div>
    {done ? (
      <CheckCircle2 size={18} className="text-green-500 flex-shrink-0" />
    ) : (
      <div className="w-[18px] h-[18px] rounded-full border-2 border-gray-200 dark:border-gray-700 flex-shrink-0" />
    )}
  </div>
);

const StoreDashboard = () => {
  const products = useSelector((state) => state.products.items);
  const services = useSelector((state) => state.services.items);
  const orders = useSelector((state) => state.orders.items);
  const bookings = useSelector((state) => state.bookings.items);
  const [earningsPeriod, setEarningsPeriod] = useState('This month');
  const earningsData = useMemo(() => buildEarningsSeries(earningsPeriod), [earningsPeriod]);
  const earningsTotal = earningsData[earningsData.length - 1].value;

  const activeProducts = products.filter((p) => (p.status || (p.rating > 0 ? 'Active' : 'Draft')) === 'Active').length;
  const openOrders = orders.filter((o) => !['Delivered', 'Cancelled'].includes(o.status)).length;
  const newBookings = bookings.filter((b) => b.status === 'New').length;
  const availableBalance = Math.round(THIS_MONTH_TOTAL * 0.7);

  const recentActivity = [
    { icon: Calendar, iconBg: 'bg-blue-50 dark:bg-blue-900/20 text-blue-500', title: 'New booking request', detail: `Booking for ${MOCK_BOOKINGS[0]?.service}`, time: 'Today, 10:24 AM' },
    { icon: ShoppingBag, iconBg: 'bg-pink-50 dark:bg-pink-900/20 text-[#fa3f5e]', title: 'New product order', detail: `Order ${MOCK_ORDERS[MOCK_ORDERS.length - 1]?.id} · ${MOCK_ORDERS[MOCK_ORDERS.length - 1]?.qty} items`, time: 'Today, 9:15 AM' },
    { icon: Star, iconBg: 'bg-amber-50 dark:bg-amber-900/20 text-amber-500', title: 'Review received', detail: `5-star review for ${SEED_SERVICES[2]?.name || 'a recent order'}`, time: 'Yesterday, 6:42 PM' },
  ];

  return (
    <div className="max-w-[1280px] ml-auto px-4 md:px-8 pt-6 pb-10">
      <h1 className="text-2xl font-bold text-gray-900 dark:text-white mb-4">My Store</h1>

      {/* Live status banner */}
      {/* <div className="flex flex-wrap items-center justify-between gap-3 bg-gray-50 dark:bg-gray-900 rounded-2xl px-5 py-3.5 mb-5">
        <div className="flex items-center gap-2.5">
          <span className="w-2 h-2 rounded-full bg-green-500 flex-shrink-0" />
          <div>
            <p className="text-sm font-bold text-gray-900 dark:text-white leading-tight">Live</p>
            <p className="text-xs text-gray-500 dark:text-gray-400">Your store is live and visible to customers.</p>
          </div>
        </div>
        <Link to="/market" className="flex items-center gap-1.5 text-sm font-semibold text-[#fa3f5e] hover:opacity-80 transition-opacity">
          <Eye size={15} /> View as customer
        </Link>
      </div> */}

      {/* Stat cards */}
      <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-6 gap-3 mb-5">
        <StatCard label="This month" value={`₹${THIS_MONTH_TOTAL.toLocaleString()}`} sparkline />
        <StatCard label="Available balance" value={`₹${availableBalance.toLocaleString()}`} />
        <StatCard to="/market/my-store/services" icon={Briefcase} accent="bg-teal-50 dark:bg-teal-900/20 text-teal-600" label="Services" value={services.filter((service) => service.status === 'Published').length} sub="active" />
        <StatCard to="/market/my-store/products" icon={Package} accent="bg-purple-50 dark:bg-purple-900/20 text-purple-600" label="Products" value={activeProducts} sub="active" />
        <StatCard to="/market/my-store/bookings" icon={Calendar} accent="bg-blue-50 dark:bg-blue-900/20 text-blue-600" label="Bookings" value={newBookings} sub="new" />
        <StatCard to="/market/my-store/orders" icon={ShoppingBag} accent="bg-pink-50 dark:bg-pink-900/20 text-[#fa3f5e]" label="Orders" value={openOrders} sub="open" />
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-[1fr_300px] gap-5 items-start">
        {/* Left column */}
        <div className="space-y-5 min-w-0">
          {/* Earnings overview */}
          <div className="bg-white dark:bg-gray-900 border border-gray-100 dark:border-gray-800 rounded-2xl p-5 shadow-sm">
            <div className="flex items-center justify-between mb-1">
              <h2 className="font-bold text-gray-900 dark:text-white text-sm">Earnings overview</h2>
              <Dropdown className="w-40" value={earningsPeriod} onChange={setEarningsPeriod} options={PERIOD_OPTIONS} />
            </div>
            <p className="text-2xl font-bold text-[#fa3f5e] mb-4">
              ₹{earningsTotal.toLocaleString()} <span className="text-xs font-medium text-gray-400">{earningsPeriod}</span>
            </p>
            <div className="h-56 -ml-2">
              <ResponsiveContainer width="100%" height="100%">
                <AreaChart data={earningsData} margin={{ top: 0, right: 8, left: 0, bottom: 0 }}>
                  <defs>
                    <linearGradient id="earningsFill" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="0%" stopColor="#fa3f5e" stopOpacity={0.25} />
                      <stop offset="100%" stopColor="#fa3f5e" stopOpacity={0} />
                    </linearGradient>
                  </defs>
                  <CartesianGrid vertical={false} strokeDasharray="3 3" className="stroke-gray-100 dark:stroke-gray-800" />
                  <XAxis dataKey="label" interval={PERIOD_CONFIG[earningsPeriod].xInterval} tick={{ fontSize: 11, fill: '#9ca3af' }} axisLine={false} tickLine={false} />
                  <YAxis tickFormatter={(v) => `₹${v}`} tick={{ fontSize: 11, fill: '#9ca3af' }} axisLine={false} tickLine={false} width={48} />
                  <Tooltip formatter={(v) => [`₹${v}`, 'Earnings']} contentStyle={{ borderRadius: 10, border: '1px solid #f3f4f6', fontSize: 12 }} />
                  <Area type="monotone" dataKey="value" stroke="#fa3f5e" strokeWidth={2.5} fill="url(#earningsFill)" />
                </AreaChart>
              </ResponsiveContainer>
            </div>
          </div>

          {/* Recent activity */}
          <div className="bg-white dark:bg-gray-900 border border-gray-100 dark:border-gray-800 rounded-2xl shadow-sm overflow-hidden">
            <h2 className="font-bold text-gray-900 dark:text-white text-sm px-5 pt-4 pb-3">Recent activity</h2>
            <div className="hidden sm:grid grid-cols-[1fr_1fr_auto] gap-3 px-5 pb-2 text-xs font-semibold text-gray-400 dark:text-gray-500">
              <span>Activity</span>
              <span>Details</span>
              <span>Time</span>
            </div>
            <div className="divide-y divide-gray-100 dark:divide-gray-800">
              {recentActivity.map((a, i) => (
                <div key={i} className="flex items-center gap-3 px-5 py-3 hover:bg-gray-50 dark:hover:bg-gray-800/50 transition-colors cursor-pointer">
                  <div className={`w-8 h-8 rounded-lg flex items-center justify-center flex-shrink-0 ${a.iconBg}`}>
                    <a.icon size={15} />
                  </div>
                  <div className="flex-1 min-w-0 grid grid-cols-1 sm:grid-cols-2 gap-1">
                    <p className="text-sm font-medium text-gray-900 dark:text-white truncate">{a.title}</p>
                    <p className="text-sm text-gray-500 dark:text-gray-400 truncate">{a.detail}</p>
                  </div>
                  <span className="text-xs text-gray-400 dark:text-gray-500 flex-shrink-0 hidden sm:inline">{a.time}</span>
                  <ChevronRight size={15} className="text-gray-300 dark:text-gray-600 flex-shrink-0" />
                </div>
              ))}
            </div>
          </div>
        </div>

        {/* Right column */}
        <div className="space-y-5">
          {/* Quick actions */}
          <div className="bg-white dark:bg-gray-900 border border-gray-100 dark:border-gray-800 rounded-2xl shadow-sm p-4">
            <h2 className="font-bold text-gray-900 dark:text-white text-sm mb-3">Quick actions</h2>
            <div className="space-y-2">
              <Link
                to="/market/add-service"
                className="flex items-center gap-3 px-3.5 py-2.5 rounded-xl border border-gray-100 dark:border-gray-800 hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors"
              >
                <div className="w-7 h-7 rounded-full bg-teal-500 text-white flex items-center justify-center flex-shrink-0">
                  <Plus size={14} />
                </div>
                <span className="text-sm font-semibold text-gray-800 dark:text-gray-200">Add Service</span>
              </Link>
              <Link
                to="/market/add-product"
                className="flex items-center gap-3 px-3.5 py-2.5 rounded-xl border border-gray-100 dark:border-gray-800 hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors"
              >
                <div className="w-7 h-7 rounded-full bg-[#fa3f5e] text-white flex items-center justify-center flex-shrink-0">
                  <Plus size={14} />
                </div>
                <span className="text-sm font-semibold text-gray-800 dark:text-gray-200">Add Product</span>
              </Link>
            </div>
          </div>

          {/* Store health */}
          <div className="bg-white dark:bg-gray-900 border border-gray-100 dark:border-gray-800 rounded-2xl shadow-sm p-4">
            <h2 className="font-bold text-gray-900 dark:text-white text-sm mb-1">Store health</h2>
            <div className="divide-y divide-gray-50 dark:divide-gray-800">
              <HealthItem icon={UserCog} title="Complete your profile" sub="Add store information and profile photo" done />
              <HealthItem icon={Package} title="Add a service or product" sub="List at least one service or product" done={products.length > 0 || services.length > 0} />
              <HealthItem icon={CreditCard} title="Set up payments" sub="Connect a payout method" done />
              <HealthItem icon={MessageCircle} title="Respond to messages" sub="Keep your response rate high" done />
            </div>
            <p className="text-sm font-semibold text-[#fa3f5e] mt-2 flex items-center gap-1">
              View all recommendations <ChevronRight size={14} />
            </p>
          </div>
        </div>
      </div>
    </div>
  );
};

export default StoreDashboard;
