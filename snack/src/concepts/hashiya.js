// «الحاشية»: the lecture as a page of a classical study book. The slide is the matn in the middle
// of the page; the tutor's explanation grows in the margin beside it as a sharh, each gloss tied to
// its ink by a fine line, numbered in the colour of that step's pen. Afterwards the margin is
// your notes. Paper and ink, but typographic, not props.
import React, { useState } from 'react';
import { Pressable, ScrollView, View } from 'react-native';
import Svg, { Circle, Path } from 'react-native-svg';
import { S, T, isDark, ltr } from '../theme';
import { BACK, FORWARD, Icon } from '../controls';
import { useSize } from '../ui';
import { LogoMark } from '../logo';
import { Ringed } from '../pen';
import { SlideStage } from '../slide';
import { usePlayer } from '../player';
import { reviewItems, sinePage } from '../data';
import { Appear, FONTS, Glossed, InkSlide, Underlined, ar, stepAnchor } from './engine';
import { LECTURES, ORDINAL } from './mock';

const pal = () =>
  isDark()
    ? {
        bg: '#15120E',
        page: '#1C1814',
        ink: '#EFE6D6',
        ink2: '#B8AB95',
        ink3: '#7C7161',
        rule: 'rgba(239,230,214,0.14)',
        red: '#F0704F',
        student: '#8EA7EE',
      }
    : {
        bg: '#F1EBDF',
        page: '#F7F3EB',
        ink: '#1B1712',
        ink2: '#5E554A',
        ink3: '#9A8F7F',
        rule: 'rgba(27,23,18,0.14)',
        red: '#C1351B',
        student: '#2A4C9E',
      };

// Each step's pen, as it sits on the white slide and as it reads in the margin.
const INKS = [
  { slide: '#C1351B', light: '#B3301A', dark: '#F28466' },
  { slide: '#1F57A8', light: '#1F57A8', dark: '#8DAEF0' },
  { slide: '#2B7A4B', light: '#28704A', dark: '#7CCB9D' },
  { slide: '#A66A06', light: '#946005', dark: '#E5B65E' },
  { slide: '#7A3A9E', light: '#73379A', dark: '#C9A0E4' },
];
const slideInk = (i) => INKS[i % INKS.length].slide;
const marginInk = (i) => INKS[i % INKS.length][isDark() ? 'dark' : 'light'];

const naskh = FONTS.naskh;

// MARK: Shared

function RunningHead({ c, right, center, left }) {
  return (
    <View style={{ height: 54, flexDirection: 'row', alignItems: 'center', paddingHorizontal: 22, borderBottomWidth: 1, borderBottomColor: c.rule }}>
      <View style={{ flex: 1, alignItems: 'flex-start' }}>{right}</View>
      <View style={{ flexShrink: 1 }}>{center}</View>
      <View style={{ flex: 1, alignItems: 'flex-end' }}>{left}</View>
    </View>
  );
}

function Label({ c, children, style }) {
  return (
    <T size={12} w="700" color={c.ink3} style={[{ letterSpacing: 1.5 }, style]}>
      {children}
    </T>
  );
}

// MARK: Player

/** One gloss in the margin: the step's numeral in its pen colour, and its words. */
function Gloss({ c, idx, current, size, onPress, onLayout, children }) {
  return (
    <Pressable onPress={onPress} disabled={current} onLayout={onLayout} style={{ flexDirection: 'row', paddingVertical: current ? 10 : 5 }}>
      <T size={current ? 34 : 20} w="300" color={marginInk(idx)} lh={current ? 40 : 26} style={{ width: current ? 40 : 30, fontFamily: naskh }}>
        {ar(idx + 1)}
      </T>
      <View style={{ flex: 1, paddingTop: current ? 4 : 0 }}>{children}</View>
    </Pressable>
  );
}

function PastLine({ c, step, idx }) {
  const text = step.ask ? step.ask.question : step.caption.join('، ');
  return <Glossed text={text} size={15} color={c.ink2} term={marginInk(idx)} font={naskh} lh={26} numberOfLines={1} />;
}

