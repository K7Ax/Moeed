// «الدرج»: the logo is the map. The course is the stair in the mark, each unit a tread, the exam the
// doorway with play in it; the little climber from the intro stands where you are. In the player
// that same climber is the tutor: it stands on the slide holding the pen, and the explanation is a
// short stair of its own that it climbs a step at a time.
import React, { useEffect, useRef, useState } from 'react';
import { Animated, Easing, Pressable, ScrollView, View } from 'react-native';
import Svg, { Circle, Defs, G, Image as SvgImage, Line, LinearGradient, Path, Rect, Stop } from 'react-native-svg';
import { S, T, isDark, ltr } from '../theme';
import { BACK, FORWARD, Icon } from '../controls';
import { useSize } from '../ui';
import { LOGO, LOGO_URI, LogoMark } from '../logo';
import { usePlayer } from '../player';
import { reviewItems, sinePage } from '../data';
import { Appear, FONTS, Glossed, InkSlide, Tutor, ar } from './engine';
import { LECTURES } from './mock';

const pal = () =>
  isDark()
    ? {
        bg: '#0B1D2E',
        surface: '#11283D',
        text: '#E7F0F1',
        text2: '#93A9B4',
        text3: '#5F7886',
        line: 'rgba(231,240,241,0.12)',
        teal: '#2CC6B6',
        mint: '#7AF5D0',
        coral: '#FF7A5C',
        figure: '#E7F0F1',
      }
    : {
        bg: '#F5F3EC',
        surface: '#FFFFFF',
        text: '#13232F',
        text2: '#566672',
        text3: '#93A0A8',
        line: 'rgba(19,35,47,0.12)',
        teal: '#0E9C93',
        mint: '#5FE3BC',
        coral: '#E4573D',
        figure: '#13232F',
      };

// The pen on the slide: teal and deep blue by turns, coral for the question.
const inkFor = (i) => (sinePage.steps[i].ask ? '#D9482E' : i % 2 ? '#1D4F86' : '#0B8078');
const kufi = FONTS.kufi;

/** The climber, standing, feet at the bottom middle of a w×h box. */
function Climber({ w = 26, color, halo, wave }) {
  const h = w * 1.7;
  const k = w / 12;
  const x = w / 2;
  const y = h - 2;
  const limbs = [
    [[x, y - 15 * k], [x, y - 7 * k]],
    [[x, y - 7 * k], [x - 2.6 * k, y]],
    [[x, y - 7 * k], [x + 2.6 * k, y]],
    [[x, y - 13 * k], [x - 4 * k, y - (wave ? 17 : 9) * k]],
    [[x, y - 13 * k], [x + 4 * k, y - 9 * k]],
  ];
  const pass = (stroke, sw, r) => (
    <G>
      {limbs.map(([a, b], n) => (
        <Line key={n} x1={a[0]} y1={a[1]} x2={b[0]} y2={b[1]} stroke={stroke} strokeWidth={sw} strokeLinecap="round" />
      ))}
      <Circle cx={x + 0.3 * k} cy={y - 18.6 * k} r={r} fill={stroke} />
    </G>
  );
  return (
    <Svg width={w} height={h}>
      {halo && pass(halo, 2.1 * k + 3, 3.2 * k + 1.5)}
      {pass(color, 2.1 * k, 3.2 * k)}
    </Svg>
  );
}

/** Moves to a new spot with a hop: up over an arc and down, with the feet as the anchor. */
function useHop(x, y, duration = 420) {
  const ax = useRef(new Animated.Value(x)).current;
  const ay = useRef(new Animated.Value(y)).current;
  const arc = useRef(new Animated.Value(0)).current;
  const first = useRef(true);
  useEffect(() => {
    if (first.current) {
      first.current = false;
      return;
    }
    arc.setValue(0);
    Animated.parallel([
      Animated.timing(ax, { toValue: x, duration, easing: Easing.inOut(Easing.quad), useNativeDriver: false }),
      Animated.timing(ay, { toValue: y, duration, easing: Easing.inOut(Easing.quad), useNativeDriver: false }),
      Animated.timing(arc, { toValue: 1, duration, useNativeDriver: false }),
    ]).start();
  }, [x, y]);
  const lift = arc.interpolate({ inputRange: [0, 0.5, 1], outputRange: [0, -28, 0] });
  return { left: ax, top: Animated.add(ay, lift) };
}

