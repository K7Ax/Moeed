// The mark: a flight of stairs with a play mark at the top: you climb a lecture step by step.
// Geometry lives in one place so the launch intro climbs exactly the stairs the logo draws.
import React from 'react';
import Svg, { Path, Polygon } from 'react-native-svg';
import { isDark } from './theme';

export const LOGO = {
  box: 100,
  // Each step's tread, left to right, bottom to top: [x0, x1, y].
  treads: [
    [10, 36, 74],
    [36, 62, 52],
    [62, 88, 30],
  ],
  base: 92,
  play: [
    [66, 6],
    [66, 24],
    [82, 15],
  ],
};

export const logoColors = () => (isDark() ? { stairs: '#A9BCDD', play: '#4FC1B6' } : { stairs: '#1F3A5F', play: '#1E8C8C' });

export function stairsPath() {
  const { treads, base } = LOGO;
  let d = `M${treads[0][0]} ${base} V${treads[0][2]}`;
  treads.forEach(([, x1, y], i) => {
    d += ` H${x1}`;
    d += i < treads.length - 1 ? ` V${treads[i + 1][2]}` : ` V${base}`;
  });
  return d + ' Z';
}

export function LogoMark({ size = 28, stairs, play, style }) {
  const c = logoColors();
  return (
    <Svg width={size} height={size} viewBox="0 0 100 100" style={style}>
      <Path d={stairsPath()} fill={stairs || c.stairs} />
      <Polygon points={LOGO.play.map((p) => p.join(',')).join(' ')} fill={play || c.play} />
    </Svg>
  );
}