function AskGloss({ c, p, size }) {
  const a = p.step.ask;
  const [hint, setHint] = useState(false);
  const letters = ['أ', 'ب', 'ج', 'د'];
  return (
    <View>
      <Glossed text={a.question} size={size + 1} w="600" color={c.ink} term={marginInk(p.i)} font={naskh} lh={Math.round(size * 1.8)} />
      <T size={13} color={c.ink3} style={{ marginTop: 2 }}>
        {p.isAnswered ? ' ' : 'قبل ما أكمل: وش تتوقع؟'}
      </T>
      <View style={{ marginTop: 8 }}>
        {a.options.map((o, k) => {
          const chosen = p.picked === o.id;
          const right = o.id === a.answerID;
          const ring = p.isAnswered && (right || chosen) ? (right ? c.red : c.student) : null;
          return (
            <Pressable key={o.id} onPress={() => p.pick(o.id)} disabled={p.isAnswered} style={{ flexDirection: 'row', alignItems: 'center', paddingVertical: 8 }}>
              <T size={size} w="700" color={c.ink2} style={{ width: 30, fontFamily: naskh }}>
                {letters[k] + ')'}
              </T>
              <Ringed progress={ring ? 1 : 0} color={ring} padX={12} padY={5}>
                <S size={size + 1} color={chosen && !right ? c.ink3 : c.ink} style={chosen && !right ? { textDecorationLine: 'line-through' } : null}>
                  {ltr(o.label)}
                </S>
              </Ringed>
            </Pressable>
          );
        })}
      </View>
      {!p.isAnswered && (
        <Pressable onPress={() => setHint(!hint)} style={{ alignSelf: 'flex-start', marginTop: 6 }}>
          <T size={14} w="600" color={c.red}>
            {hint ? 'أخفِ التلميح' : 'تلميح'}
          </T>
        </Pressable>
      )}
      {hint && !p.isAnswered && <Glossed text={a.hint} size={size - 2} color={c.ink2} term={marginInk(p.i)} font={naskh} lh={Math.round(size * 1.7)} style={{ marginTop: 6 }} />}
      {p.isAnswered && (
        <Appear style={{ marginTop: 10, borderTopWidth: 1, borderTopColor: c.rule, paddingTop: 10 }}>
          <Glossed
            text={(p.pickedRight ? 'صح. ' : 'لا، ') + a.why}
            size={size - 1}
            color={c.ink}
            term={c.red}
            font={naskh}
            lh={Math.round(size * 1.75)}
          />
        </Appear>
      )}
    </View>
  );
}

function Controls({ c, p, size = 16 }) {
  const locked = p.step.ask && !p.isAnswered;
  return (
    <View style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' }}>
      <Pressable onPress={p.next} disabled={locked || p.isLast} style={{ flexDirection: 'row', alignItems: 'center', opacity: p.isLast ? 0.35 : 1 }}>
        {locked ? (
          <T size={size} w="600" color={c.ink3}>
            اختر جواباً أولاً
          </T>
        ) : (
          <Underlined color={c.red}>
            <T size={size + 1} w="700" color={c.red}>
              الخطوة التالية
            </T>
          </Underlined>
        )}
        {!locked && <Icon name={FORWARD} size={size} color={c.red} style={{ marginHorizontal: 8 }} />}
      </Pressable>
      <View style={{ flexDirection: 'row', alignItems: 'center' }}>
        <Pressable onPress={p.replay} hitSlop={8} style={{ paddingHorizontal: 10 }}>
          <T size={size - 1} color={c.ink2}>
            أعِد
          </T>
        </Pressable>
        <Pressable onPress={p.previous} disabled={p.isFirst} hitSlop={8} style={{ paddingHorizontal: 10, opacity: p.isFirst ? 0.35 : 1 }}>
          <T size={size - 1} color={c.ink2}>
            السابقة
          </T>
        </Pressable>
        <Pressable onPress={p.toggleAuto} hitSlop={8} style={{ paddingHorizontal: 10 }}>
          <T size={size - 1} w={p.auto ? '700' : '400'} color={p.auto ? c.red : c.ink2}>
            {p.auto ? 'تلقائي ✓' : 'تلقائي'}
          </T>
        </Pressable>
      </View>
    </View>
  );
}

