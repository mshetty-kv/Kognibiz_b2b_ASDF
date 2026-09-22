/**
 * officeDepotImagery
 *
 * Generated SVG product illustrations, one per catalogue family, returned as data URIs.
 *
 * WHY THIS EXISTS AND WHAT IT IS NOT
 * The catalogue has no product photography. ProductMedia is DML-createable, but it requires a
 * ManagedContent record, and ManagedContent is NOT DML-createable; the CMS REST route
 * (/connect/cms/spaces/...) returns "URL No Longer Exists", and authoring an sfdc_cms__image item
 * inside the DigitalExperienceBundle was attempted and rejected with "The JSON provided in
 * <name>.json is invalid" for every body shape tried. Rather than guess at an undocumented
 * metadata schema, these are locally generated vector illustrations.
 *
 * They are DELIBERATELY abstract line-art on a light tint - they represent the product family,
 * they are not photographs, and no third-party imagery is used. This is recorded as a known
 * fidelity gap in docs/ASDF_ASSESSMENT.md.
 *
 * Data URIs keep everything inside force-app with no binary pipeline and no static-resource zip.
 */

const TINTS = {
    pap: '#eef3fb',
    wrt: '#fdf1e7',
    fil: '#eef7f2',
    lap: '#eef2f7',
    prn: '#f4eefb',
    mon: '#e9f4f7',
    chr: '#fdeef1',
    dsk: '#f6f2ea',
    cof: '#f7efe7',
    cln: '#eaf6f4',
    generic: '#f2f4f5'
};

const INK = '#37475a';
const ACCENT = '#ff9900';

/* Each entry is the inner markup of a 200x200 viewBox. Kept deliberately simple. */
const SHAPES = {
    pap: `<rect x="58" y="40" width="84" height="112" rx="4" fill="#fff" stroke="${INK}" stroke-width="4"/>
          <path d="M72 66h56M72 84h56M72 102h56M72 120h36" stroke="${INK}" stroke-width="4" stroke-linecap="round" opacity=".55"/>`,
    wrt: `<path d="M64 140l8-28 58-58 20 20-58 58-28 8z" fill="#fff" stroke="${INK}" stroke-width="4" stroke-linejoin="round"/>
          <path d="M122 54l20 20" stroke="${INK}" stroke-width="4"/>
          <path d="M64 140l8-28 12 16-20 12z" fill="${ACCENT}"/>`,
    fil: `<path d="M46 66h44l10 14h54v66a6 6 0 01-6 6H52a6 6 0 01-6-6V66z" fill="#fff" stroke="${INK}" stroke-width="4" stroke-linejoin="round"/>
          <path d="M46 96h108" stroke="${INK}" stroke-width="4" opacity=".55"/>`,
    lap: `<rect x="52" y="54" width="96" height="62" rx="5" fill="#fff" stroke="${INK}" stroke-width="4"/>
          <rect x="64" y="66" width="72" height="38" rx="2" fill="${INK}" opacity=".12"/>
          <path d="M38 124h124l-8 14H46z" fill="#fff" stroke="${INK}" stroke-width="4" stroke-linejoin="round"/>`,
    prn: `<rect x="54" y="84" width="92" height="46" rx="6" fill="#fff" stroke="${INK}" stroke-width="4"/>
          <rect x="72" y="52" width="56" height="32" rx="3" fill="#fff" stroke="${INK}" stroke-width="4"/>
          <rect x="72" y="126" width="56" height="26" rx="3" fill="#fff" stroke="${INK}" stroke-width="4"/>
          <circle cx="134" cy="98" r="5" fill="${ACCENT}"/>`,
    mon: `<rect x="42" y="50" width="116" height="74" rx="5" fill="#fff" stroke="${INK}" stroke-width="4"/>
          <rect x="54" y="62" width="92" height="50" rx="2" fill="${INK}" opacity=".12"/>
          <path d="M100 124v20M76 152h48" stroke="${INK}" stroke-width="4" stroke-linecap="round"/>`,
    chr: `<path d="M70 58h60v44H70z" fill="#fff" stroke="${INK}" stroke-width="4" stroke-linejoin="round"/>
          <path d="M64 108h72v18H64z" fill="#fff" stroke="${INK}" stroke-width="4" stroke-linejoin="round"/>
          <path d="M100 126v22M78 158l22-10 22 10" stroke="${INK}" stroke-width="4" stroke-linecap="round" stroke-linejoin="round"/>`,
    dsk: `<path d="M38 92h124v14H38z" fill="#fff" stroke="${INK}" stroke-width="4" stroke-linejoin="round"/>
          <path d="M52 106v44M148 106v44" stroke="${INK}" stroke-width="4" stroke-linecap="round"/>
          <rect x="74" y="60" width="52" height="32" rx="3" fill="${ACCENT}" opacity=".25"/>`,
    cof: `<path d="M62 68h66v54a26 26 0 01-26 26H88a26 26 0 01-26-26V68z" fill="#fff" stroke="${INK}" stroke-width="4" stroke-linejoin="round"/>
          <path d="M128 82h14a14 14 0 010 28h-14" fill="none" stroke="${INK}" stroke-width="4"/>
          <path d="M80 44c0 8 8 8 8 16M100 44c0 8 8 8 8 16" stroke="${ACCENT}" stroke-width="4" stroke-linecap="round"/>`,
    cln: `<path d="M84 44h32v22H84z" fill="#fff" stroke="${INK}" stroke-width="4" stroke-linejoin="round"/>
          <path d="M72 66h56v82a8 8 0 01-8 8H80a8 8 0 01-8-8V66z" fill="#fff" stroke="${INK}" stroke-width="4" stroke-linejoin="round"/>
          <path d="M72 96h56" stroke="${INK}" stroke-width="4" opacity=".5"/>`,
    generic: `<rect x="56" y="56" width="88" height="88" rx="8" fill="#fff" stroke="${INK}" stroke-width="4"/>
              <path d="M56 116l26-24 20 18 20-16 22 22" fill="none" stroke="${INK}" stroke-width="4" stroke-linecap="round" stroke-linejoin="round"/>
              <circle cx="122" cy="80" r="8" fill="${ACCENT}"/>`
};

/**
 * Returns a data-URI SVG for a product image key.
 * @param {string} key one of the SKU family segments (pap, wrt, lap, ...) or 'generic'
 * @returns {string} an image/svg+xml data URI safe to use in an <img src>
 */
export function productImage(key) {
    const k = SHAPES[key] ? key : 'generic';
    const svg =
        `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 200" width="200" height="200" role="img">` +
        `<rect width="200" height="200" fill="${TINTS[k]}"/>` +
        SHAPES[k] +
        `</svg>`;
    return `data:image/svg+xml;charset=utf-8,${encodeURIComponent(svg)}`;
}

/** Wider 16:9 tint panel used by the category deal tiles. */
export function categoryImage(key) {
    const k = SHAPES[key] ? key : 'generic';
    const svg =
        `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 200" width="200" height="200" role="img">` +
        `<rect width="200" height="200" fill="${TINTS[k]}"/>` +
        SHAPES[k] +
        `</svg>`;
    return `data:image/svg+xml;charset=utf-8,${encodeURIComponent(svg)}`;
}
