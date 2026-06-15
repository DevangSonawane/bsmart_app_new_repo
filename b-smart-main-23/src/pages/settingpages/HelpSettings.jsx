import React from 'react';
import { Link } from 'react-router-dom';
import { ArrowLeft, HelpCircle } from 'lucide-react';

const HelpSettings = () => {
  return (
    <div className="min-h-screen bg-gray-50 dark:bg-black pb-20">
      <div className="sticky top-0 bg-white dark:bg-black border-b border-gray-100 dark:border-gray-800 px-4 py-3 flex items-center gap-3 z-40">
        <Link to="/settings/account" className="text-gray-800 dark:text-white">
          <ArrowLeft size={22} />
        </Link>
        <h1 className="text-base font-semibold dark:text-white">Help & Support</h1>
      </div>

      <div className="max-w-2xl mx-auto pt-4 px-4 space-y-4">
        <div className="bg-white dark:bg-gray-900 border border-gray-100 dark:border-gray-800 rounded-2xl p-6 shadow-sm">
          <div className="flex flex-col items-center text-center mb-6">
            <div className="w-16 h-16 rounded-full bg-pink-50 dark:bg-gray-800 flex items-center justify-center text-[#fa3f5e] mb-4">
              <HelpCircle size={32} />
            </div>
            <h2 className="text-xl font-bold text-gray-900 dark:text-white">How can we help?</h2>
            <p className="text-sm text-gray-500 mt-1">Our team is here to support you with any questions or issues.</p>
          </div>

          <div className="space-y-4">
            <div className="p-4 rounded-xl bg-gray-50 dark:bg-gray-800/50 border border-gray-100 dark:border-gray-800">
              <h3 className="font-semibold text-gray-900 dark:text-white text-sm mb-1">Frequently Asked Questions</h3>
              <p className="text-xs text-gray-500 leading-relaxed">Browse through our common questions about accounts, ads, and vendor tools.</p>
            </div>

            <div className="p-4 rounded-xl bg-gray-50 dark:bg-gray-800/50 border border-gray-100 dark:border-gray-800">
              <h3 className="font-semibold text-gray-900 dark:text-white text-sm mb-1">Contact Support</h3>
              <p className="text-xs text-gray-500 leading-relaxed mb-3">Email us directly for personalized assistance.</p>
              <a href="mailto:support@bebsmart.in"
                className="inline-block px-4 py-2 bg-[#fa3f5e] text-white text-xs font-bold rounded-lg hover:opacity-90 transition-opacity">
                Email Support
              </a>
            </div>

            <div className="p-4 rounded-xl bg-gray-50 dark:bg-gray-800/50 border border-gray-100 dark:border-gray-800">
              <h3 className="font-semibold text-gray-900 dark:text-white text-sm mb-1">Community Guidelines</h3>
              <p className="text-xs text-gray-500 leading-relaxed">Learn about our standards for maintaining a safe and professional community.</p>
            </div>
          </div>

          <div className="mt-8 text-center">
            <p className="text-[10px] text-gray-400 uppercase tracking-widest">B-Smart Support Version 1.0.0</p>
          </div>
        </div>
      </div>
    </div>
  );
};

export default HelpSettings;
