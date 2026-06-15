import React from 'react';
import { useLocation, useNavigate } from 'react-router-dom';
import CreatePostModal from '../components/CreatePostModal';

const CreatePostPage = () => {
  const navigate = useNavigate();
  const location = useLocation();
  const searchParams = new URLSearchParams(location.search);

  const requestedType = location.state?.initialType
    || location.state?.type
    || searchParams.get('type')
    || 'post';

  const initialType = ['post', 'reel', 'tweet', 'ad'].includes(requestedType)
    ? requestedType
    : 'post';

  return (
    <CreatePostModal
      isOpen
      onClose={() => navigate(-1)}
      initialType={initialType}
    />
  );
};

export default CreatePostPage;
