// One slide, explained step by step: the tutor's pen on the printed page, its words streaming in
// beside it like an assistant's reply, and a question before each reveal.
import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { Animated, Pressable, ScrollView, StyleSheet, View } from 'react-native';
import { C, R, Rich, S, T, clamp01, easeInOut, inkTotal, lift, ltr, readingMs, me } from './theme';
import { explainAnswer, explainSelection } from './data';
import { Ringed } from './pen';
import { BACK, Button, Chip, Composer, FORWARD, Icon, IconButton, Toggle, haptic } from './controls';
import { Card, Pill, TutorMessage, slideFrame, useSize } from './ui';
import { CaptionCard, RegionCrop, SlideStage, useClock } from './slide';

// MARK: Model

/** Which step is showing, how much is drawn and said, and the predict-before-reveal answer. */
export function usePlayer(page) {
  const n = page.steps.length;
  const [i, setI] = useState(0);
  const [playKey, setPlayKey] = useState(1);
  const [revealed, setRevealed] = useState(0);
  const [auto, setAuto] = useState(false);
  const [speed, setSpeed] = useState(1);
  const [picked, setPicked] = useState(null);
  const [shown, setShown] = useState(false);
  const [showInk, setShowInk] = useState(true);
  const [showText, setShowText] = useState(true);
  const step = page.steps[i];
  const autoRef = useRef(auto);
  autoRef.current = auto;
  const speedRef = useRef(speed);
  speedRef.current = speed;

  const go = useCallback(
    (idx) => {
      if (idx < 0 || idx >= n) return;
      setI(idx);
      setPicked(null);
      setShown(false);
      setPlayKey((k) => k + 1);
    },
    [n]
  );

  // Erase the step's ink, redraw it stroke by stroke, and bring the words in at reading pace,
  // starting when the ink is ~60% drawn so words and strokes overlap.
  useEffect(() => {
    setRevealed(0);
    const timers = [];
    let t = 60 + inkTotal(step.marks.length) * 0.6;
    step.caption.forEach((phrase, idx) => {
      timers.push(setTimeout(() => setRevealed(idx + 1), t));
      t += readingMs(phrase) / speedRef.current;
    });
    timers.push(
      setTimeout(() => {
        if (autoRef.current && !step.ask && i < n - 1) go(i + 1);
      }, t)
    );
    return () => timers.forEach(clearTimeout);
  }, [playKey]);

  const pastMarks = useMemo(
    () =>
      page.steps
        .slice(0, i)
        .filter((s) => !s.ask)
        .flatMap((s) => s.marks)
        .filter((m) => m.t !== 'spot'),
    [i]
  );

  const isAnswered = picked !== null || shown;
  return {
    page,
    i,
    n,
    step,
    playKey,
    revealed,
    auto,
    speed,
    picked,
    showInk,
    showText,
    pastMarks,
    isAnswered,
    pickedRight: picked !== null && picked === (step.ask && step.ask.answerID),
    isFirst: i === 0,
    isLast: i === n - 1,
    go,
    next: () => go(i + 1),
    previous: () => go(i - 1),
    replay: () => setPlayKey((k) => k + 1),
    setShowInk,
    setShowText,
    pick: (id) => {
      if (shown) return;
      setPicked(id);
      haptic(id === step.ask.answerID ? 'success' : 'error');
    },
    showAnswer: () => setShown(true),
    toggleAuto: () => {
      const on = !auto;
      setAuto(on);
      if (on && revealed >= step.caption.length && !step.ask && i < n - 1) go(i + 1);
    },
    cycleSpeed: () => {
      const speeds = [1, 1.25, 1.5, 0.75];
      setSpeed(speeds[(speeds.indexOf(speed) + 1) % speeds.length]);
    },
  };
}

// MARK: Screen

