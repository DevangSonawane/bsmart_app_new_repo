import { useParams, useNavigate } from "react-router-dom";
import { 
  ArrowLeft, CheckCircle, BarChart2, DollarSign, Users,
  MessageCircle, Share2, ThumbsUp, Activity, Clock, Eye, Download
} from "lucide-react";
import { 
  XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, 
  BarChart, Bar, PieChart, Pie, Cell, Legend, AreaChart, Area
} from 'recharts';

// ─── Reusable Components ─────────────────────────────────────────────────────

const Badge = ({ status }) => {
  const styles = {
    active: "bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-400 border-green-200 dark:border-green-800",
    paused: "bg-amber-100 text-amber-700 dark:bg-amber-900/30 dark:text-amber-400 border-amber-200 dark:border-amber-800",
    completed: "bg-blue-100 text-blue-700 dark:bg-blue-900/30 dark:text-blue-400 border-blue-200 dark:border-blue-800",
    draft: "bg-gray-100 text-gray-700 dark:bg-gray-800 dark:text-gray-400 border-gray-200 dark:border-gray-700",
    rejected: "bg-red-100 text-red-700 dark:bg-red-900/30 dark:text-red-400 border-red-200 dark:border-red-800",
  };
  return (
    <span className={`px-2.5 py-1 rounded-full text-[10px] font-bold uppercase tracking-wider border ${styles[status.toLowerCase()] || styles.draft}`}>
      {status}
    </span>
  );
};

const Card = ({ title, children, className = "", action }) => (
  <div className={`bg-white dark:bg-gray-900 rounded-2xl border border-gray-100 dark:border-gray-800 p-6 shadow-sm ${className}`}>
    <div className="flex justify-between items-center mb-6">
      {title && <h3 className="text-lg font-bold text-gray-900 dark:text-white">{title}</h3>}
      {action}
    </div>
    {children}
  </div>
);

const StatCard = ({ label, value, trend, color = "blue", icon: Icon }) => {
  const colors = {
    blue: "bg-blue-50 text-blue-600 dark:bg-blue-900/20 dark:text-blue-400",
    purple: "bg-purple-50 text-purple-600 dark:bg-purple-900/20 dark:text-purple-400",
    pink: "bg-pink-50 text-pink-600 dark:bg-pink-900/20 dark:text-pink-400",
    orange: "bg-orange-50 text-orange-600 dark:bg-orange-900/20 dark:text-orange-400",
    green: "bg-green-50 text-green-600 dark:bg-green-900/20 dark:text-green-400",
  };

  return (
    <div className="p-5 rounded-2xl bg-white dark:bg-gray-900 border border-gray-100 dark:border-gray-800 hover:shadow-md transition-shadow">
      <div className="flex justify-between items-start mb-4">
        <div className={`p-3 rounded-xl ${colors[color]}`}>
          <Icon className="w-5 h-5" />
        </div>
        {trend && (
          <span className={`px-2 py-1 rounded-lg text-xs font-bold ${trend > 0 ? 'bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-400' : 'bg-red-100 text-red-700 dark:bg-red-900/30 dark:text-red-400'}`}>
            {trend > 0 ? '+' : ''}{trend}%
          </span>
        )}
      </div>
      <div className="text-2xl font-bold text-gray-900 dark:text-white mb-1">{value}</div>
      <div className="text-xs font-medium text-gray-500 dark:text-gray-400">{label}</div>
    </div>
  );
};

