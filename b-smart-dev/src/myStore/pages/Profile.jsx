import React, { useState } from 'react';
import { Link, useSearchParams } from 'react-router-dom';
import { useDispatch, useSelector } from 'react-redux';
import { LayoutGrid, Briefcase, Package, Heart, Star, Clock, MapPin, Globe, MessageCircle, UserPlus, Check, BadgeCheck, ShoppingCart, ChevronRight, Search, UserRound } from 'lucide-react';
import { Dropdown, inputCls } from '../../components/productForm/ProductFormFields';
import { CATEGORY_STYLE } from '../../data/marketplaceCategoryStyle';
import { servicePrice } from '../data/serviceFields';
import { addItem } from '../../store/cartSlice';
import useMarketplaceWishlist from '../../hooks/useMarketplaceWishlist';

const panel = 'bg-white dark:bg-gray-900 border border-gray-100 dark:border-gray-800 rounded-2xl shadow-sm';
const primary = 'bg-gradient-to-r from-insta-purple via-insta-pink to-insta-orange text-white rounded-lg font-semibold';

function ListingCard({ item, service, favorite, onFavorite, onAdd, added }) {

  const [imageFailed, setImageFailed] = useState(false);
  const Icon = service ? Briefcase : CATEGORY_STYLE[item.category]?.icon || Package;
  return (
    <article className={`${panel} min-w-0 overflow-hidden flex flex-col`}>
      <div className={`relative w-full flex-none overflow-hidden ${service ? 'aspect-[6/5] min-h-[180px]' : 'aspect-[1/1.12]'} bg-gray-50 dark:bg-gray-800 flex items-center justify-center`}>
        {item.images?.[0] && !imageFailed ? <img src={item.images[0]} onError={() => setImageFailed(true)} alt={item.name} className="absolute inset-0 w-full h-full object-cover" /> : <Icon size={48} className="text-[#fa3f5e]/60" />}
        {service && <span className="absolute top-3 left-3 p-2 rounded-lg bg-white/95 dark:bg-gray-900/95 text-[#fa3f5e]"><Icon size={17} /></span>}
        <button type="button" onClick={onFavorite} aria-label={`${favorite ? 'Unsave' : 'Save'} ${item.name}`} aria-pressed={favorite} className="absolute top-3 right-3 w-8 h-8 rounded-full bg-white dark:bg-gray-900 shadow-sm flex items-center justify-center"><Heart size={17} className={favorite ? 'fill-[#fa3f5e] text-[#fa3f5e]' : 'text-gray-500'} /></button>
      </div>
      <div className={`p-3 flex-1 flex flex-col ${service ? 'min-h-[200px]' : 'min-h-[152px]'}`}>
        <h3 className="text-sm font-semibold text-gray-900 dark:text-white break-words">{item.name}</h3>
        {service && <p className="text-xs leading-5 text-gray-500 dark:text-gray-400 mt-2 flex-1 min-h-10">{item.description}</p>}
        <div className={`flex flex-wrap items-center justify-between gap-2 ${service ? 'border-t border-gray-100 dark:border-gray-800 pt-3 mt-3' : 'mt-2'}`}>
          {service && <span className="flex items-center gap-1 text-[11px] text-gray-500 dark:text-gray-400"><Clock size={13} />{item.duration || '1 hour'}</span>}
          <span className="text-sm font-bold text-[#fa3f5e]">{service && item.rateType === 'Starting from' ? <><span className="text-[10px] font-normal text-gray-400 mr-1">From</span>₹{item.price}</> : service ? servicePrice(item) : `₹${item.price.toFixed(2)}`}</span>
        </div>
        <div className="flex items-center gap-1.5 text-xs text-gray-500 dark:text-gray-400 mt-2 mb-4"><Star size={13} className="fill-amber-400 text-amber-400" />{item.rating > 0 ? <><span className="font-semibold text-gray-700 dark:text-gray-200">{item.rating}</span><span>({item.reviews || 0})</span></> : 'New listing'}</div>
        {service ? <Link to={`/market/service/${item.id}`} className={`${primary} relative w-full mt-auto py-2.5 px-3 flex items-center justify-center !font-medium text-xs`}>View service<ChevronRight size={15} className="absolute right-3" /></Link> : <button type="button" onClick={onAdd} className="mt-auto w-full py-2.5 text-xs font-semibold text-[#fa3f5e] border border-[#fa3f5e]/40 rounded-lg hover:bg-pink-50 dark:hover:bg-pink-900/10 flex items-center justify-center gap-2">{added ? <Check size={15} /> : <ShoppingCart size={15} />}{added ? 'Add another' : 'Add'}</button>}
      </div>
    </article>
  );
}