export function PlayerScreen({ page, wide, onBack }) {
  const p = usePlayer(page);
  const [explaining, setExplaining] = useState(false);
  const [area, onLayout] = useSize();

  const stage = (width, extra = {}) => (
    <View style={[slideFrame(), lift(1.4)]}>
      <SlideStage page={page} width={width} pastMarks={p.pastMarks} marks={p.step.marks} playKey={p.playKey} animate showInk={p.showInk} {...extra} />
    </View>
  );
  const still = { selection: explainSelection, animate: false, marks: [], pastMarks: [] };
  const caption = { number: p.step.id, phrases: p.step.caption, revealed: p.revealed };

  let content = null;
  if (area && wide) {
    const w = area.w - 56;
    const h = area.h - 24;
    if (explaining || p.step.ask) {
      const panelW = 420;
      const sw = Math.max(200, Math.min(w - panelW - 28, h * (4 / 3)));
      content = (
        <View style={{ flex: 1, flexDirection: 'row' }}>
          <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center' }}>{stage(sw, explaining ? still : {})}</View>
          <View style={{ width: panelW, paddingVertical: 4 }}>
            {explaining ? <ExplainPanel page={page} onDraw={() => setExplaining(false)} wide /> : <AskPanel key={p.playKey} p={p} ask={p.step.ask} wide />}
          </View>
        </View>
      );
    } else {
      // The tutor's message floats on the slide when there's room beside the ink,
      // and sits under the slide when there's spare height.
      const fitW = Math.min(w, h * (4 / 3));
      const spareBelow = h - fitW * 0.75;
      const floating = p.step.placement && fitW >= 600 && spareBelow < 200;
      content = (
        <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center' }}>
          {floating ? (
            stage(fitW, { caption: p.showText ? { ...caption, placement: p.step.placement } : null })
          ) : (
            <View style={{ alignItems: 'center' }}>
              {stage(Math.min(fitW, (h - 170) * (4 / 3)))}
              {p.showText && (
                <View style={{ width: Math.min(fitW, 680), marginTop: 20 }}>
                  <CaptionCard {...caption} />
                </View>
              )}
            </View>
          )}
        </View>
      );
    }
  } else if (area) {
    const sw = area.w - 32;
    content = (
      <ScrollView style={{ flex: 1 }} contentContainerStyle={{ padding: 16, paddingBottom: 28 }}>
        {stage(sw, explaining ? still : {})}
        <View style={{ marginTop: 16 }}>
          {explaining ? (
            <ExplainPanel page={page} onDraw={() => setExplaining(false)} />
          ) : p.step.ask ? (
            <AskPanel key={p.playKey} p={p} ask={p.step.ask} />
          ) : p.showText ? (
            <CaptionCard {...caption} compact />
          ) : null}
        </View>
      </ScrollView>
    );
  }

  return (
    <View style={{ flex: 1, backgroundColor: C.bg }}>
      <TopBar p={p} wide={wide} explaining={explaining} onExplain={() => setExplaining((e) => !e)} onBack={onBack} />
      <View style={{ flex: 1 }} onLayout={onLayout}>
        {wide ? <View style={{ flex: 1, paddingHorizontal: 28, paddingVertical: 12 }}>{content}</View> : content}
      </View>
      <View style={{ alignItems: 'center', paddingHorizontal: wide ? 28 : 10, paddingBottom: wide ? 18 : 10, paddingTop: 4 }}>
        <Controls p={p} wide={wide} />
      </View>
    </View>
  );
}

