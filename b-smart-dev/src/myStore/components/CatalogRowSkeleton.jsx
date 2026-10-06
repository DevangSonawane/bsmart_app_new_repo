import React from 'react';

const Bar = ({ className = '' }) => <div className={`animate-pulse bg-gray-200 dark:bg-gray-800 rounded ${className}`} />;

// Skeleton row matching the [Item, Price, Middle stat, (Status), Visibility, Actions]
// table shape shared by My Store's Products and Services list pages. Pass
// showStatus for tables that added the extra Status column (e.g. Products).
export default function CatalogRowSkeleton({ showStatus = false }) {
  return (
    <tr>
      <td className="rounded-l-xl border-y border-l border-gray-100 bg-white px-4 py-3 dark:border-gray-800 dark:bg-gray-900">
        <div className="flex items-start gap-3.5">
          <Bar className="w-24 h-24 rounded-xl flex-shrink-0" />
          <div className="min-w-0 flex-1 py-1 space-y-2">
            <Bar className="h-4 w-16 rounded-full" />
            <Bar className="h-4 w-4/5" />
            <Bar className="h-3 w-2/5" />
          </div>
        </div>
      </td>
      <td className="border-y border-gray-100 bg-white px-4 py-3 align-middle dark:border-gray-800 dark:bg-gray-900"><Bar className="h-4 w-14" /></td>
      <td className="border-y border-gray-100 bg-white px-4 py-3 align-middle dark:border-gray-800 dark:bg-gray-900"><Bar className="h-4 w-16" /></td>
      {showStatus && <td className="border-y border-gray-100 bg-white px-4 py-3 align-middle dark:border-gray-800 dark:bg-gray-900"><Bar className="h-6 w-16 rounded-full" /></td>}
      <td className="border-y border-gray-100 bg-white px-4 py-3 align-middle dark:border-gray-800 dark:bg-gray-900"><Bar className="h-6 w-20 rounded-full" /></td>
      <td className="rounded-r-xl border-y border-r border-gray-100 bg-white px-4 py-3 text-right align-middle dark:border-gray-800 dark:bg-gray-900">
        <Bar className="h-7 w-7 rounded-lg ml-auto" />
      </td>
    </tr>
  );
}
