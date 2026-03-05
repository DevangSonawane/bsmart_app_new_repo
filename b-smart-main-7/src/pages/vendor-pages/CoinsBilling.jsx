import { useState } from "react";
import { Coins, CreditCard, TicketPercent, CalendarDays, Download, Receipt, ShieldCheck, Building2, MapPin } from "lucide-react";

export default function CoinsBilling() {
  const [packageId, setPackageId] = useState("5k");
  const [paymentMethod, setPaymentMethod] = useState("card");
  const [coupon, setCoupon] = useState("");
  const [billing, setBilling] = useState({ name: "", address: "", city: "", zip: "" });

  const wallet = {
    totalPurchased: 50000,
    used: 21000,
    remaining: 29000,
    expiry: "2026-12-31",
  };

  const packages = [
    { id: "1k", label: "1,000 Coins", price: "₹999" },
    { id: "5k", label: "5,000 Coins", price: "₹4,499" },
    { id: "10k", label: "10,000 Coins", price: "₹8,499" },
    { id: "50k", label: "50,000 Coins", price: "₹39,999" },
  ];

  return (
    <div className="min-h-screen bg-gray-50 dark:bg-black font-sans transition-colors duration-300">
      <div className="max-w-7xl mx-auto p-6 md:p-8">
        <div className="mb-8">
          <h1 className="text-3xl md:text-4xl font-extrabold tracking-tight mb-2">
            <span className="bg-clip-text text-transparent bg-gradient-to-r from-orange-500 via-red-500 to-pink-600">
              Coins & Billing
            </span>
          </h1>
          <p className="text-gray-500 dark:text-gray-400">Manage wallet balance and purchase coins securely.</p>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6 mb-8">
          <div className="lg:col-span-2 p-6 rounded-3xl bg-gradient-to-br from-gray-900 to-black text-white relative overflow-hidden">
            <div className="absolute top-0 right-0 w-64 h-64 bg-yellow-500/10 rounded-full blur-3xl -translate-y-1/2 translate-x-1/2" />
            <div className="relative z-10">
              <div className="text-sm font-medium text-gray-400 mb-1">Wallet Overview</div>
              <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
                <div className="p-4 rounded-2xl bg-white/5">
                  <div className="flex items-center gap-2 text-yellow-300 mb-1"><Coins className="w-4 h-4" /> <span className="text-xs font-bold uppercase tracking-wider">Purchased</span></div>
                  <div className="text-2xl font-extrabold">{wallet.totalPurchased.toLocaleString()}</div>
                </div>
                <div className="p-4 rounded-2xl bg-white/5">
                  <div className="flex items-center gap-2 text-rose-300 mb-1"><Receipt className="w-4 h-4" /> <span className="text-xs font-bold uppercase tracking-wider">Used</span></div>
                  <div className="text-2xl font-extrabold">{wallet.used.toLocaleString()}</div>
                </div>
                <div className="p-4 rounded-2xl bg-white/5">
                  <div className="flex items-center gap-2 text-emerald-300 mb-1"><ShieldCheck className="w-4 h-4" /> <span className="text-xs font-bold uppercase tracking-wider">Remaining</span></div>
                  <div className="text-2xl font-extrabold">{wallet.remaining.toLocaleString()}</div>
                </div>
                <div className="p-4 rounded-2xl bg-white/5">
                  <div className="flex items-center gap-2 text-sky-300 mb-1"><CalendarDays className="w-4 h-4" /> <span className="text-xs font-bold uppercase tracking-wider">Expiry</span></div>
                  <div className="text-lg font-bold">{wallet.expiry}</div>
                </div>
              </div>
              <div className="mt-6 flex gap-3">
                <button className="px-4 py-2 rounded-xl bg-white/10 hover:bg-white/20 backdrop-blur-sm text-sm font-semibold transition-colors">
                  Download Receipt
                </button>
                <button className="px-4 py-2 rounded-xl bg-white/10 hover:bg-white/20 backdrop-blur-sm text-sm font-semibold transition-colors">
                  Generate Invoice
                </button>
              </div>
            </div>
          </div>

          <div className="p-6 rounded-3xl bg-white dark:bg-gray-900 border border-gray-100 dark:border-gray-800">
            <h3 className="text-lg font-bold text-gray-900 dark:text-white mb-4">Quick Actions</h3>
            <div className="space-y-3">
              <button className="w-full p-3 rounded-xl bg-gray-50 dark:bg-gray-800 hover:bg-gray-100 dark:hover:bg-gray-700 text-left text-sm font-semibold text-gray-700 dark:text-gray-200 transition-colors flex justify-between items-center">
                <span>View Pricing Plans</span>
                <span>→</span>
              </button>
              <button className="w-full p-3 rounded-xl bg-gray-50 dark:bg-gray-800 hover:bg-gray-100 dark:hover:bg-gray-700 text-left text-sm font-semibold text-gray-700 dark:text-gray-200 transition-colors flex justify-between items-center">
                <span>Manage Payment Methods</span>
                <span>→</span>
              </button>
            </div>
          </div>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          <div className="lg:col-span-2 p-6 rounded-3xl bg-white dark:bg-gray-900 border border-gray-100 dark:border-gray-800">
            <h3 className="text-lg font-bold text-gray-900 dark:text-white mb-6">Purchase Coins</h3>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              <div>
                <label className="text-xs font-bold text-gray-500 uppercase tracking-wider mb-2 block">Select Coin Package</label>
                <div className="grid grid-cols-2 gap-3">
                  {packages.map(p => (
                    <button
                      key={p.id}
                      onClick={() => setPackageId(p.id)}
                      className={`p-4 rounded-2xl border text-left transition-colors ${packageId === p.id ? "border-black dark:border-white bg-gray-50 dark:bg-gray-800" : "border-gray-200 dark:border-gray-800 hover:bg-gray-50 dark:hover:bg-gray-800"}`}
                    >
                      <div className="flex items-center justify-between">
                        <div className="font-bold text-gray-900 dark:text-white">{p.label}</div>
                        <Coins className="w-4 h-4 text-yellow-500" />
                      </div>
                      <div className="text-sm text-gray-500 mt-1">{p.price}</div>
                    </button>
                  ))}
                </div>
              </div>
              <div>
                <label className="text-xs font-bold text-gray-500 uppercase tracking-wider mb-2 block">Payment Method</label>
                <div className="grid grid-cols-2 gap-3">
                  {[
                    { id: "card", label: "Credit/Debit Card", icon: CreditCard },
                    { id: "upi", label: "UPI", icon: Receipt },
                    { id: "netbank", label: "Net Banking", icon: ShieldCheck },
                    { id: "wallet", label: "Wallet", icon: Coins },
                  ].map(opt => (
                    <button
                      key={opt.id}
                      onClick={() => setPaymentMethod(opt.id)}
                      className={`p-4 rounded-2xl border text-left transition-colors ${paymentMethod === opt.id ? "border-black dark:border-white bg-gray-50 dark:bg-gray-800" : "border-gray-200 dark:border-gray-800 hover:bg-gray-50 dark:hover:bg-gray-800"}`}
                    >
                      <div className="flex items-center gap-3">
                        <opt.icon className="w-4 h-4 text-gray-600 dark:text-gray-300" />
                        <div className="font-semibold text-gray-900 dark:text-white">{opt.label}</div>
                      </div>
                    </button>
                  ))}
                </div>
              </div>
              <div>
                <label className="text-xs font-bold text-gray-500 uppercase tracking-wider mb-2 block">Apply Coupon</label>
                <div className="flex gap-2">
                  <input
                    value={coupon}
                    onChange={e => setCoupon(e.target.value)}
                    placeholder="Enter coupon code"
                    className="flex-1 px-4 py-2.5 rounded-xl border border-gray-200 dark:border-gray-800 bg-white dark:bg-gray-900 text-sm outline-none focus:ring-2 focus:ring-blue-500/20"
                  />
                  <button className="px-4 py-2.5 rounded-xl border border-gray-200 dark:border-gray-800 text-sm font-bold hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors">
                    Apply
                  </button>
                </div>
              </div>
              <div className="space-y-3">
                <label className="text-xs font-bold text-gray-500 uppercase tracking-wider block">Billing Address</label>
                <input
                  value={billing.name}
                  onChange={e => setBilling({ ...billing, name: e.target.value })}
                  placeholder="Full Name"
                  className="w-full px-4 py-2.5 rounded-xl border border-gray-200 dark:border-gray-800 bg-white dark:bg-gray-900 text-sm outline-none focus:ring-2 focus:ring-blue-500/20"
                />
                <input
                  value={billing.address}
                  onChange={e => setBilling({ ...billing, address: e.target.value })}
                  placeholder="Street Address"
                  className="w-full px-4 py-2.5 rounded-xl border border-gray-200 dark:border-gray-800 bg-white dark:bg-gray-900 text-sm outline-none focus:ring-2 focus:ring-blue-500/20"
                />
                <div className="grid grid-cols-2 gap-3">
                  <input
                    value={billing.city}
                    onChange={e => setBilling({ ...billing, city: e.target.value })}
                    placeholder="City"
                    className="w-full px-4 py-2.5 rounded-xl border border-gray-200 dark:border-gray-800 bg-white dark:bg-gray-900 text-sm outline-none focus:ring-2 focus:ring-blue-500/20"
                  />
                  <input
                    value={billing.zip}
                    onChange={e => setBilling({ ...billing, zip: e.target.value })}
                    placeholder="ZIP / Postal Code"
                    className="w-full px-4 py-2.5 rounded-xl border border-gray-200 dark:border-gray-800 bg-white dark:bg-gray-900 text-sm outline-none focus:ring-2 focus:ring-blue-500/20"
                  />
                </div>
              </div>
            </div>
            <div className="mt-6 flex flex-col sm:flex-row gap-3">
              <button className="px-6 py-3 rounded-xl bg-gradient-to-r from-purple-600 to-pink-600 text-white font-bold hover:opacity-90 transition-opacity shadow-lg shadow-pink-500/20">
                Pay Securely
              </button>
              <button className="px-6 py-3 rounded-xl border border-gray-200 dark:border-gray-800 font-bold hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors">
                Download Receipt
              </button>
            </div>
            <div className="mt-3 text-xs text-gray-500">
              Auto credit to wallet after successful payment.
            </div>
          </div>
          <div className="p-6 rounded-3xl bg-white dark:bg-gray-900 border border-gray-100 dark:border-gray-800">
            <h3 className="text-lg font-bold text-gray-900 dark:text-white mb-4">Billing Summary</h3>
            <div className="space-y-3 text-sm">
              <div className="flex justify-between"><span>Selected Package</span><span>{packages.find(p => p.id === packageId)?.label}</span></div>
              <div className="flex justify-between"><span>Method</span><span className="capitalize">{paymentMethod}</span></div>
              <div className="flex justify-between"><span>Coupon</span><span>{coupon ? coupon.toUpperCase() : "None"}</span></div>
              <div className="flex justify-between font-bold pt-2 border-t border-gray-100 dark:border-gray-800"><span>Payable</span><span>{packages.find(p => p.id === packageId)?.price}</span></div>
            </div>
            <div className="mt-6 p-4 rounded-2xl bg-gray-50 dark:bg-gray-800">
              <div className="text-xs font-bold text-gray-500 uppercase tracking-wider mb-2">Invoice</div>
              <div className="flex gap-2">
                <button className="flex-1 px-4 py-2.5 rounded-xl border border-gray-200 dark:border-gray-800 text-sm font-bold hover:bg-gray-100 dark:hover:bg-gray-800 transition-colors flex items-center justify-center gap-2">
                  <Download className="w-4 h-4" /> Download
                </button>
                <button className="flex-1 px-4 py-2.5 rounded-xl border border-gray-200 dark:border-gray-800 text-sm font-bold hover:bg-gray-100 dark:hover:bg-gray-800 transition-colors flex items-center justify-center gap-2">
                  <Receipt className="w-4 h-4" /> Generate
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