// MARK: Player

/** The explanation as a winding stair: one tread per step, the question a wider landing, the doorway at the top. */
function StepStair({ c, p, width, height }) {
  const n = p.n;
  const top = 96;
  const bottom = 36;
  const rise = (height - top - bottom) / (n - 1);
  const treads = Array.from({ length: n }, (_, k) => {
    const cx = width / 2 + width * 0.24 * Math.sin(k * 0.9 + 0.9);
    const w = p.page.steps[k].ask ? 84 : 58;
    return { cx, y: height - bottom - k * rise, w };
  });
  const fig = treads[p.i];
  const pos = useHop(fig.cx - 13, fig.y - 44);
  let d = '';
  treads.forEach((t, k) => (d += `${k ? 'L' : 'M'}${t.cx.toFixed(1)} ${t.y.toFixed(1)}`));
  return (
    <View style={{ width, height, direction: 'ltr' }}>
      <Svg width={width} height={height}>
        <Defs>
          <LinearGradient id="stairTread" x1="0" y1="0" x2="1" y2="0">
            <Stop offset="0" stopColor={c.teal} />
            <Stop offset="1" stopColor={c.mint} />
          </LinearGradient>
        </Defs>
        <Path d={d} stroke={c.line} strokeWidth={1.5} strokeDasharray="2 5" fill="none" />
        {treads.map((t, k) => {
          const done = k <= p.i;
          const ask = !!p.page.steps[k].ask;
          return (
            <G key={k} onPress={() => p.go(k)}>
              <Rect x={t.cx - t.w / 2} y={t.y} width={t.w} height={9} rx={3} fill={done ? 'url(#stairTread)' : 'none'} stroke={done ? 'none' : c.text3} strokeWidth={1.2} />
              <Rect x={t.cx - t.w / 2 + 3} y={t.y + 9} width={t.w - 6} height={7} rx={2} fill={done ? c.teal : 'none'} opacity={done ? 0.35 : 0} />
              {ask && <Circle cx={t.cx + t.w / 2 + 9} cy={t.y + 4} r={4} fill={c.coral} />}
            </G>
          );
        })}
      </Svg>
      {treads.map((t, k) => (
        <T key={k} size={11} w={k === p.i ? '700' : '400'} color={k === p.i ? c.teal : c.text3} align="center" style={{ position: 'absolute', left: t.cx - 20, width: 40, top: t.y + 17 }}>
          {ar(k + 1)}
        </T>
      ))}
      <View style={{ position: 'absolute', top: 8, left: width / 2 - 34, alignItems: 'center', opacity: p.isLast ? 1 : 0.45 }}>
        <LogoMark size={68} />
      </View>
      <Animated.View pointerEvents="none" style={{ position: 'absolute', left: pos.left, top: pos.top }}>
        <Climber w={26} color={c.figure} wave={p.isLast} />
      </Animated.View>
    </View>
  );
}

function AskTreads({ c, p, wide }) {
  const a = p.step.ask;
  return (
    <View>
      <Glossed text={a.question} size={wide ? 23 : 20} w="700" color={c.text} term={c.coral} font={kufi} lh={wide ? 38 : 32} />
      <T size={14} color={c.text3} style={{ marginTop: 2 }}>
        {p.isAnswered ? ' ' : 'اختر الدرجة اللي تتوقعها قبل ما أكمل'}
      </T>
      <View style={{ marginTop: 14 }}>
        {a.options.map((o, k) => {
          const right = o.id === a.answerID;
          const chosen = o.id === p.picked;
          const tone = p.isAnswered ? (right ? 'right' : chosen ? 'wrong' : 'dim') : 'idle';
          return (
            <Pressable
              key={o.id}
              onPress={() => p.pick(o.id)}
              disabled={p.isAnswered}
              style={{
                width: 170,
                height: 46,
                marginBottom: 8,
                marginRight: (a.options.length - 1 - k) * 34,
                borderRadius: 8,
                borderWidth: 1.5,
                borderBottomWidth: 6,
                borderColor: tone === 'right' ? c.teal : tone === 'wrong' ? c.coral : c.line,
                backgroundColor: tone === 'right' ? c.teal : c.surface,
                alignItems: 'center',
                justifyContent: 'center',
                opacity: tone === 'dim' ? 0.5 : 1,
              }}
            >
              <S size={17} w="700" color={tone === 'right' ? '#FFFFFF' : tone === 'wrong' ? c.coral : c.text} align="center">
                {ltr(o.label)}
              </S>
            </Pressable>
          );
        })}
      </View>
      {p.isAnswered && (
        <Appear style={{ marginTop: 6 }}>
          <Glossed text={(p.pickedRight ? 'صح! ' : 'مو هذي. ') + a.why} size={wide ? 17 : 16} color={c.text} term={c.teal} lh={wide ? 30 : 27} />
        </Appear>
      )}
    </View>
  );
}

