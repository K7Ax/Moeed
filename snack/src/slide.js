// The printed slide, the tutor's ink over it, and the caption slip.
// Everything on the slide is laid out in slide space (800 × 600), always left-to-right.
import React, { useEffect, useRef, useState } from 'react';
import { Animated, StyleSheet, View } from 'react-native';
import Svg, { Circle, G, Line, Path, Polygon, Rect, Text as SvgText } from 'react-native-svg';
import { C, F, INK, Rich, S, clamp01, easeInOut, inkDelay, inkTotal } from './theme';
import { Grain, paperShadow } from './paper';
import { DrawnPath, PenRing, toPath } from './pen';

// MARK: Clock

/** Milliseconds since `key` last changed, ticking until `total`. Not animating → always "done". */
export function useClock(key, total, animate) {
  const [t, setT] = useState(animate ? 0 : 1e9);
  useEffect(() => {
    if (!animate) {
      setT(1e9);
      return undefined;
    }
    let raf;
    const start = Date.now();
    setT(0);
    const tick = () => {
      const e = Date.now() - start;
      setT(e);
      if (e < total + 60) raf = requestAnimationFrame(tick);
    };
    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
  }, [key, animate]);
  return t;
}

// MARK: Ink geometry

function quad(a, c, b, n = 24) {
  const pts = [];
  for (let i = 0; i <= n; i++) {
    const f = i / n;
    const u = 1 - f;
    pts.push([u * u * a[0] + 2 * u * f * c[0] + f * f * b[0], u * u * a[1] + 2 * u * f * c[1] + f * f * b[1]]);
  }
  return pts;
}

const geoCache = new WeakMap();

/** Hand-drawn geometry for each mark. Deterministic wobble, so a step always looks the same. */
export function markGeometry(m) {
  if (geoCache.has(m)) return geoCache.get(m);
  let pts = [];
  switch (m.t) {
    case 'circle':
      for (let i = 0; i <= 56; i++) {
        const f = i / 56;
        const a = -2.3 + f * (2 * Math.PI + 0.45);
        const wob = 1 + 0.05 * Math.sin(f * 9) + 0.08 * f;
        pts.push([m.c[0] + m.rx * wob * Math.cos(a), m.c[1] + m.ry * wob * Math.sin(a)]);
      }
      break;
    case 'box': {
      const [x, y, w, h] = m.r;
      pts = [
        [x - 2, y + 1],
        [x + w + 1, y - 2],
        [x + w + 2, y + h + 1],
        [x - 1, y + h + 2],
        [x - 1, y - 2],
        [x + 12, y - 3],
      ];
      break;
    }
    case 'underline':
      pts = quad(m.a, [(m.a[0] + m.b[0]) / 2, (m.a[1] + m.b[1]) / 2 - 3], m.b, 20);
      break;
    case 'dot':
      for (let i = 0; i <= 16; i++) {
        const a = (i / 16) * Math.PI * 2;
        pts.push([m.p[0] + 3.5 * Math.cos(a), m.p[1] + 3.5 * Math.sin(a)]);
      }
      break;
    case 'guide':
      pts = [m.a, m.b];
      break;
    case 'arrow': {
      const { a, b, bend } = m;
      const c = [(a[0] + b[0]) / 2 - (b[1] - a[1]) * bend, (a[1] + b[1]) / 2 + (b[0] - a[0]) * bend];
      pts = quad(a, c, b, 28);
      const tx = b[0] - c[0];
      const ty = b[1] - c[1];
      const l = Math.max(1, Math.hypot(tx, ty));
      const ux = -tx / l;
      const uy = -ty / l;
      const head = 16;
      const sp = 0.5;
      const left = [b[0] + (ux * Math.cos(sp) - uy * Math.sin(sp)) * head, b[1] + (ux * Math.sin(sp) + uy * Math.cos(sp)) * head];
      const right = [b[0] + (ux * Math.cos(-sp) - uy * Math.sin(-sp)) * head, b[1] + (ux * Math.sin(-sp) + uy * Math.cos(-sp)) * head];
      pts.push(left, b, right);
      break;
    }
    default:
      break;
  }
  const geo = pts.length ? toPath(pts) : null;
  geoCache.set(m, geo);
  return geo;
}

