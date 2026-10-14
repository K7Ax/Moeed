// «الجهاز»: a bench instrument for one lecture, in the manner of Teenage Engineering. The slide is
// its screen; the tutor's words come up on a small dark readout; a scope trace under the screen
// is the timeline, one coloured stretch per step; and nine keys, one per step, light up in the
// colour of the pen that step uses. Few controls, all visible, nothing nested.
// Lectures are cartridges you slot in.
import React, { useEffect, useRef, useState } from 'react';
import { Animated, Pressable, ScrollView, View } from 'react-native';
import Svg, { Circle, Line, Path, Rect } from 'react-native-svg';
import { S, T, isDark, ltr, readingMs } from '../theme';
import { Icon } from '../controls';
import { useSize } from '../ui';
import { LogoMark } from '../logo';
import { usePlayer } from '../player';
import { reviewItems, sinePage } from '../data';
import { Appear, FONTS, Glossed, InkSlide, ar, useHold } from './engine';
import { LECTURES } from './mock';

const pal = () =>
  isDark()
    ? {
        panel: '#1B1C1E',
        panel2: '#141517',
        key: '#2B2C30',
        keyEdge: '#0C0D0E',
        ink: '#ECEAE4',
        ink2: '#A3A19A',
        ink3: '#66655F',
        groove: 'rgba(255,255,255,0.07)',
      }
    : {
        panel: '#E6E3DB',
        panel2: '#D9D5CB',
        key: '#F7F5F0',
        keyEdge: '#BDB8AC',
        ink: '#1C1D1F',
        ink2: '#5F5E58',
        ink3: '#9A988F',
        groove: 'rgba(0,0,0,0.08)',
      };
const LCD = { bg: '#0F1110', text: '#A6F5DD', dim: 'rgba(166,245,221,0.38)', grid: 'rgba(166,245,221,0.09)' };
const ORANGE = '#FF5A1F';
const GREEN = '#16B46C';

// The four encoder colours. Graphite reads as near-white on the readout.
const CHANNELS = [
  { pen: '#2F6BFF', led: '#5C8BFF' },
  { pen: '#14A863', led: '#33D98A' },
  { pen: '#FF5A1F', led: '#FF7A47' },
  { pen: '#26282C', led: '#E9E6DE' },
];
const pen = (i) => CHANNELS[i % 4].pen;
const led = (i) => CHANNELS[i % 4].led;
const mono = FONTS.mono;
const pad2 = (n) => String(n).padStart(2, '0');

function Mono({ size = 12, color, children, style, align }) {
  return (
    <S size={size} color={color} align={align} style={[{ fontFamily: mono, letterSpacing: 1 }, style]}>
      {children}
    </S>
  );
}

function usePulse(on) {
  const v = useRef(new Animated.Value(1)).current;
  useEffect(() => {
    if (!on) {
      v.setValue(1);
      return undefined;
    }
    const loop = Animated.loop(
      Animated.sequence([
        Animated.timing(v, { toValue: 0.25, duration: 420, useNativeDriver: false }),
        Animated.timing(v, { toValue: 1, duration: 420, useNativeDriver: false }),
      ])
    );
    loop.start();
    return () => loop.stop();
  }, [on]);
  return v;
}

function Led({ color, on, pulse, size = 8 }) {
  const v = usePulse(pulse);
  return <Animated.View style={{ width: size, height: size, borderRadius: size / 2, backgroundColor: on ? color : 'rgba(127,127,127,0.25)', opacity: pulse ? v : 1 }} />;
}

/** A physical key: a pale cap on a darker skirt, pressed down when pressed. */
function Key({ c, w = 60, h = 60, onPress, onPressIn, onPressOut, disabled, face, children, style }) {
  return (
    <Pressable onPress={onPress} onPressIn={onPressIn} onPressOut={onPressOut} disabled={disabled} style={[{ opacity: disabled ? 0.45 : 1 }, style]}>
      {({ pressed }) => (
        <View style={{ width: w, height: h, borderRadius: 10, backgroundColor: c.keyEdge, paddingBottom: pressed ? 1 : 4, paddingTop: pressed ? 3 : 0 }}>
          <View style={{ flex: 1, borderRadius: 9, backgroundColor: face || c.key, padding: 7 }}>{children}</View>
        </View>
      )}
    </Pressable>
  );
}

