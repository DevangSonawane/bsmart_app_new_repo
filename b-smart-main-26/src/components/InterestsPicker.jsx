import React, { useRef } from 'react';
import { Plus, Loader2, ChevronLeft, ChevronRight } from 'lucide-react';
import bSmartBanner1 from '../assets/B-smart-banners/1.png';
import bSmartBanner2 from '../assets/B-smart-banners/2.png';
import bSmartBanner3 from '../assets/B-smart-banners/3.png';
import bSmartBanner4 from '../assets/B-smart-banners/4.png';
import bSmartBanner5 from '../assets/B-smart-banners/5.png';
import bSmartBanner6 from '../assets/B-smart-banners/6.png';
import bSmartBanner7 from '../assets/B-smart-banners/7.png';
import bSmartBanner8 from '../assets/B-smart-banners/8.png';
import bSmartBanner9 from '../assets/B-smart-banners/9.png';
import bSmartBanner10 from '../assets/B-smart-banners/10.png';
import bSmartBanner11 from '../assets/B-smart-banners/11.png';
import bSmartBanner12 from '../assets/B-smart-banners/12.png';
import bSmartBanner13 from '../assets/B-smart-banners/13.png';
import bSmartBanner14 from '../assets/B-smart-banners/14.png';
import bSmartBanner15 from '../assets/B-smart-banners/15.png';
import bSmartBanner16 from '../assets/B-smart-banners/16.png';
import bSmartBanner17 from '../assets/B-smart-banners/17.png';
import bSmartBanner18 from '../assets/B-smart-banners/18.png';
import bSmartBanner19 from '../assets/B-smart-banners/19.png';
import { AD_CATEGORIES_FALLBACK } from '../constants/interestCategories';

const CATEGORY_IMAGES_LIST = [
    bSmartBanner1, bSmartBanner2, bSmartBanner3, bSmartBanner4, bSmartBanner5,
    bSmartBanner6, bSmartBanner7, bSmartBanner8, bSmartBanner9, bSmartBanner10,
    bSmartBanner11, bSmartBanner12, bSmartBanner13, bSmartBanner14, bSmartBanner15,
    bSmartBanner16, bSmartBanner17, bSmartBanner18, bSmartBanner19
];

const getCategoryImage = (categoryName) => {
    const idx = AD_CATEGORIES_FALLBACK.indexOf(categoryName);
    if (idx !== -1) return CATEGORY_IMAGES_LIST[idx];
    return null;
};

// Category → emoji mapping for visual flair
const CATEGORY_EMOJI = {
    'Accessories': '👜', 'Action Figures': '🤖', 'Art Supplies': '🎨',
    'Baby Products': '🍼', 'Beauty & Personal Care': '💄', 'Books': '📚',
    'Clothing & Apparel': '👕', 'Electronics': '💻', 'Food & Beverages': '🍕',
    'Footwear': '👟', 'Gaming': '🎮', 'Health & Wellness': '💪',
    'Home & Kitchen': '🏠', 'Jewellery': '💎', 'Mobile & Tablets': '📱',
    'Pet Supplies': '🐾', 'Sports & Fitness': '⚽', 'Toys': '🧸', 'Travel': '✈️',
};

// ── Interests Modal — toggle-grid picker with batch Save ───────────────────────
export const InterestsModal = ({ isOpen, onClose, currentInterests = [], categories = AD_CATEGORIES_FALLBACK, onSave, saving }) => {
    const [selected, setSelected] = React.useState([]);

    React.useEffect(() => {
        if (isOpen) setSelected(currentInterests);
    }, [isOpen, currentInterests]);

    const toggle = (cat) =>
        setSelected(prev =>
            prev.includes(cat) ? prev.filter(c => c !== cat) : [...prev, cat]
        );

    if (!isOpen) return null;

    return (
        <div className="fixed inset-0 z-[9999] flex items-end sm:items-center justify-center">
            {/* Backdrop */}
            <div className="absolute inset-0 bg-black/60 backdrop-blur-sm" onClick={onClose} />

            {/* Sheet */}
            <div className="relative w-full sm:max-w-md bg-white dark:bg-gray-950 rounded-t-3xl sm:rounded-2xl shadow-2xl flex flex-col max-h-[85vh] overflow-hidden">
                {/* Handle bar */}
                <div className="flex justify-center pt-3 pb-1 sm:hidden">
                    <div className="w-10 h-1 rounded-full bg-gray-300 dark:bg-gray-700" />
                </div>

                {/* Header */}
                <div className="flex items-center justify-between px-5 py-4 border-b border-gray-100 dark:border-gray-800">
                    <div>
                        <h2 className="text-base font-bold text-gray-900 dark:text-white flex items-center gap-2">
                            Your Interests
                            {saving && <Loader2 size={13} className="animate-spin text-orange-400" />}
                        </h2>
                        <p className="text-xs text-gray-400 mt-0.5">{selected.length} selected · tap to toggle</p>
                    </div>
                    <button onClick={onClose}
                        className="w-8 h-8 flex items-center justify-center rounded-full bg-gray-100 dark:bg-gray-800 text-gray-500 dark:text-gray-400 hover:bg-gray-200 dark:hover:bg-gray-700 transition-colors text-lg font-light">
                        ✕
                    </button>
                </div>

                {/* Categories grid */}
                <div className="flex-1 overflow-y-auto px-4 py-4">
                    <div className="grid grid-cols-2 gap-2.5">
                        {categories.map(cat => {
                            const active = selected.includes(cat);
                            return (
                                <button key={cat} type="button" onClick={() => toggle(cat)}
                                    className={`flex items-center gap-2.5 px-3 py-2.5 rounded-xl border text-left transition-all duration-150 ${
                                        active
                                            ? 'bg-orange-50 dark:bg-orange-900/20 border-orange-400 dark:border-orange-500'
                                            : 'bg-white dark:bg-gray-900 border-gray-200 dark:border-gray-700 hover:border-gray-400 dark:hover:border-gray-500'
                                    }`}>
                                    <span className="text-xl leading-none">{CATEGORY_EMOJI[cat] || '🏷️'}</span>
                                    <span className={`text-xs font-medium leading-tight ${active ? 'text-orange-600 dark:text-orange-400' : 'text-gray-700 dark:text-gray-300'}`}>
                                        {cat}
                                    </span>
                                    {active && (
                                        <span className="ml-auto text-orange-500 text-xs font-bold">✓</span>
                                    )}
                                </button>
                            );
                        })}
                    </div>
                </div>

                {/* Footer */}
                <div className="px-4 py-4 border-t border-gray-100 dark:border-gray-800 flex gap-3">
                    <button onClick={onClose}
                        className="flex-1 h-11 rounded-xl border border-gray-200 dark:border-gray-700 text-sm font-semibold text-gray-700 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors">
                        Cancel
                    </button>
                    <button onClick={() => onSave(selected)} disabled={saving}
                        className="flex-1 h-11 rounded-xl bg-orange-500 hover:bg-orange-600 disabled:opacity-60 text-white text-sm font-bold transition-colors flex items-center justify-center gap-2">
                        {saving && <Loader2 size={15} className="animate-spin" />}
                        {saving ? 'Saving…' : 'Save Interests'}
                    </button>
                </div>
            </div>
        </div>
    );
};

