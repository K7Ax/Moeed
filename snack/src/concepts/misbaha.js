// «المسبحة»: the lecture is a strand of beads. Each step of the explanation is a bead, and its
// stone takes the colour of the ink that step drew. The question bead is the long shāhid. Pull the
// strand to move through it, one detent per bead. A wrong answer becomes an amber bead that is tied
// onto a separate review strand, and slides off when you get it right later.
import React, { useState } from 'react';
import { Animated, Pressable, ScrollView, View } from 'react-native';
import Svg, { Circle, Ellipse, G, Line, Path } from 'react-native-svg';
import { S, T, isDark, ltr } from '../theme';
import { BACK, Icon } from '../controls';
import { useSize } from '../ui';
import { LogoMark } from '../logo';
import { usePlayer } from '../player';
import { reviewItems, sinePage } from '../data';
import { Appear, FONTS, Glossed, InkSlide, ar, useEased, useHold, useScrub } from './engine';
import { LECTURES } from './mock';

const pal = () =>
  isDark()
    ? {
        bg: '#0A1530',
        bg2: '#0E1C3C',
        surface: '#12224A',
        gold: '#D9B46C',
        goldSoft: 'rgba(217,180,108,0.28)',
        text: '#F2E8D2',
        text2: 'rgba(242,232,210,0.68)',
        text3: 'rgba(242,232,210,0.42)',
        line: 'rgba(217,180,108,0.22)',
        thread: '#A88A52',
        amber: '#EE9445',
        jade: '#5FC9A6',
        hollow: '#0A1530',
      }
    : {
        bg: '#F4EEDF',
        bg2: '#ECE4D0',
        surface: '#FBF8F1',
        gold: '#9A762F',
        goldSoft: 'rgba(154,118,47,0.2)',
        text: '#0E2147',
        text2: 'rgba(14,33,71,0.68)',
        text3: 'rgba(14,33,71,0.42)',
        line: 'rgba(14,33,71,0.14)',
        thread: '#A9884C',
        amber: '#C2651C',
        jade: '#23806A',
        hollow: '#F4EEDF',
      };

// The stones: lapis, carnelian, jade, amber, amethyst. Deep on the white slide, lifted on navy.
const STONES = [
  { deep: '#2A4FB0', lit: '#86A2F2' },
  { deep: '#B2382A', lit: '#F28B78' },
  { deep: '#257A62', lit: '#6CD2B2' },
  { deep: '#B87512', lit: '#F2BC5E' },
  { deep: '#6B3FA4', lit: '#BB98EC' },
];
const stone = (i) => STONES[i % STONES.length].deep;
const stoneText = (i) => STONES[i % STONES.length][isDark() ? 'lit' : 'deep'];

const kufi = FONTS.kufi;

/** One bead: a stone with a little light on it, the shāhid long, the ones ahead hollow. */
function Bead({ c, x, y, r, color, hollow, long, onPress }) {
  const ry = long ? r * 1.55 : r;
  return (
    <G onPress={onPress}>
      {hollow ? (
        <Ellipse cx={x} cy={y} rx={r} ry={ry} fill={c.hollow} stroke={c.thread} strokeWidth={1.5} />
      ) : (
        <>
          <Ellipse cx={x} cy={y} rx={r} ry={ry} fill={color} />
          <Ellipse cx={x - r * 0.32} cy={y - ry * 0.36} rx={r * 0.34} ry={ry * 0.26} fill="#FFFFFF" opacity={0.32} />
        </>
      )}
    </G>
  );
}

function Tassel({ c, x, y, len = 56 }) {
  return (
    <G>
      <Circle cx={x} cy={y} r={5} fill={c.gold} />
      {[-12, -7, -3, 0, 3, 7, 12].map((dx, k) => (
        <Line key={k} x1={x} y1={y + 4} x2={x + dx} y2={y + len - Math.abs(dx) * 0.6} stroke={c.gold} strokeWidth={1.4} strokeLinecap="round" />
      ))}
    </G>
  );
}

