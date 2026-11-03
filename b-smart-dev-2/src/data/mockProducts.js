// Placeholder until Market is wired to a real product/vendor data source.
export const MOCK_PRODUCTS = [];

export const getProductById = (id) => MOCK_PRODUCTS.find((p) => String(p.id) === String(id));