export default function AdDetails() {
  const { adId } = useParams();
  const navigate = useNavigate();

  // Mock Data (In a real app, fetch data based on adId)
  const ad = {
      id: adId || "AD-2024-001",
      name: "Summer Sale Campaign",
      category: "Fashion",
      status: "Active",
      totalCoins: 5000,
      coinsUsed: 2100,
      clicks: 850,
      impressions: 12500,
      startDate: "2024-03-01",
      endDate: "2024-03-15",
      performance: {
        reach: "10.2k",
        ctr: "6.8%",
        cpc: "₹2.47",
        cpm: "₹168",
        engagementRate: "4.2%",
        conversionRate: "1.8%",
        dailyData: [
          { name: 'Day 1', value: 120 }, { name: 'Day 2', value: 150 }, { name: 'Day 3', value: 180 },
          { name: 'Day 4', value: 140 }, { name: 'Day 5', value: 200 }, { name: 'Day 6', value: 250 },
          { name: 'Day 7', value: 300 }, { name: 'Day 8', value: 280 }, { name: 'Day 9', value: 320 },
          { name: 'Day 10', value: 350 }, { name: 'Day 11', value: 400 }, { name: 'Day 12', value: 380 },
          { name: 'Day 13', value: 420 }, { name: 'Day 14', value: 450 }, { name: 'Day 15', value: 480 }
        ],
        genderData: [
          { name: 'Male', value: 45 }, { name: 'Female', value: 55 }
        ],
        locationData: [
          { name: 'Mumbai', value: 30 }, { name: 'Delhi', value: 25 }, 
          { name: 'Bangalore', value: 20 }, { name: 'Hyderabad', value: 15 }, 
          { name: 'Pune', value: 10 }
        ],
        languageData: [
          { name: 'English', value: 60 }, { name: 'Hindi', value: 30 }, { name: 'Other', value: 10 }
        ],
      },
      engagement: { likes: 1200, comments: 450, shares: 85 },
      financial: { remaining: 2900, spend: 2100, tax: 378 },
      logs: [
        { action: "Ad Created", date: "2024-02-28 10:00 AM", user: "Admin" },
        { action: "Approved", date: "2024-02-29 02:30 PM", user: "System" },
        { action: "Started", date: "2024-03-01 09:00 AM", user: "System" },
      ]
  };

  const isEditable = ["Draft", "Paused"].includes(ad.status);
  const COLORS = ['#3b82f6', '#ec4899', '#8b5cf6', '#f59e0b', '#10b981'];

  return (
    <div className="min-h-screen bg-gray-50 dark:bg-black font-sans transition-colors duration-300">
      <div className="max-w-7xl mx-auto p-6 md:p-8">
        
        <div className="animate-fade-in pb-20 pt-6">
          {/* Header */}
          <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 mb-8">
            <div className="flex items-center gap-4">
              <button onClick={() => navigate('/vendor/ads-management')} className="p-2.5 rounded-xl bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-800 hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors shadow-sm">
                <ArrowLeft className="w-5 h-5 text-gray-600 dark:text-gray-300" />
              </button>
              <div>
                <div className="flex items-center gap-3">
                  <h1 className="text-2xl font-bold text-gray-900 dark:text-white">{ad.name}</h1>
                  <Badge status={ad.status} />
                </div>
                <div className="text-sm text-gray-500 dark:text-gray-400 mt-1 flex items-center gap-2">
                  <span className="font-mono bg-gray-100 dark:bg-gray-800 px-1.5 py-0.5 rounded text-xs">ID: {ad.id}</span>
                  <span>•</span>
                  <span>Created on {ad.startDate}</span>
                </div>
              </div>
            </div>
            <div className="flex gap-3">
              {isEditable && (
                <button className="px-5 py-2.5 rounded-xl text-sm font-bold bg-blue-600 text-white hover:bg-blue-700 transition-colors shadow-lg shadow-blue-500/20">
                  Save Changes
                </button>
              )}
              <button className="px-5 py-2.5 rounded-xl text-sm font-bold bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-800 text-gray-700 dark:text-gray-200 hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors shadow-sm">
                Export Report
              </button>
            </div>
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
            
            {/* Left Column (2/3) */}
            <div className="lg:col-span-2 space-y-8">
              
              {/* Section 1: Basic Info */}
              <Card title="Basic Information">
                <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                  <div>
                    <label className="text-xs font-bold text-gray-500 uppercase tracking-wide mb-2 block">Campaign Name</label>
                    <input 
                      type="text" 
                      defaultValue={ad.name} 
                      disabled={!isEditable}
                      className="w-full px-4 py-3 bg-gray-50 dark:bg-gray-800 rounded-xl border border-gray-200 dark:border-gray-700 text-sm font-semibold focus:ring-2 focus:ring-blue-500 outline-none transition-all"
                    />
                  </div>
                  <div>
                    <label className="text-xs font-bold text-gray-500 uppercase tracking-wide mb-2 block">Category</label>
                    <select 
                      defaultValue={ad.category} 
                      disabled={!isEditable}
                      className="w-full px-4 py-3 bg-gray-50 dark:bg-gray-800 rounded-xl border border-gray-200 dark:border-gray-700 text-sm font-semibold focus:ring-2 focus:ring-blue-500 outline-none transition-all appearance-none"
                    >
                      <option>Fashion</option>
                      <option>Electronics</option>
                      <option>Gifts</option>
                    </select>
                  </div>
                  <div>
                    <label className="text-xs font-bold text-gray-500 uppercase tracking-wide mb-2 block">Start Date</label>
                    <div className="flex items-center gap-3 px-4 py-3 bg-gray-50 dark:bg-gray-800 rounded-xl border border-gray-200 dark:border-gray-700 text-sm font-semibold text-gray-700 dark:text-gray-200">
                      <Clock className="w-4 h-4 text-gray-400" />
                      {ad.startDate}
                    </div>
                  </div>
                  <div>
                    <label className="text-xs font-bold text-gray-500 uppercase tracking-wide mb-2 block">End Date</label>
                    <div className="flex items-center gap-3 px-4 py-3 bg-gray-50 dark:bg-gray-800 rounded-xl border border-gray-200 dark:border-gray-700 text-sm font-semibold text-gray-700 dark:text-gray-200">
                      <Clock className="w-4 h-4 text-gray-400" />
                      {ad.endDate}
                    </div>
                  </div>
                </div>
              </Card>

              {/* Section 2: Performance Overview */}
              <div className="grid grid-cols-2 md:grid-cols-4 gap-5">
                <StatCard label="Total Impressions" value={ad.impressions.toLocaleString()} icon={Eye} trend={12} color="blue" />
                <StatCard label="Reach" value={ad.performance.reach} icon={Users} trend={8} color="purple" />
                <StatCard label="Clicks" value={ad.clicks} icon={Activity} trend={-2} color="orange" />
                <StatCard label="CTR" value={ad.performance.ctr} icon={BarChart2} color="green" />
                <StatCard label="CPC" value={ad.performance.cpc} icon={DollarSign} color="pink" />
                <StatCard label="CPM" value={ad.performance.cpm} icon={DollarSign} color="blue" />
                <StatCard label="Engagement" value={ad.performance.engagementRate} icon={ThumbsUp} trend={5} color="purple" />
                <StatCard label="Conversion" value={ad.performance.conversionRate} icon={CheckCircle} color="green" />
              </div>

              {/* Charts Grid */}
              <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                
                {/* Daily Performance Line Chart */}
                <Card title="Daily Performance" className="col-span-1 md:col-span-2">
                  <div className="h-72 w-full">
                    <ResponsiveContainer width="100%" height="100%">
                      <AreaChart data={ad.performance.dailyData} margin={{ top: 10, right: 10, left: -20, bottom: 0 }}>
                        <defs>
                          <linearGradient id="colorValue" x1="0" y1="0" x2="0" y2="1">
                            <stop offset="5%" stopColor="#3b82f6" stopOpacity={0.3}/>
                            <stop offset="95%" stopColor="#3b82f6" stopOpacity={0}/>
                          </linearGradient>
                        </defs>
                        <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#E5E7EB" />
                        <XAxis dataKey="name" axisLine={false} tickLine={false} tick={{fontSize: 12, fill: '#9CA3AF'}} dy={10} />
                        <YAxis axisLine={false} tickLine={false} tick={{fontSize: 12, fill: '#9CA3AF'}} />
                        <Tooltip 
                          contentStyle={{ backgroundColor: '#fff', borderRadius: '12px', border: 'none', boxShadow: '0 4px 6px -1px rgb(0 0 0 / 0.1)' }}
                          itemStyle={{ color: '#111827', fontWeight: 600 }}
                        />
                        <Area type="monotone" dataKey="value" stroke="#3b82f6" strokeWidth={3} fillOpacity={1} fill="url(#colorValue)" />
                      </AreaChart>
                    </ResponsiveContainer>
                  </div>
                </Card>

                {/* Gender Pie Chart */}
                <Card title="Demographics (Gender)">
                  <div className="h-64 w-full flex items-center justify-center">
                    <ResponsiveContainer width="100%" height="100%">
                      <PieChart>
                        <Pie
                          data={ad.performance.genderData}
                          cx="50%"
                          cy="50%"
                          innerRadius={60}
                          outerRadius={80}
                          paddingAngle={5}
                          dataKey="value"
                        >
                          {ad.performance.genderData.map((entry, index) => (
                            <Cell key={`cell-${index}`} fill={COLORS[index % COLORS.length]} />
                          ))}
                        </Pie>
                        <Tooltip contentStyle={{ borderRadius: '8px' }} />
                        <Legend verticalAlign="bottom" height={36} iconType="circle" />
                      </PieChart>
                    </ResponsiveContainer>
                  </div>
                </Card>

                {/* Location Bar Chart */}
                <Card title="Top Locations">
                  <div className="h-64 w-full">
                    <ResponsiveContainer width="100%" height="100%">
                      <BarChart data={ad.performance.locationData} layout="vertical" margin={{ top: 5, right: 30, left: 40, bottom: 5 }}>
                        <CartesianGrid strokeDasharray="3 3" horizontal={true} vertical={false} stroke="#E5E7EB" />
                        <XAxis type="number" hide />
                        <YAxis dataKey="name" type="category" axisLine={false} tickLine={false} tick={{fontSize: 12, fill: '#6B7280'}} width={60} />
                        <Tooltip cursor={{fill: 'transparent'}} contentStyle={{ borderRadius: '8px' }} />
                        <Bar dataKey="value" fill="#8b5cf6" radius={[0, 4, 4, 0]} barSize={20} />
                      </BarChart>
                    </ResponsiveContainer>
                  </div>
                </Card>

              </div>

              {/* Section 5: Activity Logs */}
              <Card title="Activity Logs">
                <div className="relative pl-4 border-l-2 border-gray-100 dark:border-gray-800 space-y-8">
                  {ad.logs.map((log, i) => (
                    <div key={i} className="relative">
                      <div className="absolute -left-[21px] top-1 w-3 h-3 rounded-full bg-blue-500 border-2 border-white dark:border-gray-900 shadow-sm" />
                      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-1">
                        <div className="text-sm font-bold text-gray-900 dark:text-white">{log.action}</div>
                        <div className="text-xs text-gray-400 flex items-center gap-1">
                          <Clock className="w-3 h-3" /> {log.date}
                        </div>
                      </div>
                      <div className="text-xs text-gray-500 mt-0.5">Performed by <span className="font-medium text-gray-700 dark:text-gray-300">{log.user}</span></div>
                    </div>
                  ))}
                </div>
              </Card>
            </div>

            {/* Right Column (1/3) */}
            <div className="space-y-8">
              
              {/* Section 3: Engagement Summary */}
              <Card title="Engagement">
                <div className="space-y-4">
                  {[
                    { label: "Likes", value: ad.engagement.likes, icon: ThumbsUp, color: "bg-red-50 text-red-600" },
                    { label: "Comments", value: ad.engagement.comments, icon: MessageCircle, color: "bg-blue-50 text-blue-600" },
                    { label: "Shares", value: ad.engagement.shares, icon: Share2, color: "bg-green-50 text-green-600" },
                  ].map((item, i) => (
                    <div key={i} className="flex justify-between items-center p-4 rounded-xl bg-gray-50 dark:bg-gray-800/50 hover:bg-gray-100 dark:hover:bg-gray-800 transition-colors">
                      <div className="flex items-center gap-4">
                        <div className={`p-2.5 rounded-lg ${item.color} dark:bg-opacity-20`}>
                          <item.icon className="w-4 h-4" />
                        </div>
                        <span className="text-sm font-semibold text-gray-700 dark:text-gray-200">{item.label}</span>
                      </div>
                      <span className="text-lg font-bold text-gray-900 dark:text-white">{item.value.toLocaleString()}</span>
                    </div>
                  ))}

                  <div className="pt-6 mt-2 border-t border-gray-100 dark:border-gray-800">
                    <label className="flex items-center justify-between cursor-pointer group">
                      <div className="flex flex-col">
                        <span className="text-sm font-bold text-gray-900 dark:text-white group-hover:text-blue-600 transition-colors">Disable Comments</span>
                        <span className="text-xs text-gray-500">Prevent new comments on this ad</span>
                      </div>
                      <div className="relative inline-block w-11 h-6 align-middle select-none transition duration-200 ease-in">
                        <input type="checkbox" name="toggle" id="toggle" className="toggle-checkbox absolute block w-5 h-5 rounded-full bg-white border-4 appearance-none cursor-pointer translate-x-0.5 translate-y-0.5 transition-transform duration-200 ease-in-out shadow-sm" />
                        <label htmlFor="toggle" className="toggle-label block overflow-hidden h-6 rounded-full bg-gray-200 dark:bg-gray-700 cursor-pointer"></label>
                      </div>
                    </label>
                  </div>
                </div>
              </Card>

              {/* Section 4: Financial Report */}
              <Card title="Financial Report">
                <div className="relative p-6 rounded-2xl bg-gradient-to-br from-gray-900 via-gray-800 to-black text-white overflow-hidden mb-6 shadow-lg">
                  <div className="absolute top-0 right-0 w-32 h-32 bg-blue-500/10 rounded-full blur-3xl -translate-y-1/2 translate-x-1/2"></div>
                  <div className="relative z-10">
                    <div className="text-xs text-gray-400 font-bold uppercase tracking-wider mb-2">Total Spend</div>
                    <div className="text-4xl font-extrabold mb-6 tracking-tight">₹ {ad.financial.spend.toLocaleString()}</div>
                    <div className="grid grid-cols-2 gap-6 pt-4 border-t border-white/10">
                      <div>
                        <div className="text-gray-400 text-[10px] font-bold uppercase tracking-wider mb-1">Budget</div>
                        <div className="font-bold text-lg">₹ {ad.totalCoins.toLocaleString()}</div>
                      </div>
                      <div>
                        <div className="text-gray-400 text-[10px] font-bold uppercase tracking-wider mb-1">Remaining</div>
                        <div className="font-bold text-lg text-emerald-400">₹ {ad.financial.remaining.toLocaleString()}</div>
                      </div>
                    </div>
                  </div>
                </div>

                <div className="space-y-4 text-sm">
                  <div className="flex justify-between items-center text-gray-500 dark:text-gray-400">
                    <span>Base Cost</span>
                    <span className="font-medium">₹ {(ad.financial.spend - ad.financial.tax).toLocaleString()}</span>
                  </div>
                  <div className="flex justify-between items-center text-gray-500 dark:text-gray-400">
                    <span>Tax (18% GST)</span>
                    <span className="font-medium">₹ {ad.financial.tax.toLocaleString()}</span>
                  </div>
                  <div className="flex justify-between items-center font-bold text-gray-900 dark:text-white pt-4 border-t border-gray-100 dark:border-gray-800 text-base">
                    <span>Total Amount</span>
                    <span>₹ {ad.financial.spend.toLocaleString()}</span>
                  </div>
                </div>

                <button className="w-full mt-8 py-3.5 rounded-xl border border-gray-200 dark:border-gray-700 text-sm font-bold flex items-center justify-center gap-2 hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors shadow-sm">
                  <Download className="w-4 h-4" /> Download Invoice
                </button>
              </Card>

            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
