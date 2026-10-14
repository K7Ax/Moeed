// One slide, explained step by step: red pen on the printed page, words on a slip beside it,
// a question before each reveal.
import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { Animated, Pressable, ScrollView, TextInput, View } from 'react-native';
import Svg from 'react-native-svg';
import { C, END, Rich, S, START, T, clamp01, easeInOut, inkTotal, ltr, readingMs, ms, me, ps } from './theme';
import { explainAnswer, explainSelection } from './data';
import { Desk, Hairline, Perforation, Sheet, Tape, slideFrame, useSize } from './paper';
import { DrawnPath, PenCheckbox, PenRing, PenTick, Ringed, ellipsePath } from './pen';
import { BACK, Chip, FORWARD, Icon, InkButton, OutlineButton, RedPenButton, SquareIcon, UnderLink, haptic } from './controls';
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
    <View style={slideFrame}>
      <SlideStage
        page={page}
        width={width}
        pastMarks={p.pastMarks}
        marks={p.step.marks}
        playKey={p.playKey}
        animate
        showInk={p.showInk}
        {...extra}
      />
    </View>
  );

  const caption = { number: p.step.id, phrases: p.step.caption, revealed: p.revealed };

  let content = null;
  if (area && wide) {
    const w = area.w - 56;
    const h = area.h - 36;
    if (explaining || p.step.ask) {
      const panelW = explaining ? 420 : 410;
      const sw = Math.max(200, Math.min(w - panelW - 26, h * (4 / 3)));
      content = (
        <View style={{ flex: 1, flexDirection: 'row' }}>
          <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center' }}>
            {stage(sw, explaining ? { selection: explainSelection, animate: false, marks: [], pastMarks: [] } : {})}
          </View>
          <View style={{ width: panelW, ...ms(26) }}>
            {explaining ? (
              <ExplainPanel page={page} onDraw={() => setExplaining(false)} wide />
            ) : (
              <AskPanel key={p.playKey} p={p} ask={p.step.ask} wide />
            )}
          </View>
        </View>
      );
    } else {
      // The caption floats on the slide when there's room beside the ink,
      // and docks under the slide when there's spare height.
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
                <View style={{ width: Math.min(fitW, 680), marginTop: 22 }}>
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
        {stage(sw, explaining ? { selection: explainSelection, animate: false, marks: [], pastMarks: [] } : {})}
        <View style={{ marginTop: 18 }}>
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
    <Desk>
      <TopBar p={p} wide={wide} explaining={explaining} onExplain={() => setExplaining((e) => !e)} onBack={onBack} />
      <View style={{ flex: 1 }} onLayout={onLayout}>
        {wide ? <View style={{ flex: 1, paddingHorizontal: 28, paddingVertical: 18 }}>{content}</View> : content}
      </View>
      <View style={{ alignItems: 'center', paddingHorizontal: wide ? 28 : 10, paddingBottom: wide ? 18 : 10 }}>
        <Controls p={p} wide={wide} />
      </View>
    </Desk>
  );
}

function TopBar({ p, wide, explaining, onExplain, onBack }) {
  const explain = explaining ? (
    <InkButton label="رجوع للشرح" icon="x" height={44} onPress={onExplain} size={15} />
  ) : (
    <OutlineButton label="اشرح هذا" icon="maximize" height={44} onPress={onExplain} />
  );
  const toggles = (
    <View style={{ flexDirection: 'row' }}>
      <LayerToggle title="الحبر" on={p.showInk} onPress={() => p.setShowInk(!p.showInk)} />
      <View style={{ width: 14 }} />
      <LayerToggle title="النص" on={p.showText} onPress={() => p.setShowText(!p.showText)} />
    </View>
  );
  const title = (
    <View style={{ flexShrink: 1 }}>
      <T size={wide ? 20 : 18} w="800" numberOfLines={1}>
        {p.page.title}
      </T>
      <View style={{ flexDirection: 'row', alignItems: 'baseline' }}>
        <T size={13} color={C.inkSoft} lh={18}>
          {`سلايد ${p.page.id} من ${p.page.deckPageCount} · `}
        </T>
        <S size={13.5} italic color={C.inkSoft} lh={18} numberOfLines={1} style={{ flexShrink: 1 }}>
          {p.page.deckTitle}
        </S>
      </View>
    </View>
  );
  if (wide) {
    return (
      <View style={{ paddingHorizontal: 28 }}>
        <View style={{ flexDirection: 'row', alignItems: 'center', paddingTop: 16, paddingBottom: 12 }}>
          <UnderLink label="المكتبة" onPress={onBack} />
          <View style={{ width: 20 }} />
          {title}
          <View style={{ flex: 1, minWidth: 12 }} />
          {toggles}
          <View style={{ width: 20 }} />
          {explain}
        </View>
        <Hairline color="rgba(23,21,19,0.35)" />
      </View>
    );
  }
  return (
    <View style={{ paddingHorizontal: 16 }}>
      <View style={{ flexDirection: 'row', alignItems: 'center', paddingTop: 6 }}>
        <UnderLink label="المكتبة" onPress={onBack} />
        <View style={{ flex: 1 }} />
        {explain}
      </View>
      <View style={{ marginTop: 6 }}>{title}</View>
      <View style={{ flexDirection: 'row', marginTop: 2, marginBottom: 4 }}>{toggles}</View>
      <Hairline color="rgba(23,21,19,0.35)" />
    </View>
  );
}