function TopBar({ p, wide, explaining, onExplain, onBack }) {
  const explain = explaining ? (
    <Button label="رجوع للشرح" icon="x" height={38} size={14} onPress={onExplain} />
  ) : (
    <Button label="اشرح هذا" icon="message-square" kind="secondary" height={38} size={14} onPress={onExplain} />
  );
  const toggles = (
    <View style={{ flexDirection: 'row' }}>
      <Toggle label="الحبر" icon="edit-3" on={p.showInk} onPress={() => p.setShowInk(!p.showInk)} />
      <View style={{ width: 8 }} />
      <Toggle label="النص" icon="align-right" on={p.showText} onPress={() => p.setShowText(!p.showText)} />
    </View>
  );
  const title = (
    <View style={{ flexShrink: 1 }}>
      <T size={wide ? 17 : 16} w="700" numberOfLines={1} lh={24}>
        {p.page.title}
      </T>
      <T size={12.5} color={C.text2} numberOfLines={1} lh={18}>
        {`سلايد ${p.page.id} من ${p.page.deckPageCount} · ${ltr(p.page.deckTitle)}`}
      </T>
    </View>
  );
  if (wide) {
    return (
      <View style={{ flexDirection: 'row', alignItems: 'center', paddingHorizontal: 20, paddingTop: 12, paddingBottom: 8 }}>
        <IconButton name={BACK} label="رجوع" onPress={onBack} />
        <View style={{ width: 8 }} />
        {title}
        <View style={{ flex: 1, minWidth: 12 }} />
        {toggles}
        <View style={{ width: 12 }} />
        {explain}
      </View>
    );
  }
  return (
    <View style={{ paddingHorizontal: 8, paddingTop: 4 }}>
      <View style={{ flexDirection: 'row', alignItems: 'center' }}>
        <IconButton name={BACK} label="رجوع" onPress={onBack} />
        <View style={{ flex: 1, marginHorizontal: 4 }}>{title}</View>
        <IconButton name={explaining ? 'x' : 'message-square'} label={explaining ? 'رجوع للشرح' : 'اشرح هذا'} onPress={onExplain} filled={explaining} />
      </View>
      <View style={{ flexDirection: 'row', marginTop: 6, marginBottom: 2, paddingHorizontal: 8 }}>{toggles}</View>
    </View>
  );
}

// MARK: Controls

/** The step controls, on a floating bar like an assistant's message box. */
function Controls({ p, wide }) {
  const askSteps = p.page.steps.map((s, idx) => (s.ask ? idx : -1)).filter((x) => x >= 0);
  const prev = <IconButton name={BACK} label="الخطوة السابقة" onPress={p.previous} disabled={p.isFirst} />;
  const count = (
    <T size={13.5} w="600" color={C.text2} align="center" style={{ minWidth: 48 }} lh={20}>
      {`${p.i + 1} من ${p.n}`}
    </T>
  );
  const next = (
    <Button
      label="التالي"
      trailIcon={FORWARD}
      height={40}
      size={14.5}
      onPress={p.next}
      disabled={p.isLast || (p.step.ask && !p.isAnswered)}
      style={wide ? null : { flex: 1 }}
    />
  );
  const replay = <IconButton name="rotate-ccw" label="أعد الخطوة" onPress={p.replay} />;
  const auto = <Toggle label="تلقائي" icon={p.auto ? 'pause' : 'play'} on={p.auto} onPress={p.toggleAuto} />;
  const speed = (
    <Pressable
      onPress={p.cycleSpeed}
      accessibilityLabel="السرعة"
      style={{ height: 34, minWidth: 48, paddingHorizontal: 10, borderRadius: R.pill, backgroundColor: C.raised, alignItems: 'center', justifyContent: 'center' }}
    >
      <S size={13.5} w="700" color={C.text2} align="center" lh={18}>
        {`${p.speed}×`}
      </S>
    </Pressable>
  );
  const track = <StepTrack count={p.n} current={p.i} askSteps={askSteps} onSelect={p.go} width={wide ? 220 : undefined} />;
  const gap = (w = 12) => <View style={{ width: w }} />;

  if (wide) {
    return (
      <Card level={1.6} radius={R.pill} style={{ flexDirection: 'row', alignItems: 'center', height: 60, paddingHorizontal: 10 }}>
        {prev}
        {gap(8)}
        {track}
        {gap(8)}
        {count}
        {gap()}
        {next}
        {gap()}
        <View style={{ width: StyleSheet.hairlineWidth * 2, height: 26, backgroundColor: C.lineStrong }} />
        {gap(6)}
        {replay}
        {gap(4)}
        {auto}
        {gap(8)}
        {speed}
        {gap(6)}
      </Card>
    );
  }
  return (
    <Card level={1.4} radius={R.xl} style={{ alignSelf: 'stretch', paddingHorizontal: 10, paddingVertical: 8 }}>
      <View style={{ flexDirection: 'row', alignItems: 'center' }}>
        {prev}
        {gap(6)}
        <View style={{ flex: 1 }}>{track}</View>
        {gap(6)}
        {count}
      </View>
      <View style={{ flexDirection: 'row', alignItems: 'center', marginTop: 6 }}>
        {next}
        {gap(6)}
        {replay}
        {auto}
        {gap(6)}
        {speed}
      </View>
    </Card>
  );
}