function Words({ c, p, wide }) {
  return (
    <View style={{ flexDirection: 'row' }}>
      <View style={{ width: 3, borderRadius: 2, backgroundColor: inkFor(p.i), marginLeft: 14, opacity: p.revealed ? 1 : 0.3 }} />
      <View style={{ flex: 1 }}>
        {p.step.caption.map((ph, k) => (
          <Appear key={p.playKey + '-' + k} on={k < p.revealed}>
            <Glossed text={ph} size={wide ? 22 : 18} w={k === p.revealed - 1 ? '600' : '400'} color={k === p.revealed - 1 ? c.text : c.text2} term={c.teal} font={kufi} lh={wide ? 38 : 31} />
          </Appear>
        ))}
      </View>
    </View>
  );
}

function ClimbButton({ c, p }) {
  const locked = p.step.ask && !p.isAnswered;
  return (
    <View style={{ flexDirection: 'row', alignItems: 'center' }}>
      <Pressable onPress={p.next} disabled={locked || p.isLast} style={{ opacity: locked || p.isLast ? 0.4 : 1 }}>
        <Svg width={180} height={50}>
          <Defs>
            <LinearGradient id="climbBtn" x1="1" y1="0" x2="0" y2="0">
              <Stop offset="0" stopColor={c.teal} />
              <Stop offset="1" stopColor={c.mint} />
            </LinearGradient>
          </Defs>
          {/* A pill with one stepped corner: the button is a tread. */}
          <Path d="M25 0 H180 V36 H166 V50 H25 A25 25 0 0 1 25 0 Z" fill="url(#climbBtn)" />
        </Svg>
        <View style={{ position: 'absolute', left: 0, right: 14, top: 0, height: 50, flexDirection: 'row', alignItems: 'center', justifyContent: 'center' }}>
          <T size={15} w="800" color="#06302E">
            {p.isLast ? 'وصلت الباب' : 'الدرجة التالية'}
          </T>
          <Icon name={FORWARD} size={16} color="#06302E" style={{ marginHorizontal: 6 }} />
        </View>
      </Pressable>
      <Pressable onPress={p.replay} hitSlop={8} style={{ marginHorizontal: 16 }}>
        <Icon name="rotate-ccw" size={19} color={c.text2} />
      </Pressable>
      <Pressable onPress={p.previous} disabled={p.isFirst} hitSlop={8} style={{ opacity: p.isFirst ? 0.3 : 1 }}>
        <Icon name="corner-left-down" size={19} color={c.text2} />
      </Pressable>
      <Pressable onPress={p.toggleAuto} hitSlop={8} style={{ marginHorizontal: 16 }}>
        <T size={13} w="700" color={p.auto ? c.teal : c.text3}>
          {p.auto ? 'تلقائي ●' : 'تلقائي'}
        </T>
      </Pressable>
    </View>
  );
}

