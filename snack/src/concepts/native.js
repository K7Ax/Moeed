// «الأصلي»: Mo'eed built the way the platform's own best apps are, not around an invented
// metaphor. The library reads like Apple Books and Podcasts: a sidebar, a large title, one "now
// playing" card with the slide as its artwork, shelves of covers, a mini player. The player reads
// like Apple Music's lyrics: the slide is the artwork, and the tutor's words scroll beside it line
// by line, lighting word by word as they're said (as Speak does).
//
// The second pass adds what the big apps have and the first didn't: one family set properly (IBM
// Plex Sans Arabic, Eastern Arabic figures), the tutor's pen reaching off the slide into the UI
// (nib-drawn icons, an ink ring round today, a tick on finished lectures), covers set like
// Thmanyah's (the lecture's word as the art), a live "preparing" card in the manner of Flighty,
// a week of study rings as in Fitness, and motion throughout: staggered entrances, springs on
// press, covers that tilt toward the pointer, slow light behind the player, a sheet that lifts the
// player over the library, and a burst when an answer is right.
import React, { useEffect, useMemo, useRef, useState } from 'react';
import { Animated, Easing, Platform, Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import Svg, { Circle, Defs, G, LinearGradient, Path, RadialGradient, Rect, Stop } from 'react-native-svg';
import { T, clamp01, digits, easeOut, face, isDark, ltr, readingMs } from '../theme';
import { Icon, haptic } from '../controls';
import { useSize } from '../ui';
import { LogoMark } from '../logo';
import { DrawnPath, ellipsePath } from '../pen';
import { SlideCrop, SlideStage, useClock } from '../slide';
import { usePlayer } from '../player';
import { importJob, resume, reviewItems, sinePage } from '../data';
import { InkSlide, useScrub } from './engine';
import { LECTURES, ORDINAL } from './mock';

const WEB = Platform.OS === 'web';
// The native driver can't run on the web; there Animated falls back to JS, which is fine.
const ND = !WEB;

// iOS system colours, with the logo's teal as the only tint.
const pal = () =>
  isDark()
    ? {
        bg: '#000000',
        raised: '#1C1C1E',
        raised2: '#2C2C2E',
        sidebar: '#141416',
        text: '#FFFFFF',
        text2: 'rgba(235,235,245,0.6)',
        text3: 'rgba(235,235,245,0.3)',
        sep: 'rgba(84,84,88,0.6)',
        fill: 'rgba(120,120,128,0.24)',
        hover: 'rgba(120,120,128,0.16)',
        accent: '#3CC8B8',
        accentSoft: 'rgba(60,200,184,0.18)',
        onAccent: '#00201D',
        bar: 'rgba(22,22,24,0.92)',
        ink: '#5FE0CF',
      }
    : {
        bg: '#FFFFFF',
        raised: '#F4F4F7',
        raised2: '#E5E5EA',
        sidebar: '#F4F4F7',
        text: '#000000',
        text2: 'rgba(60,60,67,0.62)',
        text3: 'rgba(60,60,67,0.3)',
        sep: 'rgba(60,60,67,0.18)',
        fill: 'rgba(120,120,128,0.12)',
        hover: 'rgba(120,120,128,0.08)',
        accent: '#0A8F86',
        accentSoft: 'rgba(10,143,134,0.12)',
        onAccent: '#FFFFFF',
        bar: 'rgba(250,250,250,0.94)',
        ink: '#0A8F86',
      };

// Each lecture's cover colour, and the word that stands for it.
const COVERS = ['#2E4C73', '#5D3D8F', '#2D6A4F', '#9A4B1F', '#0B7F78', '#4B5058'];
const WORDS = ['الأساس', 'أوم', 'كيرشوف', 'المكثّف', 'الجيبية', 'الطور'];
const CODE = 'كهر ٢٠٧';
const PEN = '#0A8F86';
const ASK_PEN = '#E8590C';
// The player's light: the logo's teals over near-black.
const DEEP = '#061210';
const MINT = '#8FF2E2';
const RIGHT_BG = '#7CE6CF';
const RIGHT_FG = '#00231C';
const WRONG_BG = '#FFB340';
const WRONG_FG = '#2A1800';
// Where the sample question's answer sits on the slide: the trough at 0.3 s.
const ANSWER_AT = [430, 510];

const hair = StyleSheet.hairlineWidth;
const current = LECTURES.find((l) => l.current);
const preparing = LECTURES.find((l) => l.preparing !== undefined);
const pastInk = sinePage.steps
  .slice(0, 4)
  .filter((s) => !s.ask)
  .flatMap((s) => s.marks)
  .filter((m) => m.t !== 'spot');
const liveInk = sinePage.steps[4].marks.filter((m) => m.t !== 'spot');

// MARK: Motion

const useValue = (init = 0) => useRef(new Animated.Value(init)).current;

/** A number that eases to `to` whenever it changes; for counters and rings drawn in JS. */
function useTween(to, { ms = 800, delay = 0 } = {}) {
  const [v, setV] = useState(0);
  const cur = useRef(0);
  useEffect(() => {
    let raf;
    let start = null;
    const from = cur.current;
    const tick = (now) => {
      if (start === null) start = now;
      const f = Math.min(1, (now - start) / ms);
      cur.current = from + (to - from) * easeOut(f);
      setV(cur.current);
      if (f < 1) raf = requestAnimationFrame(tick);
    };
    const id = setTimeout(() => {
      raf = requestAnimationFrame(tick);
    }, delay);
    return () => {
      clearTimeout(id);
      cancelAnimationFrame(raf);
    };
  }, [to]);
  return v;
}

/** 0 → 1 forever, linearly, every `ms`. */
function useLoop(ms, delay = 0) {
  const v = useValue(0);
  useEffect(() => {
    const run = Animated.loop(Animated.timing(v, { toValue: 1, duration: ms, easing: Easing.linear, useNativeDriver: ND }));
    const id = setTimeout(() => run.start(), delay);
    return () => {
      clearTimeout(id);
      run.stop();
    };
  }, []);
  return v;
}

/** Fades and lifts in once, `delay` ms after it first appears: the stagger on every screen. */
function Rise({ delay = 0, dy = 18, children, style }) {
  const v = useValue(0);
  useEffect(() => {
    Animated.timing(v, { toValue: 1, duration: 560, delay, easing: Easing.out(Easing.cubic), useNativeDriver: ND }).start();
  }, []);
  return (
    <Animated.View style={[style, { opacity: v, transform: [{ translateY: v.interpolate({ inputRange: [0, 1], outputRange: [dy, 0] }) }] }]}>
      {children}
    </Animated.View>
  );
}

/** Springs down a little under the finger and back with a small overshoot; tints on hover. */
function Press({ onPress, children, style, outer, scaleTo = 0.96, hoverBg, disabled, hitSlop, silent }) {
  const s = useValue(1);
  const [hover, setHover] = useState(false);
  const to = (x) => Animated.spring(s, { toValue: x, useNativeDriver: ND, speed: 40, bounciness: x === 1 ? 9 : 0 }).start();
  return (
    <Pressable
      style={outer}
      disabled={disabled}
      hitSlop={hitSlop}
      onHoverIn={() => setHover(true)}
      onHoverOut={() => setHover(false)}
      onPressIn={() => to(scaleTo)}
      onPressOut={() => to(1)}
      onPress={
        onPress
          ? () => {
              if (!silent) haptic('light');
              onPress();
            }
          : undefined
      }
    >
      <Animated.View style={[style, hover && hoverBg ? { backgroundColor: hoverBg } : null, { transform: [{ scale: s }] }]}>
        {typeof children === 'function' ? children({ hover }) : children}
      </Animated.View>
    </Pressable>
  );
}

/**
 * Tilts toward the pointer in 3D, lifts a touch, and catches a little light across its face. On
 * the web it follows the mouse; on a device, the finger where it lands.
 */
function Tilt({ children, max = 8, radius = 14, style }) {
  const x = useValue(0);
  const y = useValue(0);
  const lift = useValue(0);
  const host = useRef(null);
  const box = useRef({ width: 1, height: 1 });
  const go = (tx, ty, l) => {
    const cfg = { useNativeDriver: ND, speed: 16, bounciness: 5 };
    Animated.spring(x, { toValue: tx, ...cfg }).start();
    Animated.spring(y, { toValue: ty, ...cfg }).start();
    Animated.spring(lift, { toValue: l, ...cfg }).start();
  };
  useEffect(() => {
    const el = host.current;
    if (!WEB || !el || !el.addEventListener) return undefined;
    const move = (e) => {
      const r = el.getBoundingClientRect();
      go(((e.clientX - r.left) / r.width) * 2 - 1, ((e.clientY - r.top) / r.height) * 2 - 1, 1);
    };
    const leave = () => go(0, 0, 0);
    el.addEventListener('mousemove', move);
    el.addEventListener('mouseleave', leave);
    return () => {
      el.removeEventListener('mousemove', move);
      el.removeEventListener('mouseleave', leave);
    };
  }, []);
  const touch = WEB
    ? null
    : {
        onTouchStart: (e) => go((e.nativeEvent.locationX / box.current.width) * 2 - 1, (e.nativeEvent.locationY / box.current.height) * 2 - 1, 1),
        onTouchEnd: () => go(0, 0, 0),
        onTouchCancel: () => go(0, 0, 0),
      };
  return (
    <View ref={host} style={style} onLayout={(e) => (box.current = e.nativeEvent.layout)} {...touch}>
      <Animated.View
        style={{
          borderRadius: radius,
          transform: [
            { perspective: 900 },
            { rotateY: x.interpolate({ inputRange: [-1, 1], outputRange: [`-${max}deg`, `${max}deg`] }) },
            { rotateX: y.interpolate({ inputRange: [-1, 1], outputRange: [`${max}deg`, `-${max}deg`] }) },
            { scale: lift.interpolate({ inputRange: [0, 1], outputRange: [1, 1.03] }) },
          ],
        }}
      >
        {children}
        <Animated.View
          pointerEvents="none"
          style={{
            ...StyleSheet.absoluteFillObject,
            borderRadius: radius,
            overflow: 'hidden',
            opacity: lift,
          }}
        >
          <Animated.View style={{ position: 'absolute', top: -40, bottom: -40, width: '70%', left: '15%', transform: [{ translateX: x.interpolate({ inputRange: [-1, 1], outputRange: [-120, 120] }) }, { rotate: '18deg' }] }}>
            <Svg width="100%" height="100%">
              <Defs>
                <LinearGradient id="glare" x1="0" y1="0" x2="1" y2="0">
                  <Stop offset="0" stopColor="#FFFFFF" stopOpacity="0" />
                  <Stop offset="0.5" stopColor="#FFFFFF" stopOpacity="0.16" />
                  <Stop offset="1" stopColor="#FFFFFF" stopOpacity="0" />
                </LinearGradient>
              </Defs>
              <Rect width="100%" height="100%" fill="url(#glare)" />
            </Svg>
          </Animated.View>
        </Animated.View>
      </Animated.View>
    </View>
  );
}

let blobId = 0;
/** One soft pool of light that drifts in a slow loop. */
function Blob({ color, size, x, y, dx, dy, ms, delay = 0, opacity = 0.9 }) {
  const id = useMemo(() => 'blob' + blobId++, []);
  const v = useLoop(ms, delay);
  const steps = [0, 0.25, 0.5, 0.75, 1];
  return (
    <Animated.View
      pointerEvents="none"
      style={{
        position: 'absolute',
        left: x - size / 2,
        top: y - size / 2,
        width: size,
        height: size,
        opacity,
        transform: [
          { translateX: v.interpolate({ inputRange: steps, outputRange: [0, dx, 0, -dx, 0] }) },
          { translateY: v.interpolate({ inputRange: steps, outputRange: [-dy, 0, dy, 0, -dy] }) },
          { scale: v.interpolate({ inputRange: steps, outputRange: [1, 1.18, 1, 0.88, 1] }) },
        ],
      }}
    >
      <Svg width={size} height={size}>
        <Defs>
          <RadialGradient id={id} cx="50%" cy="50%" rx="50%" ry="50%">
            <Stop offset="0" stopColor={color} stopOpacity="1" />
            <Stop offset="0.5" stopColor={color} stopOpacity="0.42" />
            <Stop offset="1" stopColor={color} stopOpacity="0" />
          </RadialGradient>
        </Defs>
        <Circle cx={size / 2} cy={size / 2} r={size / 2} fill={`url(#${id})`} />
      </Svg>
    </Animated.View>
  );
}

/** The player's light: pools of the logo's teals drifting over near-black, as Apple Music does. */
function Ambient({ w, h, dim = 1 }) {
  if (!w) return null;
  const m = Math.max(w, h);
  return (
    <View pointerEvents="none" style={[StyleSheet.absoluteFill, { overflow: 'hidden', backgroundColor: DEEP }]}>
      <Blob color="#14776C" size={m * 1.1} x={w * 0.82} y={h * 0.12} dx={m * 0.08} dy={m * 0.06} ms={19000} opacity={0.85 * dim} />
      <Blob color="#0E3F5C" size={m * 1.0} x={w * 0.12} y={h * 0.85} dx={m * 0.1} dy={m * 0.05} ms={23000} delay={400} opacity={0.9 * dim} />
      <Blob color="#2BA889" size={m * 0.6} x={w * 0.35} y={h * 0.3} dx={m * 0.12} dy={m * 0.09} ms={17000} delay={900} opacity={0.38 * dim} />
      <Blob color="#0B5A55" size={m * 0.8} x={w * 0.62} y={h * 0.95} dx={m * 0.07} dy={m * 0.08} ms={27000} delay={200} opacity={0.7 * dim} />
      <View style={[StyleSheet.absoluteFill, { backgroundColor: 'rgba(0,0,0,0.18)' }]} />
    </View>
  );
}

/** A small dot that breathes: live, now, in progress. */
function Pulse({ color, size = 8 }) {
  const v = useLoop(1600);
  return (
    <View style={{ width: size * 2.4, height: size * 2.4, alignItems: 'center', justifyContent: 'center' }}>
      <Animated.View
        style={{
          position: 'absolute',
          width: size * 2.4,
          height: size * 2.4,
          borderRadius: size * 1.2,
          backgroundColor: color,
          opacity: v.interpolate({ inputRange: [0, 0.7, 1], outputRange: [0.45, 0, 0] }),
          transform: [{ scale: v.interpolate({ inputRange: [0, 1], outputRange: [0.4, 1.1] }) }],
        }}
      />
      <View style={{ width: size, height: size, borderRadius: size / 2, backgroundColor: color }} />
    </View>
  );
}

/** A figure that counts up to its value when it first shows. */
function Count({ to, delay = 0, ms = 1100, suffix = '', ...t }) {
  const v = useTween(to, { ms, delay });
  return <T {...t}>{Math.round(v) + suffix}</T>;
}

/** A progress ring, drawn round from the top. */
function Ring({ size, stroke, value, color, track, dashed }) {
  const r = (size - stroke) / 2;
  const len = 2 * Math.PI * r;
  return (
    <Svg width={size} height={size} style={{ transform: [{ rotate: '-90deg' }] }}>
      <Circle cx={size / 2} cy={size / 2} r={r} stroke={track} strokeWidth={stroke} fill="none" strokeDasharray={dashed ? `2 ${3.2}` : undefined} />
      {value > 0.001 && <Circle cx={size / 2} cy={size / 2} r={r} stroke={color} strokeWidth={stroke} fill="none" strokeLinecap="round" strokeDasharray={`${len} ${len}`} strokeDashoffset={len * (1 - Math.min(1, value))} />}
    </Svg>
  );
}

/** A light band that sweeps across whatever it sits in: something is being made. */
function Shimmer({ width, color = '#FFFFFF', opacity = 0.5 }) {
  const v = useLoop(1500);
  return (
    <Animated.View pointerEvents="none" style={{ position: 'absolute', top: 0, bottom: 0, width: 70, opacity, transform: [{ translateX: v.interpolate({ inputRange: [0, 1], outputRange: [width, -70] }) }] }}>
      <Svg width={70} height="100%">
        <Defs>
          <LinearGradient id="shim" x1="0" y1="0" x2="1" y2="0">
            <Stop offset="0" stopColor={color} stopOpacity="0" />
            <Stop offset="0.5" stopColor={color} stopOpacity="1" />
            <Stop offset="1" stopColor={color} stopOpacity="0" />
          </LinearGradient>
        </Defs>
        <Rect width={70} height="100%" fill="url(#shim)" />
      </Svg>
    </Animated.View>
  );
}

/** The tutor's ink round something in the UI, drawn on after `delay`. */
function InkRing({ w, h, color, delay = 0, lw = 2 }) {
  const p = useTween(1, { ms: 650, delay });
  const geo = useMemo(() => ellipsePath(3, 3, w, h), [w, h]);
  return (
    <Svg pointerEvents="none" width={w + 6} height={h + 6} style={{ position: 'absolute', left: -3, top: -3 }}>
      <DrawnPath geo={geo} progress={p} color={color} width={lw} />
    </Svg>
  );
}

// MARK: Nib-drawn icons

// The icons are drawn the way the tutor writes: each stroke thin where the pen lands and lifts,
// full in the middle, a little wider across the broad nib's angle, with one fixed lean of the hand.
const SLANT = Math.tan((7 * Math.PI) / 180);
const NIB = (38 * Math.PI) / 180;
const seg = (a, b, k = 12) => Array.from({ length: k + 1 }, (_, i) => [a[0] + ((b[0] - a[0]) * i) / k, a[1] + ((b[1] - a[1]) * i) / k]);
const quad = (a, c, b, k = 16) =>
  Array.from({ length: k + 1 }, (_, i) => {
    const f = i / k;
    const u = 1 - f;
    return [u * u * a[0] + 2 * u * f * c[0] + f * f * b[0], u * u * a[1] + 2 * u * f * c[1] + f * f * b[1]];
  });
const arc = (cx, cy, r, a0, a1, k = 34) => Array.from({ length: k + 1 }, (_, i) => [cx + r * Math.cos(a0 + ((a1 - a0) * i) / k), cy + r * Math.sin(a0 + ((a1 - a0) * i) / k)]);
const chain = (...parts) => parts.reduce((all, p, i) => all.concat(i ? p.slice(1) : p), []);
function arrowHead(tip, dir, len = 3.4, spread = 2.6) {
  const n = [-dir[1], dir[0]];
  const back = [tip[0] - dir[0] * len, tip[1] - dir[1] * len];
  return chain(seg([back[0] + n[0] * spread, back[1] + n[1] * spread], tip, 6), seg(tip, [back[0] - n[0] * spread, back[1] - n[1] * spread], 6));
}

const REVIEW_END = 4.75;
const ICONS = {
  home: [
    chain(seg([3.2, 11.8], [12, 4.2]), seg([12, 4.2], [20.8, 11.8])),
    chain(seg([5.8, 10.2], [5.8, 20.2]), seg([5.8, 20.2], [18.2, 20.2]), seg([18.2, 20.2], [18.2, 10.2])),
    chain(seg([10.1, 20.2], [10.1, 15.4], 6), quad([10.1, 15.4], [12, 13.4], [13.9, 15.4], 8), seg([13.9, 15.4], [13.9, 20.2], 6)),
  ],
  library: [
    chain(quad([12, 6.6], [7.4, 3.8], [2.8, 5.3]), seg([2.8, 5.3], [2.8, 18.6]), quad([2.8, 18.6], [7.6, 17.3], [12, 19.9])),
    chain(quad([12, 6.6], [16.6, 3.8], [21.2, 5.3]), seg([21.2, 5.3], [21.2, 18.6]), quad([21.2, 18.6], [16.4, 17.3], [12, 19.9])),
    seg([12, 6.8], [12, 19.4]),
  ],
  review: [
    arc(12, 12.4, 7.8, -0.35, REVIEW_END),
    arrowHead([12 + 7.8 * Math.cos(REVIEW_END), 12.4 + 7.8 * Math.sin(REVIEW_END)], [-Math.sin(REVIEW_END), Math.cos(REVIEW_END)]),
    chain(seg([12, 8.6], [12, 12.6], 6), seg([12, 12.6], [14.8, 14.4], 5)),
  ],
  plus: [arc(12, 12, 8.8, -1.3, 5.2), seg([12, 7.8], [12, 16.2], 8), seg([7.8, 12], [16.2, 12], 8)],
};

function nibOutline(raw, w, seed) {
  const pts = raw.map(([x, y], i) => [x - (y - 12) * SLANT + 0.16 * Math.sin(i * 1.3 + seed), y + 0.16 * Math.cos(i * 1.1 + seed * 2)]);
  const n = pts.length;
  const L = [];
  const R = [];
  for (let i = 0; i < n; i++) {
    const a = pts[Math.max(0, i - 1)];
    const b = pts[Math.min(n - 1, i + 1)];
    let tx = b[0] - a[0];
    let ty = b[1] - a[1];
    const len = Math.hypot(tx, ty) || 1;
    tx /= len;
    ty /= len;
    const f = n > 1 ? i / (n - 1) : 0.5;
    const taper = Math.pow(Math.sin(Math.PI * (0.03 + 0.94 * f)), 0.5);
    const hw = (w / 2) * (0.14 + 0.86 * taper) * (0.62 + 0.38 * Math.abs(Math.sin(Math.atan2(ty, tx) - NIB)));
    L.push([pts[i][0] - ty * hw, pts[i][1] + tx * hw]);
    R.push([pts[i][0] + ty * hw, pts[i][1] - tx * hw]);
  }
  const out = L.concat(R.reverse());
  return 'M' + out.map((p) => p[0].toFixed(2) + ' ' + p[1].toFixed(2)).join('L') + 'Z';
}

/** A nib-drawn icon. When it becomes `active` it writes itself again, stroke by stroke. */
function NibIcon({ name, size = 22, color, active, weight = 2.3 }) {
  const strokes = ICONS[name];
  const total = strokes.reduce((s, x) => s + x.length, 0);
  const t = useClock(active ? 'on' : 'off', 520, !!active);
  const p = active ? clamp01(t / 520) : 1;
  const paths = useMemo(() => {
    if (p >= 1) return strokes.map((s, k) => nibOutline(s, weight, k + 1));
    let left = Math.ceil(easeOut(p) * total);
    const out = [];
    strokes.forEach((s, k) => {
      if (left < 2) return;
      out.push(nibOutline(s.slice(0, Math.min(s.length, left)), weight, k + 1));
      left -= s.length;
    });
    return out;
  }, [p, name, weight]);
  return (
    <Svg width={size} height={size} viewBox="0 0 24 24">
      {paths.map((d, k) => (
        <Path key={k} d={d} fill={color} />
      ))}
    </Svg>
  );
}

// MARK: Glyphs and buttons

/** The filled transport glyphs the system players use. `fwd` points right; mirror it for left. */
function Glyph({ name, size = 28, color = '#FFFFFF', flip }) {
  const d = {
    play: 'M7 4.6v14.8c0 .8.9 1.3 1.6.9l12.2-7.4c.7-.4.7-1.4 0-1.8L8.6 3.7C7.9 3.3 7 3.8 7 4.6z',
    pause: 'M6 4h4.2v16H6zM13.8 4H18v16h-4.2z',
    fwd: 'M2.5 5.8v12.4c0 .7.8 1.1 1.4.7l8.1-6.2c.5-.4.5-1 0-1.4L3.9 5.1c-.6-.4-1.4 0-1.4.7zM12 5.8v12.4c0 .7.8 1.1 1.4.7l8.1-6.2c.5-.4.5-1 0-1.4l-8.1-6.2c-.6-.4-1.4 0-1.4.7z',
  }[name];
  return (
    <Svg width={size} height={size} viewBox="0 0 24 24" style={flip ? { transform: [{ scaleX: -1 }] } : null}>
      <Path d={d} fill={color} />
    </Svg>
  );
}

function Capsule({ label, glyph, onPress, bg, fg, hoverBg, height = 46, style }) {
  return (
    <Press onPress={onPress} hoverBg={hoverBg} style={[{ height, paddingHorizontal: 22, borderRadius: height / 2, backgroundColor: bg, flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: 8 }, style]}>
      {glyph && <Glyph name={glyph} size={16} color={fg} />}
      <T size={17} w="600" color={fg}>
        {label}
      </T>
    </Press>
  );
}

// MARK: Covers

/** A line drawing for each lecture, the way its subject is drawn on the board. */
function Motif({ n, size, spin }) {
  const sw = 2.4;
  const st = { stroke: '#FFFFFF', strokeWidth: sw, fill: 'none', strokeLinecap: 'round', strokeLinejoin: 'round' };
  const art = {
    1: <Path d="M22 30H78V72H22Z M14 46V56 M8 49V53 M22 51H14" {...st} />,
    2: <Path d="M6 52H26L31 38L39 66L47 38L55 66L63 38L68 52H94" {...st} />,
    3: (
      <G>
        <Path d="M50 50L16 26M50 50L84 26M50 50V90" {...st} />
        <Path d="M30 33l-6-1 2-6M70 33l6-1-2-6M47 76l3 6 3-6" {...st} />
        <Circle cx={50} cy={50} r={5} fill="#FFFFFF" />
      </G>
    ),
    4: <Path d="M6 50H42M42 28V72M58 28V72M58 50H94" {...st} />,
    5: <Path d={'M4 50' + Array.from({ length: 46 }, (_, i) => `L${4 + i * 2} ${50 - 24 * Math.sin((i / 45) * Math.PI * 3)}`).join('')} {...st} />,
    6: null,
  }[n];
  return (
    <Svg width={size} height={size} viewBox="0 0 100 100" style={{ opacity: 0.4 }}>
      {art}
    </Svg>
  );
}

/** The phasor, turning while its lecture is being prepared. */
function Phasor({ size }) {
  const v = useLoop(4800);
  return (
    <View style={{ width: size, height: size, opacity: 0.5 }}>
      <Svg width={size} height={size} viewBox="0 0 100 100" style={StyleSheet.absoluteFill}>
        <Circle cx={50} cy={50} r={32} stroke="#FFFFFF" strokeWidth={2.4} fill="none" strokeDasharray="3 5" />
      </Svg>
      <Animated.View style={[StyleSheet.absoluteFill, { transform: [{ rotate: v.interpolate({ inputRange: [0, 1], outputRange: ['0deg', '-360deg'] }) }] }]}>
        <Svg width={size} height={size} viewBox="0 0 100 100">
          <Path d="M50 50L80 50M72 44l8 6-8 6" stroke="#FFFFFF" strokeWidth={2.6} fill="none" strokeLinecap="round" strokeLinejoin="round" />
          <Circle cx={50} cy={50} r={3.5} fill="#FFFFFF" />
        </Svg>
      </Animated.View>
    </View>
  );
}

/** A hand-drawn tick, written on when the cover first shows. */
function InkTick({ size, delay }) {
  const p = useTween(1, { ms: 520, delay });
  const geo = useMemo(() => {
    const pts = chain(quad([4, 13], [6.5, 14.5], [9, 19], 8), quad([9, 19], [13, 9], [21, 4], 12)).map(([x, y]) => [x * (size / 24), y * (size / 24)]);
    let len = 0;
    pts.forEach((q, i) => i && (len += Math.hypot(q[0] - pts[i - 1][0], q[1] - pts[i - 1][1])));
    return { d: 'M' + pts.map((q) => q[0].toFixed(1) + ' ' + q[1].toFixed(1)).join('L'), len };
  }, [size]);
  return (
    <Svg width={size} height={size}>
      <DrawnPath geo={geo} progress={p} color="#FFFFFF" width={size * 0.11} />
    </Svg>
  );
}

/**
 * A lecture's cover, set the way Thmanyah sets its shows: the subject's word large as the art,
 * its line drawing behind, the course code and number small, the English title in Brygada.
 */
function Cover({ lec, size, delay = 0 }) {
  const bg = COVERS[(lec.n - 1) % COVERS.length];
  const id = `cv${lec.n}-${Math.round(size)}`;
  const pad = size * 0.085;
  const isPrep = lec.preparing !== undefined;
  const done = lec.done >= 1;
  return (
    <View style={{ width: size, height: size, borderRadius: size * 0.07, overflow: 'hidden', backgroundColor: bg }}>
      <Svg style={StyleSheet.absoluteFill} width={size} height={size}>
        <Defs>
          <LinearGradient id={id} x1="0" y1="0" x2="0.35" y2="1">
            <Stop offset="0" stopColor="#FFFFFF" stopOpacity="0.18" />
            <Stop offset="1" stopColor="#000000" stopOpacity="0.32" />
          </LinearGradient>
        </Defs>
        <Rect width={size} height={size} fill={`url(#${id})`} />
      </Svg>
      <View style={{ position: 'absolute', left: size * 0.12, top: size * 0.1 }}>{isPrep ? <Phasor size={size * 0.76} /> : <Motif n={lec.n} size={size * 0.76} />}</View>
      <View style={{ flex: 1, padding: pad, justifyContent: 'space-between' }}>
        <View style={{ flexDirection: 'row', alignItems: 'flex-start', justifyContent: 'space-between' }}>
          <T size={Math.max(9, size * 0.068)} w="600" color="rgba(255,255,255,0.75)">
            {CODE}
          </T>
          <T size={size * 0.15} w="700" color="#FFFFFF" lh={size * 0.17}>
            {String(lec.n)}
          </T>
        </View>
        <View>
          <T size={size * 0.17} w="700" color="#FFFFFF" lh={size * 0.24} numberOfLines={1} adjustsFontSizeToFit>
            {WORDS[lec.n - 1]}
          </T>
          <T serif italic size={Math.max(9, size * 0.072)} color="rgba(255,255,255,0.82)" numberOfLines={1} lh={Math.max(12, size * 0.1)} align="left" style={{ writingDirection: 'ltr' }}>
            {lec.en}
          </T>
        </View>
      </View>
      {done && (
        <View style={{ position: 'absolute', left: pad * 0.7, top: size * 0.36 }}>
          <InkTick size={size * 0.2} delay={delay + 600} />
        </View>
      )}
      {lec.current && (
        <View style={{ position: 'absolute', left: pad, right: pad, bottom: pad * 0.55, height: 3, borderRadius: 2, backgroundColor: 'rgba(255,255,255,0.28)' }}>
          <View style={{ position: 'absolute', right: 0, top: 0, bottom: 0, width: `${lec.done * 100}%`, borderRadius: 2, backgroundColor: '#FFFFFF' }} />
        </View>
      )}
      {isPrep && (
        <View style={{ position: 'absolute', left: pad, right: pad, bottom: pad * 0.55, height: 3, borderRadius: 2, backgroundColor: 'rgba(255,255,255,0.25)', overflow: 'hidden' }}>
          <View style={{ position: 'absolute', right: 0, top: 0, bottom: 0, width: `${lec.preparing * 100}%`, borderRadius: 2, backgroundColor: '#FFFFFF' }} />
          <Shimmer width={size} opacity={0.8} />
        </View>
      )}
    </View>
  );
}

// MARK: Library

const DAYS = ['الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'];
const DAY_LETTER = ['ح', 'ن', 'ث', 'ر', 'خ', 'ج', 'س'];
const MONTHS = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
// Minutes studied each day of this week, Sunday first; the days still to come stay empty.
const WEEK_MIN = [34, 22, 0, 41, 28, 19, 26];
const GOAL_MIN = 30;

/** Today, Gregorian, and Hijri where the device can say it. */
function dateLine() {
  const d = new Date();
  let s = `${DAYS[d.getDay()]}، ${d.getDate()} ${MONTHS[d.getMonth()]}`;
  try {
    const h = new Intl.DateTimeFormat('ar-SA-u-ca-islamic-umalqura', { day: 'numeric', month: 'long' }).format(d);
    if (/[ء-ي]{3}/.test(h) && !/[/]/.test(h)) s += ' · ' + h.replace(/\s*هـ\s*$/, '');
  } catch (e) {}
  return s;
}

function SectionHead({ c, title, action, onAction, top = 38 }) {
  return (
    <View style={{ flexDirection: 'row', alignItems: 'center', marginTop: top, marginBottom: 12 }}>
      <T size={22} w="700" color={c.text} style={{ flex: 1 }}>
        {title}
      </T>
      {action && (
        <Press onPress={onAction} hitSlop={8} silent>
          {({ hover }) => (
            <View style={{ flexDirection: 'row', alignItems: 'center', gap: 2, opacity: hover ? 0.7 : 1 }}>
              <T size={16} color={c.accent}>
                {action}
              </T>
              <Icon name="chevron-left" size={17} color={c.accent} />
            </View>
          )}
        </Press>
      )}
    </View>
  );
}

/** The slide, its earlier ink kept, with the current step's ink writing itself again and again. */
function LiveArtwork({ width }) {
  const [k, setK] = useState(1);
  useEffect(() => {
    const id = setInterval(() => setK((x) => x + 1), 5600);
    return () => clearInterval(id);
  }, []);
  return <SlideStage page={sinePage} width={width} pastMarks={pastInk} marks={liveInk} playKey={k} animate />;
}

/** The lecture's steps as segments: the done ones full, the one you're on breathing. */
function Pips({ n = resume.stepCount, at = resume.step - 1 }) {
  const v = useLoop(1800);
  return (
    <View style={{ flexDirection: 'row', gap: 4, marginTop: 16 }}>
      {Array.from({ length: n }, (_, k) => (
        <View key={k} style={{ flex: 1, height: 4, borderRadius: 2, backgroundColor: k < at ? 'rgba(255,255,255,0.9)' : 'rgba(255,255,255,0.18)', overflow: 'hidden' }}>
          {k === at && <Animated.View style={{ ...StyleSheet.absoluteFillObject, backgroundColor: MINT, opacity: v.interpolate({ inputRange: [0, 0.5, 1], outputRange: [0.35, 1, 0.35] }) }} />}
        </View>
      ))}
    </View>
  );
}

/** "Now playing": the lecture you're in, in the player's own light, its slide still being inked. */
function NowCard({ wide, onPlay }) {
  const [box, onBox] = useSize();
  const aw = box ? (wide ? Math.round(Math.min(440, (box.w - 52 - 30) * 0.52)) : box.w - 36) : 0;
  const meta = (
    <View style={{ flex: wide ? 1 : undefined, justifyContent: 'center' }}>
      <View style={{ flexDirection: 'row', alignItems: 'center', gap: 4 }}>
        <Pulse color={MINT} size={7} />
        <T size={13} w="600" color={MINT}>
          أكمل من حيث وقفت
        </T>
      </View>
      <T size={wide ? 32 : 26} w="700" color="#FFFFFF" lh={wide ? 46 : 38} style={{ marginTop: 6 }}>
        {current.ar}
      </T>
      <T size={15} color="rgba(255,255,255,0.62)">
        {`المحاضرة ${ORDINAL[current.n - 1]} · صفحة ${current.page} من ${current.pages}`}
      </T>
      <Pips />
      <T size={15} color="rgba(255,255,255,0.88)" style={{ marginTop: 10 }}>
        {`الخطوة ${resume.step} من ${resume.stepCount}: ${resume.stepTitle}`}
      </T>
      <View style={{ flexDirection: 'row', alignItems: 'center', gap: 10, marginTop: 8 }}>
        <Ring size={22} stroke={3} value={useTween(current.done, { ms: 1200, delay: 500 })} color={MINT} track="rgba(255,255,255,0.18)" />
        <T size={13} color="rgba(255,255,255,0.62)">
          <Count to={Math.round(current.done * 100)} delay={500} suffix="٪" size={13} w="600" color="#FFFFFF" />
          {' من المحاضرة · باقي تقريبًا ٢٥ دقيقة'}
        </T>
      </View>
      <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 10, marginTop: 22 }}>
        <Capsule label="أكمل" glyph="play" onPress={onPlay} bg="#FFFFFF" fg="#000000" hoverBg="#E8FFFA" />
        <Capsule label="من أولها" onPress={onPlay} bg="rgba(255,255,255,0.14)" fg="#FFFFFF" hoverBg="rgba(255,255,255,0.22)" />
      </View>
    </View>
  );
  return (
    <View onLayout={onBox} style={{ borderRadius: 26, overflow: 'hidden', backgroundColor: DEEP }}>
      {box && <Ambient w={box.w} h={box.h} dim={0.9} />}
      <View style={{ padding: wide ? 26 : 18, flexDirection: wide ? 'row' : 'column', gap: wide ? 30 : 18 }}>
        {box && (
          <Tilt radius={wide ? 14 : 12}>
            <Pressable onPress={onPlay} style={{ borderRadius: wide ? 14 : 12, overflow: 'hidden', shadowColor: '#000', shadowOpacity: 0.5, shadowRadius: 24, shadowOffset: { width: 0, height: 14 } }}>
              <LiveArtwork width={aw} />
            </Pressable>
          </Tilt>
        )}
        {meta}
      </View>
    </View>
  );
}

