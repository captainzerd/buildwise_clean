// functions/src/marketPricesUpdater.ts
import { onSchedule } from 'firebase-functions/v2/scheduler';
import * as admin from 'firebase-admin';

// Seeded Ghana construction material prices (GHS, Accra market, Q1 2026)
const SEED_PRICES = [
  { name: 'Cement (50kg bag)', unit: 'bag', priceGhs: 85.0, category: 'Masonry' },
  { name: 'Steel rod 12mm (tonne)', unit: 'tonne', priceGhs: 8500.0, category: 'Structure' },
  { name: 'Sharp sand (tipper)', unit: 'tipper', priceGhs: 1200.0, category: 'Aggregate' },
  { name: 'Gravel (tipper)', unit: 'tipper', priceGhs: 1400.0, category: 'Aggregate' },
  { name: 'Burnt bricks (1000)', unit: '1000 pcs', priceGhs: 1800.0, category: 'Masonry' },
  { name: 'Hollow blocks 6" (each)', unit: 'each', priceGhs: 6.5, category: 'Masonry' },
  { name: 'Plywood 3/4" sheet', unit: 'sheet', priceGhs: 320.0, category: 'Timber' },
  { name: 'Roofing sheet (long span, m²)', unit: 'm²', priceGhs: 85.0, category: 'Roofing' },
  { name: 'Ceramic floor tile (m²)', unit: 'm²', priceGhs: 120.0, category: 'Finishes' },
  { name: 'Emulsion paint (20L)', unit: '20L tin', priceGhs: 380.0, category: 'Finishes' },
];

export const refreshMarketPrices = onSchedule(
  { schedule: '0 6 * * *', region: 'europe-west1' },
  async () => {
  const db = admin.firestore();
  await db.collection('market_prices').doc('ghana_current').set({
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    currency: 'GHS',
    items: SEED_PRICES,
  });
});