/** One mark of tutor ink at `progress` (0…1). */
function Mark({ m, progress, faded }) {
  if (progress <= 0) return null;
  const op = faded ? 0.38 : 1;
  switch (m.t) {
    case 'spot': {
      const [x, y, w, h] = m.r;
      const r = 14;
      const hx = x - 8;
      const hy = y - 8;
      const hw = w + 16;
      const hh = h + 16;
      const hole =
        `M${hx + r} ${hy} H${hx + hw - r} Q${hx + hw} ${hy} ${hx + hw} ${hy + r} V${hy + hh - r} ` +
        `Q${hx + hw} ${hy + hh} ${hx + hw - r} ${hy + hh} H${hx + r} Q${hx} ${hy + hh} ${hx} ${hy + hh - r} ` +
        `V${hy + r} Q${hx} ${hy} ${hx + r} ${hy} Z`;
      return <Path d={`M0 0 H800 V600 H0 Z ${hole}`} fill={C.spotlight} fillRule="evenodd" opacity={progress} />;
    }
    case 'label':
      return (
        <SvgText
          x={m.at[0]}
          y={m.at[1] + 9}
          textAnchor="middle"
          fontSize={26}
          fontFamily={F.hand}
          fontWeight="bold"
          fill={C.red}
          opacity={progress * op}
        >
          {m.text}
        </SvgText>
      );
    case 'guide': {
      const b = [m.a[0] + (m.b[0] - m.a[0]) * progress, m.a[1] + (m.b[1] - m.a[1]) * progress];
      return (
        <Line
          x1={m.a[0]}
          y1={m.a[1]}
          x2={b[0]}
          y2={b[1]}
          stroke={C.red}
          strokeOpacity={0.8 * op}
          strokeWidth={2.5}
          strokeLinecap="round"
          strokeDasharray="7 7"
        />
      );
    }
    case 'dot':
      return <DrawnPath geo={markGeometry(m)} progress={progress} color={C.red} width={7} opacity={op} />;
    default:
      return <DrawnPath geo={markGeometry(m)} progress={progress} color={C.red} width={4.5} opacity={op} />;
  }
}

// MARK: The sample slide

function Lead({ y, children, size = 21, bold, italic, color = C.slideInk }) {
  return (
    <SvgText x={56} y={y} fontSize={size} fontFamily={F.serif} fontWeight={bold ? 'bold' : 'normal'} fontStyle={italic ? 'italic' : 'normal'} fill={color}>
      {children}
    </SvgText>
  );
}

function Tick({ x, y, children }) {
  return (
    <SvgText x={x} y={y} fontSize={16} fontFamily={F.serif} textAnchor="middle" fill={C.slideLabel}>
      {children}
    </SvgText>
  );
}

let waveD = 'M340 400';
for (let i = 0; i < 7; i++) {
  const x0 = 340 + i * 60;
  waveD += ` Q${x0 + 30} ${i % 2 === 0 ? 180 : 620} ${x0 + 60} 400`;
}

