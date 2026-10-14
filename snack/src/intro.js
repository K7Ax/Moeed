// The launch: the logo's stairs rise, a little figure climbs them one step at a time,
// and at the top it becomes the play mark. Then the name is written in, right to left.
import React, { useEffect, useRef, useState } from 'react';
import { Animated, Pressable, StyleSheet, View } from 'react-native';
import Svg, { Circle, G, Line, Path, Polygon } from 'react-native-svg';
import { C, T, clamp01, easeInOut, easeOut } from './theme';
import { LOGO, logoColors } from './logo';

const TL = {
  stairIn: 100, // first step starts rising
  stairGap: 170,
  stairDur: 380,
  figureIn: 620,
  hopStart: 860,
  hop: 430,
  hopRest: 90,
  morph: 300,
  wordDur: 850,
  underline: 450,
  hold: 650,
  fade: 380,
};
const HOPS = LOGO.treads.length;
const AT_TOP = TL.hopStart + HOPS * (TL.hop + TL.hopRest);
const WORD_AT = AT_TOP + TL.morph;
const LINE_AT = WORD_AT + TL.wordDur - 150;
const DONE_AT = LINE_AT + TL.underline + TL.hold;

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

/** Where the figure's feet stand: the ground before the stairs, then the middle of each tread. */
const SPOTS = [[1, LOGO.base], ...LOGO.treads.map(([x0, x1, y]) => [(x0 + x1) / 2, y])];

/** The climber, feet at (x, y). `tuck` 0…1 bends the legs mid-hop, `squash` lands it. */
function Figure({ x, y, tuck, squash, opacity, scale, color }) {
  const h = 1 - squash * 0.12;
  const hip = [x, y - 7 * h];
  const neck = [x, y - 15.5 * h];
  const head = [x + 0.6, y - 19.4 * h];
  const legL = [lerp(x - 3, x - 1.5, tuck), lerp(y, y - 3, tuck)];
  const legR = [lerp(x + 3, x + 4, tuck), lerp(y, y - 4, tuck)];
  const armL = [lerp(x - 4, x - 4.5, tuck), lerp(y - 9 * h, y - 14 * h, tuck)];
  const armR = [lerp(x + 4, x + 5, tuck), lerp(y - 10 * h, y - 15 * h, tuck)];
  const sw = 2.3;
  return (
    <G opacity={opacity} transform={`translate(${x} ${y - 10}) scale(${scale}) translate(${-x} ${-(y - 10)})`}>
      <Line x1={neck[0]} y1={neck[1]} x2={hip[0]} y2={hip[1]} stroke={color} strokeWidth={sw} strokeLinecap="round" />
      <Line x1={hip[0]} y1={hip[1]} x2={legL[0]} y2={legL[1]} stroke={color} strokeWidth={sw} strokeLinecap="round" />
      <Line x1={hip[0]} y1={hip[1]} x2={legR[0]} y2={legR[1]} stroke={color} strokeWidth={sw} strokeLinecap="round" />
      <Line x1={x} y1={y - 13 * h} x2={armL[0]} y2={armL[1]} stroke={color} strokeWidth={sw} strokeLinecap="round" />
      <Line x1={x} y1={y - 13 * h} x2={armR[0]} y2={armR[1]} stroke={color} strokeWidth={sw} strokeLinecap="round" />
      <Circle cx={head[0]} cy={head[1]} r={3.3} fill={color} />
    </G>
  );
}

function figureAt(t) {
  if (t < TL.hopStart) return { x: SPOTS[0][0], y: SPOTS[0][1], tuck: 0, squash: 0 };
  const local = t - TL.hopStart;
  const k = Math.min(HOPS - 1, Math.floor(local / (TL.hop + TL.hopRest)));
  const within = local - k * (TL.hop + TL.hopRest);
  const [a, b] = [SPOTS[k], SPOTS[k + 1]];
  if (within >= TL.hop) {
    // Landed: a small squash that springs back.
    const r = clamp01((within - TL.hop) / TL.hopRest);
    return { x: b[0], y: b[1], tuck: 0, squash: Math.sin(r * Math.PI) * 0.9 };
  }
  const f = within / TL.hop;
  const e = easeInOut(f);
  return {
    x: lerp(a[0], b[0], e),
    y: lerp(a[1], b[1], e) - Math.sin(f * Math.PI) * 11,
    tuck: Math.sin(f * Math.PI),
    squash: 0,
  };
}

export function Intro({ onDone }) {
  const t = useTime(true);
  const fade = useRef(new Animated.Value(1)).current;
  const [wordW, setWordW] = useState(0);
  const finished = useRef(false);
  const colors = logoColors();

  const finish = () => {
    if (finished.current) return;
    finished.current = true;
    Animated.timing(fade, { toValue: 0, duration: TL.fade, useNativeDriver: true }).start(() => onDone());
  };
  useEffect(() => {
    if (t >= DONE_AT) finish();
  }, [t >= DONE_AT]);

  // Stairs: each step rises from the ground in turn.
  const steps = LOGO.treads.map(([x0, x1, y], i) => {
    const p = easeOut(clamp01((t - TL.stairIn - i * TL.stairGap) / TL.stairDur));
    return { d: `M${x0} ${LOGO.base} V${y} H${x1} V${LOGO.base} Z`, p };
  });

  const fig = figureAt(t);
  const morph = clamp01((t - AT_TOP) / TL.morph);
  const figOpacity = clamp01((t - TL.figureIn) / 200) * (1 - morph);
  const playPop = morph <= 0 ? 0 : morph < 0.7 ? easeOut(morph / 0.7) * 1.15 : lerp(1.15, 1, (morph - 0.7) / 0.3);
  const playC = [(LOGO.play[0][0] + LOGO.play[1][0] + LOGO.play[2][0]) / 3, (LOGO.play[0][1] + LOGO.play[1][1] + LOGO.play[2][1]) / 3];

  // The whole mark lifts a little as the name comes in under it.
  const rise = easeInOut(clamp01((t - WORD_AT + 200) / 600));
  const word = easeInOut(clamp01((t - WORD_AT) / TL.wordDur));
  const line = easeInOut(clamp01((t - LINE_AT) / TL.underline));
  const tagline = clamp01((t - LINE_AT) / 400);

  const size = 168;
  return (
    <Animated.View style={[StyleSheet.absoluteFill, { backgroundColor: C.bg, opacity: fade, zIndex: 10 }]}>
      <Pressable style={{ flex: 1, alignItems: 'center', justifyContent: 'center' }} onPress={finish} accessibilityLabel="تخطَّ المقدمة">
        <View style={{ alignItems: 'center', transform: [{ translateY: -26 * rise }] }}>
          <Svg width={size} height={size} viewBox="-6 -4 108 104">
            {steps.map((s, i) => (
              <Path
                key={i}
                d={s.d}
                fill={colors.stairs}
                opacity={s.p}
                transform={`translate(0 ${(1 - s.p) * 14})`}
              />
            ))}
            {playPop > 0 && (
              <G transform={`translate(${playC[0]} ${playC[1]}) scale(${playPop}) translate(${-playC[0]} ${-playC[1]})`}>
                <Polygon points={LOGO.play.map((p) => p.join(',')).join(' ')} fill={colors.play} />
              </G>
            )}
            {figOpacity > 0 && <Figure {...fig} opacity={figOpacity} scale={1 - morph * 0.6} color={C.accent} />}
          </Svg>

          <View style={{ height: 70, marginTop: 6, alignItems: 'center' }}>
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