/** The steps as a row of pen strokes, one per step in its colour; the current one stands tall. */
function StepRule({ c, p }) {
  return (
    <View style={{ flexDirection: 'row', alignItems: 'flex-end', justifyContent: 'center', direction: 'rtl' }}>
      {p.page.steps.map((s, k) => {
        const on = k === p.i;
        return (
          <Pressable key={k} onPress={() => p.go(k)} hitSlop={6} style={{ alignItems: 'center', width: 26 }}>
            <View style={{ width: on ? 3 : 2, height: on ? 24 : s.ask ? 16 : 12, borderRadius: 2, backgroundColor: k <= p.i ? slideInk(k) : c.rule }} />
            <T size={11} w={on ? '700' : '400'} color={on ? marginInk(k) : c.ink3} align="center" style={{ marginTop: 4 }}>
              {ar(k + 1)}
            </T>
          </Pressable>
        );
      })}
    </View>
  );
}

function Player({ wide, onBack }) {
  const c = pal();
  const p = usePlayer(sinePage);
  const [area, onArea] = useSize();
  const [listY, setListY] = useState(0);
  const [entryY, setEntryY] = useState(null);

  const steps = p.page.steps.slice(0, p.i + 1);
  const hidden = Math.max(0, p.i - 5);
  const glossSize = wide ? 19 : 18;

  const current = (
    <>
      {p.step.ask ? (
        <AskGloss key={p.playKey} c={c} p={p} size={glossSize} />
      ) : (
        p.step.caption.map((ph, k) => (
          <Appear key={p.playKey + '-' + k} on={k < p.revealed}>
            <Glossed text={ph} size={glossSize} color={c.ink} term={marginInk(p.i)} font={naskh} lh={Math.round(glossSize * 1.85)} />
          </Appear>
        ))
      )}
    </>
  );

  const glosses = (onEntry) => (
    <>
      {hidden > 0 && (
        <T size={13} color={c.ink3} style={{ marginBottom: 4 }}>
          {`… و${ar(hidden)} حواشٍ قبلها`}
        </T>
      )}
      {steps.map((s, k) =>
        k < hidden ? null : (
          <Gloss key={k} c={c} idx={k} current={k === p.i} onPress={() => p.go(k)} onLayout={k === p.i ? onEntry : undefined}>
            {k === p.i ? current : <PastLine c={c} step={s} idx={k} />}
          </Gloss>
        )
      )}
    </>
  );

  const head = (
    <RunningHead
      c={c}
      right={
        <Pressable onPress={onBack} style={{ flexDirection: 'row', alignItems: 'center' }} hitSlop={8}>
          <Icon name={BACK} size={16} color={c.ink2} />
          <T size={14} color={c.ink2} style={{ marginHorizontal: 4 }}>
            الفهرس
          </T>
        </Pressable>
      }
      center={
        <T size={wide ? 15 : 13} w="600" color={c.ink} numberOfLines={1} style={{ fontFamily: naskh }}>
          {wide ? 'المحاضرة الخامسة · الموجات الجيبية' : 'الموجات الجيبية'}
        </T>
      }
      left={
        <T size={14} color={c.ink3} style={{ fontFamily: naskh }}>
          {`ص ${ar(p.page.id)}`}
        </T>
      }
    />
  );

  if (!wide) {
    return (
      <View style={{ flex: 1, backgroundColor: c.bg }}>
        {head}
        <ScrollView contentContainerStyle={{ padding: 16, paddingBottom: 30 }}>
          <View onLayout={onArea} style={{ borderWidth: 1, borderColor: c.rule, padding: 6, backgroundColor: c.page }}>
            {area && <InkSlide p={p} width={area.w - 14} inkFor={slideInk} onJump={p.go} />}
          </View>
          <View style={{ marginTop: 14 }}>
            <StepRule c={c} p={p} />
          </View>
          <View style={{ marginTop: 16, borderTopWidth: 1, borderTopColor: c.rule, paddingTop: 8 }}>
            <Label c={c}>الحاشية</Label>
            {glosses()}
          </View>
        </ScrollView>
        <View style={{ paddingHorizontal: 16, paddingVertical: 12, borderTopWidth: 1, borderTopColor: c.rule, backgroundColor: c.bg }}>
          <Controls c={c} p={p} size={15} />
        </View>
      </View>
    );
  }

  // Wide: the slide is the matn, the margin runs down the reading-start side.
  let layout = null;
  if (area) {
    const pad = 28;
    const marginW = Math.max(300, Math.min(380, area.w * 0.3));
    const gap = 48;
    const avail = area.w - marginW - gap - pad * 2;
    const sw = Math.max(240, Math.min(avail, (area.h - 110) * (4 / 3)));
    const sh = sw * 0.75;
    const sx = pad + (avail - sw) / 2;
    const sy = Math.max(24, (area.h - sh - 70) / 2);
    const s = sw / p.page.width;
    const anchor = stepAnchor(p.step);
    const marginX = area.w - pad - marginW;
    const showLine = entryY !== null && (p.revealed > 0 || p.step.ask);
    const y0 = listY + entryY + 26;
    const ax = sx + anchor[0] * s;
    const ay = sy + anchor[1] * s;
    const col = slideInk(p.i);
    layout = (
      <>
        <View style={{ position: 'absolute', left: sx - 8, top: sy - 8, padding: 7, borderWidth: 1, borderColor: c.rule, backgroundColor: c.page }}>
          <InkSlide p={p} width={sw} inkFor={slideInk} onJump={p.go} />
        </View>
        <View style={{ position: 'absolute', left: sx, top: sy + sh + 22, width: sw }}>
          <StepRule c={c} p={p} />
        </View>
        <View style={{ position: 'absolute', left: marginX, top: 0, bottom: 0, width: marginW, paddingTop: 22, paddingBottom: 20, borderLeftWidth: 1, borderLeftColor: c.rule, paddingLeft: 22 }}>
          <Label c={c}>الحاشية</Label>
          <View style={{ flex: 1, marginTop: 8 }} onLayout={(e) => setListY(e.nativeEvent.layout.y)}>
            {glosses((e) => setEntryY(e.nativeEvent.layout.y))}
          </View>
          <Controls c={c} p={p} />
        </View>
        {showLine && (
          <Svg pointerEvents="none" width={area.w} height={area.h} style={{ position: 'absolute', left: 0, top: 0 }}>
            <Path
              d={`M${marginX + 14} ${y0} C${marginX - 50} ${y0}, ${ax + 70} ${ay}, ${ax} ${ay}`}
              stroke={col}
              strokeOpacity={0.75}
              strokeWidth={1.6}
              strokeDasharray="1 5"
              strokeLinecap="round"
              fill="none"
            />
            <Circle cx={ax} cy={ay} r={3.5} fill={col} />
            <Circle cx={marginX + 14} cy={y0} r={2.5} fill={col} />
          </Svg>
        )}
      </>
    );
  }
  return (
    <View style={{ flex: 1, backgroundColor: c.bg }}>
      {head}
      <View style={{ flex: 1 }} onLayout={onArea}>
        {layout}
      </View>
    </View>
  );
}