/** Our own sample slide: a sine-wave reading exercise. */
const SineArt = React.memo(function SineArt() {
  return (
    <G>
      <Rect x={0} y={0} width={800} height={600} fill="#FFFFFF" />
      <SvgText x={400} y={62} fontSize={34} fontFamily={F.serif} fontWeight="bold" textAnchor="middle" fill={C.slideTitle}>
        Sine Wave · Reading the Graph
      </SvgText>
      <Line x1={60} y1={84} x2={740} y2={84} stroke={C.slideRule} strokeWidth={2} />
      <Lead y={134} bold color={C.slideTitle}>
        Find:
      </Lead>
      <Lead y={172}>a) the peak value Vp</Lead>
      <Lead y={206}>b) v at 0.3 s and 0.6 s</Lead>
      <Lead y={240}>c) the peak-to-peak value</Lead>
      <Lead y={274}>d) the period T</Lead>
      <Lead y={308}>e) the frequency</Lead>
      <Lead y={372} bold color={C.slideTitle}>
        Key relation
      </Lead>
      <Lead y={414} size={26} italic>
        f = 1 / T
      </Lead>
      <Path d="M340 270 L340 540 M330 400 L778 400" stroke={C.slideAxis} strokeWidth={2.5} fill="none" />
      <Polygon points="778,400 768,395 768,405" fill={C.slideAxis} />
      <Path d="M340 290 L370 290 M340 510 L430 510" stroke={C.slideGuide} strokeWidth={1.5} strokeDasharray="5 5" fill="none" />
      <Path d={waveD} stroke={C.slideWave} strokeWidth={3.5} fill="none" />
      <Tick x={316} y={300}>
        8 V
      </Tick>
      <Tick x={312} y={520}>
        −8 V
      </Tick>
      {['0.2', '0.4', '0.6', '0.8', '1.0', '1.2', '1.4'].map((l, i) => (
        <Tick key={l} x={400 + i * 60} y={429}>
          {l}
        </Tick>
      ))}
      <Tick x={762} y={453}>
        t (s)
      </Tick>
      <Tick x={352} y={269}>
        v
      </Tick>
    </G>
  );
});

function clampTo(rect, p) {
  const [x, y, w, h] = rect;
  return [Math.min(Math.max(p[0], x), x + w), Math.min(Math.max(p[1], y), y + h)];
}

/**
 * A slide with the ink layer, an optional selection, and an optional floating caption.
 * `playKey` restarts the drawing; `animate={false}` shows everything already drawn.
 */
export function SlideStage({ page, width, pastMarks = [], marks = [], playKey = 0, animate = false, showInk = true, selection, caption }) {
  const height = width * (page.height / page.width);
  const s = width / page.width;
  const t = useClock(playKey, inkTotal(marks.length), animate);
  const card = caption && caption.placement.card;
  const anchor = caption && caption.placement.anchor;
  return (
    <View style={{ width, height, overflow: 'hidden', direction: 'ltr', backgroundColor: '#FFFFFF' }}>
      <Svg width={width} height={height} viewBox={`0 0 ${page.width} ${page.height}`}>
        <SineArt />
        {showInk && (
          <G>
            {pastMarks.map((m, i) => (
              <Mark key={'p' + i} m={m} progress={1} faded />
            ))}
            {marks.map((m, i) => (
              <Mark key={i} m={m} progress={easeInOut(clamp01((t - inkDelay(i)) / INK.stroke))} />
            ))}
          </G>
        )}
        {selection && (
          <G>
            <Rect
              x={selection[0]}
              y={selection[1]}
              width={selection[2]}
              height={selection[3]}
              rx={10}
              fill={C.blueTint}
              stroke={C.blue}
              strokeWidth={2.5 / s}
              strokeDasharray={`${8 / s} ${6 / s}`}
            />
            {[
              [selection[0] + selection[2], selection[1]],
              [selection[0], selection[1] + selection[3]],
            ].map((p, i) => (
              <Circle key={i} cx={p[0]} cy={p[1]} r={8 / s} fill={C.blue} stroke="#FFFFFF" strokeWidth={2 / s} />
            ))}
          </G>
        )}
        {anchor && caption.revealed > 0 && (
          <Line
            x1={clampTo(card, anchor)[0]}
            y1={clampTo(card, anchor)[1]}
            x2={anchor[0]}
            y2={anchor[1]}
            stroke={C.red}
            strokeOpacity={0.75}
            strokeWidth={2 / s}
            strokeLinecap="round"
            strokeDasharray={`${6 / s} ${7 / s}`}
          />
        )}
      </Svg>
      {caption && (
        <View style={{ position: 'absolute', left: card[0] * s, top: card[1] * s, width: card[2] * s, direction: 'rtl' }}>
          <CaptionCard number={caption.number} phrases={caption.phrases} revealed={caption.revealed} compact={width < 900} />
        </View>
      )}
    </View>
  );
}

