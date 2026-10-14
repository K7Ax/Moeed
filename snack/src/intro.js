// The launch: the logo builds itself from the bottom step up, a little figure climbs its
// stair one tread at a time and leaps into the doorway, where play appears. Then the name
// is written in, right to left.
import React, { useEffect, useRef, useState } from 'react';
import { Animated, Pressable, StyleSheet, View } from 'react-native';
import Svg, { Circle, ClipPath, Defs, G, Image as SvgImage, Line, Path, Polygon } from 'react-native-svg';
import { C, T, clamp01, easeInOut, easeOut } from './theme';
import { LOGO, LOGO_URI } from './logo';

const TL = {
  build: 100, // the bottom step starts rising
  buildGap: 120,
  buildDur: 380,
  archIn: 560,
  archDur: 560,
  figureIn: 1050,
  hopStart: 1250,
  hop: 300,
  hopRest: 60,
  leap: 400,
  pop: 380,
  wordDur: 800,
  underline: 450,
  hold: 650,
  fade: 380,
};
const HOPS = LOGO.spots.length - 1;
const LEAP_AT = TL.hopStart + HOPS * (TL.hop + TL.hopRest);
const POP_AT = LEAP_AT + TL.leap;
const WORD_AT = POP_AT + 150;
const LINE_AT = WORD_AT + TL.wordDur - 150;
const DONE_AT = LINE_AT + TL.underline + TL.hold;

// The stair pieces in the order they rise.
const BUILD = ['bottom', 'middle', 'top', 'block'];
const K = 5.8; // the figure's size in the logo's 900-unit space

function useTime(running) {
  const [t, setT] = useState(0);
  useEffect(() => {
    if (!running) return undefined;
    let raf;
    const start = Date.now();
    const tick = () => {
      const e = Date.now() - start;
      setT(e);
      if (e < DONE_AT + 100) raf = requestAnimationFrame(tick);
    };
    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
  }, [running]);
  return t;
}

const lerp = (a, b, f) => a + (b - a) * f;

/** The climber, feet at (x, y), facing `dir` (1 right, -1 left). `tuck` bends it mid-hop, `squash` lands it. */
function Figure({ x, y, tuck, squash, dir, opacity, scale, color, halo }) {
  const h = 1 - squash * 0.12;
  const f = (dx) => x + dx * K * dir;
  const hip = [x, y - 7 * K * h];
  const neck = [x, y - 15.5 * K * h];
  const head = [f(0.6), y - 19.4 * K * h];
  const shoulder = y - 13 * K * h;
  const limbs = [
    [neck, hip],
    [hip, [f(lerp(-3, -1.5, tuck)), y - lerp(0, 3, tuck) * K]],
    [hip, [f(lerp(3, 4, tuck)), y - lerp(0, 4, tuck) * K]],
    [[x, shoulder], [f(lerp(-4, -4.5, tuck)), y - lerp(9, 14, tuck) * K * h]],
    [[x, shoulder], [f(lerp(4, 5, tuck)), y - lerp(10, 15, tuck) * K * h]],
  ];
  const sw = 2.3 * K;
  const pivot = y - 10 * K;
  // Drawn twice: a wide pass in the background colour first, so it reads cleanly on the logo.
  const pass = (stroke, width, r, key) => (
    <G key={key}>
      {limbs.map(([a, b], i) => (
        <Line key={i} x1={a[0]} y1={a[1]} x2={b[0]} y2={b[1]} stroke={stroke} strokeWidth={width} strokeLinecap="round" />
      ))}
      <Circle cx={head[0]} cy={head[1]} r={r} fill={stroke} />
    </G>
  );
  return (
    <G opacity={opacity} transform={`translate(${x} ${pivot}) scale(${scale}) translate(${-x} ${-pivot})`}>
      {pass(halo, sw + 10, 3.3 * K + 5, 'halo')}
      {pass(color, sw, 3.3 * K, 'ink')}
    </G>
  );
}

function figureAt(t) {
  const { spots, playCenter } = LOGO;
  if (t < TL.hopStart) return { x: spots[0][0], y: spots[0][1], tuck: 0, squash: 0, dir: -1, scale: 1, fade: 0 };
  if (t >= LEAP_AT) {
    // The last jump: off the top block, into the doorway, shrinking as it goes.
    const f = clamp01((t - LEAP_AT) / TL.leap);
    const e = easeInOut(f);
    const [a, b] = [spots[HOPS], playCenter];
    return {
      x: lerp(a[0], b[0], e),
      y: lerp(a[1], b[1] + 60, e) - Math.sin(f * Math.PI) * 90,
      tuck: Math.sin(f * Math.PI),
      squash: 0,
      dir: 1,
      scale: lerp(1, 0.25, e),
      fade: clamp01((f - 0.55) / 0.45),
    };
  }
  const local = t - TL.hopStart;
  const k = Math.min(HOPS - 1, Math.floor(local / (TL.hop + TL.hopRest)));
  const within = local - k * (TL.hop + TL.hopRest);
  const [a, b] = [spots[k], spots[k + 1]];
  const dir = b[0] >= a[0] ? 1 : -1;
  if (within >= TL.hop) {
    // Landed: a small squash that springs back.
    const r = clamp01((within - TL.hop) / TL.hopRest);
    return { x: b[0], y: b[1], tuck: 0, squash: Math.sin(r * Math.PI) * 0.9, dir, scale: 1, fade: 0 };
  }
  const f = within / TL.hop;
  const e = easeInOut(f);
  return {
    x: lerp(a[0], b[0], e),
    y: lerp(a[1], b[1], e) - Math.sin(f * Math.PI) * 70,
    tuck: Math.sin(f * Math.PI),
    squash: 0,
    dir,
    scale: 1,
    fade: 0,
  };
}