// MARK: Home, the index

function LectureRow({ c, l, onOpen }) {
  const done = l.done >= 1;
  const tone = l.current ? c.red : done ? c.ink : c.ink3;
  return (
    <Pressable onPress={l.current ? onOpen : undefined} style={{ flexDirection: 'row', alignItems: 'flex-start', paddingVertical: 14, borderBottomWidth: 1, borderBottomColor: c.rule }}>
      <T size={40} w="300" color={tone} lh={46} style={{ width: 54, fontFamily: naskh }}>
        {ar(l.n)}
      </T>
      <View style={{ flex: 1 }}>
        <View style={{ flexDirection: 'row', alignItems: 'flex-end' }}>
          <T size={20} w={l.current ? '700' : '500'} color={l.preparing ? c.ink3 : c.ink} style={{ fontFamily: naskh }}>
            {l.ar}
          </T>
          <View style={{ flex: 1, borderBottomWidth: 1.5, borderStyle: 'dotted', borderBottomColor: c.rule, marginHorizontal: 10, marginBottom: 7 }} />
          <T size={14} color={c.ink3} style={{ fontFamily: naskh }}>
            {l.preparing ? `يُحضَّر · ${ar(Math.round(l.preparing * 100))}٪` : `${ar(l.pages)} ص`}
          </T>
        </View>
        <S size={13} italic color={c.ink3} style={{ marginTop: 1 }}>
          {l.en}
        </S>
        {/* One tick per page; the read ones in ink, where you stopped in red. */}
        <View style={{ flexDirection: 'row', flexWrap: 'wrap', marginTop: 8 }}>
          {Array.from({ length: l.pages }, (_, k) => {
            const read = k < Math.round(l.pages * l.done);
            const here = l.current && k === l.page - 1;
            return (
              <View
                key={k}
                style={{ width: 2, height: here ? 12 : 7, marginLeft: 3, borderRadius: 1, backgroundColor: here ? c.red : read ? c.ink2 : c.rule }}
              />
            );
          })}
        </View>
      </View>
    </Pressable>
  );
}