function Player({ wide, onBack }) {
  const c = pal();
  const p = usePlayer(sinePage);
  const [area, onArea] = useSize();
  const [col, onCol] = useSize();
  const slide = (sw) => (
    <View style={{ alignSelf: 'center', borderRadius: 14, overflow: 'hidden', borderWidth: 1, borderColor: c.line }}>
      <InkSlide
        p={p}
        width={sw}
        inkFor={inkFor}
        onJump={p.go}
        overlay={({ t, tip }) => (p.step.marks[0] && p.step.marks[0].t === 'spot' ? null : <Tutor tip={tip} t={t} color="#13232F" pen={inkFor(p.i)} />)}
      />
    </View>
  );
  const words = p.step.ask ? <AskTreads key={p.playKey} c={c} p={p} wide={wide} /> : <Words c={c} p={p} wide={wide} />;
  const head = (
    <View style={{ height: 56, flexDirection: 'row', alignItems: 'center', paddingHorizontal: 20 }}>
      <Pressable onPress={onBack} hitSlop={8} style={{ flexDirection: 'row', alignItems: 'center' }}>
        <Icon name={BACK} size={17} color={c.text2} />
        <T size={14} color={c.text2} style={{ marginHorizontal: 4 }}>
          الدرج
        </T>
      </Pressable>
      <View style={{ flex: 1 }} />
      <T size={14} w="700" color={c.text}>
        {`الدرجة ${ar(p.i + 1)}`}
      </T>
      <T size={14} color={c.text3}>{` من ${ar(p.n)}`}</T>
    </View>
  );
  if (!wide) {
    return (
      <View style={{ flex: 1, backgroundColor: c.bg }}>
        {head}
        <ScrollView contentContainerStyle={{ padding: 16, paddingBottom: 24 }}>
          <View onLayout={onArea}>{area && slide(area.w)}</View>
          {/* On a phone the stair lies down: a row of treads under the slide. */}
          <View style={{ flexDirection: 'row', justifyContent: 'center', alignItems: 'flex-end', marginTop: 14, height: 30 }}>
            {p.page.steps.map((s, k) => (
              <Pressable key={k} onPress={() => p.go(k)} style={{ width: s.ask ? 40 : 28, height: 6 + k * 2.6, marginHorizontal: 2, borderTopLeftRadius: 3, borderTopRightRadius: 3, backgroundColor: k <= p.i ? (k === p.i ? c.teal : c.mint) : c.line }} />
            ))}
          </View>
          <View style={{ marginTop: 18 }}>{words}</View>
        </ScrollView>
        <View style={{ paddingHorizontal: 16, paddingVertical: 10, borderTopWidth: 1, borderTopColor: c.line }}>
          <ClimbButton c={c} p={p} />
        </View>
      </View>
    );
  }
  return (
    <View style={{ flex: 1, backgroundColor: c.bg }}>
      {head}
      <View style={{ flex: 1, flexDirection: 'row' }}>
        <View style={{ width: 200 }} onLayout={onCol}>
          {col && <StepStair c={c} p={p} width={200} height={col.h - 10} />}
        </View>
        <View style={{ flex: 1, paddingHorizontal: 28, paddingBottom: 18 }} onLayout={onArea}>
          {area && (
            <View style={{ flex: 1 }}>
              {slide(Math.min(area.w - 56, (area.h - 240) * (4 / 3)))}
              <View style={{ flex: 1, marginTop: 18, maxWidth: 720 }}>{words}</View>
              <ClimbButton c={c} p={p} />
            </View>
          )}
        </View>
      </View>
    </View>
  );
}

// MARK: Home, the logo as the map

// Units of the course on the mark's treads, bottom to top; the exam is the doorway.
const FLOORS = LECTURES.slice(0, 5).map((l, k) => ({ ...l, spot: LOGO.spots[k] }));

