import React, { useState, useRef, useEffect, useCallback } from 'react';
import { useSelector } from 'react-redux';
import { useNavigate } from 'react-router-dom';
import api from '../lib/api';
import { Image, Images, Video, X, ArrowLeft, Maximize2, Search, Copy, ZoomIn, Plus, ChevronLeft, ChevronRight, UserPlus, ChevronDown, ChevronUp, Smile, Megaphone,
  MousePointerClick, Target, Smartphone, Monitor, Calendar, Link2, Phone, Mail, MessageSquare,
  TestTube2, CalendarClock, Zap, ShieldCheck, Tag, Globe, MapPin, Coins
} from 'lucide-react';
import Cropper from 'react-easy-crop';

// Filter Definitions
const FILTERS = [
  { name: 'Original', style: '' },
  { name: 'Clarendon', style: 'contrast(1.2) saturate(1.25)' },
  { name: 'Gingham', style: 'brightness(1.05) hue-rotate(-10deg)' },
  { name: 'Moon', style: 'grayscale(1) contrast(1.1) brightness(1.1)' },
  { name: 'Lark', style: 'contrast(0.9)' },
  { name: 'Reyes', style: 'sepia(0.22) brightness(1.1) contrast(0.85) saturate(0.75)' },
  { name: 'Juno', style: 'contrast(1.2) brightness(1.1) saturate(1.4) sepia(0.2)' },
  { name: 'Slumber', style: 'brightness(1.05) saturate(0.66) sepia(0.20)' },
  { name: 'Crema', style: 'contrast(0.9) saturate(0.9) sepia(0.2)' },
  { name: 'Ludwig', style: 'contrast(0.9) saturate(0.9) brightness(1.1)' },
  { name: 'Aden', style: 'contrast(0.9) saturate(0.85) brightness(1.2) hue-rotate(-20deg)' },
  { name: 'Perpetua', style: 'contrast(1.1) brightness(1.1) saturate(1.1)' }
];

const ADJUSTMENTS = [
  { name: 'Brightness', property: 'brightness', min: -100, max: 100 },
  { name: 'Contrast', property: 'contrast', min: -100, max: 100 },
  { name: 'Saturation', property: 'saturate', min: -100, max: 100 },
  { name: 'Temperature', property: 'sepia', min: -100, max: 100 },
  { name: 'Fade', property: 'opacity', min: 0, max: 100 },
  { name: 'Vignette', property: 'vignette', min: 0, max: 100 }
];

// Utility to create image
const createImage = (url) =>
  new Promise((resolve, reject) => {
    const image = new window.Image()
    image.addEventListener('load', () => resolve(image))
    image.addEventListener('error', (error) => reject(error))
    image.setAttribute('crossOrigin', 'anonymous')
    image.src = url
  })

// Utility to crop image
async function getCroppedImg(imageSrc, pixelCrop) {
  const image = await createImage(imageSrc)
  const canvas = document.createElement('canvas')
  const ctx = canvas.getContext('2d')

  if (!pixelCrop) {
    const size = Math.min(image.width, image.height);
    pixelCrop = {
      x: (image.width - size) / 2,
      y: (image.height - size) / 2,
      width: size,
      height: size
    }
  }

  canvas.width = pixelCrop.width
  canvas.height = pixelCrop.height

  ctx.drawImage(
    image,
    pixelCrop.x,
    pixelCrop.y,
    pixelCrop.width,
    pixelCrop.height,
    0,
    0,
    pixelCrop.width,
    pixelCrop.height
  )

  return new Promise((resolve) => {
    canvas.toBlob((file) => {
      resolve(URL.createObjectURL(file))
    }, 'image/jpeg')
  })
}

// ─── Video Processing Utility ──────────────────────────────────────────────
async function processVideoForUpload(originalFile, trimStart, trimEnd, cropParams, onProgress) {
  return new Promise((resolve) => {
    const video = document.createElement('video');
    const objectUrl = URL.createObjectURL(originalFile);
    video.src = objectUrl;
    video.muted = true;
    video.playsInline = true;
    video.preload = 'auto';
    video.style.cssText = 'position:fixed;top:-9999px;left:-9999px;width:1px;height:1px;';
    document.body.appendChild(video);

    const cleanup = () => {
      try { document.body.removeChild(video); } catch (err) {
        console.warn('Video element cleanup failed', err);
      }
      URL.revokeObjectURL(objectUrl);
    };

    video.onloadedmetadata = async () => {
      const totalDuration = trimEnd - trimStart;
      if (totalDuration <= 0.05) {
        cleanup();
        resolve(originalFile);
        return;
      }

      const natW = video.videoWidth  || 1280;
      const natH = video.videoHeight || 720;

      const srcX = cropParams?.x      ?? 0;
      const srcY = cropParams?.y      ?? 0;
      const srcW = cropParams?.width  ?? natW;
      const srcH = cropParams?.height ?? natH;

      const outW = cropParams?.outputWidth  ?? natW;
      const outH = cropParams?.outputHeight ?? natH;

      const canvas = document.createElement('canvas');
      canvas.width  = outW;
      canvas.height = outH;
      const ctx = canvas.getContext('2d');

      const mimeType =
        MediaRecorder.isTypeSupported('video/mp4;codecs=avc1') ? 'video/mp4;codecs=avc1' :
        MediaRecorder.isTypeSupported('video/mp4')             ? 'video/mp4'              :
        MediaRecorder.isTypeSupported('video/webm;codecs=vp9') ? 'video/webm;codecs=vp9' :
        MediaRecorder.isTypeSupported('video/webm;codecs=vp8') ? 'video/webm;codecs=vp8' :
        'video/webm';

      let stream, recorder;
      try {
        stream   = canvas.captureStream(30);
        recorder = new MediaRecorder(stream, { mimeType, videoBitsPerSecond: 8_000_000 });
      } catch {
        try {
          const vStream = video.captureStream
            ? video.captureStream(30)
            : video.mozCaptureStream
            ? video.mozCaptureStream(30)
            : null;
          if (!vStream) throw new Error('no stream');
          recorder = new MediaRecorder(vStream, { mimeType });
        } catch {
          cleanup();
          resolve(originalFile);
          return;
        }
      }

      const chunks = [];
      recorder.ondataavailable = (e) => { if (e.data?.size > 0) chunks.push(e.data); };

      recorder.onstop = () => {
        cleanup();
        const blob = new Blob(chunks, { type: 'video/mp4' });
        resolve(new File([blob], 'video.mp4', { type: 'video/mp4' }));
      };

      recorder.onerror = () => { cleanup(); resolve(originalFile); };

      video.currentTime = trimStart;
      await new Promise(res => {
        const onSeeked = () => { video.removeEventListener('seeked', onSeeked); res(); };
        video.addEventListener('seeked', onSeeked);
      });

      recorder.start(100);
      video.play().catch(() => {});

      const drawFrame = () => {
        const elapsed  = Math.max(0, video.currentTime - trimStart);
        const progress = Math.min(100, Math.round((elapsed / totalDuration) * 100));
        if (onProgress) onProgress(progress);

        if (video.currentTime >= trimEnd - 0.05 || video.ended || video.paused) {
          video.pause();
          if (recorder.state === 'recording') {
            ctx.drawImage(video, srcX, srcY, srcW, srcH, 0, 0, outW, outH);
            recorder.stop();
          }
          return;
        }

        ctx.drawImage(video, srcX, srcY, srcW, srcH, 0, 0, outW, outH);

        if (recorder.state === 'recording') requestAnimationFrame(drawFrame);
      };

      requestAnimationFrame(drawFrame);
    };

    video.onerror = () => { cleanup(); resolve(originalFile); };
  });
}

// SuccessCountdown — thin line depletes over 5s then auto-navigates
function SuccessCountdown({ onDone }) {
  const [elapsed, setElapsed] = React.useState(0);
  const TOTAL = 5000;
  const STEP  = 50;
  const onDoneRef = React.useRef(onDone);
  React.useEffect(() => { onDoneRef.current = onDone; }, [onDone]);
  React.useEffect(() => {
    if (elapsed >= TOTAL) { onDoneRef.current(); return; }
    const t = setTimeout(() => setElapsed(e => e + STEP), STEP);
    return () => clearTimeout(t);
  }, [elapsed]);
  const progress = Math.min(1, elapsed / TOTAL);
  return (
    <div className="flex flex-col items-center gap-2 w-full">
      <div className="w-full h-0.5 rounded-full overflow-hidden" style={{ background: 'rgba(255,255,255,0.1)' }}>
        <div
          className="h-full rounded-full"
          style={{
            width: `${(1 - progress) * 100}%`,
            background: 'linear-gradient(90deg,#feda75,#fa7e1e,#d62976,#962fbf)',
            transition: `width ${STEP}ms linear`
          }}
        />
      </div>
      <p className="text-xs text-white/40">Redirecting to home…</p>
    </div>
  );
}