/** This week as rings, one a day, the way Fitness shows a week; today ringed in the tutor's ink. */
function WeekCard({ c, wide }) {
  const today = new Date().getDay();
  const mins = WEEK_MIN.map((m, k) => (k > today ? null : m));
  let streak = 0;
  for (let k = today; k >= 0 && mins[k] > 0; k--) streak++;
  const total = mins.reduce((s, m) => s + (m || 0), 0);
  const days = (
    <View style={{ flex: wide ? 1.3 : undefined, flexDirection: 'row', justifyContent: 'space-between' }}>
      {mins.map((m, k) => (
        <Day key={k} c={c} k={k} m={m} today={k === today} />
      ))}
    </View>
  );
  const stat = (value, label, delay, suffix) => (
    <View style={{ flex: 1 }}>
      <Count to={value} delay={delay} suffix={suffix} size={28} w="600" color={c.text} lh={36} />
      <T size={13} color={c.text2}>
        {label}
      </T>
    </View>
  );
  const stats = (
    <View style={{ flex: wide ? 1 : undefined, flexDirection: 'row', gap: 12 }}>
      {stat(total, 'دقيقة هالأسبوع', 300)}
      {stat(streak, streak > 2 ? 'أيام ورا بعض' : 'يوم ورا بعض', 450)}
      {stat(72, 'صح من أول مرة', 600, '٪')}
    </View>
  );
  return (
    <View style={{ backgroundColor: c.raised, borderRadius: 20, padding: 18, flexDirection: wide ? 'row' : 'column', gap: wide ? 28 : 20, alignItems: wide ? 'center' : 'stretch' }}>
      {days}
      {wide && <View style={{ width: hair, alignSelf: 'stretch', backgroundColor: c.sep }} />}
      {stats}
    </View>
  );
}

