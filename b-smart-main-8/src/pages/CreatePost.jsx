import React, { useState, useRef } from 'react';
import { Image, Video, X, Maximize2, ZoomIn, Megaphone } from 'lucide-react';
import Cropper from 'react-easy-crop';
import { useNavigate } from 'react-router-dom';

const CreatePost = () => {
  const navigate = useNavigate();
  const fileInputRef = useRef(null);
  const [postType, setPostType] = useState('post');
  const [caption, setCaption] = useState('');
  const [mediaType, setMediaType] = useState(null);
  const [sourceUrl, setSourceUrl] = useState(null);
  const [coverUrl, setCoverUrl] = useState(null);
  const [aspect, setAspect] = useState(1);
  const [originalAspect, setOriginalAspect] = useState(null);
  const [crop, setCrop] = useState({ x: 0, y: 0 });
  const [zoom, setZoom] = useState(1);
  
  const [showRatioMenu, setShowRatioMenu] = useState(false);
  const [showZoomSlider, setShowZoomSlider] = useState(false);

  const handleFileSelect = async (e) => {
    const file = e.target.files && e.target.files[0];
    if (!file) return;
    const url = URL.createObjectURL(file);
    if (file.type.startsWith('image/')) {
      setMediaType('image');
      setSourceUrl(url);
      setCoverUrl(null);
      setZoom(1);
      setCrop({ x: 0, y: 0 });
      try {
        const img = await new Promise((resolve, reject) => {
          const i = new Image();
          i.onload = () => resolve(i);
          i.onerror = reject;
          i.src = url;
        });
        const oa = img.width / img.height;
        setOriginalAspect(oa);
        setAspect(oa);
      } catch {
        setOriginalAspect(1);
        setAspect(1);
      }
    } else if (file.type.startsWith('video/')) {
      setMediaType('video');
      setSourceUrl(url);
      setZoom(1);
      setCrop({ x: 0, y: 0 });
      const v = document.createElement('video');
      v.src = url;
      await new Promise((resolve) => {
        v.onloadedmetadata = resolve;
      });
      const oa = (v.videoWidth && v.videoHeight) ? (v.videoWidth / v.videoHeight) : 1;
      setOriginalAspect(oa);
      setAspect(oa);
      const canvas = document.createElement('canvas');
      const ctx = canvas.getContext('2d');
      canvas.width = v.videoWidth || 640;
      canvas.height = v.videoHeight || 360;
      await new Promise((res) => {
        v.currentTime = 0;
        v.onseeked = res;
      });
      ctx.drawImage(v, 0, 0, canvas.width, canvas.height);
      const frameUrl = canvas.toDataURL('image/jpeg', 0.9);
      setCoverUrl(frameUrl);
    }
  };

  return (
    <div className="bg-white dark:bg-black min-h-screen pt-4 px-4 pb-20 transition-colors duration-200">
      <h2 className="text-xl font-bold mb-4 text-center text-gray-900 dark:text-white">{postType === 'reel' ? 'New Reel' : 'New Post'}</h2>
      
      {!sourceUrl ? (
        <div className="w-full aspect-square bg-gray-100 dark:bg-gray-900 rounded-lg flex flex-col items-center justify-center border-2 border-dashed border-gray-300 dark:border-gray-800">
          <Image size={48} className="text-gray-400 dark:text-gray-600 mb-2" />
          <button
            onClick={() => fileInputRef.current?.click()}
            className="text-blue-500 font-semibold hover:text-blue-400"
          >
            Select from Computer
          </button>
          <input ref={fileInputRef} type="file" className="hidden" accept="image/*,video/*" onChange={handleFileSelect} />
          <div className="mt-6">
            <div className="bg-white dark:bg-gray-800 rounded-xl shadow-lg border border-gray-200 dark:border-gray-700 p-2 w-60">
              <button
                onClick={() => setPostType('post')}
                className="flex items-center gap-3 w-full p-3 hover:bg-gray-50 dark:hover:bg-gray-700 rounded-lg transition-colors text-left"
              >
                <Image size={20} className="text-purple-600" />
                <span className="font-semibold text-gray-700 dark:text-gray-200">Create Post</span>
              </button>
              <div className="h-px bg-gray-100 dark:bg-gray-700 mx-2" />
              <button
                onClick={() => setPostType('reel')}
                className="flex items-center gap-3 w-full p-3 hover:bg-gray-50 dark:hover:bg-gray-700 rounded-lg transition-colors text-left"
              >
                <Video size={20} className="text-pink-600" />
                <span className="font-semibold text-gray-700 dark:text-gray-200">Upload Reel</span>
              </button>
              <div className="h-px bg-gray-100 dark:bg-gray-700 mx-2" />
              <button
                onClick={() => navigate('/ads')}
                className="flex items-center gap-3 w-full p-3 hover:bg-gray-50 dark:hover:bg-gray-700 rounded-lg transition-colors text-left"
              >
                <Megaphone size={20} className="text-blue-600" />
                <span className="font-semibold text-gray-700 dark:text-gray-200">Upload Ad</span>
              </button>
            </div>
          </div>
        </div>
      ) : (
        <div className="relative w-full aspect-square bg-black rounded-lg overflow-hidden">
          {mediaType === 'video' ? (
            <Cropper
              image={coverUrl || sourceUrl}
              crop={crop}
              zoom={zoom}
              aspect={aspect || 1}
              onCropChange={(c) => setCrop(c)}
              onCropComplete={() => {}}
              onZoomChange={(z) => setZoom(z)}
              objectFit="contain"
              showGrid={false}
              style={{
                containerStyle: { background: 'transparent' },
                cropAreaStyle: { border: '1px solid rgba(255, 255, 255, 0.5)' }
              }}
            />
          ) : (
            <Cropper
              image={sourceUrl}
              crop={crop}
              zoom={zoom}
              aspect={aspect || 1}
              onCropChange={(c) => setCrop(c)}
              onCropComplete={() => {}}
              onZoomChange={(z) => setZoom(z)}
              objectFit="contain"
              showGrid={false}
              style={{
                containerStyle: { background: 'transparent' },
                cropAreaStyle: { border: '1px solid rgba(255, 255, 255, 0.5)' }
              }}
            />
          )}
          <button
            onClick={() => {
              setSourceUrl(null);
              setCoverUrl(null);
              setMediaType(null);
              setZoom(1);
              setCrop({ x: 0, y: 0 });
            }}
            className="absolute top-2 right-2 bg-black/50 p-1 rounded-full text-white hover:bg-black/70 transition-colors"
          >
            <X size={20} />
          </button>
          <div className="absolute bottom-4 left-4 flex gap-3 z-30">
            <div className="relative">
              {showRatioMenu && (
                <div className="absolute bottom-full left-0 mb-2 bg-black/80 backdrop-blur-sm rounded-lg overflow-hidden flex flex-col w-32 shadow-xl">
                  <button onClick={() => { setAspect(originalAspect || 1); setShowRatioMenu(false); setZoom(1); setCrop({ x: 0, y: 0 }); }} className={`flex items-center gap-3 px-4 py-3 text-sm font-medium hover:bg-white/10 ${aspect === originalAspect ? 'text-white' : 'text-gray-400'}`}><Image size={18} /> Original</button>
                  <button onClick={() => { setAspect(1); setShowRatioMenu(false); setZoom(1); setCrop({ x: 0, y: 0 }); }} className={`flex items-center gap-3 px-4 py-3 text-sm font-medium hover:bg-white/10 ${aspect === 1 ? 'text-white' : 'text-gray-400'}`}><span className="w-5 h-5 border-2 border-current rounded-sm"></span> 1:1</button>
                  <button onClick={() => { setAspect(4 / 5); setShowRatioMenu(false); setZoom(1); setCrop({ x: 0, y: 0 }); }} className={`flex items-center gap-3 px-4 py-3 text-sm font-medium hover:bg-white/10 ${aspect === 0.8 ? 'text-white' : 'text-gray-400'}`}><span className="w-4 h-5 border-2 border-current rounded-sm"></span> 4:5</button>
                  <button onClick={() => { setAspect(16 / 9); setShowRatioMenu(false); setZoom(1); setCrop({ x: 0, y: 0 }); }} className={`flex items-center gap-3 px-4 py-3 text-sm font-medium hover:bg-white/10 ${aspect === 16 / 9 ? 'text-white' : 'text-gray-400'}`}><span className="w-5 h-3 border-2 border-current rounded-sm"></span> 16:9</button>
                </div>
              )}
              <button onClick={() => { setShowRatioMenu(!showRatioMenu); setShowZoomSlider(false); }} className={`w-8 h-8 rounded-full ${showRatioMenu ? 'bg-white text-black' : 'bg-black/70 text-white'} hover:bg-white hover:text-black flex items-center justify-center transition-colors`}><Maximize2 size={16} /></button>
            </div>
          </div>
          <div className="absolute bottom-4 right-4 flex gap-3 z-30">
            <div className="relative">
              {showZoomSlider && (
                <div className="absolute bottom-full right-0 mb-2 p-3 bg-black/80 backdrop-blur-sm rounded-lg shadow-xl w-32">
                  <input type="range" min={1} max={3} step={0.1} value={zoom} onChange={(e) => setZoom(Number(e.target.value))} className="w-full h-1 bg-gray-600 rounded-lg appearance-none cursor-pointer accent-white" />
                </div>
              )}
              <button onClick={() => { setShowZoomSlider(!showZoomSlider); setShowRatioMenu(false); }} className={`w-8 h-8 rounded-full ${showZoomSlider ? 'bg-white text-black' : 'bg-black/70 text-white'} hover:bg-white hover:text-black flex items-center justify-center transition-colors`}><ZoomIn size={16} /></button>
            </div>
          </div>
        </div>
      )}

      <div className="mt-4">
        <textarea
          className="w-full p-3 border border-gray-300 dark:border-gray-800 rounded-lg resize-none focus:outline-none focus:border-gray-500 dark:focus:border-gray-600 bg-white dark:bg-black text-gray-900 dark:text-white placeholder-gray-400 dark:placeholder-gray-600"
          rows="4"
          placeholder="Write a caption..."
          value={caption}
          onChange={(e) => setCaption(e.target.value)}
        ></textarea>
      </div>

      <button className="w-full mt-4 bg-blue-500 text-white font-bold py-3 rounded-lg hover:bg-blue-600 transition">
        Share
      </button>
    </div>
  );
};

export default CreatePost;