const CreatePostModal = ({ isOpen, onClose, initialType = 'post', onOpenAdModal }) => {
  const navigate = useNavigate();
  const [isDragging, setIsDragging] = useState(false);
  const [step, setStep] = useState('select');
  const { userObject } = useSelector((state) => state.auth);
  const userId = userObject?._id || userObject?.id;
  const [postType, setPostType] = useState(initialType);
  
  useEffect(() => {
    if (isOpen) {
      setPostType(initialType);
    }
  }, [isOpen, initialType]);

  useEffect(() => {
    let active = true;

    const loadVendorProfileData = async () => {
      if (!isOpen || userObject?.role !== 'vendor' || !userId) return;
      try {
        const [profileRes, packageRes, adsRes] = await Promise.all([
          api.get(`/vendors/profile/${userId}`),
          api.get('/vendor-packages/my/active').catch(() => ({ data: null })),
          api.get(`/ads/user/${userId}`).catch(() => ({ data: [] })),
        ]);
        if (!active) return;
        setVendorProfileCompletion(Number(profileRes.data?.profile_completion_percentage || 0));

        const activePackage = packageRes?.data?.active_package || packageRes?.data?.package || packageRes?.data || null;
        const packageData = activePackage?.package || activePackage || {};
        setActivePackageAdsLimit(Number(packageData?.ads_allowed_max || 0));

        const ads = Array.isArray(adsRes?.data)
          ? adsRes.data
          : Array.isArray(adsRes?.data?.ads)
          ? adsRes.data.ads
          : Array.isArray(adsRes?.data?.data)
          ? adsRes.data.data
          : [];
        setUploadedAdsCount(ads.length);
      } catch (err) {
        if (!active) return;
        console.error('Failed to load vendor profile/ad package data', err);
        setVendorProfileCompletion(0);
        setActivePackageAdsLimit(0);
        setUploadedAdsCount(0);
      }
    };

    loadVendorProfileData();
    return () => { active = false; };
  }, [isOpen, userId, userObject?.role]);

  const [media, setMedia] = useState([]);
  const [currentIndex, setCurrentIndex] = useState(0);

  const [caption, setCaption] = useState('');
  const [location, setLocation] = useState('');
  const [hideLikes, setHideLikes] = useState(false);
  const [turnOffCommenting, setTurnOffCommenting] = useState(false);
  const [isAdvancedSettingsOpen, setIsAdvancedSettingsOpen] = useState(false);

  const [showEmojiPicker, setShowEmojiPicker] = useState(false);
  const [tags, setTags] = useState([]);
  const [showTagSearch, setShowTagSearch] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');
  const [searchResults, setSearchResults] = useState([]);
  const [isSearchingUsers, setIsSearchingUsers] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [showVendorNotValidated, setShowVendorNotValidated] = useState(false);
  const [vendorProfileCompletion, setVendorProfileCompletion] = useState(0);
  const [showAdProfileGate, setShowAdProfileGate] = useState(false);
  const [activePackageAdsLimit, setActivePackageAdsLimit] = useState(0);
  const [uploadedAdsCount, setUploadedAdsCount] = useState(0);
  const [showAdLimitPopup, setShowAdLimitPopup] = useState(false);
  const [allUsers, setAllUsers] = useState([]);
  const [isLoadingAllUsers, setIsLoadingAllUsers] = useState(false);
  const [showSuccess, setShowSuccess] = useState(false);
  const [adSubmitMode, setAdSubmitMode] = useState('publish');
  
  const CATEGORIES = [
    'Fashion', 'Electronics', 'Food & Dining', 'Beauty & Personal Care', 'Travel', 'Education',
    'Real Estate', 'Automotive', 'Health & Fitness', 'Entertainment', 'Sports', 'Technology',
    'Home & Garden', 'Pets', 'Business & Finance', 'Art & Design', 'Books & Literature',
    'Gaming', 'Music', 'Photography', 'Science', 'Social Media', 'Other'
  ];

  const LANGUAGES = [
    'English', 'Spanish', 'French', 'German', 'Chinese', 'Japanese', 'Arabic', 'Hindi', 'Portuguese', 'Russian', 'Italian', 'Korean', 'Turkish'
  ].sort();

  const COUNTRIES = [
    'USA', 'Canada', 'UK', 'Australia', 'India', 'Germany', 'France', 'Italy', 'Spain', 'Brazil',
    'Mexico', 'Japan', 'South Korea', 'China', 'Russia', 'South Africa', 'Nigeria', 'Egypt',
    'Saudi Arabia', 'UAE', 'Turkey', 'Argentina', 'Chile', 'Colombia', 'Peru', 'Indonesia',
    'Thailand', 'Vietnam', 'Malaysia', 'Philippines', 'Singapore', 'New Zealand', 'Netherlands',
    'Belgium', 'Sweden', 'Norway', 'Denmark', 'Finland', 'Poland', 'Ukraine', 'Greece', 'Portugal',
    'Ireland', 'Switzerland', 'Austria', 'Hungary', 'Czech Republic', 'Romania', 'Pakistan', 'Bangladesh'
  ].sort();

  const [categories, setCategories] = useState(CATEGORIES);
  const [isLoadingCategories, setIsLoadingCategories] = useState(false);
  
  // Ad multi-select states
  const [selectedCategory, setSelectedCategory] = useState("");
  const [selectedLanguages, setSelectedLanguages] = useState([]);
  const [selectedCountries, setSelectedCountries] = useState([]);
  const [selectedStates, setSelectedStates] = useState([]);
  const [totalBudgetCoins, setTotalBudgetCoins] = useState('');

  // ── NEW ad fields ──────────────────────────────────────────────────────────
  const [adTitle, setAdTitle] = useState('');
  const [adDescription, setAdDescription] = useState('');
  const [adType, setAdType] = useState('sponsored_post');
  const [subCategory, setSubCategory] = useState('');
  const [keywords, setKeywords] = useState([]);
  const [keywordInput, setKeywordInput] = useState('');

  // CTA
  const [ctaType, setCtaType] = useState('view_site');
  const [ctaUrl, setCtaUrl] = useState('');
  const [ctaDeepLink, setCtaDeepLink] = useState('');
  const [ctaPhone, setCtaPhone] = useState('');
  const [ctaEmail, setCtaEmail] = useState('');
  const [ctaWhatsapp, setCtaWhatsapp] = useState('');

  // Budget extended
  const [dailyBudgetCoins, setDailyBudgetCoins] = useState('');
  const [budgetStartDate, setBudgetStartDate] = useState('');
  const [budgetEndDate, setBudgetEndDate] = useState('');

  // Targeting new fields
  const [selectedCities, setSelectedCities] = useState([]);
  const [cityInput, setCityInput] = useState('');
  const [ageMin, setAgeMin] = useState('');
  const [ageMax, setAgeMax] = useState('');
  const [genderTarget, setGenderTarget] = useState('all');
  const [selectedInterests, setSelectedInterests] = useState([]);
  const [interestInput, setInterestInput] = useState('');
  const [selectedDeviceTypes, setSelectedDeviceTypes] = useState([]);

  // Tracking / UTM
  const [utmSource, setUtmSource] = useState('');
  const [utmMedium, setUtmMedium] = useState('');
  const [utmCampaign, setUtmCampaign] = useState('');
  const [utmTerm, setUtmTerm] = useState('');
  const [utmContent, setUtmContent] = useState('');
  const [conversionPixelId, setConversionPixelId] = useState('');

  // Engagement controls (new)
  const [disableShare, setDisableShare] = useState(false);
  const [disableSave, setDisableSave] = useState(false);
  const [disableReport, setDisableReport] = useState(false);
  const [moderationEnabled, setModerationEnabled] = useState(false);

  // Compliance
  const [policyAgreed, setPolicyAgreed] = useState(false);

  // A/B testing
  const [abTestingEnabled, setAbTestingEnabled] = useState(false);

  // Scheduling
  const [scheduleSlots, setScheduleSlots] = useState([]);

  // Accordion state — extended
  // 'category' | 'country' | 'state' | 'language' | 'budget' | 'cta' | 'adtype' | 'targeting_advanced' | 'tracking' | 'engagement' | 'compliance' | null

  // API-driven country/state/language data
  const [allCountries, setAllCountries] = useState([]);
  const [isLoadingCountries, setIsLoadingCountries] = useState(false);
  const [statesByCountry, setStatesByCountry] = useState({}); // { countryName: [states] }
  const [isLoadingStates, setIsLoadingStates] = useState(false);
  const [languagesByState, setLanguagesByState] = useState({}); // { 'country|state': [languages] }
  const [isLoadingLanguages, setIsLoadingLanguages] = useState(false);
  
  // Accordion state: 'category' | 'country' | 'state' | 'language' | 'budget' | null
  const [openAccordion, setOpenAccordion] = useState(null);
  const isVendorValidated = Boolean(
    userObject?.vendor_validated ??
    userObject?.validated ??
    userObject?.vendor?.validated
  );

  const ensureAdProfileCompletion = useCallback(() => {
    if (Number(vendorProfileCompletion || 0) <= 80) {
      setShowAdProfileGate(true);
      return false;
    }
    return true;
  }, [vendorProfileCompletion]);

  const ensureAdPackageLimit = useCallback(() => {
    if (Number(activePackageAdsLimit || 0) <= 0 || Number(uploadedAdsCount || 0) >= Number(activePackageAdsLimit || 0)) {
      setShowAdLimitPopup(true);
      return false;
    }
    return true;
  }, [activePackageAdsLimit, uploadedAdsCount]);

  useEffect(() => {
    let active = true;
    setIsLoadingCategories(true);
    api.get('/ads/categories')
      .then((res) => {
        const cats = res?.data?.categories || [];
        if (!active) return;
        if (cats.length) {
          setCategories(cats);
        }
      })
      .catch(() => {})
      .finally(() => { if (active) setIsLoadingCategories(false); });
    return () => { active = false; };
  }, []);

  // Fetch all countries (flat list) on mount
  useEffect(() => {
    let active = true;
    setIsLoadingCountries(true);
    fetch('https://api.bebsmart.in/api/countries')
      .then(r => r.json())
      .then(data => {
        if (!active) return;
        const list = Array.isArray(data) ? data : (data?.countries || data?.data || []);
        setAllCountries(list);
      })
      .catch(() => {})
      .finally(() => { if (active) setIsLoadingCountries(false); });
    return () => { active = false; };
  }, []);

  // When selectedCountries changes: fetch full data (states + languages) in one call
  // API response shape: { success, country, count, data: [{ state, languages, cities }] }
  useEffect(() => {
    if (selectedCountries.length === 0) {
      setStatesByCountry({});
      setSelectedStates([]);
      setLanguagesByState({});
      setSelectedLanguages([]);
      return;
    }
    setIsLoadingStates(true);
    Promise.all(
      selectedCountries.map(country =>
        fetch(`https://api.bebsmart.in/api/countries/${encodeURIComponent(country)}/states`)
          .then(r => r.json())
          .then(res => {
            // response: { success, country, count, data: [{ state, languages, cities }] }
            const stateData = Array.isArray(res) ? res : (res?.data || []);
            return { country, stateData };
          })
          .catch(() => ({ country, stateData: [] }))
      )
    ).then(results => {
      const newStatesByCountry = {};
      results.forEach(({ country, stateData }) => {
        newStatesByCountry[country] = stateData; // each item: { state, languages, cities }
      });
      setStatesByCountry(newStatesByCountry);
      // Prune selected states no longer in any selected country
      const allValidStateNames = new Set(
        results.flatMap(({ stateData }) => stateData.map(s => s.state))
      );
      setSelectedStates(prev => prev.filter(s => allValidStateNames.has(s)));
      setIsLoadingStates(false);
    });
  }, [selectedCountries]);

  // When selectedStates changes: derive languages directly from statesByCountry data (no extra API call)
  useEffect(() => {
    if (selectedStates.length === 0) {
      setLanguagesByState({});
      setSelectedLanguages([]);
      return;
    }
    const newLangMap = {};
    selectedCountries.forEach(country => {
      const stateDataArr = statesByCountry[country] || [];
      const langs = stateDataArr
        .filter(s => selectedStates.includes(s.state))
        .flatMap(s => s.languages || []);
      newLangMap[country] = [...new Set(langs)];
    });
    setLanguagesByState(newLangMap);
    const allValidLangs = new Set(Object.values(newLangMap).flat());
    setSelectedLanguages(prev => prev.filter(l => allValidLangs.has(l)));
  }, [selectedStates, statesByCountry]);


  const [uploadStage, setUploadStage] = useState('idle');
  const [uploadProgress, setUploadProgress] = useState(0);
  const [uploadError, setUploadError] = useState('');
  
  const [draggingTagId, setDraggingTagId] = useState(null);

  const POPULAR_EMOJIS = ['😂', '😮', '😍', '😢', '👏', '🔥', '🎉', '💯', '❤️', '🤣', '🥰', '😘', '😭', '😊'];

  const [showRatioMenu, setShowRatioMenu] = useState(false);
  const [showZoomSlider, setShowZoomSlider] = useState(false);
  const [showMultiSelect, setShowMultiSelect] = useState(false);
  const [activeTab, setActiveTab] = useState('filters');

  const fileInputRef = useRef(null);
  const cropContainerRef = useRef(null);
  const [overlaySize, setOverlaySize] = useState({ w: 0, h: 0 });
  const editContainerRef = useRef(null);
  const [editBoxSize, setEditBoxSize] = useState({ w: 0, h: 0 });
  const coverInputRef = useRef(null);
  const trimTrackRef = useRef(null);
  const [dragHandle, setDragHandle] = useState(null);
  const editVideoRef = useRef(null);
  const shareContainerRef = useRef(null);
  const [trimPlayTime, setTrimPlayTime] = useState(0);
  const [shareBoxSize, setShareBoxSize] = useState({ w: 0, h: 0 });

  const currentMedia = media[currentIndex];

  const handleDragOver = (e) => { e.preventDefault(); setIsDragging(true); };
  const handleDragLeave = (e) => { e.preventDefault(); setIsDragging(false); };
  const handleDrop = (e) => {
    e.preventDefault();
    setIsDragging(false);
    const files = Array.from(e.dataTransfer.files);
    if (files && files.length > 0) handleFiles(files);
  };

  useEffect(() => {
    if (step !== 'crop') return;
    const el = cropContainerRef.current;
    if (!el || !currentMedia) return;
    const compute = () => {
      const cw = el.clientWidth;
      const ch = el.clientHeight;
      const videoAspect = currentMedia.originalAspect || 1;
      let vw, vh;
      if (cw / ch > videoAspect) { vh = ch; vw = vh * videoAspect; }
      else { vw = cw; vh = vw / videoAspect; }
      const a = currentMedia.aspect || 1;
      let w = vw;
      let h = w / a;
      if (h > vh) { h = vh; w = h * a; }
      setOverlaySize({ w, h });
    };
    compute();
    const ro = new ResizeObserver(compute);
    ro.observe(el);
    return () => ro.disconnect();
  }, [step, currentMedia]);

  useEffect(() => {
    if (step !== 'share') return;
    const el = shareContainerRef.current;
    if (!el || !currentMedia) return;
    const compute = () => {
      const cw = el.clientWidth;
      const ch = el.clientHeight;
      const a = currentMedia.aspect || 1;
      let w = cw;
      let h = w / a;
      if (h > ch) { h = ch; w = h * a; }
      setShareBoxSize({ w, h });
    };
    compute();
    const ro = new ResizeObserver(compute);
    ro.observe(el);
    return () => ro.disconnect();
  }, [step, currentMedia]);

  useEffect(() => {
    if (step !== 'edit') return;
    const el = editContainerRef.current;
    if (!el || !currentMedia) return;
    const compute = () => {
      const cw = el.clientWidth;
      const ch = el.clientHeight;
      const a = currentMedia.aspect || 1;
      let w = cw;
      let h = w / a;
      if (h > ch) { h = ch; w = h * a; }
      setEditBoxSize({ w, h });
    };
    compute();
    const ro = new ResizeObserver(compute);
    ro.observe(el);
    return () => ro.disconnect();
  }, [step, currentMedia]);

  useEffect(() => {
    if (step !== 'edit') return;
    if (!currentMedia || currentMedia.type !== 'video') return;
    const v = editVideoRef.current;
    if (!v) return;
    const s = currentMedia.trimStart || 0;
    const d = currentMedia.duration || 0;
    const end = currentMedia.trimEnd && currentMedia.trimEnd > 0 ? currentMedia.trimEnd : d;
    try {
      if (v.currentTime < s || (end > 0 && v.currentTime > end)) {
        v.currentTime = s;
      }
    } catch { void 0; }
  }, [step, currentMedia?.trimStart, currentMedia?.trimEnd, currentMedia?.type]);

  const handleFileSelect = (e) => {
    const files = Array.from(e.target.files);
    if (files && files.length > 0) handleFiles(files);
    e.target.value = '';
  };

  const handleFiles = async (files) => {
    const validFiles = files.filter(file => {
      if (postType === 'post') return file.type.startsWith('image/');
      if (postType === 'reel') return file.type.startsWith('video/');
      if (postType === 'ad') return file.type.startsWith('image/') || file.type.startsWith('video/');
      return file.type.startsWith('image/') || file.type.startsWith('video/');
    });

    if (validFiles.length === 0) return;

    const newMedia = await Promise.all(validFiles.map(async (file) => {
      const url = URL.createObjectURL(file);
      if (file.type.startsWith('image/')) {
        let aspect = 1;
        let originalAspect = null;
        try {
          const img = await createImage(url);
          originalAspect = img.width / img.height;
          aspect = originalAspect;
        } catch {
          aspect = 1;
          originalAspect = null;
        }
        return {
          id: Math.random().toString(36).substr(2, 9),
          url,
          type: 'image',
          crop: { x: 0, y: 0 },
          zoom: 1,
          aspect,
          originalAspect,
          croppedAreaPixels: null,
          filter: 'Original',
          adjustments: { brightness: 0, contrast: 0, saturate: 0, sepia: 0, opacity: 0, vignette: 0 }
        };
      } else {
        const video = document.createElement('video');
        video.src = url;
        await new Promise((resolve) => { video.onloadedmetadata = resolve; });
        const originalAspect = (video.videoWidth && video.videoHeight) ? (video.videoWidth / video.videoHeight) : 1;
        const duration = isFinite(video.duration) ? video.duration : 0;
        return {
          id: Math.random().toString(36).substr(2, 9),
          url,
          originalFile: file,
          videoNaturalWidth:  video.videoWidth  || 0,
          videoNaturalHeight: video.videoHeight || 0,
          type: 'video',
          crop: { x: 0, y: 0 },
          zoom: 1,
          aspect: originalAspect || 1,
          originalAspect: originalAspect || 1,
          duration,
          coverUrl: null,
          thumbnails: null,
          trimStart: 0,
          trimEnd: duration || 0,
          soundOn: true,
          croppedAreaPixels: null,
          filter: 'Original',
          adjustments: { brightness: 0, contrast: 0, saturate: 0, sepia: 0, opacity: 0, vignette: 0 }
        };
      }
    }));

    if (step === 'select') {
      setMedia(newMedia);
      setCurrentIndex(0);
      setTimeout(() => setStep('crop'), 0);
    } else {
      setMedia(prev => [...prev, ...newMedia]);
      setCurrentIndex(prev => prev + newMedia.length - 1);
    }
  };

  const updateCurrentMedia = useCallback((updates) => {
    setMedia(prev => prev.map((item, index) =>
      index === currentIndex ? { ...item, ...updates } : item
    ));
  }, [currentIndex]);

  const onCropChange = (crop) => updateCurrentMedia({ crop });
  const onZoomChange = (zoom) => updateCurrentMedia({ zoom });
  const onCropComplete = (croppedArea, croppedAreaPixels) => updateCurrentMedia({ croppedAreaPixels });

  useEffect(() => {
    if (step === 'edit' && currentMedia?.type === 'video') setActiveTab('video');
  }, [step, currentMedia]);

  const handleRemoveMedia = (index, e) => {
    e.stopPropagation();
    if (media.length === 1) { handleClose(); return; }
    const newMedia = media.filter((_, i) => i !== index);
    setMedia(newMedia);
    if (currentIndex >= index && currentIndex > 0) setCurrentIndex(prev => prev - 1);
  };

  const handleButtonClick = () => fileInputRef.current?.click();

  const handleBack = () => {
    if (step === 'share') {
      setStep('edit');
    } else if (step === 'edit') {
      setStep('crop');
    } else if (step === 'crop') {
      setStep('select');
      setMedia([]);
      setCurrentIndex(0);
    } else {
      handleClose();
    }
  };

  // ── Helper: stringify aspect ratio label ──
  const getAspectRatioLabel = (a) => {
    if (!a) return 'original';
    if (Math.abs(a - 1) < 0.001) return '1:1';
    if (Math.abs(a - (4 / 5)) < 0.001) return '4:5';
    if (Math.abs(a - (16 / 9)) < 0.001) return '16:9';
    if (Math.abs(a - (9 / 16)) < 0.001) return '9:16';
    return 'custom';
  };

  const handleNextStep = async (submitMode = 'publish') => {
    if (step === 'crop') {
      const containerEl = cropContainerRef.current;

      const computeVideoCropPixels = (item) => {
        if (item.type !== 'video') return item.croppedAreaPixels || null;
        if (!containerEl) return null;

        const cw = containerEl.clientWidth;
        const ch = containerEl.clientHeight;
        const vw = item.videoNaturalWidth  || item.originalAspect ? (ch * item.originalAspect) : cw;
        const vh = item.videoNaturalHeight || ch;

        const videoAspect = item.originalAspect || (vw / vh) || 1;
        let rendW, rendH;
        if (cw / ch > videoAspect) { rendH = ch; rendW = rendH * videoAspect; }
        else                        { rendW = cw; rendH = rendW / videoAspect; }

        const boxW = overlaySize.w || rendW;
        const boxH = overlaySize.h || rendH;

        const vidLeft = (cw - rendW) / 2;
        const vidTop  = (ch - rendH) / 2;
        const boxLeft = (cw - boxW) / 2;
        const boxTop  = (ch - boxH) / 2;

        const offsetX = boxLeft - vidLeft;
        const offsetY = boxTop  - vidTop;

        const scaleX = (item.videoNaturalWidth  || rendW) / rendW;
        const scaleY = (item.videoNaturalHeight || rendH) / rendH;

        return {
          x:      Math.max(0, Math.round(offsetX * scaleX)),
          y:      Math.max(0, Math.round(offsetY * scaleY)),
          width:  Math.round(boxW * scaleX),
          height: Math.round(boxH * scaleY),
        };
      };

      const newMedia = await Promise.all(media.map(async (item) => {
        if (item.type === 'video') {
          const cropPx = computeVideoCropPixels(item);
          return { ...item, croppedAreaPixels: cropPx, croppedUrl: item.url };
        }
        try {
          const croppedUrl = await getCroppedImg(item.url, item.croppedAreaPixels);
          return { ...item, croppedUrl };
        } catch {
          return { ...item, croppedUrl: item.url };
        }
      }));
      setMedia(newMedia);
      setStep('edit');
    } else if (step === 'edit') {
      setStep('share');
    } else if (step === 'share') {
      if (isSubmitting) return;
      setAdSubmitMode(submitMode);
      setIsSubmitting(true);
      setUploadStage('converting');
      setUploadProgress(0);
      setUploadError('');

      try {
        if (!userObject) {
          setUploadStage('error');
          setUploadError('Please log in to share a post.');
          setIsSubmitting(false);
          return;
        }

        // ── STAGE 1: Trim + Crop + Convert each video ──────────────
        const totalItems = media.length;
        const convertedMedia = await Promise.all(media.map(async (item, idx) => {
          if (item.type !== 'video' || !item.originalFile) return item;

          const start = item.trimStart || 0;
          const dur   = item.duration  || 0;
          const end   = (item.trimEnd && item.trimEnd > 0) ? item.trimEnd : dur;

          let cropParams = null;
          if (item.croppedAreaPixels) {
            const { x, y, width, height } = item.croppedAreaPixels;
            if (width > 0 && height > 0) {
              const aspect = item.aspect || (width / height) || 1;
              const maxLong = 1920;
              let outputWidth, outputHeight;
              if (aspect >= 1) {
                outputWidth  = Math.min(width,  maxLong);
                outputHeight = Math.round(outputWidth / aspect);
              } else {
                outputHeight = Math.min(height, maxLong);
                outputWidth  = Math.round(outputHeight * aspect);
              }
              outputWidth  = outputWidth  % 2 === 0 ? outputWidth  : outputWidth  - 1;
              outputHeight = outputHeight % 2 === 0 ? outputHeight : outputHeight - 1;
              cropParams = { x, y, width, height, outputWidth, outputHeight };
            }
          }

          const convertedFile = await processVideoForUpload(
            item.originalFile, start, end, cropParams,
            (pct) => {
              const base  = (idx / totalItems) * 50;
              const slice = (1 / totalItems) * 50;
              setUploadProgress(Math.round(base + (pct / 100) * slice));
            }
          );
          return { ...item, convertedFile };
        }));

        // ── STAGE 2: Upload files ──────────────────────────────────
        setUploadStage('uploading');
        setUploadProgress(50);

        const processedMedia = await Promise.all(convertedMedia.map(async (item, idx) => {
          let blob;
          let uploadMimeType;

          try {
            if (item.type === 'video') {
              const fileToUpload = item.convertedFile || item.originalFile;
              if (fileToUpload) {
                blob = fileToUpload;
                uploadMimeType = 'video/mp4';
              } else {
                const response = await fetch(item.url);
                blob = await response.blob();
                uploadMimeType = blob.type;
              }
            } else {
              blob = await applyFiltersToImage(item);
              uploadMimeType = blob.type;
            }
          } catch (e) {
            console.error('Error processing media, falling back to original', e);
            const response = await fetch(item.croppedUrl || item.url);
            blob = await response.blob();
            uploadMimeType = blob.type;
          }

          const fileExt = item.type === 'video' ? 'mp4' : (uploadMimeType.split('/')[1] || 'jpg');
          const fileName = `upload_${Date.now()}_${Math.random().toString(36).substr(2, 9)}.${fileExt}`;
          const file = new File([blob], fileName, { type: uploadMimeType });

          const formData = new FormData();
          formData.append('file', file);

          const uploadResponse = await api.post('https://api.bebsmart.in/api/upload', formData, {
            headers: { 'Content-Type': 'multipart/form-data' },
            onUploadProgress: (evt) => {
              if (evt.total) {
                const filePct = Math.round((evt.loaded / evt.total) * 100);
                const base = 50 + (idx / totalItems) * 45;
                const slice = (1 / totalItems) * 45;
                setUploadProgress(Math.round(base + (filePct / 100) * slice));
              }
            }
          });

          const { fileName: serverFileName, url: serverUrl, fileUrl: serverFileUrl } = uploadResponse.data;
          const finalUrl = serverUrl || serverFileUrl;

          // Generate Filter CSS
          const filterDef = FILTERS.find(f => f.name === item.filter);
          const baseFilter = filterDef ? filterDef.style : '';
          const adj = item.adjustments;
          const brightness = `brightness(${100 + adj.brightness}%)`;
          const contrast = `contrast(${100 + adj.contrast}%)`;
          const saturate = `saturate(${100 + adj.saturate}%)`;
          const sepia = adj.sepia !== 0 ? `sepia(${Math.abs(adj.sepia)}%)` : '';
          const hue = adj.sepia < 0 ? `hue-rotate(-${Math.abs(adj.sepia)}deg)` : (adj.sepia > 0 ? `hue-rotate(${adj.sepia}deg)` : '');
          const filterCss = `${baseFilter} ${brightness} ${contrast} ${saturate} ${sepia} ${hue}`.trim();

          // Upload thumbnail for video
          let uploadedThumbs = null;
          let thumbnailTime = 0;
          if (item.type === 'video') {
            const thumbs = item.thumbnails || [];
            const cover = item.coverUrl;
            if (cover) {
              const thumbForm = new FormData();
              const imgBlob = await (await fetch(cover)).blob();
              const tFile = new File([imgBlob], `thumb_${Date.now()}.jpg`, { type: 'image/jpeg' });
              thumbForm.append('file', tFile);
              try {
                const thumbRes = await api.post('https://api.bebsmart.in/api/upload/thumbnail', thumbForm, {
                  headers: { 'Content-Type': 'multipart/form-data' }
                });
                uploadedThumbs = thumbRes.data?.thumbnails || null;
              } catch {
                uploadedThumbs = null;
              }
              const count = thumbs.length;
              const idxThumb = Math.max(0, thumbs.findIndex(t => t === cover));
              const dur = item.duration || 0;
              thumbnailTime = (count > 1 && dur > 0) ? (idxThumb * dur) / (count - 1) : 0;
            }
          }

          const dur = item.duration || 0;
          const trimStart = item.trimStart || 0;
          const trimEnd = (item.trimEnd && item.trimEnd > 0) ? item.trimEnd : dur;

          // Build the media object per the API schema
          const mediaObj = {
            fileName: serverFileName || fileName,
            fileUrl: finalUrl,
            url: finalUrl,
            media_type: item.type === 'video' ? 'video' : 'image',
          };

          if (item.type === 'video') {
            mediaObj.video_meta = {
              original_length_seconds: dur,
              selected_start: trimStart,
              selected_end: trimEnd,
              final_duration: Math.max(0, trimEnd - trimStart),
              thumbnail_time: thumbnailTime
            };
            mediaObj.timing_window = {
              start: trimStart,
              end: trimEnd
            };
            if (uploadedThumbs) {
              mediaObj.thumbnails = uploadedThumbs;
            }
          } else {
            // Image editing data
            mediaObj.image_editing = {
              filter: { name: item.filter || 'Original', css: filterCss },
              adjustments: {
                brightness: item.adjustments.brightness,
                contrast: item.adjustments.contrast,
                saturation: item.adjustments.saturate,
                temperature: item.adjustments.sepia,
                fade: item.adjustments.opacity,
                vignette: item.adjustments.vignette
              }
            };
          }

          // Crop settings (for both image and video)
          mediaObj.crop_settings = {
            mode: 'original',
            aspect_ratio: getAspectRatioLabel(item.aspect || item.originalAspect || 1),
            zoom: item.zoom || 1,
            x: item.crop?.x || 0,
            y: item.crop?.y || 0
          };

          

          return mediaObj;
        }));

        // ── STAGE 3: Post to API ──────────────────────────────────
        setUploadStage('posting');
        setUploadProgress(97);

        const hashtags = caption.match(/#[a-zA-Z0-9_]+/g) || [];

        if (postType === 'reel') {
          // Reel — existing endpoint unchanged
          const payload = {
            caption,
            location,
            media: processedMedia
              .filter(m => m.media_type === 'video')
              .map(m => { const copy = { ...m }; delete copy._fileUrl; return copy; }),
            tags: hashtags,
            people_tags: tags.map(t => ({
              user_id: t.user.id,
              username: t.user.username,
              x: t.x,
              y: t.y
            })),
            hide_likes_count: hideLikes,
            turn_off_commenting: turnOffCommenting
          };
          await api.post('https://api.bebsmart.in/api/posts/reels', payload);

        } else if (postType === 'ad') {
          if (!ensureAdProfileCompletion()) {
            setIsSubmitting(false);
            setUploadStage('idle');
            setUploadProgress(0);
            return;
          }
          // ── AD — new /api/ads endpoint with full schema ──
          if (!ensureAdPackageLimit()) {
            setIsSubmitting(false);
            setUploadStage('idle');
            setUploadProgress(0);
            return;
          }
          const mediaForApi = processedMedia.map(m => { const copy = { ...m }; delete copy._fileUrl; return copy; });

          const adPayload = {
            type: 'ads',
            // Core
            ad_title: adTitle,
            ad_description: adDescription,
            caption,
            location,
            ad_type: adType,
            content_type: media.some(m => m.type === 'video') ? 'reel' : 'post',
            status: submitMode === 'draft' ? 'draft' : 'pending',
            // Media
            media: mediaForApi,
            hashtags,
            tagged_users: tags.map(t => ({
              user_id: t.user.id,
              username: t.user.username,
              position_x: t.x,
              position_y: t.y
            })),
            // CTA
            cta: {
              type: ctaType,
              url: ctaUrl,
              deep_link: ctaDeepLink,
              phone_number: ctaPhone,
              email: ctaEmail,
              whatsapp_number: ctaWhatsapp,
            },
            // Budget
            total_budget_coins: parseFloat(totalBudgetCoins) || 0,
            budget: {
              daily_budget_coins: parseFloat(dailyBudgetCoins) || 0,
              start_date: budgetStartDate || undefined,
              end_date: budgetEndDate || undefined,
              auto_stop_on_budget_exhausted: false,
            },
            // Categorization
            category: selectedCategory || '',
            sub_category: subCategory,
            tags: hashtags,
            keywords,
            // Legacy targeting
            target_language: selectedLanguages,
            target_location: selectedCountries,
            target_states: selectedStates,
            // New structured targeting
            targeting: {
              countries: selectedCountries,
              states: selectedStates,
              cities: selectedCities,
              age_min: parseInt(ageMin) || 13,
              age_max: parseInt(ageMax) || 65,
              gender: genderTarget,
              interests: selectedInterests,
              device_types: selectedDeviceTypes,
            },
            // Engagement
            engagement_controls: {
              hide_likes_count: hideLikes,
              disable_comments: turnOffCommenting,
              disable_share: disableShare,
              disable_save: disableSave,
              disable_report: disableReport,
              moderation_enabled: moderationEnabled,
            },
            // Tracking
            tracking: {
              utm_source: utmSource,
              utm_medium: utmMedium,
              utm_campaign: utmCampaign,
              utm_term: utmTerm,
              utm_content: utmContent,
              conversion_pixel_id: conversionPixelId,
            },
            // Compliance
            compliance: {
              policy_agreed: policyAgreed,
            },
          };

          await api.post('https://api.bebsmart.in/api/ads', adPayload);

        } else {
          // Post — existing endpoint unchanged
          const payload = {
            caption,
            location,
            media: processedMedia.map(m => { const copy = { ...m }; delete copy.fileUrl; return copy; }),
            tags: hashtags,
            people_tags: tags.map(t => ({
              user_id: t.user.id,
              username: t.user.username,
              x: t.x,
              y: t.y
            })),
            hide_likes_count: hideLikes,
            turn_off_commenting: turnOffCommenting,
            type: postType
          };
          await api.post('/posts', payload);
        }

        setUploadProgress(100);
        setUploadStage('done');
        setShowSuccess(true);

      } catch (error) {
        console.error('Error creating post:', error);
        setUploadStage('error');
        setUploadError(error?.response?.data?.message || error?.message || 'Failed to upload. Please try again.');
      } finally {
        setIsSubmitting(false);
      }
    }
  };

  const handleEmojiClick = (emoji) => {
    setCaption(prev => prev + emoji);
    setShowEmojiPicker(false);
  };

  const handleImageClick = (e) => {
    if (step !== 'share') return;
    if (e.target.closest('.tag-item')) return;
    if (draggingTagId) return;
    setShowTagSearch(true);
    setSearchQuery('');
    fetchUsers('');
  };

  const fetchUsers = async (query) => {
    setIsSearchingUsers(true);
    try {
      const { data } = await api.get('https://api.bebsmart.in/api/users');
      let usersRaw = Array.isArray(data) ? data : (data.users || []);
      const users = usersRaw.map(item => item.user || item);
      let filtered = users;
      if (query && query.trim()) {
        const q = query.trim().toLowerCase();
        filtered = users.filter(u => (u.username || '').toLowerCase().includes(q) || (u.full_name || '').toLowerCase().includes(q));
      }
      const mapped = filtered.map(u => ({
        id: u.id, username: u.username, avatar_url: u.avatar_url || '', full_name: u.full_name || ''
      }));
      setSearchResults(mapped);
    } catch {
      setSearchResults([]);
    } finally {
      setIsSearchingUsers(false);
    }
  };

  useEffect(() => {
    if (step !== 'share') return;
    const loadAll = async () => {
      setIsLoadingAllUsers(true);
      try {
        const { data } = await api.get('https://api.bebsmart.in/api/users');
        const usersRaw = Array.isArray(data) ? data : (data.users || []);
        const users = usersRaw.map(item => item.user || item);
        const mapped = users.map(u => ({
          id: u.id, username: u.username, avatar_url: u.avatar_url || '', full_name: u.full_name || ''
        }));
        setAllUsers(mapped);
      } catch {
        setAllUsers([]);
      } finally {
        setIsLoadingAllUsers(false);
      }
    };
    loadAll();
  }, [step]);

  const handleTagUser = (user) => {
    const newTag = { id: Math.random().toString(36).substr(2, 9), x: 50, y: 50, user };
    setTags([...tags, newTag]);
    setShowTagSearch(false);
  };

  const handleRemoveTag = (e, tagId) => {
    e.stopPropagation();
    setTags(tags.filter(t => t.id !== tagId));
  };

  useEffect(() => {
    if (showTagSearch) {
      const timer = setTimeout(() => fetchUsers(searchQuery), 300);
      return () => clearTimeout(timer);
    }
  }, [searchQuery, showTagSearch]);

  const handleClose = () => {
    setStep('select');
    setMedia([]);
    setCurrentIndex(0);
    setCaption('');
    
    setSelectedCategory("");
    setSelectedLanguages([]);
    setSelectedCountries([]);
    setSelectedStates([]);
    setTotalBudgetCoins('');
    
    setTags([]);
    onClose();
  };

  const setAspect = (aspect) => {
    updateCurrentMedia({ aspect, zoom: 1, crop: { x: 0, y: 0 } });
    setShowRatioMenu(false);
  };

  const applyFilter = (filterName) => updateCurrentMedia({ filter: filterName });

  const updateAdjustment = (property, value) => {
    const currentAdjustments = currentMedia.adjustments || {};
    updateCurrentMedia({ adjustments: { ...currentAdjustments, [property]: value } });
  };

  const getFilterStyle = (item) => {
    if (!item) return {};
    const filterDef = FILTERS.find(f => f.name === item.filter);
    const baseFilter = filterDef ? filterDef.style : '';
    const adj = item.adjustments;
    const brightness = `brightness(${100 + adj.brightness}%)`;
    const contrast = `contrast(${100 + adj.contrast}%)`;
    const saturate = `saturate(${100 + adj.saturate}%)`;
    const sepia = adj.sepia !== 0 ? `sepia(${Math.abs(adj.sepia)}%)` : '';
    const hue = adj.sepia < 0 ? `hue-rotate(-${Math.abs(adj.sepia)}deg)` : (adj.sepia > 0 ? `hue-rotate(${adj.sepia}deg)` : '');
    return {
      filter: `${baseFilter} ${brightness} ${contrast} ${saturate} ${sepia} ${hue}`.trim(),
      opacity: (100 - adj.opacity) / 100
    };
  };

  const applyFiltersToImage = async (item) => {
    const imageUrl = item.croppedUrl || item.url;
    if (item.type === 'video') return await (await fetch(imageUrl)).blob();
    return new Promise((resolve, reject) => {
      const img = new window.Image();
      img.crossOrigin = "anonymous";
      img.onload = () => {
        const canvas = document.createElement('canvas');
        canvas.width = img.width;
        canvas.height = img.height;
        const ctx = canvas.getContext('2d');
        const filterStyle = getFilterStyle(item);
        if (filterStyle.filter) ctx.filter = filterStyle.filter;
        if (filterStyle.opacity !== undefined && filterStyle.opacity !== 1) ctx.globalAlpha = filterStyle.opacity;
        ctx.drawImage(img, 0, 0, img.width, img.height);
        canvas.toBlob((blob) => {
          if (blob) resolve(blob);
          else reject(new Error('Canvas to Blob conversion failed'));
        }, 'image/jpeg', 0.95);
      };
      img.onerror = (e) => reject(e);
      img.src = imageUrl;
    });
  };

  const formatDuration = (d) => {
    if (!d || !isFinite(d)) return '00:00';
    const m = Math.floor(d / 60);
    const s = Math.floor(d % 60);
    return `${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
  };

  useEffect(() => {
    if (step !== 'cover' && step !== 'edit') return;
    const item = currentMedia;
    if (!item || item.type !== 'video') return;
    if (item.thumbnails && Array.isArray(item.thumbnails)) return;
    const v = document.createElement('video');
    v.crossOrigin = 'anonymous';
    v.src = item.croppedUrl || item.url;
    const canvas = document.createElement('canvas');
    const ctx = canvas.getContext('2d');
    const run = async () => {
      await new Promise(res => { v.onloadedmetadata = res; });
      const duration = isFinite(v.duration) ? v.duration : 0;
      const count = duration > 0 ? Math.min(30, Math.max(2, Math.ceil(duration))) : 7;
      const natW = v.videoWidth  || 640;
      const natH = v.videoHeight || 360;
      const aspect = natW / natH;
      // Strip canvas — small/compact for the filmstrip timeline UI
      const stripH = 120;
      const stripW = Math.round(stripH * aspect);
      const stripCanvas = document.createElement('canvas');
      stripCanvas.width = stripW; stripCanvas.height = stripH;
      const stripCtx = stripCanvas.getContext('2d');

      // Cover canvas — full native resolution (max 720p) for crisp cover photo
      const coverH = Math.min(natH, 720);
      const coverW = Math.round(coverH * aspect);
      const coverCanvas = document.createElement('canvas');
      coverCanvas.width = coverW; coverCanvas.height = coverH;
      const coverCtx = coverCanvas.getContext('2d');

      const stripFrames = [];
      const coverFrames = [];
      for (let i = 0; i < count; i++) {
        const t = duration > 0 ? Math.min(duration - 0.01, i) : 0;
        await new Promise(res => { v.currentTime = t; v.onseeked = res; });
        stripCtx.drawImage(v, 0, 0, stripW, stripH);
        stripFrames.push(stripCanvas.toDataURL('image/jpeg', 0.80));
        coverCtx.drawImage(v, 0, 0, coverW, coverH);
        coverFrames.push(coverCanvas.toDataURL('image/jpeg', 0.95));
      }
      // Use stripFrames for timeline strip (compact), coverFrames[0] for crisp cover
      updateCurrentMedia({ thumbnails: stripFrames, coverUrl: coverFrames[0], coverFrames });
    };
    run();
  }, [step, currentMedia, updateCurrentMedia]);

  useEffect(() => {
    if (step !== 'crop') return;
    const item = currentMedia;
    if (!item || item.type !== 'video') return;
    if (item.coverUrl) return;
    const v = document.createElement('video');
    v.crossOrigin = 'anonymous';
    v.src = item.url;
    const canvas = document.createElement('canvas');
    const ctx = canvas.getContext('2d');
    const run = async () => {
      await new Promise((resolve) => { v.onloadedmetadata = resolve; });
      const w = v.videoWidth || 640;
      const h = v.videoHeight || 360;
      canvas.width = w;
      canvas.height = h;
      await new Promise((res) => { v.currentTime = 0; v.onseeked = res; });
      ctx.drawImage(v, 0, 0, w, h);
      updateCurrentMedia({ coverUrl: canvas.toDataURL('image/jpeg', 0.9) });
    };
    run();
  }, [step, currentMedia, updateCurrentMedia]);

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-[60] bg-black/60 backdrop-blur-sm flex items-center justify-center p-0 md:p-8">
      <button onClick={handleClose} className="absolute top-4 right-4 text-white z-50 md:block hidden">
        <X size={32} />
      </button>

      <div className={`bg-white dark:bg-[#262626] md:max-h-[85vh] md:rounded-xl overflow-hidden flex flex-col transition-all duration-300 shadow-2xl ${step === 'select'
        ? 'w-full h-full md:w-[500px] md:h-[550px]'
        : step === 'crop'
          ? 'w-full h-full md:w-[750px] md:h-[800px]'
          : 'w-full h-full md:w-[1100px] md:h-[800px]'
        }`}>

        {/* Header */}
        <div className="h-[45px] border-b border-gray-200 dark:border-gray-800 flex items-center justify-between px-4 bg-white dark:bg-[#262626] sticky top-0 z-40">
          {step === 'select' ? (
            <>
              <div className="w-10"></div>
              <h2 className="font-semibold text-base text-center dark:text-white flex-1">Create new {postType === 'reel' ? 'reel' : postType === 'ad' ? 'ad' : 'post'}</h2>
              <button onClick={handleClose} className="text-black dark:text-white md:hidden"><X size={24} /></button>
              <div className="w-10 md:block hidden"></div>
            </>
          ) : (
            <>
              <div className="w-20 flex justify-start">
                <button onClick={handleBack} className="text-black dark:text-white p-1 hover:bg-gray-100 dark:hover:bg-gray-800 rounded-full transition-colors">
                  <ArrowLeft size={24} />
                </button>
              </div>
              <h2 className="font-semibold text-base text-center dark:text-white flex-1">
                {step === 'crop' ? 'Step 1 · Crop' : step === 'cover' ? 'Cover' : step === 'edit' ? 'Step 2 · Edit' : step === 'share' && postType === 'ad' ? 'Ad Setup' : 'Share'}
              </h2>
              <div className="w-auto min-w-[140px] flex justify-end items-center gap-2">
                {step === 'share' && postType === 'ad' && (
                  <button
                    onClick={() => handleNextStep('draft')}
                    className="px-3 py-1.5 rounded-full border border-gray-300 dark:border-gray-700 text-gray-700 dark:text-gray-200 font-semibold text-sm transition-colors hover:bg-gray-100 dark:hover:bg-gray-800 disabled:opacity-40"
                    disabled={!totalBudgetCoins || !policyAgreed || isSubmitting}
                  >
                    Save Draft
                  </button>
                )}
                <button
                  onClick={() => handleNextStep('publish')}
                  className="text-[#0095f6] hover:text-[#00376b] dark:hover:text-blue-400 font-semibold text-sm transition-colors disabled:opacity-40"
                  disabled={step === 'share' && postType === 'ad' && (!totalBudgetCoins || !policyAgreed)}
                >
                  {step === 'share' ? 'Share' : 'Next'}
                </button>
              </div>
            </>
          )}
        </div>

        {/* Content */}
        {step === 'select' ? (
          <div
            className={`flex-1 relative flex flex-col items-center justify-center p-8 transition-colors ${isDragging ? 'bg-blue-50 dark:bg-blue-900/20' : 'bg-white dark:bg-[#262626]'}`}
            onDragOver={handleDragOver}
            onDragLeave={handleDragLeave}
            onDrop={handleDrop}
          >
            <div className="relative mb-6">
              <div className="absolute inset-0 blur-xl rounded-full bg-gradient-to-tr from-purple-500/20 to-blue-500/20"></div>
              <div className="relative flex items-center justify-center w-24 h-24 rounded-xl bg-gray-100 dark:bg-gray-800">
                <Images size={56} className="text-gray-800 dark:text-white" />
              </div>
            </div>
            <h3 className="text-xl font-normal mb-6 text-gray-800 dark:text-gray-200">Drag photos and videos here</h3>
            <button
              onClick={handleButtonClick}
              className="bg-[#0095f6] hover:bg-[#1877f2] text-white px-4 py-2 rounded-lg text-sm font-semibold transition-colors"
            >
              Select From Computer
            </button>
            <div className="md:hidden absolute left-0 right-0 bottom-6 flex justify-center">
              <div className="backdrop-blur-md bg-black/40 dark:bg-black/40 border border-white/10 rounded-2xl shadow-xl px-2 py-2 w-[92%] max-w-sm text-white flex items-center justify-around">
                {userObject?.role !== 'vendor' && (
                  <>
                    <button
                      onClick={() => setPostType('post')}
                      className={`flex items-center gap-2 px-3 py-2 rounded-xl ${postType === 'post' ? 'bg-white/20' : 'hover:bg-white/10'}`}
                    >
                      <Image size={18} className="text-purple-400" />
                      <span className="text-xs font-semibold">Post</span>
                    </button>
                    <button
                      onClick={() => setPostType('reel')}
                      className={`flex items-center gap-2 px-3 py-2 rounded-xl ${postType === 'reel' ? 'bg-white/20' : 'hover:bg-white/10'}`}
                    >
                      <Video size={18} className="text-pink-400" />
                      <span className="text-xs font-semibold">Reel</span>
                    </button>
                  </>
                )}
                {userObject?.role === 'vendor' && (
                  <button
                    onClick={() => {
                      if (!isVendorValidated) {
                        setShowVendorNotValidated(true);
                      } else if (!ensureAdProfileCompletion()) {
                        return;
                      } else if (!ensureAdPackageLimit()) {
                        return;
                      } else {
                        if (onOpenAdModal) onOpenAdModal();
                        else onClose();
                        setPostType('ad');
                      }
                    }}
                    className={`flex items-center gap-2 px-3 py-2 rounded-xl ${postType === 'ad' ? 'bg-white/20' : 'hover:bg-white/10'}`}
                  >
                    <Megaphone size={18} className="text-blue-400" />
                    <span className="text-xs font-semibold">Ad</span>
                  </button>
                )}
              </div>
            </div>
          </div>
        ) : step === 'crop' ? (
          <div className="flex-1 bg-[#f0f0f0] dark:bg-[#121212] relative flex items-center justify-center overflow-hidden">
            {currentMedia && (
              <div className="relative w-full h-full" ref={cropContainerRef}>
                {currentMedia.type === 'video' ? (
                  <>
                    <video
                      src={currentMedia.url}
                      className="absolute inset-0 w-full h-full object-contain"
                      autoPlay muted playsInline controls
                    />
                    <div className="absolute inset-0 flex items-center justify-center pointer-events-none">
                      <div
                        className="rounded"
                        style={{
                          width: overlaySize.w,
                          height: overlaySize.h,
                          border: '2px solid rgba(255,255,255,0.85)',
                          boxShadow: '0 0 0 9999px rgba(0,0,0,0.4)'
                        }}
                      />
                    </div>
                  </>
                ) : (
                  <Cropper
                    image={currentMedia.url}
                    crop={currentMedia.crop}
                    zoom={currentMedia.zoom}
                    aspect={currentMedia.aspect || 1}
                    onCropChange={onCropChange}
                    onCropComplete={onCropComplete}
                    onZoomChange={onZoomChange}
                    onMediaLoaded={(mediaSize) => {
                      const { naturalWidth, naturalHeight } = mediaSize;
                      if (naturalWidth && naturalHeight) {
                        const originalAspect = naturalWidth / naturalHeight;
                        if (!currentMedia.originalAspect || Math.abs(currentMedia.originalAspect - originalAspect) > 0.01) {
                          updateCurrentMedia({
                            originalAspect,
                            aspect: (!currentMedia.originalAspect && currentMedia.aspect === 1) ? originalAspect : currentMedia.aspect
                          });
                        }
                      }
                    }}
                    objectFit="contain"
                    showGrid={false}
                    style={{
                      containerStyle: { background: 'transparent' },
                      cropAreaStyle: { border: '1px solid rgba(255, 255, 255, 0.5)' }
                    }}
                  />
                )}
              </div>
            )}
            {media.length > 1 && (
              <>
                {currentIndex > 0 && (
                  <button onClick={() => setCurrentIndex(prev => prev - 1)} className="absolute left-4 top-1/2 -translate-y-1/2 z-20 w-8 h-8 rounded-full bg-white/90 dark:bg-black/80 hover:bg-white dark:hover:bg-black text-gray-800 dark:text-white shadow-md flex items-center justify-center"><ChevronLeft size={20} /></button>
                )}
                {currentIndex < media.length - 1 && (
                  <button onClick={() => setCurrentIndex(prev => prev + 1)} className="absolute right-4 top-1/2 -translate-y-1/2 z-20 w-8 h-8 rounded-full bg-white/90 dark:bg-black/80 hover:bg-white dark:hover:bg-black text-gray-800 dark:text-white shadow-md flex items-center justify-center"><ChevronRight size={20} /></button>
                )}
              </>
            )}
            <div className="absolute bottom-4 left-4 flex gap-3 z-30">
              <div className="relative">
                {showRatioMenu && (
                  <div className="absolute bottom-full left-0 mb-2 bg-black/80 backdrop-blur-sm rounded-lg overflow-hidden flex flex-col w-32 shadow-xl">
                    <button onClick={() => setAspect(currentMedia.originalAspect || 1)} className={`flex items-center gap-3 px-4 py-3 text-sm font-medium hover:bg-white/10 ${currentMedia.aspect === currentMedia.originalAspect ? 'text-white' : 'text-gray-400'}`}><Image size={18} /> Original</button>
                    <button onClick={() => setAspect(1)} className={`flex items-center gap-3 px-4 py-3 text-sm font-medium hover:bg-white/10 ${currentMedia.aspect === 1 ? 'text-white' : 'text-gray-400'}`}><span className="w-5 h-5 border-2 border-current rounded-sm"></span> 1:1</button>
                    <button onClick={() => setAspect(4 / 5)} className={`flex items-center gap-3 px-4 py-3 text-sm font-medium hover:bg-white/10 ${currentMedia.aspect === 0.8 ? 'text-white' : 'text-gray-400'}`}><span className="w-4 h-5 border-2 border-current rounded-sm"></span> 4:5</button>
                    <button onClick={() => setAspect(16 / 9)} className={`flex items-center gap-3 px-4 py-3 text-sm font-medium hover:bg-white/10 ${currentMedia.aspect === 16 / 9 ? 'text-white' : 'text-gray-400'}`}><span className="w-5 h-3 border-2 border-current rounded-sm"></span> 16:9</button>
                    <button onClick={() => setAspect(9 / 16)} className={`flex items-center gap-3 px-4 py-3 text-sm font-medium hover:bg-white/10 ${currentMedia.aspect === 9 / 16 ? 'text-white' : 'text-gray-400'}`}><span className="w-3 h-5 border-2 border-current rounded-sm"></span> 9:16</button>
                  </div>
                )}
                <button onClick={() => { setShowRatioMenu(!showRatioMenu); setShowZoomSlider(false); setShowMultiSelect(false); }} className={`w-8 h-8 rounded-full ${showRatioMenu ? 'bg-white text-black' : 'bg-black/70 text-white'} hover:bg-white hover:text-black flex items-center justify-center transition-colors`}><Maximize2 size={16} /></button>
              </div>
            </div>
            <div className="absolute bottom-4 right-4 flex gap-3 z-30">
              <div className="relative">
                {showZoomSlider && (
                  <div className="absolute bottom-full right-0 mb-2 p-3 bg-black/80 backdrop-blur-sm rounded-lg shadow-xl w-32">
                    <input type="range" min={1} max={3} step={0.1} value={currentMedia.zoom} onChange={(e) => onZoomChange(Number(e.target.value))} className="w-full h-1 bg-gray-600 rounded-lg appearance-none cursor-pointer accent-white" />
                  </div>
                )}
                <button onClick={() => { setShowZoomSlider(!showZoomSlider); setShowRatioMenu(false); setShowMultiSelect(false); }} className={`w-8 h-8 rounded-full ${showZoomSlider ? 'bg-white text-black' : 'bg-black/70 text-white'} hover:bg-white hover:text-black flex items-center justify-center transition-colors`}><ZoomIn size={16} /></button>
              </div>
              <div className="relative">
                {showMultiSelect && (
                  <div className="absolute bottom-full right-0 mb-2 p-3 bg-black/80 backdrop-blur-sm rounded-lg shadow-xl w-auto min-w-[200px] max-w-[300px]">
                    <div className="flex gap-2 overflow-x-auto pb-1 scrollbar-hide">
                      {media.map((item, idx) => (
                        <div key={item.id} className={`relative flex-shrink-0 w-16 h-16 rounded overflow-hidden cursor-pointer border-2 ${idx === currentIndex ? 'border-white' : 'border-transparent'}`} onClick={() => setCurrentIndex(idx)}>
                          <img src={item.type === 'video' ? (item.coverUrl || item.url) : item.url} className="w-full h-full object-cover" alt="" />
                          <button onClick={(e) => handleRemoveMedia(idx, e)} className="absolute top-0.5 right-0.5 w-4 h-4 bg-black/50 rounded-full flex items-center justify-center text-white hover:bg-black/80"><X size={10} /></button>
                        </div>
                      ))}
                      <button onClick={handleButtonClick} className="flex-shrink-0 w-12 h-12 rounded-full border border-gray-500 flex items-center justify-center text-gray-400 hover:text-white hover:border-white transition-colors self-center ml-2"><Plus size={24} /></button>
                    </div>
                  </div>
                )}
                <button onClick={() => { setShowMultiSelect(!showMultiSelect); setShowRatioMenu(false); setShowZoomSlider(false); }} className={`w-8 h-8 rounded-full ${showMultiSelect ? 'bg-white text-black' : 'bg-black/70 text-white'} hover:bg-white hover:text-black flex items-center justify-center transition-colors`}><Copy size={16} /></button>
              </div>
            </div>
          </div>
        ) : step === 'edit' ? (
          /* EDIT STEP */
          <div className="flex-1 flex lg:flex-row flex-col lg:overflow-hidden overflow-y-auto overflow-x-hidden">
            {/* Left: Image/Video Preview */}
            <div ref={editContainerRef} className="relative bg-[#f0f0f0] dark:bg-[#121212] flex items-center justify-center w-full flex-1 h-auto">
              {currentMedia && (
                currentMedia.type === 'video' ? (
                  <div style={{ width: editBoxSize.w, height: editBoxSize.h }} className="relative overflow-hidden bg-black rounded">
                    <video
                      src={currentMedia.croppedUrl || currentMedia.url}
                      className="hidden"
                      ref={editVideoRef}
                      muted
                      preload="metadata"
                      onLoadedMetadata={(e) => { e.currentTarget.currentTime = currentMedia.trimStart || 0; }}
                      onTimeUpdate={(e) => {
                        setTrimPlayTime(e.currentTarget.currentTime);
                        const d = currentMedia.duration || 0;
                        const end = currentMedia.trimEnd && currentMedia.trimEnd > 0 ? currentMedia.trimEnd : d;
                        if (end > 0 && e.currentTarget.currentTime >= end) {
                          e.currentTarget.currentTime = currentMedia.trimStart || 0;
                        }
                      }}
                    />
                    <img
                      src={currentMedia.coverUrl || (currentMedia.thumbnails && currentMedia.thumbnails[0]) || currentMedia.croppedUrl || currentMedia.url}
                      className="w-full h-full object-cover"
                      alt="Cover"
                    />
                    <div className="absolute inset-0 flex items-center justify-center pointer-events-none">
                      <div className="w-14 h-14 rounded-full bg-black/40 flex items-center justify-center">
                        <svg className="w-7 h-7 text-white ml-1" fill="currentColor" viewBox="0 0 24 24"><path d="M8 5v14l11-7z"/></svg>
                      </div>
                    </div>
                    {currentMedia.duration > 0 && (
                      <div className="absolute bottom-2 right-2 bg-black/70 text-white text-xs font-mono px-2 py-0.5 rounded">
                        {formatDuration((currentMedia.trimEnd && currentMedia.trimEnd > 0 ? currentMedia.trimEnd : currentMedia.duration) - (currentMedia.trimStart || 0))}
                      </div>
                    )}
                  </div>
                ) : (
                  <img
                    src={currentMedia.croppedUrl || currentMedia.url}
                    className="lg:max-w-full lg:max-h-full object-contain w-[400px] h-[500px] transition-all duration-200"
                    style={getFilterStyle(currentMedia)}
                    alt="Edit"
                  />
                )
              )}
              {media.length > 1 && (
                <>
                  {currentIndex > 0 && (
                    <button onClick={() => setCurrentIndex(prev => prev - 1)} className="absolute left-4 top-1/2 -translate-y-1/2 z-20 w-8 h-8 rounded-full bg-white/90 hover:bg-white text-gray-800 shadow-md flex items-center justify-center"><ChevronLeft size={20} /></button>
                  )}
                  {currentIndex < media.length - 1 && (
                    <button onClick={() => setCurrentIndex(prev => prev + 1)} className="absolute right-4 top-1/2 -translate-y-1/2 z-20 w-8 h-8 rounded-full bg-white/90 hover:bg-white text-gray-800 shadow-md flex items-center justify-center"><ChevronRight size={20} /></button>
                  )}
                </>
              )}
            </div>

            {/* Right: Tools */}
            <div className="bg-white dark:bg-black border-l border-gray-200 dark:border-gray-800 flex flex-col lg:w-[340px] w-full min-w-[340px] flex-none">
              <div className="flex border-b border-gray-200 dark:border-gray-800">
                {currentMedia?.type !== 'video' ? (
                  <>
                    <button className={`flex-1 py-3 text-sm font-semibold transition-colors ${activeTab === 'filters' ? 'text-black dark:text-white border-b border-black dark:border-white' : 'text-gray-400 hover:text-gray-600 dark:hover:text-gray-300'}`} onClick={() => setActiveTab('filters')}>Filter</button>
                    <button className={`flex-1 py-3 text-sm font-semibold transition-colors ${activeTab === 'adjustments' ? 'text-black dark:text-white border-b border-black dark:border-white' : 'text-gray-400 hover:text-gray-600 dark:hover:text-gray-300'}`} onClick={() => setActiveTab('adjustments')}>Adjustment</button>
                  </>
                ) : (
                  <button className={`flex-1 py-3 text-sm font-semibold transition-colors ${activeTab === 'video' ? 'text-black dark:text-white border-b border-black dark:border-white' : 'text-gray-400 hover:text-gray-600 dark:hover:text-gray-300'}`} onClick={() => setActiveTab('video')}>Video</button>
                )}
              </div>

              <div className="flex flex-col h-full overflow-y-scroll scrollbar-hide px-5 py-5">
                {activeTab === 'filters' ? (
                  <div className="grid grid-cols-3 gap-4">
                    {FILTERS.map((filter) => (
                      <div key={filter.name} className="flex flex-col items-center gap-2 cursor-pointer group" onClick={() => applyFilter(filter.name)}>
                        <div className={`w-full aspect-square rounded-md overflow-hidden border-2 transition-all ${currentMedia.filter === filter.name ? 'border-[#0095f6]' : 'border-transparent'}`}>
                          <img src={currentMedia.croppedUrl || currentMedia.url} className="w-full h-full object-cover" style={{ filter: filter.style }} alt={filter.name} />
                        </div>
                        <span className={`text-xs font-semibold ${currentMedia.filter === filter.name ? 'text-[#0095f6]' : 'text-gray-500 dark:text-gray-400'}`}>{filter.name}</span>
                      </div>
                    ))}
                  </div>
                ) : activeTab === 'adjustments' ? (
                  <div className="flex flex-col gap-6 pb-4">
                    {ADJUSTMENTS.map((adj) => (
                      <div key={adj.name} className="flex flex-col gap-3">
                        <div className="flex justify-between items-center">
                          <span className="text-sm font-semibold dark:text-white">{adj.name}</span>
                          {currentMedia.adjustments[adj.property] !== 0 && (
                            <button onClick={() => updateAdjustment(adj.property, 0)} className="text-xs text-blue-500 font-semibold hover:text-blue-600">Reset</button>
                          )}
                        </div>
                        <div className="flex items-center gap-3">
                          <input
                            type="range" min={adj.min} max={adj.max}
                            value={currentMedia.adjustments[adj.property] || 0}
                            onChange={(e) => updateAdjustment(adj.property, parseInt(e.target.value))}
                            className="flex-1 h-1 bg-gray-200 dark:bg-gray-700 rounded-lg appearance-none cursor-pointer accent-black dark:accent-white"
                            disabled={currentMedia?.type === 'video'}
                          />
                          <span className="text-xs font-mono w-8 text-right text-gray-500 dark:text-gray-400">{currentMedia.adjustments[adj.property] || 0}</span>
                        </div>
                      </div>
                    ))}
                  </div>
                ) : (
                  (currentMedia?.thumbnails && currentMedia.duration !== undefined) ? (
                  <div className="flex flex-col gap-5 pb-4">
                    {/* Cover Photo */}
                    <div>
                      <div className="flex items-center justify-between mb-3">
                        <span className="text-sm font-semibold dark:text-white">Cover photo</span>
                        <button className="text-sm font-bold text-[#0095f6] hover:text-blue-400 transition-colors" onClick={() => coverInputRef.current?.click()}>Select From Computer</button>
                        <input ref={coverInputRef} type="file" accept="image/*" className="hidden" onChange={(e) => {
                          const f = e.target.files?.[0];
                          if (!f) return;
                          const url = URL.createObjectURL(f);
                          updateCurrentMedia({ coverUrl: url, uploadedCoverUrl: url });
                          e.target.value = '';
                        }} />
                      </div>
                      {(() => {
                        const thumbs = currentMedia?.thumbnails || [];
                        const selIdx = Math.max(0, thumbs.findIndex(t => t === currentMedia.coverUrl));
                        const frameW = thumbs.length > 0 ? 100 / thumbs.length : 100;
                        return (
                          <div
                            className="relative w-full rounded-xl overflow-hidden bg-black select-none cursor-grab active:cursor-grabbing"
                            style={{ height: 72 }}
                            onMouseDown={(startE) => {
                              startE.preventDefault();
                              const strip = startE.currentTarget;
                              const rect  = strip.getBoundingClientRect();
                              const pick  = (clientX) => {
                                const ratio = Math.min(1, Math.max(0, (clientX - rect.left) / rect.width));
                                const idx   = Math.min(thumbs.length - 1, Math.floor(ratio * thumbs.length));
                                if (thumbs[idx]) updateCurrentMedia({ coverUrl: thumbs[idx] });
                              };
                              pick(startE.clientX);
                              const onMove = (e) => pick(e.clientX);
                              const onUp   = () => { window.removeEventListener('mousemove', onMove); window.removeEventListener('mouseup', onUp); };
                              window.addEventListener('mousemove', onMove);
                              window.addEventListener('mouseup', onUp);
                            }}
                          >
                            <div className="flex h-full pointer-events-none">
                              {thumbs.map((thumb, idx) => (
                                <div key={idx} className="relative flex-1 h-full overflow-hidden" style={{ minWidth: 0 }}>
                                  <img src={thumb} className="w-full h-full object-cover" alt="" draggable={false} />
                                </div>
                              ))}
                            </div>
                            <div
                              className="absolute top-0 bottom-0 pointer-events-none z-10 transition-all duration-100"
                              style={{ left: `${selIdx * frameW}%`, width: `${frameW}%`, border: '3px solid white', borderRadius: 4, boxShadow: '0 0 0 1.5px rgba(0,0,0,0.5), inset 0 0 0 1px rgba(255,255,255,0.3)' }}
                            />
                            <div className="absolute top-0 bottom-0 left-0 bg-black/40 pointer-events-none transition-all duration-100" style={{ width: `${selIdx * frameW}%` }} />
                            <div className="absolute top-0 bottom-0 right-0 bg-black/40 pointer-events-none transition-all duration-100" style={{ width: `${(thumbs.length - selIdx - 1) * frameW}%` }} />
                          </div>
                        );
                      })()}
                    </div>

                    {/* Trim */}
                    <div>
                      <div className="flex items-center justify-between mb-3">
                        <span className="text-sm font-semibold dark:text-white">Trim</span>
                        {(() => {
                          const dur = currentMedia.duration || 0;
                          const s   = currentMedia.trimStart || 0;
                          const e2  = (currentMedia.trimEnd && currentMedia.trimEnd > 0) ? currentMedia.trimEnd : dur;
                          return <span className="text-xs text-gray-400 dark:text-gray-500 font-mono">{formatDuration(Math.max(0, e2 - s))} selected</span>;
                        })()}
                      </div>
                      {currentMedia?.thumbnails && (
                        <div
                          className="relative select-none"
                          style={{ paddingBottom: 20 }}
                          onMouseMove={(e) => {
                            if (!dragHandle) return;
                            const rect = trimTrackRef.current.getBoundingClientRect();
                            const ratio = Math.min(1, Math.max(0, (e.clientX - rect.left) / rect.width));
                            const t = ratio * (currentMedia.duration || 0);
                            if (dragHandle === 'start') updateCurrentMedia({ trimStart: Math.max(0, Math.min(t, (currentMedia.trimEnd || 0) - 0.5)) });
                            else updateCurrentMedia({ trimEnd: Math.min(currentMedia.duration || 0, Math.max(t, (currentMedia.trimStart || 0) + 0.5)) });
                          }}
                          onMouseLeave={() => setDragHandle(null)}
                          onMouseUp={() => setDragHandle(null)}
                        >
                          <div ref={trimTrackRef} className="relative w-full rounded-xl overflow-hidden" style={{ height: 64 }}>
                            <div className="flex h-full">
                              {(currentMedia.thumbnails || []).map((thumb, idx) => (
                                <div key={idx} className="flex-1 h-full overflow-hidden" style={{ minWidth: 0 }}>
                                  <img src={thumb} className="w-full h-full object-cover" alt="" draggable={false} />
                                </div>
                              ))}
                            </div>
                            {(() => {
                              const dur = currentMedia.duration || 0;
                              const s   = (currentMedia.trimStart || 0) / (dur || 1);
                              const e2  = ((currentMedia.trimEnd && currentMedia.trimEnd > 0) ? currentMedia.trimEnd : dur) / (dur || 1);
                              return (
                                <>
                                  <div className="absolute top-0 bottom-0 left-0 bg-black/55 pointer-events-none" style={{ width: `${s * 100}%` }} />
                                  <div className="absolute top-0 bottom-0 right-0 bg-black/55 pointer-events-none" style={{ width: `${(1 - e2) * 100}%` }} />
                                  <div className="absolute top-0 bottom-0 border-t-[3px] border-b-[3px] border-white pointer-events-none z-10" style={{ left: `${s * 100}%`, width: `${Math.max(0, e2 - s) * 100}%` }} />
                                  <div className="absolute top-0 bottom-0 w-[2px] bg-white z-20" style={{ left: `${Math.min(1, Math.max(0, (trimPlayTime || 0) / (dur || 1))) * 100}%`, boxShadow: '0 0 4px rgba(255,255,255,0.8)' }} />
                                  <div className="absolute top-0 bottom-0 z-30 flex items-center justify-center cursor-ew-resize" style={{ left: `${s * 100}%`, width: 20, transform: 'translateX(-4px)' }} onMouseDown={(e) => { e.preventDefault(); setDragHandle('start'); }}>
                                    <div className="w-[14px] h-full rounded-l-lg flex items-center justify-center" style={{ background: 'white' }}>
                                      <div className="flex flex-col gap-[3px]"><div className="w-[2px] h-3 bg-gray-400 rounded-full" /><div className="w-[2px] h-3 bg-gray-400 rounded-full" /></div>
                                    </div>
                                  </div>
                                  <div className="absolute top-0 bottom-0 z-30 flex items-center justify-center cursor-ew-resize" style={{ left: `${e2 * 100}%`, width: 20, transform: 'translateX(-16px)' }} onMouseDown={(e2e) => { e2e.preventDefault(); setDragHandle('end'); }}>
                                    <div className="w-[14px] h-full rounded-r-lg flex items-center justify-center" style={{ background: 'white' }}>
                                      <div className="flex flex-col gap-[3px]"><div className="w-[2px] h-3 bg-gray-400 rounded-full" /><div className="w-[2px] h-3 bg-gray-400 rounded-full" /></div>
                                    </div>
                                  </div>
                                </>
                              );
                            })()}
                          </div>
                        </div>
                      )}
                    </div>

                    {/* Sound toggle */}
                    <div className="flex items-center justify-between pt-1 border-t border-gray-100 dark:border-gray-800">
                      <span className="text-sm font-semibold dark:text-white">Sound</span>
                      <label className="relative inline-flex items-center cursor-pointer">
                        <input type="checkbox" className="sr-only peer" checked={currentMedia.soundOn} onChange={(e) => updateCurrentMedia({ soundOn: e.target.checked })} />
                        <div className="w-11 h-6 bg-gray-200 dark:bg-gray-600 peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-blue-600"></div>
                      </label>
                    </div>
                  </div>
                  ) : (
                    <div className="flex flex-col items-center justify-center py-16 gap-3">
                      <div className="w-8 h-8 border-2 border-[#0095f6] border-t-transparent rounded-full animate-spin"></div>
                      <span className="text-xs text-gray-400 dark:text-gray-500">Generating frames…</span>
                    </div>
                  )
                )}
              </div>
            </div>
          </div>
        ) : (
          /* SHARE STEP */
          <div className="flex-1 flex flex-col md:flex-row lg:overflow-hidden overflow-y-auto overflow-x-hidden">
            {/* Left: Final Image Preview */}
            <div className="relative bg-[#f0f0f0] dark:bg-[#121212] flex items-center justify-center select-none w-full h-auto md:flex-[2]">
              {currentMedia && (
                <div ref={shareContainerRef} data-media-container className="relative w-full h-full flex items-center justify-center" onClick={handleImageClick}>
                  {currentMedia.type === 'video' ? (
                    <div style={{ width: shareBoxSize.w, height: shareBoxSize.h }} className="overflow-hidden bg-black rounded">
                      <video
                        src={currentMedia.croppedUrl || currentMedia.url}
                        className="w-full h-full object-cover"
                        controls={false} autoPlay loop
                        muted={!currentMedia.soundOn}
                        onLoadedMetadata={(e) => { e.currentTarget.currentTime = currentMedia.trimStart || 0; }}
                        onTimeUpdate={(e) => {
                          const v = e.currentTarget;
                          const trimEnd = (currentMedia.trimEnd && currentMedia.trimEnd > 0) ? currentMedia.trimEnd : (currentMedia.duration || 0);
                          if (trimEnd > 0 && v.currentTime >= trimEnd) {
                            v.currentTime = currentMedia.trimStart || 0;
                            v.play().catch(() => {});
                          }
                        }}
                      />
                    </div>
                  ) : (
                    <img
                      src={currentMedia.croppedUrl || currentMedia.url}
                      className="max-w-full max-h-full object-contain cursor-crosshair"
                      style={getFilterStyle(currentMedia)}
                      alt="Share Preview"
                    />
                  )}
                  {tags.length === 0 && (
                    <div className="absolute bottom-4 left-1/2 -translate-x-1/2 bg-black/70 text-white text-xs px-3 py-1.5 rounded-full pointer-events-none select-none">
                      Tap to tag · Drag tags to reposition
                    </div>
                  )}
                  {tags.map((tag) => (
                    <div
                      key={tag.id}
                      className="tag-item absolute z-20 select-none"
                      style={{ left: `${tag.x}%`, top: `${tag.y}%`, transform: 'translate(-50%, -50%)', cursor: draggingTagId === tag.id ? 'grabbing' : 'grab' }}
                      onMouseDown={(e) => {
                        if (e.target.closest('button')) return;
                        e.preventDefault(); e.stopPropagation();
                        const container = e.currentTarget.closest('[data-media-container]');
                        if (!container) return;
                        setDraggingTagId(tag.id);
                        const rect = container.getBoundingClientRect();
                        const onMove = (me) => {
                          const nx = Math.min(100, Math.max(0, ((me.clientX - rect.left) / rect.width) * 100));
                          const ny = Math.min(100, Math.max(0, ((me.clientY - rect.top) / rect.height) * 100));
                          setTags(prev => prev.map(t => t.id === tag.id ? { ...t, x: nx, y: ny } : t));
                        };
                        const onUp = () => { setDraggingTagId(null); window.removeEventListener('mousemove', onMove); window.removeEventListener('mouseup', onUp); };
                        window.addEventListener('mousemove', onMove);
                        window.addEventListener('mouseup', onUp);
                      }}
                    >
                      <div className="relative flex items-center gap-1.5 bg-black/80 backdrop-blur-sm text-white px-3 py-1.5 rounded-full shadow-lg border border-white/20">
                        {tag.user.avatar_url ? (
                          <img src={tag.user.avatar_url} className="w-4 h-4 rounded-full object-cover flex-shrink-0" alt="" />
                        ) : (
                          <div className="w-4 h-4 rounded-full bg-gradient-to-br from-pink-400 to-purple-500 flex items-center justify-center flex-shrink-0">
                            <span className="text-[8px] font-bold text-white">{(tag.user.username || '').slice(0,1).toUpperCase()}</span>
                          </div>
                        )}
                        <span className="text-xs font-semibold whitespace-nowrap">@{tag.user.username}</span>
                        <button onClick={(e) => handleRemoveTag(e, tag.id)} className="ml-0.5 w-4 h-4 rounded-full bg-white/20 hover:bg-white/40 flex items-center justify-center transition-colors"><X size={9} /></button>
                      </div>
                      <div className="absolute left-1/2 -translate-x-1/2 -bottom-[5px] w-2 h-2 bg-black/80 rounded-full border border-white/30" />
                    </div>
                  ))}
                  {showTagSearch && (
                    <div className="absolute z-50 bg-white dark:bg-gray-800 rounded-lg shadow-xl w-64 overflow-hidden" style={{ left: '50%', top: '50%', transform: 'translate(-50%, -50%)' }}>
                      <div className="p-3 border-b border-gray-100 dark:border-gray-700 flex items-center justify-between">
                        <span className="font-semibold text-sm dark:text-white">Tag People</span>
                        <button onClick={(e) => { e.stopPropagation(); setShowTagSearch(false); }} className="dark:text-white"><X size={18} /></button>
                      </div>
                      <div className="p-2">
                        <div className="relative">
                          <Search size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
                          <input
                            type="text" placeholder="Search user"
                            className="w-full bg-gray-100 dark:bg-gray-700 rounded-md py-1.5 pl-9 pr-3 text-sm outline-none focus:ring-1 focus:ring-gray-300 dark:text-white dark:placeholder-gray-400"
                            value={searchQuery} onChange={(e) => setSearchQuery(e.target.value)}
                            onClick={(e) => e.stopPropagation()} autoFocus
                          />
                        </div>
                      </div>
                      <div className="max-h-48 overflow-y-auto scrollbar-hide">
                        {isSearchingUsers ? (
                          <div className="p-4 text-center text-gray-400 text-xs">Searching...</div>
                        ) : searchResults.length > 0 ? (
                          searchResults.map(user => (
                            <div key={user.id} className="flex items-center gap-3 p-3 hover:bg-gray-50 dark:hover:bg-gray-700 cursor-pointer" onClick={(e) => { e.stopPropagation(); handleTagUser(user); }}>
                              <div className="w-8 h-8 bg-gray-200 dark:bg-gray-600 rounded-full overflow-hidden flex-shrink-0 flex items-center justify-center">
                                {user.avatar_url ? <img src={user.avatar_url} className="w-full h-full object-cover" alt={user.username} /> : <span className="text-xs font-semibold text-gray-800 dark:text-white">{(user.username || '').slice(0, 1).toUpperCase()}</span>}
                              </div>
                              <div className="flex flex-col overflow-hidden">
                                <span className="text-sm font-semibold truncate dark:text-white">{user.username}</span>
                                <span className="text-xs text-gray-500 dark:text-gray-400 truncate">{user.full_name}</span>
                              </div>
                            </div>
                          ))
                        ) : (
                          <div className="p-4 text-center text-gray-400 text-xs">No users found</div>
                        )}
                      </div>
                    </div>
                  )}
                </div>
              )}
              {media.length > 1 && (
                <>
                  {currentIndex > 0 && <button onClick={() => setCurrentIndex(prev => prev - 1)} className="absolute left-4 top-1/2 -translate-y-1/2 z-20 w-8 h-8 rounded-full bg-white/90 hover:bg-white text-gray-800 shadow-md flex items-center justify-center"><ChevronLeft size={20} /></button>}
                  {currentIndex < media.length - 1 && <button onClick={() => setCurrentIndex(prev => prev + 1)} className="absolute right-4 top-1/2 -translate-y-1/2 z-20 w-8 h-8 rounded-full bg-white/90 hover:bg-white text-gray-800 shadow-md flex items-center justify-center"><ChevronRight size={20} /></button>}
                </>
              )}
            </div>

            {/* Right: Share Details */}
            <div className="flex-1 bg-white dark:bg-black border-t md:border-t-0 md:border-l border-gray-200 dark:border-gray-800 flex flex-col w-full md:w-auto md:min-w-[340px] overflow-y-auto scrollbar-hide">
              {/* User Info */}
              <div className="flex items-center gap-3 p-4">
                <div className="w-8 h-8 bg-gray-200 dark:bg-gray-700 rounded-full overflow-hidden flex items-center justify-center">
                  {userObject?.avatar_url ? (
                    <img src={userObject.avatar_url} className="w-full h-full object-cover" alt={userObject.username} />
                  ) : (
                    <span className="text-xs font-semibold text-gray-800 dark:text-white">{(userObject?.username || 'U').slice(0, 1).toUpperCase()}</span>
                  )}
                </div>
                <span className="font-semibold text-sm dark:text-white">{userObject?.username || 'User'}</span>
              </div>

              {/* Caption */}
              <div className="px-4 pb-4 border-b border-gray-100 dark:border-gray-800 relative">
                <textarea
                  className="w-full min-h-[150px] resize-none outline-none text-sm placeholder-gray-400 bg-transparent dark:text-white"
                  placeholder="Write a caption..."
                  value={caption}
                  onChange={(e) => setCaption(e.target.value)}
                  maxLength={2200}
                />
                <div className="flex items-center justify-between mt-2">
                  <div className="relative">
                    <button onClick={() => setShowEmojiPicker(!showEmojiPicker)} className="text-gray-400 hover:text-gray-600 dark:hover:text-gray-200"><Smile size={20} /></button>
                    {showEmojiPicker && (
                      <div className="absolute bottom-full left-0 mb-2 bg-white dark:bg-gray-800 rounded-lg shadow-xl border border-gray-100 dark:border-gray-700 p-2 w-64 z-50">
                        <div className="text-xs font-semibold text-gray-500 dark:text-gray-400 mb-2 px-1">Most popular</div>
                        <div className="grid grid-cols-7 gap-1">
                          {POPULAR_EMOJIS.map(emoji => (
                            <button key={emoji} onClick={() => handleEmojiClick(emoji)} className="w-8 h-8 flex items-center justify-center text-xl hover:bg-gray-100 dark:hover:bg-gray-700 rounded">{emoji}</button>
                          ))}
                        </div>
                      </div>
                    )}
                  </div>
                  <span className="text-xs text-gray-400">{caption.length}/2,200</span>
                </div>
              </div>

              {/* Location */}
              <div className="px-4 py-3 border-b border-gray-100 dark:border-gray-800">
                <input
                  type="text"
                  placeholder="Add location"
                  value={location}
                  onChange={(e) => setLocation(e.target.value)}
                  className="w-full text-sm bg-transparent outline-none dark:text-white placeholder-gray-400"
                />
              </div>

              

              {/* Ad-specific fields */}
              {postType === 'ad' && (
                <div className="px-4 pb-4 border-b border-gray-100 dark:border-gray-800 space-y-3 pt-4">

                  {/* Ad Content */}
                  <div className="text-[10px] font-bold text-gray-400 uppercase tracking-widest px-1 pb-1">Ad Content</div>

                  <input
                    type="text"
                    placeholder="Ad Title *"
                    value={adTitle}
                    onChange={(e) => setAdTitle(e.target.value)}
                    className="w-full p-3 rounded-xl border border-gray-200 dark:border-gray-700 bg-gray-50 dark:bg-gray-900 text-sm dark:text-white outline-none focus:ring-2 focus:ring-purple-500 transition-all"
                  />
                  <textarea
                    placeholder="Ad Description"
                    value={adDescription}
                    onChange={(e) => setAdDescription(e.target.value)}
                    rows={2}
                    className="w-full p-3 rounded-xl border border-gray-200 dark:border-gray-700 bg-gray-50 dark:bg-gray-900 text-sm dark:text-white outline-none focus:ring-2 focus:ring-purple-500 transition-all resize-none"
                  />

                  {/* Ad Type */}
                  <div>
                    <div className="text-xs font-semibold text-gray-500 dark:text-gray-400 mb-2 flex items-center gap-1.5"><Megaphone size={13} /> Ad Type</div>
                    <div className="grid grid-cols-2 gap-2">
                      {[
                        { value: 'sponsored_post', label: 'Sponsored Post' },
                        { value: 'banner',         label: 'Banner' },
                        { value: 'video',          label: 'Video' },
                        { value: 'carousel',       label: 'Carousel' },
                      ].map(t => (
                        <button key={t.value} onClick={() => setAdType(t.value)}
                          className={`py-2.5 px-3 rounded-xl text-xs font-bold border transition-all ${
                            adType === t.value
                              ? 'bg-purple-600 text-white border-purple-600'
                              : 'bg-gray-50 dark:bg-gray-900 text-gray-600 dark:text-gray-400 border-gray-200 dark:border-gray-700 hover:border-purple-400'
                          }`}>
                          {t.label}
                        </button>
                      ))}
                    </div>
                  </div>

                  {/* ── STEP 3: CTA ── */}
                  <div className="pt-2 text-[10px] font-bold text-gray-400 uppercase tracking-widest px-1 pb-1">Step 3 · Call-To-Action</div>

                  <div className="border border-gray-200 dark:border-gray-700 rounded-xl overflow-hidden">
                    <button
                      onClick={() => setOpenAccordion(openAccordion === 'cta' ? null : 'cta')}
                      className="w-full flex items-center justify-between p-3 bg-gray-50 dark:bg-gray-900 text-sm font-semibold dark:text-white"
                    >
                      <span className="flex items-center gap-2">
                        <MousePointerClick size={14} className="text-indigo-500" />
                        CTA {ctaType ? `· ${ctaType.replace('_', ' ')}` : ''}
                      </span>
                      <ChevronDown size={16} className={`transition-transform ${openAccordion === 'cta' ? 'rotate-180' : ''}`} />
                    </button>
                    {openAccordion === 'cta' && (
                      <div className="p-3 bg-white dark:bg-black space-y-3">
                        <div className="grid grid-cols-2 gap-2">
                          {[
                            { value: 'view_site',    label: 'View Site' },
                            { value: 'contact_info', label: 'Contact' },
                            { value: 'install_app',  label: 'Install App' },
                            { value: 'book_now',     label: 'Book Now' },
                            { value: 'learn_more',   label: 'Learn More' },
                            { value: 'call_now',     label: 'Call Now' },
                          ].map(c => (
                            <button key={c.value} onClick={() => setCtaType(c.value)}
                              className={`py-2 px-3 rounded-lg text-xs font-bold border transition-all ${
                                ctaType === c.value
                                  ? 'bg-indigo-600 text-white border-indigo-600'
                                  : 'bg-gray-50 dark:bg-gray-800 text-gray-600 dark:text-gray-400 border-gray-200 dark:border-gray-700'
                              }`}>
                              {c.label}
                            </button>
                          ))}
                        </div>
                        <input type="url" placeholder="Destination URL" value={ctaUrl} onChange={e => setCtaUrl(e.target.value)}
                          className="w-full p-2.5 rounded-lg border border-gray-200 dark:border-gray-700 bg-gray-50 dark:bg-gray-900 text-sm dark:text-white outline-none focus:ring-2 focus:ring-indigo-500" />
                        <input type="text" placeholder="Deep Link (e.g. myapp://product/123)" value={ctaDeepLink} onChange={e => setCtaDeepLink(e.target.value)}
                          className="w-full p-2.5 rounded-lg border border-gray-200 dark:border-gray-700 bg-gray-50 dark:bg-gray-900 text-sm dark:text-white outline-none focus:ring-2 focus:ring-indigo-500" />
                        <input type="tel" placeholder="Phone Number (for Call Now)" value={ctaPhone} onChange={e => setCtaPhone(e.target.value)}
                          className="w-full p-2.5 rounded-lg border border-gray-200 dark:border-gray-700 bg-gray-50 dark:bg-gray-900 text-sm dark:text-white outline-none focus:ring-2 focus:ring-indigo-500" />
                        <input type="text" placeholder="WhatsApp Number (e.g. 919876543210)" value={ctaWhatsapp} onChange={e => setCtaWhatsapp(e.target.value)}
                          className="w-full p-2.5 rounded-lg border border-gray-200 dark:border-gray-700 bg-gray-50 dark:bg-gray-900 text-sm dark:text-white outline-none focus:ring-2 focus:ring-indigo-500" />
                        <input type="email" placeholder="Contact Email" value={ctaEmail} onChange={e => setCtaEmail(e.target.value)}
                          className="w-full p-2.5 rounded-lg border border-gray-200 dark:border-gray-700 bg-gray-50 dark:bg-gray-900 text-sm dark:text-white outline-none focus:ring-2 focus:ring-indigo-500" />
                      </div>
                    )}
                  </div>

                  {/* ── STEP 4: Audience Targeting ── */}
                  <div className="pt-2 text-[10px] font-bold text-gray-400 uppercase tracking-widest px-1 pb-1">Step 4 · Audience Targeting</div>

                  {/* Category */}
                  <div className="border border-gray-200 dark:border-gray-700 rounded-xl overflow-hidden">
                    <button onClick={() => setOpenAccordion(openAccordion === 'category' ? null : 'category')}
                      className="w-full flex items-center justify-between p-3 bg-gray-50 dark:bg-gray-900 text-sm font-semibold dark:text-white">
                      <span className="flex items-center gap-2"><Tag size={14} className="text-orange-500" />Category {selectedCategory && `· ${selectedCategory}`}</span>
                      <ChevronDown size={16} className={`transition-transform ${openAccordion === 'category' ? 'rotate-180' : ''}`} />
                    </button>
                    {openAccordion === 'category' && (
                      <div className="max-h-52 overflow-y-auto p-2 bg-white dark:bg-black space-y-1">
                        {isLoadingCategories ? (
                          <div className="p-2 text-xs text-gray-500">Loading...</div>
                        ) : (
                          categories.map(cat => (
                            <label key={cat} className="flex items-center gap-2 p-2 hover:bg-gray-50 dark:hover:bg-gray-800 cursor-pointer rounded-lg">
                              <input type="radio" name="ad_category" checked={selectedCategory === cat} onChange={() => setSelectedCategory(cat)} className="accent-purple-600" />
                              <span className="text-sm dark:text-gray-200">{cat}</span>
                            </label>
                          ))
                        )}
                      </div>
                    )}
                  </div>

                  {/* Sub-category + Keywords */}
                  <input type="text" placeholder="Sub-category (optional, e.g. Women's Clothing)" value={subCategory} onChange={e => setSubCategory(e.target.value)}
                    className="w-full p-3 rounded-xl border border-gray-200 dark:border-gray-700 bg-gray-50 dark:bg-gray-900 text-sm dark:text-white outline-none focus:ring-2 focus:ring-purple-500" />

                  <div>
                    <div className="flex gap-2">
                      <input type="text" placeholder="Add keyword & press Enter" value={keywordInput} onChange={e => setKeywordInput(e.target.value)}
                        onKeyDown={e => { if (e.key === 'Enter' && keywordInput.trim()) { setKeywords(prev => [...prev, keywordInput.trim()]); setKeywordInput(''); e.preventDefault(); }}}
                        className="flex-1 p-3 rounded-xl border border-gray-200 dark:border-gray-700 bg-gray-50 dark:bg-gray-900 text-sm dark:text-white outline-none focus:ring-2 focus:ring-purple-500" />
                      <button onClick={() => { if (keywordInput.trim()) { setKeywords(prev => [...prev, keywordInput.trim()]); setKeywordInput(''); }}}
                        className="px-3 py-2 rounded-xl bg-purple-600 text-white text-sm font-bold hover:bg-purple-700 transition-colors">+</button>
                    </div>
                    {keywords.length > 0 && (
                      <div className="flex flex-wrap gap-1.5 mt-2">
                        {keywords.map((k, i) => (
                          <span key={i} className="inline-flex items-center gap-1 px-2.5 py-1 rounded-full bg-purple-100 dark:bg-purple-900/30 text-purple-700 dark:text-purple-300 text-xs font-semibold">
                            {k} <button onClick={() => setKeywords(prev => prev.filter((_, j) => j !== i))} className="hover:text-red-500 transition-colors">×</button>
                          </span>
                        ))}
                      </div>
                    )}
                  </div>

                  {/* Country */}
                  <div className="border border-gray-200 dark:border-gray-700 rounded-xl overflow-hidden">
                    <button onClick={() => setOpenAccordion(openAccordion === 'country' ? null : 'country')}
                      className="w-full flex items-center justify-between p-3 bg-gray-50 dark:bg-gray-900 text-sm font-semibold dark:text-white">
                      <span className="flex items-center gap-2"><Globe size={14} className="text-blue-500" />Countries {selectedCountries.length > 0 && `(${selectedCountries.length})`}</span>
                      <ChevronDown size={16} className={`transition-transform ${openAccordion === 'country' ? 'rotate-180' : ''}`} />
                    </button>
                    {openAccordion === 'country' && (
                      <div className="max-h-52 overflow-y-auto p-2 bg-white dark:bg-black">
                        {isLoadingCountries ? (
                          <div className="p-2 text-xs text-gray-500">Loading countries...</div>
                        ) : allCountries.length === 0 ? (
                          <div className="p-2 text-xs text-gray-400">No countries available</div>
                        ) : allCountries.map(c => {
                          const name = typeof c === 'string' ? c : (c.name || c.country);
                          return (
                            <label key={name} className="flex items-center gap-2 p-2 hover:bg-gray-50 dark:hover:bg-gray-800 cursor-pointer rounded-lg">
                              <input type="checkbox" checked={selectedCountries.includes(name)}
                                onChange={() => setSelectedCountries(prev => prev.includes(name) ? prev.filter(x => x !== name) : [...prev, name])}
                                className="accent-blue-600" />
                              <span className="text-sm dark:text-gray-200">{name}</span>
                            </label>
                          );
                        })}
                      </div>
                    )}
                  </div>

                  {/* State */}
                  {selectedCountries.length > 0 && (
                    <div className="border border-gray-200 dark:border-gray-700 rounded-xl overflow-hidden">
                      <button onClick={() => setOpenAccordion(openAccordion === 'state' ? null : 'state')}
                        className="w-full flex items-center justify-between p-3 bg-gray-50 dark:bg-gray-900 text-sm font-semibold dark:text-white">
                        <span className="flex items-center gap-2"><MapPin size={14} className="text-blue-400" />States / Regions {selectedStates.length > 0 && `(${selectedStates.length})`}</span>
                        <ChevronDown size={16} className={`transition-transform ${openAccordion === 'state' ? 'rotate-180' : ''}`} />
                      </button>
                      {openAccordion === 'state' && (
                        <div className="max-h-52 overflow-y-auto p-2 bg-white dark:bg-black">
                          {isLoadingStates ? <div className="p-2 text-xs text-gray-500">Loading states...</div> : (
                            selectedCountries.map(country => {
                              const states = statesByCountry[country] || [];
                              if (!states.length) return null;
                              return (
                                <div key={country}>
                                  <div className="px-2 pt-2 pb-1 text-xs font-bold text-gray-400 uppercase tracking-wide">{country}</div>
                                  {states.map(st => {
                                    const stateName = st.state || (typeof st === 'string' ? st : st.name);
                                    return (
                                      <label key={stateName} className="flex items-center gap-2 p-2 hover:bg-gray-50 dark:hover:bg-gray-800 cursor-pointer rounded-lg">
                                        <input type="checkbox" checked={selectedStates.includes(stateName)}
                                          onChange={() => setSelectedStates(prev => prev.includes(stateName) ? prev.filter(x => x !== stateName) : [...prev, stateName])}
                                          className="accent-blue-600" />
                                        <span className="text-sm dark:text-gray-200">{stateName}</span>
                                      </label>
                                    );
                                  })}
                                </div>
                              );
                            })
                          )}
                        </div>
                      )}
                    </div>
                  )}

                  {/* Cities */}
                  <div>
                    <div className="text-xs font-semibold text-gray-500 dark:text-gray-400 mb-2 flex items-center gap-1.5"><MapPin size={13} className="text-green-500" />Cities (optional)</div>
                    <div className="flex gap-2">
                      <input type="text" placeholder="Add city & press Enter" value={cityInput} onChange={e => setCityInput(e.target.value)}
                        onKeyDown={e => { if (e.key === 'Enter' && cityInput.trim()) { setSelectedCities(prev => [...prev, cityInput.trim()]); setCityInput(''); e.preventDefault(); }}}
                        className="flex-1 p-2.5 rounded-xl border border-gray-200 dark:border-gray-700 bg-gray-50 dark:bg-gray-900 text-sm dark:text-white outline-none focus:ring-2 focus:ring-green-500" />
                      <button onClick={() => { if (cityInput.trim()) { setSelectedCities(prev => [...prev, cityInput.trim()]); setCityInput(''); }}}
                        className="px-3 py-2 rounded-xl bg-green-600 text-white text-sm font-bold hover:bg-green-700 transition-colors">+</button>
                    </div>
                    {selectedCities.length > 0 && (
                      <div className="flex flex-wrap gap-1.5 mt-2">
                        {selectedCities.map((c, i) => (
                          <span key={i} className="inline-flex items-center gap-1 px-2.5 py-1 rounded-full bg-green-100 dark:bg-green-900/30 text-green-700 dark:text-green-300 text-xs font-semibold">
                            {c} <button onClick={() => setSelectedCities(prev => prev.filter((_, j) => j !== i))} className="hover:text-red-500">×</button>
                          </span>
                        ))}
                      </div>
                    )}
                  </div>

                  {/* Age + Gender */}
                  <div className="grid grid-cols-2 gap-3">
                    <div>
                      <div className="text-xs font-semibold text-gray-500 dark:text-gray-400 mb-2">Age Range</div>
                      <div className="flex gap-2">
                        <input type="number" placeholder="Min" value={ageMin} onChange={e => setAgeMin(e.target.value)} min={13} max={99}
                          className="w-full p-2.5 rounded-xl border border-gray-200 dark:border-gray-700 bg-gray-50 dark:bg-gray-900 text-sm dark:text-white outline-none focus:ring-2 focus:ring-indigo-500" />
                        <input type="number" placeholder="Max" value={ageMax} onChange={e => setAgeMax(e.target.value)} min={13} max={100}
                          className="w-full p-2.5 rounded-xl border border-gray-200 dark:border-gray-700 bg-gray-50 dark:bg-gray-900 text-sm dark:text-white outline-none focus:ring-2 focus:ring-indigo-500" />
                      </div>
                    </div>
                    <div>
                      <div className="text-xs font-semibold text-gray-500 dark:text-gray-400 mb-2">Gender</div>
                      <div className="flex flex-col gap-1.5">
                        {['all', 'male', 'female', 'other'].map(g => (
                          <label key={g} className="flex items-center gap-2 cursor-pointer">
                            <input type="radio" name="gender_target" value={g} checked={genderTarget === g} onChange={() => setGenderTarget(g)} className="accent-pink-600" />
                            <span className="text-xs dark:text-gray-300 capitalize">{g}</span>
                          </label>
                        ))}
                      </div>
                    </div>
                  </div>

                  {/* Interests */}
                  <div>
                    <div className="text-xs font-semibold text-gray-500 dark:text-gray-400 mb-2 flex items-center gap-1.5"><Zap size={13} className="text-yellow-500" />Interests</div>
                    <div className="flex gap-2">
                      <input type="text" placeholder="Add interest & press Enter" value={interestInput} onChange={e => setInterestInput(e.target.value)}
                        onKeyDown={e => { if (e.key === 'Enter' && interestInput.trim()) { setSelectedInterests(prev => [...prev, interestInput.trim()]); setInterestInput(''); e.preventDefault(); }}}
                        className="flex-1 p-2.5 rounded-xl border border-gray-200 dark:border-gray-700 bg-gray-50 dark:bg-gray-900 text-sm dark:text-white outline-none focus:ring-2 focus:ring-yellow-500" />
                      <button onClick={() => { if (interestInput.trim()) { setSelectedInterests(prev => [...prev, interestInput.trim()]); setInterestInput(''); }}}
                        className="px-3 py-2 rounded-xl bg-yellow-500 text-white text-sm font-bold hover:bg-yellow-600 transition-colors">+</button>
                    </div>
                    {selectedInterests.length > 0 && (
                      <div className="flex flex-wrap gap-1.5 mt-2">
                        {selectedInterests.map((item, i) => (
                          <span key={i} className="inline-flex items-center gap-1 px-2.5 py-1 rounded-full bg-yellow-100 dark:bg-yellow-900/30 text-yellow-700 dark:text-yellow-300 text-xs font-semibold">
                            {item} <button onClick={() => setSelectedInterests(prev => prev.filter((_, j) => j !== i))} className="hover:text-red-500">×</button>
                          </span>
                        ))}
                      </div>
                    )}
                  </div>

                  {/* Device Types */}
                  <div>
                    <div className="text-xs font-semibold text-gray-500 dark:text-gray-400 mb-2 flex items-center gap-1.5"><Smartphone size={13} className="text-indigo-500" />Device Types</div>
                    <div className="flex flex-wrap gap-2">
                      {['mobile', 'ios', 'android', 'desktop'].map(d => (
                        <button key={d} onClick={() => setSelectedDeviceTypes(prev => prev.includes(d) ? prev.filter(x => x !== d) : [...prev, d])}
                          className={`flex items-center gap-1.5 px-3 py-2 rounded-xl text-xs font-bold border transition-all ${
                            selectedDeviceTypes.includes(d)
                              ? 'bg-indigo-600 text-white border-indigo-600'
                              : 'bg-gray-50 dark:bg-gray-900 text-gray-600 dark:text-gray-400 border-gray-200 dark:border-gray-700'
                          }`}>
                          {d === 'desktop' ? <Monitor size={12} /> : <Smartphone size={12} />}
                          {d}
                        </button>
                      ))}
                    </div>
                  </div>

                  {/* Language */}
                  {selectedStates.length > 0 && (
                    <div className="border border-gray-200 dark:border-gray-700 rounded-xl overflow-hidden">
                      <button onClick={() => setOpenAccordion(openAccordion === 'language' ? null : 'language')}
                        className="w-full flex items-center justify-between p-3 bg-gray-50 dark:bg-gray-900 text-sm font-semibold dark:text-white">
                        <span className="flex items-center gap-2"><Globe size={14} className="text-purple-500" />Languages {selectedLanguages.length > 0 && `(${selectedLanguages.length})`}</span>
                        <ChevronDown size={16} className={`transition-transform ${openAccordion === 'language' ? 'rotate-180' : ''}`} />
                      </button>
                      {openAccordion === 'language' && (
                        <div className="max-h-52 overflow-y-auto p-2 bg-white dark:bg-black">
                          {isLoadingLanguages ? <div className="p-2 text-xs text-gray-500">Loading languages...</div>
                          : Object.keys(languagesByState).length === 0 ? <div className="p-2 text-xs text-gray-400">No languages found for selected states</div>
                          : selectedCountries.map(country => {
                              const langs = languagesByState[country] || [];
                              if (!langs.length) return null;
                              return (
                                <div key={country}>
                                  <div className="px-2 pt-2 pb-1 text-xs font-bold text-gray-400 uppercase tracking-wide">{country}</div>
                                  {langs.map(langName => (
                                    <label key={langName} className="flex items-center gap-2 p-2 hover:bg-gray-50 dark:hover:bg-gray-800 cursor-pointer rounded-lg">
                                      <input type="checkbox" checked={selectedLanguages.includes(langName)}
                                        onChange={() => setSelectedLanguages(prev => prev.includes(langName) ? prev.filter(x => x !== langName) : [...prev, langName])}
                                        className="accent-purple-600" />
                                      <span className="text-sm dark:text-gray-200">{langName}</span>
                                    </label>
                                  ))}
                                </div>
                              );
                            })
                          }
                        </div>
                      )}
                    </div>
                  )}

                  {/* ── STEP 5: Budget & Duration ── */}
                  <div className="pt-2 text-[10px] font-bold text-gray-400 uppercase tracking-widest px-1 pb-1">Step 5 · Budget & Duration</div>

                  <div className="border border-gray-200 dark:border-gray-700 rounded-xl overflow-hidden">
                    <button onClick={() => setOpenAccordion(openAccordion === 'budget' ? null : 'budget')}
                      className="w-full flex items-center justify-between p-3 bg-gray-50 dark:bg-gray-900 text-sm font-semibold dark:text-white">
                      <span className="flex items-center gap-2"><Coins size={14} className="text-amber-500" />Budget {totalBudgetCoins && `· ${totalBudgetCoins} 🪙`}</span>
                      <ChevronDown size={16} className={`transition-transform ${openAccordion === 'budget' ? 'rotate-180' : ''}`} />
                    </button>
                    {openAccordion === 'budget' && (
                      <div className="p-3 bg-white dark:bg-black space-y-3">
                        <div>
                          <label className="text-xs font-semibold text-gray-500 dark:text-gray-400 mb-1 block">Total Budget (Coins) *</label>
                          <input type="number" value={totalBudgetCoins} onChange={e => setTotalBudgetCoins(e.target.value)} placeholder="e.g. 5000 (min 100)"
                            className="w-full p-2.5 rounded-lg border border-gray-200 dark:border-gray-700 bg-gray-50 dark:bg-gray-900 text-sm dark:text-white outline-none focus:ring-2 focus:ring-amber-500" />
                        </div>
                        <div>
                          <label className="text-xs font-semibold text-gray-500 dark:text-gray-400 mb-1 block">Daily Budget Limit (Coins)</label>
                          <input type="number" value={dailyBudgetCoins} onChange={e => setDailyBudgetCoins(e.target.value)} placeholder="e.g. 500 (0 = no limit)"
                            className="w-full p-2.5 rounded-lg border border-gray-200 dark:border-gray-700 bg-gray-50 dark:bg-gray-900 text-sm dark:text-white outline-none focus:ring-2 focus:ring-amber-500" />
                        </div>
                        <div className="grid grid-cols-2 gap-3">
                          <div>
                            <label className="text-xs font-semibold text-gray-500 dark:text-gray-400 mb-1 block">Start Date</label>
                            <input type="date" value={budgetStartDate} onChange={e => setBudgetStartDate(e.target.value)}
                              className="w-full p-2.5 rounded-lg border border-gray-200 dark:border-gray-700 bg-gray-50 dark:bg-gray-900 text-sm dark:text-white outline-none focus:ring-2 focus:ring-amber-500" />
                          </div>
                          <div>
                            <label className="text-xs font-semibold text-gray-500 dark:text-gray-400 mb-1 block">End Date</label>
                            <input type="date" value={budgetEndDate} onChange={e => setBudgetEndDate(e.target.value)}
                              className="w-full p-2.5 rounded-lg border border-gray-200 dark:border-gray-700 bg-gray-50 dark:bg-gray-900 text-sm dark:text-white outline-none focus:ring-2 focus:ring-amber-500" />
                          </div>
                        </div>
                        <p className="text-xs text-gray-400">Minimum 100 coins required. Budget is deducted from your wallet on creation.</p>
                      </div>
                    )}
                  </div>

                  {/* Tracking / UTM */}
                  <div className="border border-gray-200 dark:border-gray-700 rounded-xl overflow-hidden">
                    <button onClick={() => setOpenAccordion(openAccordion === 'tracking' ? null : 'tracking')}
                      className="w-full flex items-center justify-between p-3 bg-gray-50 dark:bg-gray-900 text-sm font-semibold dark:text-white">
                      <span className="flex items-center gap-2"><Target size={14} className="text-teal-500" />Tracking & UTM (optional)</span>
                      <ChevronDown size={16} className={`transition-transform ${openAccordion === 'tracking' ? 'rotate-180' : ''}`} />
                    </button>
                    {openAccordion === 'tracking' && (
                      <div className="p-3 bg-white dark:bg-black space-y-2.5">
                        {[
                          { label: 'UTM Source', value: utmSource, setter: setUtmSource, placeholder: 'e.g. myapp' },
                          { label: 'UTM Medium', value: utmMedium, setter: setUtmMedium, placeholder: 'e.g. paid_ad' },
                          { label: 'UTM Campaign', value: utmCampaign, setter: setUtmCampaign, placeholder: 'e.g. summer_sale_2025' },
                          { label: 'UTM Term', value: utmTerm, setter: setUtmTerm, placeholder: 'e.g. fashion' },
                          { label: 'UTM Content', value: utmContent, setter: setUtmContent, placeholder: 'e.g. banner_v1' },
                          { label: 'Conversion Pixel ID', value: conversionPixelId, setter: setConversionPixelId, placeholder: 'e.g. px_abc123' },
                        ].map(field => (
                          <div key={field.label}>
                            <label className="text-xs font-semibold text-gray-400 mb-1 block">{field.label}</label>
                            <input type="text" value={field.value} onChange={e => field.setter(e.target.value)} placeholder={field.placeholder}
                              className="w-full p-2.5 rounded-lg border border-gray-200 dark:border-gray-700 bg-gray-50 dark:bg-gray-900 text-sm dark:text-white outline-none focus:ring-2 focus:ring-teal-500" />
                          </div>
                        ))}
                      </div>
                    )}
                  </div>

                  {/* ── STEP 6: Review & Submit ── */}
                  <div className="pt-2 text-[10px] font-bold text-gray-400 uppercase tracking-widest px-1 pb-1">Step 6 · Review & Submit</div>

                  {/* Policy Agreement — REQUIRED */}
                  <div className={`flex items-start gap-3 p-4 rounded-xl border-2 transition-colors cursor-pointer ${
                    policyAgreed
                      ? 'bg-green-50 dark:bg-green-900/20 border-green-400 dark:border-green-700'
                      : 'bg-red-50/50 dark:bg-red-900/10 border-red-200 dark:border-red-900/50'
                  }`} onClick={() => setPolicyAgreed(!policyAgreed)}>
                    <div className={`w-5 h-5 rounded flex-shrink-0 border-2 flex items-center justify-center transition-all mt-0.5 ${
                      policyAgreed ? 'bg-green-500 border-green-500' : 'border-gray-400 dark:border-gray-600'
                    }`}>
                      {policyAgreed && <span className="text-white text-xs font-bold">✓</span>}
                    </div>
                    <div>
                      <p className="text-sm font-semibold text-gray-800 dark:text-gray-200">
                        I agree to the Ad Content Policy <span className="text-red-500">*</span>
                      </p>
                      <p className="text-xs text-gray-500 dark:text-gray-400 mt-0.5 leading-relaxed">
                        By submitting this ad I confirm the content complies with platform guidelines and applicable laws. <strong>Required to publish.</strong>
                      </p>
                    </div>
                  </div>

                  {/* Review Summary */}
                  {(adTitle || selectedCategory || totalBudgetCoins) && (
                    <div className="p-4 rounded-xl bg-gray-50 dark:bg-gray-800/50 border border-gray-200 dark:border-gray-700 space-y-2">
                      <div className="text-xs font-bold text-gray-500 uppercase tracking-wider mb-2">Review Summary</div>
                      {adTitle && <div className="flex justify-between text-sm"><span className="text-gray-500">Title</span><span className="font-semibold dark:text-white truncate max-w-[180px]">{adTitle}</span></div>}
                      {selectedCategory && <div className="flex justify-between text-sm"><span className="text-gray-500">Category</span><span className="font-semibold dark:text-white">{selectedCategory}</span></div>}
                      {ctaType && <div className="flex justify-between text-sm"><span className="text-gray-500">CTA</span><span className="font-semibold dark:text-white capitalize">{ctaType.replace('_', ' ')}</span></div>}
                      {totalBudgetCoins && <div className="flex justify-between text-sm"><span className="text-gray-500">Total Budget</span><span className="font-bold text-amber-600">{totalBudgetCoins} 🪙</span></div>}
                      {dailyBudgetCoins && <div className="flex justify-between text-sm"><span className="text-gray-500">Daily Budget</span><span className="font-bold text-amber-500">{dailyBudgetCoins} 🪙/day</span></div>}
                      {selectedCountries.length > 0 && <div className="flex justify-between text-sm"><span className="text-gray-500">Countries</span><span className="font-semibold dark:text-white">{selectedCountries.length} selected</span></div>}
                      {(ageMin || ageMax) && <div className="flex justify-between text-sm"><span className="text-gray-500">Age</span><span className="font-semibold dark:text-white">{ageMin || 13}–{ageMax || 65}</span></div>}
                      {genderTarget !== 'all' && <div className="flex justify-between text-sm"><span className="text-gray-500">Gender</span><span className="font-semibold dark:text-white capitalize">{genderTarget}</span></div>}
                      <div className="flex justify-between text-sm pt-1 border-t border-gray-200 dark:border-gray-700">
                        <span className="text-gray-500">Policy Agreed</span>
                        <span className={`font-bold ${policyAgreed ? 'text-green-600' : 'text-red-500'}`}>{policyAgreed ? '✓ Yes' : '✗ Required'}</span>
                      </div>
                    </div>
                  )}
                </div>
              )}

              {/* Tag Section */}
              <div className="flex flex-col">
                <div className="flex items-center justify-between px-4 py-3 border-b border-gray-100 dark:border-gray-800 cursor-pointer hover:bg-gray-50 dark:hover:bg-gray-900" onClick={() => { setShowTagSearch(true); setSearchQuery(''); fetchUsers(''); }}>
                  <span className="text-sm text-gray-700 dark:text-gray-300">Add Tag</span>
                  <UserPlus size={20} className="text-gray-800 dark:text-gray-200" />
                </div>
                {allUsers.length > 0 && (
                  <div className="px-4 py-2 max-h-40 overflow-y-auto flex flex-col gap-2 pr-2" style={{ scrollbarWidth: 'none', msOverflowStyle: 'none' }}>
                    {isLoadingAllUsers ? (
                      <div className="text-xs text-gray-500 dark:text-gray-400">Loading users...</div>
                    ) : allUsers.map(u => (
                      <div key={u.id} className="flex items-center gap-3 cursor-pointer hover:bg-gray-50 dark:hover:bg-gray-900 rounded-md px-2 py-1" onClick={() => handleTagUser(u)}>
                        <div className="w-8 h-8 bg-gray-200 dark:bg-gray-600 rounded-full overflow-hidden flex-shrink-0 flex items-center justify-center">
                          {u.avatar_url ? <img src={u.avatar_url} className="w-full h-full object-cover" alt={u.username} /> : <span className="text-xs font-semibold text-gray-800 dark:text-white">{(u.username || '').slice(0, 1).toUpperCase()}</span>}
                        </div>
                        <div className="flex flex-col overflow-hidden">
                          <span className="text-sm font-semibold truncate dark:text-white">{u.username}</span>
                          <span className="text-xs text-gray-500 dark:text-gray-400 truncate">{u.full_name}</span>
                        </div>
                      </div>
                    ))}
                  </div>
                )}

                {/* Advanced Settings */}
                <div className="border-b border-gray-100 dark:border-gray-800">
                  <div className="flex items-center justify-between px-4 py-3 cursor-pointer hover:bg-gray-50 dark:hover:bg-gray-900" onClick={() => setIsAdvancedSettingsOpen(!isAdvancedSettingsOpen)}>
                    <span className="text-sm text-gray-800 dark:text-gray-200 font-medium">Advanced Settings</span>
                    {isAdvancedSettingsOpen ? <ChevronUp size={20} className="text-gray-600 dark:text-gray-400" /> : <ChevronDown size={20} className="text-gray-600 dark:text-gray-400" />}
                  </div>
                  {isAdvancedSettingsOpen && (
                    <div className="px-4 pb-4 flex flex-col gap-4">
                      <div className="flex flex-col gap-2">
                        <div className="flex items-center justify-between">
                          <span className="text-sm text-gray-800 dark:text-gray-200">Hide like and view counts on this post</span>
                          <div className="relative inline-flex items-center cursor-pointer" onClick={() => setHideLikes(!hideLikes)}>
                            <input type="checkbox" className="sr-only peer" checked={hideLikes} readOnly />
                            <div className="w-11 h-6 bg-gray-200 dark:bg-gray-600 peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-blue-600"></div>
                          </div>
                        </div>
                        <p className="text-xs text-gray-500 dark:text-gray-400">Only you will see the total number of likes and views on this post. <span className="text-blue-500 cursor-pointer">Learn more</span></p>
                      </div>
                      <div className="flex flex-col gap-2">
                        <div className="flex items-center justify-between">
                          <span className="text-sm text-gray-800 dark:text-gray-200">Turn off commenting</span>
                          <div className="relative inline-flex items-center cursor-pointer" onClick={() => setTurnOffCommenting(!turnOffCommenting)}>
                            <input type="checkbox" className="sr-only peer" checked={turnOffCommenting} readOnly />
                            <div className="w-11 h-6 bg-gray-200 dark:bg-gray-600 peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-blue-600"></div>
                          </div>
                        </div>
                        <p className="text-xs text-gray-500 dark:text-gray-400">You can change this later by going to the ... menu at the top of your post.</p>
                      </div>
                      <div className="border border-gray-200 dark:border-gray-700 rounded-xl overflow-hidden">
                        <button onClick={() => setOpenAccordion(openAccordion === 'engagement' ? null : 'engagement')}
                          className="w-full flex items-center justify-between p-3 bg-gray-50 dark:bg-gray-900 text-sm font-semibold dark:text-white">
                          <span>Engagement Controls</span>
                          <ChevronDown size={16} className={`transition-transform ${openAccordion === 'engagement' ? 'rotate-180' : ''}`} />
                        </button>
                        {openAccordion === 'engagement' && (
                          <div className="p-3 bg-white dark:bg-black space-y-3">
                            {[
                              { label: 'Hide likes count',   value: hideLikes,          setter: setHideLikes },
                              { label: 'Disable comments',   value: turnOffCommenting,  setter: setTurnOffCommenting },
                              { label: 'Disable share',      value: disableShare,       setter: setDisableShare },
                              { label: 'Disable save',       value: disableSave,        setter: setDisableSave },
                              { label: 'Disable report',     value: disableReport,      setter: setDisableReport },
                              { label: 'Moderation mode',    value: moderationEnabled,  setter: setModerationEnabled },
                            ].map(ctrl => (
                              <div key={ctrl.label} className="flex items-center justify-between">
                                <span className="text-sm text-gray-700 dark:text-gray-300">{ctrl.label}</span>
                                <div className="relative inline-flex items-center cursor-pointer" onClick={() => ctrl.setter(!ctrl.value)}>
                                  <input type="checkbox" className="sr-only peer" checked={ctrl.value} readOnly />
                                  <div className="w-10 h-5 bg-gray-200 dark:bg-gray-600 peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border after:rounded-full after:h-4 after:w-4 after:transition-all peer-checked:bg-purple-600"></div>
                                </div>
                              </div>
                            ))}
                          </div>
                        )}
                      </div>
                    </div>
                  )}
                </div>
              </div>
            </div>
          </div>
        )}
      </div>

      <input
        type="file" ref={fileInputRef} className="hidden" multiple
        accept={postType === 'post' ? 'image/*' : postType === 'reel' ? 'video/*' : 'image/*,video/*'}
        onChange={handleFileSelect}
      />

      {showVendorNotValidated && (
        <div className="fixed inset-0 z-[70] flex items-center justify-center bg-black/50 backdrop-blur-sm p-4 md:hidden">
          <div className="bg-white dark:bg-gray-900 rounded-xl p-6 w-full max-w-sm shadow-2xl border border-gray-100 dark:border-gray-800">
            <h3 className="text-lg font-bold text-gray-900 dark:text-white mb-2 text-center">Vendor verification pending</h3>
            <p className="text-gray-500 dark:text-gray-400 text-sm mb-6 text-center">Your vendor account is not yet validated. Please wait for approval before uploading ads.</p>
            <div className="flex justify-center">
              <button onClick={() => setShowVendorNotValidated(false)} className="px-4 py-2.5 rounded-lg bg-insta-pink text-white font-medium hover:bg-insta-purple transition-colors">OK</button>
            </div>
          </div>
        </div>
      )}

      {showAdProfileGate && (
        <div className="fixed inset-0 z-[70] flex items-center justify-center bg-black/50 backdrop-blur-sm p-4">
          <div className="bg-white dark:bg-gray-900 rounded-2xl p-6 w-full max-w-sm shadow-2xl border border-gray-100 dark:border-gray-800">
            <div className="w-14 h-14 rounded-2xl bg-orange-50 dark:bg-orange-900/20 mx-auto flex items-center justify-center mb-4">
              <Megaphone size={26} className="text-orange-500" />
            </div>
            <h3 className="text-lg font-bold text-gray-900 dark:text-white mb-2 text-center">Complete your profile first</h3>
            <p className="text-gray-500 dark:text-gray-400 text-sm mb-6 text-center leading-relaxed">
              Your profile completion is currently <span className="font-bold text-orange-500">{Math.round(Number(vendorProfileCompletion || 0))}%</span>.
              You need to complete it above <span className="font-bold text-pink-600">80%</span> before uploading ads.
            </p>
            <div className="flex justify-center">
              <button
                onClick={() => setShowAdProfileGate(false)}
                className="px-5 py-2.5 rounded-lg bg-gradient-to-r from-orange-500 to-pink-600 text-white font-medium hover:opacity-90 transition-opacity"
              >
                OK
              </button>
            </div>
          </div>
        </div>
      )}

      {showAdLimitPopup && (
        <div className="fixed inset-0 z-[70] flex items-center justify-center bg-black/50 backdrop-blur-sm p-4">
          <div className="bg-white dark:bg-gray-900 rounded-2xl p-6 w-full max-w-sm shadow-2xl border border-gray-100 dark:border-gray-800">
            <div className="w-14 h-14 rounded-2xl bg-pink-50 dark:bg-pink-900/20 mx-auto flex items-center justify-center mb-4">
              <Megaphone size={26} className="text-pink-500" />
            </div>
            <h3 className="text-lg font-bold text-gray-900 dark:text-white mb-2 text-center">Upgrade your package</h3>
            <p className="text-gray-500 dark:text-gray-400 text-sm mb-6 text-center leading-relaxed">
              Your current package allows <span className="font-bold text-pink-600">{activePackageAdsLimit}</span> ads, and you have already uploaded <span className="font-bold text-orange-500">{uploadedAdsCount}</span>.
              Upgrade your package to create more ads.
            </p>
            <div className="flex justify-center">
              <button
                onClick={() => setShowAdLimitPopup(false)}
                className="px-5 py-2.5 rounded-lg bg-gradient-to-r from-orange-500 to-pink-600 text-white font-medium hover:opacity-90 transition-opacity"
              >
                OK
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Upload Progress Overlay */}
      {isSubmitting && uploadStage !== 'idle' && (
        <div className="fixed inset-0 z-[90] flex items-center justify-center p-4" style={{ background: 'rgba(0,0,0,0.82)', backdropFilter: 'blur(12px)' }}>
          <div className="rounded-3xl p-8 w-full max-w-xs flex flex-col items-center gap-5" style={{ background: 'linear-gradient(145deg,#1a1a1a,#0d0d0d)', border: '1px solid rgba(255,255,255,0.07)', boxShadow: '0 32px 80px rgba(0,0,0,0.6)' }}>
            <div className="relative flex items-center justify-center w-24 h-24">
              <svg className="absolute inset-0 w-24 h-24" style={{ transform: 'rotate(-90deg)' }} viewBox="0 0 96 96">
                <circle cx="48" cy="48" r="42" fill="none" stroke="rgba(255,255,255,0.07)" strokeWidth="5" />
                <circle cx="48" cy="48" r="42" fill="none" stroke="url(#iGrad)" strokeWidth="5" strokeLinecap="round"
                  strokeDasharray={`${2 * Math.PI * 42}`}
                  strokeDashoffset={`${2 * Math.PI * 42 * (1 - uploadProgress / 100)}`}
                  style={{ transition: 'stroke-dashoffset 0.5s cubic-bezier(0.4,0,0.2,1)' }}
                />
                <defs>
                  <linearGradient id="iGrad" x1="0%" y1="0%" x2="100%" y2="100%">
                    <stop offset="0%"   stopColor="#feda75" />
                    <stop offset="25%"  stopColor="#fa7e1e" />
                    <stop offset="50%"  stopColor="#d62976" />
                    <stop offset="75%"  stopColor="#962fbf" />
                    <stop offset="100%" stopColor="#4f5bd5" />
                  </linearGradient>
                </defs>
              </svg>
              <span className="relative z-10 text-2xl font-bold text-white tabular-nums">{uploadProgress}%</span>
            </div>
            <div className="flex flex-col items-center gap-1 text-center">
              <p className="text-base font-semibold text-white">
                {uploadStage === 'converting' && '✂️ Trimming video…'}
                {uploadStage === 'uploading'  && '⬆️ Uploading…'}
                {uploadStage === 'posting'    && (postType === 'ad' && adSubmitMode === 'draft' ? '💾 Saving draft…' : '🚀 Publishing…')}
              </p>
              <p className="text-xs text-white/40">
                {uploadStage === 'converting' && 'Applying your trim & crop'}
                {uploadStage === 'uploading'  && 'Sending to server'}
                {uploadStage === 'posting'    && (postType === 'ad' && adSubmitMode === 'draft' ? 'Saving your draft' : 'Almost done!')}
              </p>
            </div>
            <div className="w-full h-1.5 rounded-full overflow-hidden" style={{ background: 'rgba(255,255,255,0.08)' }}>
              <div className="h-full rounded-full transition-all duration-500" style={{ width: `${uploadProgress}%`, background: 'linear-gradient(90deg,#feda75,#fa7e1e,#d62976,#962fbf,#4f5bd5)' }} />
            </div>
          </div>
        </div>
      )}

      {/* Success Popup */}
      {showSuccess && (() => {
        const doClose = () => {
          setShowSuccess(false);
          setUploadStage('idle');
          setUploadProgress(0);
          handleClose();
          setMedia([]);
          setCaption('');
          setLocation('');
          setTags([]);
          navigate(postType === 'ad' ? '/vendor/ads-management' : '/');
        };
        return (
          <div className="fixed inset-0 z-[90] flex items-center justify-center p-4" style={{ background: 'rgba(0,0,0,0.85)', backdropFilter: 'blur(16px)' }}>
            <style>{`
              @keyframes igPopIn { from { opacity:0; transform:scale(0.8) translateY(16px); } to { opacity:1; transform:scale(1) translateY(0); } }
              @keyframes igCheckDraw { from { stroke-dashoffset: 48; } to { stroke-dashoffset: 0; } }
              @keyframes igRingRotate { from { transform: rotate(0deg); } to { transform: rotate(360deg); } }
            `}</style>
            <div
              className="w-full max-w-xs flex flex-col items-center gap-6 rounded-3xl p-8"
              style={{ animation: 'igPopIn 0.4s cubic-bezier(0.34,1.56,0.64,1) both', background: 'linear-gradient(145deg,#1c1c1c,#111)', border: '1px solid rgba(255,255,255,0.08)', boxShadow: '0 40px 100px rgba(0,0,0,0.7)' }}
            >
              <div className="relative flex items-center justify-center w-24 h-24">
                <svg className="absolute inset-0 w-24 h-24" style={{ animation: 'igRingRotate 3s linear infinite' }} viewBox="0 0 96 96">
                  <defs>
                    <linearGradient id="igSuccessGrad" x1="0%" y1="0%" x2="100%" y2="100%">
                      <stop offset="0%"   stopColor="#feda75" />
                      <stop offset="25%"  stopColor="#fa7e1e" />
                      <stop offset="50%"  stopColor="#d62976" />
                      <stop offset="75%"  stopColor="#962fbf" />
                      <stop offset="100%" stopColor="#4f5bd5" />
                    </linearGradient>
                  </defs>
                  <circle cx="48" cy="48" r="44" fill="none" stroke="url(#igSuccessGrad)" strokeWidth="4" strokeDasharray="138 138" strokeLinecap="round" />
                </svg>
                <div className="w-16 h-16 rounded-full flex items-center justify-center" style={{ background: 'linear-gradient(135deg,#feda75,#fa7e1e,#d62976,#962fbf,#4f5bd5)' }}>
                  <svg className="w-8 h-8" viewBox="0 0 32 32" fill="none">
                    <path d="M7 17l6 6 12-12" stroke="white" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round"
                      strokeDasharray="48" strokeDashoffset="0" style={{ animation: 'igCheckDraw 0.5s 0.15s ease both' }} />
                  </svg>
                </div>
              </div>
              <div className="flex flex-col items-center gap-1.5 text-center">
                <h3 className="text-xl font-bold text-white">
                  {postType === 'reel'
                    ? 'Reel Published! 🎉'
                    : postType === 'ad'
                    ? adSubmitMode === 'draft'
                      ? 'Ad Saved as Draft'
                      : 'Ad Published! 🎉'
                    : 'Post Shared! 🎉'}
                </h3>
                <p className="text-sm text-white/50">
                  {postType === 'reel'
                    ? 'Your reel is now live'
                    : postType === 'ad'
                    ? adSubmitMode === 'draft'
                      ? 'Your ad has been saved and can be published later'
                      : 'Your ad is now submitted for review'
                    : 'Your post has been shared'}
                </p>
              </div>
              <div className="w-full h-px" style={{ background: 'linear-gradient(90deg,transparent,#d62976,transparent)' }} />
              <SuccessCountdown onDone={doClose} />
            </div>
          </div>
        );
      })()}

      {/* Error Popup */}
      {uploadStage === 'error' && !isSubmitting && (
        <div className="fixed inset-0 z-[90] flex items-center justify-center bg-black/60 backdrop-blur-sm p-4">
          <div className="bg-white dark:bg-[#1a1a1a] rounded-2xl p-8 w-full max-w-sm shadow-2xl border border-red-100 dark:border-red-900/40 flex flex-col items-center gap-5">
            <div className="w-20 h-20 rounded-full flex items-center justify-center bg-red-50 dark:bg-red-900/20 border-2 border-red-200 dark:border-red-800">
              <svg className="w-9 h-9 text-red-500" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126zM12 15.75h.007v.008H12v-.008z" />
              </svg>
            </div>
            <div className="flex flex-col items-center gap-1 text-center">
              <h3 className="text-lg font-bold text-gray-900 dark:text-white">Upload Failed</h3>
              <p className="text-sm text-gray-500 dark:text-gray-400">{uploadError || 'Something went wrong. Please try again.'}</p>
            </div>
            <div className="flex gap-3 w-full">
              <button onClick={() => { setUploadStage('idle'); setUploadProgress(0); setUploadError(''); }} className="flex-1 py-3 rounded-xl border border-gray-200 dark:border-gray-700 text-gray-700 dark:text-gray-300 font-semibold text-sm hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors">Cancel</button>
              <button onClick={() => { setUploadStage('idle'); setUploadProgress(0); setUploadError(''); handleNextStep(adSubmitMode); }} className="flex-1 py-3 rounded-xl text-white font-semibold text-sm transition-all active:scale-95" style={{ background: 'linear-gradient(135deg, #f472b6, #a855f7)' }}>Try Again</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default CreatePostModal;
