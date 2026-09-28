import assert from 'node:assert/strict';
import React from 'react';
import { renderToStaticMarkup } from 'react-dom/server';
import { Provider } from 'react-redux';
import { MemoryRouter } from 'react-router-dom';
import { configureStore } from '@reduxjs/toolkit';
import { createServer } from 'vite';

const vite = await createServer({ server: { middlewareMode: true }, appType: 'custom' });
try {
  const { default: Profile } = await vite.ssrLoadModule('/src/myStore/pages/Profile.jsx');
  const { default: Sidebar } = await vite.ssrLoadModule('/src/myStore/components/StoreSidebar.jsx');
  const { default: products } = await vite.ssrLoadModule('/src/store/productsSlice.js');
  const { default: services } = await vite.ssrLoadModule('/src/store/servicesSlice.js');
  const { default: cart, addItem } = await vite.ssrLoadModule('/src/store/cartSlice.js');
  const store = configureStore({ reducer: { products, services, cart, auth: () => ({ userObject: null }) } });
  const render = (component, tab = 'All') => renderToStaticMarkup(React.createElement(Provider, { store }, React.createElement(MemoryRouter, { initialEntries: [`/market/my-store/profile?tab=${tab}`] }, React.createElement(component))));
  const all = render(Profile);
  assert.ok(all.includes('aria-label="All listings"'));
  assert.ok(!all.includes('aria-label="Services"') && !all.includes('aria-label="Products"'));
  assert.ok(all.includes('Installation Service') && all.includes('Classic Brown Leather Tote'));
  assert.ok(!all.includes('<header'));
  const service = render(Profile, 'Services');
  assert.ok(service.includes('Installation Service') && !service.includes('Classic Brown Leather Tote'));
  const product = render(Profile, 'Products');
  const header = (html) => html.match(/<section aria-label="Store profile"[\s\S]*?<\/section>/)?.[0];
  assert.ok(header(all));
  assert.equal(header(all), header(service));
  assert.equal(header(all), header(product));
  assert.ok(header(product).includes('Follow'));
  assert.ok(product.includes('Classic Brown Leather Tote') && !product.includes('Installation Service'));
  assert.ok(product.includes('Search products') && product.includes('Recommended'));
  store.dispatch(addItem({ id: 1, name: 'Test product', price: 25 }));
  assert.ok(render(Profile, 'Products').includes('My Cart, 1 item'));
  assert.ok(render(Sidebar).includes('/market/my-store/profile'));
  assert.ok(all.includes('min-[900px]:grid-cols-3') && product.includes('min-[900px]:grid-cols-4') && all.includes('min-w-0'));
  console.log('PASS: single-page All/Services/Products views, profile sidebar link, cart state, grid classes, and no profile-specific header.');
} finally { await vite.close(); }
