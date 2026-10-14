// Pen marks made by hand: rings, ticks, checkboxes, and a rubber stamp.
import React from 'react';
import { View } from 'react-native';
import Svg, { Path, Rect } from 'react-native-svg';
import { C, T } from './theme';
import { Grain, useSize } from './paper';

/** A hand-drawn loop that fits a box, with a small overshoot where the pen lifts. */
export function ellipsePath(x, y, w, h, samples = 48) {
  const cx = x + w / 2;
  const cy = y + h / 2;
  const pts = [];
  for (let i = 0; i <= samples; i++) {
    const f = i / samples;
    const a = -2.3 + f * (2 * Math.PI + 0.45);
    const wob = 1 + 0.04 * Math.sin(f * 9) + 0.07 * f;
    pts.push([cx + (w / 2) * wob * Math.cos(a), cy + (h / 2) * wob * Math.sin(a)]);
  }
  return toPath(pts);
}

export function toPath(pts) {
  let d = '';
  let len = 0;
  pts.forEach((p, i) => {
    d += (i ? 'L' : 'M') + p[0].toFixed(1) + ' ' + p[1].toFixed(1);
    if (i) len += Math.hypot(p[0] - pts[i - 1][0], p[1] - pts[i - 1][1]);
  });
  return { d, len };
}

/** A stroke drawn on up to `progress` (0…1). */
export function DrawnPath({ geo, progress = 1, color, width, opacity = 1, dash }) {
  if (progress <= 0) return null;
  const done = progress >= 1;
  return (
    <Path
      d={geo.d}
      stroke={color}
      strokeWidth={width}
      strokeOpacity={opacity}
      strokeLinecap="round"
      strokeLinejoin="round"
      fill="none"
      strokeDasharray={dash || (done ? undefined : `${geo.len} ${geo.len}`)}
      strokeDashoffset={dash || done ? undefined : geo.len * (1 - progress)}
    />
  );
}

/** The tutor's pen ring around a box of known size. */
export function PenRing({ w, h, color = C.red, lw = 2, pad = 3, progress = 1, style }) {
  const geo = ellipsePath(pad, pad, w, h);
  return (
    <Svg
      pointerEvents="none"
      width={w + pad * 2}
      height={h + pad * 2}
      style={[{ position: 'absolute', top: -pad, left: -pad }, style]}
    >
      <DrawnPath geo={geo} progress={progress} color={color} width={lw} />
    </Svg>
  );
}

/** Rings whatever it wraps, sized to the content. */
export function Ringed({ color = C.red, lw = 2, padX = 8, padY = 6, progress = 1, children, style }) {
  const [size, onLayout] = useSize();
  return (
    <View onLayout={onLayout} style={style}>
      {children}
      {size && progress > 0 && (
        <View pointerEvents="none" style={{ position: 'absolute', top: -padY, left: -padX }}>
          <PenRing w={size.w + padX * 2} h={size.h + padY * 2} color={color} lw={lw} progress={progress} />
        </View>
      )}
    </View>
  );
}

/** A hand-drawn tick. */
export function tickPath(w, h, x = 0, y = 0) {
  return (
    `M${x} ${y + h * 0.55} ` +
    `Q${x + w * 0.2} ${y + h * 0.8} ${x + w * 0.36} ${y + h} ` +
    `Q${x + w * 0.55} ${y + h * 0.4} ${x + w} ${y}`
  );
}

export function PenTick({ w = 24, h = 18, color = C.red, lw = 2.8 }) {
  return (
    <Svg width={w + 4} height={h + 4}>
      <Path d={tickPath(w, h, 2, 2)} stroke={color} strokeWidth={lw} strokeLinecap="round" strokeLinejoin="round" fill="none" />
    </Svg>
  );
}

/** A box you tick by hand, as on an exam sheet. */
export function PenCheckbox({ on, color = C.red }) {
  return (
    <Svg width={26} height={24}>
      <Rect x={4.6} y={5.6} width={14.8} height={14.8} stroke={C.ink} strokeWidth={1.2} fill="none" />
      {on && (
        <Path d={tickPath(17, 14, 5, 1)} stroke={color} strokeWidth={2.4} strokeLinecap="round" strokeLinejoin="round" fill="none" />
      )}
    </Svg>
  );
}

/** A rubber stamp, pressed a little crooked: double frame, heavy letters, uneven ink. */
export function Stamp({ text, color = C.stamp, size = 15, angle = -7, style }) {
  return (
    <View style={[{ transform: [{ rotate: `${angle}deg` }], opacity: 0.88, alignSelf: 'flex-start' }, style]}>
      <View style={{ borderWidth: size * 0.07, borderColor: color, padding: size * 0.12 }}>
        <View style={{ borderWidth: size * 0.12, borderColor: color, paddingHorizontal: size * 0.55, paddingVertical: size * 0.08 }}>
          <T size={size} w="900" color={color} align="center" lh={size * 1.35}>
            {text}
          </T>
        </View>
      </View>
      <Grain density={4} wear />
    </View>
  );
}
