// What the design directions share: the slide with each step's ink in its own colour, where the
// pen is right now, the little tutor who holds it, and a few small instruments.
import React, { useEffect, useMemo, useRef } from 'react';
import { Animated, PanResponder, Platform, Text, View } from 'react-native';
import Svg, { Circle, G, Line, Path, Rect, Text as SvgText } from 'react-native-svg';
import { F, INK, T, clamp01, easeInOut, inkDelay, inkTotal, ltr } from '../theme';
import { DrawnPath } from '../pen';
import { SineArt, markGeometry, useClock } from '../slide';
import { haptic } from '../controls';

/** Eastern Arabic digits: ١٦ rather than 16. */
export const ar = (n) => String(n).replace(/[0-9]/g, (d) => '٠١٢٣٤٥٦٧٨٩'[d]);

// System faces only; nothing is bundled. The web stacks reach for the open Arabic faces when the
// machine has them, and fall back cleanly when it doesn't.
export const FONTS = {
  naskh: Platform.select({ web: '"Noto Naskh Arabic", "Amiri", "Sakkal Majalla", "Traditional Arabic", "Times New Roman", serif', default: undefined }),
  kufi: Platform.select({ web: '"Reem Kufi", "Noto Kufi Arabic", "Segoe UI", Tahoma, sans-serif', default: undefined }),
  mono: Platform.select({ ios: 'Menlo', android: 'monospace', default: '"IBM Plex Mono", "SF Mono", Consolas, Menlo, monospace' }),
  serif: F.serif,
};

// MARK: Geometry

function bounds(pts) {
  let [x0, y0, x1, y1] = [1e9, 1e9, -1e9, -1e9];
  pts.forEach(([x, y]) => {
    x0 = Math.min(x0, x);
    y0 = Math.min(y0, y);
    x1 = Math.max(x1, x);
    y1 = Math.max(y1, y);
  });
  return [x0, y0, x1, y1];
}

export function markBox(m) {
  if (m.t === 'spot') return [m.r[0], m.r[1], m.r[0] + m.r[2], m.r[1] + m.r[3]];
  if (m.t === 'label') return [m.at[0] - 52, m.at[1] - 18, m.at[0] + 52, m.at[1] + 16];
  const g = markGeometry(m);
  return g ? bounds(g.pts) : [0, 0, 0, 0];
}

/** Everything a step drew, padded so a finger can find it. */
export function stepBox(step, pad = 12) {
  const boxes = step.marks.filter((m) => m.t !== 'spot').map(markBox);
  if (!boxes.length) return [0, 0, 0, 0];
  const b = bounds(boxes.flatMap((r) => [[r[0], r[1]], [r[2], r[3]]]));
  return [b[0] - pad, b[1] - pad, b[2] + pad, b[3] + pad];
}

/** Where a line from the words should land on the slide. */
export function stepAnchor(step) {
  if (step.placement && step.placement.anchor) return step.placement.anchor;
  const b = stepBox(step, 0);
  return [(b[0] + b[2]) / 2, (b[1] + b[3]) / 2];
}

function along(pts, f) {
  const lens = [];
  let total = 0;
  for (let k = 1; k < pts.length; k++) {
    const l = Math.hypot(pts[k][0] - pts[k - 1][0], pts[k][1] - pts[k - 1][1]);
    lens.push(l);
    total += l;
  }
  let want = total * f;
  for (let k = 1; k < pts.length; k++) {
    if (want <= lens[k - 1] || k === pts.length - 1) {
      const u = lens[k - 1] ? Math.min(1, want / lens[k - 1]) : 0;
      return [pts[k - 1][0] + (pts[k][0] - pts[k - 1][0]) * u, pts[k - 1][1] + (pts[k][1] - pts[k - 1][1]) * u];
    }
    want -= lens[k - 1];
  }
  return pts[pts.length - 1];
}

/** The pen's point at time `t` into a step: on the stroke being drawn, or resting where it lifted. */
export function penTip(marks, t) {
  if (!marks.length) return { x: 400, y: 300, drawing: false };
  let k = 0;
  for (let j = 0; j < marks.length; j++) if (t >= inkDelay(j)) k = j;
  const m = marks[k];
  const f = easeInOut(clamp01((t - inkDelay(k)) / INK.stroke));
  const drawing = t >= inkDelay(k) && t < inkDelay(k) + INK.stroke;
  if (m.t === 'label') return { x: m.at[0] - 46 + 92 * f, y: m.at[1] + 10, drawing };
  if (m.t === 'spot') return { x: m.r[0] + m.r[2] - 20, y: m.r[1] + m.r[3] - 20, drawing: false };
  const g = markGeometry(m);
  const [x, y] = along(g.pts, f);
  return { x, y, drawing };
}

// MARK: Ink

