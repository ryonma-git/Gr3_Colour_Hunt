// RGB と HSV の変換。Swift 版 RGBHSVConversion.swift と同じ式。

/** RGB(各 0...1) -> HSV(h:0...360, s:0...1, v:0...1) */
export function rgbToHsv(r, g, b) {
  const rr = Math.min(Math.max(r, 0), 1);
  const gg = Math.min(Math.max(g, 0), 1);
  const bb = Math.min(Math.max(b, 0), 1);

  const max = Math.max(rr, gg, bb);
  const min = Math.min(rr, gg, bb);
  const delta = max - min;

  let h = 0;
  if (delta > 1e-6) {
    if (max === rr) {
      h = 60 * (((gg - bb) / delta) % 6);
    } else if (max === gg) {
      h = 60 * ((bb - rr) / delta + 2);
    } else {
      h = 60 * ((rr - gg) / delta + 4);
    }
  }
  if (h < 0) h += 360;
  if (h >= 360) h -= 360;

  const s = max <= 1e-6 ? 0 : delta / max;
  return { h, s, v: max };
}