/** The player's strand: hanging down the reading-start edge, or across the top on a phone. */
function Strand({ c, p, length, vertical }) {
  const n = p.n;
  const lead = 26;
  const tail = vertical ? 96 : 30;
  const sp = Math.min(vertical ? 62 : 40, (length - lead - tail) / (n - 1));
  const cross = vertical ? 46 : 40;
  // Along the strand, with a slight sway across it.
  const pos = (k) => {
    const a = lead + k * sp;
    const b = cross + Math.sin(k * 0.8) * (vertical ? 7 : 5) + (vertical ? 0 : Math.sin((k / (n - 1)) * Math.PI) * 8);
    return vertical ? [b, a] : [length - a, b];
  };
  const pts = Array.from({ length: n }, (_, k) => pos(k));
  const start = vertical ? [pts[0][0], 0] : [length, pts[0][1]];
  const end = vertical ? [pts[n - 1][0], pts[n - 1][1] + 34] : [pts[n - 1][0] - 22, pts[n - 1][1]];
  let d = `M${start[0]} ${start[1]}`;
  [...pts, end].forEach((q) => (d += ` L${q[0].toFixed(1)} ${q[1].toFixed(1)}`));

  const [hx, hy] = pts[p.i];
  const ex = useEased(hx, 260);
  const ey = useEased(hy, 260);
  const scrub = useScrub({ count: n, spacing: sp, axis: vertical ? 'y' : 'x', reverse: !vertical, current: p.i, onIndex: p.go });
  const W = vertical ? 96 : length;
  const H = vertical ? length : 86;
  const halo = 50;
  return (
    <View {...scrub.panHandlers} style={{ width: W, height: H, direction: 'ltr' }}>
      <Svg width={W} height={H}>
        <Path d={d} stroke={c.thread} strokeWidth={1.4} fill="none" />
        {vertical && <Tassel c={c} x={end[0]} y={end[1]} />}
        {pts.map(([x, y], k) => (
          <Bead
            key={k}
            c={c}
            x={x}
            y={y}
            r={k === p.i ? 15 : 11}
            color={stone(k)}
            hollow={k > p.i}
            long={!!p.page.steps[k].ask}
            onPress={() => p.go(k)}
          />
        ))}
      </Svg>
      <Animated.View
        pointerEvents="none"
        style={{
          position: 'absolute',
          width: halo,
          height: halo,
          borderRadius: halo / 2,
          borderWidth: 1.5,
          borderColor: c.gold,
          left: Animated.add(ex, -halo / 2),
          top: Animated.add(ey, -halo / 2),
        }}
      />
    </View>
  );
}

/** Press and hold an answer bead; it fills with gold, and commits when full. */
function HoldBead({ c, label, state, onCommit, size }) {
  const h = useHold(onCommit, 700);
  const fill = h.v.interpolate({ inputRange: [0, 1], outputRange: [0, size] });
  const bg = state === 'right' ? c.jade : state === 'wrong' ? c.amber : 'transparent';
  const fg = state === 'right' || state === 'wrong' ? '#FFFFFF' : state === 'dim' ? c.text3 : c.text;
  return (
    <Pressable onPressIn={h.start} onPressOut={h.cancel} disabled={state !== 'idle'} style={{ alignItems: 'center', marginHorizontal: 9 }}>
      <View
        style={{
          width: size,
          height: size,
          borderRadius: size / 2,
          borderWidth: 1.5,
          borderColor: state === 'dim' ? c.line : c.gold,
          overflow: 'hidden',
          alignItems: 'center',
          justifyContent: 'center',
          backgroundColor: bg,
        }}
      >
        <Animated.View style={{ position: 'absolute', bottom: 0, left: 0, right: 0, height: fill, backgroundColor: c.goldSoft }} />
        <S size={size * 0.24} w="700" color={fg} align="center">
          {ltr(label)}
        </S>
      </View>
    </Pressable>
  );
}

