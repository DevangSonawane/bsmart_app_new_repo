import { useState } from "react";

const mockData = {
  totalActiveAds: 12,
  totalCoinsAvailable: 4820,
  totalCoinsUsed: 11340,
  totalClicks: 28419,
  totalImpressions: 891200,
  totalSpend: 6250,
  expiringCampaigns: 3,
  recentActivity: [
    { id: 1, type: "click", message: "Ad 'Summer Sale' received 240 new clicks", time: "2m ago", icon: "👆" },
    { id: 2, type: "warning", message: "Campaign 'Brand Boost' expiring in 2 days", time: "15m ago", icon: "⚠️" },
    { id: 3, type: "reject", message: "Ad 'Promo V2' was rejected — review content", time: "1h ago", icon: "❌" },
    { id: 4, type: "success", message: "'Flash Deals' reached 100K impressions", time: "3h ago", icon: "🎯" },
    { id: 5, type: "coins", message: "Coin balance running low — recharge soon", time: "5h ago", icon: "🪙" },
  ],
  alerts: [
    { type: "low-coins", message: "Your coin balance is low. Top up to keep ads running.", color: "text-amber-500 bg-amber-50 dark:bg-amber-900/20 border-amber-200 dark:border-amber-800" },
    { type: "rejected", message: "1 ad was rejected. Tap to review and resubmit.", color: "text-red-500 bg-red-50 dark:bg-red-900/20 border-red-200 dark:border-red-800" },
  ],
};

const MetricCard = ({ label, value, icon, sublabel, onClick, highlight }) => (
  <div
    onClick={onClick}
    className={`relative cursor-pointer rounded-2xl p-5 flex flex-col gap-3 transition-all duration-300 hover:scale-[1.02] hover:shadow-xl border ${
      highlight
        ? "bg-gradient-to-tr from-[#f09433] via-[#dc2743] to-[#bc1888] text-white border-transparent shadow-lg shadow-pink-500/20"
        : "bg-white dark:bg-gray-900 border-gray-100 dark:border-gray-800 hover:border-gray-200 dark:hover:border-gray-700"
    }`}
  >
    <div className="flex items-center justify-between">
      <span className="text-2xl">{icon}</span>
      <span
        className={`text-xs font-semibold px-2 py-1 rounded-full ${
          highlight
            ? "bg-white/20 text-white"
            : "bg-gray-100 dark:bg-gray-800 text-gray-500 dark:text-gray-400"
        }`}
      >
        {sublabel}
      </span>
    </div>
    <div>
      <div className={`text-3xl font-bold tracking-tight ${highlight ? "text-white" : "text-gray-900 dark:text-white"}`}>
        {typeof value === "number" ? value.toLocaleString() : value}
      </div>
      <div className={`text-sm mt-1 font-medium ${highlight ? "text-white/90" : "text-gray-500 dark:text-gray-400"}`}>
        {label}
      </div>
    </div>
    {onClick && (
      <div className={`absolute bottom-4 right-4 text-xs font-semibold opacity-60 hover:opacity-100 transition-opacity ${highlight ? "text-white" : "text-pink-600 dark:text-pink-400"}`}>
        View →
      </div>
    )}
  </div>
);

const AlertBanner = ({ alert, onDismiss }) => (
  <div className={`flex items-center justify-between rounded-xl px-4 py-3 text-sm font-medium border ${alert.color}`}>
    <div className="flex items-center gap-2">
      <span>{alert.type === "low-coins" ? "🪙" : "🚫"}</span>
      <span>{alert.message}</span>
    </div>
    <button
      onClick={onDismiss}
      className="ml-4 opacity-60 hover:opacity-100 transition-opacity text-lg leading-none"
    >
      ×
    </button>
  </div>
);

