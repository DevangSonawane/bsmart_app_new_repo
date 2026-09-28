import React from 'react';
import { Link, useParams } from 'react-router-dom';
import { useSelector } from 'react-redux';
import ServiceForm from '../myStore/components/ServiceForm';

export default function EditService() {
  const { serviceId } = useParams();
  const service = useSelector((state) => state.services.items.find((item) => String(item.id) === serviceId));
  if (!service) return (
    <div className="min-h-screen bg-white dark:bg-black flex flex-col items-center justify-center gap-3">
      <p className="text-gray-500 dark:text-gray-400">Service not found.</p>
      <Link to="/market/my-store/services" className="text-[#fa3f5e] font-semibold text-sm">Back to My Store</Link>
    </div>
  );
  return <ServiceForm key={service.id} service={service} />;
}