/** A box ticked in red pen, as on an exam sheet. */
function LayerToggle({ title, on, onPress }) {
  return (
    <Pressable onPress={onPress} accessibilityState={{ checked: on }} style={{ flexDirection: 'row', alignItems: 'center', minHeight: 44 }}>
      <PenCheckbox on={on} />
      <T size={14.5} w="600" color={on ? C.ink : C.mark} style={{ ...ms(5) }} lh={20}>
        {title}
      </T>
    </Pressable>
  );
}

// MARK: Controls

/** The step controls, printed on a strip of card along the bottom of the desk. */
function Controls({ p, wide }) {
  const askSteps = p.page.steps.map((s, idx) => (s.ask ? idx : -1)).filter((x) => x >= 0);
  const prev = <SquareIcon name={BACK} label="الخطوة السابقة" onPress={p.previous} disabled={p.isFirst} />;
  const count = (
    <S size={15} w="600" align="center" style={{ minWidth: 52 }} lh={20}>
      {`${p.i + 1} من ${p.n}`}
    </S>
  );
  const next = (
    <InkButton
      label="التالي"
      trailIcon={FORWARD}
      height={44}
      size={15}
      onPress={p.next}
      disabled={p.isLast || (p.step.ask && !p.isAnswered)}
      style={wide ? null : { flex: 1 }}
    />
  );
  const replay = <SquareIcon name="rotate-ccw" label="أعد الخطوة" onPress={p.replay} />;
  const auto = <Chip label="تلقائي" icon={p.auto ? 'pause' : 'play'} selected={p.auto} onPress={p.toggleAuto} />;
  const speed = (
    <Chip onPress={p.cycleSpeed}>
      <S size={14} w="700" align="center" style={{ minWidth: 26 }} lh={20}>
        {`${p.speed}×`}
      </S>
    </Chip>
  );
  const ruler = <StepRuler count={p.n} current={p.i} askSteps={askSteps} onSelect={p.go} width={wide ? 270 : undefined} />;
  const gap = (w = 14) => <View style={{ width: w }} />;

  if (wide) {
    return (
      <Sheet stock={C.card} lift={0.8} style={{ flexDirection: 'row', alignItems: 'center', height: 64, paddingHorizontal: 14 }}>
        {prev}
        {gap()}
        {ruler}
        {gap()}
        {count}
        {gap()}
        {next}
        {gap()}
        <View style={{ width: 0.75, height: 30, backgroundColor: C.rule }} />
        {gap()}
        {replay}
        {gap()}
        {auto}
        {gap(8)}
        {speed}
      </Sheet>
    );
  }
  return (
    <Sheet stock={C.card} lift={0.8} style={{ alignSelf: 'stretch', paddingHorizontal: 10, paddingVertical: 6 }}>
      <View style={{ flexDirection: 'row', alignItems: 'center' }}>
        {prev}
        {gap(10)}
        <View style={{ flex: 1 }}>{ruler}</View>
        {gap(6)}
        {count}
      </View>
      <View style={{ flexDirection: 'row', alignItems: 'center', marginTop: 2 }}>
        {next}
        {gap(8)}
        {replay}
        {gap(8)}
        {auto}
        {gap(6)}
        {speed}
      </View>
    </Sheet>
  );
}

/**
 * The steps as marks on a ruler. Done steps are inked; the current one carries the red pen;
 * question steps are ringed so you can see where the predictions are.
 */