function InkMark({ m, progress, color, opacity = 1 }) {
  if (progress <= 0) return null;
  switch (m.t) {
    case 'spot': {
      const [x, y, w, h] = m.r;
      const [hx, hy, hw, hh, r] = [x - 8, y - 8, w + 16, h + 16, 14];
      const hole =
        `M${hx + r} ${hy} H${hx + hw - r} Q${hx + hw} ${hy} ${hx + hw} ${hy + r} V${hy + hh - r} ` +
        `Q${hx + hw} ${hy + hh} ${hx + hw - r} ${hy + hh} H${hx + r} Q${hx} ${hy + hh} ${hx} ${hy + hh - r} ` +
        `V${hy + r} Q${hx} ${hy} ${hx + r} ${hy} Z`;
      return <Path d={`M0 0 H800 V600 H0 Z ${hole}`} fill="rgba(18,20,24,0.5)" fillRule="evenodd" opacity={progress} />;
    }
    case 'label':
      return (
        <SvgText x={m.at[0]} y={m.at[1] + 9} textAnchor="middle" fontSize={26} fontFamily={F.hand} fontWeight="bold" fill={color} opacity={progress * opacity}>
          {m.text}
        </SvgText>
      );
    case 'guide': {
      const b = [m.a[0] + (m.b[0] - m.a[0]) * progress, m.a[1] + (m.b[1] - m.a[1]) * progress];
      return <Line x1={m.a[0]} y1={m.a[1]} x2={b[0]} y2={b[1]} stroke={color} strokeOpacity={0.85 * opacity} strokeWidth={2.5} strokeLinecap="round" strokeDasharray="7 7" />;
    }
    case 'dot':
      return <DrawnPath geo={markGeometry(m)} progress={progress} color={color} width={7} opacity={opacity} />;
    default:
      return <DrawnPath geo={markGeometry(m)} progress={progress} color={color} width={4.5} opacity={opacity} />;
  }
}

/**
 * The slide with its ink. Each step draws in `inkFor(stepIndex)`, earlier steps stay on the page
 * faded, and tapping an earlier step's ink jumps back to it. `overlay` draws on top in slide space.
 */
export function InkSlide({ p, width, inkFor, pastOpacity = 0.42, onJump, overlay, radius = 0, style }) {
  const { page, step, playKey, i } = p;
  const height = width * (page.height / page.width);
  const t = useClock(playKey, inkTotal(step.marks.length) + 400, true);
  const past = useMemo(
    () =>
      page.steps
        .slice(0, i)
        .map((st, idx) => ({ st, idx }))
        .filter(({ st }) => !st.ask),
    [i]
  );
  return (
    <View style={[{ width, height, overflow: 'hidden', direction: 'ltr', backgroundColor: '#FFFFFF', borderRadius: radius }, style]}>
      <Svg width={width} height={height} viewBox={`0 0 ${page.width} ${page.height}`}>
        <SineArt />
        {past.map(({ st, idx }) =>
          st.marks
            .filter((m) => m.t !== 'spot')
            .map((m, j) => <InkMark key={`p${idx}-${j}`} m={m} progress={1} color={inkFor(idx)} opacity={pastOpacity} />)
        )}
        {step.marks.map((m, j) => (
          <InkMark key={`c${playKey}-${j}`} m={m} progress={easeInOut(clamp01((t - inkDelay(j)) / INK.stroke))} color={inkFor(i)} />
        ))}
        {onJump &&
          past.map(({ st, idx }) => {
            const b = stepBox(st);
            return <Rect key={'hit' + idx} x={b[0]} y={b[1]} width={b[2] - b[0]} height={b[3] - b[1]} fill="#000000" fillOpacity={0.001} onPress={() => onJump(idx)} />;
          })}
        {overlay && overlay({ t, tip: penTip(step.marks, t) })}
      </Svg>
    </View>
  );
}

// MARK: The tutor on the page

/**
 * The climber from the logo, standing beside the pen with its arm reaching the tip. It bobs
 * while it draws and rests when the pen lifts. Drawn in slide space.
 */
export function Tutor({ tip, t, color = '#14212B', halo = '#FFFFFF', pen = '#0E8F87', k = 2.3 }) {
  // Stand below and to the right of the point, or to the left near the slide's right edge.
  const side = tip.x > 690 ? -1 : 1;
  const fx = tip.x + side * 13 * k;
  const fy = Math.min(596, tip.y + 21 * k);
  const bob = tip.drawing ? Math.sin(t / 70) * 0.6 * k : 0;
  const hip = [fx, fy - 7 * k + bob];
  const neck = [fx, fy - 15 * k + bob];
  const head = [fx + side * 0.4 * k, fy - 18.8 * k + bob];
  const shoulder = [fx, fy - 13 * k + bob];
  const stride = tip.drawing ? Math.sin(t / 90) * 1.4 : 0;
  const limbs = [
    [neck, hip],
    [hip, [fx - (2.6 + stride) * k, fy]],
    [hip, [fx + (2.6 + stride) * k, fy]],
    [shoulder, [tip.x, tip.y]],
    [shoulder, [fx + side * 3.6 * k, fy - 8.5 * k + bob]],
  ];
  const sw = 2.1 * k;
  const pass = (stroke, w, r) => (
    <G>
      {limbs.map(([a, b], n) => (
        <Line key={n} x1={a[0]} y1={a[1]} x2={b[0]} y2={b[1]} stroke={stroke} strokeWidth={w} strokeLinecap="round" />
      ))}
      <Circle cx={head[0]} cy={head[1]} r={r} fill={stroke} />
    </G>
  );
  return (
    <G>
      {pass(halo, sw + 5, 3.2 * k + 2.5)}
      {pass(color, sw, 3.2 * k)}
      <Circle cx={tip.x} cy={tip.y} r={tip.drawing ? 4.5 : 3.5} fill={pen} />
    </G>
  );
}