export default function StoreProfile() {
  const dispatch = useDispatch();
  const { isSaved, toggle } = useMarketplaceWishlist();
  const user = useSelector((state) => state.auth.userObject);
  const services = useSelector((state) => state.services.items).filter((item) => item.status === 'Published' && item.visible);
  const products = useSelector((state) => state.products.items).filter((item) => (item.status || (item.rating > 0 ? 'Active' : 'Draft')) === 'Active');
  const cart = useSelector((state) => state.cart.items);
  const [params, setParams] = useSearchParams();
  const tab = ['All', 'Services', 'Products'].includes(params.get('tab')) ? params.get('tab') : 'All';
  const setTab = (value) => setParams((current) => { const next = new URLSearchParams(current); next.set('tab', value); return next; }, { replace: true });
  const [search, setSearch] = useState('');
  const [category, setCategory] = useState('All categories');
  const [sort, setSort] = useState('Recommended');
  const [following, setFollowing] = useState(false);
  const [areasOpen, setAreasOpen] = useState(false);
  const [notice, setNotice] = useState('');
  const name = user?.name || user?.full_name || 'Alex Morgan';
  const avatar = user?.profile_picture || user?.avatar;
  const count = cart.reduce((sum, item) => sum + item.qty, 0);
  const shownProducts = products.filter((item) => item.name.toLowerCase().includes(search.trim().toLowerCase()) && (category === 'All categories' || item.category === category)).sort((a, b) => sort === 'Price: Low to high' ? a.price - b.price : sort === 'Price: High to low' ? b.price - a.price : sort === 'Top rated' ? b.rating - a.rating : 0);
  const add = (item) => {
    dispatch(addItem({ id: item.id, name: item.name, subtitle: item.dimensions, brand: item.vendor, price: item.price, category: item.category, images: item.images, storeName: `${name}'s Personal Store`, storeAvatar: avatar, storeType: 'Personal Store' }));
    setNotice(`${item.name} added to your cart.`);
  };
  return (
    <div className="box-border w-full max-w-[1280px] ml-auto px-4 md:px-8 pt-6 pb-10">
      <div className={`grid grid-cols-1 min-[900px]:grid-cols-[minmax(0,1fr)_210px] min-[1200px]:grid-cols-[minmax(0,1fr)_240px] gap-4 items-start`}>
        <main className="min-w-0">
          <section aria-label="Store profile" className={`${panel} p-4 min-[900px]:p-5 min-[900px]:relative min-[900px]:min-h-[156px] grid grid-cols-[96px_minmax(0,1fr)] min-[900px]:grid-cols-[112px_minmax(0,1fr)] items-center gap-x-5 gap-y-3`}>
            <div className="relative flex-shrink-0 col-start-1 row-start-1 min-[900px]:row-span-2"><div className="w-24 h-24 min-[900px]:w-28 min-[900px]:h-28 rounded-full overflow-hidden bg-pink-50 dark:bg-pink-900/20 flex items-center justify-center">{avatar ? <img src={avatar} alt={name} className="w-full h-full object-cover" /> : <UserRound size={48} className="text-[#fa3f5e]" />}</div>{user?.is_verified && <BadgeCheck className="absolute bottom-1 right-0 text-[#fa3f5e] fill-white dark:fill-gray-900" size={27} />}</div>
            <div className="col-start-2 min-w-0 min-[900px]:self-start"><h1 className="text-xl lg:text-2xl font-bold text-gray-900 dark:text-white break-words">{name}’s Store</h1><p className="flex items-center gap-1.5 text-xs text-insta-purple font-semibold mt-2">{user?.is_verified && <BadgeCheck size={14} />}{user?.is_verified ? 'Verified creator' : 'Personal Store'}</p><p className="flex flex-wrap items-center gap-2 text-xs text-gray-500 dark:text-gray-400 mt-3"><Star size={15} className="fill-amber-400 text-amber-400" />{user?.rating > 0 ? <><span className="font-semibold text-gray-900 dark:text-white">{user.rating}</span><span className="ml-2">{user.reviews || 0} reviews</span></> : 'No store reviews yet'}</p><p className="text-[11px] text-gray-500 dark:text-gray-400 mt-3 min-[1200px]:pr-[225px]">Professional · Trusted · Reliable</p></div>
            <div className="col-span-2 min-[900px]:col-span-1 min-[900px]:col-start-2 min-[900px]:-mt-2 flex flex-wrap justify-end gap-2 min-[1200px]:absolute min-[1200px]:right-5 min-[1200px]:m-0 min-[1200px]:bottom-7"><Link to="/messages" className="flex items-center gap-2 px-4 py-2.5 rounded-lg border border-gray-200 dark:border-gray-700 text-xs font-semibold text-gray-700 dark:text-gray-300 shadow-sm"><MessageCircle size={15} />Message</Link><button type="button" aria-pressed={following} onClick={() => setFollowing(!following)} className={`${primary} flex items-center gap-2 px-4 py-2.5 text-xs`}>{following ? <Check size={15} /> : <UserPlus size={15} />}{following ? 'Following' : 'Follow'}</button></div>
          </section>
          <div role="tablist" aria-label="Store listings" className={`${panel} h-12 flex mt-3 mb-3 overflow-hidden`}>
            {[['All', LayoutGrid], ['Services', Briefcase], ['Products', Package]].map(([value, Icon], index) => <button key={value} id={`profile-tab-${value}`} role="tab" type="button" aria-selected={tab === value} aria-controls="profile-listings" onClick={() => setTab(value)} className={`relative flex-1 min-w-0 flex items-center justify-center gap-2 py-3 px-1 text-xs sm:text-sm font-semibold border-b-0 transition-colors focus:outline-none focus-visible:outline focus-visible:outline-2 focus-visible:outline-current focus-visible:-outline-offset-4 ${index > 0 ? "before:content-[''] before:absolute before:left-0 before:h-4 before:w-px before:bg-current before:opacity-[0.15]" : ''} ${tab === value ? "text-[#fa3f5e] after:content-[''] after:absolute after:bottom-0 after:left-1/4 after:right-1/4 after:h-0.5 after:bg-current" : 'text-gray-500 dark:text-gray-400 hover:bg-gray-50 dark:hover:bg-gray-800'}`}>{React.createElement(Icon, { size: 17 })}{value}</button>)}
          </div>
          <div id="profile-listings" role="tabpanel" aria-labelledby={`profile-tab-${tab}`} className="space-y-6">
            {tab === 'All' && <>
              <div aria-label="All listings" className="grid grid-cols-1 min-[600px]:grid-cols-2 min-[900px]:grid-cols-3 gap-3 items-start">
                {services.map((item) => <ListingCard key={`service-${item.id}`} item={item} service favorite={isSaved('service', item.id)} onFavorite={() => toggle('service', item.id)} />)}
                {products.map((item) => <ListingCard key={`product-${item.id}`} item={item} favorite={isSaved('product', item.id)} onFavorite={() => toggle('product', item.id)} onAdd={() => add(item)} added={cart.some((entry) => entry.id === item.id)} />)}
                {!services.length && !products.length && <p className="col-span-full py-10 text-center text-gray-400">No published listings yet.</p>}
              </div>
              <p role="status" className="text-xs text-[#fa3f5e] mt-3">{notice}</p>
            </>}
            {tab === 'Services' && <section aria-label="Services"><h2 className="sr-only">Services</h2><div className="grid grid-cols-1 min-[600px]:grid-cols-2 min-[900px]:grid-cols-3 gap-3 items-start">{services.map((item) => <ListingCard key={item.id} item={item} service favorite={isSaved('service', item.id)} onFavorite={() => toggle('service', item.id)} />)}{!services.length && <p className="col-span-full py-10 text-center text-gray-400">No published services yet.</p>}</div></section>}
            {tab === 'Products' && <section aria-label="Products"><h2 className="sr-only">Products</h2><div className="grid grid-cols-1 min-[700px]:grid-cols-[minmax(0,1fr)_130px_160px] min-[900px]:grid-cols-[minmax(0,1fr)_110px_145px] min-[1200px]:grid-cols-[minmax(0,1fr)_140px_180px] gap-3 min-[900px]:gap-2.5 mb-4 min-[900px]:[&_button]:text-xs min-[900px]:[&_button]:pr-2.5 min-[900px]:[&_input]:text-xs min-[900px]:[&_input]:pr-2.5"><div className="relative w-full min-w-0"><Search size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" /><input aria-label="Search products" placeholder="Search products" value={search} onChange={(event) => setSearch(event.target.value)} className={`${inputCls} pl-9`} /></div><Dropdown className="w-full min-w-0" value={category} options={['All categories', ...new Set(products.map((item) => item.category))]} onChange={setCategory} /><Dropdown className="w-full min-w-0" value={sort} options={['Recommended', 'Price: Low to high', 'Price: High to low', 'Top rated']} onChange={setSort} /></div><div className="grid grid-cols-1 min-[400px]:grid-cols-2 min-[900px]:grid-cols-4 gap-3">{shownProducts.map((item) => <ListingCard key={item.id} item={item} favorite={isSaved('product', item.id)} onFavorite={() => toggle('product', item.id)} onAdd={() => add(item)} added={cart.some((entry) => entry.id === item.id)} />)}{!shownProducts.length && <p className="col-span-full py-10 text-center text-gray-400">No products match your search.</p>}</div><p role="status" className="text-xs text-[#fa3f5e] mt-3">{notice}</p></section>}
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
          <div aria-label="About store" className={`${panel} p-4 lg:p-5 divide-y divide-gray-100 dark:divide-gray-800`}><section className="pb-5"><h2 className="text-sm font-bold text-gray-900 dark:text-white mb-3">About {name.split(' ')[0]}</h2><p className="text-xs leading-6 text-gray-500 dark:text-gray-400">{user?.bio || 'Helping you make everyday life simpler with thoughtful services and useful products. Explore the store to find what works for you.'}</p></section><section className="py-5 flex items-start gap-3"><span className="w-9 h-9 rounded-full bg-pink-50 dark:bg-pink-900/20 text-[#fa3f5e] flex items-center justify-center shrink-0"><Clock size={19} /></span><p className="text-xs leading-5 text-gray-500 dark:text-gray-400">Message the store for availability and response times.</p></section><section className="py-5"><h2 className="text-sm font-bold text-gray-900 dark:text-white mb-3">Service areas</h2><div className="flex gap-3"><span className="w-9 h-9 rounded-full bg-pink-50 dark:bg-pink-900/20 text-[#fa3f5e] flex items-center justify-center shrink-0"><MapPin size={19} /></span><div><p className="text-xs leading-5 text-gray-500 dark:text-gray-400">At your location and online, depending on the service.</p><button type="button" aria-expanded={areasOpen} onClick={() => setAreasOpen(!areasOpen)} className="text-xs font-semibold text-[#fa3f5e] mt-3">{areasOpen ? 'Hide areas' : 'View all areas'}</button>{areasOpen && <p className="text-xs text-gray-500 dark:text-gray-400 mt-2 leading-5">Contact the store to confirm coverage for your address.</p>}</div></div></section><section className="pt-5"><h2 className="text-sm font-bold text-gray-900 dark:text-white mb-3">Languages</h2><p className="flex gap-3 items-center text-xs text-gray-500 dark:text-gray-400"><span className="w-9 h-9 rounded-full bg-pink-50 dark:bg-pink-900/20 text-[#fa3f5e] flex items-center justify-center shrink-0"><Globe size={19} /></span>English</p></section></div>
        </aside>
      </div>
    </div>
  );
}
