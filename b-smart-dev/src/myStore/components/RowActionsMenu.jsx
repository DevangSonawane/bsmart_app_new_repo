import React, { useEffect, useLayoutEffect, useRef, useState } from 'react';
import { createPortal } from 'react-dom';
import { MoreVertical } from 'lucide-react';

const MENU_GAP = 8;
const VIEWPORT_GAP = 12;

export default function RowActionsMenu({ ariaLabel = 'More actions', children, menuClassName = 'w-44' }) {
  const [open, setOpen] = useState(false);
  const [position, setPosition] = useState({ top: 0, left: 0 });
  const buttonRef = useRef(null);
  const menuRef = useRef(null);

  const updatePosition = () => {
    const button = buttonRef.current;
    if (!button) return;

    const rect = button.getBoundingClientRect();
    const menu = menuRef.current;
    const menuWidth = menu?.offsetWidth || 176;
    const menuHeight = menu?.offsetHeight || 120;
    const spaceBelow = window.innerHeight - rect.bottom - VIEWPORT_GAP;
    const opensUp = spaceBelow < menuHeight && rect.top > menuHeight;
    const top = opensUp ? rect.top - menuHeight - MENU_GAP : rect.bottom + MENU_GAP;
    const left = Math.min(
      Math.max(VIEWPORT_GAP, rect.right - menuWidth),
      window.innerWidth - menuWidth - VIEWPORT_GAP,
    );

    setPosition({ top: Math.max(VIEWPORT_GAP, top), left });
  };

  useLayoutEffect(() => {
    if (open) updatePosition();
  }, [open]);

  useEffect(() => {
    if (!open) return undefined;

    const handlePointerDown = (event) => {
      if (buttonRef.current?.contains(event.target) || menuRef.current?.contains(event.target)) return;
      setOpen(false);
    };
    const handleKeyDown = (event) => {
      if (event.key === 'Escape') setOpen(false);
    };

    updatePosition();
    document.addEventListener('mousedown', handlePointerDown);
    document.addEventListener('keydown', handleKeyDown);
    window.addEventListener('resize', updatePosition);
    window.addEventListener('scroll', updatePosition, true);

    return () => {
      document.removeEventListener('mousedown', handlePointerDown);
      document.removeEventListener('keydown', handleKeyDown);
      window.removeEventListener('resize', updatePosition);
      window.removeEventListener('scroll', updatePosition, true);
    };
  }, [open]);

  const close = () => setOpen(false);

  return (
    <>
      <button
        ref={buttonRef}
        type="button"
        aria-label={ariaLabel}
        aria-haspopup="menu"
        aria-expanded={open}
        onClick={() => setOpen((value) => !value)}
        className="inline-flex h-9 w-9 items-center justify-center rounded-lg border border-gray-200 text-gray-500 transition-colors hover:border-[#fa3f5e]/40 hover:text-[#fa3f5e] dark:border-gray-800 dark:text-gray-300"
      >
        <MoreVertical size={16} />
      </button>
      {open && createPortal(
        <div
          ref={menuRef}
          role="menu"
          style={{ top: position.top, left: position.left }}
          className={`fixed z-[9999] overflow-hidden rounded-xl border border-gray-100 bg-white py-1.5 text-left shadow-xl dark:border-gray-800 dark:bg-gray-900 ${menuClassName}`}
        >
          {typeof children === 'function' ? children(close) : children}
        </div>,
        document.body,
      )}
    </>
  );
}
