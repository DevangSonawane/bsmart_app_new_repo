import React, { useState, useEffect, useCallback } from 'react';
import { Link, useParams } from 'react-router-dom';
import { Loader2, AlertCircle, ArrowLeft } from 'lucide-react';
import api from '../lib/api';
import bsmartIcon from '../assets/bsmart_logo.png';

const TITLE_FALLBACKS = {
  terms: 'Terms & Conditions',
  privacy: 'Privacy Policy',
  refund: 'Refund Policy',
  community_guidelines: 'Community Guidelines',
  'child-safety-standards': 'Child Safety Standards',
  support: 'Support',
  marketing: 'B-Smart | Connect & Grow',
  guides: 'Guides',
};

// Public, unauthenticated policy viewer — reachable without logging in so
// external reviewers (e.g. Google Play / OAuth verification) and users can
// always read Terms, Privacy, Refund, Community Guidelines, and the Child
// Safety Standards page.
const PublicPolicyPage = () => {
  const { type } = useParams();
  const [html, setHtml] = useState('');
  const [title, setTitle] = useState(TITLE_FALLBACKS[type] || 'Policy');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  const fetchPolicy = useCallback(async () => {
    try {
      setLoading(true);
      setError('');
      const res = await api.get('/policies/app/member', { params: { type } });
      const data = res.data?.data?.[0];
      if (!data) {
        setError('Policy not found.');
        return;
      }
      setHtml(data.content || '');
      setTitle(data.title || TITLE_FALLBACKS[type] || 'Policy');
    } catch (e) {
      setError(e?.response?.data?.message || 'Failed to load policy.');
    } finally {
      setLoading(false);
    }
  }, [type]);

  useEffect(() => { fetchPolicy(); }, [fetchPolicy]);

  return (
    <div className="min-h-screen bg-white dark:bg-black">
      <div className="sticky top-0 bg-white dark:bg-black border-b border-gray-100 dark:border-gray-800 px-4 py-3 flex items-center gap-3 z-10">
        <Link to="/login" className="text-gray-800 dark:text-white p-1">
          <ArrowLeft size={20} />
        </Link>
        <img src={bsmartIcon} alt="B-Smart" className="w-8 h-8 object-contain flex-shrink-0" />
        <h1 className="text-base font-semibold dark:text-white">{title}</h1>
      </div>

      <div className="max-w-2xl mx-auto px-5 py-8">
        {loading ? (
          <div className="flex flex-col items-center justify-center py-20 gap-3">
            <Loader2 size={28} className="animate-spin text-gray-300 dark:text-gray-600" />
            <span className="text-sm text-gray-400">Loading…</span>
          </div>
        ) : error ? (
          <div className="flex flex-col items-center justify-center py-16 gap-3 text-red-500">
            <AlertCircle size={28} />
            <p className="text-sm">{error}</p>
          </div>
        ) : (
          <div
            className="policy-content prose prose-sm dark:prose-invert max-w-none"
            dangerouslySetInnerHTML={{ __html: html }}
          />
        )}
      </div>

      <style>{`
        .policy-content h1 { font-size: 1.5rem; font-weight: 700; margin-bottom: 0.75rem; color: inherit; }
        .policy-content h2 { font-size: 1.1rem; font-weight: 700; margin-top: 1.5rem; margin-bottom: 0.5rem; color: inherit; }
        .policy-content p, .policy-content .LegalBody, .policy-content .SmallNote {
          font-size: 0.9rem; line-height: 1.7; margin-bottom: 0.75rem; color: inherit;
        }
        .policy-content .SmallNote { color: #6b7280; font-size: 0.8rem; }
        .policy-content ul, .policy-content ol { padding-left: 1.5rem; margin-bottom: 0.75rem; }
        .policy-content li { margin-bottom: 0.35rem; font-size: 0.9rem; line-height: 1.65; }
        .policy-content a { color: #fa3f5e; text-decoration: underline; }
      `}</style>
    </div>
  );
};

export default PublicPolicyPage;