function MarkMap({ c, size, onOpen }) {
  const s = size / LOGO.box;
  const current = FLOORS.findIndex((f) => f.current);
  return (
    <View style={{ width: size, height: size, direction: 'ltr' }}>
      <Svg width={size} height={size} viewBox="0 0 900 900">
        <SvgImage href={LOGO_URI} x={0} y={0} width={900} height={900} preserveAspectRatio="none" opacity={isDark() ? 0.95 : 1} />
        {/* The path climbed so far, as a dotted line over the treads. */}
        <Path
          d={FLOORS.slice(0, current + 1)
            .map((f, k) => `${k ? 'L' : 'M'}${f.spot[0]} ${f.spot[1] - 16}`)
            .join(' ')}
          stroke="#FFFFFF"
          strokeWidth={7}
          strokeDasharray="2 16"
          strokeLinecap="round"
          fill="none"
        />
        {FLOORS.map((f, k) => {
          const done = f.done >= 1;
          const here = k === current;
          return (
            <G key={f.n} onPress={here ? onOpen : undefined}>
              <Circle cx={f.spot[0]} cy={f.spot[1] - 16} r={here ? 30 : 24} fill={done || here ? '#FFFFFF' : 'rgba(255,255,255,0.35)'} stroke={here ? c.coral : '#0E5E63'} strokeWidth={here ? 7 : 4} />
            </G>
          );
        })}
        <Circle cx={LOGO.playCenter[0]} cy={LOGO.playCenter[1]} r={150} fill="none" stroke="#FFFFFF" strokeWidth={5} strokeDasharray="4 14" opacity={0.8} />
      </Svg>
      {FLOORS.map((f, k) => (
        <T key={f.n} size={Math.max(11, 34 * s)} w="800" color={k === current ? c.coral : '#0E4F54'} align="center" style={{ position: 'absolute', left: f.spot[0] * s - 20, width: 40, top: (f.spot[1] - 16) * s - Math.max(11, 34 * s) * 0.75 }}>
          {ar(f.n)}
        </T>
      ))}
      <View style={{ position: 'absolute', left: FLOORS[current].spot[0] * s + 18 * s, top: (FLOORS[current].spot[1] - 46) * s - 52 }}>
        <Climber w={30} color={c.figure} halo={c.bg} wave />
      </View>
    </View>
  );
}