function Day({ c, k, m, today }) {
  const v = useTween(m === null ? 0 : m / GOAL_MIN, { ms: 900, delay: 200 + k * 70 });
  const met = m !== null && m >= GOAL_MIN;
  return (
    <View style={{ alignItems: 'center', width: 40 }}>
      <View style={{ width: 22, height: 22, alignItems: 'center', justifyContent: 'center' }}>
        <T size={13} w={today ? '700' : '500'} color={today ? c.ink : c.text2} align="center" lh={18}>
          {DAY_LETTER[k]}
        </T>
        {today && <InkRing w={22} h={20} color={c.ink} delay={1100} lw={1.8} />}
      </View>
      <View style={{ marginTop: 8, width: 34, height: 34, alignItems: 'center', justifyContent: 'center' }}>
        <Ring size={34} stroke={4} value={v} color={c.accent} track={c.fill} dashed={m === null} />
        {met && (
          <View style={{ position: 'absolute' }}>
            <Icon name="check" size={13} color={c.accent} />
          </View>
        )}
      </View>
      <T size={11} color={m === null ? c.text3 : c.text2} align="center" style={{ marginTop: 4 }}>
        {m === null ? '—' : String(m)}
      </T>
    </View>
  );
}

function Shelf({ c, size, onOpen }) {
  return (
    <ScrollView horizontal showsHorizontalScrollIndicator={false} style={{ marginHorizontal: -10 }} contentContainerStyle={{ gap: 18, paddingHorizontal: 10, paddingVertical: 10 }}>
      {LECTURES.map((l, k) => (
        <Press key={l.n} onPress={l.current ? onOpen : undefined} scaleTo={0.97} style={{ width: size }}>
          <Tilt radius={size * 0.07}>
            <View style={{ borderRadius: size * 0.07, shadowColor: '#000', shadowOpacity: isDark() ? 0 : 0.16, shadowRadius: 14, shadowOffset: { width: 0, height: 8 } }}>
              <Cover lec={l} size={size} delay={k * 120} />
            </View>
          </Tilt>
          <T size={15} w="600" color={c.text} numberOfLines={1} style={{ marginTop: 10 }}>
            {l.ar}
          </T>
          <T size={13} color={l.current ? c.accent : c.text2} numberOfLines={1}>
            {l.preparing !== undefined
              ? `يتجهّز · ${Math.round(l.preparing * 100)}٪`
              : l.current
              ? `وصلت صفحة ${l.page} من ${l.pages}`
              : `خلصتها · ${l.pages} صفحة`}
          </T>
        </Press>
      ))}
    </ScrollView>
  );
}

