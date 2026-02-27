import React, { useState } from 'react';
import { ArrowLeft, ChevronDown, SlidersHorizontal, ArrowUpRight, ShoppingCart, CheckCircle2, User, Mail, Phone, Building2, Globe } from 'lucide-react';
import { useNavigate } from 'react-router-dom';
import { useSelector } from 'react-redux';

const AccordionItem = ({ id, title, openSection, setOpenSection, children }) => (
  <div className={`rounded-xl border border-gray-100 dark:border-gray-800 ${openSection === id ? 'bg-white dark:bg-gray-900 shadow-sm' : 'bg-white dark:bg-gray-900'}`}>
    <button
      onClick={() => setOpenSection(openSection === id ? '' : id)}
      className={`w-full p-4 flex items-center justify-between transition-colors rounded-xl ${openSection === id ? 'bg-gray-50 dark:bg-gray-800' : 'hover:bg-gray-50 dark:hover:bg-gray-800'}`}
    >
      <span className="text-sm font-semibold text-gray-900 dark:text-white">{title}</span>
      <ChevronDown
        size={18}
        className={`transition-transform ${openSection === id ? 'rotate-180 text-gray-600 dark:text-gray-300' : 'rotate-0 text-gray-400'}`}
      />
    </button>
    {openSection === id && (
      <div className="px-4 pb-4 border-t border-gray-100 dark:border-gray-800">
        {children}
      </div>
    )}
  </div>
);

