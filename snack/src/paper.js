// Paper, tape and printed rules.
import React, { useCallback, useState } from 'react';
import { StyleSheet, View } from 'react-native';
import Svg, { Circle, Defs, Line, Path, Pattern, Polygon, Rect } from 'react-native-svg';
import { C } from './theme';

/** Measures a view: `const [size, onLayout] = useSize()`. */
export function useSize() {
  const [size, setSize] = useState(null);
  const onLayout = useCallback((e) => {
    const { width, height } = e.nativeEvent.layout;
    setSize((s) => (s && Math.abs(s.w - width) < 0.5 && Math.abs(s.h - height) < 0.5 ? s : { w: width, h: height }));
  }, []);
  return [size, onLayout];
}

// Grain is one seeded tile, repeated, so every render looks the same and stays cheap.
function makeTile(seed, count) {
  let s = seed;
  const next = () => {
    s = (s * 16807) % 2147483647;
    return (s - 1) / 2147483646;
  };
  const specks = [];
  for (let i = 0; i < count; i++) {
    const dark = next() > 0.35;
    specks.push({ x: next() * 160, y: next() * 160, r: 0.3 + next() * 0.7, dark, o: dark ? 0.035 + next() * 0.05 : 0.25 });
  }
  const fibres = [];
  for (let i = 0; i < Math.max(1, Math.round(count / 30)); i++) {
    const x = next() * 160;
    const y = next() * 160;
    const a = next() * Math.PI;
    const l = 4 + next() * 10;
    fibres.push({ x, y, x2: x + Math.cos(a) * l, y2: y + Math.sin(a) * l });
  }
  return { specks, fibres };
}
const tiles = {};
function tile(density) {
  const key = Math.round(density * 10);
  if (!tiles[key]) tiles[key] = makeTile(97 + key, Math.round(36 * density));
  return tiles[key];
}

/** Paper grain and toner specks. `wear` prints paper-coloured specks instead, for worn stamps. */
export function Grain({ density = 0.6, wear }) {
  const { specks, fibres } = tile(density);
  const id = `grain${Math.round(density * 10)}${wear ? 'w' : ''}`;
  return (
    <Svg style={StyleSheet.absoluteFill} width="100%" height="100%" pointerEvents="none">
      <Defs>
        <Pattern id={id} patternUnits="userSpaceOnUse" x="0" y="0" width="160" height="160">
          {specks.map((p, i) =>
            wear ? (
              <Circle key={i} cx={p.x} cy={p.y} r={p.r * 1.3} fill={C.paper} opacity={0.9} />
            ) : (
              <Circle key={i} cx={p.x} cy={p.y} r={p.r} fill={p.dark ? C.ink : '#FFFFFF'} opacity={p.o} />
            )
          )}
          {!wear &&
            fibres.map((f, i) => <Line key={'f' + i} x1={f.x} y1={f.y} x2={f.x2} y2={f.y2} stroke={C.ink} strokeOpacity={0.05} strokeWidth={0.5} />)}
        </Pattern>
      </Defs>
      <Rect x="0" y="0" width="100%" height="100%" fill={`url(#${id})`} />
    </Svg>
  );
}

export const paperShadow = (lift = 1) => ({
  shadowColor: C.ink,
  shadowOpacity: 0.16,
  shadowRadius: 8 * lift,
  shadowOffset: { width: 0, height: 5 * lift },
  elevation: 3 * lift,
});

/** A sheet of paper lying on the desk: square corners, grain, the tight shadow paper actually casts. */
export function Sheet({ stock = C.paper, lift = 1, grain = 0.6, style, children, ...rest }) {
  return (
    <View
      {...rest}
      style={[{ backgroundColor: stock, borderWidth: StyleSheet.hairlineWidth, borderColor: 'rgba(23,21,19,0.08)' }, paperShadow(lift), style]}
    >
      <Grain density={grain} />
      {children}
    </View>
  );
}

/** The desk under the packet. */
export function Desk({ style, children }) {
  return (
    <View style={[{ flex: 1, backgroundColor: C.desk }, style]}>
      <Grain density={1.2} />
      {children}
    </View>
  );
}

/** A slide printed into the packet. */
export const slideFrame = {
  backgroundColor: '#FFFFFF',
  borderWidth: 0.75,
  borderColor: 'rgba(23,21,19,0.18)',
  shadowColor: C.ink,
  shadowOpacity: 0.16,
  shadowRadius: 10,
  shadowOffset: { width: 0, height: 6 },
  elevation: 4,
};

