import React, { useEffect, useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import { Loader2 } from 'lucide-react';
import ServiceForm from '../myStore/components/ServiceForm';
import influencerServiceService from '../services/influencerServiceService';

export default function EditService() {
  const { serviceId } = useParams();
  const [service, setService] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    let alive = true;
    influencerServiceService.get(serviceId)
      .then((item) => {
        if (alive) setService(item);
      })
      .catch((err) => {
        if (alive) setError(err?.response?.data?.message || 'Service not found.');
      })
      .finally(() => {
        if (alive) setLoading(false);
      });
    return () => { alive = false; };
  }, [serviceId]);

  if (loading) return (
    <div className="min-h-screen bg-white dark:bg-black flex flex-col items-center justify-center gap-3">
      <Loader2 size={24} className="animate-spin text-[#fa3f5e]" />
      <p className="text-gray-500 dark:text-gray-400">Loading service...</p>
    </div>
  );

  if (!service) return (
    <div className="min-h-screen bg-white dark:bg-black flex flex-col items-center justify-center gap-3">
      <p className="text-gray-500 dark:text-gray-400">{error || 'Service not found.'}</p>
      <Link to="/market/my-store/services" className="text-[#fa3f5e] font-semibold text-sm">Back to My Store</Link>
    </div>
  );
  return <ServiceForm key={service.id} service={service} />;
}