/** The steps as segments: done ones filled, the current one in the tutor's colour, a dot over each question. */
function StepTrack({ count, current, askSteps, onSelect, width }) {
  const segments = [];
  for (let idx = 0; idx < count; idx++) {
    const isAsk = askSteps.includes(idx);
    const color = idx === current ? C.accent : idx < current ? C.text2 : C.lineStrong;
    segments.push(
      <Pressable
        key={idx}
        onPress={() => {
          haptic();
          onSelect(idx);
        }}
        accessibilityLabel={`الخطوة ${idx + 1}`}
        style={{ flex: 1, height: 40, justifyContent: 'center', paddingHorizontal: 1.5 }}
      >
        <View style={{ position: 'absolute', top: 7, left: 0, right: 0, alignItems: 'center' }}>
          {isAsk && <View style={{ width: 5, height: 5, borderRadius: 3, backgroundColor: idx <= current ? C.accent : C.text3 }} />}
        </View>
        <View style={{ height: idx === current ? 5 : 4, borderRadius: 3, backgroundColor: color }} />
      </Pressable>
    );
  }
  return <View style={{ width, flexDirection: 'row' }}>{segments}</View>;
}

// MARK: Ask

const LETTERS = ['أ', 'ب', 'ج', 'د', 'هـ'];

/**
 * Predict before the reveal. Your pick is marked in your own blue. A wrong guess is never red:
 * the option shakes once, and the tutor's pen rings the right answer, the way a tutor would on paper.
 */
function AskPanel({ p, ask, wide }) {
  const [hint, setHint] = useState(false);
  const look = (o) => {
    if (!p.isAnswered) return 'open';
    if (o.id === ask.answerID) return p.pickedRight ? 'right' : 'revealed';
    return o.id === p.picked ? 'yourPick' : 'other';
  };

  return (
    <Card style={[{ padding: 20 }, wide && { flex: 1 }]}>
      <View style={{ flexDirection: 'row', alignItems: 'center' }}>
        <Pill label="سؤال توقّع" tone="accent" icon="help-circle" />
        <View style={{ flex: 1 }} />
        <T size={12.5} color={C.text3}>
          قبل لا تكمل
        </T>
      </View>
      <Rich text={ask.question} size={wide ? 22 : 20} w="700" style={{ marginTop: 14 }} />
      <T size={14.5} color={C.text2} style={{ marginTop: 4 }}>
        اختر جوابك، بعدها نكمل الرسم ونشوف.
      </T>

      <View style={{ marginTop: 8 }}>
        {ask.options.map((o, idx) => (
          <OptionRow
            key={o.id}
            letter={LETTERS[idx % LETTERS.length]}
            label={o.label}
            look={look(o)}
            wrongPick={p.picked === o.id && o.id !== ask.answerID}
            disabled={p.isAnswered}
            onPress={() => p.pick(o.id)}
          />
        ))}
      </View>

      {p.isAnswered ? (
        <TutorMessage style={{ marginTop: 18 }} avatar={26}>
          <T size={15} w="700" color={p.pickedRight ? C.green : C.text} lh={22}>
            {p.pickedRight ? 'صح، بالضبط.' : 'مو بالضبط، شوف وين انرسمت الدائرة.'}
          </T>
          <Rich text={ask.why} size={15} color={C.text2} style={{ marginTop: 2 }} />
        </TutorMessage>
      ) : hint ? (
        <TutorMessage style={{ marginTop: 18 }} avatar={26}>
          <Rich text={ask.hint} size={15} color={C.text2} />
        </TutorMessage>
      ) : null}

      {wide ? <View style={{ flex: 1, minHeight: 12 }} /> : <View style={{ height: 18 }} />}

      {p.isAnswered ? (
        <Button label="كمّل الشرح" trailIcon={FORWARD} onPress={p.next} />
      ) : (
        <View style={{ flexDirection: 'row' }}>
          <Button label="اكشف الجواب" kind="secondary" onPress={p.showAnswer} style={{ flex: 1 }} />
          <View style={{ width: 8 }} />
          <Button label="تلميح" icon="help-circle" kind="secondary" onPress={() => setHint((h) => !h)} />
        </View>
      )}
    </Card>
  );
}