const STAGE_LABELS = ['قراءة الملف', 'تحديد المناطق', 'كتابة الشرح', 'المراجعة'];

/**
 * The next lecture while it's being prepared, as a live activity: which stage it's at, slides
 * turning ready one by one, and roughly how long is left (Flighty's way of showing a flight).
 */
function Preparing({ c, wide }) {
  const total = importJob.slideCount;
  const [ready, setReady] = useState(importJob.scripted);
  const [bar, onBar] = useSize();
  useEffect(() => {
    const id = setInterval(() => setReady((r) => (r >= total - 1 ? importJob.scripted : r + 1)), 2400);
    return () => clearInterval(id);
  }, []);
  const at = 2;
  const left = Math.max(1, Math.round((total - ready) * 0.18));
  const thumbs = wide ? 14 : 8;
  const first = Math.max(1, ready - Math.floor(thumbs / 2) + 1);
  return (
    <View style={{ backgroundColor: c.raised, borderRadius: 20, padding: 18 }}>
      <View style={{ flexDirection: 'row', gap: 16, alignItems: 'center' }}>
        <Cover lec={preparing} size={wide ? 76 : 64} />
        <View style={{ flex: 1 }}>
          <View style={{ flexDirection: 'row', alignItems: 'center', gap: 2 }}>
            <Pulse color={c.accent} size={6} />
            <T size={12} w="600" color={c.accent}>
              يتجهّز الحين
            </T>
          </View>
          <T size={17} w="600" color={c.text} numberOfLines={1}>
            {`المحاضرة ${ORDINAL[preparing.n - 1]}: ${preparing.ar}`}
          </T>
          <T size={13} color={c.text2}>
            {`${ready} من ${total} شريحة جاهزة · باقي تقريبًا ${left} ${left > 2 && left < 11 ? 'دقايق' : 'دقيقة'}`}
          </T>
        </View>
      </View>
      <View style={{ flexDirection: 'row', alignItems: 'center', marginTop: 18 }}>
        {STAGE_LABELS.map((s, k) => (
          <React.Fragment key={k}>
            {k > 0 && <View style={{ flex: 1, height: 2, borderRadius: 1, marginHorizontal: 6, backgroundColor: k <= at ? c.accent : c.fill }} />}
            <View style={{ flexDirection: 'row', alignItems: 'center', gap: 6 }}>
              {k < at ? (
                <View style={{ width: 18, height: 18, borderRadius: 9, backgroundColor: c.accent, alignItems: 'center', justifyContent: 'center' }}>
                  <Icon name="check" size={11} color={c.onAccent} />
                </View>
              ) : k === at ? (
                <Pulse color={c.accent} size={8} />
              ) : (
                <View style={{ width: 18, height: 18, borderRadius: 9, borderWidth: 2, borderColor: c.fill }} />
              )}
              {(wide || k === at) && (
                <T size={13} w={k === at ? '600' : '400'} color={k <= at ? c.text : c.text2}>
                  {s}
                </T>
              )}
            </View>
          </React.Fragment>
        ))}
      </View>
      <View onLayout={onBar} style={{ height: 6, borderRadius: 3, backgroundColor: c.fill, marginTop: 16, overflow: 'hidden' }}>
        <View style={{ position: 'absolute', right: 0, top: 0, bottom: 0, width: `${(ready / total) * 100}%`, borderRadius: 3, backgroundColor: c.accent }} />
        {bar && <Shimmer width={bar.w} opacity={isDark() ? 0.35 : 0.6} />}
      </View>
      <View style={{ flexDirection: 'row', gap: 6, marginTop: 14 }}>
        {Array.from({ length: thumbs }, (_, j) => {
          const n = first + j;
          const state = n <= ready ? 'ready' : n === ready + 1 ? 'writing' : 'waiting';
          return <Thumb key={n} c={c} n={n} state={state} />;
        })}
      </View>
    </View>
  );
}

