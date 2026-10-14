// The tutor's pen: hand-drawn rings and ticks, drawn on stroke by stroke.
import React from 'react';
import { View } from 'react-native';
import Svg, { Path } from 'react-native-svg';
import { C } from './theme';
import { useSize } from './ui';

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
export function PenRing({ w, h, color, lw = 2, pad = 3, progress = 1, style }) {
  const geo = ellipsePath(pad, pad, w, h);
  return (
    <Svg pointerEvents="none" width={w + pad * 2} height={h + pad * 2} style={[{ position: 'absolute', top: -pad, left: -pad }, style]}>
      <DrawnPath geo={geo} progress={progress} color={color || C.accent} width={lw} />
    </Svg>
  );
}

/** Rings whatever it wraps, sized to the content. */
export function Ringed({ color, lw = 2, padX = 8, padY = 6, progress = 1, children, style }) {
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