function OptionRow({ letter, label, look, wrongPick, disabled, onPress }) {
  const circled = look === 'revealed';
  const t = useClock(circled ? 'on' : 'off', 900, circled);
  const ring = circled ? easeInOut(clamp01((t - 250) / 550)) : 0;

  // A wrong pick shakes once.
  const shake = useRef(new Animated.Value(0)).current;
  useEffect(() => {
    if (!wrongPick) return;
    shake.setValue(0);
    Animated.timing(shake, { toValue: 1, duration: 400, useNativeDriver: true }).start();
  }, [wrongPick]);
  const translateX = shake.interpolate({
    inputRange: [0, 0.125, 0.375, 0.625, 0.875, 1],
    outputRange: [0, 7, -7, 7, -7, 0],
  });

  const tone = {
    open: { border: C.lineStrong, bg: C.surface, dot: C.raised, dotFg: C.text2 },
    yourPick: { border: C.blue, bg: C.blueSoft, dot: C.blue, dotFg: '#FFFFFF' },
    right: { border: C.green, bg: C.greenSoft, dot: C.green, dotFg: '#FFFFFF' },
    revealed: { border: C.lineStrong, bg: C.surface, dot: C.raised, dotFg: C.text2 },
    other: { border: C.line, bg: 'transparent', dot: C.raised, dotFg: C.text3 },
  }[look];

  return (
    <Animated.View style={{ transform: [{ translateX }], marginTop: 10, opacity: look === 'other' ? 0.55 : 1 }}>
      <Pressable onPress={onPress} disabled={disabled}>
        {({ pressed }) => (
          <View
            style={{
              flexDirection: 'row',
              alignItems: 'center',
              minHeight: 58,
              paddingHorizontal: 14,
              borderRadius: R.md,
              borderWidth: look === 'open' ? StyleSheet.hairlineWidth * 2 : 1.5,
              borderColor: tone.border,
              backgroundColor: pressed && look === 'open' ? C.raised : tone.bg,
            }}
          >
            <View style={{ width: 28, height: 28, borderRadius: 14, backgroundColor: tone.dot, alignItems: 'center', justifyContent: 'center' }}>
              <T size={14} w="700" color={tone.dotFg} align="center" lh={18}>
                {letter}
              </T>
            </View>
            <View style={{ width: 14 }} />
            <Ringed progress={ring} padX={8} padY={6} lw={2.4} style={{ paddingHorizontal: 6 }}>
              <S size={20} w="600" color={look === 'other' ? C.text3 : C.text} lh={28}>
                {ltr(label)}
              </S>
            </Ringed>
            <View style={{ flex: 1 }} />
            {look === 'right' && (
              <View style={{ flexDirection: 'row', alignItems: 'center' }}>
                <Icon name="check-circle" size={16} color={C.green} />
                <T size={13} w="700" color={C.green} style={{ marginHorizontal: 5 }}>
                  صح
                </T>
              </View>
            )}
            {look === 'revealed' && (
              <T size={13} w="700" color={C.accent}>
                الصحيح
              </T>
            )}
            {look === 'yourPick' && (
              <T size={13} w="600" color={C.blue}>
                اختيارك
              </T>
            )}
          </View>
        )}
      </Pressable>
    </Animated.View>
  );
}