/** One part of the logo: the image clipped to that part, moved and faded as a unit. */
function Piece({ name, opacity, dy = 0, scale = 1, origin = [450, 450] }) {
  if (opacity <= 0) return null;
  const [ox, oy] = origin;
  return (
    <G opacity={opacity} transform={`translate(${ox} ${oy + dy}) scale(${scale}) translate(${-ox} ${-oy})`}>
      <G clipPath={`url(#mo-${name})`}>
        <SvgImage href={LOGO_URI} x={0} y={0} width={900} height={900} preserveAspectRatio="none" />
      </G>
    </G>
  );
}

export function Intro({ onDone }) {
  const t = useTime(true);
  const fade = useRef(new Animated.Value(1)).current;
  const [wordW, setWordW] = useState(0);
  const finished = useRef(false);

  const finish = () => {
    if (finished.current) return;
    finished.current = true;
    Animated.timing(fade, { toValue: 0, duration: TL.fade, useNativeDriver: true }).start(() => onDone());
  };
  useEffect(() => {
    if (t >= DONE_AT) finish();
  }, [t >= DONE_AT]);

  // The stair rises a piece at a time from the bottom step, then the arch comes up over it.
  const built = BUILD.map((name, i) => ({ name, p: easeOut(clamp01((t - TL.build - i * TL.buildGap) / TL.buildDur)) }));
  const arch = easeOut(clamp01((t - TL.archIn) / TL.archDur));

  const fig = figureAt(t);
  const figOpacity = clamp01((t - TL.figureIn) / 200) * (1 - fig.fade);

  // Play pops when the climber lands in the doorway, with a ripple.
  const pop = clamp01((t - POP_AT + 60) / TL.pop);
  const playScale = pop <= 0 ? 0 : pop < 0.65 ? easeOut(pop / 0.65) * 1.15 : lerp(1.15, 1, (pop - 0.65) / 0.35);
  const ripple = clamp01((t - POP_AT) / 600);

  // The whole mark lifts a little as the name comes in under it.
  const rise = easeInOut(clamp01((t - WORD_AT + 200) / 600));
  const word = easeInOut(clamp01((t - WORD_AT) / TL.wordDur));
  const line = easeInOut(clamp01((t - LINE_AT) / TL.underline));
  const tagline = clamp01((t - LINE_AT) / 400);

  const size = 196;
  return (
    <Animated.View style={[StyleSheet.absoluteFill, { backgroundColor: C.bg, opacity: fade, zIndex: 10 }]}>
      <Pressable style={{ flex: 1, alignItems: 'center', justifyContent: 'center' }} onPress={finish} accessibilityLabel="تخطَّ المقدمة">
        <View style={{ alignItems: 'center', transform: [{ translateY: -26 * rise }] }}>
          <Svg width={size} height={size} viewBox="0 0 900 900" style={{ overflow: 'visible' }}>
            <Defs>
              {Object.entries(LOGO.pieces).map(([name, points]) => (
                <ClipPath key={name} id={`mo-${name}`}>
                  <Polygon points={points} />
                </ClipPath>
              ))}
            </Defs>
            {built.map(({ name, p }) => (
              <Piece key={name} name={name} opacity={p} dy={(1 - p) * 60} />
            ))}
            <Piece name="arch" opacity={arch} dy={(1 - arch) * 70} scale={lerp(0.94, 1, arch)} origin={[630, 900]} />
            {ripple > 0 && ripple < 1 && (
              <Circle
                cx={LOGO.playCenter[0]}
                cy={LOGO.playCenter[1]}
                r={lerp(60, 230, easeOut(ripple))}
                fill="none"
                stroke="#3CD6C8"
                strokeWidth={10}
                opacity={(1 - ripple) * 0.6}
              />
            )}
            <Piece name="play" opacity={clamp01(pop * 3)} scale={playScale} origin={LOGO.playCenter} />
            {figOpacity > 0 && <Figure {...fig} opacity={figOpacity} color={C.text} halo={C.bg} />}
          </Svg>

          <View style={{ height: 70, marginTop: 10, alignItems: 'center' }}>
            {/* Measured once, then revealed from the right like a pen writing Arabic. */}
            <View style={{ position: 'absolute', opacity: 0 }} onLayout={(e) => setWordW(e.nativeEvent.layout.width)}>
              <T size={46} w="800" lh={64} align="center">
                مُعيد
              </T>
            </View>
            {wordW > 0 && (
              <View style={{ width: wordW, height: 64 }}>
                <View style={{ position: 'absolute', top: 0, bottom: 0, right: 0, width: wordW * word, overflow: 'hidden' }}>
                  <View style={{ position: 'absolute', top: 0, right: 0, width: wordW }}>
                    <T size={46} w="800" lh={64} align="center">
                      مُعيد
                    </T>
                  </View>
                </View>
                <Svg width={wordW + 16} height={10} style={{ position: 'absolute', bottom: -6, left: -8 }}>
                  <Path
                    d={`M${wordW + 12} 4 Q${(wordW + 16) / 2} 9 4 5`}
                    stroke={C.accent}
                    strokeWidth={3}
                    strokeLinecap="round"
                    fill="none"
                    strokeDasharray={`${wordW + 20} ${wordW + 20}`}
                    strokeDashoffset={(wordW + 20) * (1 - line)}
                  />
                </Svg>
              </View>
            )}
          </View>
          <T size={15} color={C.text2} align="center" style={{ marginTop: 14, opacity: tagline }}>
            محاضرتك، خطوة بخطوة
          </T>
        </View>
      </Pressable>
    </Animated.View>
  );
}
