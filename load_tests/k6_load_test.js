import http from 'k6/http';
import { check, sleep, group } from 'k6';
import { Counter, Rate, Trend } from 'k6/metrics';

// ===========================================
// SUPER APP - YÜK TESTİ
// ===========================================

// Supabase bilgileri
const SUPABASE_URL = 'https://mzgtvdgwxrlhgjboolys.supabase.co';
const SUPABASE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im16Z3R2ZGd3eHJsaGdqYm9vbHlzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjgwNTUyODUsImV4cCI6MjA4MzYzMTI4NX0.B8xL9pKDX76eVnu-s2K-TjvRyPUDx4kus85qDFWO8SY';

// Özel metrikler
const apiErrors = new Counter('api_errors');
const apiSuccess = new Rate('api_success_rate');
const dashboardLatency = new Trend('dashboard_latency');
const ordersLatency = new Trend('orders_latency');
const merchantsLatency = new Trend('merchants_latency');

// Test konfigürasyonu
export const options = {
  // Yük profili - kademeli artış
  stages: [
    { duration: '30s', target: 10 },   // Isınma: 10 kullanıcıya çık
    { duration: '1m', target: 50 },    // Orta yük: 50 kullanıcı
    { duration: '2m', target: 100 },   // Yüksek yük: 100 kullanıcı
    { duration: '1m', target: 200 },   // Stres testi: 200 kullanıcı
    { duration: '30s', target: 0 },    // Soğuma: 0'a düş
  ],

  // Başarı kriterleri
  thresholds: {
    http_req_duration: ['p(95)<2000'],     // %95 istek 2 saniyeden hızlı
    http_req_failed: ['rate<0.05'],        // %5'ten az hata
    api_success_rate: ['rate>0.95'],       // %95 başarı oranı
    dashboard_latency: ['p(95)<1000'],     // Dashboard 1 saniyeden hızlı
  },
};

// Ortak headers
const headers = {
  'apikey': SUPABASE_KEY,
  'Authorization': `Bearer ${SUPABASE_KEY}`,
  'Content-Type': 'application/json',
  'Prefer': 'return=representation',
};

// ===========================================
// TEST SENARYOLARI
// ===========================================

export default function () {

  // 1. Dashboard Stats Testi (Cache'li RPC fonksiyonu)
  group('Dashboard Stats', () => {
    const start = Date.now();
    const res = http.post(
      `${SUPABASE_URL}/rest/v1/rpc/get_dashboard_stats_cached`,
      '{}',
      { headers }
    );
    dashboardLatency.add(Date.now() - start);

    const success = check(res, {
      'dashboard status 200': (r) => r.status === 200,
      'dashboard has data': (r) => r.json() !== null,
    });

    if (!success) apiErrors.add(1);
    apiSuccess.add(success);
  });

  sleep(0.5);

  // 2. Siparişler Listesi (Pagination ile)
  group('Orders List', () => {
    const start = Date.now();
    const res = http.get(
      `${SUPABASE_URL}/rest/v1/orders?select=*&order=created_at.desc&limit=20`,
      { headers }
    );
    ordersLatency.add(Date.now() - start);

    const success = check(res, {
      'orders status 200': (r) => r.status === 200,
      'orders is array': (r) => Array.isArray(r.json()),
    });

    if (!success) apiErrors.add(1);
    apiSuccess.add(success);
  });

  sleep(0.5);

  // 3. İşletmeler Listesi (Pagination ile)
  group('Merchants List', () => {
    const start = Date.now();
    const res = http.get(
      `${SUPABASE_URL}/rest/v1/merchants?select=*&order=created_at.desc&limit=20`,
      { headers }
    );
    merchantsLatency.add(Date.now() - start);

    const success = check(res, {
      'merchants status 200': (r) => r.status === 200,
      'merchants is array': (r) => Array.isArray(r.json()),
    });

    if (!success) apiErrors.add(1);
    apiSuccess.add(success);
  });

  sleep(0.5);

  // 4. Kuryeler Listesi
  group('Couriers List', () => {
    const res = http.get(
      `${SUPABASE_URL}/rest/v1/couriers?select=*&order=created_at.desc&limit=20`,
      { headers }
    );

    const success = check(res, {
      'couriers status 200': (r) => r.status === 200,
    });

    if (!success) apiErrors.add(1);
    apiSuccess.add(success);
  });

  sleep(0.5);

  // 5. Taksi Sürücüleri
  group('Taxi Drivers List', () => {
    const res = http.get(
      `${SUPABASE_URL}/rest/v1/taxi_drivers?select=*&order=created_at.desc&limit=20`,
      { headers }
    );

    const success = check(res, {
      'taxi_drivers status 200': (r) => r.status === 200,
    });

    if (!success) apiErrors.add(1);
    apiSuccess.add(success);
  });

  sleep(0.5);

  // 6. Emlak İlanları (tablo ismi: properties)
  group('Property Listings', () => {
    const res = http.get(
      `${SUPABASE_URL}/rest/v1/properties?select=*&order=created_at.desc&limit=20`,
      { headers }
    );

    const success = check(res, {
      'properties status 200': (r) => r.status === 200,
    });

    if (!success) apiErrors.add(1);
    apiSuccess.add(success);
  });

  sleep(0.5);

  // 7. Konuşmalar (Chat)
  group('Conversations', () => {
    const res = http.get(
      `${SUPABASE_URL}/rest/v1/conversations?select=*&order=updated_at.desc&limit=20`,
      { headers }
    );

    const success = check(res, {
      'conversations status 200': (r) => r.status === 200,
    });

    if (!success) apiErrors.add(1);
    apiSuccess.add(success);
  });

  sleep(1);
}

// ===========================================
// TEST SONUÇ RAPORU
// ===========================================

export function handleSummary(data) {
  const summary = {
    test_date: new Date().toISOString(),
    total_requests: data.metrics.http_reqs.values.count,
    failed_requests: data.metrics.http_req_failed.values.passes,
    avg_response_time: data.metrics.http_req_duration.values.avg.toFixed(2) + 'ms',
    p95_response_time: data.metrics.http_req_duration.values['p(95)'].toFixed(2) + 'ms',
    max_response_time: data.metrics.http_req_duration.values.max.toFixed(2) + 'ms',
    requests_per_second: data.metrics.http_reqs.values.rate.toFixed(2),
    dashboard_p95: data.metrics.dashboard_latency ? data.metrics.dashboard_latency.values['p(95)'].toFixed(2) + 'ms' : 'N/A',
    orders_p95: data.metrics.orders_latency ? data.metrics.orders_latency.values['p(95)'].toFixed(2) + 'ms' : 'N/A',
    merchants_p95: data.metrics.merchants_latency ? data.metrics.merchants_latency.values['p(95)'].toFixed(2) + 'ms' : 'N/A',
  };

  return {
    'stdout': textSummary(data, { indent: ' ', enableColors: true }),
    'load_test_results.json': JSON.stringify(summary, null, 2),
  };
}

import { textSummary } from 'https://jslib.k6.io/k6-summary/0.0.1/index.js';
