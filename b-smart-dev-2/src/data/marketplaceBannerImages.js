import banner1 from '../assets/marketplace_banner/optimized/1.webp';
import banner2 from '../assets/marketplace_banner/optimized/2.webp';
import banner3 from '../assets/marketplace_banner/optimized/3.webp';
import banner4 from '../assets/marketplace_banner/optimized/4.webp';
import categoryFashion from '../assets/marketplace_category/optimized/1.webp';
import categoryTech from '../assets/marketplace_category/optimized/2.webp';

// Real photo assets (see src/assets/marketplace_banner, marketplace_category).
// Products = 1 & 2, Services = 3 & 4. Marketplace + Category pages share all four.
export const PRODUCT_BANNER_IMAGES = [banner1, banner2];
export const SERVICE_BANNER_IMAGES = [banner3, banner4];
export const MARKETPLACE_BANNER_IMAGES = [banner1, banner2, banner3, banner4];

// Only Fashion and Tech have a dedicated category photo today — other
// categories fall back to their icon tile (see CATEGORY_STYLE).
export const CATEGORY_IMAGE = {
  Fashion: categoryFashion,
  Tech: categoryTech,
};
