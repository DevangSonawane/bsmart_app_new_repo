import React from 'react';
import { Link } from 'react-router-dom';
import { ArrowLeft, Smartphone, Hash, Building2, Globe, Linkedin, Youtube, ChevronRight } from 'lucide-react';

const SectionTitle = ({ title }) => (
  <p className="text-[11px] font-bold text-[#fa3f5e] uppercase tracking-widest mb-2 px-1">{title}</p>
);

const InfoRow = ({ icon: Icon, iconBg, iconColor, label, value }) => (
  <div className="flex items-center justify-between px-4 py-3.5 border-b border-gray-100 dark:border-gray-800 last:border-0">
    <div className="flex items-center gap-3">
      <div className={`w-9 h-9 rounded-full flex items-center justify-center flex-shrink-0 ${iconBg}`}>
        <Icon size={16} className={iconColor} />
      </div>
      <p className="text-sm font-medium text-gray-900 dark:text-white">{label}</p>
    </div>
    <span className="text-sm font-semibold text-gray-500 dark:text-gray-400">{value}</span>
  </div>
);

const ExternalRow = ({ icon: Icon, iconBg, iconColor, label, href }) => (
  <a
    href={href}
    target="_blank"
    rel="noopener noreferrer"
    className="flex items-center justify-between px-4 py-3.5 border-b border-gray-100 dark:border-gray-800 last:border-0 hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors"
  >
    <div className="flex items-center gap-3">
      <div className={`w-9 h-9 rounded-full flex items-center justify-center flex-shrink-0 ${iconBg}`}>
        <Icon size={16} className={iconColor} />
      </div>
      <p className="text-sm font-medium text-gray-900 dark:text-white">{label}</p>
    </div>
    <ChevronRight size={16} className="text-gray-400" />
  </a>
);

const AboutSettings = () => {
  return (
    <div className="min-h-screen bg-gray-50 dark:bg-black pb-24 max-w-[1100px] mx-auto">

      {/* Header */}
      <div className="sticky top-0 bg-white dark:bg-black border-b border-gray-100 dark:border-gray-800 px-4 py-3 flex items-center justify-between z-40">
        <Link to="/settings" className="text-gray-800 dark:text-white p-1">
          <ArrowLeft size={22} />
        </Link>
        <h1 className="text-base font-semibold dark:text-white">About bSmart</h1>
        <div className="w-8" />
      </div>

      <div className="max-w-2xl mx-auto px-4 pt-5 space-y-5">

        {/* App logo hero */}
        <div className="bg-white dark:bg-gray-900 rounded-2xl border border-gray-100 dark:border-gray-800 shadow-sm p-6 flex flex-col items-center text-center">
          <div className="w-20 h-20 rounded-2xl bg-gradient-to-br from-[#fa3f5e] to-orange-400 flex items-center justify-center shadow-md mb-3">
            <span className="text-white text-3xl font-black tracking-tight">B</span>
          </div>
          <h2 className="text-xl font-bold text-gray-900 dark:text-white">bSmart</h2>
          <p className="text-xs text-gray-400 dark:text-gray-500 mt-1">Smart Social · Smarter Business</p>
        </div>

        {/* ── Application Information ── */}
        <div>
          <SectionTitle title="Application Information" />
          <div className="bg-white dark:bg-gray-900 rounded-2xl border border-gray-100 dark:border-gray-800 shadow-sm overflow-hidden">
            <InfoRow
              icon={Smartphone}
              iconBg="bg-blue-50 dark:bg-gray-800"
              iconColor="text-blue-500"
              label="App Version"
              value="1.0.0"
            />
            <InfoRow
              icon={Hash}
              iconBg="bg-purple-50 dark:bg-gray-800"
              iconColor="text-purple-500"
              label="Build Number"
              value="100"
            />
          </div>
        </div>

        {/* ── Company Information ── */}
        <div>
          <SectionTitle title="Company Information" />
          <div className="bg-white dark:bg-gray-900 rounded-2xl border border-gray-100 dark:border-gray-800 shadow-sm overflow-hidden">
            <div className="px-4 py-4 flex items-center gap-3">
              <div className="w-9 h-9 rounded-full flex items-center justify-center flex-shrink-0 bg-orange-50 dark:bg-gray-800">
                <Building2 size={16} className="text-orange-500" />
              </div>
              <div>
                <p className="text-sm font-semibold text-gray-900 dark:text-white">RuVees IT Solution Pvt Ltd</p>
                <p className="text-xs text-gray-500 dark:text-gray-400 mt-0.5">Registered company · India</p>
              </div>
            </div>
          </div>
        </div>

        {/* ── Links ── */}
        <div>
          <SectionTitle title="Links" />
          <div className="bg-white dark:bg-gray-900 rounded-2xl border border-gray-100 dark:border-gray-800 shadow-sm overflow-hidden">
            <ExternalRow
              icon={Globe}
              iconBg="bg-teal-50 dark:bg-gray-800"
              iconColor="text-teal-500"
              label="Website"
              href="https://bebsmart.in"
            />
            <ExternalRow
              icon={Linkedin}
              iconBg="bg-blue-50 dark:bg-gray-800"
              iconColor="text-blue-600"
              label="LinkedIn"
              href="https://linkedin.com/company/bebsmart"
            />
            <ExternalRow
              icon={Youtube}
              iconBg="bg-red-50 dark:bg-gray-800"
              iconColor="text-red-500"
              label="YouTube"
              href="https://youtube.com/@bebsmart"
            />
          </div>
        </div>

        <p className="text-center text-[11px] text-gray-400 dark:text-gray-600 pb-4">
          © 2024 RuVees IT Solution Pvt Ltd · All rights reserved
        </p>

      </div>
    </div>
  );
};

export default AboutSettings;
