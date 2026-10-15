// «الأصلي»: Mo'eed built the way the platform's own best apps are, not around an invented
// metaphor. The library reads like Apple Books and Podcasts: a sidebar, a large title, one "up
// next" with the slide as its artwork, shelves of covers, a mini player. The player reads like
// Apple Music's lyrics: the slide is the artwork, and the tutor's words scroll beside it line by
// line, lighting word by word as they're said (as Speak does). Past lines stay, dimmed, and
// tapping one goes back to it. Questions arrive as a line of their own, with Brilliant's quiet
// answer buttons. Colour comes from the logo's teal and nowhere else.
import React, { useEffect, useMemo, useRef, useState } from 'react';
import { Platform, Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import Svg, { Circle, Defs, LinearGradient, Path, Rect, Stop } from 'react-native-svg';
import { S, START, T, clamp01, isDark, ltr, readingMs } from '../theme';
import { Icon, haptic } from '../controls';
import { useSize } from '../ui';
import { LogoMark } from '../logo';
import { SlideCrop, SlideStage, useClock } from '../slide';
import { usePlayer } from '../player';
import { reviewItems, sinePage } from '../data';
import { InkSlide, ar, useScrub } from './engine';
import { LECTURES, ORDINAL } from './mock';

// iOS system colours, with the logo's teal as the only tint.
const pal = () =>
  isDark()
    ? {
        bg: '#000000',
        raised: '#1C1C1E',
        raised2: '#2C2C2E',
        sidebar: '#1C1C1E',
        text: '#FFFFFF',
        text2: 'rgba(235,235,245,0.6)',
        text3: 'rgba(235,235,245,0.3)',
        sep: 'rgba(84,84,88,0.6)',
        fill: 'rgba(120,120,128,0.24)',
        accent: '#3CC8B8',
        accentSoft: 'rgba(60,200,184,0.18)',
        onAccent: '#00201D',
        bar: 'rgba(30,30,32,0.94)',
      }
    : {
        bg: '#FFFFFF',
        raised: '#F2F2F7',
        raised2: '#E5E5EA',
        sidebar: '#F2F2F7',
        text: '#000000',
        text2: 'rgba(60,60,67,0.6)',
        text3: 'rgba(60,60,67,0.3)',
        sep: 'rgba(60,60,67,0.2)',
        fill: 'rgba(120,120,128,0.12)',
        accent: '#0A8F86',
        accentSoft: 'rgba(10,143,134,0.12)',
        onAccent: '#FFFFFF',
        bar: 'rgba(249,249,249,0.94)',
      };

// Each lecture's cover colour; the current one wears the logo's teal.
const COVERS = ['#2E4C73', '#5D3D8F', '#2D6A4F', '#9A4B1F', '#0B7F78', '#4B5058'];
const PEN = '#0A8F86';
const ASK_PEN = '#E8590C';
// Where the sample question's answer sits on the slide: the trough at 0.3 s.
const ANSWER_AT = [430, 510];

const hair = StyleSheet.hairlineWidth;
const current = LECTURES.find((l) => l.current);
const pastInk = sinePage.steps
  .slice(0, 4)
  .filter((s) => !s.ask)
  .flatMap((s) => s.marks)
  .filter((m) => m.t !== 'spot');

// MARK: Glyphs

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

function Capsule({ label, icon, glyph, onPress, kind = 'filled', c, height = 44, style }) {
  const filled = kind === 'filled';
  const fg = filled ? c.onAccent : c.accent;
  return (
    <Pressable
      onPress={() => {
        haptic('light');
        onPress && onPress();
      }}
      style={({ pressed }) => [
        {
          height,
          paddingHorizontal: 20,
          borderRadius: height / 2,
          backgroundColor: filled ? c.accent : c.accentSoft,
          flexDirection: 'row',
          alignItems: 'center',
          justifyContent: 'center',
          gap: 8,
          opacity: pressed ? 0.75 : 1,
        },
        style,
      ]}
    >
      {glyph && <Glyph name={glyph} size={16} color={fg} />}
      {icon && <Icon name={icon} size={17} color={fg} />}
      <T size={17} w="600" color={fg}>
        {label}
      </T>
    </Pressable>
  );
}

// MARK: Covers and artwork

/** A lecture's cover: its colour, its number large, its English title the way the slides set it. */
function Cover({ lec, size }) {
  const bg = COVERS[(lec.n - 1) % COVERS.length];
  const id = `cv${lec.n}-${size}`;
  return (
    <View style={{ width: size, height: size, borderRadius: size * 0.06, overflow: 'hidden', backgroundColor: bg }}>
      <Svg style={StyleSheet.absoluteFill} width={size} height={size}>
        <Defs>
          <LinearGradient id={id} x1="0" y1="0" x2="0.3" y2="1">
            <Stop offset="0" stopColor="#FFFFFF" stopOpacity="0.16" />
            <Stop offset="1" stopColor="#000000" stopOpacity="0.28" />
          </LinearGradient>
        </Defs>
        <Rect width={size} height={size} fill={`url(#${id})`} />
      </Svg>
      <View style={{ flex: 1, padding: size * 0.09, justifyContent: 'space-between' }}>
        <T size={Math.max(9, size * 0.07)} w="700" color="rgba(255,255,255,0.72)">
          {ltr('EE207')}
        </T>
        <View>
          <T size={size * 0.4} w="800" color="#FFFFFF" lh={size * 0.44}>
            {ar(lec.n)}
          </T>
          <S size={Math.max(10, size * 0.082)} color="rgba(255,255,255,0.9)" numberOfLines={2} lh={Math.max(13, size * 0.1)}>
            {lec.en}
          </S>
        </View>
      </View>
      {lec.preparing !== undefined && (
        <View style={{ ...StyleSheet.absoluteFillObject, backgroundColor: 'rgba(0,0,0,0.35)' }}>
          <View style={{ position: 'absolute', left: size * 0.09, right: size * 0.09, bottom: size * 0.09, height: 4, borderRadius: 2, backgroundColor: 'rgba(255,255,255,0.3)' }}>
            <View style={{ position: 'absolute', right: 0, top: 0, bottom: 0, width: `${lec.preparing * 100}%`, borderRadius: 2, backgroundColor: '#FFFFFF' }} />
          </View>
        </View>
      )}
    </View>
  );
}

/** The slide as artwork: white, rounded, a hairline at its edge. */
function Artwork({ width, radius = 12, c }) {
  return (
    <View style={{ width, borderRadius: radius, overflow: 'hidden', borderWidth: hair, borderColor: c.sep }}>
      <SlideStage page={sinePage} width={width} pastMarks={pastInk} />
    </View>
  );
}

// MARK: Library

function SectionHead({ c, title, action, onAction }) {
  return (
    <View style={{ flexDirection: 'row', alignItems: 'baseline', marginTop: 34, marginBottom: 12 }}>
      <T size={22} w="700" color={c.text} style={{ flex: 1 }}>
        {title}
      </T>
      {action && (
        <Pressable onPress={onAction} hitSlop={8}>
          <T size={17} color={c.accent}>
            {action}
          </T>
        </Pressable>
      )}
    </View>
  );
}

function UpNext({ c, wide, onPlay }) {
  const [box, onBox] = useSize();
  const meta = (
    <View style={{ flex: wide ? 1 : undefined, justifyContent: 'center' }}>
      <T size={13} w="600" color={c.accent}>
        أكمل من حيث وقفت
      </T>
      <T size={wide ? 28 : 26} w="800" color={c.text} style={{ marginTop: 4 }}>
        {current.ar}
      </T>
      <T size={15} color={c.text2} style={{ marginTop: 2 }}>
        {`المحاضرة ${ORDINAL[current.n - 1]} · صفحة ${ar(current.page)} من ${ar(current.pages)}`}
      </T>
      <View style={{ flexDirection: 'row', alignItems: 'center', gap: 10, marginTop: 16 }}>
        <View style={{ flex: 1, height: 4, borderRadius: 2, backgroundColor: c.fill }}>
          <View style={{ position: 'absolute', right: 0, top: 0, bottom: 0, width: `${current.done * 100}%`, borderRadius: 2, backgroundColor: c.accent }} />
        </View>
        <T size={13} color={c.text2}>
          {`${ar(Math.round(current.done * 100))}٪`}
        </T>
      </View>
      <T size={15} color={c.text} style={{ marginTop: 14 }}>
        {`الخطوة ${ar(5)} من ${ar(9)}: ${sinePage.title}`}
      </T>
      <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 10, marginTop: 20 }}>
        <Capsule c={c} label="أكمل" glyph="play" onPress={onPlay} />
        <Capsule c={c} kind="tinted" label="من أولها" onPress={onPlay} />
      </View>
    </View>
  );
  if (!wide) {
    return (
      <Pressable onPress={onPlay}>
        <View style={{ backgroundColor: c.raised, borderRadius: 20, padding: 16 }}>
          <ArtworkFit c={c} />
          <View style={{ marginTop: 16 }}>{meta}</View>
        </View>
      </Pressable>
    );
  }
  return (
    <View onLayout={onBox} style={{ backgroundColor: c.raised, borderRadius: 22, padding: 22, flexDirection: 'row', gap: 26 }}>
      {box && (
        <Pressable onPress={onPlay}>
          <Artwork c={c} width={Math.round(Math.min(420, (box.w - 70) * 0.5))} />
        </Pressable>
      )}
      {meta}
    </View>
  );
}