function StepRuler({ count, current, askSteps, onSelect, width }) {
  const ticks = [];
  for (let idx = 0; idx < count; idx++) {
    const done = idx <= current;
    const isAsk = askSteps.includes(idx);
    const isCurrent = idx === current;
    ticks.push(
      <Pressable
        key={idx}
        onPress={() => {
          haptic();
          onSelect(idx);
        }}
        accessibilityLabel={`الخطوة ${idx + 1}`}
        style={{ flex: 1, height: 44, alignItems: 'center', justifyContent: 'flex-end', paddingBottom: 9 }}
      >
        {isAsk && (
          <View style={{ position: 'absolute', bottom: 27, width: 18, height: 14 }}>
            <Svg width={18} height={14}>
              <DrawnPath geo={ellipsePath(1, 1, 16, 12)} color={done ? C.red : C.mark} width={1.4} />
            </Svg>
          </View>
        )}
        <View
          style={{
            width: isCurrent ? 3 : 1.5,
            height: isCurrent ? 24 : isAsk ? 16 : 11,
            backgroundColor: isCurrent ? C.red : done ? C.ink : 'rgba(140,133,121,0.6)',
          }}
        />
      </Pressable>
    );
  }
  return (
    <View style={{ width, flexDirection: 'row' }}>
      <View style={{ position: 'absolute', left: 0, right: 0, bottom: 9, height: 1, backgroundColor: C.ink }} />
      {ticks}
    </View>
  );
}

// MARK: Ask

const LETTERS = ['أ', 'ب', 'ج', 'د', 'هـ'];

/**
 * Predict before the reveal, on a question slip torn from a quiz pad.
 * Your pick is ringed in your own blue pen. A wrong guess is never red: the option shakes once,
 * and the tutor's red pen rings the right answer, the way a tutor would on paper.
 */
function AskPanel({ p, ask, wide }) {
  const [hint, setHint] = useState(false);
  const look = (o) => {
    if (!p.isAnswered) return 'open';
    if (o.id === ask.answerID) return p.pickedRight ? 'right' : 'revealed';
    return o.id === p.picked ? 'yourPick' : 'other';
  };

  return (
    <Sheet stock={C.card} style={[{ paddingHorizontal: 24, paddingTop: 26, paddingBottom: 22 }, wide && { flex: 1 }]}>
      <Perforation />
      <View style={{ flexDirection: 'row', alignItems: 'center' }}>
        <T size={13} w="800" color={C.red}>
          سؤال توقّع
        </T>
        <View style={{ flex: 1 }} />
        <T size={12.5} color={C.mark}>
          قبل لا تكمل
        </T>
      </View>
      <Hairline style={{ marginTop: 8 }} />
      <Rich text={ask.question} size={wide ? 25 : 22} w="800" style={{ marginTop: 16 }} />
      <T size={15} color={C.inkSoft} style={{ marginTop: 6 }}>
        اختر جوابك، بعدها نكمل الرسم ونشوف.
      </T>

      <View style={{ marginTop: 14 }}>
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
        <MarginNote color={C.red}>
          <T size={15.5} w="700" color={C.red}>
            {p.pickedRight ? 'صح، بالضبط.' : 'مو بالضبط، شوف وين انرسمت الدائرة.'}
          </T>
          <Rich text={ask.why} size={15} />
        </MarginNote>
      ) : hint ? (
        <MarginNote color={C.mark}>
          <Rich text={ask.hint} size={15} color={C.inkSoft} />
        </MarginNote>
      ) : null}

      {wide ? <View style={{ flex: 1, minHeight: 12 }} /> : <View style={{ height: 18 }} />}

      {p.isAnswered ? (
        <InkButton label="كمّل الشرح" trailIcon={FORWARD} onPress={p.next} />
      ) : (
        <View style={{ flexDirection: 'row' }}>
          <OutlineButton label="اكشف الجواب" onPress={p.showAnswer} style={{ flex: 1 }} />
          <View style={{ width: 10 }} />
          <OutlineButton label="تلميح" icon="help-circle" onPress={() => setHint((h) => !h)} />
        </View>
      )}
    </Sheet>
  );
}

/** The tutor's note in the margin: a pen bar and the words beside it. */
function MarginNote({ color, children }) {
  return (
    <View style={{ flexDirection: 'row', marginTop: 14 }}>
      <View style={{ width: 2, backgroundColor: color }} />
      <View style={{ flex: 1, paddingHorizontal: 12 }}>{children}</View>
    </View>
  );
}

function OptionRow({ letter, label, look, wrongPick, disabled, onPress }) {
  const circled = look === 'right' || look === 'revealed';
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

  return (
    <Animated.View style={{ transform: [{ translateX }] }}>
      <Pressable
        onPress={onPress}
        disabled={disabled}
        style={{ flexDirection: 'row', alignItems: 'center', minHeight: 60, paddingHorizontal: 4, borderBottomWidth: 0.75, borderColor: C.rule }}
      >
        <View style={{ width: 30, height: 30, alignItems: 'center', justifyContent: 'center' }}>
          <T size={17} w="700" color={C.inkSoft} align="center" lh={22}>
            {letter}
          </T>
          {(look === 'yourPick' || look === 'right') && <PenRing w={30} h={30} color={C.blue} lw={2} />}
        </View>
        <View style={{ width: 16 }} />
        <Ringed progress={ring} padX={8} padY={7} lw={2.6} style={{ paddingHorizontal: 10 }}>
          <S size={22} w="700" color={look === 'other' ? C.mark : C.ink} lh={30}>
            {ltr(label)}
          </S>
        </Ringed>
        <View style={{ width: 12 }} />
        {look === 'right' && <PenTick />}
        {look === 'revealed' && (
          <T size={13} w="700" color={C.red}>
            الصحيح
          </T>
        )}
        {look === 'yourPick' && (
          <T size={13} w="600" color={C.blue}>
            اختيارك
          </T>
        )}
      </Pressable>
    </Animated.View>
  );
}