function MarginNotes({ c }) {
  return (
    <View>
      <Label c={c}>حواشيك · ما أخطأت فيه</Label>
      {reviewItems.slice(0, 4).map((r, k) => (
        <View key={r.id} style={{ flexDirection: 'row', paddingVertical: 12, borderBottomWidth: k < 3 ? 1 : 0, borderBottomColor: c.rule }}>
          <T size={20} w="300" color={c.red} lh={26} style={{ width: 26, fontFamily: naskh }}>
            {ar(k + 1)}
          </T>
          <View style={{ flex: 1 }}>
            <Glossed text={r.question} size={15} color={c.ink} term={c.ink} font={naskh} lh={25} />
            <View style={{ flexDirection: 'row', flexWrap: 'wrap', alignItems: 'center', marginTop: 4 }}>
              <T size={13} color={c.ink3}>
                {'قلت '}
              </T>
              <S size={14} color={c.ink3} style={{ textDecorationLine: 'line-through' }}>
                {ltr(r.yours)}
              </S>
              <T size={13} color={c.ink3}>
                {'  والصواب '}
              </T>
              <S size={14} w="700" color={c.red}>
                {ltr(r.correct)}
              </S>
            </View>
            <T size={12} color={c.ink3} style={{ marginTop: 3 }}>
              {`المحاضرة ${ar(r.lecture)} · ص ${ar(r.page)}`}
            </T>
          </View>
        </View>
      ))}
      <Pressable style={{ marginTop: 14, alignSelf: 'flex-start' }}>
        <Underlined color={c.red}>
          <T size={15} w="700" color={c.red}>
            {`راجع الحواشي السبع`}
          </T>
        </Underlined>
      </Pressable>
    </View>
  );
}

