import React, { useEffect, useMemo, useState } from 'react';
import { Link, useSearchParams } from 'react-router-dom';
import { useSelector } from 'react-redux';
import { LayoutGrid, Briefcase, Package, Heart, Star, Clock, MapPin, Globe, MessageCircle, UserPlus, Check, BadgeCheck, ShoppingCart, ChevronRight, Search, UserRound, Loader2, Save } from 'lucide-react';
import { Dropdown, inputCls } from '../../components/productForm/ProductFormFields';
import { CATEGORY_STYLE } from '../../data/marketplaceCategoryStyle';
import { servicePrice } from '../data/serviceFields';
import useMarketplaceWishlist from '../../hooks/useMarketplaceWishlist';
import storeProfileService from '../../services/storeProfileService';
import influencerProductService from '../../services/influencerProductService';
import influencerServiceService from '../../services/influencerServiceService';

const panel = 'bg-white dark:bg-gray-900 border border-gray-100 dark:border-gray-800 rounded-2xl shadow-sm';
const primary = 'bg-gradient-to-r from-insta-purple via-insta-pink to-insta-orange text-white rounded-lg font-semibold';

const textToList = (value) => String(value || '').split(',').map((item) => item.trim()).filter(Boolean);
const listToText = (value) => (Array.isArray(value) ? value.join(', ') : '');

const Skeleton = ({ className = '' }) => <div className={`animate-pulse bg-gray-200 dark:bg-gray-800 rounded ${className}`} />;

function ProfileHeaderSkeleton() {
  return (
    <section aria-label="Loading store profile" className={`${panel} p-4 min-[900px]:p-5 min-[900px]:min-h-[156px] grid grid-cols-[96px_minmax(0,1fr)] min-[900px]:grid-cols-[112px_minmax(0,1fr)] items-center gap-x-5 gap-y-3`}>
      <Skeleton className="w-24 h-24 min-[900px]:w-28 min-[900px]:h-28 rounded-full col-start-1 row-start-1 min-[900px]:row-span-2" />
      <div className="col-start-2 min-w-0 space-y-3">
        <Skeleton className="h-6 w-2/3 max-w-[240px]" />
        <Skeleton className="h-3 w-1/3 max-w-[140px]" />
        <div className="flex flex-wrap gap-3 pt-1">
          <Skeleton className="h-3 w-20" />
          <Skeleton className="h-3 w-16" />
          <Skeleton className="h-3 w-16" />
          <Skeleton className="h-3 w-20" />
        </div>
      </div>
      <div className="col-span-2 min-[900px]:col-span-1 min-[900px]:col-start-2 flex flex-wrap justify-end gap-2">
        <Skeleton className="h-9 w-24 rounded-lg" />
        <Skeleton className="h-9 w-24 rounded-lg" />
      </div>
    </section>
  );
}

function ListingCardSkeleton({ service }) {
  return (
    <div className={`${panel} min-w-0 overflow-hidden flex flex-col`}>
      <Skeleton className={`w-full rounded-none ${service ? 'aspect-[6/5] min-h-[180px]' : 'aspect-[1/1.12]'}`} />
      <div className="p-3 flex-1 flex flex-col gap-2.5">
        <Skeleton className="h-4 w-4/5" />
        {service && <Skeleton className="h-3 w-full" />}
        <Skeleton className="h-3 w-1/3" />
        <Skeleton className="h-9 w-full rounded-lg mt-auto" />
      </div>
    </div>
  );
}

function ListingsGridSkeleton({ count = 6, service }) {
  return (
    <div className="grid grid-cols-1 min-[600px]:grid-cols-2 min-[900px]:grid-cols-3 gap-3 items-start">
      {Array.from({ length: count }, (_, i) => <ListingCardSkeleton key={i} service={service} />)}
    </div>
  );
}