const WalletDetails = () => {
  const navigate = useNavigate();
  const [filter, setFilter] = useState('All');
  const [isLifeTime, setIsLifeTime] = useState(true);
  const { userObject } = useSelector((state) => state.auth);
  const [openSection, setOpenSection] = useState('transaction');
  const [redeemPackage, setRedeemPackage] = useState('');

  // Mock data based on the screenshot
  const transactions = [
    {
      id: 1,
      type: 'earned',
      title: 'Watched video: Kids Learning Fun',
      date: 'Dec 16, 2025 at 10:45 PM',
      amount: 8,
      icon: <ArrowUpRight size={16} className="text-green-500" />,
      color: 'text-green-500'
    },
    {
      id: 2,
      type: 'spent',
      title: 'Redeemed on order #9c2656b4',
      date: 'Dec 16, 2025 at 10:35 PM',
      amount: -139,
      icon: <ShoppingCart size={16} className="text-blue-500" />,
      color: 'text-red-500'
    },
    {
      id: 3,
      type: 'earned',
      title: 'Watched video: Kids Learning Fun',
      date: 'Dec 16, 2025 at 10:45 PM',
      amount: 8,
      icon: <ArrowUpRight size={16} className="text-green-500" />,
      color: 'text-green-500'
    },
    {
      id: 4,
      type: 'spent',
      title: 'Redeemed on order #9c2656b4',
      date: 'Dec 16, 2025 at 10:35 PM',
      amount: -139,
      icon: <ShoppingCart size={16} className="text-blue-500" />,
      color: 'text-red-500'
    }
  ];

  return (
    <div className="min-h-screen bg-gray-50 dark:bg-black pb-20">
      {/* Header */}
      <div className="bg-white dark:bg-black px-4 py-3 flex items-center gap-3 sticky top-0 z-10">
        <button onClick={() => navigate(-1)} className="text-gray-900 dark:text-white">
          <ArrowLeft size={24} />
        </button>
        <h1 className="text-lg font-bold text-gray-900 dark:text-white">Wallet & Coins</h1>
      </div>

      <div className="p-4 space-y-6">
        {/* Balance Card */}
        <div className="w-full rounded-2xl p-6 text-white bg-gradient-to-r from-orange-400 to-orange-600 shadow-lg relative overflow-hidden">
            {/* Background decoration */}
            <div className="absolute top-0 right-0 w-32 h-32 bg-white/10 rounded-full -mr-10 -mt-10 blur-xl"></div>
            
            <div className="flex justify-between items-start mb-2 relative z-10">
                <div className="flex items-center gap-2 text-white/90 text-sm font-medium">
                    <div className="flex -space-x-1">
                        <div className="w-4 h-4 rounded-full border border-orange-500 bg-white/30"></div>
                        <div className="w-4 h-4 rounded-full border border-orange-500 bg-white/30"></div>
                    </div>
                    Available Balance
                </div>
                
                <div className="flex items-center gap-2">
                    <span className="text-sm font-medium">Life Time</span>
                    <button 
                        onClick={() => setIsLifeTime(!isLifeTime)}
                        className={`w-10 h-5 rounded-full flex items-center px-0.5 transition-colors ${isLifeTime ? 'bg-teal-400' : 'bg-gray-300'}`}
                    >
                        <div className={`w-4 h-4 bg-white rounded-full shadow-sm transform transition-transform ${isLifeTime ? 'translate-x-5' : 'translate-x-0'}`}></div>
                    </button>
                </div>
            </div>

            <div className="mb-6 relative z-10">
                <div className="flex items-baseline gap-1">
                    <span className="text-4xl font-bold">4201</span>
                    <span className="text-lg font-medium opacity-90">coins</span>
                </div>
            </div>

            <div className="flex justify-between items-end relative z-10">
                <div>
                    <div className="text-xs text-white/80 mb-0.5">Total Earned</div>
                    <div className="text-xl font-bold">203</div>
                </div>
                <div className="text-right">
                    <div className="text-xs text-white/80 mb-0.5">Total Spent</div>
                    <div className="text-xl font-bold">738</div>
                </div>
            </div>
        </div>

        <AccordionItem id="transaction" title="Transaction History" openSection={openSection} setOpenSection={setOpenSection}>
          <div className="flex justify-between items-center mb-3">
            <div className="flex gap-2">
              <button className="p-1.5 rounded-md hover:bg-gray-100 dark:hover:bg-gray-800 text-gray-600 dark:text-gray-400">
                <SlidersHorizontal size={20} />
              </button>
            </div>
          </div>
          <div className="flex bg-gray-100 dark:bg-gray-900 p-1 rounded-lg mb-3">
            {['All', 'Earned', 'Spent', 'Expired'].map((tab) => (
              <button
                key={tab}
                onClick={() => setFilter(tab)}
                className={`flex-1 py-1.5 text-xs font-medium rounded-md transition-all ${
                  filter === tab
                    ? 'bg-white dark:bg-gray-800 text-gray-900 dark:text-white shadow-sm'
                    : 'text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-200'
                }`}
              >
                {tab}
              </button>
            ))}
          </div>
          <div className="bg-white dark:bg-gray-900 rounded-xl border border-gray-100 dark:border-gray-800 divide-y divide-gray-100 dark:divide-gray-800">
            {transactions.map((tx) => (
              <div key={tx.id} className="p-4 flex items-start gap-3">
                <div className={`mt-1 p-1.5 rounded-full ${tx.type === 'earned' ? 'bg-green-50 dark:bg-green-900/20' : 'bg-blue-50 dark:bg-blue-900/20'}`}>
                  {tx.icon}
                </div>
                <div className="flex-1 min-w-0">
                  <h3 className="text-sm font-medium text-gray-900 dark:text-white truncate pr-2">{tx.title}</h3>
                  <p className="text-xs text-gray-500 dark:text-gray-400 mt-0.5">{tx.date}</p>
                </div>
                <span className={`text-sm font-bold whitespace-nowrap ${tx.color}`}>
                  {tx.amount > 0 ? '+' : ''}{tx.amount}
                </span>
              </div>
            ))}
          </div>
        </AccordionItem>

        <AccordionItem id="account" title="Account Details" openSection={openSection} setOpenSection={setOpenSection}>
          <div className="space-y-4">
            <div className="bg-white dark:bg-gray-900 rounded-xl border border-gray-100 dark:border-gray-800 p-4">
              <div className="flex items-center gap-3 mb-3">
                <div className="w-10 h-10 rounded-full overflow-hidden bg-gray-100 dark:bg-gray-800 flex items-center justify-center">
                  {userObject?.avatar_url ? (
                    <img src={userObject.avatar_url} alt="avatar" className="w-full h-full object-cover" />
                  ) : (
                    <User size={20} className="text-gray-500 dark:text-gray-400" />
                  )}
                </div>
                <div className="flex-1">
                  <div className="text-sm font-semibold text-gray-900 dark:text-white">{userObject?.full_name || userObject?.username || '-'}</div>
                  <div className="text-xs text-gray-500 dark:text-gray-400">@{userObject?.username || '-'}</div>
                </div>
                <div className="flex items-center gap-2">
                  {userObject?.role && (
                    <span className="px-2 py-1 rounded-md text-xs font-semibold bg-gray-100 dark:bg-gray-800 text-gray-700 dark:text-gray-300">{userObject.role}</span>
                  )}
                  {userObject?.role === 'vendor' && (
                    <span className={`px-2 py-1 rounded-md text-xs font-semibold ${userObject.vendor_validated ? 'bg-green-100 text-green-700 dark:bg-green-900/20 dark:text-green-300' : 'bg-yellow-100 text-yellow-700 dark:bg-yellow-900/20 dark:text-yellow-300'}`}>
                      {userObject.vendor_validated ? 'Validated' : 'Pending'}
                    </span>
                  )}
                </div>
              </div>

              <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                <div className="flex items-center justify-between bg-gray-50 dark:bg-gray-800 rounded-lg px-3 py-2">
                  <span className="text-xs text-gray-500 dark:text-gray-400">Email</span>
                  <div className="flex items-center gap-2">
                    <Mail size={14} className="text-gray-500 dark:text-gray-400" />
                    <span className="text-sm font-semibold text-gray-900 dark:text-white">{userObject?.email || '-'}</span>
                  </div>
                </div>
                <div className="flex items-center justify-between bg-gray-50 dark:bg-gray-800 rounded-lg px-3 py-2">
                  <span className="text-xs text-gray-500 dark:text-gray-400">Phone</span>
                  <div className="flex items-center gap-2">
                    <Phone size={14} className="text-gray-500 dark:text-gray-400" />
                    <span className="text-sm font-semibold text-gray-900 dark:text-white">{userObject?.phone || '-'}</span>
                  </div>
                </div>
                <div className="flex items-center justify-between bg-gray-50 dark:bg-gray-800 rounded-lg px-3 py-2">
                  <span className="text-xs text-gray-500 dark:text-gray-400">Balance</span>
                  <span className="text-sm font-bold text-gray-900 dark:text-white">
                    Coins {userObject?.wallet?.balance ? Math.floor(Number(userObject.wallet.balance)) : 0}
                  </span>
                </div>
                <div className="flex items-center justify-between bg-gray-50 dark:bg-gray-800 rounded-lg px-3 py-2">
                  <span className="text-xs text-gray-500 dark:text-gray-400">Currency</span>
                  <span className="text-sm font-semibold text-gray-900 dark:text-white">{userObject?.wallet?.currency || 'Coins'}</span>
                </div>
              </div>
            </div>

            {userObject?.role === 'vendor' && (
              <div className="bg-white dark:bg-gray-900 rounded-xl border border-gray-100 dark:border-gray-800 p-4">
                <div className="flex items-center justify-between mb-3">
                  <div className="flex items-center gap-2">
                    <Building2 size={18} className="text-gray-700 dark:text-gray-300" />
                    <span className="text-sm font-semibold text-gray-900 dark:text-white">Company Details</span>
                  </div>
                  {userObject?.company_details?.website && (
                    <a
                      href={userObject.company_details.website}
                      target="_blank"
                      rel="noreferrer"
                      className="text-xs text-insta-pink font-semibold hover:underline"
                    >
                      Visit site
                    </a>
                  )}
                </div>
                <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                  <div className="flex items-center justify-between bg-gray-50 dark:bg-gray-800 rounded-lg px-3 py-2">
                    <span className="text-xs text-gray-500 dark:text-gray-400">Company</span>
                    <span className="text-sm font-semibold text-gray-900 dark:text-white">{userObject?.company_details?.company_name || '-'}</span>
                  </div>
                  <div className="flex items-center justify-between bg-gray-50 dark:bg-gray-800 rounded-lg px-3 py-2">
                    <span className="text-xs text-gray-500 dark:text-gray-400">Legal Name</span>
                    <span className="text-sm font-semibold text-gray-900 dark:text-white">{userObject?.company_details?.legal_business_name || '-'}</span>
                  </div>
                  <div className="flex items-center justify-between bg-gray-50 dark:bg-gray-800 rounded-lg px-3 py-2">
                    <span className="text-xs text-gray-500 dark:text-gray-400">Industry</span>
                    <span className="text-sm font-semibold text-gray-900 dark:text-white">{userObject?.company_details?.industry || '-'}</span>
                  </div>
                  <div className="flex items-center justify-between bg-gray-50 dark:bg-gray-800 rounded-lg px-3 py-2">
                    <span className="text-xs text-gray-500 dark:text-gray-400">Website</span>
                    <div className="flex items-center gap-2">
                      <Globe size={14} className="text-gray-500 dark:text-gray-400" />
                      <span className="text-sm font-semibold text-gray-900 dark:text-white truncate max-w-[180px]">{userObject?.company_details?.website || '-'}</span>
                    </div>
                  </div>
                  <div className="flex items-center justify-between bg-gray-50 dark:bg-gray-800 rounded-lg px-3 py-2">
                    <span className="text-xs text-gray-500 dark:text-gray-400">Business Email</span>
                    <span className="text-sm font-semibold text-gray-900 dark:text-white">{userObject?.company_details?.business_email || '-'}</span>
                  </div>
                  <div className="flex items-center justify-between bg-gray-50 dark:bg-gray-800 rounded-lg px-3 py-2">
                    <span className="text-xs text-gray-500 dark:text-gray-400">Business Phone</span>
                    <span className="text-sm font-semibold text-gray-900 dark:text-white">{userObject?.company_details?.business_phone || '-'}</span>
                  </div>
                  <div className="flex items-center justify-between bg-gray-50 dark:bg-gray-800 rounded-lg px-3 py-2">
                    <span className="text-xs text-gray-500 dark:text-gray-400">City</span>
                    <span className="text-sm font-semibold text-gray-900 dark:text-white">{userObject?.company_details?.city || '-'}</span>
                  </div>
                  <div className="flex items-center justify-between bg-gray-50 dark:bg-gray-800 rounded-lg px-3 py-2">
                    <span className="text-xs text-gray-500 dark:text-gray-400">Country</span>
                    <span className="text-sm font-semibold text-gray-900 dark:text-white">{userObject?.company_details?.country || '-'}</span>
                  </div>
                </div>
              </div>
            )}
          </div>
        </AccordionItem>

        <AccordionItem id="redeem" title="Redeem Coins" openSection={openSection} setOpenSection={setOpenSection}>
          <div className="space-y-4">
            <div className="flex items-center justify-between">
              <span className="text-sm text-gray-700 dark:text-gray-300">Use coins on eligible orders.</span>
              <button className="px-3 py-1.5 text-xs rounded-md bg-gradient-to-tr from-insta-yellow via-insta-orange to-insta-pink text-white">Redeem</button>
            </div>
            <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
              {[
                { id: '50000', name: 'Starter', credits: '50,000', description: 'Perfect for testing campaigns and first ads.' },
                { id: '150000', name: 'Growth', credits: '150,000', description: 'Best for growing brands and multi-channel ads.' },
                { id: '200000', name: 'Scale', credits: '200,000', description: 'For serious campaigns and always-on promotion.' }
              ].map((pkg) => {
                const selected = redeemPackage === pkg.id;
                return (
                  <button
                    key={pkg.id}
                    type="button"
                    onClick={() => setRedeemPackage(pkg.id)}
                    className={`relative rounded-2xl border px-4 py-4 text-left transition-all bg-gray-50 dark:bg-gray-900 ${selected
                      ? 'border-insta-pink shadow-lg shadow-insta-pink/30 ring-2 ring-insta-pink/20 scale-[1.02]'
                      : 'border-gray-200 dark:border-gray-800 hover:border-insta-pink/60 hover:shadow-md'
                      }`}
                  >
                    {selected && (
                      <div className="absolute top-3 right-3 text-insta-pink">
                        <CheckCircle2 size={18} />
                      </div>
                    )}
                    <div className="text-xs font-semibold uppercase tracking-wide text-gray-500 dark:text-gray-400 mb-1">
                      {pkg.name} Package
                    </div>
                    <div className="text-2xl font-bold text-gray-900 dark:text-white mb-1">
                      {pkg.credits} credits
                    </div>
                    <div className="text-xs text-gray-500 dark:text-gray-400 mb-3">
                      Approx. budget {pkg.id}
                    </div>
                    <p className="text-sm text-gray-600 dark:text-gray-400">{pkg.description}</p>
                  </button>
                );
              })}
            </div>
            <p className="text-xs text-gray-500 dark:text-gray-400">You can change or top up later from your wallet.</p>
          </div>
        </AccordionItem>

        <AccordionItem id="help" title="Help" openSection={openSection} setOpenSection={setOpenSection}>
          <div className="space-y-2 text-sm text-gray-700 dark:text-gray-300">
            <div>How do coins work?</div>
            <div>Why is my balance changed?</div>
            <div>Contact support</div>
          </div>
        </AccordionItem>
      </div>
    </div>
  );
};

export default WalletDetails;