function Ask({ c, p, wide }) {
  const a = p.step.ask;
  const size = wide ? 84 : 70;
  const state = (o) => {
    if (!p.isAnswered) return 'idle';
    if (o.id === a.answerID) return 'right';
    if (o.id === p.picked) return 'wrong';
    return 'dim';
  };
  return (
    <View style={{ alignItems: 'center' }}>
      <Glossed text={a.question} size={wide ? 26 : 21} w="700" color={c.text} term={stoneText(p.i)} font={kufi} align="center" lh={wide ? 42 : 34} />
      <View style={{ flexDirection: 'row', marginTop: 18 }}>
        {a.options.map((o) => (
          <HoldBead key={o.id} c={c} label={o.label} state={state(o)} size={size} onCommit={() => p.pick(o.id)} />
        ))}
      </View>
      <T size={14} color={c.text3} align="center" style={{ marginTop: 12 }}>
        {p.isAnswered ? ' ' : 'اضغط مطوّلاً على الحبّة اللي تتوقعها'}
      </T>
      {p.isAnswered && (
        <Appear style={{ marginTop: 4, alignItems: 'center', maxWidth: 520 }}>
          <Glossed text={a.why} size={wide ? 18 : 16} color={c.text} term={c.gold} align="center" lh={wide ? 32 : 28} />
          {!p.pickedRight && (
            <View style={{ flexDirection: 'row', alignItems: 'center', marginTop: 10 }}>
              <View style={{ width: 12, height: 12, borderRadius: 6, backgroundColor: c.amber }} />
              <T size={14} w="600" color={c.amber} style={{ marginHorizontal: 8 }}>
                انربطت حبّة على خيط المراجعة
              </T>
            </View>
          )}
          <Pressable onPress={p.next} style={{ marginTop: 16, paddingHorizontal: 22, height: 44, borderRadius: 22, borderWidth: 1.5, borderColor: c.gold, justifyContent: 'center' }}>
            <T size={15} w="700" color={c.gold}>
              الحبّة التالية
            </T>
          </Pressable>
        </Appear>
      )}
    </View>
  );
}

/** The step's words: the phrase being said large, the one before it small above. */
function Words({ c, p, wide }) {
  const big = wide ? 27 : 21;
  return (
    <View style={{ minHeight: wide ? 120 : 100, justifyContent: 'flex-start' }}>
      {p.step.caption.map((ph, k) => {
        const on = k < p.revealed;
        const now = k === p.revealed - 1;
        return (
          <Appear key={p.playKey + '-' + k} on={on}>
            <Glossed
              text={ph}
              size={now ? big : big * 0.68}
              w={now ? '700' : '400'}
              color={now ? c.text : c.text3}
              term={stoneText(p.i)}
              font={kufi}
              align="center"
              lh={Math.round((now ? big : big * 0.68) * 1.55)}
            />
          </Appear>
        );
      })}
    </View>
  );
}

function RoundKey({ c, icon, label, on, onPress }) {
  return (
    <Pressable onPress={onPress} hitSlop={6} style={{ alignItems: 'center', marginHorizontal: 12 }}>
      <View style={{ width: 44, height: 44, borderRadius: 22, borderWidth: 1.2, borderColor: on ? c.gold : c.line, backgroundColor: on ? c.goldSoft : 'transparent', alignItems: 'center', justifyContent: 'center' }}>
        {icon ? <Icon name={icon} size={17} color={on ? c.gold : c.text2} /> : <S size={14} w="700" color={c.text2}>{label}</S>}
      </View>
    </Pressable>
  );
}