function ListingCard({ item, service, favorite, onFavorite }) {

  const [imageFailed, setImageFailed] = useState(false);
  const Icon = service ? Briefcase : CATEGORY_STYLE[item.category]?.icon || Package;
  return (
    <article className={`${panel} min-w-0 overflow-hidden flex flex-col`}>
      <div className={`relative w-full flex-none overflow-hidden ${service ? 'aspect-[6/5] min-h-[180px]' : 'aspect-[1/1.12]'} bg-gray-50 dark:bg-gray-800 flex items-center justify-center`}>
        {item.images?.[0] && !imageFailed ? <img src={item.images[0]} onError={() => setImageFailed(true)} alt={item.name} className="absolute inset-0 w-full h-full object-cover" /> : <Icon size={48} className="text-[#fa3f5e]/60" />}
        {service && <span className="absolute top-3 left-3 p-2 rounded-lg bg-white/95 dark:bg-gray-900/95 text-[#fa3f5e]"><Icon size={17} /></span>}
        <button type="button" onClick={onFavorite} aria-label={`${favorite ? 'Unsave' : 'Save'} ${item.name}`} aria-pressed={favorite} className="absolute top-3 right-3 w-8 h-8 rounded-full bg-white dark:bg-gray-900 shadow-sm flex items-center justify-center"><Heart size={17} className={favorite ? 'fill-[#fa3f5e] text-[#fa3f5e]' : 'text-gray-500'} /></button>
      </div>
      <div className="p-3 flex-1 flex flex-col min-h-[200px]">
        <h3 title={item.name} className="text-sm font-semibold text-gray-900 dark:text-white leading-5 line-clamp-2 min-h-[2.5rem]">{item.name}</h3>
        {service && <p className="text-xs leading-5 text-gray-500 dark:text-gray-400 mt-2 flex-1 line-clamp-2 min-h-10">{item.description}</p>}
        {!service && <div className="flex-1" />}
        <div className="flex flex-wrap items-center justify-between gap-2 border-t border-gray-100 dark:border-gray-800 pt-3 mt-3">
          {service && <span className="flex items-center gap-1 text-[11px] text-gray-500 dark:text-gray-400"><Clock size={13} />{item.duration || '1 hour'}</span>}
          <span className="text-sm font-bold text-[#fa3f5e]">{service && item.rateType === 'Starting from' ? <><span className="text-[10px] font-normal text-gray-400 mr-1">From</span>₹{item.price}</> : service ? servicePrice(item) : `₹${item.price.toFixed(2)}`}</span>
        </div>
        <div className="flex items-center gap-1.5 text-xs text-gray-500 dark:text-gray-400 mt-2 mb-4"><Star size={13} className="fill-amber-400 text-amber-400" />{item.rating > 0 ? <><span className="font-semibold text-gray-700 dark:text-gray-200">{item.rating}</span><span>({item.reviews || 0})</span></> : 'New listing'}</div>
        <Link to={service ? `/market/service/${item.id}` : `/market/product/${item.id}`} className={`${primary} relative w-full mt-auto py-2.5 px-3 flex items-center justify-center !font-medium text-xs`}>{service ? 'View service' : 'View product'}<ChevronRight size={15} className="absolute right-3" /></Link>
      </div>
    </article>
  );
}

