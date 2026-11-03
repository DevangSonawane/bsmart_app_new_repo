import React, { useState, useRef, useCallback, useEffect } from 'react';
import { X, Upload, ZoomIn, ZoomOut, RotateCcw, Check } from 'lucide-react';
import api from '../lib/api';

/**
 * CoverImageCropModal
 * Props:
 *   isOpen        - boolean
 *   onClose       - () => void
 *   onSuccess     - (newCoverUrl: string) => void   called after successful upload
 *   userId        - string         (for vendor profile endpoint)
 */
const CoverImageCropModal = ({ isOpen, onClose, onSuccess, userId }) => {
    const [stage, setStage] = useState('select');
    const [rawImage, setRawImage] = useState(null);
    const [error, setError] = useState('');
    const [zoom, setZoom] = useState(1);
    const [offset, setOffset] = useState({ x: 0, y: 0 });
    const [dragging, setDragging] = useState(false);
    const dragStart = useRef({ x: 0, y: 0, ox: 0, oy: 0 });
    const canvasRef = useRef(null);
    const imgRef = useRef(null);

    const CANVAS_WIDTH = 600;
    const CANVAS_HEIGHT = 200; // 3:1 Aspect Ratio

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
        ctx.clearRect(0, 0, CANVAS_WIDTH, CANVAS_HEIGHT);

        const baseScale = Math.max(CANVAS_WIDTH / img.naturalWidth, CANVAS_HEIGHT / img.naturalHeight);
        const scale = baseScale * zoom;
        const drawW = img.naturalWidth * scale;
        const drawH = img.naturalHeight * scale;

        const x = (CANVAS_WIDTH - drawW) / 2 + offset.x;
        const y = (CANVAS_HEIGHT - drawH) / 2 + offset.y;

        ctx.drawImage(img, x, y, drawW, drawH);
    }, [zoom, offset]);

    useEffect(() => {
        if (stage !== 'crop' || !canvasRef.current || !imgRef.current) return;
        drawCanvas();
    }, [drawCanvas, stage, rawImage]);

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

        const img = imgRef.current;
        if (!img) return;
        const baseScale = Math.max(CANVAS_WIDTH / img.naturalWidth, CANVAS_HEIGHT / img.naturalHeight);
        const scale = baseScale * zoom;
        const drawW = img.naturalWidth * scale;
        const drawH = img.naturalHeight * scale;
        const maxX = (drawW - CANVAS_WIDTH) / 2;
        const maxY = (drawH - CANVAS_HEIGHT) / 2;

        setOffset({
            x: Math.max(-maxX, Math.min(maxX, dragStart.current.ox + dx)),
            y: Math.max(-maxY, Math.min(maxY, dragStart.current.oy + dy)),
        });
    }, [dragging, zoom]);

    const onPointerUp = () => setDragging(false);

    const onWheel = (e) => {
        e.preventDefault();
        const delta = e.deltaY < 0 ? 0.08 : -0.08;
        setZoom(z => Math.max(1, Math.min(4, z + delta)));
    };

    const handleUpload = async () => {
        setStage('uploading');
        setError('');
        try {
            const canvas = canvasRef.current;
            const blob = await new Promise((res) => canvas.toBlob(res, 'image/jpeg', 0.92));

            const formData = new FormData();
            formData.append('files', blob, 'cover.jpg');

            const response = await api.post(`/vendors/profile/${userId}/cover-image`, formData, {
                headers: { 'Content-Type': 'multipart/form-data' },
            });

            const data = response.data;
            // The API documentation shows 'files' as an array. Let's handle both single and array responses.
            const newUrl = 
                (Array.isArray(data?.cover_image_urls) ? data.cover_image_urls[0] : null) ||
                data?.cover_image_url || 
                data?.url || 
                data?.data?.cover_image_url || 
                data?.avatar_url;
            onSuccess(newUrl);
            resetState();
            onClose();
        } catch (err) {
            setError(err?.response?.data?.message || 'Upload failed. Please try again.');
            setStage('crop');
        }
    };

    if (!isOpen) return null;

    return (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 backdrop-blur-sm p-4">
            <div className="w-full max-w-2xl bg-white dark:bg-gray-950 rounded-2xl shadow-2xl border border-gray-200 dark:border-gray-800 overflow-hidden">
                <div className="flex items-center justify-between px-5 py-4 border-b border-gray-100 dark:border-gray-800">
                    <h3 className="text-base font-semibold text-gray-900 dark:text-white">
                        {stage === 'select' ? 'Add Cover Photo' : stage === 'uploading' ? 'Uploading…' : 'Adjust Photo'}
                    </h3>
                    <button
                        type="button"
                        onClick={() => { resetState(); onClose(); }}
                        disabled={stage === 'uploading'}
                        className="p-1.5 rounded-full hover:bg-gray-100 dark:hover:bg-gray-800 text-gray-600 dark:text-gray-300 transition-colors"
                    >
                        <X size={18} />
                    </button>
                </div>

                {stage === 'select' && (
                    <div className="px-6 py-12 flex flex-col items-center gap-6">
                        <div className="w-full h-40 rounded-2xl border-2 border-dashed border-gray-200 dark:border-gray-800 flex items-center justify-center bg-gray-50 dark:bg-gray-900/50">
                            <Upload size={32} className="text-gray-300" />
                        </div>
                        <p className="text-sm text-gray-500 dark:text-gray-400 text-center">
                            Select a high-quality photo to set as your cover image
                        </p>
                        <label className="cursor-pointer w-full max-w-xs">
                            <div className="w-full flex items-center justify-center gap-2 px-4 py-3 rounded-xl bg-gradient-to-r from-orange-500 to-pink-500 text-white text-sm font-semibold hover:opacity-90 transition-opacity shadow-md">
                                <Upload size={16} />
                                Select Image
                            </div>
                            <input type="file" accept="image/*" onChange={handleFileChange} className="hidden" />
                        </label>
                        {error && <p className="text-sm text-red-500 text-center">{error}</p>}
                    </div>
                )}

                {stage === 'crop' && (
                    <div className="flex flex-col items-center">
                        <p className="text-xs text-gray-400 dark:text-gray-500 py-3 text-center px-4">
                            Drag to reposition · Scroll or pinch to zoom
                        </p>
                        <div className="relative flex items-center justify-center bg-gray-900 w-full py-8 overflow-hidden">
                            <canvas
                                ref={canvasRef}
                                width={CANVAS_WIDTH}
                                height={CANVAS_HEIGHT}
                                className="cursor-grab active:cursor-grabbing touch-none select-none border-2 border-white/20"
                                onPointerDown={onPointerDown}
                                onPointerMove={onPointerMove}
                                onPointerUp={onPointerUp}
                                onPointerLeave={onPointerUp}
                                onWheel={onWheel}
                            />
                        </div>
                        <div className="flex items-center gap-4 px-8 py-6 w-full">
                            <ZoomOut size={18} className="text-gray-400" />
                            <input
                                type="range" min="100" max="400" step="1"
                                value={Math.round(zoom * 100)}
                                onChange={e => setZoom(parseInt(e.target.value) / 100)}
                                className="flex-1 h-1.5 bg-gray-200 dark:bg-gray-800 rounded-lg appearance-none cursor-pointer accent-pink-500"
                            />
                            <ZoomIn size={18} className="text-gray-400" />
                        </div>
                        <div className="flex gap-3 px-8 pb-6 w-full">
                            <button
                                onClick={resetState}
                                className="flex-1 px-4 py-2.5 rounded-xl border border-gray-200 dark:border-gray-800 text-sm font-bold text-gray-600 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-900 transition-colors"
                            >
                                Cancel
                            </button>
                            <button
                                onClick={handleUpload}
                                className="flex-1 px-4 py-2.5 rounded-xl bg-gradient-to-r from-orange-500 to-pink-500 text-white text-sm font-bold shadow-lg shadow-pink-500/20 hover:opacity-90 transition-opacity"
                            >
                                Save Photo
                            </button>
                        </div>
                    </div>
                )}

                {stage === 'uploading' && (
                    <div className="px-6 py-20 flex flex-col items-center gap-4">
                        <div className="w-10 h-10 border-4 border-pink-500 border-t-transparent rounded-full animate-spin" />
                        <p className="text-sm font-semibold text-gray-900 dark:text-white">Uploading your cover photo…</p>
                    </div>
                )}
            </div>
        </div>
    );
};

export default CoverImageCropModal;