function Home({ wide, onOpen }) {
  const c = pal();
  const step = sinePage.steps[4];
  const resumeBlock = (
    <View style={{ flexDirection: wide ? 'row' : 'column', marginTop: 26, paddingVertical: 20, borderTopWidth: 1, borderBottomWidth: 1, borderColor: c.rule }}>
      <View style={{ flex: 1 }}>
        <Label c={c}>وقفتَ هنا</Label>
        <T size={wide ? 22 : 19} color={c.ink} lh={wide ? 40 : 34} style={{ fontFamily: naskh, marginTop: 6 }}>
          {`في المحاضرة الخامسة، عند الصفحة ${ar(16)}، الخطوة ${ar(5)} من ${ar(9)}: قراءة القيمة اللحظية من الرسم.`}
        </T>
        <Pressable onPress={onOpen} style={{ flexDirection: 'row', alignItems: 'center', marginTop: 14, alignSelf: 'flex-start' }}>
          <Underlined color={c.red}>
            <T size={17} w="700" color={c.red}>
              أكمل من هنا
            </T>
          </Underlined>
          <Icon name={FORWARD} size={16} color={c.red} style={{ marginHorizontal: 8 }} />
        </Pressable>
      </View>
      <Pressable onPress={onOpen} style={{ marginTop: wide ? 0 : 16, marginRight: wide ? 24 : 0, alignSelf: wide ? 'center' : 'stretch' }}>
        <View style={{ padding: 5, borderWidth: 1, borderColor: c.rule, backgroundColor: c.page, alignSelf: 'flex-start' }}>
          <SlideStage page={sinePage} width={wide ? 230 : 200} marks={step.marks} />
        </View>
      </Pressable>
    </View>
  );

  const main = (
    <View>
      <S size={13} color={c.ink3} style={{ letterSpacing: 3 }}>
        EE207
      </S>
      <T size={wide ? 54 : 40} w="700" color={c.ink} lh={wide ? 76 : 58} style={{ fontFamily: naskh, marginTop: 4 }}>
        الدوائر الكهربائية
      </T>
      <T size={16} color={c.ink2} style={{ fontFamily: naskh }}>
        مقرّرك كما يشرحه لك مُعيد، صفحةً صفحة.
      </T>
      {resumeBlock}
      <View style={{ marginTop: 28 }}>
        <Label c={c}>الفهرس</Label>
        {LECTURES.map((l) => (
          <LectureRow key={l.n} c={c} l={l} onOpen={onOpen} />
        ))}
        <Pressable style={{ marginTop: 16, alignSelf: 'flex-start' }}>
          <T size={15} w="600" color={c.ink2}>
            + أضف محاضرة
          </T>
        </Pressable>
      </View>
    </View>
  );

  return (
    <View style={{ flex: 1, backgroundColor: c.bg }}>
      <RunningHead
        c={c}
        right={
          <View style={{ flexDirection: 'row', alignItems: 'center' }}>
            <LogoMark size={26} />
            <T size={17} w="700" color={c.ink} style={{ marginHorizontal: 8, fontFamily: naskh }}>
              مُعيد
            </T>
          </View>
        }
        center={null}
        left={
          <T size={13} color={c.ink3} style={{ fontFamily: naskh }}>
            الفصل الأول
          </T>
        }
      />
      <ScrollView contentContainerStyle={{ paddingHorizontal: wide ? 48 : 18, paddingTop: wide ? 40 : 24, paddingBottom: 48 }}>
        {wide ? (
          <View style={{ flexDirection: 'row', alignItems: 'flex-start', maxWidth: 1100, width: '100%', alignSelf: 'center' }}>
            <View style={{ flex: 1 }}>{main}</View>
            <View style={{ width: 300, marginRight: 40, paddingRight: 28, borderRightWidth: 1, borderRightColor: c.rule }}>
              <MarginNotes c={c} />
            </View>
          </View>
        ) : (
          <View>
            {main}
            <View style={{ marginTop: 34 }}>
              <MarginNotes c={c} />
            </View>
          </View>
        )}
      </ScrollView>
    </View>
  );
}

export function HashiyaApp({ wide }) {
  const [route, setRoute] = useState('home');
  return route === 'player' ? <Player wide={wide} onBack={() => setRoute('home')} /> : <Home wide={wide} onOpen={() => setRoute('player')} />;
}

export const hashiya = {
  key: 'hashiya',
  name: 'الحاشية',
  line: 'الشريحة متنٌ في وسط الصفحة، والشرح يكبر في الهامش جنبها، كل حاشية مربوطة بحبرها.',
  refs: 'كتب الشروح والحواشي · Ciechanowski · ثمانية',
  swatches: ['#F1EBDF', '#1B1712', '#C1351B', '#1F57A8', '#2B7A4B'],
  App: HashiyaApp,
};