// MARK: Explain this

const PROMPTS = ['وش معنى هذا الرمز؟', 'من وين جات؟', 'مثال ثاني', 'أبسط'];

/**
 * "Explain this" as a short conversation: you frame a part of the slide in blue and ask,
 * the tutor answers in numbered steps and can draw the answer on the slide.
 */
function ExplainPanel({ page, onDraw, wide }) {
  const [chosen, setChosen] = useState(0);
  const [question, setQuestion] = useState('');
  const [size, onLayout] = useSize();
  const cropW = size ? Math.min(240, size.w * 0.62) : 0;

  const thread = (
    <View onLayout={onLayout}>
      <View style={{ flexDirection: 'row', alignItems: 'center' }}>
        <T size={16} w="700" lh={22}>
          اشرح هذا الجزء
        </T>
        <View style={{ flex: 1 }} />
        <Pill label="منطقة محدّدة" tone="blue" icon="crop" />
      </View>

      {cropW > 0 && (
        <View style={{ alignSelf: 'flex-end', marginTop: 16, backgroundColor: C.raised, borderRadius: R.lg, padding: 6, maxWidth: '88%' }}>
          <View style={slideFrame()}>
            <RegionCrop page={page} rect={explainSelection} width={cropW} />
          </View>
          <T size={15} style={{ paddingHorizontal: 8, paddingTop: 8, paddingBottom: 4 }} lh={22}>
            {PROMPTS[chosen]}
          </T>
        </View>
      )}

      <TutorMessage style={{ marginTop: 18 }}>
        {explainAnswer.map((line, idx) => (
          <View key={idx} style={{ flexDirection: 'row', marginBottom: 10 }}>
            <View style={{ width: 22, height: 22, borderRadius: 11, backgroundColor: C.accentSoft, alignItems: 'center', justifyContent: 'center', marginTop: 2 }}>
              <S size={12} w="700" color={C.accent} align="center" lh={16}>
                {String(idx + 1)}
              </S>
            </View>
            <View style={{ width: 10 }} />
            <Rich text={line} size={15.5} style={{ flex: 1 }} />
          </View>
        ))}
        <View style={{ flexDirection: 'row', flexWrap: 'wrap', marginTop: 2 }}>
          <Button label="ارسمها على السلايد" icon="edit-2" kind="accent" height={38} size={14} onPress={onDraw} style={{ marginBottom: 8, ...me(8) }} />
          <Button label="ما زلت مو فاهم" kind="secondary" height={38} size={14} onPress={() => {}} />
        </View>
      </TutorMessage>
    </View>
  );

  const ask = (
    <View>
      <View style={{ flexDirection: 'row', flexWrap: 'wrap', marginBottom: 8 }}>
        {PROMPTS.map((q, idx) => (
          <Chip key={q} label={q} selected={chosen === idx} onPress={() => setChosen(idx)} style={{ ...me(6), marginBottom: 6 }} />
        ))}
      </View>
      <Composer
        value={question}
        onChangeText={setQuestion}
        placeholder="اكتب سؤالك عن هالجزء…"
        minHeight={26}
        tools={
          <View style={{ flexDirection: 'row', alignItems: 'center', paddingHorizontal: 4 }}>
            <Icon name="bookmark" size={13} color={C.text3} />
            <T size={12} color={C.text3} style={{ marginHorizontal: 5 }} lh={16}>
              ينحفظ في «أسئلتي» مع مكانه على السلايد
            </T>
          </View>
        }
      />
    </View>
  );

  if (!wide) {
    return (
      <Card style={{ padding: 16 }}>
        {thread}
        <View style={{ marginTop: 14 }}>{ask}</View>
      </Card>
    );
  }
  return (
    <Card style={{ flex: 1, overflow: 'hidden' }}>
      <ScrollView style={{ flex: 1 }} contentContainerStyle={{ padding: 18 }}>
        {thread}
      </ScrollView>
      <View style={{ padding: 12, paddingTop: 4 }}>{ask}</View>
    </Card>
  );
}
