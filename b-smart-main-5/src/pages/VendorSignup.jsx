import React, { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import api from '../lib/api';
import {
  User,
  Mail,
  Phone,
  Lock,
  Building2,
  Briefcase,
  Globe,
  MapPin,
  Users,
  Target,
  Sparkles,
  ArrowLeft,
  ArrowRight,
  CheckCircle2,
  Eye,
  EyeOff
} from 'lucide-react';

const COUNTRIES = [
  'Afghanistan',
  'Albania',
  'Algeria',
  'Andorra',
  'Angola',
  'Argentina',
  'Armenia',
  'Australia',
  'Austria',
  'Azerbaijan',
  'Bahamas',
  'Bahrain',
  'Bangladesh',
  'Belarus',
  'Belgium',
  'Belize',
  'Benin',
  'Bhutan',
  'Bolivia',
  'Bosnia and Herzegovina',
  'Botswana',
  'Brazil',
  'Brunei',
  'Bulgaria',
  'Burkina Faso',
  'Burundi',
  'Cambodia',
  'Cameroon',
  'Canada',
  'Cape Verde',
  'Central African Republic',
  'Chad',
  'Chile',
  'China',
  'Colombia',
  'Comoros',
  'Costa Rica',
  'Croatia',
  'Cuba',
  'Cyprus',
  'Czech Republic',
  'Democratic Republic of the Congo',
  'Denmark',
  'Djibouti',
  'Dominican Republic',
  'Ecuador',
  'Egypt',
  'El Salvador',
  'Equatorial Guinea',
  'Eritrea',
  'Estonia',
  'Ethiopia',
  'Fiji',
  'Finland',
  'France',
  'Gabon',
  'Gambia',
  'Georgia',
  'Germany',
  'Ghana',
  'Greece',
  'Guatemala',
  'Guinea',
  'Guinea-Bissau',
  'Guyana',
  'Haiti',
  'Honduras',
  'Hungary',
  'Iceland',
  'India',
  'Indonesia',
  'Iran',
  'Iraq',
  'Ireland',
  'Israel',
  'Italy',
  'Ivory Coast',
  'Jamaica',
  'Japan',
  'Jordan',
  'Kazakhstan',
  'Kenya',
  'Kuwait',
  'Kyrgyzstan',
  'Laos',
  'Latvia',
  'Lebanon',
  'Lesotho',
  'Liberia',
  'Libya',
  'Lithuania',
  'Luxembourg',
  'Madagascar',
  'Malawi',
  'Malaysia',
  'Maldives',
  'Mali',
  'Malta',
  'Mauritania',
  'Mauritius',
  'Mexico',
  'Moldova',
  'Monaco',
  'Mongolia',
  'Montenegro',
  'Morocco',
  'Mozambique',
  'Myanmar',
  'Namibia',
  'Nepal',
  'Netherlands',
  'New Zealand',
  'Nicaragua',
  'Niger',
  'Nigeria',
  'North Macedonia',
  'Norway',
  'Oman',
  'Pakistan',
  'Panama',
  'Papua New Guinea',
  'Paraguay',
  'Peru',
  'Philippines',
  'Poland',
  'Portugal',
  'Qatar',
  'Republic of the Congo',
  'Romania',
  'Russia',
  'Rwanda',
  'Saudi Arabia',
  'Senegal',
  'Serbia',
  'Sierra Leone',
  'Singapore',
  'Slovakia',
  'Slovenia',
  'Somalia',
  'South Africa',
  'South Korea',
  'South Sudan',
  'Spain',
  'Sri Lanka',
  'Sudan',
  'Sweden',
  'Switzerland',
  'Syria',
  'Taiwan',
  'Tajikistan',
  'Tanzania',
  'Thailand',
  'Togo',
  'Trinidad and Tobago',
  'Tunisia',
  'Turkey',
  'Uganda',
  'Ukraine',
  'United Arab Emirates',
  'United Kingdom',
  'United States',
  'Uruguay',
  'Uzbekistan',
  'Venezuela',
  'Vietnam',
  'Yemen',
  'Zambia',
  'Zimbabwe'
];

const VendorSignup = () => {
  const navigate = useNavigate();

  const [step, setStep] = useState(1);
  const [error, setError] = useState('');
  const [completed, setCompleted] = useState(false);
  const [loading, setLoading] = useState(false);
  const [showPassword, setShowPassword] = useState(false);
  const [showConfirmPassword, setShowConfirmPassword] = useState(false);

  const [form, setForm] = useState({
    name: '',
    username: '',
    email: '',
    phone: '',
    password: '',
    confirmPassword: '',
    companyName: '',
    companyLegalName: '',
    industry: '',
    website: '',
    companyEmail: '',
    companyPhone: '',
    address: '',
    city: '',
    country: '',
    businessNote: '',
    creditsPackage: '',
    interests: '',
    targetPeople: '',
    locationTarget: '',
    campaignIdea: ''
  });

  const handleChange = (e) => {
    const { name, value } = e.target;
    setForm((prev) => ({ ...prev, [name]: value }));
  };

  const validateStep = () => {
    if (step === 1) {
      if (!form.name || !form.username || !form.email || !form.phone || !form.password || !form.confirmPassword) {
        setError('Please fill in all required fields.');
        return false;
      }
      if (form.password !== form.confirmPassword) {
        setError('Passwords do not match.');
        return false;
      }
    }

    if (step === 2) {
      if (!form.companyName || !form.industry || !form.city || !form.country) {
        setError('Please complete the key company details.');
        return false;
      }
    }

    if (step === 3) {
      if (!form.creditsPackage) {
        setError('Please select a credits package.');
        return false;
      }
    }

    setError('');
    return true;
  };

  const handleNext = () => {
    if (!validateStep()) return;
    setStep((prev) => Math.min(prev + 1, 4));
  };

  const handleBack = () => {
    setError('');
    setStep((prev) => Math.max(prev - 1, 1));
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!validateStep()) return;

    setError('');
    setCompleted(false);
    setLoading(true);

    const credits =
      form.creditsPackage === '50000'
        ? 50000
        : form.creditsPackage === '150000'
          ? 150000
          : form.creditsPackage === '200000'
            ? 200000
            : 0;

    const payload = {
      email: form.email,
      password: form.password,
      username: form.username,
      full_name: form.name,
      phone: form.phone,
      role: 'vendor',
      company_details: {
        company_name: form.companyName,
        legal_business_name: form.companyLegalName,
        industry: form.industry,
        website: form.website,
        business_email: form.companyEmail,
        business_phone: form.companyPhone,
        country: form.country,
        city: form.city,
        note: form.businessNote
      },
      credits,
      interests: form.interests,
      target_people: form.targetPeople,
      location_target: form.locationTarget,
      campaign_idea: form.campaignIdea
    };

    try {
      await api.post('/auth/register', payload);
      setCompleted(true);
      navigate('/login');
    } catch (err) {
      setError(err.response?.data?.message || 'Something went wrong.');
    } finally {
      setLoading(false);
    }
  };

  const steps = [
    { id: 1, label: 'Account' },
    { id: 2, label: 'Business' },
    { id: 3, label: 'Credits' },
    { id: 4, label: 'Audience' }
  ];

  const renderStep = () => {
    if (step === 1) {
      return (
        <div className="space-y-4">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div className="space-y-1">
              <label className="text-sm font-medium text-gray-700 dark:text-gray-300 ml-1">Full Name</label>
              <div className="relative group">
                <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none text-gray-400 dark:text-gray-500 group-focus-within:text-insta-pink transition-colors">
                  <User size={18} />
                </div>
                <input
                  name="name"
                  value={form.name}
                  onChange={handleChange}
                  placeholder="John Founder"
                  className="w-full pl-10 pr-4 py-2.5 bg-gray-50 dark:bg-gray-900 border border-gray-200 dark:border-gray-800 rounded-xl focus:outline-none focus:ring-2 focus:ring-insta-pink/20 focus:border-insta-pink transition-all placeholder:text-gray-400 dark:placeholder:text-gray-600 dark:text-white"
                  required
                />
              </div>
            </div>
            <div className="space-y-1">
              <label className="text-sm font-medium text-gray-700 dark:text-gray-300 ml-1">Username</label>
              <div className="relative group">
                <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none text-gray-400 dark:text-gray-500 group-focus-within:text-insta-pink transition-colors">
                  <User size={18} />
                </div>
                <input
                  name="username"
                  value={form.username}
                  onChange={handleChange}
                  placeholder="brandname"
                  className="w-full pl-10 pr-4 py-2.5 bg-gray-50 dark:bg-gray-900 border border-gray-200 dark:border-gray-800 rounded-xl focus:outline-none focus:ring-2 focus:ring-insta-pink/20 focus:border-insta-pink transition-all placeholder:text-gray-400 dark:placeholder:text-gray-600 dark:text-white"
                  required
                />
              </div>
            </div>
          </div>
          <div className="space-y-1">
            <label className="text-sm font-medium text-gray-700 dark:text-gray-300 ml-1">Email Address</label>
            <div className="relative group">
              <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none text-gray-400 dark:text-gray-500 group-focus-within:text-insta-pink transition-colors">
                <Mail size={18} />
              </div>
              <input
                name="email"
                type="email"
                value={form.email}
                onChange={handleChange}
                placeholder="founder@company.com"
                className="w-full pl-10 pr-4 py-2.5 bg-gray-50 dark:bg-gray-900 border border-gray-200 dark:border-gray-800 rounded-xl focus:outline-none focus:ring-2 focus:ring-insta-pink/20 focus:border-insta-pink transition-all placeholder:text-gray-400 dark:placeholder:text-gray-600 dark:text-white"
                required
              />
            </div>
          </div>
          <div className="space-y-1">
            <label className="text-sm font-medium text-gray-700 dark:text-gray-300 ml-1">Phone Number</label>
            <div className="relative group">
              <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none text-gray-400 dark:text-gray-500 group-focus-within:text-insta-pink transition-colors">
                <Phone size={18} />
              </div>
              <input
                name="phone"
                value={form.phone}
                onChange={handleChange}
                placeholder="+1 234 567 890"
                className="w-full pl-10 pr-4 py-2.5 bg-gray-50 dark:bg-gray-900 border border-gray-200 dark:border-gray-800 rounded-xl focus:outline-none focus:ring-2 focus:ring-insta-pink/20 focus:border-insta-pink transition-all placeholder:text-gray-400 dark:placeholder:text-gray-600 dark:text-white"
                required
              />
            </div>
          </div>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div className="space-y-1">
              <label className="text-sm font-medium text-gray-700 dark:text-gray-300 ml-1">Password</label>
              <div className="relative group">
                <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none text-gray-400 dark:text-gray-500 group-focus-within:text-insta-pink transition-colors">
                  <Lock size={18} />
                </div>
                <input
                  name="password"
                  type={showPassword ? 'text' : 'password'}
                  value={form.password}
                  onChange={handleChange}
                  placeholder="••••••••"
                  className="w-full pl-10 pr-4 py-2.5 bg-gray-50 dark:bg-gray-900 border border-gray-200 dark:border-gray-800 rounded-xl focus:outline-none focus:ring-2 focus:ring-insta-pink/20 focus:border-insta-pink transition-all placeholder:text-gray-400 dark:placeholder:text-gray-600 dark:text-white"
                  required
                />
                <button
                  type="button"
                  onClick={() => setShowPassword((v) => !v)}
                  className="absolute inset-y-0 right-0 pr-3 flex items-center text-gray-400 dark:text-gray-500 hover:text-gray-600 dark:hover:text-gray-300"
                >
                  {showPassword ? <EyeOff size={18} /> : <Eye size={18} />}
                </button>
              </div>
            </div>
            <div className="space-y-1">
              <label className="text-sm font-medium text-gray-700 dark:text-gray-300 ml-1">Confirm Password</label>
              <div className="relative group">
                <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none text-gray-400 dark:text-gray-500 group-focus-within:text-insta-pink transition-colors">
                  <Lock size={18} />
                </div>
                <input
                  name="confirmPassword"
                  type={showConfirmPassword ? 'text' : 'password'}
                  value={form.confirmPassword}
                  onChange={handleChange}
                  placeholder="••••••••"
                  className="w-full pl-10 pr-4 py-2.5 bg-gray-50 dark:bg-gray-900 border border-gray-200 dark:border-gray-800 rounded-xl focus:outline-none focus:ring-2 focus:ring-insta-pink/20 focus:border-insta-pink transition-all placeholder:text-gray-400 dark:placeholder:text-gray-600 dark:text-white"
                  required
                />
                <button
                  type="button"
                  onClick={() => setShowConfirmPassword((v) => !v)}
                  className="absolute inset-y-0 right-0 pr-3 flex items-center text-gray-400 dark:text-gray-500 hover:text-gray-600 dark:hover:text-gray-300"
                >
                  {showConfirmPassword ? <EyeOff size={18} /> : <Eye size={18} />}
                </button>
              </div>
            </div>
          </div>
        </div>
      );
    }

    if (step === 2) {
      return (
        <div className="space-y-4">
          <div className="space-y-1">
            <label className="text-sm font-medium text-gray-700 dark:text-gray-300 ml-1">Company Name</label>
            <div className="relative group">
              <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none text-gray-400 dark:text-gray-500 group-focus-within:text-insta-pink transition-colors">
                <Building2 size={18} />
              </div>
              <input
                name="companyName"
                value={form.companyName}
                onChange={handleChange}
                placeholder="Company or brand name"
                className="w-full pl-10 pr-4 py-2.5 bg-gray-50 dark:bg-gray-900 border border-gray-200 dark:border-gray-800 rounded-xl focus:outline-none focus:ring-2 focus:ring-insta-pink/20 focus:border-insta-pink transition-all placeholder:text-gray-400 dark:placeholder:text-gray-600 dark:text-white"
                required
              />
            </div>
          </div>
          <div className="space-y-1">
            <label className="text-sm font-medium text-gray-700 dark:text-gray-300 ml-1">Legal Business Name (optional)</label>
            <div className="relative group">
              <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none text-gray-400 dark:text-gray-500 group-focus-within:text-insta-pink transition-colors">
                <Briefcase size={18} />
              </div>
              <input
                name="companyLegalName"
                value={form.companyLegalName}
                onChange={handleChange}
                placeholder="Registered legal name"
                className="w-full pl-10 pr-4 py-2.5 bg-gray-50 dark:bg-gray-900 border border-gray-200 dark:border-gray-800 rounded-xl focus:outline-none focus:ring-2 focus:ring-insta-pink/20 focus:border-insta-pink transition-all placeholder:text-gray-400 dark:placeholder:text-gray-600 dark:text-white"
              />
            </div>
          </div>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div className="space-y-1">
              <label className="text-sm font-medium text-gray-700 dark:text-gray-300 ml-1">Industry</label>
              <div className="relative group">
                <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none text-gray-400 dark:text-gray-500 group-focus-within:text-insta-pink transition-colors">
                  <Briefcase size={18} />
                </div>
                <input
                  name="industry"
                  value={form.industry}
                  onChange={handleChange}
                  placeholder="Fashion, Food, Tech..."
                  className="w-full pl-10 pr-4 py-2.5 bg-gray-50 dark:bg-gray-900 border border-gray-200 dark:border-gray-800 rounded-xl focus:outline-none focus:ring-2 focus:ring-insta-pink/20 focus:border-insta-pink transition-all placeholder:text-gray-400 dark:placeholder:text-gray-600 dark:text-white"
                  required
                />
              </div>
            </div>
            <div className="space-y-1">
              <label className="text-sm font-medium text-gray-700 dark:text-gray-300 ml-1">Website (optional)</label>
              <div className="relative group">
                <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none text-gray-400 dark:text-gray-500 group-focus-within:text-insta-pink transition-colors">
                  <Globe size={18} />
                </div>
                <input
                  name="website"
                  value={form.website}
                  onChange={handleChange}
                  placeholder="https://yourwebsite.com"
                  className="w-full pl-10 pr-4 py-2.5 bg-gray-50 dark:bg-gray-900 border border-gray-200 dark:border-gray-800 rounded-xl focus:outline-none focus:ring-2 focus:ring-insta-pink/20 focus:border-insta-pink transition-all placeholder:text-gray-400 dark:placeholder:text-gray-600 dark:text-white"
                />
              </div>
            </div>
          </div>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div className="space-y-1">
              <label className="text-sm font-medium text-gray-700 dark:text-gray-300 ml-1">Business Email (optional)</label>
              <div className="relative group">
                <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none text-gray-400 dark:text-gray-500 group-focus-within:text-insta-pink transition-colors">
                  <Mail size={18} />
                </div>
                <input
                  name="companyEmail"
                  value={form.companyEmail}
                  onChange={handleChange}
                  placeholder="contact@company.com"
                  className="w-full pl-10 pr-4 py-2.5 bg-gray-50 dark:bg-gray-900 border border-gray-200 dark:border-gray-800 rounded-xl focus:outline-none focus:ring-2 focus:ring-insta-pink/20 focus:border-insta-pink transition-all placeholder:text-gray-400 dark:placeholder:text-gray-600 dark:text-white"
                />
              </div>
            </div>
            <div className="space-y-1">
              <label className="text-sm font-medium text-gray-700 dark:text-gray-300 ml-1">Business Phone (optional)</label>
              <div className="relative group">
                <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none text-gray-400 dark:text-gray-500 group-focus-within:text-insta-pink transition-colors">
                  <Phone size={18} />
                </div>
                <input
                  name="companyPhone"
                  value={form.companyPhone}
                  onChange={handleChange}
                  placeholder="+1 987 654 321"
                  className="w-full pl-10 pr-4 py-2.5 bg-gray-50 dark:bg-gray-900 border border-gray-200 dark:border-gray-800 rounded-xl focus:outline-none focus:ring-2 focus:ring-insta-pink/20 focus:border-insta-pink transition-all placeholder:text-gray-400 dark:placeholder:text-gray-600 dark:text-white"
                />
              </div>
            </div>
          </div>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div className="space-y-1">
              <label className="text-sm font-medium text-gray-700 dark:text-gray-300 ml-1">City</label>
              <div className="relative group">
                <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none text-gray-400 dark:text-gray-500 group-focus-within:text-insta-pink transition-colors">
                  <MapPin size={18} />
                </div>
                <input
                  name="city"
                  value={form.city}
                  onChange={handleChange}
                  placeholder="City"
                  className="w-full pl-10 pr-4 py-2.5 bg-gray-50 dark:bg-gray-900 border border-gray-200 dark:border-gray-800 rounded-xl focus:outline-none focus:ring-2 focus:ring-insta-pink/20 focus:border-insta-pink transition-all placeholder:text-gray-400 dark:placeholder:text-gray-600 dark:text-white"
                  required
                />
              </div>
            </div>
            <div className="space-y-1">
              <label className="text-sm font-medium text-gray-700 dark:text-gray-300 ml-1">Country</label>
              <div className="relative group">
                <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none text-gray-400 dark:text-gray-500 group-focus-within:text-insta-pink transition-colors">
                  <Globe size={18} />
                </div>
                <input
                  name="country"
                  value={form.country}
                  onChange={handleChange}
                  placeholder="Country"
                  className="w-full pl-10 pr-4 py-2.5 bg-gray-50 dark:bg-gray-900 border border-gray-200 dark:border-gray-800 rounded-xl focus:outline-none focus:ring-2 focus:ring-insta-pink/20 focus:border-insta-pink transition-all placeholder:text-gray-400 dark:placeholder:text-gray-600 dark:text-white"
                  required
                />
              </div>
            </div>
          </div>
          <div className="space-y-1">
            <label className="text-sm font-medium text-gray-700 dark:text-gray-300 ml-1">Business Overview (optional)</label>
            <textarea
              name="businessNote"
              value={form.businessNote}
              onChange={handleChange}
              placeholder="Tell us about your products, services and goals."
              className="w-full px-4 py-2.5 bg-gray-50 dark:bg-gray-900 border border-gray-200 dark:border-gray-800 rounded-xl focus:outline-none focus:ring-2 focus:ring-insta-pink/20 focus:border-insta-pink transition-all placeholder:text-gray-400 dark:placeholder:text-gray-600 dark:text-white min-h-[80px] resize-none"
            />
          </div>
        </div>
      );
    }

    if (step === 3) {
      const packages = [
        { id: '50000', name: 'Starter', credits: '50,000', description: 'Perfect for testing campaigns and first ads.' },
        { id: '150000', name: 'Growth', credits: '150,000', description: 'Best for growing brands and multi-channel ads.' },
        { id: '200000', name: 'Scale', credits: '200,000', description: 'For serious campaigns and always-on promotion.' }
      ];

      return (
        <div className="space-y-4">
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            {packages.map((pkg) => {
              const selected = form.creditsPackage === pkg.id;
              return (
                <button
                  key={pkg.id}
                  type="button"
                  onClick={() => setForm((prev) => ({ ...prev, creditsPackage: pkg.id }))}
                  className={`relative rounded-2xl border px-4 py-4 text-left transition-all bg-gray-50 dark:bg-gray-900 ${selected
                    ? 'border-insta-pink shadow-lg shadow-insta-pink/30 ring-2 ring-insta-pink/20 scale-[1.02]'
                    : 'border-gray-200 dark:border-gray-800 hover:border-insta-pink/60 hover:shadow-md'
                    }`}
                >
                  {selected && (
                    <div className="absolute top-3 right-3 text-insta-pink">
                      <CheckCircle2 size={18} />
                    </div>
                  )}
                  <div className="text-xs font-semibold uppercase tracking-wide text-gray-500 dark:text-gray-400 mb-1">
                    {pkg.name} Package
                  </div>
                  <div className="text-2xl font-bold text-gray-900 dark:text-white mb-1">
                    {pkg.credits} credits
                  </div>
                  <div className="text-xs text-gray-500 dark:text-gray-400 mb-3">
                    Approx. budget {pkg.id}
                  </div>
                  <p className="text-sm text-gray-600 dark:text-gray-400">{pkg.description}</p>
                </button>
              );
            })}
          </div>
          <p className="text-xs text-gray-500 dark:text-gray-400">
            You can change or top up your credits later from your wallet.
          </p>
        </div>
      );
    }

    return (
      <div className="space-y-4">
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div className="space-y-1">
            <label className="text-sm font-medium text-gray-700 dark:text-gray-300 ml-1">Interests</label>
            <div className="relative group">
              <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none text-gray-400 dark:text-gray-500 group-focus-within:text-insta-pink transition-colors">
                <Users size={18} />
              </div>
              <input
                name="interests"
                value={form.interests}
                onChange={handleChange}
                placeholder="Fashion, Food, Tech, Education..."
                className="w-full pl-10 pr-4 py-2.5 bg-gray-50 dark:bg-gray-900 border border-gray-200 dark:border-gray-800 rounded-xl focus:outline-none focus:ring-2 focus:ring-insta-pink/20 focus:border-insta-pink transition-all placeholder:text-gray-400 dark:placeholder:text-gray-600 dark:text-white"
              />
            </div>
          </div>
          <div className="space-y-1">
            <label className="text-sm font-medium text-gray-700 dark:text-gray-300 ml-1">Target People</label>
            <div className="relative group">
              <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none text-gray-400 dark:text-gray-500 group-focus-within:text-insta-pink transition-colors">
                <Target size={18} />
              </div>
              <input
                name="targetPeople"
                value={form.targetPeople}
                onChange={handleChange}
                placeholder="Age, location, interests..."
                className="w-full pl-10 pr-4 py-2.5 bg-gray-50 dark:bg-gray-900 border border-gray-200 dark:border-gray-800 rounded-xl focus:outline-none focus:ring-2 focus:ring-insta-pink/20 focus:border-insta-pink transition-all placeholder:text-gray-400 dark:placeholder:text-gray-600 dark:text-white"
              />
            </div>
          </div>
        </div>
        <div className="space-y-1">
          <label className="text-sm font-medium text-gray-700 dark:text-gray-300 ml-1">Location Target (Country)</label>
          <div className="relative">
            <select
              value={form.locationTarget}
              onChange={(e) => {
                const value = e.target.value;
                setForm((prev) => ({ ...prev, locationTarget: value }));
              }}
              className="w-full px-3 py-2.5 bg-gray-50 dark:bg-gray-900 border border-gray-200 dark:border-gray-800 rounded-xl focus:outline-none focus:ring-2 focus:ring-insta-pink/20 focus:border-insta-pink transition-all text-sm text-gray-800 dark:text-gray-100"
            >
              <option value="">Select a country</option>
              {COUNTRIES.map((country) => (
                <option
                  key={country}
                  value={country}
                  className="py-1 text-gray-800 dark:text-gray-100 bg-white dark:bg-gray-900"
                >
                  {country}
                </option>
              ))}
            </select>
          </div>
        </div>
        <div className="space-y-1">
          <label className="text-sm font-medium text-gray-700 dark:text-gray-300 ml-1">Campaign Idea (optional)</label>
          <textarea
            name="campaignIdea"
            value={form.campaignIdea}
            onChange={handleChange}
            placeholder="Share what you want to promote first on b_smart."
            className="w-full px-4 py-2.5 bg-gray-50 dark:bg-gray-900 border border-gray-200 dark:border-gray-800 rounded-xl focus:outline-none focus:ring-2 focus:ring-insta-pink/20 focus:border-insta-pink transition-all placeholder:text-gray-400 dark:placeholder:text-gray-600 dark:text-white min-h-[80px] resize-none"
          />
        </div>
      </div>
    );
  };

  const progress = (step / 4) * 100;

  return (
    <div className="h-screen flex bg-white dark:bg-black overflow-hidden">
      <div className="hidden lg:flex lg:w-1/2 relative bg-insta-gradient overflow-hidden h-full">
        <div className="absolute inset-0 bg-black/10" />
        <div className="absolute inset-0 flex flex-col items-center justify-center text-white p-12 text-center z-10">
          <div className="w-24 h-24 bg-white/20 backdrop-blur-lg rounded-3xl flex items-center justify-center mb-8 shadow-xl border border-white/30">
            <Sparkles size={48} className="text-white" />
          </div>
          <h1 className="text-4xl font-bold mb-4 tracking-tight">Grow your business with b_smart</h1>
          <p className="text-lg text-white/90 max-w-md font-light leading-relaxed">
            Reach the right people, run smart campaigns and measure performance in one place.
          </p>
          <div className="mt-10 flex flex-wrap gap-3 justify-center text-sm text-white/90">
            <span className="px-3 py-1 rounded-full bg-white/15 border border-white/30">Smart audience targeting</span>
            <span className="px-3 py-1 rounded-full bg-white/15 border border-white/30">Real-time performance</span>
            <span className="px-3 py-1 rounded-full bg-white/15 border border-white/30">Flexible credit packages</span>
          </div>
          <div className="absolute -top-24 -left-24 w-64 h-64 bg-white/10 rounded-full blur-3xl" />
          <div className="absolute -bottom-32 -right-32 w-80 h-80 bg-purple-900/20 rounded-full blur-3xl" />
        </div>
      </div>

      <div className="w-full lg:w-1/2 flex flex-col px-6 sm:px-12 xl:px-24 bg-white dark:bg-black h-full overflow-y-auto scrollbar-hide">
        <div className="max-w-md w-full mx-auto py-10">
          <div className="mb-6 flex items-center justify-between">
            <Link
              to="/signup"
              className="inline-flex items-center text-gray-500 hover:text-insta-pink transition-colors group text-sm"
            >
              <ArrowLeft size={18} className="mr-1 group-hover:-translate-x-1 transition-transform" />
              Back to user signup
            </Link>
            <Link
              to="/login"
              className="text-xs text-gray-500 hover:text-insta-pink transition-colors"
            >
              Already a vendor? Log in
            </Link>
          </div>

          <div className="mb-6">
            <h2 className="text-3xl font-bold text-gray-900 dark:text-white mb-1">Create Vendor Account</h2>
            <p className="text-gray-500 dark:text-gray-400 text-sm">
              Step {step} of 4 · Set up your business profile to run ads.
            </p>
          </div>

          <div className="mb-6">
            <div className="flex items-center justify-between mb-3">
              {steps.map((s) => (
                <div key={s.id} className="flex-1 flex flex-col items-center">
                  <div
                    className={`w-8 h-8 rounded-full flex items-center justify-center text-xs font-semibold border ${step === s.id
                      ? 'bg-insta-pink text-white border-insta-pink'
                      : step > s.id
                        ? 'bg-insta-pink/10 text-insta-pink border-insta-pink/40'
                        : 'bg-gray-100 dark:bg-gray-900 text-gray-500 dark:text-gray-400 border-gray-200 dark:border-gray-800'
                      }`}
                  >
                    {s.id}
                  </div>
                  <span className="mt-1 text-[11px] font-medium text-gray-500 dark:text-gray-400">{s.label}</span>
                </div>
              ))}
            </div>
            <div className="w-full h-1.5 rounded-full bg-gray-100 dark:bg-gray-900 overflow-hidden">
              <div
                className="h-full rounded-full bg-gradient-to-r from-insta-purple via-insta-pink to-insta-orange transition-all"
                style={{ width: `${progress}%` }}
              />
            </div>
          </div>

          <form onSubmit={step === 4 ? handleSubmit : (e) => { e.preventDefault(); handleNext(); }} className="space-y-5">
            {renderStep()}

            {error && (
              <div className="p-3 rounded-lg bg-red-50 dark:bg-red-900/20 border border-red-100 dark:border-red-800 text-red-600 dark:text-red-400 text-sm flex items-center">
                <svg className="w-4 h-4 mr-2 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
                {error}
              </div>
            )}

            {completed && !error && (
              <div className="p-3 rounded-lg bg-green-50 dark:bg-green-900/20 border border-green-100 dark:border-green-800 text-green-600 dark:text-green-400 text-sm flex items-center">
                <svg className="w-4 h-4 mr-2 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
                Vendor signup steps completed. No account has been created yet.
              </div>
            )}

            <div className="flex items-center justify-between pt-2">
              <button
                type="button"
                onClick={handleBack}
                disabled={step === 1}
                className="inline-flex items-center text-sm px-3 py-2 rounded-xl border border-gray-200 dark:border-gray-800 text-gray-600 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-900 disabled:opacity-50 disabled:cursor-not-allowed"
              >
                <ArrowLeft size={16} className="mr-1" />
                Back
              </button>

              {step < 4 && (
                <button
                  type="submit"
                  className="inline-flex items-center px-5 py-2.5 rounded-xl bg-gradient-to-r from-insta-purple via-insta-pink to-insta-orange text-white text-sm font-semibold shadow-lg shadow-insta-pink/30 hover:shadow-xl hover:shadow-insta-pink/40 hover:scale-[1.02] active:scale-[0.98] transition-all disabled:opacity-70 disabled:hover:scale-100 disabled:shadow-none"
                >
                  Next
                  <ArrowRight size={16} className="ml-2" />
                </button>
              )}

              {step === 4 && (
                <button
                  type="submit"
                  disabled={loading}
                  className="inline-flex items-center px-5 py-2.5 rounded-xl bg-gradient-to-r from-insta-purple via-insta-pink to-insta-orange text-white text-sm font-semibold shadow-lg shadow-insta-pink/30 hover:shadow-xl hover:shadow-insta-pink/40 hover:scale-[1.02] active:scale-[0.98] transition-all disabled:opacity-70 disabled:hover:scale-100 disabled:shadow-none"
                >
                  {loading ? (
                    <>
                      Submitting...
                      <ArrowRight size={16} className="ml-2" />
                    </>
                  ) : (
                    <>
                      Complete vendor signup
                      <ArrowRight size={16} className="ml-2" />
                    </>
                  )}
                </button>
              )}
            </div>
          </form>
        </div>
      </div>
    </div>
  );
};

export default VendorSignup;
