import assert from 'node:assert/strict';
import React from 'react';
import { renderToStaticMarkup } from 'react-dom/server';
import { Provider } from 'react-redux';
import { MemoryRouter, Routes, Route } from 'react-router-dom';
import { configureStore } from '@reduxjs/toolkit';
import { createServer } from 'vite';

const vite = await createServer({ server: { middlewareMode: true }, appType: 'custom' });
try {
  const { default: orders, updateOrderFulfillment, shipOrder, canShipOrder } = await vite.ssrLoadModule('/src/store/ordersSlice.js');
  const { default: products } = await vite.ssrLoadModule('/src/store/productsSlice.js');
  const { default: Orders } = await vite.ssrLoadModule('/src/myStore/pages/Orders.jsx');
  const { filterOrders } = await vite.ssrLoadModule('/src/myStore/data/orderFilters.js');
  const store = configureStore({ reducer: { orders, products } });
  const all = store.getState().orders.items;
  assert.equal(filterOrders(all).length, 2);
  assert.equal(filterOrders(all, { tab: 'Completed' }).length, 3);
  assert.equal(filterOrders(all, { tab: 'Completed', payment: 'Refunded' }).length, 1);
  assert.equal(filterOrders(all, { search: 'rahul' })[0].id, 'ORD-1045');
  assert.equal(filterOrders(all, { from: '2026-09-06', to: '2026-09-08' }).length, 1);
  assert.equal(filterOrders(all, { oldest: true })[0].id, 'ORD-1045');
  const getOrder = () => store.getState().orders.items.find((order) => order.id === 'ORD-1045');
  store.dispatch(shipOrder('ORD-1045'));
  assert.equal(getOrder().status, 'Pending');
  store.dispatch(updateOrderFulfillment({ id: 'ORD-1045', packed: true }));
  assert.equal(getOrder().packed, false);
  store.dispatch(updateOrderFulfillment({ id: 'ORD-1045', confirmed: true, packed: true, courier: 'Delhivery', trackingNumber: '  ' }));
  assert.equal(getOrder().status, 'Processing');
  assert.equal(canShipOrder(getOrder()), false);
  store.dispatch(updateOrderFulfillment({ id: 'ORD-1045', trackingNumber: ' TEST123 ', notifyCustomer: false }));
  assert.equal(canShipOrder(getOrder()), true);
  store.dispatch(shipOrder('ORD-1045'));
  assert.equal(getOrder().status, 'Shipped');
  assert.equal(getOrder().trackingNumber, 'TEST123');
  store.dispatch(updateOrderFulfillment({ id: 'ORD-1045', confirmed: false }));
  assert.equal(getOrder().confirmed, true);
  store.dispatch(shipOrder('ORD-1046'));
  assert.equal(store.getState().orders.items.find((order) => order.id === 'ORD-1046').status, 'Cancelled');
  const render = (path) => renderToStaticMarkup(React.createElement(Provider, { store },
    React.createElement(MemoryRouter, { initialEntries: [path] },
      React.createElement(Routes, null,
        React.createElement(Route, { path: '/orders', element: React.createElement(Orders) }),
        React.createElement(Route, { path: '/orders/:orderId', element: React.createElement(Orders) }),
      ),
    ),
  ));
  const list = render('/orders');
  assert.ok(list.includes('Search orders') && list.includes('View order') && list.includes('All dates'));
  const detail = render('/orders/ORD-1045');
  assert.ok(detail.includes('Order details') && detail.includes('Delivery address') && detail.includes('Order shipped') && detail.includes('TEST123'));
  const pending = render('/orders/ORD-1049');
  assert.ok(pending.includes('Confirm items') && pending.includes('Mark as shipped') && pending.includes('Tracking number'));
  assert.ok(render('/orders/unknown').includes('Order not found'));
  console.log('PASS: order filters, sorting, fulfillment guards, shipping transition, list/detail rendering, and missing-order fallback.');
} finally {
  await vite.close();
}