// MARK: Words

/** A caption line: math and Latin between backticks set in the step's colour, optionally highlighted. */
export function Glossed({ text, size = 16, w = '400', color, term, mark, font, termFont, lh, align, style, numberOfLines }) {
  const parts = text.split('`');
  return (
    <T size={size} w={w} color={color} lh={lh} align={align} numberOfLines={numberOfLines} style={[font ? { fontFamily: font } : null, style]}>
      {'‏'}
      {parts.map((part, k) =>
        k % 2 === 1 ? (
          <Text key={k} style={{ color: term || color, fontWeight: '700', fontFamily: termFont, backgroundColor: mark }}>
            {ltr((mark ? ' ' : '') + part.replace(/ /g, ' ') + (mark ? ' ' : ''))}
          </Text>
        ) : (
          part
        )
      )}
    </T>
  );
}

// MARK: Instruments

/** Press and hold to commit: `v` runs 0→1 while held, and `onDone` fires if it gets there. */
export function useHold(onDone, ms = 650) {
  const v = useRef(new Animated.Value(0)).current;
  const run = useRef(null);
  const done = useRef(onDone);
  done.current = onDone;
  const start = () => {
    haptic('light');
    run.current = Animated.timing(v, { toValue: 1, duration: ms, useNativeDriver: false });
    run.current.start(({ finished }) => {
      if (finished) {
        done.current();
        v.setValue(0);
      }
    });
  };
  const cancel = () => {
    if (run.current) run.current.stop();
    Animated.timing(v, { toValue: 0, duration: 160, useNativeDriver: false }).start();
  };
  return { v, start, cancel };
}

/**
 * Drag along a row or column of `count` items `spacing` apart to scrub through them. Calls
 * `onIndex` each time the item under the finger changes, with a tick of haptics.
 */
export function useScrub({ count, spacing, axis = 'y', current, onIndex, reverse = false }) {
  const from = useRef(current);
  const last = useRef(current);
  const cur = useRef(current);
  cur.current = current;
  const cb = useRef(onIndex);
  cb.current = onIndex;
  return useMemo(
    () =>
      PanResponder.create({
        onMoveShouldSetPanResponderCapture: (_, g) => Math.abs(axis === 'y' ? g.dy : g.dx) > 6,
        onPanResponderGrant: () => {
          from.current = cur.current;
          last.current = cur.current;
        },
        onPanResponderMove: (_, g) => {
          const d = (axis === 'y' ? g.dy : g.dx) * (reverse ? -1 : 1);
          const idx = Math.max(0, Math.min(count - 1, from.current + Math.round(d / spacing)));
          if (idx !== last.current) {
            last.current = idx;
            haptic('light');
            cb.current(idx);
          }
        },
      }),
    [count, spacing, axis, reverse]
  );
}

/** A value that eases toward `to` whenever it changes; for the strands and stairs. */
export function useEased(to, duration = 380) {
  const v = useRef(new Animated.Value(to)).current;
  useEffect(() => {
    Animated.timing(v, { toValue: to, duration, useNativeDriver: false }).start();
  }, [to]);
  return v;
}

/** Fades and lifts its content in when `on` turns true. */
export function Appear({ on = true, children, style, dy = 6, duration = 320 }) {
  const v = useEased(on ? 1 : 0, duration);
  return (
    <Animated.View style={[style, { opacity: v, transform: [{ translateY: v.interpolate({ inputRange: [0, 1], outputRange: [dy, 0] }) }] }]}>
      {children}
    </Animated.View>
  );
}

/** A pen stroke under whatever it wraps, sized to it. */
export function Underlined({ color, width = 2.5, children, style }) {
  const [size, setSize] = React.useState(null);
  return (
    <View style={style} onLayout={(e) => setSize({ w: e.nativeEvent.layout.width, h: e.nativeEvent.layout.height })}>
      {children}
      {size && (
        <Svg pointerEvents="none" width={size.w + 8} height={10} style={{ position: 'absolute', left: -4, bottom: -7 }}>
          <Path d={`M${size.w + 6} 4 Q${size.w * 0.55} 8 2 4.5`} stroke={color} strokeWidth={width} strokeLinecap="round" fill="none" />
        </Svg>
      )}
    </View>
  );
}