function Thumb({ c, n, state }) {
  return (
    <View style={{ flex: 1 }}>
      <View style={{ aspectRatio: 4 / 3, borderRadius: 4, overflow: 'hidden', backgroundColor: state === 'waiting' ? c.fill : '#FFFFFF', borderWidth: hair, borderColor: c.sep }}>
        {state !== 'waiting' && (
          <Svg width="100%" height="100%" viewBox="0 0 40 30">
            <Rect x={5} y={5} width={18} height={2.4} rx={1.2} fill="#C9CDD2" />
            <Rect x={5} y={10} width={26} height={1.6} rx={0.8} fill="#E1E4E8" />
            <Rect x={5} y={14} width={22} height={1.6} rx={0.8} fill="#E1E4E8" />
            {state === 'ready' && <Path d={`M6 ${22 + (n % 3)} Q 14 ${17 + (n % 4)} 20 ${22 - (n % 2)} T 34 ${20 + (n % 3)}`} stroke={PEN} strokeWidth={1.6} fill="none" strokeLinecap="round" />}
          </Svg>
        )}
        {state === 'writing' && <Shimmer width={60} color={PEN} opacity={0.25} />}
      </View>
      <T size={10} color={state === 'writing' ? c.accent : c.text3} align="center" style={{ marginTop: 2 }}>
        {String(n)}
      </T>
    </View>
  );
}

const DUE = ['اليوم', 'اليوم', 'بكرة', 'بعد ٣ أيام', 'بعد أسبوع'];

function ReviewList({ c, limit = 3 }) {
  const items = reviewItems.slice(0, limit);
  return (
    <View style={{ backgroundColor: c.raised, borderRadius: 16, overflow: 'hidden' }}>
      {items.map((it, k) => (
        <Press key={it.id} scaleTo={0.99} hoverBg={c.hover} onPress={() => {}}>
          <View style={{ flexDirection: 'row', alignItems: 'center', paddingVertical: 12, paddingHorizontal: 14, gap: 14 }}>
            <View style={{ borderRadius: 8, overflow: 'hidden', borderWidth: hair, borderColor: c.sep }}>
              <SlideCrop page={sinePage} focus={it.focus} w={64} h={48} zoom={2.6} />
            </View>
            <View style={{ flex: 1 }}>
              <Question text={it.question} c={c} />
              <T size={13} color={c.text2} style={{ marginTop: 2 }}>
                {`جاوبت ${ltr(it.yours)} · المحاضرة ${it.lecture}، صفحة ${it.page}`}
              </T>
            </View>
            <View style={{ paddingHorizontal: 9, height: 24, borderRadius: 12, justifyContent: 'center', backgroundColor: k < 2 ? c.accentSoft : c.fill }}>
              <T size={12} w="600" color={k < 2 ? c.accent : c.text2}>
                {DUE[k]}
              </T>
            </View>
            <Icon name="chevron-left" size={18} color={c.text3} />
          </View>
          {k < items.length - 1 && <View style={{ height: hair, backgroundColor: c.sep, marginRight: 92 }} />}
        </Press>
      ))}
    </View>
  );
}

function Question({ text, c, size = 16 }) {
  const parts = text.split('`');
  return (
    <T size={size} w="500" color={c.text} numberOfLines={1}>
      {'‏'}
      {parts.map((s, k) => (k % 2 ? <Text key={k}>{ltr(s)}</Text> : s))}
    </T>
  );
}

function MiniPlayer({ c, onOpen, style }) {
  return (
    <Press onPress={onOpen} scaleTo={0.985} style={[{ borderRadius: 18, backgroundColor: c.bar, borderWidth: hair, borderColor: c.sep, overflow: 'hidden', shadowColor: '#000', shadowOpacity: isDark() ? 0 : 0.14, shadowRadius: 24, shadowOffset: { width: 0, height: 8 } }, style]}>
      {({ hover }) => (
        <>
          <View style={{ height: 2, backgroundColor: c.fill }}>
            <View style={{ position: 'absolute', right: 0, top: 0, bottom: 0, width: `${((resume.step - 0.5) / resume.stepCount) * 100}%`, backgroundColor: c.accent }} />
          </View>
          <View style={{ flexDirection: 'row', alignItems: 'center', height: 64, paddingHorizontal: 10, gap: 12, backgroundColor: hover ? c.hover : 'transparent' }}>
            <View style={{ borderRadius: 7, overflow: 'hidden' }}>
              <SlideStage page={sinePage} width={62} pastMarks={pastInk} />
            </View>
            <View style={{ flex: 1 }}>
              <T size={15} w="600" color={c.text} numberOfLines={1}>
                {sinePage.title}
              </T>
              <T size={13} color={c.text2} numberOfLines={1}>
                {`${current.ar} · الخطوة ${resume.step} من ${resume.stepCount}`}
              </T>
            </View>
            <Press onPress={onOpen} hitSlop={10} style={{ padding: 8, borderRadius: 20 }} hoverBg={c.fill}>
              <Glyph name="play" size={24} color={c.text} />
            </Press>
            <Press onPress={onOpen} hitSlop={10} style={{ padding: 8, borderRadius: 20 }} hoverBg={c.fill}>
              <Glyph name="fwd" flip size={24} color={c.text} />
            </Press>
          </View>
        </>
      )}
    </Press>
  );
}