// MARK: Explain this

const PROMPTS = ['وش معنى هذا الرمز؟', 'من وين جات؟', 'مثال ثاني', 'أبسط'];

/**
 * "Explain this": the student frames a region of the slide in blue pen and asks about it.
 * The region comes back as a taped clipping, and the answer as the tutor's numbered margin notes.
 */
function ExplainPanel({ page, onDraw, wide }) {
  const [chosen, setChosen] = useState(0);
  const [question, setQuestion] = useState('');
  const [size, onLayout] = useSize();
  const cropW = size ? Math.min(300, size.w - 48 - 20) : 0;

  return (
    <Sheet stock={C.card} style={[{ padding: 24 }, wide && { flex: 1 }]} onLayout={onLayout}>
      <View style={{ flexDirection: 'row', alignItems: 'baseline' }}>
        <T size={21} w="800">
          اشرح هذا الجزء
        </T>
        <View style={{ flex: 1 }} />
        <T size={12.5} w="600" color={C.blue}>
          منطقة محدّدة
        </T>
      </View>
      <Hairline style={{ marginTop: 8 }} />

      {cropW > 0 && (
        <View style={{ alignItems: 'center', marginTop: 22 }}>
          <View style={[slideFrame, { transform: [{ rotate: '-1.5deg' }] }]}>
            <RegionCrop page={page} rect={explainSelection} width={cropW} />
            <Tape angle={4} />
          </View>
        </View>
      )}

      <View style={{ flexDirection: 'row', flexWrap: 'wrap', marginTop: 18 }}>
        {PROMPTS.map((q, idx) => (
          <Chip key={q} label={q} selected={chosen === idx} onPress={() => setChosen(idx)} style={{ ...me(8) }} />
        ))}
      </View>

      <View style={{ flexDirection: 'row', marginTop: 16 }}>
        <View style={{ width: 1, backgroundColor: 'rgba(194,59,34,0.55)' }} />
        <View style={{ flex: 1, ...ps(12) }}>
          {explainAnswer.map((line, idx) => (
            <View key={idx} style={{ flexDirection: 'row', marginBottom: 10 }}>
              <S size={14} w="700" color={C.red} align="center" style={{ width: 20, marginTop: 2 }}>
                {String(idx + 1)}
              </S>
              <View style={{ width: 10 }} />
              <Rich text={line} size={16} style={{ flex: 1 }} />
            </View>
          ))}
          <View style={{ flexDirection: 'row', flexWrap: 'wrap', marginTop: 4 }}>
            <RedPenButton label="ارسمها على السلايد" icon="edit-2" height={44} size={15} onPress={onDraw} style={{ ...me(10), marginBottom: 8 }} />
            <OutlineButton label="ما زلت مو فاهم" height={44} onPress={() => {}} />
          </View>
        </View>
      </View>

      {wide ? <View style={{ flex: 1, minHeight: 12 }} /> : <View style={{ height: 16 }} />}

      <View style={{ flexDirection: 'row', alignItems: 'center', borderBottomWidth: 1, borderColor: C.ink, paddingBottom: 4 }}>
        <TextInput
          value={question}
          onChangeText={setQuestion}
          placeholder="اكتب سؤالك عن هالجزء…"
          placeholderTextColor={C.mark}
          style={{ flex: 1, fontSize: 15.5, color: C.blue, textAlign: START, writingDirection: 'rtl', paddingVertical: 8 }}
        />
        <Pressable accessibilityLabel="أرسل" style={{ width: 44, height: 44, alignItems: 'center', justifyContent: 'center' }}>
          <View style={{ width: 36, height: 36, backgroundColor: C.ink, alignItems: 'center', justifyContent: 'center' }}>
            <Icon name="arrow-up" color={C.paper} size={17} />
          </View>
        </Pressable>
      </View>
      <T size={12} color={C.mark} style={{ marginTop: 6 }}>
        ينحفظ السؤال في «أسئلتي» مع مكانه على السلايد.
      </T>
    </Sheet>
  );
}