function Home({ wide, onOpen }) {
  const c = pal();
  const cur = LECTURES.find((l) => l.current);
  const mapSize = 300;
  const [mapArea, onMapArea] = useSize();
  const legend = (
    <View>
      {FLOORS.map((f) => (
        <Pressable key={f.n} onPress={f.current ? onOpen : undefined} style={{ flexDirection: 'row', alignItems: 'center', paddingVertical: 9 }}>
          <View style={{ width: 30, height: 30, borderRadius: 15, borderWidth: 2, borderColor: f.current ? c.coral : c.teal, backgroundColor: f.done >= 1 ? c.teal : 'transparent', alignItems: 'center', justifyContent: 'center' }}>
            <T size={13} w="800" color={f.done >= 1 ? '#FFFFFF' : f.current ? c.coral : c.teal} align="center">
              {ar(f.n)}
            </T>
          </View>
          <View style={{ flex: 1, marginHorizontal: 12 }}>
            <T size={16} w={f.current ? '800' : '500'} color={c.text} style={{ fontFamily: kufi }}>
              {f.ar}
            </T>
            <T size={12} color={c.text3}>
              {f.done >= 1 ? 'صعدتها' : f.current ? `أنت هنا · ص ${ar(f.page)} من ${ar(f.pages)}` : ''}
            </T>
          </View>
        </Pressable>
      ))}
      <View style={{ flexDirection: 'row', alignItems: 'center', paddingVertical: 9, opacity: 0.8 }}>
        <View style={{ width: 30, height: 30, borderRadius: 15, borderWidth: 2, borderStyle: 'dashed', borderColor: c.text3, alignItems: 'center', justifyContent: 'center' }}>
          <Icon name="play" size={12} color={c.text3} />
        </View>
        <T size={16} color={c.text2} style={{ marginHorizontal: 12, fontFamily: kufi }}>
          الباب: الاختبار النهائي
        </T>
      </View>
    </View>
  );
  const resumeCard = (
    <Pressable onPress={onOpen} style={{ borderRadius: 20, backgroundColor: c.surface, borderWidth: 1, borderColor: c.line, padding: 20 }}>
      <T size={13} w="700" color={c.teal}>
        الدرجة اللي وقفت عليها
      </T>
      <T size={wide ? 28 : 24} w="800" color={c.text} lh={wide ? 42 : 36} style={{ fontFamily: kufi, marginTop: 4 }}>
        {cur.ar}
      </T>
      <T size={14} color={c.text2}>{`ص ${ar(16)} · قراءة القيمة اللحظية من الرسم`}</T>
      <View style={{ flexDirection: 'row', alignItems: 'flex-end', marginTop: 14 }}>
        {Array.from({ length: 9 }, (_, k) => (
          <View key={k} style={{ width: 16, height: 6 + k * 3, marginLeft: 3, borderTopLeftRadius: 2, borderTopRightRadius: 2, backgroundColor: k < 4 ? c.teal : k === 4 ? c.coral : c.line }} />
        ))}
        <T size={12} color={c.text3} style={{ marginHorizontal: 10 }}>
          {`الخطوة ${ar(5)} من ${ar(9)}`}
        </T>
      </View>
      <View style={{ marginTop: 16, height: 46, borderRadius: 23, backgroundColor: c.teal, flexDirection: 'row', alignItems: 'center', justifyContent: 'center' }}>
        <T size={15} w="800" color="#FFFFFF">
          اصعد
        </T>
        <Icon name="arrow-up-left" size={17} color="#FFFFFF" style={{ marginHorizontal: 6 }} />
      </View>
    </Pressable>
  );
  const review = (
    <View style={{ marginTop: 16, borderRadius: 20, borderWidth: 1, borderColor: c.line, padding: 18, flexDirection: 'row', alignItems: 'center' }}>
      <View style={{ width: 44, height: 44, borderRadius: 12, backgroundColor: c.coral, alignItems: 'center', justifyContent: 'center' }}>
        <T size={20} w="800" color="#FFFFFF" align="center">
          {ar(reviewItems.length + 2)}
        </T>
      </View>
      <View style={{ flex: 1, marginHorizontal: 14 }}>
        <T size={15} w="700" color={c.text}>
          درجات تحتاج ترجع لها
        </T>
        <T size={13} color={c.text2}>
          أسئلة غلطت فيها، كل وحدة ترجعك لمكانها في السلايد
        </T>
      </View>
      <Icon name={FORWARD} size={18} color={c.text3} />
    </View>
  );
  return (
    <View style={{ flex: 1, backgroundColor: c.bg }}>
      <View style={{ height: 60, flexDirection: 'row', alignItems: 'center', paddingHorizontal: wide ? 40 : 18 }}>
        <T size={20} w="800" color={c.text} style={{ fontFamily: kufi }}>
          مُعيد
        </T>
        <T size={13} color={c.text3} style={{ marginHorizontal: 10 }}>
          EE207 · الدوائر الكهربائية
        </T>
        <View style={{ flex: 1 }} />
        <Icon name="plus" size={20} color={c.text2} />
      </View>
      <ScrollView contentContainerStyle={{ paddingHorizontal: wide ? 40 : 18, paddingBottom: 40 }}>
        {wide ? (
          <View style={{ flexDirection: 'row', alignItems: 'flex-start', marginTop: 10 }}>
            <View style={{ width: 340 }}>
              {resumeCard}
              {review}
            </View>
            <View style={{ flex: 1, marginRight: 28 }} onLayout={onMapArea}>
              {mapArea &&
                (mapArea.w >= 600 ? (
                  <View style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'center' }}>
                    <View style={{ width: 220, marginLeft: 12 }}>{legend}</View>
                    <MarkMap c={c} size={Math.min(460, mapArea.w - 240)} onOpen={onOpen} />
                  </View>
                ) : (
                  <View style={{ alignItems: 'center' }}>
                    <MarkMap c={c} size={Math.min(400, mapArea.w)} onOpen={onOpen} />
                    <View style={{ alignSelf: 'stretch', marginTop: 8 }}>{legend}</View>
                  </View>
                ))}
            </View>
          </View>
        ) : (
          <View>
            <View style={{ alignItems: 'center', marginTop: 4 }}>
              <MarkMap c={c} size={mapSize} onOpen={onOpen} />
            </View>
            <View style={{ marginTop: 10 }}>{resumeCard}</View>
            <View style={{ marginTop: 10 }}>{legend}</View>
            {review}
          </View>
        )}
      </ScrollView>
    </View>
  );
}

export function StairsApp({ wide }) {
  const [route, setRoute] = useState('home');
  return route === 'player' ? <Player wide={wide} onBack={() => setRoute('home')} /> : <Home wide={wide} onOpen={() => setRoute('player')} />;
}

export const stairs = {
  key: 'stairs',
  name: 'الدرج',
  line: 'شعارك هو الخريطة: المقرر درجه والاختبار بابه. والرجل الصغير اللي يصعد بالمقدمة هو نفسه المعلّم اللي يمسك القلم على السلايد.',
  refs: 'شعار مُعيد · Brilliant (Koji) · Duolingo path بدون إجبار',
  swatches: ['#F5F3EC', '#0E9C93', '#5FE3BC', '#13232F', '#E4573D'],
  App: StairsApp,
};