const NAV = [
  { key: 'home', label: 'الرئيسية', icon: 'home' },
  { key: 'library', label: 'المكتبة', icon: 'library' },
  { key: 'review', label: 'المراجعة', icon: 'review', badge: reviewItems.length + 2 },
  { key: 'import', label: 'محاضرة جديدة', icon: 'plus' },
];

function Sidebar({ c, tab, setTab }) {
  return (
    <View style={{ width: 268, backgroundColor: c.sidebar, borderLeftWidth: hair, borderLeftColor: c.sep, paddingHorizontal: 12, paddingTop: 22 }}>
      <View style={{ flexDirection: 'row', alignItems: 'center', gap: 10, paddingHorizontal: 8, marginBottom: 22 }}>
        <LogoMark size={32} />
        <T size={22} w="700" color={c.text}>
          مُعيد
        </T>
      </View>
      {NAV.map((n) => {
        const on = n.key === tab;
        return (
          <Press key={n.key} onPress={() => setTab(n.key)} scaleTo={0.98} hoverBg={on ? undefined : c.hover} style={{ flexDirection: 'row', alignItems: 'center', height: 44, borderRadius: 11, paddingHorizontal: 10, gap: 12, backgroundColor: on ? c.accentSoft : 'transparent' }}>
            <NibIcon name={n.icon} size={22} color={c.accent} active={on} weight={on ? 2.7 : 2.2} />
            <T size={17} w={on ? '600' : '400'} color={on ? c.accent : c.text} style={{ flex: 1 }}>
              {n.label}
            </T>
            {n.badge && (
              <T size={14} w="500" color={c.text2}>
                {String(n.badge)}
              </T>
            )}
          </Press>
        );
      })}
      <T size={13} w="600" color={c.text2} style={{ marginTop: 26, marginBottom: 6, paddingHorizontal: 10 }}>
        المقررات
      </T>
      {[
        ['٢٠٧', 'الدوائر الكهربائية', COVERS[4], 5, 12],
        ['٢١١', 'الإلكترونيات', COVERS[0], 0, 10],
      ].map(([code, name, color, done, all]) => (
        <Press key={code} scaleTo={0.98} hoverBg={c.hover} onPress={() => {}} style={{ flexDirection: 'row', alignItems: 'center', height: 44, borderRadius: 11, paddingHorizontal: 10, gap: 12 }}>
          <View style={{ width: 24, height: 24, borderRadius: 6, backgroundColor: color, alignItems: 'center', justifyContent: 'center' }}>
            <T size={9} w="700" color="#FFFFFF" lh={12}>
              {code}
            </T>
          </View>
          <T size={16} color={c.text} style={{ flex: 1 }} numberOfLines={1}>
            {name}
          </T>
          <T size={12} color={c.text3}>
            {`${done}/${all}`}
          </T>
        </Press>
      ))}
    </View>
  );
}

function TabBar({ c, tab, setTab }) {
  return (
    <View style={{ flexDirection: 'row', backgroundColor: c.bar, borderTopWidth: hair, borderTopColor: c.sep, paddingTop: 7, paddingBottom: 8 }}>
      {NAV.map((n) => {
        const on = n.key === tab;
        return (
          <Press key={n.key} onPress={() => setTab(n.key)} scaleTo={0.9} outer={{ flex: 1 }} style={{ alignItems: 'center' }}>
            <NibIcon name={n.icon} size={25} color={on ? c.accent : c.text2} active={on} weight={on ? 2.6 : 2.1} />
            <T size={10} w="500" color={on ? c.accent : c.text2} align="center" lh={14} style={{ marginTop: 2 }}>
              {n.label}
            </T>
          </Press>
        );
      })}
    </View>
  );
}

function Home({ wide, onOpen }) {
  const c = pal();
  const [tab, setTab] = useState('home');
  const y = useValue(0);
  const onScroll = Animated.event([{ nativeEvent: { contentOffset: { y } } }], { useNativeDriver: ND });
  const compact = y.interpolate({ inputRange: [40, 70], outputRange: [0, 1], extrapolate: 'clamp' });
  const sections = (
    <>
      <Rise>
        <T size={13} w="600" color={c.text2}>
          {dateLine()}
        </T>
        <View style={{ flexDirection: 'row', alignItems: 'center' }}>
          <T size={36} w="700" color={c.text} lh={50} style={{ flex: 1 }}>
            الرئيسية
          </T>
          {!wide && <LogoMark size={32} />}
        </View>
      </Rise>
      <Rise delay={90} style={{ marginTop: 12 }}>
        <NowCard wide={wide} onPlay={onOpen} />
      </Rise>
      <Rise delay={180}>
        <SectionHead c={c} title="هالأسبوع" action="التفاصيل" />
        <WeekCard c={c} wide={wide} />
      </Rise>
      <Rise delay={260}>
        <SectionHead c={c} title="الدوائر الكهربائية" action="عرض الكل" />
        <Shelf c={c} size={wide ? 164 : 136} onOpen={onOpen} />
      </Rise>
      <Rise delay={330}>
        <SectionHead c={c} title="الجاية" top={26} />
        <Preparing c={c} wide={wide} />
      </Rise>
      <Rise delay={400}>
        <SectionHead c={c} title={`للمراجعة · ${reviewItems.length + 2}`} action="ابدأ المراجعة" />
        <ReviewList c={c} limit={wide ? 4 : 3} />
        <T size={13} color={c.text2} style={{ marginTop: 8, paddingHorizontal: 4 }}>
          الأسئلة اللي غلطت فيها ترجع لك هنا، كل وحدة مع مكانها في السلايد.
        </T>
      </Rise>
    </>
  );
  const bar = (
    <Animated.View pointerEvents="none" style={{ position: 'absolute', top: 0, left: 0, right: 0, height: 50, backgroundColor: c.bar, borderBottomWidth: hair, borderBottomColor: c.sep, opacity: compact, alignItems: 'center', justifyContent: 'center' }}>
      <T size={17} w="600" color={c.text} align="center">
        الرئيسية
      </T>
    </Animated.View>
  );
  if (wide) {
    return (
      <View style={{ flex: 1, flexDirection: 'row', backgroundColor: c.bg }}>
        <Sidebar c={c} tab={tab} setTab={setTab} />
        <View style={{ flex: 1 }}>
          <Animated.ScrollView onScroll={onScroll} scrollEventThrottle={16} contentContainerStyle={{ paddingHorizontal: 40, paddingTop: 26, paddingBottom: 130, maxWidth: 1040, width: '100%', alignSelf: 'center' }}>
            {sections}
          </Animated.ScrollView>
          {bar}
          <MiniPlayer c={c} onOpen={onOpen} style={{ position: 'absolute', bottom: 18, left: 40, right: 40 }} />
        </View>
      </View>
    );
  }
  return (
    <View style={{ flex: 1, backgroundColor: c.bg }}>
      <Animated.ScrollView onScroll={onScroll} scrollEventThrottle={16} contentContainerStyle={{ padding: 16, paddingTop: 10, paddingBottom: 110 }}>
        {sections}
      </Animated.ScrollView>
      {bar}
      <MiniPlayer c={c} onOpen={onOpen} style={{ position: 'absolute', bottom: 70, left: 8, right: 8 }} />
      <TabBar c={c} tab={tab} setTab={setTab} />
    </View>
  );
}

// MARK: Player

/** Words and the math between backticks, so a line can light up one word at a time. */
function tokens(text) {
  const out = [];
  text.split('`').forEach((part, k) => {
    if (k % 2) {
      out.push({ w: part, term: true });
      return;
    }
    part.split(/(\s+)/).forEach((s) => {
      if (!s) return;
      out.push(/^\s+$/.test(s) ? { sp: s } : { w: s });
    });
  });
  return out;
}

// Keeps `t = 0.3 s` on one line in the browser; native Text never breaks at the no-break spaces.
const NOWRAP = WEB ? { whiteSpace: 'nowrap' } : null;

/**
 * One line of the tutor's words. `lit` runs 0 → 1 across it, and each word fades up as the
 * light reaches it rather than snapping on.
 */
function Line({ text, size, lit }) {
  const toks = tokens(text);
  const count = toks.filter((t) => t.w !== undefined).length;
  const reach = lit * count;
  let idx = -1;
  return (
    <Text style={[face('700'), { fontSize: size, lineHeight: Math.round(size * 1.42), textAlign: 'right', writingDirection: 'rtl', color: 'rgba(255,255,255,0.3)' }]}>
      {'‏'}
      {toks.map((t, j) => {
        if (t.sp) return t.sp;
        idx += 1;
        const a = 0.3 + 0.7 * clamp01((reach - idx) * 1.6);
        return (
          <Text key={j} style={[{ color: t.term ? `rgba(143,242,226,${a})` : `rgba(255,255,255,${a})` }, t.term && NOWRAP]}>
            {t.term ? ltr(digits(t.w).replace(/ /g, ' ')) : digits(t.w)}
          </Text>
        );
      })}
    </Text>
  );
}

/** The line being said: lights across its words over the time it takes to say them. */
function Speaking({ text, size, runKey, ms }) {
  const t = useClock(runKey, ms, true);
  return <Line text={text} size={size} lit={clamp01(t / ms)} />;
}

/** A small burst of light from a right answer. */
function Burst({ color = MINT }) {
  const parts = useMemo(() => Array.from({ length: 12 }, (_, k) => ({ a: (k / 12) * Math.PI * 2 + (k % 2) * 0.2, r: 26 + (k % 3) * 9, s: 3 + (k % 3) })), []);
  const v = useValue(0);
  useEffect(() => {
    Animated.timing(v, { toValue: 1, duration: 720, easing: Easing.out(Easing.cubic), useNativeDriver: ND }).start();
  }, []);
  return (
    <View pointerEvents="none" style={{ position: 'absolute', left: '50%', top: '50%', width: 0, height: 0 }}>
      {parts.map((p, k) => (
        <Animated.View
          key={k}
          style={{
            position: 'absolute',
            width: p.s * 2,
            height: p.s * 2,
            borderRadius: p.s,
            left: -p.s,
            top: -p.s,
            backgroundColor: k % 3 ? color : '#FFFFFF',
            opacity: v.interpolate({ inputRange: [0, 0.6, 1], outputRange: [1, 0.8, 0] }),
            transform: [
              { translateX: v.interpolate({ inputRange: [0, 1], outputRange: [0, Math.cos(p.a) * p.r] }) },
              { translateY: v.interpolate({ inputRange: [0, 1], outputRange: [0, Math.sin(p.a) * p.r] }) },
              { scale: v.interpolate({ inputRange: [0, 1], outputRange: [1, 0.3] }) },
            ],
          }}
        />
      ))}
    </View>
  );
}