// ── Interested Section — horizontal scroll of gradient category cards ──────────
export const InterestedSection = ({ interests = [], isOwnProfile = false, onAdd }) => {
    const scrollRef = useRef(null);

    const scroll = (direction) => {
        if (scrollRef.current) {
            const { scrollLeft, clientWidth } = scrollRef.current;
            const scrollTo = direction === 'left' ? scrollLeft - clientWidth / 1.5 : scrollLeft + clientWidth / 1.5;
            scrollRef.current.scrollTo({ left: scrollTo, behavior: 'smooth' });
        }
    };

    if (interests.length === 0) {
        return (
            <div className="w-full py-4 flex flex-col items-center gap-3">
                <p className="text-sm text-gray-500 dark:text-gray-400 font-medium italic">No interests listed yet.</p>
                {isOwnProfile && onAdd && (
                    <button
                        type="button"
                        onClick={onAdd}
                        className="inline-flex items-center gap-1.5 px-4 py-2 rounded-full bg-blue-500 hover:bg-blue-600 text-white text-xs font-semibold transition-colors shadow-sm"
                    >
                        <Plus size={13} /> Add interests
                    </button>
                )}
            </div>
        );
    }

    return (
        <div className="w-full max-w-full overflow-hidden">
            <div className="mb-2.5 flex items-center justify-between">
                <div className="text-[13px] font-bold tracking-tight text-gray-900 dark:text-white">
                    Interested Section
                </div>
                <div className="flex items-center gap-1">
                    {isOwnProfile && onAdd && (
                        <button
                            type="button"
                            onClick={onAdd}
                            className="inline-flex h-6 w-6 items-center justify-center rounded-full bg-blue-500 hover:bg-blue-600 text-white transition shadow-sm"
                            aria-label="Add interest"
                        >
                            <Plus size={12} />
                        </button>
                    )}
                    <button
                        type="button"
                        onClick={() => scroll('left')}
                        className="inline-flex h-6 w-6 items-center justify-center rounded-full bg-gray-100 dark:bg-gray-800 text-gray-900 dark:text-white transition hover:bg-gray-200 dark:hover:bg-gray-700 shadow-sm"
                        aria-label="Previous"
                    >
                        <ChevronLeft size={12} />
                    </button>
                    <button
                        type="button"
                        onClick={() => scroll('right')}
                        className="inline-flex h-6 w-6 items-center justify-center rounded-full bg-gray-100 dark:bg-gray-800 text-gray-900 dark:text-white transition hover:bg-gray-200 dark:hover:bg-gray-700 shadow-sm"
                        aria-label="Next"
                    >
                        <ChevronRight size={12} />
                    </button>
                </div>
            </div>

            <div
                ref={scrollRef}
                className="flex gap-2 overflow-x-auto scrollbar-none pb-0.5"
                style={{ WebkitOverflowScrolling: 'touch', scrollbarWidth: 'none', msOverflowStyle: 'none' }}
            >
                {interests.map((interest) => {
                    const img = getCategoryImage(interest);
                    return (
                        <div key={interest} className="flex-shrink-0 w-[115px] sm:w-[135px] aspect-[16/9] relative rounded-lg overflow-hidden shadow-sm group border border-gray-100 dark:border-gray-800">
                            {img ? (
                                <img src={img} alt={interest} className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-500" />
                            ) : (
                                <div className="w-full h-full bg-gray-100 dark:bg-gray-900 flex items-center justify-center">
                                    <span className="text-lg">🏷️</span>
                                </div>
                            )}
                            <div className="absolute inset-0 bg-gradient-to-t from-black/85 via-black/20 to-transparent flex items-end p-2">
                                <span className="text-white text-[9px] font-bold truncate leading-tight italic tracking-tight">{interest}</span>
                            </div>
                        </div>
                    );
                })}
            </div>
            <style>{`
                .scrollbar-none::-webkit-scrollbar { display: none; }
            `}</style>
        </div>
    );
};