function ArtworkFit({ c }) {
  const [size, onLayout] = useSize();
  return <View onLayout={onLayout}>{size && <Artwork c={c} width={size.w} />}</View>;
}

function Shelf({ c, size, onOpen }) {
  return (
    <ScrollView horizontal showsHorizontalScrollIndicator={false} style={{ marginHorizontal: -4 }} contentContainerStyle={{ gap: 16, paddingHorizontal: 4 }}>
      {LECTURES.map((l) => (
        <Pressable key={l.n} onPress={l.current ? onOpen : undefined} style={({ pressed }) => ({ width: size, opacity: pressed ? 0.7 : 1 })}>
          <Cover lec={l} size={size} />
          <T size={15} w="600" color={c.text} numberOfLines={1} style={{ marginTop: 8 }}>
            {l.ar}
          </T>
          <T size={13} color={l.current ? c.accent : c.text2} numberOfLines={1}>
            {l.preparing !== undefined
              ? `يتجهّز · ${ar(Math.round(l.preparing * 100))}٪`
              : l.current
              ? `وصلت صفحة ${ar(l.page)}`
              : `خلصتها · ${ar(l.pages)} صفحة`}
          </T>
        </Pressable>
      ))}
    </ScrollView>
  );
}

function ReviewList({ c, limit = 3 }) {
  const items = reviewItems.slice(0, limit);
  return (
    <View style={{ backgroundColor: c.raised, borderRadius: 14, overflow: 'hidden' }}>
      {items.map((it, k) => (
        <Pressable key={it.id} style={({ pressed }) => ({ backgroundColor: pressed ? c.fill : 'transparent' })}>
          <View style={{ flexDirection: 'row', alignItems: 'center', paddingVertical: 11, paddingHorizontal: 14, gap: 14 }}>
            <View style={{ borderRadius: 8, overflow: 'hidden', borderWidth: hair, borderColor: c.sep }}>
              <SlideCrop page={sinePage} focus={it.focus} w={64} h={48} zoom={2.6} />
            </View>
            <View style={{ flex: 1 }}>
              <Question text={it.question} c={c} />
              <T size={13} color={c.text2} style={{ marginTop: 2 }}>
                {`جاوبت ${ltr(it.yours)} · المحاضرة ${ar(it.lecture)}، صفحة ${ar(it.page)}`}
              </T>
            </View>
            <Icon name="chevron-left" size={18} color={c.text3} />
          </View>
          {k < items.length - 1 && <View style={{ height: hair, backgroundColor: c.sep, marginRight: 92 }} />}
        </Pressable>
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
    <Pressable onPress={onOpen} style={[{ borderRadius: 16, backgroundColor: c.bar, borderWidth: hair, borderColor: c.sep, shadowColor: '#000', shadowOpacity: isDark() ? 0 : 0.12, shadowRadius: 20, shadowOffset: { width: 0, height: 6 } }, style]}>
      <View style={{ flexDirection: 'row', alignItems: 'center', height: 64, paddingHorizontal: 10, gap: 12 }}>
        <View style={{ borderRadius: 6, overflow: 'hidden' }}>
          <SlideStage page={sinePage} width={60} pastMarks={pastInk} />
        </View>
        <View style={{ flex: 1 }}>
          <T size={15} w="600" color={c.text} numberOfLines={1}>
            {sinePage.title}
          </T>
          <T size={13} color={c.text2} numberOfLines={1}>
            {`${current.ar} · صفحة ${ar(current.page)}`}
          </T>
        </View>
        <Pressable onPress={onOpen} hitSlop={10} style={{ padding: 8 }}>
          <Glyph name="play" size={24} color={c.text} />
        </Pressable>
        <Pressable onPress={onOpen} hitSlop={10} style={{ padding: 8 }}>
          <Glyph name="fwd" flip size={24} color={c.text} />
        </Pressable>
      </View>
    </Pressable>
  );
}

const NAV = [
  { key: 'home', label: 'الرئيسية', icon: 'home' },
  { key: 'library', label: 'المكتبة', icon: 'book-open' },
  { key: 'review', label: 'المراجعة', icon: 'rotate-ccw', badge: reviewItems.length + 2 },
  { key: 'import', label: 'محاضرة جديدة', icon: 'plus-circle' },
];

function Sidebar({ c }) {
  return (
    <View style={{ width: 270, backgroundColor: c.sidebar, borderLeftWidth: hair, borderLeftColor: c.sep, paddingHorizontal: 14, paddingTop: 22 }}>
      <View style={{ flexDirection: 'row', alignItems: 'center', gap: 10, paddingHorizontal: 8, marginBottom: 20 }}>
        <LogoMark size={30} />
        <T size={22} w="800" color={c.text}>
          مُعيد
        </T>
      </View>
      {NAV.map((n, k) => {
        const on = k === 0;
        return (
          <View key={n.key} style={{ flexDirection: 'row', alignItems: 'center', height: 42, borderRadius: 10, paddingHorizontal: 10, gap: 12, backgroundColor: on ? c.fill : 'transparent' }}>
            <Icon name={n.icon} size={19} color={c.accent} />
            <T size={17} w={on ? '600' : '400'} color={c.text} style={{ flex: 1 }}>
              {n.label}
            </T>
            {n.badge && (
              <T size={15} color={c.text2}>
                {ar(n.badge)}
              </T>
            )}
          </View>
        );
      })}
      <T size={13} w="600" color={c.text2} style={{ marginTop: 26, marginBottom: 6, paddingHorizontal: 10 }}>
        المقررات
      </T>
      {[
        ['EE207', 'الدوائر الكهربائية', true],
        ['EE211', 'الإلكترونيات', false],
      ].map(([code, name, on]) => (
        <View key={code} style={{ flexDirection: 'row', alignItems: 'center', height: 42, borderRadius: 10, paddingHorizontal: 10, gap: 12 }}>
          <View style={{ width: 22, height: 22, borderRadius: 5, backgroundColor: on ? COVERS[4] : COVERS[0], alignItems: 'center', justifyContent: 'center' }}>
            <T size={9} w="800" color="#FFFFFF">
              {ltr(code.slice(2))}
            </T>
          </View>
          <T size={17} color={c.text} style={{ flex: 1 }} numberOfLines={1}>
            {name}
          </T>
        </View>
      ))}
    </View>
  );
}

function TabBar({ c }) {
  return (
    <View style={{ flexDirection: 'row', backgroundColor: c.bar, borderTopWidth: hair, borderTopColor: c.sep, paddingTop: 6, paddingBottom: 8 }}>
      {NAV.map((n, k) => (
        <View key={n.key} style={{ flex: 1, alignItems: 'center' }}>
          <Icon name={n.icon} size={22} color={k === 0 ? c.accent : c.text2} />
          <T size={10} w="500" color={k === 0 ? c.accent : c.text2} align="center" style={{ marginTop: 2 }}>
            {n.label}
          </T>
        </View>
      ))}
    </View>
  );
}

function Home({ wide, onOpen }) {
  const c = pal();
  const sections = (
    <>
      <View style={{ flexDirection: 'row', alignItems: 'center' }}>
        <T size={34} w="800" color={c.text} style={{ flex: 1 }}>
          الرئيسية
        </T>
        {!wide && <LogoMark size={32} />}
      </View>
      <View style={{ marginTop: 14 }}>
        <UpNext c={c} wide={wide} onPlay={onOpen} />
      </View>
      <SectionHead c={c} title="الدوائر الكهربائية" action="عرض الكل" />
      <Shelf c={c} size={wide ? 168 : 140} onOpen={onOpen} />
      <SectionHead c={c} title={`للمراجعة · ${ar(reviewItems.length + 2)}`} action="ابدأ المراجعة" />
      <ReviewList c={c} limit={wide ? 4 : 3} />
      <T size={13} color={c.text2} style={{ marginTop: 8, paddingHorizontal: 4 }}>
        الأسئلة اللي غلطت فيها ترجع لك هنا، كل وحدة مع مكانها في السلايد.
      </T>
    </>
  );
  if (wide) {
    return (
      <View style={{ flex: 1, flexDirection: 'row', backgroundColor: c.bg }}>
        <Sidebar c={c} />
        <View style={{ flex: 1 }}>
          <ScrollView contentContainerStyle={{ paddingHorizontal: 40, paddingTop: 30, paddingBottom: 120, maxWidth: 1000, width: '100%', alignSelf: 'center' }}>{sections}</ScrollView>
          <MiniPlayer c={c} onOpen={onOpen} style={{ position: 'absolute', bottom: 18, left: 40, right: 40 }} />
        </View>
      </View>
    );
  }
  return (
    <View style={{ flex: 1, backgroundColor: c.bg }}>
      <ScrollView contentContainerStyle={{ padding: 16, paddingTop: 12, paddingBottom: 100 }}>{sections}</ScrollView>
      <MiniPlayer c={c} onOpen={onOpen} style={{ position: 'absolute', bottom: 66, left: 8, right: 8 }} />
      <TabBar c={c} />
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

const LIT = '#FFFFFF';
const UNLIT = 'rgba(255,255,255,0.3)';
const TERM = '#8FF2E2';
// Keeps `t = 0.3 s` on one line in the browser; native Text never breaks at the no-break spaces.
const NOWRAP = Platform.OS === 'web' ? { whiteSpace: 'nowrap' } : null;

/** One line of the tutor's words; the first `lit` fraction of its words are lit. */
function Line({ text, size, lit }) {
  const toks = tokens(text);
  const count = toks.filter((t) => t.w !== undefined).length;
  const on = lit >= 1 ? count : Math.floor(lit * count + 0.0001);
  let idx = -1;
  return (
    <Text style={{ fontSize: size, fontWeight: '800', lineHeight: Math.round(size * 1.32), textAlign: START, writingDirection: 'rtl', color: UNLIT }}>
      {'‏'}
      {toks.map((t, j) => {
        if (t.sp) return t.sp;
        idx += 1;
        const isOn = idx < on;
        return (
          <Text key={j} style={[{ color: isOn ? (t.term ? TERM : LIT) : UNLIT }, t.term && NOWRAP]}>
            {t.term ? ltr(t.w.replace(/ /g, ' ')) : t.w}
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

function AskLines({ p, size }) {
  const a = p.step.ask;
  const [hint, setHint] = useState(false);
  const answered = p.isAnswered;
  const right = p.pickedRight;
  return (
    <View>
      <Speaking text={a.question} size={size} runKey={'q' + p.playKey} ms={readingMs(a.question) * 0.6} />
      <View style={{ gap: 10, marginTop: 18 }}>
        {a.options.map((o) => {
          const isAnswer = o.id === a.answerID;
          const isPick = o.id === p.picked;
          let bg = 'rgba(255,255,255,0.12)';
          let fg = '#FFFFFF';
          let mark = null;
          if (answered && isAnswer) {
            bg = '#30D158';
            fg = '#00210A';
            mark = 'check';
          } else if (answered && isPick) {
            bg = 'rgba(255,69,58,0.9)';
            mark = 'x';
          }
          return (
            <Pressable
              key={o.id}
              disabled={answered}
              onPress={() => p.pick(o.id)}
              style={({ pressed }) => ({ height: 56, borderRadius: 16, backgroundColor: bg, paddingHorizontal: 18, flexDirection: 'row', alignItems: 'center', opacity: answered && !isAnswer && !isPick ? 0.35 : pressed ? 0.7 : 1 })}
            >
              <T size={20} w="700" color={fg} style={{ flex: 1 }}>
                {ltr(o.label)}
              </T>
              {mark && <Icon name={mark} size={20} color={fg} />}
            </Pressable>
          );
        })}
      </View>
      {!answered && (
        <View style={{ flexDirection: 'row', gap: 22, marginTop: 16 }}>
          <Pressable onPress={() => setHint(true)} hitSlop={8}>
            <T size={15} w="600" color="rgba(255,255,255,0.65)">
              تلميح
            </T>
          </Pressable>
          <Pressable onPress={p.showAnswer} hitSlop={8}>
            <T size={15} w="600" color="rgba(255,255,255,0.65)">
              ما أدري، وريني
            </T>
          </Pressable>
        </View>
      )}
      {hint && !answered && (
        <View style={{ marginTop: 14 }}>
          <Speaking text={a.hint} size={size * 0.62} runKey={'h' + p.playKey} ms={readingMs(a.hint) * 0.7} />
        </View>
      )}
      {answered && (
        <View style={{ marginTop: 22 }}>
          <T size={17} w="700" color={right ? '#30D158' : '#FF9F0A'}>
            {right ? 'صح.' : p.picked ? 'مو هذا. شوف ليش:' : 'هذا الجواب، وليش:'}
          </T>
          <View style={{ marginTop: 6 }}>
            <Speaking text={a.why} size={size * 0.72} runKey={'w' + p.playKey + p.picked} ms={readingMs(a.why) * 0.7} />
          </View>
          <Pressable
            onPress={() => {
              haptic('light');
              p.next();
            }}
            style={({ pressed }) => ({ alignSelf: 'flex-start', marginTop: 20, height: 50, paddingHorizontal: 28, borderRadius: 25, backgroundColor: '#FFFFFF', justifyContent: 'center', opacity: pressed ? 0.8 : 1 })}
          >
            <T size={17} w="700" color="#000000">
              متابعة
            </T>
          </Pressable>
        </View>
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
            <Pressable
              key={k}
              onPress={() => {
                haptic('light');
                p.go(k);
              }}
              style={({ pressed }) => ({ opacity: pressed ? 0.75 : 0.42, marginBottom: size * 0.9 })}
            >
              {s.ask ? <Line text={s.ask.question} size={size} lit={1} /> : s.caption.map((ph, j) => <Line key={j} text={ph} size={size} lit={1} />)}
            </Pressable>
          );
        }
        return (
          <View key={k} onLayout={(e) => setY(e.nativeEvent.layout.y)} style={{ marginBottom: size }}>
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
          </View>
        );
      })}
    </ScrollView>
  );
}

/** Steps as a track: drag across it or tap to move; the question steps are marked above it. */
function Scrubber({ p, width }) {
  const { step, n, i } = p;
  const within = step.ask ? (p.isAnswered ? 1 : 0.5) : step.caption.length ? p.revealed / step.caption.length : 1;
  const f = (i + within) / n;
  const scrub = useScrub({ count: n, spacing: width / n, axis: 'x', current: i, onIndex: p.go, reverse: true });
  return (
    <View {...scrub.panHandlers} style={{ width, paddingVertical: 10 }}>
      <View style={{ height: 6 }}>
        {p.page.steps.map((s, k) =>
          s.ask ? <View key={k} style={{ position: 'absolute', right: ((k + 0.5) / n) * width - 2.5, top: 0, width: 5, height: 5, borderRadius: 3, backgroundColor: TERM }} /> : null
        )}
      </View>
      <View style={{ height: 5, borderRadius: 3, backgroundColor: 'rgba(255,255,255,0.22)', marginTop: 3 }}>
        <View style={{ position: 'absolute', right: 0, top: 0, bottom: 0, width: f * width, borderRadius: 3, backgroundColor: 'rgba(255,255,255,0.9)' }} />
      </View>
      <View style={{ flexDirection: 'row', justifyContent: 'space-between', marginTop: 6 }}>
        <T size={12} w="600" color="rgba(255,255,255,0.55)">
          {`الخطوة ${ar(i + 1)}`}
        </T>
        <T size={12} w="600" color="rgba(255,255,255,0.55)">
          {`من ${ar(n)}`}
        </T>
      </View>
    </View>
  );
}

function Transport({ p, width, big = 46 }) {
  const press = (fn) => () => {
    haptic('light');
    fn();
  };
  return (
    <View style={{ width }}>
      <Scrubber p={p} width={width} />
      <View style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'space-evenly', marginTop: 6 }}>
        <Pressable onPress={press(p.previous)} disabled={p.isFirst} hitSlop={12} style={{ opacity: p.isFirst ? 0.3 : 1 }}>
          <Glyph name="fwd" size={big * 0.75} />
        </Pressable>
        <Pressable onPress={press(p.toggleAuto)} hitSlop={12}>
          <Glyph name={p.auto ? 'pause' : 'play'} size={big} />
        </Pressable>
        <Pressable onPress={press(p.next)} disabled={p.isLast} hitSlop={12} style={{ opacity: p.isLast ? 0.3 : 1 }}>
          <Glyph name="fwd" flip size={big * 0.75} />
        </Pressable>
      </View>
      <View style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginTop: 14 }}>
        <Pressable onPress={press(p.cycleSpeed)} hitSlop={8} style={{ paddingHorizontal: 10, height: 26, borderRadius: 13, backgroundColor: 'rgba(255,255,255,0.14)', justifyContent: 'center' }}>
          <T size={13} w="700" color="rgba(255,255,255,0.8)">
            {ltr(p.speed + '×')}
          </T>
        </Pressable>
        <Pressable onPress={press(p.replay)} hitSlop={8}>
          <Icon name="rotate-ccw" size={19} color="rgba(255,255,255,0.75)" />
        </Pressable>
      </View>
    </View>
  );
}

function Backdrop() {
  return (
    <Svg style={StyleSheet.absoluteFill} width="100%" height="100%">
      <Defs>
        <LinearGradient id="np" x1="0" y1="0" x2="0.4" y2="1">
          <Stop offset="0" stopColor="#1A4A46" />
          <Stop offset="0.55" stopColor="#0C2321" />
          <Stop offset="1" stopColor="#060D0C" />
        </LinearGradient>
      </Defs>
      <Rect width="100%" height="100%" fill="url(#np)" />
    </Svg>
  );
}

function RoundButton({ icon, onPress }) {
  return (
    <Pressable onPress={onPress} hitSlop={8} style={({ pressed }) => ({ width: 34, height: 34, borderRadius: 17, backgroundColor: 'rgba(255,255,255,0.14)', alignItems: 'center', justifyContent: 'center', opacity: pressed ? 0.7 : 1 })}>
      <Icon name={icon} size={18} color="#FFFFFF" />
    </Pressable>
  );
}

function Player({ wide, onBack }) {
  const p = usePlayer(sinePage);
  const [area, onArea] = useSize();
  const inkFor = (k) => (p.page.steps[k].ask ? ASK_PEN : PEN);
  // Once a question is answered, the slide shows where the answer was.
  const overlay = ({ tip }) => (
    <>
      {tip.drawing && <Circle cx={tip.x} cy={tip.y} r={6} fill={inkFor(p.i)} />}
      {p.step.ask && p.isAnswered && <Circle cx={ANSWER_AT[0]} cy={ANSWER_AT[1]} r={13} fill="none" stroke="#1FA34A" strokeWidth={4} />}
    </>
  );

  const top = (
    <View style={{ height: 58, flexDirection: 'row', alignItems: 'center', paddingHorizontal: 18, gap: 12 }}>
      <RoundButton icon="chevron-down" onPress={onBack} />
      <View style={{ flex: 1, alignItems: 'center' }}>
        <T size={15} w="700" color="#FFFFFF" align="center" numberOfLines={1}>
          {current.ar}
        </T>
        <T size={12} color="rgba(255,255,255,0.6)" align="center" numberOfLines={1}>
          {`المحاضرة ${ORDINAL[current.n - 1]} · صفحة ${ar(current.page)}`}
        </T>
      </View>
      <RoundButton icon="more-horizontal" />
    </View>
  );

  let body = null;
  if (area) {
    if (wide) {
      const colW = Math.min(area.w * 0.54, ((area.h - 250) * 4) / 3);
      body = (
        <View style={{ flex: 1, flexDirection: 'row', paddingHorizontal: 40 }}>
          <View style={{ width: colW, justifyContent: 'center' }}>
            <View style={{ borderRadius: 14, shadowColor: '#000', shadowOpacity: 0.45, shadowRadius: 30, shadowOffset: { width: 0, height: 16 } }}>
              <InkSlide p={p} width={colW} inkFor={inkFor} pastOpacity={0.32} onJump={p.go} overlay={overlay} radius={14} />
            </View>
            <View style={{ marginTop: 22 }}>
              <T size={19} w="700" color="#FFFFFF" numberOfLines={1}>
                {sinePage.title}
              </T>
              <T size={15} color="rgba(255,255,255,0.6)" numberOfLines={1}>
                {ltr(sinePage.deckTitle)}
              </T>
            </View>
            <View style={{ marginTop: 6 }}>
              <Transport p={p} width={colW} />
            </View>
          </View>
          <View style={{ flex: 1, marginRight: 56 }}>
            <Lyrics p={p} size={Math.min(34, Math.max(26, area.w / 34))} padTop={area.h * 0.12} padBottom={area.h * 0.6} />
          </View>
        </View>
      );
    } else {
      const sw = area.w - 32;
      body = (
        <View style={{ flex: 1, paddingHorizontal: 16 }}>
          <View style={{ borderRadius: 10, overflow: 'hidden' }}>
            <InkSlide p={p} width={sw} inkFor={inkFor} pastOpacity={0.32} onJump={p.go} overlay={overlay} radius={10} />
          </View>
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
    <View style={{ flex: 1, backgroundColor: '#060D0C' }}>
      <Backdrop />
      {top}
      <View style={{ flex: 1 }} onLayout={onArea}>
        {body}
      </View>
    </View>
  );
}

export function NativeApp({ wide }) {
  const [route, setRoute] = useState('home');
  return route === 'player' ? <Player wide={wide} onBack={() => setRoute('home')} /> : <Home wide={wide} onOpen={() => setRoute('player')} />;
}

export const native = {
  key: 'native',
  name: 'الأصلي',
  line: 'بدون استعارة مخترعة: أنماط iPadOS نفسها. السلايد هو الغلاف، والشرح يمشي جنبه مثل كلمات Apple Music، كلمة كلمة.',
  refs: 'Apple Music · Apple Podcasts · Apple Books · Speak · Brilliant · Photomath',
  swatches: ['#0C2321', '#FFFFFF', '#0A8F86', '#F2F2F7', '#000000'],
  App: NativeApp,
};