function Player({ wide, onBack }) {
  const c = pal();
  const p = usePlayer(sinePage);
  const [area, onArea] = useSize();
  const head = (
    <View style={{ height: 56, flexDirection: 'row', alignItems: 'center', paddingHorizontal: 20 }}>
      <Pressable onPress={onBack} hitSlop={8} style={{ flexDirection: 'row', alignItems: 'center', flex: 1 }}>
        <Icon name={BACK} size={17} color={c.gold} />
        <T size={14} color={c.gold} style={{ marginHorizontal: 6 }}>
          المسبحة
        </T>
      </Pressable>
      <T size={14} w="600" color={c.text2} style={{ fontFamily: kufi }}>
        {`الموجات الجيبية · ص ${ar(16)}`}
      </T>
      <View style={{ flex: 1, alignItems: 'flex-end' }}>
        <T size={14} color={c.text3}>{`الحبّة ${ar(p.i + 1)} من ${ar(p.n)}`}</T>
      </View>
    </View>
  );
  const keys = (
    <View style={{ flexDirection: 'row', justifyContent: 'center' }}>
      <RoundKey c={c} icon="chevron-right" onPress={p.previous} />
      <RoundKey c={c} icon="rotate-ccw" onPress={p.replay} />
      <RoundKey c={c} icon={p.auto ? 'pause' : 'play'} on={p.auto} onPress={p.toggleAuto} />
      <RoundKey c={c} label={'×' + p.speed} onPress={p.cycleSpeed} />
      <RoundKey c={c} icon="chevron-left" on onPress={p.next} />
    </View>
  );
  const body = (sw) => (
    <View style={{ alignItems: 'center' }}>
      <View style={{ padding: 4, borderRadius: 10, borderWidth: 1, borderColor: c.line, backgroundColor: c.bg2 }}>
        <InkSlide p={p} width={sw} inkFor={stone} onJump={p.go} radius={6} />
      </View>
      <View style={{ width: Math.min(sw, 680), marginTop: wide ? 22 : 16 }}>{p.step.ask ? <Ask key={p.playKey} c={c} p={p} wide={wide} /> : <Words c={c} p={p} wide={wide} />}</View>
    </View>
  );

  if (!wide) {
    return (
      <View style={{ flex: 1, backgroundColor: c.bg }}>
        {head}
        <View onLayout={onArea}>{area && <Strand c={c} p={p} length={area.w} vertical={false} />}</View>
        <ScrollView contentContainerStyle={{ paddingHorizontal: 14, paddingTop: 6, paddingBottom: 24 }}>{area && body(area.w - 28)}</ScrollView>
        <View style={{ paddingVertical: 10 }}>{keys}</View>
      </View>
    );
  }
  return (
    <View style={{ flex: 1, backgroundColor: c.bg }}>
      {head}
      <View style={{ flex: 1, flexDirection: 'row' }}>
        <View style={{ width: 120, alignItems: 'center' }} onLayout={onArea}>
          {area && <Strand c={c} p={p} length={area.h} vertical />}
        </View>
        <View style={{ flex: 1, paddingHorizontal: 28, paddingBottom: 16 }}>
          <View style={{ flex: 1 }}>{area && body(Math.min(860, (area.h - 290) * (4 / 3)))}</View>
          {keys}
        </View>
      </View>
    </View>
  );
}

// MARK: Home

/** A lecture's pages as a long strand across the width: read stones, where you are in gold, the rest hollow. */
function PageStrand({ c, width, l, height = 70, r = 6 }) {
  const n = l.pages;
  const pad = 14;
  const read = Math.round(n * l.done);
  const pts = Array.from({ length: n }, (_, k) => {
    const f = k / (n - 1);
    return [width - pad - f * (width - pad * 2), height / 2 + Math.sin(f * Math.PI * 2.2) * (height / 2 - r - 6)];
  });
  let d = `M${width} ${pts[0][1]}`;
  pts.forEach((q) => (d += ` L${q[0].toFixed(1)} ${q[1].toFixed(1)}`));
  return (
    <Svg width={width} height={height}>
      <Path d={d} stroke={c.thread} strokeWidth={1.2} fill="none" />
      {pts.map(([x, y], k) => {
        const here = l.current && k === l.page - 1;
        if (here) {
          return (
            <G key={k}>
              <Circle cx={x} cy={y} r={r * 2.6} fill="none" stroke={c.gold} strokeWidth={1.5} />
              <Bead c={c} x={x} y={y} r={r * 1.7} color={c.gold} />
            </G>
          );
        }
        return <Bead key={k} c={c} x={x} y={y} r={r} color={stone(k)} hollow={k >= read} />;
      })}
    </Svg>
  );
}