/** A rotary knob; tapping it turns it to the next detent. */
function Knob({ c, value, values, label, color = ORANGE, onPress, size = 54 }) {
  const a = -135 + (270 * values.indexOf(value)) / (values.length - 1);
  const r = size / 2;
  const rad = ((a - 90) * Math.PI) / 180;
  return (
    <Pressable onPress={onPress} style={{ alignItems: 'center' }}>
      <Svg width={size + 12} height={size + 12}>
        {values.map((v, k) => {
          const t = ((-135 + (270 * k) / (values.length - 1) - 90) * Math.PI) / 180;
          return <Line key={k} x1={r + 6 + Math.cos(t) * (r + 2)} y1={r + 6 + Math.sin(t) * (r + 2)} x2={r + 6 + Math.cos(t) * (r + 5)} y2={r + 6 + Math.sin(t) * (r + 5)} stroke={c.ink3} strokeWidth={1.5} />;
        })}
        <Circle cx={r + 6} cy={r + 6} r={r - 3} fill={color} />
        <Circle cx={r + 6} cy={r + 6} r={r - 11} fill="rgba(255,255,255,0.14)" />
        <Line x1={r + 6} y1={r + 6} x2={r + 6 + Math.cos(rad) * (r - 7)} y2={r + 6 + Math.sin(rad) * (r - 7)} stroke="#FFFFFF" strokeWidth={3} strokeLinecap="round" />
      </Svg>
      <Mono size={10} color={c.ink2} align="center">
        {label}
      </Mono>
    </Pressable>
  );
}

// MARK: Readout and trace

function Readout({ p, compact }) {
  const size = compact ? 17 : 19;
  return (
    <View style={{ backgroundColor: LCD.bg, borderRadius: 10, padding: 14, minHeight: compact ? 150 : 200 }}>
      <View style={{ flexDirection: 'row', justifyContent: 'space-between', direction: 'ltr' }}>
        <Mono size={11} color={LCD.dim}>{`STEP ${pad2(p.i + 1)}/${pad2(p.n)}`}</Mono>
        <Mono size={11} color={LCD.dim}>{`×${p.speed.toFixed(2)}  ${p.auto ? 'AUTO' : 'MAN'}`}</Mono>
      </View>
      <View style={{ height: 1, backgroundColor: LCD.grid, marginVertical: 10 }} />
      {p.step.ask ? (
        <View>
          <Glossed text={p.step.ask.question} size={size} w="700" color={LCD.text} term={led(p.i)} lh={Math.round(size * 1.6)} />
          <Mono size={11} color={LCD.dim} style={{ marginTop: 8 }}>
            {p.isAnswered ? (p.pickedRight ? 'OK ✓' : 'ERR → REVIEW') : 'HOLD A KEY TO ANSWER'}
          </Mono>
          {p.isAnswered && (
            <Appear style={{ marginTop: 6 }}>
              <Glossed text={p.step.ask.why} size={size - 3} color={LCD.text} term={led(p.i)} lh={Math.round(size * 1.5)} />
            </Appear>
          )}
        </View>
      ) : (
        p.step.caption.map((ph, k) => (
          <Appear key={p.playKey + '-' + k} on={k < p.revealed}>
            <Glossed text={ph} size={size} w={k === p.revealed - 1 ? '600' : '400'} color={k === p.revealed - 1 ? LCD.text : LCD.dim} term={led(p.i)} lh={Math.round(size * 1.65)} />
          </Appear>
        ))
      )}
    </View>
  );
}

