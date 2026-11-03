import React, { useEffect, useRef, useState } from 'react';
import { createPortal } from 'react-dom';
import { Link } from 'react-router-dom';
import { useDispatch } from 'react-redux';
import { MoreVertical, Pencil, Trash2, Eye, EyeOff } from 'lucide-react';
import { useFloating, autoUpdate, offset, flip, shift } from '@floating-ui/react-dom';
import { deleteService, updateService } from '../../store/servicesSlice';

export default function ServiceActions({ service }) {
  const dispatch = useDispatch();
  const [open, setOpen] = useState(false);
  const menuRef = useRef(null);
  const buttonRef = useRef(null);
  const { refs, floatingStyles } = useFloating({
    open, onOpenChange: setOpen, placement: 'bottom-end', whileElementsMounted: autoUpdate,
    middleware: [offset(4), flip(), shift({ padding: 8 })],
  });
  useEffect(() => {
    if (!open) return;
    const close = (event) => {
      if (!buttonRef.current?.contains(event.target) && !menuRef.current?.contains(event.target)) setOpen(false);
    };
    const escape = (event) => {
      if (event.key === 'Escape') { setOpen(false); buttonRef.current?.focus(); }
    };
    document.addEventListener('mousedown', close);
    document.addEventListener('keydown', escape);
    return () => { document.removeEventListener('mousedown', close); document.removeEventListener('keydown', escape); };
  }, [open]);
  const itemCls = 'w-full flex items-center gap-2 px-3.5 py-2.5 text-sm text-gray-700 dark:text-gray-200 hover:bg-gray-50 dark:hover:bg-gray-800';
  return (
    <>
      <button ref={(node) => { refs.setReference(node); buttonRef.current = node; }} type="button" aria-label={`More actions for ${service.name}`} aria-expanded={open} onClick={() => setOpen(!open)} className="w-8 h-8 rounded-lg flex items-center justify-center text-gray-400 hover:bg-gray-100 dark:hover:bg-gray-800"><MoreVertical size={16} /></button>
      {open && createPortal(
        <div ref={(node) => { refs.setFloating(node); menuRef.current = node; }} style={floatingStyles} className="w-40 bg-white dark:bg-gray-900 border border-gray-100 dark:border-gray-800 rounded-xl shadow-xl z-50 overflow-hidden">
          <Link to={`/market/edit-service/${service.id}`} className={itemCls}><Pencil size={13} /> Edit</Link>
          {service.status === 'Published' && <button type="button" className={itemCls} onClick={() => { dispatch(updateService({ id: service.id, visible: !service.visible })); setOpen(false); }}>{service.visible ? <EyeOff size={13} /> : <Eye size={13} />}{service.visible ? 'Hide service' : 'Show service'}</button>}
          <button type="button" className="w-full flex items-center gap-2 px-3.5 py-2.5 text-sm text-red-500 hover:bg-red-50 dark:hover:bg-red-900/20" onClick={() => {
            setOpen(false);
            if (window.confirm(`Remove "${service.name}" from your store?`)) dispatch(deleteService(service.id));
          }}><Trash2 size={13} /> Delete</button>
        </div>, document.body,
      )}
    </>
  );
}
