#!/usr/bin/env node
/**
 * Uploads data/inventory/inventory.csv to Omnichannel Inventory (OCI).
 *
 * CSV columns: ProductName,SKU,LocationIdentifier,OnHand,SafetyStock
 * OnHand is absolute (replaces the current level). ProductName is for humans only.
 *
 * Usage: node scripts/upload-inventory.js [targetOrg] [csvPath]
 *   targetOrg defaults to vscodeOrg, csvPath to data/inventory/inventory.csv
 */
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const { execSync } = require('child_process');

const targetOrg = process.argv[2] || 'vscodeOrg';
const csvPath = process.argv[3] || path.join(__dirname, '..', 'data', 'inventory', 'inventory.csv');

function parseCsv(text) {
  const rows = [];
  let row = [], field = '', inQuotes = false;
  for (let i = 0; i < text.length; i++) {
    const c = text[i];
    if (inQuotes) {
      if (c === '"' && text[i + 1] === '"') { field += '"'; i++; }
      else if (c === '"') inQuotes = false;
      else field += c;
    } else if (c === '"') inQuotes = true;
    else if (c === ',') { row.push(field); field = ''; }
    else if (c === '\n' || c === '\r') {
      if (c === '\r' && text[i + 1] === '\n') i++;
      row.push(field); field = '';
      if (row.some(v => v !== '')) rows.push(row);
      row = [];
    } else field += c;
  }
  row.push(field);
  if (row.some(v => v !== '')) rows.push(row);
  return rows;
}

function buildNdjson(records) {
  const byLocation = new Map();
  for (const r of records) {
    if (!byLocation.has(r.location)) byLocation.set(r.location, []);
    byLocation.get(r.location).push(r);
  }
  const effectiveDate = new Date().toISOString();
  const lines = [];
  for (const [location, items] of byLocation) {
    lines.push(JSON.stringify({ location, mode: 'UPDATE' }));
    for (const r of items) {
      lines.push(JSON.stringify({
        recordId: crypto.randomUUID(),
        sku: r.sku,
        onHand: r.onHand,
        safetyStockCount: r.safetyStock,
        effectiveDate,
        futures: [],
      }));
    }
  }
  return lines.join('\n') + '\n';
}

function readRecords() {
  const [header, ...rows] = parseCsv(fs.readFileSync(csvPath, 'utf8').replace(/^﻿/, ''));
  const col = name => {
    const i = header.indexOf(name);
    if (i < 0) throw new Error(`CSV is missing column ${name}`);
    return i;
  };
  const [sku, loc, onHand, safety] = ['SKU', 'LocationIdentifier', 'OnHand', 'SafetyStock'].map(col);
  const seen = new Set();
  return rows.map((r, n) => {
    const rec = {
      sku: r[sku].trim(),
      location: r[loc].trim(),
      onHand: Number(r[onHand]),
      safetyStock: Number(r[safety] || 0),
    };
    const key = rec.location + '|' + rec.sku;
    if (!rec.sku || !rec.location || !Number.isFinite(rec.onHand) || !Number.isFinite(rec.safetyStock)) {
      throw new Error(`Row ${n + 2} is invalid: ${r.join(',')}`);
    }
    if (seen.has(key)) throw new Error(`Row ${n + 2} duplicates SKU ${rec.sku} at ${rec.location}`);
    seen.add(key);
    return rec;
  });
}

async function main() {
  const records = readRecords();
  console.log(`Read ${records.length} rows from ${csvPath}`);

  const org = JSON.parse(execSync(`sf org display --target-org ${targetOrg} --json`, { encoding: 'utf8' })).result;
  const base = `${org.instanceUrl}/services/data/v${org.apiVersion}/commerce/oci/availability-records/uploads`;
  const auth = { Authorization: `Bearer ${org.accessToken}` };

  const form = new FormData();
  form.append('fileUpload', new Blob([buildNdjson(records)], { type: 'application/json' }), 'inventory.ndjson');
  const res = await fetch(base, { method: 'POST', headers: auth, body: form });
  const body = await res.json();
  if (!res.ok || !body.uploadId) throw new Error(`Upload rejected (${res.status}): ${JSON.stringify(body)}`);
  console.log(`Upload id: ${body.uploadId}`);

  for (let attempt = 1; attempt <= 30; attempt++) {
    await new Promise(r => setTimeout(r, 5000));
    const status = await (await fetch(`${base}/${body.uploadId}`, { headers: auth })).json();
    console.log(`  ${attempt}: ${status.status}`);
    if (/^COMPLETED?$/i.test(status.status)) {
      console.log(`Done: read ${status.recordsReadCount}, processed ${status.recordsProcessedCount}, skipped ${status.recordsSkippedCount}`);
      if (status.validationErrors?.length) console.log('Validation errors:', status.validationErrors);
      return;
    }
    if (/FAIL|ERROR/i.test(status.status)) throw new Error(`Upload failed: ${JSON.stringify(status)}`);
  }
  throw new Error(`Upload ${body.uploadId} still not complete; check it later.`);
}

main().catch(e => { console.error(e.message); process.exit(1); });