export default function StoreProfile() {
  const { isSaved, toggle } = useMarketplaceWishlist();
  const user = useSelector((state) => state.auth.userObject);
  const [myProducts, setMyProducts] = useState([]);
  const [myServices, setMyServices] = useState([]);
  const [listingsLoading, setListingsLoading] = useState(true);
  const services = useMemo(() => myServices.filter((item) => item.status === 'Published' && item.visible), [myServices]);
  const products = useMemo(() => myProducts.filter((item) => item.status === 'Active'), [myProducts]);
  const cart = useSelector((state) => state.cart.items);
  const [params, setParams] = useSearchParams();
  const tab = ['All', 'Services', 'Products'].includes(params.get('tab')) ? params.get('tab') : 'All';
  const setTab = (value) => setParams((current) => { const next = new URLSearchParams(current); next.set('tab', value); return next; }, { replace: true });
  const [search, setSearch] = useState('');
  const [category, setCategory] = useState('All categories');
  const [sort, setSort] = useState('Recommended');
  const [following, setFollowing] = useState(false);
  const [areasOpen, setAreasOpen] = useState(false);
  const [storeProfile, setStoreProfile] = useState(null);
  const [profileLoading, setProfileLoading] = useState(false);
  const [profileError, setProfileError] = useState('');
  const [profileSaving, setProfileSaving] = useState(false);
  const [profileSaved, setProfileSaved] = useState('');
  const [profileForm, setProfileForm] = useState({
    service_areas: '',
    languages: '',
    store_type: '',
    trust_badges: '',
  });
  const name = user?.name || user?.full_name || 'Alex Morgan';
  const avatar = user?.profile_picture || user?.avatar;
  const userId = user?._id || user?.id;
  const influencerProfile = user?.influencer_profile || user?.influencerProfile || {};
  const fallbackStoreName = influencerProfile.store_name || `${name}'s Store`;
  const storeName = storeProfile?.store_name || fallbackStoreName;
  const storeType = storeProfile?.store_type || influencerProfile.store_type || 'Personal Store';
  const about = storeProfile?.about || influencerProfile.store_description || user?.bio || 'Helping you make everyday life simpler with thoughtful services and useful products. Explore the store to find what works for you.';
  const serviceAreas = storeProfile?.service_areas?.length ? storeProfile.service_areas : (influencerProfile.service_areas || []);
  const languages = storeProfile?.languages?.length ? storeProfile.languages : (influencerProfile.languages || ['English']);
  const trustBadges = storeProfile?.trust_badges?.length ? storeProfile.trust_badges : (influencerProfile.trust_badges || ['Professional', 'Trusted', 'Reliable']);
  const productCount = storeProfile?.product_count || products.length;
  const serviceCount = storeProfile?.service_count || services.length;
  const followersCount = storeProfile?.followers_count ?? user?.followers_count ?? 0;
  const followingCount = storeProfile?.following_count ?? user?.following_count ?? 0;
  const count = cart.reduce((sum, item) => sum + item.qty, 0);
  const shownProducts = products.filter((item) => item.name.toLowerCase().includes(search.trim().toLowerCase()) && (category === 'All categories' || item.category === category)).sort((a, b) => sort === 'Price: Low to high' ? a.price - b.price : sort === 'Price: High to low' ? b.price - a.price : sort === 'Top rated' ? b.rating - a.rating : 0);
  useEffect(() => {
    if (!userId) return;
    let active = true;
    setProfileLoading(true);
    setProfileError('');
    storeProfileService.get(userId)
      .then((profile) => {
        if (!active) return;
        setStoreProfile(profile);
        setFollowing(Boolean(profile.is_following));
        setProfileForm({
          service_areas: listToText(profile.service_areas),
          languages: listToText(profile.languages),
          store_type: profile.store_type || '',
          trust_badges: listToText(profile.trust_badges),
        });
      })
      .catch((error) => {
        if (!active) return;
        setProfileError(error?.response?.data?.message || 'Store profile could not be loaded.');
      })
      .finally(() => {
        if (active) setProfileLoading(false);
      });
    return () => { active = false; };
  }, [userId]);

  useEffect(() => {
    if (!userId) return;
    let active = true;
    setListingsLoading(true);
    Promise.all([
      influencerProductService.listMine().catch(() => []),
      influencerServiceService.listMine().catch(() => []),
    ]).then(([productItems, serviceItems]) => {
      if (!active) return;
      setMyProducts(productItems);
      setMyServices(serviceItems);
    }).finally(() => {
      if (active) setListingsLoading(false);
    });
    return () => { active = false; };
  }, [userId]);

  const updateProfileForm = (field, value) => {
    setProfileSaved('');
    setProfileForm((current) => ({ ...current, [field]: value }));
  };

  const saveStoreProfile = async (event) => {
    event.preventDefault();
    setProfileSaving(true);
    setProfileError('');
    setProfileSaved('');
    const payload = {
      service_areas: textToList(profileForm.service_areas),
      languages: textToList(profileForm.languages),
      store_type: profileForm.store_type.trim(),
      trust_badges: textToList(profileForm.trust_badges),
    };
    try {
      const saved = await storeProfileService.update(payload);
      const merged = { ...storeProfile, ...payload, ...saved };
      setStoreProfile(merged);
      setProfileForm({
        service_areas: listToText(merged.service_areas),
        languages: listToText(merged.languages),
        store_type: merged.store_type || '',
        trust_badges: listToText(merged.trust_badges),
      });
      setProfileSaved('Store profile updated.');
    } catch (error) {
      setProfileError(error?.response?.data?.message || 'Store profile update failed.');
    } finally {
      setProfileSaving(false);
    }
  };

  return (
    <div className="box-border w-full max-w-[1280px] ml-auto px-4 md:px-8 pt-6 pb-10">
      <div className={`grid grid-cols-1 min-[900px]:grid-cols-[minmax(0,1fr)_210px] min-[1200px]:grid-cols-[minmax(0,1fr)_240px] gap-4 items-start`}>
        <main className="min-w-0">
          {profileLoading ? <ProfileHeaderSkeleton /> : (
          <section aria-label="Store profile" className={`${panel} p-4 min-[900px]:p-5 min-[900px]:relative min-[900px]:min-h-[156px] grid grid-cols-[96px_minmax(0,1fr)] min-[900px]:grid-cols-[112px_minmax(0,1fr)] items-center gap-x-5 gap-y-3`}>
            <div className="relative flex-shrink-0 col-start-1 row-start-1 min-[900px]:row-span-2"><div className="w-24 h-24 min-[900px]:w-28 min-[900px]:h-28 rounded-full overflow-hidden bg-pink-50 dark:bg-pink-900/20 flex items-center justify-center">{avatar ? <img src={avatar} alt={storeName} className="w-full h-full object-cover" /> : <UserRound size={48} className="text-[#fa3f5e]" />}</div>{user?.is_verified && <BadgeCheck className="absolute bottom-1 right-0 text-[#fa3f5e] fill-white dark:fill-gray-900" size={27} />}</div>
            <div className="col-start-2 min-w-0 min-[900px]:self-start"><h1 className="text-xl lg:text-2xl font-bold text-gray-900 dark:text-white break-words">{storeName}</h1><p className="flex items-center gap-1.5 text-xs text-insta-purple font-semibold mt-2">{user?.is_verified && <BadgeCheck size={14} />}{user?.is_verified ? `Verified creator · ${storeType}` : storeType}</p><p className="flex flex-wrap items-center gap-x-4 gap-y-2 text-xs text-gray-500 dark:text-gray-400 mt-3"><span className="flex items-center gap-1.5"><Star size={15} className="fill-amber-400 text-amber-400" />{user?.rating > 0 ? <><span className="font-semibold text-gray-900 dark:text-white">{user.rating}</span><span>{user.reviews || 0} reviews</span></> : 'No store reviews yet'}</span><span>{productCount} {productCount === 1 ? 'product' : 'products'}</span><span>{serviceCount} {serviceCount === 1 ? 'service' : 'services'}</span><span>{followersCount} followers</span><span>{followingCount} following</span></p><p className="text-[11px] text-gray-500 dark:text-gray-400 mt-3 min-[1200px]:pr-[225px]">{trustBadges.length ? trustBadges.join(' · ') : 'Trusted store'}</p></div>
            <div className="col-span-2 min-[900px]:col-span-1 min-[900px]:col-start-2 min-[900px]:-mt-2 flex flex-wrap justify-end gap-2 min-[1200px]:absolute min-[1200px]:right-5 min-[1200px]:m-0 min-[1200px]:bottom-7"><Link to="/messages" className="flex items-center gap-2 px-4 py-2.5 rounded-lg border border-gray-200 dark:border-gray-700 text-xs font-semibold text-gray-700 dark:text-gray-300 shadow-sm"><MessageCircle size={15} />Message</Link><button type="button" aria-pressed={following} onClick={() => setFollowing(!following)} className={`${primary} flex items-center gap-2 px-4 py-2.5 text-xs`}>{following ? <Check size={15} /> : <UserPlus size={15} />}{following ? 'Following' : 'Follow'}</button></div>
          </section>
          )}
          <div role="tablist" aria-label="Store listings" className={`${panel} h-12 flex mt-3 mb-3 overflow-hidden`}>
            {[['All', LayoutGrid], ['Services', Briefcase], ['Products', Package]].map(([value, Icon], index) => <button key={value} id={`profile-tab-${value}`} role="tab" type="button" aria-selected={tab === value} aria-controls="profile-listings" onClick={() => setTab(value)} className={`relative flex-1 min-w-0 flex items-center justify-center gap-2 py-3 px-1 text-xs sm:text-sm font-semibold border-b-0 transition-colors focus:outline-none focus-visible:outline focus-visible:outline-2 focus-visible:outline-current focus-visible:-outline-offset-4 ${index > 0 ? "before:content-[''] before:absolute before:left-0 before:h-4 before:w-px before:bg-current before:opacity-[0.15]" : ''} ${tab === value ? "text-[#fa3f5e] after:content-[''] after:absolute after:bottom-0 after:left-1/4 after:right-1/4 after:h-0.5 after:bg-current" : 'text-gray-500 dark:text-gray-400 hover:bg-gray-50 dark:hover:bg-gray-800'}`}>{React.createElement(Icon, { size: 17 })}{value}</button>)}
          </div>
          <div id="profile-listings" role="tabpanel" aria-labelledby={`profile-tab-${tab}`} className="space-y-6">
            {tab === 'All' && (listingsLoading ? <ListingsGridSkeleton count={6} /> : <>
              <div aria-label="All listings" className="grid grid-cols-1 min-[600px]:grid-cols-2 min-[900px]:grid-cols-3 gap-3 items-start">
                {services.map((item) => <ListingCard key={`service-${item.id}`} item={item} service favorite={isSaved('service', item.id)} onFavorite={() => toggle('service', item.id)} />)}
                {products.map((item) => <ListingCard key={`product-${item.id}`} item={item} favorite={isSaved('product', item.id)} onFavorite={() => toggle('product', item.id, item)} />)}
                {!services.length && !products.length && <p className="col-span-full py-10 text-center text-gray-400">No published listings yet.</p>}
              </div>
            </>)}
            {tab === 'Services' && (listingsLoading ? <ListingsGridSkeleton count={3} service /> : <section aria-label="Services"><h2 className="sr-only">Services</h2><div className="grid grid-cols-1 min-[600px]:grid-cols-2 min-[900px]:grid-cols-3 gap-3 items-start">{services.map((item) => <ListingCard key={item.id} item={item} service favorite={isSaved('service', item.id)} onFavorite={() => toggle('service', item.id)} />)}{!services.length && <p className="col-span-full py-10 text-center text-gray-400">No published services yet.</p>}</div></section>)}
            {tab === 'Products' && (listingsLoading ? <ListingsGridSkeleton count={4} /> : <section aria-label="Products"><h2 className="sr-only">Products</h2><div className="grid grid-cols-1 min-[700px]:grid-cols-[minmax(0,1fr)_130px_160px] min-[900px]:grid-cols-[minmax(0,1fr)_110px_145px] min-[1200px]:grid-cols-[minmax(0,1fr)_140px_180px] gap-3 min-[900px]:gap-2.5 mb-4 min-[900px]:[&_button]:text-xs min-[900px]:[&_button]:pr-2.5 min-[900px]:[&_input]:text-xs min-[900px]:[&_input]:pr-2.5"><div className="relative w-full min-w-0"><Search size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" /><input aria-label="Search products" placeholder="Search products" value={search} onChange={(event) => setSearch(event.target.value)} className={`${inputCls} pl-9`} /></div><Dropdown className="w-full min-w-0" value={category} options={['All categories', ...new Set(products.map((item) => item.category))]} onChange={setCategory} /><Dropdown className="w-full min-w-0" value={sort} options={['Recommended', 'Price: Low to high', 'Price: High to low', 'Top rated']} onChange={setSort} /></div><div className="grid grid-cols-1 min-[600px]:grid-cols-2 min-[900px]:grid-cols-3 gap-3">{shownProducts.map((item) => <ListingCard key={item.id} item={item} favorite={isSaved('product', item.id)} onFavorite={() => toggle('product', item.id, item)} />)}{!shownProducts.length && <p className="col-span-full py-10 text-center text-gray-400">No products match your search.</p>}</div></section>)}
          </div>
        </main>
        <aside aria-label="Store information" className="space-y-4 min-w-0 min-[900px]:sticky min-[900px]:top-6">
          {tab !== 'Services' && (
            <Link to="/cart" aria-label={`My Cart, ${count} ${count === 1 ? 'item' : 'items'}`} className={`${panel} min-h-[96px] px-4 py-5 flex items-center gap-3 hover:shadow-md transition-shadow`}>
              <span className="relative w-12 h-12 shrink-0 rounded-full bg-gradient-to-r from-insta-purple via-insta-pink to-insta-orange flex items-center justify-center text-white">
                <ShoppingCart size={26} strokeWidth={1.5} />
                <span className="absolute -top-1 -right-1 min-w-[18px] h-[18px] px-1 flex items-center justify-center bg-white dark:bg-gray-800 text-[#fa3f5e] border border-gray-100 dark:border-gray-700 rounded-full text-[10px] font-medium">{count}</span>
              </span>
              <span className="flex-1 min-w-0">
                <span className="block text-sm font-semibold text-gray-900 dark:text-white">My Cart</span>
                <span className="block mt-1 text-xs text-gray-500 dark:text-gray-400">{count} {count === 1 ? 'item' : 'items'}</span>
              </span>
              <ChevronRight size={18} strokeWidth={1.5} className="shrink-0 text-gray-700 dark:text-gray-300" />
            </Link>
          )}
          <div aria-label="About store" className={`${panel} p-4 lg:p-5 divide-y divide-gray-100 dark:divide-gray-800`}>
            <section className="pb-5">
              <h2 className="text-sm font-bold text-gray-900 dark:text-white mb-3">About {storeName}</h2>
              <p className="text-xs leading-6 text-gray-500 dark:text-gray-400">{about}</p>
            </section>
            <section className="py-5 flex items-start gap-3">
              <span className="w-9 h-9 rounded-full bg-pink-50 dark:bg-pink-900/20 text-[#fa3f5e] flex items-center justify-center shrink-0"><Clock size={19} /></span>
              <p className="text-xs leading-5 text-gray-500 dark:text-gray-400">Message the store for availability and response times.</p>
            </section>
            <section className="py-5">
              <h2 className="text-sm font-bold text-gray-900 dark:text-white mb-3">Service areas</h2>
              <div className="flex gap-3">
                <span className="w-9 h-9 rounded-full bg-pink-50 dark:bg-pink-900/20 text-[#fa3f5e] flex items-center justify-center shrink-0"><MapPin size={19} /></span>
                <div>
                  <p className="text-xs leading-5 text-gray-500 dark:text-gray-400">{serviceAreas.length ? serviceAreas.slice(0, 2).join(', ') : 'At your location and online, depending on the service.'}</p>
                  {serviceAreas.length > 2 && <button type="button" aria-expanded={areasOpen} onClick={() => setAreasOpen(!areasOpen)} className="text-xs font-semibold text-[#fa3f5e] mt-3">{areasOpen ? 'Hide areas' : 'View all areas'}</button>}
                  {areasOpen && <p className="text-xs text-gray-500 dark:text-gray-400 mt-2 leading-5">{serviceAreas.join(', ')}</p>}
                </div>
              </div>
            </section>
            <section className="py-5">
              <h2 className="text-sm font-bold text-gray-900 dark:text-white mb-3">Languages</h2>
              <p className="flex gap-3 items-center text-xs text-gray-500 dark:text-gray-400"><span className="w-9 h-9 rounded-full bg-pink-50 dark:bg-pink-900/20 text-[#fa3f5e] flex items-center justify-center shrink-0"><Globe size={19} /></span>{languages.length ? languages.join(', ') : 'English'}</p>
            </section>
            <section className="pt-5">
              <h2 className="text-sm font-bold text-gray-900 dark:text-white mb-3">Store profile</h2>
              <form onSubmit={saveStoreProfile} className="space-y-3">
                <label className="block text-xs font-semibold text-gray-600 dark:text-gray-300">Store type<input value={profileForm.store_type} onChange={(event) => updateProfileForm('store_type', event.target.value)} placeholder="Personal Store" className={`${inputCls} mt-1`} /></label>
                <label className="block text-xs font-semibold text-gray-600 dark:text-gray-300">Service areas<input value={profileForm.service_areas} onChange={(event) => updateProfileForm('service_areas', event.target.value)} placeholder="Mumbai, Online" className={`${inputCls} mt-1`} /></label>
                <label className="block text-xs font-semibold text-gray-600 dark:text-gray-300">Languages<input value={profileForm.languages} onChange={(event) => updateProfileForm('languages', event.target.value)} placeholder="English, Hindi" className={`${inputCls} mt-1`} /></label>
                <label className="block text-xs font-semibold text-gray-600 dark:text-gray-300">Trust badges<input value={profileForm.trust_badges} onChange={(event) => updateProfileForm('trust_badges', event.target.value)} placeholder="Professional, Trusted, Reliable" className={`${inputCls} mt-1`} /></label>
                <button type="submit" disabled={profileSaving} className={`${primary} w-full px-4 py-2.5 text-xs flex items-center justify-center gap-2 disabled:opacity-60 disabled:cursor-not-allowed`}>{profileSaving ? <Loader2 size={15} className="animate-spin" /> : <Save size={15} />}{profileSaving ? 'Saving...' : 'Save profile'}</button>
                {(profileSaved || profileError) && <p className={`text-xs leading-5 ${profileSaved ? 'text-emerald-600' : 'text-[#fa3f5e]'}`}>{profileSaved || profileError}</p>}
              </form>
            </section>
          </div>
        </aside>
      </div>
    </div>
  );
}