/** The timeline as a scope trace: one stretch per step, as long as the step takes to say. */
function Trace({ p, width, height = 62 }) {
  const lens = p.page.steps.map((s) => (s.ask ? 2600 : s.caption.reduce((a, ph) => a + readingMs(ph), 0) + 600));
  const total = lens.reduce((a, b) => a + b, 0);
  let x = 0;
  const segs = lens.map((l, k) => {
    const w = (l / total) * (width - 16);
    const seg = { x0: 8 + x, w, k };
    x += w;
    return seg;
  });
  const mid = height / 2;
  const wave = (s) => {
    const cycles = Math.max(2, Math.round(s.w / 22));
    const amp = s.k === p.i ? height * 0.34 : height * 0.2;
    let d = `M${s.x0} ${mid}`;
    for (let j = 1; j <= cycles * 8; j++) {
      const f = j / (cycles * 8);
      // A wobbly signal: the step's own shape, so each stretch looks different.
      const y = mid - Math.sin(f * cycles * Math.PI * 2) * amp * (0.55 + 0.45 * Math.sin(f * 3 + s.k));
      d += ` L${(s.x0 + f * s.w).toFixed(1)} ${y.toFixed(1)}`;
    }
    return d;
  };
  const cur = segs[p.i];
  const prog = p.step.ask ? (p.isAnswered ? 1 : 0.5) : p.step.caption.length ? p.revealed / p.step.caption.length : 1;
  const head = cur.x0 + cur.w * prog;
  // Left to right like a scope, but the steps run right to left with the reading.
  return (
    <View style={{ width, height, backgroundColor: LCD.bg, borderRadius: 8, overflow: 'hidden', direction: 'ltr', transform: [{ scaleX: -1 }] }}>
      <Svg width={width} height={height}>
        {Array.from({ length: Math.floor(width / 24) }, (_, k) => (
          <Line key={'g' + k} x1={k * 24} y1={0} x2={k * 24} y2={height} stroke={LCD.grid} strokeWidth={1} />
        ))}
        <Line x1={0} y1={mid} x2={width} y2={mid} stroke={LCD.grid} strokeWidth={1} />
        {segs.map((s) => (
          <Path key={s.k} d={wave(s)} stroke={led(s.k)} strokeOpacity={s.k <= p.i ? 1 : 0.28} strokeWidth={s.k === p.i ? 2.2 : 1.5} fill="none" />
        ))}
        <Line x1={head} y1={4} x2={head} y2={height - 4} stroke="#FFFFFF" strokeWidth={1.5} />
        {segs.map((s) => (
          <Rect key={'hit' + s.k} x={s.x0} y={0} width={s.w} height={height} fill="#000" fillOpacity={0.001} onPress={() => p.go(s.k)} />
        ))}
      </Svg>
    </View>
  );
}

// MARK: Keys

function StepKeys({ c, p, size = 62, columns = 3 }) {
  const rows = [];
  for (let r = 0; r < Math.ceil(p.n / columns); r++) rows.push(p.page.steps.slice(r * columns, r * columns + columns).map((s, j) => r * columns + j));
  return (
    <View>
      {rows.map((row, r) => (
        <View key={r} style={{ flexDirection: 'row', marginBottom: 8 }}>
          {row.map((k) => (
            <Key key={k} c={c} w={size} h={size} onPress={() => p.go(k)} style={{ marginLeft: 8 }}>
              <View style={{ flexDirection: 'row', justifyContent: 'space-between', direction: 'ltr' }}>
                <Mono size={11} color={c.ink2}>
                  {pad2(k + 1)}
                </Mono>
                <Led color={led(k)} on={k <= p.i} pulse={k === p.i} />
              </View>
              <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center' }}>
                {p.page.steps[k].ask ? (
                  <Mono size={size * 0.3} color={ORANGE}>
                    ?
                  </Mono>
                ) : (
                  <View style={{ width: size * 0.32, height: 3, borderRadius: 2, backgroundColor: pen(k), opacity: k <= p.i ? 1 : 0.35 }} />
                )}
              </View>
            </Key>
          ))}
        </View>
      ))}
    </View>
  );
}

function AnswerKey({ c, label, state, onCommit, w }) {
  const h = useHold(onCommit, 600);
  const color = state === 'right' ? GREEN : state === 'wrong' ? ORANGE : '#FFFFFF';
  return (
    <Key c={c} w={w} h={64} onPressIn={h.start} onPressOut={h.cancel} disabled={state === 'dim'} style={{ marginLeft: 8 }}>
      <View style={{ flexDirection: 'row', justifyContent: 'flex-end', direction: 'ltr' }}>
        {state === 'idle' ? (
          <Animated.View style={{ width: 8, height: 8, borderRadius: 4, backgroundColor: ORANGE, opacity: h.v }} />
        ) : (
          <Led color={color} on={state !== 'dim'} />
        )}
      </View>
      <S size={17} w="700" color={c.ink} align="center" style={{ fontFamily: mono }}>
        {ltr(label)}
      </S>
    </Key>
  );
}