/** A strip of clear tape holding something down (place inside a positioned parent). */
export function Tape({ angle = -4, width = 64, top = -10 }) {
  return (
    <View pointerEvents="none" style={{ position: 'absolute', top, left: 0, right: 0, alignItems: 'center' }}>
      <View
        style={{
          width,
          height: 20,
          backgroundColor: C.tape,
          borderWidth: 0.5,
          borderColor: 'rgba(255,255,255,0.6)',
          transform: [{ rotate: `${angle}deg` }],
        }}
      />
    </View>
  );
}

export function Hairline({ color = C.ink, weight = 0.75, style }) {
  return <View style={[{ height: weight, backgroundColor: color, alignSelf: 'stretch' }, style]} />;
}

/** The masthead's thick-over-thin rule. */
export function DoubleRule({ style }) {
  return (
    <View style={[{ alignSelf: 'stretch' }, style]}>
      <View style={{ height: 2.5, backgroundColor: C.ink }} />
      <View style={{ height: 0.75, backgroundColor: C.ink, marginTop: 2.5 }} />
    </View>
  );
}

export function ColumnRule() {
  return <View style={{ width: 0.75, backgroundColor: C.rule, alignSelf: 'stretch' }} />;
}

/** The dotted leader of a table of contents: «المحاضرة الخامسة ........ ص ١٦». */
export function Leader({ style, color = C.mark }) {
  return (
    <View style={[{ flex: 1, minWidth: 16, height: 4, justifyContent: 'center' }, style]}>
      <Svg width="100%" height="4">
        <Line x1="2" y1="2" x2="100%" y2="2" stroke={color} strokeWidth={1.3} strokeLinecap="round" strokeDasharray="0.1 5" />
      </Svg>
    </View>
  );
}

/** A highlighter swipe: uneven ends, a little off the baseline. */
export function swipePoints(w, h, seed = 0) {
  const s = seed % 5;
  return [
    [2, h * 0.12],
    [w - 1, h * (0.05 + s * 0.02)],
    [w + 2, h - h * 0.08],
    [0, h - h * (0.02 + s * 0.015)],
  ]
    .map((p) => p.map((v) => v.toFixed(1)).join(','))
    .join(' ');
}

/** Marks text with the highlighter. */
export function Highlight({ on = true, seed = 0, color = C.highlighter, opacity = 0.62, children, style }) {
  const [size, onLayout] = useSize();
  return (
    <View style={[{ alignSelf: 'flex-start' }, style]} onLayout={onLayout}>
      {on && size && (
        <Svg
          pointerEvents="none"
          style={{ position: 'absolute', top: 1, left: -5 }}
          width={size.w + 12}
          height={Math.max(1, size.h - 2)}
        >
          <Polygon points={swipePoints(size.w + 9, size.h - 2, seed)} fill={color} opacity={opacity} />
        </Svg>
      )}
      {children}
    </View>
  );
}

/** The torn top of a slip pulled off a pad: a row of punched holes. */
export function Perforation() {
  const [size, onLayout] = useSize();
  const holes = [];
  if (size) for (let x = 6; x < size.w; x += 9) holes.push(x);
  return (
    <View pointerEvents="none" onLayout={onLayout} style={{ position: 'absolute', top: 0, left: 0, right: 0, height: 14 }}>
      {size && (
        <Svg width={size.w} height={14}>
          {holes.map((x) => (
            <Circle key={x} cx={x + 1.75} cy={7.75} r={1.75} fill={C.desk} />
          ))}
        </Svg>
      )}
    </View>
  );
}

/** The wire binding: punched holes down the edge, a coil loop through each. Drawn left-to-right. */
export function Coil({ height }) {
  const loops = [];
  for (let y = 18; y < height - 10; y += 22) loops.push(y);
  return (
    <Svg width={36} height={height} pointerEvents="none">
      {loops.map((y) => (
        <React.Fragment key={y}>
          <Circle cx={27} cy={y} r={4} fill={C.hole} stroke="rgba(23,21,19,0.25)" strokeWidth={0.5} />
          <Path
            d={`M27 ${y} C2 ${y - 4} 2 ${y + 11} 29 ${y + 9.2}`}
            stroke="#3A3733"
            strokeWidth={2.2}
            strokeLinecap="round"
            fill="none"
          />
          <Path
            d={`M27 ${y} C2 ${y - 4} 2 ${y + 11} 29 ${y + 9.2}`}
            stroke="rgba(255,255,255,0.35)"
            strokeWidth={0.6}
            strokeLinecap="round"
            fill="none"
          />
        </React.Fragment>
      ))}
    </Svg>
  );
}
