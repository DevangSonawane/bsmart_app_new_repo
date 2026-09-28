import React from 'react';
import { Navigate } from 'react-router-dom';
import { useSelector } from 'react-redux';
import Ads from './Ads';

const VendorAds = () => {
  const { userObject } = useSelector((state) => state.auth);

  if (userObject?.role !== 'vendor') return <Navigate to="/ads" replace />;

  return <Ads feedMode="vendor" />;
};

export default VendorAds;
