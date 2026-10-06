import React from 'react';
import { Navigate, useLocation } from 'react-router-dom';
import { useSelector } from 'react-redux';

const ProtectedRoute = ({ children, allowedRoles, redirectTo = '/' }) => {
  const { isAuthenticated, loading, userObject } = useSelector((state) => state.auth);
  const location = useLocation();

  if (loading) {
    // You can replace this with a proper loading spinner
    return (
      <div className="flex items-center justify-center min-h-screen bg-white dark:bg-black">
        <div className="animate-spin rounded-full h-12 w-12 border-t-2 border-b-2 border-[#fa3f5e]"></div>
      </div>
    );
  }

  if (!isAuthenticated) {
    return <Navigate to="/login" state={{ from: location }} replace />;
  }

  if (allowedRoles?.length && !allowedRoles.includes(userObject?.role)) {
    return <Navigate to={redirectTo} replace />;
  }

  return children;
};

export default ProtectedRoute;