function ReviewStrand({ c, count = 7, width = 280 }) {
  const sp = 30;
  return (
    <Svg width={width} height={64}>
      <Path d={`M${width} 22 Q${width - 40} 30 ${width - 60} 30 L${width - 60 - sp * (count - 1)} 30 Q${width - 80 - sp * count} 30 ${width - 90 - sp * count} 18`} stroke={c.thread} strokeWidth={1.2} fill="none" />
      {Array.from({ length: count }, (_, k) => (
        <Bead key={k} c={c} x={width - 60 - k * sp} y={30} r={11} color={c.amber} />
      ))}
    </Svg>
  );
}

function Home({ wide, onOpen }) {
  const c = pal();
  const [w, onW] = useSize();
  const current = LECTURES.find((l) => l.current);
  const pad = wide ? 44 : 18;
  const review = (
    <View style={{ borderRadius: 18, borderWidth: 1, borderColor: c.line, padding: 20, backgroundColor: c.bg2 }}>
      <T size={13} w="700" color={c.amber}>
        خيط المراجعة
      </T>
      <T size={wide ? 24 : 21} w="700" color={c.text} style={{ fontFamily: kufi, marginTop: 4 }}>
        {`${ar(7)} حبّات تنتظرك`}
      </T>
      <View style={{ marginTop: 8, alignItems: 'flex-start' }}>
        <ReviewStrand c={c} width={wide ? 300 : 280} />
      </View>
      <T size={14} color={c.text2} lh={24}>
        كل غلطة صارت حبّة. جاوبها صح وتنفكّ من الخيط.
      </T>
      {reviewItems.slice(0, 2).map((r) => (
        <View key={r.id} style={{ flexDirection: 'row', alignItems: 'center', marginTop: 12 }}>
          <View style={{ width: 10, height: 10, borderRadius: 5, backgroundColor: c.amber, marginLeft: 10 }} />
          <Glossed text={r.question} size={14} color={c.text} term={c.gold} numberOfLines={1} style={{ flex: 1 }} />
        </View>
      ))}
      <Pressable style={{ marginTop: 16, height: 44, borderRadius: 22, backgroundColor: c.amber, alignItems: 'center', justifyContent: 'center' }}>
        <T size={15} w="700" color="#FFFFFF">
          ابدأ المراجعة
        </T>
      </Pressable>
    </View>
  );
  const lectures = (
    <View>
      <T size={13} w="700" color={c.gold} style={{ marginBottom: 6 }}>
        محاضرات EE207
      </T>
      {LECTURES.map((l) => {
        const read = Math.round(l.done * 12);
        return (
          <Pressable key={l.n} onPress={l.current ? onOpen : undefined} style={{ flexDirection: 'row', alignItems: 'center', paddingVertical: 13, borderBottomWidth: 1, borderBottomColor: c.line }}>
            <T size={26} w="700" color={l.current ? c.gold : c.text3} style={{ width: 40, fontFamily: kufi }}>
              {ar(l.n)}
            </T>
            <View style={{ flex: 1 }}>
              <T size={17} w={l.current ? '700' : '500'} color={l.preparing ? c.text3 : c.text} style={{ fontFamily: kufi }}>
                {l.ar}
              </T>
              <T size={12} color={c.text3}>
                {l.preparing ? `تُنظَم الآن · ${ar(Math.round(l.preparing * 100))}٪` : `${ar(l.pages)} صفحة`}
              </T>
            </View>
            <View style={{ flexDirection: 'row', alignItems: 'center' }}>
              {Array.from({ length: 12 }, (_, k) => (
                <View
                  key={k}
                  style={{
                    width: 8,
                    height: 8,
                    borderRadius: 4,
                    marginLeft: 3,
                    backgroundColor: k < read ? stone(k) : 'transparent',
                    borderWidth: k < read ? 0 : 1,
                    borderColor: c.thread,
                    borderStyle: l.preparing && k >= Math.round(l.preparing * 12) ? 'dotted' : 'solid',
                    opacity: l.preparing && k >= Math.round(l.preparing * 12) ? 0.5 : 1,
                  }}
                />
              ))}
            </View>
          </Pressable>
        );
      })}
    </View>
  );
  return (
    <View style={{ flex: 1, backgroundColor: c.bg }}>
      <View style={{ height: 60, flexDirection: 'row', alignItems: 'center', paddingHorizontal: pad }}>
        <LogoMark size={28} />
        <T size={19} w="700" color={c.gold} style={{ marginHorizontal: 10, fontFamily: kufi }}>
          مُعيد
        </T>
        <View style={{ flex: 1 }} />
        <Pressable style={{ height: 36, paddingHorizontal: 14, borderRadius: 18, borderWidth: 1, borderColor: c.line, justifyContent: 'center' }}>
          <T size={13} w="600" color={c.text2}>
            + محاضرة
          </T>
        </Pressable>
      </View>
      <ScrollView contentContainerStyle={{ paddingHorizontal: pad, paddingBottom: 40 }}>
        <Pressable onPress={onOpen} onLayout={onW} style={{ marginTop: wide ? 18 : 8 }}>
          <T size={14} color={c.text3}>
            تابع مسبحتك
          </T>
          <T size={wide ? 46 : 34} w="700" color={c.text} lh={wide ? 66 : 50} style={{ fontFamily: kufi }}>
            {current.ar}
          </T>
          <T size={15} color={c.text2}>
            {`المحاضرة ${ar(current.n)} · وقفت عند الصفحة ${ar(current.page)}، الخطوة ${ar(5)}`}
          </T>
          {w && (
            <View style={{ marginTop: 14 }}>
              <PageStrand c={c} width={w.w} l={current} height={wide ? 110 : 84} r={wide ? 7 : 4.5} />
            </View>
          )}
          <View style={{ flexDirection: 'row', alignItems: 'center', marginTop: 8 }}>
            <View style={{ height: 46, paddingHorizontal: 22, borderRadius: 23, backgroundColor: c.gold, justifyContent: 'center' }}>
              <T size={15} w="700" color={c.bg}>
                أكمل من الصفحة ١٦
              </T>
            </View>
            <T size={13} color={c.text3} style={{ marginHorizontal: 14 }}>
              أو اسحب على الخيط لأي صفحة
            </T>
          </View>
        </Pressable>
        <View style={{ flexDirection: wide ? 'row' : 'column', marginTop: 34, alignItems: 'flex-start' }}>
          <View style={{ flex: wide ? 1 : undefined, alignSelf: 'stretch' }}>{lectures}</View>
          <View style={{ width: wide ? 380 : undefined, alignSelf: 'stretch', marginTop: wide ? 0 : 28, marginRight: wide ? 36 : 0 }}>{review}</View>
        </View>
      </ScrollView>
    </View>
  );
}

export function MisbahaApp({ wide }) {
  const [route, setRoute] = useState('home');
  return route === 'player' ? <Player wide={wide} onBack={() => setRoute('home')} /> : <Home wide={wide} onOpen={() => setRoute('player')} />;
}

export const misbaha = {
  key: 'misbaha',
  name: 'المسبحة',
  line: 'المحاضرة خيط حبّات. كل خطوة حبّة بلون حبرها، تسحب الخيط وتتنقّل، والغلطة حبّة كهرمان على خيط المراجعة.',
  refs: 'موقعك بالمسبحة · Halide · (Not Boring) Habits',
  swatches: ['#0A1530', '#D9B46C', '#2A4FB0', '#B2382A', '#EE9445'],
  App: MisbahaApp,
};