/** A zoomed crop of the slide around one point, for list thumbnails. */
export function SlideCrop({ page, focus, w = 120, h = 90, zoom = 3 }) {
  const W = w * zoom;
  const H = W * (page.height / page.width);
  const fx = (focus[0] / page.width) * W;
  const fy = (focus[1] / page.height) * H;
  const ox = Math.min(Math.max(w / 2 - fx, w - W), 0);
  const oy = Math.min(Math.max(h / 2 - fy, h - H), 0);
  return (
    <View style={{ width: w, height: h, overflow: 'hidden', direction: 'ltr' }}>
      <View style={{ position: 'absolute', left: ox, top: oy }}>
        <SlideStage page={page} width={W} marks={[{ t: 'circle', c: focus, rx: 24, ry: 24 }]} />
      </View>
    </View>
  );
}

/** The selected part of the slide, scaled up to fill `width`. */
export function RegionCrop({ page, rect, width, pad = 6 }) {
  const s = width / (rect[2] + pad * 2);
  return (
    <View style={{ width, height: (rect[3] + pad * 2) * s, overflow: 'hidden', direction: 'ltr' }}>
      <View style={{ position: 'absolute', left: -(rect[0] - pad) * s, top: -(rect[1] - pad) * s }}>
        <SlideStage page={page} width={page.width * s} />
      </View>
    </View>
  );
}

// MARK: Caption slip

/** One phrase coming into focus; space is reserved, so nothing jumps. */
function Phrase({ text, state, size }) {
  const v = useRef(new Animated.Value(state === 'hidden' ? 0 : 1)).current;
  const target = state === 'hidden' ? 0 : state === 'past' ? 0.5 : 1;
  useEffect(() => {
    Animated.timing(v, { toValue: target, duration: 300, useNativeDriver: true }).start();
  }, [target]);
  return (
    <Animated.View
      style={{
        opacity: v,
        transform: [{ translateY: v.interpolate({ inputRange: [0, 0.5, 1], outputRange: [6, 0, 0] }) }],
      }}
    >
      <Rich text={text} size={size} w={state === 'current' ? '600' : '400'} />
    </Animated.View>
  );
}

/** The tutor's words for one step, on a slip of card with the step number ringed in red pen. */
export function CaptionCard({ number, phrases, revealed, compact, style }) {
  const size = compact ? 16 : 18;
  return (
    <View style={[{ backgroundColor: C.card, borderWidth: 0.5, borderColor: 'rgba(23,21,19,0.12)' }, paperShadow(0.9), style]}>
      <Grain density={0.5} />
      <View style={{ flexDirection: 'row', paddingHorizontal: 16, paddingVertical: 14 }}>
        <View style={{ width: 28, height: 28, alignItems: 'center', justifyContent: 'center' }}>
          <S size={16} w="700" color={C.red} align="center" lh={20}>
            {String(number)}
          </S>
          <PenRing w={26} h={26} lw={1.8} style={{ top: -2, left: -2 }} />
        </View>
        <View style={{ width: 1, backgroundColor: 'rgba(194,59,34,0.55)', marginVertical: -14, marginHorizontal: 6 }} />
        <View style={{ flex: 1, paddingHorizontal: 6 }}>
          {phrases.map((p, i) => (
            <Phrase key={i} text={p} size={size} state={i >= revealed ? 'hidden' : i === revealed - 1 ? 'current' : 'past'} />
          ))}
        </View>
      </View>
    </View>
  );
}

export const stageStyles = StyleSheet.create({});
