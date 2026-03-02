import React, { useState, useRef, useCallback, useEffect } from 'react';
import { X, Upload, ZoomIn, ZoomOut, RotateCcw, Check } from 'lucide-react';
import api from '../lib/api';

/**
 * AvatarCropModal
 * Props:
 *   isOpen        - boolean
 *   onClose       - () => void
 *   onSuccess     - (newAvatarUrl: string) => void   called after successful upload
 *   currentAvatar - string | null  (existing avatar_url)
 *   userName      - string         (for initials fallback)
 */
const AvatarCropModal = ({ isOpen, onClose, onSuccess, currentAvatar, userName }) => {
    // ─── Stage: 'select' | 'crop' | 'uploading' ───
    const [stage, setStage] = useState('select');
    const [rawImage, setRawImage] = useState(null);   // DataURL of selected file
    const [error, setError] = useState('');

    // Crop state
    const [zoom, setZoom] = useState(1);
    const [offset, setOffset] = useState({ x: 0, y: 0 });
    const [dragging, setDragging] = useState(false);
    const dragStart = useRef({ x: 0, y: 0, ox: 0, oy: 0 });
    const canvasRef = useRef(null);
    const imgRef = useRef(null);        // HTMLImageElement for drawing

    const CANVAS_SIZE = 320; // px — the circular crop canvas

    const resetState = () => {
        setStage('select');
        setRawImage(null);
        setZoom(1);
        setOffset({ x: 0, y: 0 });
        setError('');
        setDragging(false);
        imgRef.current = null;
    };

    const drawCanvas = useCallback(() => {
        const canvas = canvasRef.current;
        const img = imgRef.current;
        if (!canvas || !img) return;

        const ctx = canvas.getContext('2d');
        ctx.clearRect(0, 0, CANVAS_SIZE, CANVAS_SIZE);

        // Clip to circle
        ctx.save();
        ctx.beginPath();
        ctx.arc(CANVAS_SIZE / 2, CANVAS_SIZE / 2, CANVAS_SIZE / 2, 0, Math.PI * 2);
        ctx.clip();

        // Compute fit-cover base scale
        const baseScale = Math.max(CANVAS_SIZE / img.naturalWidth, CANVAS_SIZE / img.naturalHeight);
        const scale = baseScale * zoom;
        const drawW = img.naturalWidth * scale;
        const drawH = img.naturalHeight * scale;

        // Center + offset
        const x = (CANVAS_SIZE - drawW) / 2 + offset.x;
        const y = (CANVAS_SIZE - drawH) / 2 + offset.y;

        ctx.drawImage(img, x, y, drawW, drawH);
        ctx.restore();

        // Circle border
        ctx.beginPath();
        ctx.arc(CANVAS_SIZE / 2, CANVAS_SIZE / 2, CANVAS_SIZE / 2 - 1.5, 0, Math.PI * 2);
        ctx.strokeStyle = 'rgba(255,255,255,0.5)';
        ctx.lineWidth = 3;
        ctx.stroke();
    }, [zoom, offset]);

    // ── Draw canvas whenever zoom/offset/rawImage changes ──
    useEffect(() => {
        if (stage !== 'crop' || !canvasRef.current || !imgRef.current) return;
        drawCanvas();
    }, [drawCanvas, stage, rawImage]);

    // ── File selection ──
    const handleFileChange = (e) => {
        const file = e.target.files?.[0];
        if (!file) return;
        if (!file.type.startsWith('image/')) {
            setError('Please select an image file.');
            return;
        }
        const reader = new FileReader();
        reader.onload = (ev) => {
            const dataUrl = ev.target.result;
            setRawImage(dataUrl);
            // Preload image element
            const img = new Image();
            img.onload = () => {
                imgRef.current = img;
                setZoom(1);
                setOffset({ x: 0, y: 0 });
                setStage('crop');
            };
            img.src = dataUrl;
        };
        reader.readAsDataURL(file);
    };

    // ── Drag handlers ──
    const onPointerDown = (e) => {
        e.preventDefault();
        setDragging(true);
        dragStart.current = {
            x: e.clientX,
            y: e.clientY,
            ox: offset.x,
            oy: offset.y,
        };
    };

    const onPointerMove = useCallback((e) => {
        if (!dragging) return;
        const dx = e.clientX - dragStart.current.x;
        const dy = e.clientY - dragStart.current.y;

        // Clamp so image always covers the circle
        const img = imgRef.current;
        if (!img) return;
        const baseScale = Math.max(CANVAS_SIZE / img.naturalWidth, CANVAS_SIZE / img.naturalHeight);
        const scale = baseScale * zoom;
        const drawW = img.naturalWidth * scale;
        const drawH = img.naturalHeight * scale;
        const maxX = (drawW - CANVAS_SIZE) / 2;
        const maxY = (drawH - CANVAS_SIZE) / 2;

        setOffset({
            x: Math.max(-maxX, Math.min(maxX, dragStart.current.ox + dx)),
            y: Math.max(-maxY, Math.min(maxY, dragStart.current.oy + dy)),
        });
    }, [dragging, zoom]);

    const onPointerUp = () => setDragging(false);

    // ── Pinch/wheel zoom ──
    const onWheel = (e) => {
        e.preventDefault();
        const delta = e.deltaY < 0 ? 0.08 : -0.08;
        setZoom(z => Math.max(1, Math.min(4, z + delta)));
    };

    // ── Upload ──
    const handleUpload = async () => {
        setStage('uploading');
        setError('');
        try {
            // Export canvas to blob
            const canvas = canvasRef.current;
            const blob = await new Promise((res) => canvas.toBlob(res, 'image/jpeg', 0.92));

            const formData = new FormData();
            formData.append('file', blob, 'avatar.jpg');

            const response = await api.post('/upload/avatar', formData, {
                headers: { 'Content-Type': 'multipart/form-data' },
            });

            // API returns the new avatar_url — adjust field name if different
            const newUrl = response.data?.avatar_url || response.data?.url || response.data?.data?.avatar_url;
            onSuccess(newUrl);
            resetState();
            onClose();
        } catch (err) {
            setError(err?.response?.data?.message || 'Upload failed. Please try again.');
            setStage('crop');
        }
    };

    const getInitials = (name) => {
        if (!name) return 'U';
        return name.split(' ').map(n => n[0]).join('').toUpperCase().substring(0, 2);
    };

    if (!isOpen) return null;

    return (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 backdrop-blur-sm p-4">
            <div className="w-full max-w-sm bg-white dark:bg-gray-950 rounded-2xl shadow-2xl border border-gray-200 dark:border-gray-800 overflow-hidden">

                {/* ── Header ── */}
                <div className="flex items-center justify-between px-5 py-4 border-b border-gray-100 dark:border-gray-800">
                    <h3 className="text-base font-semibold text-gray-900 dark:text-white">
                        {stage === 'select' ? 'Change Profile Photo' : stage === 'uploading' ? 'Uploading…' : 'Adjust Photo'}
                    </h3>
                    <button
                        type="button"
                        onClick={() => {
                            resetState();
                            onClose();
                        }}
                        disabled={stage === 'uploading'}
                        className="p-1.5 rounded-full hover:bg-gray-100 dark:hover:bg-gray-800 text-gray-600 dark:text-gray-300 transition-colors"
                    >
                        <X size={18} />
                    </button>
                </div>

                {/* ── Stage: SELECT ── */}
                {stage === 'select' && (
                    <div className="px-6 py-8 flex flex-col items-center gap-5">
                        {/* Preview current avatar */}
                        <div className="w-28 h-28 rounded-full overflow-hidden ring-4 ring-offset-2 ring-orange-400 dark:ring-offset-gray-950">
                            {currentAvatar ? (
                                <img src={currentAvatar} alt="Current avatar" className="w-full h-full object-cover" />
                            ) : (
                                <div className="w-full h-full bg-gradient-to-br from-yellow-400 via-orange-500 to-pink-500 flex items-center justify-center text-3xl font-bold text-white">
                                    {getInitials(userName)}
                                </div>
                            )}
                        </div>

                        <p className="text-sm text-gray-500 dark:text-gray-400 text-center">
                            Select a photo to set as your profile picture
                        </p>

                        <label className="cursor-pointer w-full">
                            <div className="w-full flex items-center justify-center gap-2 px-4 py-3 rounded-xl bg-gradient-to-r from-orange-500 to-pink-500 text-white text-sm font-semibold hover:opacity-90 transition-opacity shadow-md shadow-orange-200 dark:shadow-orange-900/30">
                                <Upload size={16} />
                                Select image
                            </div>
                            <input
                                type="file"
                                accept="image/*"
                                onChange={handleFileChange}
                                className="hidden"
                            />
                        </label>

                        {error && <p className="text-sm text-red-500 text-center">{error}</p>}
                    </div>
                )}

                {/* ── Stage: CROP ── */}
                {stage === 'crop' && (
                    <div className="flex flex-col items-center">
                        {/* Hint */}
                        <p className="text-xs text-gray-400 dark:text-gray-500 py-3 text-center px-4">
                            Drag to reposition · Scroll or pinch to zoom
                        </p>

                        {/* Canvas crop area */}
                        <div className="relative flex items-center justify-center bg-gray-900 w-full py-4">
                            {/* Dark overlay corners (visual guide) */}
                            <div className="absolute inset-0 pointer-events-none">
                                <svg width="100%" height="100%" className="absolute inset-0">
                                    <defs>
                                        <mask id="circleMask">
                                            <rect width="100%" height="100%" fill="white" />
                                            <circle cx="50%" cy="50%" r={CANVAS_SIZE / 2} fill="black" />
                                        </mask>
                                    </defs>
                                    <rect width="100%" height="100%" fill="rgba(0,0,0,0.55)" mask="url(#circleMask)" />
                                </svg>
                            </div>

                            <canvas
                                ref={canvasRef}
                                width={CANVAS_SIZE}
                                height={CANVAS_SIZE}
                                className="rounded-full cursor-grab active:cursor-grabbing touch-none select-none"
                                style={{ width: CANVAS_SIZE, height: CANVAS_SIZE }}
                                onPointerDown={onPointerDown}
                                onPointerMove={onPointerMove}
                                onPointerUp={onPointerUp}
                                onPointerLeave={onPointerUp}
                                onWheel={onWheel}
                            />
                        </div>

                        {/* Zoom slider */}
                        <div className="flex items-center gap-3 px-6 py-4 w-full">
                            <button
                                onClick={() => setZoom(z => Math.max(1, z - 0.15))}
                                className="p-1.5 rounded-full hover:bg-gray-100 dark:hover:bg-gray-800 text-gray-600 dark:text-gray-300 transition-colors"
                            >
                                <ZoomOut size={18} />
                            </button>
                            <input
                                type="range"
                                min="100" max="400" step="1"
                                value={Math.round(zoom * 100)}
                                onChange={e => {
                                    const newZoom = parseInt(e.target.value) / 100;
                                    setZoom(newZoom);
                                    // Reclamp offset
                                    const img = imgRef.current;
                                    if (!img) return;
                                    const baseScale = Math.max(CANVAS_SIZE / img.naturalWidth, CANVAS_SIZE / img.naturalHeight);
                                    const scale = baseScale * newZoom;
                                    const drawW = img.naturalWidth * scale;
                                    const drawH = img.naturalHeight * scale;
                                    const maxX = (drawW - CANVAS_SIZE) / 2;
                                    const maxY = (drawH - CANVAS_SIZE) / 2;
                                    setOffset(o => ({
                                        x: Math.max(-maxX, Math.min(maxX, o.x)),
                                        y: Math.max(-maxY, Math.min(maxY, o.y)),
                                    }));
                                }}
                                className="flex-1 h-1.5 rounded-full accent-orange-500 cursor-pointer"
                            />
                            <button
                                onClick={() => setZoom(z => Math.min(4, z + 0.15))}
                                className="p-1.5 rounded-full hover:bg-gray-100 dark:hover:bg-gray-800 text-gray-600 dark:text-gray-300 transition-colors"
                            >
                                <ZoomIn size={18} />
                            </button>
                            <button
                                onClick={() => { setZoom(1); setOffset({ x: 0, y: 0 }); }}
                                className="p-1.5 rounded-full hover:bg-gray-100 dark:hover:bg-gray-800 text-gray-500 dark:text-gray-400 transition-colors"
                                title="Reset"
                            >
                                <RotateCcw size={16} />
                            </button>
                        </div>

                        {error && <p className="text-sm text-red-500 px-6 pb-2 text-center">{error}</p>}

                        {/* Action buttons */}
                        <div className="px-5 pb-5 flex gap-3 w-full">
                            {/* Re-select */}
                            <label className="flex-1 cursor-pointer">
                                <div className="w-full text-center py-2.5 rounded-xl bg-gray-100 dark:bg-gray-800 text-gray-900 dark:text-white text-sm font-semibold hover:bg-gray-200 dark:hover:bg-gray-700 transition-colors">
                                    Change
                                </div>
                                <input type="file" accept="image/*" onChange={handleFileChange} className="hidden" />
                            </label>
                            <button
                                type="button"
                                onClick={handleUpload}
                                className="flex-1 flex items-center justify-center gap-2 py-2.5 rounded-xl bg-gradient-to-r from-orange-500 to-pink-500 text-white text-sm font-semibold hover:opacity-90 transition-opacity shadow-md shadow-orange-200 dark:shadow-orange-900/30"
                            >
                                <Check size={16} />
                                Apply
                            </button>
                        </div>
                    </div>
                )}

                {/* ── Stage: UPLOADING ── */}
                {stage === 'uploading' && (
                    <div className="px-6 py-12 flex flex-col items-center gap-4">
                        <div className="w-16 h-16 rounded-full bg-gradient-to-br from-orange-400 to-pink-500 flex items-center justify-center animate-pulse">
                            <Upload size={28} className="text-white" />
                        </div>
                        <p className="text-sm text-gray-500 dark:text-gray-400">Uploading your photo…</p>
                        <div className="w-full h-1.5 bg-gray-100 dark:bg-gray-800 rounded-full overflow-hidden">
                            <div className="h-full bg-gradient-to-r from-orange-400 to-pink-500 rounded-full animate-[loading_1.5s_ease-in-out_infinite]" style={{ width: '60%' }} />
                        </div>
                    </div>
                )}

            </div>

            <style>{`
                @keyframes loading {
                    0% { transform: translateX(-100%); width: 60%; }
                    50% { width: 80%; }
                    100% { transform: translateX(200%); width: 60%; }
                }
            `}</style>
        </div>
    );
};

export default AvatarCropModal;