const LETTERS = ['أ', 'ب', 'ج', 'د'];

/** One answer: it shakes if it was your wrong pick, and the right one fills and bursts. */
function Option({ o, k, state, onPick, disabled }) {
  const shake = useValue(0);
  useEffect(() => {
    if (state !== 'wrong') return;
    Animated.sequence(
      [10, -9, 7, -5, 3, 0].map((x) => Animated.timing(shake, { toValue: x, duration: 55, easing: Easing.linear, useNativeDriver: ND }))
    ).start();
  }, [state]);
  let bg = 'rgba(255,255,255,0.1)';
  let fg = '#FFFFFF';
  let border = 'rgba(255,255,255,0.16)';
  let mark = null;
  if (state === 'right') {
    bg = RIGHT_BG;
    fg = RIGHT_FG;
    border = RIGHT_BG;
    mark = 'check';
  } else if (state === 'wrong') {
    bg = WRONG_BG;
    fg = WRONG_FG;
    border = WRONG_BG;
    mark = 'x';
  }
  return (
    <Rise delay={260 + k * 90} dy={12}>
      <Animated.View style={{ transform: [{ translateX: shake }], opacity: state === 'dim' ? 0.35 : 1 }}>
        <Press disabled={disabled} onPress={() => onPick(o.id)} silent scaleTo={0.97} hoverBg="rgba(255,255,255,0.17)" style={{ height: 58, borderRadius: 18, backgroundColor: bg, borderWidth: 1, borderColor: border, paddingHorizontal: 14, flexDirection: 'row', alignItems: 'center', gap: 14 }}>
          <View style={{ width: 30, height: 30, borderRadius: 15, backgroundColor: state === 'right' || state === 'wrong' ? 'rgba(0,0,0,0.12)' : 'rgba(255,255,255,0.12)', alignItems: 'center', justifyContent: 'center' }}>
            <T size={14} w="600" color={fg} align="center" lh={20}>
              {LETTERS[k]}
            </T>
          </View>
          <T size={20} w="600" color={fg} style={{ flex: 1 }}>
            {ltr(o.label)}
          </T>
          {mark && (
            <View style={{ width: 24, height: 24, alignItems: 'center', justifyContent: 'center' }}>
              {state === 'right' && <Burst />}
              <Icon name={mark} size={20} color={fg} />
            </View>
          )}
        </Press>
      </Animated.View>
    </Rise>
  );
}

function Chip({ label, icon, onPress }) {
  return (
    <Press onPress={onPress} hoverBg="rgba(255,255,255,0.16)" style={{ height: 34, borderRadius: 17, paddingHorizontal: 14, backgroundColor: 'rgba(255,255,255,0.08)', flexDirection: 'row', alignItems: 'center', gap: 6 }}>
      <Icon name={icon} size={14} color="rgba(255,255,255,0.75)" />
      <T size={14} w="500" color="rgba(255,255,255,0.8)">
        {label}
      </T>
    </Press>
  );
}

function AskLines({ p, size }) {
  const a = p.step.ask;
  const [hint, setHint] = useState(false);
  const answered = p.isAnswered;
  const right = p.pickedRight;
  return (
    <View>
      <View style={{ flexDirection: 'row', alignItems: 'center', gap: 6, marginBottom: 8 }}>
        <View style={{ width: 6, height: 6, borderRadius: 3, backgroundColor: '#FF9F5A' }} />
        <T size={13} w="600" color="#FFB98A">
          قبل ما أكمل، جاوب
        </T>
      </View>
      <Speaking text={a.question} size={size} runKey={'q' + p.playKey} ms={readingMs(a.question) * 0.6} />
      <View style={{ gap: 10, marginTop: 18 }}>
        {a.options.map((o, k) => {
          const isAnswer = o.id === a.answerID;
          const isPick = o.id === p.picked;
          const state = !answered ? 'idle' : isAnswer ? 'right' : isPick ? 'wrong' : 'dim';
          return <Option key={o.id} o={o} k={k} state={state} disabled={answered} onPick={p.pick} />;
        })}
      </View>
      {!answered && (
        <Rise delay={560} style={{ flexDirection: 'row', gap: 10, marginTop: 16 }}>
          <Chip label="تلميح" icon="help-circle" onPress={() => setHint(true)} />
          <Chip label="ما أدري، وريني" icon="eye" onPress={p.showAnswer} />
        </Rise>
      )}
      {hint && !answered && (
        <Rise style={{ marginTop: 14 }}>
          <Speaking text={a.hint} size={size * 0.62} runKey={'h' + p.playKey} ms={readingMs(a.hint) * 0.7} />
        </Rise>
      )}
      {answered && (
        <Rise delay={200} style={{ marginTop: 22 }}>
          <T size={17} w="700" color={right ? RIGHT_BG : WRONG_BG}>
            {right ? 'صح، أحسنت.' : p.picked ? 'مو هذا. شوف ليش:' : 'هذا الجواب، وليش:'}
          </T>
          <View style={{ marginTop: 6 }}>
            <Speaking text={a.why} size={size * 0.72} runKey={'w' + p.playKey + p.picked} ms={readingMs(a.why) * 0.7} />
          </View>
          <Rise delay={900}>
            <Capsule label="متابعة" onPress={p.next} bg="#FFFFFF" fg="#000000" hoverBg="#E8FFFA" height={50} style={{ alignSelf: 'flex-start', marginTop: 20, paddingHorizontal: 30 }} />
          </Rise>
        </Rise>
      )}
    </View>
  );
}

/** Every step said so far, as lyrics: the current one lit word by word, the earlier ones dimmed. */
function Lyrics({ p, size, padTop = 24, padBottom }) {
  const ref = useRef(null);
  const [y, setY] = useState(null);
  useEffect(() => {
    if (y !== null && ref.current) ref.current.scrollTo({ y: Math.max(0, y - padTop), animated: true });
  }, [y, p.i]);
  return (
    <ScrollView ref={ref} showsVerticalScrollIndicator={false} contentContainerStyle={{ paddingTop: padTop, paddingBottom: padBottom }}>
      {p.page.steps.slice(0, p.i + 1).map((s, k) => {
        const now = k === p.i;
        if (!now) {
          return (
            <Press key={k} onPress={() => p.go(k)} scaleTo={0.985} style={{ marginBottom: size * 0.9 }}>
              {({ hover }) => (
                <View style={[{ opacity: hover ? 0.7 : 0.36 }, WEB && !hover ? { filter: 'blur(0.8px)' } : null]}>
                  {s.ask ? <Line text={s.ask.question} size={size} lit={1} /> : s.caption.map((ph, j) => <Line key={j} text={ph} size={size} lit={1} />)}
                </View>
              )}
            </Press>
          );
        }
        return (
          <View key={k} onLayout={(e) => setY(e.nativeEvent.layout.y)} style={{ marginBottom: size }}>
            <Rise key={'r' + k} dy={26}>
              {s.ask ? (
                <AskLines key={p.playKey} p={p} size={size} />
              ) : (
                s.caption.map((ph, j) =>
                  j === p.revealed - 1 ? (
                    <Speaking key={j} text={ph} size={size} runKey={p.playKey + '-' + j} ms={(readingMs(ph) / p.speed) * 0.8} />
                  ) : (
                    <Line key={j} text={ph} size={size} lit={j < p.revealed - 1 ? 1 : 0} />
                  )
                )
              )}
            </Rise>
          </View>
        );
      })}
    </ScrollView>
  );
}

/** Roughly how long the rest of the slide takes to say, from the current step on. */
function minutesLeft(p) {
  let ms = 0;
  p.page.steps.slice(p.i).forEach((s, k) => {
    const lines = s.ask ? [s.ask.question, s.ask.why] : s.caption;
    lines.forEach((ph, j) => {
      if (k === 0 && !s.ask && j < p.revealed) return;
      ms += readingMs(ph) / p.speed + 1400;
    });
  });
  return Math.max(1, Math.round(ms / 60000));
}

/** Steps as a track: drag across it to move; it thickens under the pointer, as the system's does. */
function Scrubber({ p, width }) {
  const { step, n, i } = p;
  const within = step.ask ? (p.isAnswered ? 1 : 0.5) : step.caption.length ? p.revealed / step.caption.length : 1;
  const f = useTween((i + within) / n, { ms: 500 });
  const scrub = useScrub({ count: n, spacing: width / n, axis: 'x', current: i, onIndex: p.go, reverse: true });
  const thick = useValue(0);
  const grow = (x) => Animated.spring(thick, { toValue: x, useNativeDriver: false, speed: 30, bounciness: 4 }).start();
  const h = thick.interpolate({ inputRange: [0, 1], outputRange: [5, 10] });
  const left = minutesLeft(p);
  return (
    <Pressable onHoverIn={() => grow(1)} onHoverOut={() => grow(0)} onPressIn={() => grow(1)} onPressOut={() => grow(0)}>
      <View {...scrub.panHandlers} style={{ width, paddingVertical: 10 }}>
        <View style={{ height: 8 }}>
          {p.page.steps.map((s, k) =>
            s.ask ? <View key={k} style={{ position: 'absolute', right: ((k + 0.5) / n) * width - 3, top: 0, width: 6, height: 6, borderRadius: 3, backgroundColor: k < i || (k === i && p.isAnswered) ? MINT : '#FFB98A' }} /> : null
          )}
        </View>
        <View style={{ height: 10, justifyContent: 'center' }}>
          <Animated.View style={{ height: h, borderRadius: 5, backgroundColor: 'rgba(255,255,255,0.2)', overflow: 'hidden' }}>
            <View style={{ position: 'absolute', right: 0, top: 0, bottom: 0, width: f * width, backgroundColor: 'rgba(255,255,255,0.92)' }} />
          </Animated.View>
        </View>
        <View style={{ flexDirection: 'row', justifyContent: 'space-between', marginTop: 6 }}>
          <T size={12} w="500" color="rgba(255,255,255,0.55)">
            {`الخطوة ${i + 1} من ${n}`}
          </T>
          <T size={12} w="500" color="rgba(255,255,255,0.55)">
            {left === 1 ? 'باقي أقل من دقيقة' : `باقي ${left} دقايق`}
          </T>
        </View>
      </View>
    </Pressable>
  );
}