export default function VendorDashboard() {
  const [alerts, setAlerts] = useState(mockData.alerts);
  const [activeFilter, setActiveFilter] = useState(null);

  const dismissAlert = (index) => {
    setAlerts((prev) => prev.filter((_, i) => i !== index));
  };

  const handleMetricClick = (filter) => {
    setActiveFilter(filter);
    setTimeout(() => setActiveFilter(null), 1500);
  };

  const metrics = [
    { label: "Active Ads", value: mockData.totalActiveAds, icon: "📢", sublabel: "Running", onClick: () => handleMetricClick("active"), highlight: true },
    { label: "Coins Available", value: mockData.totalCoinsAvailable, icon: "🪙", sublabel: "Balance", onClick: () => handleMetricClick("coins") },
    { label: "Coins Used", value: mockData.totalCoinsUsed, icon: "💸", sublabel: "All Time", onClick: () => handleMetricClick("used") },
    { label: "Total Clicks", value: mockData.totalClicks, icon: "👆", sublabel: "Lifetime", onClick: () => handleMetricClick("clicks") },
    { label: "Total Impressions", value: mockData.totalImpressions, icon: "👁️", sublabel: "Lifetime", onClick: () => handleMetricClick("impressions") },
    { label: "Total Spend", value: `₹${mockData.totalSpend.toLocaleString()}`, icon: "📊", sublabel: "Spent", onClick: () => handleMetricClick("spend") },
    { label: "Expiring Soon", value: mockData.expiringCampaigns, icon: "⏳", sublabel: "Campaigns", onClick: () => handleMetricClick("expiring") },
  ];

  return (
    <div className="min-h-screen bg-gray-50 dark:bg-black font-sans transition-colors duration-300">
      <div className="max-w-7xl mx-auto p-6 md:p-8">

        {/* Header */}
        <div className="flex flex-col md:flex-row md:items-center justify-between mb-8 gap-4">
          <div>
            <div className="flex items-center gap-3 mb-2">
              <div className="w-8 h-8 rounded-lg flex items-center justify-center text-lg bg-gradient-to-tr from-orange-400 via-red-500 to-pink-600 text-white shadow-sm">
                📣
              </div>
              <span className="text-xs font-bold uppercase tracking-wider text-gray-500 dark:text-gray-400">
                Vendor Portal
              </span>
            </div>
            <h1 className="text-3xl md:text-4xl font-bold text-gray-900 dark:text-white tracking-tight">
              Ad Dashboard
            </h1>
            <p className="text-gray-500 dark:text-gray-400 text-sm mt-1">
              Thursday, March 05 · All metrics are live
            </p>
          </div>

          <button className="bg-gradient-to-r from-purple-600 via-pink-600 to-orange-500 text-white font-semibold rounded-xl px-6 py-3 text-sm flex items-center gap-2 shadow-lg shadow-pink-500/20 hover:shadow-pink-500/30 hover:-translate-y-0.5 transition-all">
            <span className="text-lg leading-none">+</span>
            Create New Ad
          </button>
        </div>

        {/* Alerts */}
        {alerts.length > 0 && (
          <div className="flex flex-col gap-3 mb-8 animate-fade-in">
            {alerts.map((alert, i) => (
              <AlertBanner key={i} alert={alert} onDismiss={() => dismissAlert(i)} />
            ))}
          </div>
        )}

        {/* Active filter toast */}
        {activeFilter && (
          <div className="mb-6 text-sm font-medium px-4 py-2 rounded-lg inline-block bg-pink-50 dark:bg-pink-900/20 text-pink-600 dark:text-pink-400 border border-pink-100 dark:border-pink-800 animate-fade-in">
            🔍 Filtering ads by: <strong>{activeFilter}</strong>
          </div>
        )}

        {/* Metrics Grid */}
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
          {metrics.map((m, i) => (
            <MetricCard key={i} {...m} />
          ))}
        </div>

        {/* Bottom Section: Recent Activity + Quick Stats */}
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">

          {/* Recent Activity */}
          <div className="lg:col-span-2 bg-white dark:bg-gray-900 rounded-2xl p-6 border border-gray-100 dark:border-gray-800 shadow-sm">
            <div className="flex items-center justify-between mb-6">
              <h2 className="text-lg font-bold text-gray-900 dark:text-white">Recent Activity</h2>
              <button className="text-xs font-semibold px-3 py-1.5 rounded-full bg-pink-50 dark:bg-pink-900/20 text-pink-600 dark:text-pink-400 hover:bg-pink-100 dark:hover:bg-pink-900/30 transition-colors">
                View All
              </button>
            </div>

            <div className="flex flex-col gap-1">
              {mockData.recentActivity.map((item) => (
                <div
                  key={item.id}
                  className="group flex items-start gap-4 rounded-xl p-3 hover:bg-gray-50 dark:hover:bg-gray-800/50 transition-colors cursor-pointer border-b border-gray-50 dark:border-gray-800 last:border-0"
                >
                  <div className="w-10 h-10 rounded-full flex items-center justify-center text-lg bg-gray-100 dark:bg-gray-800 flex-shrink-0 group-hover:scale-110 transition-transform">
                    {item.icon}
                  </div>
                  <div className="flex-1 min-w-0">
                    <p className="text-sm font-medium text-gray-800 dark:text-gray-200 leading-snug">
                      {item.message}
                    </p>
                    <span className="text-xs text-gray-500 dark:text-gray-400 mt-1 block">{item.time}</span>
                  </div>
                </div>
              ))}
            </div>
          </div>

          {/* Right Panel: Quick Stats + Coin Meter */}
          <div className="flex flex-col gap-6">

            {/* Coin Usage Meter */}
            <div className="bg-white dark:bg-gray-900 rounded-2xl p-6 border border-gray-100 dark:border-gray-800 shadow-sm">
              <h3 className="text-xs font-bold uppercase tracking-wider text-gray-500 dark:text-gray-400 mb-4">
                Coin Usage
              </h3>
              <div className="flex items-end justify-between mb-3">
                <div>
                  <div className="text-3xl font-black bg-clip-text text-transparent bg-gradient-to-r from-orange-500 to-pink-600">
                    {Math.round((mockData.totalCoinsUsed / (mockData.totalCoinsUsed + mockData.totalCoinsAvailable)) * 100)}%
                  </div>
                  <div className="text-xs text-gray-500 dark:text-gray-400 font-medium">of total coins used</div>
                </div>
                <div className="text-right">
                  <div className="text-sm font-bold text-gray-900 dark:text-white">
                    {mockData.totalCoinsAvailable.toLocaleString()} left
                  </div>
                  <div className="text-xs text-gray-500 dark:text-gray-400">available</div>
                </div>
              </div>
              <div className="h-2.5 rounded-full overflow-hidden bg-gray-100 dark:bg-gray-800">
                <div
                  className="h-full rounded-full transition-all duration-1000 ease-out bg-gradient-to-r from-orange-500 to-pink-600"
                  style={{
                    width: `${Math.round((mockData.totalCoinsUsed / (mockData.totalCoinsUsed + mockData.totalCoinsAvailable)) * 100)}%`,
                  }}
                />
              </div>
              <button className="w-full mt-5 bg-gray-900 dark:bg-white text-white dark:text-black font-bold rounded-xl py-3 text-sm hover:opacity-90 transition-opacity">
                🪙 Recharge Coins
              </button>
            </div>

            {/* Engagement Snapshot */}
            <div className="bg-white dark:bg-gray-900 rounded-2xl p-6 border border-gray-100 dark:border-gray-800 shadow-sm flex-1">
              <h3 className="text-xs font-bold uppercase tracking-wider text-gray-500 dark:text-gray-400 mb-4">
                Engagement Rate
              </h3>
              <div className="text-4xl font-black text-gray-900 dark:text-white mb-1">
                {((mockData.totalClicks / mockData.totalImpressions) * 100).toFixed(2)}%
              </div>
              <div className="text-xs text-gray-500 dark:text-gray-400 mb-6 font-medium">
                clicks ÷ impressions
              </div>
              <div className="flex flex-col gap-3">
                {[
                  { label: "CTR Benchmark", val: "3.20%", good: true },
                  { label: "Your CTR", val: `${((mockData.totalClicks / mockData.totalImpressions) * 100).toFixed(2)}%`, good: true },
                  { label: "Expiring Ads", val: mockData.expiringCampaigns, good: false },
                ].map((row, i) => (
                  <div key={i} className="flex items-center justify-between text-sm">
                    <span className="text-gray-600 dark:text-gray-400 font-medium">{row.label}</span>
                    <span
                      className={`font-bold px-2.5 py-1 rounded-md text-xs ${
                        row.good 
                          ? "bg-green-100 dark:bg-green-900/30 text-green-600 dark:text-green-400" 
                          : "bg-red-100 dark:bg-red-900/30 text-red-600 dark:text-red-400"
                      }`}
                    >
                      {row.val}
                    </span>
                  </div>
                ))}
              </div>
            </div>

          </div>
        </div>

      </div>
    </div>
  );
}