function Transport({ c, p, compact }) {
  const locked = p.step.ask && !p.isAnswered;
  const w = compact ? 54 : 60;
  if (p.step.ask && !p.isAnswered) {
    const a = p.step.ask;
    return (
      <View>
        <Mono size={10} color={c.ink2} style={{ marginBottom: 6, marginRight: 8 }}>
          HOLD ▸ ANSWER
        </Mono>
        <View style={{ flexDirection: 'row' }}>
          {a.options.map((o) => (
            <AnswerKey key={o.id} c={c} label={o.label} state="idle" w={compact ? 86 : 90} onCommit={() => p.pick(o.id)} />
          ))}
        </View>
      </View>
    );
  }
  return (
    <View style={{ flexDirection: 'row', alignItems: 'flex-end' }}>
      <Key c={c} w={w * 1.5} h={w} onPress={p.next} disabled={locked || p.isLast} face={ORANGE} style={{ marginLeft: 8 }}>
        <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center' }}>
          <Icon name="play" size={20} color="#FFFFFF" style={{ transform: [{ scaleX: -1 }] }} />
        </View>
      </Key>
      <Key c={c} w={w} h={w} onPress={p.replay} style={{ marginLeft: 8 }}>
        <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center' }}>
          <Icon name="rotate-ccw" size={17} color={c.ink} />
        </View>
      </Key>
      <Key c={c} w={w} h={w} onPress={p.previous} disabled={p.isFirst} style={{ marginLeft: 8 }}>
        <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center' }}>
          <Icon name="skip-forward" size={17} color={c.ink} />
        </View>
      </Key>
      <Key c={c} w={w} h={w} onPress={p.toggleAuto} style={{ marginLeft: 8 }}>
        <View style={{ flexDirection: 'row', justifyContent: 'flex-end', direction: 'ltr' }}>
          <Led color={GREEN} on={p.auto} />
        </View>
        <Mono size={10} color={c.ink} align="center" style={{ marginTop: 4 }}>
          AUTO
        </Mono>
      </Key>
    </View>
  );
}

function Player({ wide, onBack }) {
  const c = pal();
  const p = usePlayer(sinePage);
  const [area, onArea] = useSize();
  const head = (
    <View style={{ height: 52, flexDirection: 'row', alignItems: 'center', paddingHorizontal: 18 }}>
      <Key c={c} w={40} h={36} onPress={onBack}>
        <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center' }}>
          <Icon name="chevron-right" size={16} color={c.ink} />
        </View>
      </Key>
      <Mono size={12} color={c.ink2} style={{ marginHorizontal: 12, letterSpacing: 3 }}>
        MO'EED · EE207
      </Mono>
      <View style={{ flex: 1 }} />
      <Mono size={12} color={c.ink2}>
        L05 · P16
      </Mono>
    </View>
  );
  const screen = (sw) => (
    <View style={{ backgroundColor: '#0B0B0C', borderRadius: 18, padding: 10 }}>
      <InkSlide p={p} width={sw} inkFor={pen} onJump={p.go} radius={6} />
    </View>
  );
  const answered = p.step.ask && p.isAnswered && (
    <View style={{ flexDirection: 'row', marginBottom: 10 }}>
      {p.step.ask.options.map((o) => (
        <AnswerKey key={o.id} c={c} label={o.label} w={wide ? 90 : 86} state={o.id === p.step.ask.answerID ? 'right' : o.id === p.picked ? 'wrong' : 'dim'} onCommit={() => {}} />
      ))}
    </View>
  );

  if (!wide) {
    return (
      <View style={{ flex: 1, backgroundColor: c.panel }}>
        {head}
        <ScrollView contentContainerStyle={{ paddingHorizontal: 14, paddingBottom: 24 }} onLayout={onArea}>
          {area && (
            <View>
              {screen(area.w - 48)}
              <View style={{ marginTop: 10 }}>
                <Trace p={p} width={area.w - 28} height={46} />
              </View>
              <View style={{ marginTop: 12 }}>
                <Readout p={p} compact />
              </View>
              <View style={{ marginTop: 14, alignItems: 'center' }}>
                {answered}
                <Transport c={c} p={p} compact />
              </View>
              <View style={{ marginTop: 14, alignItems: 'center' }}>
                <StepKeys c={c} p={p} size={Math.min(52, (area.w - 28) / 5 - 8)} columns={5} />
              </View>
            </View>
          )}
        </ScrollView>
      </View>
    );
  }
  const side = 330;
  return (
    <View style={{ flex: 1, backgroundColor: c.panel }}>
      {head}
      <View style={{ flex: 1, flexDirection: 'row', paddingHorizontal: 22, paddingBottom: 18 }} onLayout={onArea}>
        {area && (
          <>
            <View style={{ flex: 1 }}>
              {screen(Math.min(area.w - side - 90, (area.h - 140) * (4 / 3)))}
              <View style={{ marginTop: 14 }}>
                <Trace p={p} width={Math.min(area.w - side - 70, (area.h - 140) * (4 / 3) + 20)} />
              </View>
            </View>
            <View style={{ width: side, marginRight: 22 }}>
              <Readout p={p} />
              <View style={{ flexDirection: 'row', alignItems: 'flex-start', marginTop: 16 }}>
                <StepKeys c={c} p={p} size={64} />
                <View style={{ flex: 1, alignItems: 'center', paddingTop: 4 }}>
                  <Knob c={c} value={p.speed} values={[0.75, 1, 1.25, 1.5]} label="SPEED" onPress={p.cycleSpeed} />
                </View>
              </View>
              <View style={{ marginTop: 8 }}>
                {answered}
                <Transport c={c} p={p} />
              </View>
            </View>
          </>
        )}
      </View>
    </View>
  );
}