/** Play and pause swap with a small pop, the way the system's glyphs do. */
function PlayPause({ auto, size }) {
  const v = useValue(1);
  const first = useRef(true);
  useEffect(() => {
    if (first.current) {
      first.current = false;
      return;
    }
    v.setValue(0.55);
    Animated.spring(v, { toValue: 1, useNativeDriver: ND, speed: 18, bounciness: 12 }).start();
  }, [auto]);
  return (
    <Animated.View style={{ transform: [{ scale: v }] }}>
      <Glyph name={auto ? 'pause' : 'play'} size={size} />
    </Animated.View>
  );
}

function Transport({ p, width, big = 46 }) {
  const btn = (size, extra) => ({ width: size, height: size, borderRadius: size / 2, alignItems: 'center', justifyContent: 'center', ...extra });
  return (
    <View style={{ width }}>
      <Scrubber p={p} width={width} />
      <View style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'space-evenly', marginTop: 4 }}>
        <Press onPress={p.previous} disabled={p.isFirst} scaleTo={0.85} hoverBg="rgba(255,255,255,0.1)" style={btn(big * 1.5, { opacity: p.isFirst ? 0.3 : 1 })}>
          <Glyph name="fwd" size={big * 0.72} />
        </Press>
        <Press onPress={p.toggleAuto} scaleTo={0.85} hoverBg="rgba(255,255,255,0.1)" style={btn(big * 1.7)}>
          <PlayPause auto={p.auto} size={big} />
        </Press>
        <Press onPress={p.next} disabled={p.isLast} scaleTo={0.85} hoverBg="rgba(255,255,255,0.1)" style={btn(big * 1.5, { opacity: p.isLast ? 0.3 : 1 })}>
          <Glyph name="fwd" flip size={big * 0.72} />
        </Press>
      </View>
      <View style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginTop: 10 }}>
        <Press onPress={p.cycleSpeed} hoverBg="rgba(255,255,255,0.22)" style={{ paddingHorizontal: 11, height: 28, borderRadius: 14, backgroundColor: 'rgba(255,255,255,0.14)', justifyContent: 'center' }}>
          <T size={13} w="600" color="rgba(255,255,255,0.85)" lh={18}>
            {ltr(digits(String(p.speed)) + '×')}
          </T>
        </Press>
        <Press onPress={p.replay} scaleTo={0.85} hoverBg="rgba(255,255,255,0.12)" style={{ width: 34, height: 34, borderRadius: 17, alignItems: 'center', justifyContent: 'center' }}>
          <NibIcon name="review" size={22} color="rgba(255,255,255,0.8)" weight={2.3} />
        </Press>
      </View>
    </View>
  );
}

function RoundButton({ icon, onPress }) {
  return (
    <Press onPress={onPress} hitSlop={8} scaleTo={0.88} hoverBg="rgba(255,255,255,0.24)" style={{ width: 36, height: 36, borderRadius: 18, backgroundColor: 'rgba(255,255,255,0.14)', alignItems: 'center', justifyContent: 'center' }}>
      <Icon name={icon} size={19} color="#FFFFFF" />
    </Press>
  );
}

function Player({ wide, onBack }) {
  const p = usePlayer(sinePage);
  const [area, onArea] = useSize();
  const [full, onFull] = useSize();
  const inkFor = (k) => (p.page.steps[k].ask ? ASK_PEN : PEN);
  // Once a question is answered, the tutor rings where the answer was on the slide.
  const ringT = useClock('ring' + p.playKey + String(p.isAnswered), 800, p.step.ask && p.isAnswered);
  const ring = useMemo(() => ellipsePath(ANSWER_AT[0] - 20, ANSWER_AT[1] - 18, 40, 36), []);
  const overlay = ({ tip }) => (
    <>
      {tip.drawing && (
        <>
          <Circle cx={tip.x} cy={tip.y} r={16} fill={inkFor(p.i)} fillOpacity={0.16} />
          <Circle cx={tip.x} cy={tip.y} r={6} fill={inkFor(p.i)} />
        </>
      )}
      {p.step.ask && p.isAnswered && <DrawnPath geo={ring} progress={easeOut(clamp01(ringT / 700))} color={PEN} width={5} />}
    </>
  );

  const top = (
    <View style={{ height: 60, flexDirection: 'row', alignItems: 'center', paddingHorizontal: 18, gap: 12 }}>
      <RoundButton icon="chevron-down" onPress={onBack} />
      <View style={{ flex: 1, alignItems: 'center' }}>
        <T size={15} w="600" color="#FFFFFF" align="center" numberOfLines={1}>
          {current.ar}
        </T>
        <T size={12} color="rgba(255,255,255,0.6)" align="center" numberOfLines={1}>
          {`المحاضرة ${ORDINAL[current.n - 1]} · صفحة ${current.page} من ${current.pages}`}
        </T>
      </View>
      <RoundButton icon="more-horizontal" />
    </View>
  );

  let body = null;
  if (area) {
    if (wide) {
      const colW = Math.min(area.w * 0.52, ((area.h - 260) * 4) / 3);
      body = (
        <View style={{ flex: 1, flexDirection: 'row', paddingHorizontal: 40 }}>
          <Rise dy={30} style={{ width: colW, justifyContent: 'center' }}>
            <View style={{ borderRadius: 14, shadowColor: '#000', shadowOpacity: 0.5, shadowRadius: 34, shadowOffset: { width: 0, height: 18 } }}>
              <InkSlide p={p} width={colW} inkFor={inkFor} pastOpacity={0.32} onJump={p.go} overlay={overlay} radius={14} />
            </View>
            <View style={{ marginTop: 22, flexDirection: 'row', alignItems: 'flex-end' }}>
              <View style={{ flex: 1 }}>
                <T size={20} w="700" color="#FFFFFF" numberOfLines={1}>
                  {sinePage.title}
                </T>
                <T serif italic size={15} color="rgba(255,255,255,0.6)" numberOfLines={1}>
                  {sinePage.deckTitle}
                </T>
              </View>
            </View>
            <View style={{ marginTop: 4 }}>
              <Transport p={p} width={colW} />
            </View>
          </Rise>
          <View style={{ flex: 1, marginRight: 56 }}>
            <Lyrics p={p} size={Math.min(34, Math.max(26, area.w / 34))} padTop={area.h * 0.12} padBottom={area.h * 0.6} />
          </View>
        </View>
      );
    } else {
      const sw = area.w - 32;
      body = (
        <View style={{ flex: 1, paddingHorizontal: 16 }}>
          <Rise dy={24} style={{ borderRadius: 12, overflow: 'hidden' }}>
            <InkSlide p={p} width={sw} inkFor={inkFor} pastOpacity={0.32} onJump={p.go} overlay={overlay} radius={12} />
          </Rise>
          <View style={{ flex: 1 }}>
            <Lyrics p={p} size={24} padTop={16} padBottom={area.h * 0.4} />
          </View>
          <View style={{ paddingBottom: 10 }}>
            <Transport p={p} width={sw} big={40} />
          </View>
        </View>
      );
    }
  }

  return (
    <View style={{ flex: 1, backgroundColor: DEEP }} onLayout={onFull}>
      {full && <Ambient w={full.w} h={full.h} />}
      {top}
      <View style={{ flex: 1 }} onLayout={onArea}>
        {body}
      </View>
    </View>
  );
}

/**
 * The player is a sheet over the library, as Music's is: it rises from the bottom while the
 * library sinks back a little and dims, and it falls away again when you pull it down.
 */
export function NativeApp({ wide }) {
  const [open, setOpen] = useState(false);
  const [h, setH] = useState(900);
  const v = useValue(0);
  const show = () => {
    setOpen(true);
    v.setValue(0);
    Animated.spring(v, { toValue: 1, useNativeDriver: ND, speed: 11, bounciness: 3 }).start();
  };
  const hide = () => Animated.timing(v, { toValue: 0, duration: 340, easing: Easing.in(Easing.quad), useNativeDriver: ND }).start(({ finished }) => finished && setOpen(false));
  return (
    <View style={{ flex: 1, backgroundColor: '#000000' }} onLayout={(e) => setH(e.nativeEvent.layout.height)}>
      <Animated.View
        style={{
          flex: 1,
          overflow: 'hidden',
          borderRadius: open ? 16 : 0,
          opacity: v.interpolate({ inputRange: [0, 1], outputRange: [1, 0.55] }),
          transform: [{ scale: v.interpolate({ inputRange: [0, 1], outputRange: [1, 0.93] }) }],
        }}
      >
        <Home wide={wide} onOpen={show} />
      </Animated.View>
      {open && (
        <Animated.View style={[StyleSheet.absoluteFill, { borderTopLeftRadius: 16, borderTopRightRadius: 16, overflow: 'hidden', transform: [{ translateY: v.interpolate({ inputRange: [0, 1], outputRange: [h, 0] }) }] }]}>
          <Player wide={wide} onBack={hide} />
        </Animated.View>
      )}
    </View>
  );
}

export const native = {
  key: 'native',
  name: 'الأصلي',
  line: 'أنماط iPadOS نفسها بخط IBM Plex Sans Arabic وأرقام عربية: السلايد هو الغلاف، والشرح يمشي جنبه مثل كلمات Apple Music، وحبر المعيد يطلع من السلايد للواجهة.',
  refs: 'Apple Music · Apple Books · Fitness · Flighty · ثمانية · Speak · Brilliant',
  swatches: ['#061210', '#FFFFFF', '#0A8F86', '#F4F4F7', '#14776C'],
  App: NativeApp,
};