// MARK: Home, cartridges in a rack

function Module({ c, w, h, face, children, onPress, style }) {
  return (
    <Pressable onPress={onPress} style={[{ width: w, height: h, marginLeft: 12, marginBottom: 12 }, style]}>
      <View style={{ flex: 1, borderRadius: 16, backgroundColor: face || c.key, padding: 16, overflow: 'hidden' }}>{children}</View>
    </Pressable>
  );
}

function DotMatrix({ count, filled, here, color, dim, cols = 17, dot = 6 }) {
  return (
    <View style={{ flexDirection: 'row', flexWrap: 'wrap', width: cols * (dot + 4), direction: 'ltr' }}>
      {Array.from({ length: count }, (_, k) => (
        <View key={k} style={{ width: dot, height: dot, borderRadius: dot / 2, margin: 2, backgroundColor: k === here ? '#FFFFFF' : k < filled ? color : dim }} />
      ))}
    </View>
  );
}

function Home({ wide, onOpen }) {
  const c = pal();
  const [area, onArea] = useSize();
  const cur = LECTURES.find((l) => l.current);
  const unit = area ? (wide ? Math.min(260, (area.w - 12 * 4) / 4) : (area.w - 12 * 2) / 2) : 200;
  return (
    <View style={{ flex: 1, backgroundColor: c.panel }}>
      <View style={{ height: 60, flexDirection: 'row', alignItems: 'center', paddingHorizontal: wide ? 32 : 16 }}>
        <LogoMark size={28} />
        <Mono size={13} color={c.ink} style={{ marginHorizontal: 10, letterSpacing: 4 }}>
          MO'EED
        </Mono>
        <T size={13} color={c.ink3}>
          الدوائر الكهربائية
        </T>
        <View style={{ flex: 1 }} />
        <Led color={GREEN} on />
        <Mono size={10} color={c.ink2} style={{ marginHorizontal: 6 }}>
          READY
        </Mono>
      </View>
      <ScrollView contentContainerStyle={{ paddingHorizontal: wide ? 20 : 4, paddingBottom: 40 }}>
        <View onLayout={onArea} style={{ flexDirection: 'row', flexWrap: 'wrap' }}>
          {area && (
            <>
              <Module c={c} w={wide ? unit * 2 + 12 : unit * 2 + 12} h={wide ? unit * 1.1 : 250} face="#2F6BFF" onPress={onOpen}>
                <View style={{ flexDirection: 'row', justifyContent: 'space-between', direction: 'ltr' }}>
                  <Mono size={12} color="rgba(255,255,255,0.75)">
                    CARTRIDGE · L05
                  </Mono>
                  <Led color="#FFFFFF" on pulse />
                </View>
                <View style={{ flexDirection: 'row', alignItems: 'flex-end', marginTop: 8 }}>
                  <View style={{ flex: 1 }}>
                    <T size={wide ? 30 : 24} w="800" color="#FFFFFF" lh={wide ? 44 : 34}>
                      {cur.ar}
                    </T>
                    <S size={14} color="rgba(255,255,255,0.75)">
                      {cur.en}
                    </S>
                  </View>
                  <Mono size={wide ? 64 : 48} color="rgba(255,255,255,0.95)">
                    05
                  </Mono>
                </View>
                <View style={{ flex: 1 }} />
                <View style={{ flexDirection: 'row', alignItems: 'flex-end', justifyContent: 'space-between' }}>
                  <View>
                    <DotMatrix count={cur.pages} filled={Math.round(cur.pages * cur.done)} here={cur.page - 1} color="rgba(255,255,255,0.75)" dim="rgba(255,255,255,0.18)" dot={wide ? 7 : 5} />
                    <Mono size={11} color="rgba(255,255,255,0.75)" style={{ marginTop: 6 }}>
                      {`P16/${cur.pages} · STEP 05/09`}
                    </Mono>
                  </View>
                  <View style={{ width: 64, height: 64, borderRadius: 32, backgroundColor: ORANGE, alignItems: 'center', justifyContent: 'center' }}>
                    <Icon name="play" size={24} color="#FFFFFF" style={{ transform: [{ scaleX: -1 }] }} />
                  </View>
                </View>
              </Module>

              <Module c={c} w={unit} h={wide ? unit * 1.1 : 200} face={ORANGE}>
                <View style={{ flexDirection: 'row', justifyContent: 'space-between', direction: 'ltr' }}>
                  <Mono size={12} color="rgba(255,255,255,0.8)">
                    REVIEW
                  </Mono>
                  <Led color="#FFFFFF" on />
                </View>
                <Mono size={wide ? 92 : 70} color="#FFFFFF" style={{ marginTop: 4 }}>
                  {pad2(reviewItems.length + 2)}
                </Mono>
                <View style={{ flex: 1 }} />
                <T size={15} w="700" color="#FFFFFF">
                  أسئلة غلطت فيها
                </T>
                <T size={12} color="rgba(255,255,255,0.8)">
                  كل وحدة ترجعك لمكانها في السلايد
                </T>
              </Module>

              <Module c={c} w={unit} h={wide ? unit * 1.1 : 200} face="transparent" style={{}}>
                <View style={{ flex: 1, borderRadius: 12, borderWidth: 2, borderStyle: 'dashed', borderColor: c.ink3, alignItems: 'center', justifyContent: 'center', padding: 10 }}>
                  <View style={{ width: '70%', height: 10, borderRadius: 5, backgroundColor: c.panel2, marginBottom: 14 }} />
                  <T size={15} w="700" color={c.ink} align="center">
                    أدخل محاضرة
                  </T>
                  <Mono size={10} color={c.ink3} align="center" style={{ marginTop: 4 }}>
                    PDF → INK + VOICE
                  </Mono>
                </View>
              </Module>

              {LECTURES.filter((l) => !l.current).map((l) => (
                <Module key={l.n} c={c} w={wide ? (unit * 4 + 36) / 5 - 12 * 0.8 : unit} h={130}>
                  <View style={{ flexDirection: 'row', justifyContent: 'space-between', direction: 'ltr' }}>
                    <Mono size={22} color={c.ink}>
                      {'L' + pad2(l.n)}
                    </Mono>
                    <Led color={l.preparing ? ORANGE : GREEN} on pulse={!!l.preparing} />
                  </View>
                  <View style={{ flex: 1 }} />
                  <T size={14} w="700" color={c.ink} numberOfLines={1}>
                    {l.ar}
                  </T>
                  <Mono size={10} color={c.ink3}>
                    {l.preparing ? `WRITING ${Math.round(l.preparing * 100)}%` : `${l.pages} P · DONE`}
                  </Mono>
                </Module>
              ))}
            </>
          )}
        </View>
      </ScrollView>
    </View>
  );
}

export function InstrumentApp({ wide }) {
  const [route, setRoute] = useState('home');
  return route === 'player' ? <Player wide={wide} onBack={() => setRoute('home')} /> : <Home wide={wide} onOpen={() => setRoute('player')} />;
}

export const instrument = {
  key: 'instrument',
  name: 'الجهاز',
  line: 'جهاز قياس للمحاضرة: السلايد شاشته، الشرح على شاشة صغيرة، خط الزمن إشارة سكوب، وتسعة أزرار تضوي بلون قلم كل خطوة.',
  refs: 'Teenage Engineering OP-1 · Ableton Learning Synths · أجهزة المختبر',
  swatches: ['#E6E3DB', '#1C1D1F', '#2F6BFF', '#14A863', '#FF5A1F'],
  App: InstrumentApp,
};
