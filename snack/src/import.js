// A lecture being prepared, shown the way an assistant shows its work: steps that tick off
// one by one, and the pages filling with the tutor's ink as their explanations are written.
import React, { useEffect, useRef, useState } from 'react';
import { Animated, Easing, ScrollView, StyleSheet, View } from 'react-native';
import Svg, { G } from 'react-native-svg';
import { C, R, S, T, me } from './theme';
import { STAGES, importJob as job, slideState, stageText } from './data';
import { DrawnPath } from './pen';
import { BACK, Button, FORWARD, Icon, IconButton, Segmented } from './controls';
import { Card, ProgressBar, Spinner, useSize } from './ui';
import { markGeometry } from './slide';

export function ImportScreen({ wide, go }) {
  const [filter, setFilter] = useState('all');

  const top = (
    <View style={{ flexDirection: 'row', alignItems: 'center', paddingHorizontal: wide ? 20 : 8, paddingTop: wide ? 12 : 4, paddingBottom: 8 }}>
      <IconButton name={BACK} label="رجوع" onPress={() => go('library')} />
      <View style={{ marginHorizontal: 8, flexShrink: 1 }}>
        <T size={17} w="700" lh={24}>
          تجهيز المحاضرة
        </T>
        <S size={12.5} color={C.text2} lh={18} numberOfLines={1}>
          {`${job.courseCode} · ${job.fileName}`}
        </S>
      </View>
    </View>
  );

  const steps = (
    <Card style={{ padding: 20 }}>
      <View style={{ flexDirection: 'row', alignItems: 'center' }}>
        <View style={{ width: 40, height: 40, borderRadius: R.sm, backgroundColor: C.accentSoft, alignItems: 'center', justifyContent: 'center' }}>
          <Icon name="file-text" size={18} color={C.accent} />
        </View>
        <View style={{ flex: 1, marginHorizontal: 12 }}>
          <S size={17} w="700" lh={22} numberOfLines={1}>
            {job.fileName}
          </S>
          <T size={12.5} color={C.text2} lh={18}>
            {`${job.slideCount} سلايد · ${job.courseCode}`}
          </T>
        </View>
      </View>
      <View style={{ marginTop: 18 }}>
        {STAGES.map((stage, i) => (
          <StageRow key={stage} stage={stage} last={i === STAGES.length - 1} />
        ))}
      </View>
      <View style={{ flexDirection: 'row', alignItems: 'flex-start', marginTop: 16, padding: 12, borderRadius: R.md, backgroundColor: C.raised }}>
        <Icon name="info" size={15} color={C.text2} style={{ marginTop: 3 }} />
        <T size={14} color={C.text2} style={{ flex: 1, marginHorizontal: 8 }}>
          تقدر تبدأ من السلايدات الجاهزة، والباقي يتجهّز وانت تذاكر.
        </T>
      </View>
      <Button label="ابدأ من السلايد 1" trailIcon={FORWARD} onPress={() => go('player')} style={{ marginTop: 14 }} />
    </Card>
  );

  const pages = (
    <View style={{ flex: wide ? 1 : undefined }}>
      <View style={{ flexDirection: 'row', alignItems: 'center', flexWrap: 'wrap' }}>
        <T size={16} w="700" lh={26}>
          الصفحات
        </T>
        <T size={13.5} color={C.text3} style={{ marginHorizontal: 8 }} lh={26}>
          {`${job.scripted} جاهزة من ${job.slideCount}`}
        </T>
        <View style={{ flex: 1 }} />
        <Segmented
          value={filter}
          onChange={setFilter}
          options={[
            { key: 'all', label: 'الكل' },
            { key: 'ready', label: 'الجاهزة' },
          ]}
        />
      </View>
      <PageGrid onlyReady={filter === 'ready'} />
    </View>
  );

  if (!wide) {
    return (
      <View style={{ flex: 1 }}>
        {top}
        <ScrollView style={{ flex: 1 }} contentContainerStyle={{ padding: 16, paddingBottom: 28 }}>
          {steps}
          <View style={{ marginTop: 26 }}>{pages}</View>
        </ScrollView>
      </View>
    );
  }
  return (
    <View style={{ flex: 1 }}>
      {top}
      <ScrollView style={{ flex: 1 }} contentContainerStyle={{ flexDirection: 'row', alignItems: 'flex-start', paddingHorizontal: 28, paddingVertical: 16 }}>
        <View style={{ width: 380 }}>{steps}</View>
        <View style={{ width: 28 }} />
        {pages}
      </ScrollView>
    </View>
  );
}

function StageRow({ stage, last }) {
  const at = STAGES.indexOf(job.stage);
  const idx = STAGES.indexOf(stage);
  const done = idx < at;
  const current = idx === at;
  const [title, detail] = stageText[stage];
  return (
    <View style={{ flexDirection: 'row', alignItems: 'stretch' }}>
      <View style={{ width: 24, alignItems: 'center' }}>
        <View style={{ width: 22, height: 22, alignItems: 'center', justifyContent: 'center' }}>
          {done ? (
            <View style={{ width: 20, height: 20, borderRadius: 10, backgroundColor: C.green, alignItems: 'center', justifyContent: 'center' }}>
              <Icon name="check" size={12} color="#FFFFFF" />
            </View>
          ) : current ? (
            <Spinner size={20} />
          ) : (
            <View style={{ width: 16, height: 16, borderRadius: 8, borderWidth: 1.5, borderColor: C.lineStrong }} />
          )}
        </View>
        {!last && <View style={{ flex: 1, width: 1.5, backgroundColor: done ? C.green : C.lineStrong, marginVertical: 3, opacity: done ? 0.5 : 1 }} />}
      </View>
      <View style={{ flex: 1, marginHorizontal: 12, paddingBottom: last ? 0 : 16 }}>
        <T size={15} w={current ? '700' : '600'} color={done || current ? C.text : C.text3} lh={22}>
          {current ? title + '…' : title}
        </T>
        <T size={13} color={current ? C.text2 : C.text3} lh={19}>
          {detail}
        </T>
        {current && stage === 'scripting' && (
          <View style={{ flexDirection: 'row', alignItems: 'center', marginTop: 8 }}>
            <ProgressBar value={job.scripted / job.slideCount} />
            <S size={12.5} w="600" color={C.text2} style={{ marginHorizontal: 10 }} lh={18}>
              {`${job.scripted} / ${job.slideCount}`}
            </S>
          </View>
        )}
      </View>
    </View>
  );
}

const THUMB = { w: 84, h: 63, gap: 10 };

function PageGrid({ onlyReady }) {
  const [size, onLayout] = useSize();
  const numbers = [];
  for (let n = 1; n <= job.slideCount; n++) if (!onlyReady || slideState(job, n) === 'ready') numbers.push(n);
  const cols = size ? Math.max(1, Math.floor((size.w + THUMB.gap) / (THUMB.w + THUMB.gap))) : 1;
  return (
    <View onLayout={onLayout} style={{ flexDirection: 'row', flexWrap: 'wrap', marginTop: 14 }}>
      {size &&
        numbers.map((n, i) => (
          <View key={n} style={{ ...me((i + 1) % cols === 0 ? 0 : THUMB.gap), marginBottom: 10 }}>
            <PageThumb number={n} state={slideState(job, n)} />
          </View>
        ))}
    </View>
  );
}

const THUMB_MARKS = [
  { t: 'circle', c: [520, 380], rx: 150, ry: 110 },
  { t: 'underline', a: [80, 250], b: [470, 250] },
  { t: 'box', r: [80, 330, 300, 150] },
  { t: 'arrow', a: [160, 470], b: [560, 300], bend: -0.2 },
];

/** Ready pages carry the tutor's ink; the one being written breathes; the rest wait as outlines. */
function PageThumb({ number, state }) {
  const s = THUMB.w / 800;
  const lineA = [44, 36, 50, 40][number % 4];
  const lineB = [30, 46, 38, 52][(number + 1) % 4];
  const waiting = state === 'waiting';
  const writing = state === 'writing';
  const pulse = useRef(new Animated.Value(0)).current;
  useEffect(() => {
    if (!writing) return undefined;
    const loop = Animated.loop(
      Animated.sequence([
        Animated.timing(pulse, { toValue: 1, duration: 700, easing: Easing.inOut(Easing.ease), useNativeDriver: true }),
        Animated.timing(pulse, { toValue: 0, duration: 700, easing: Easing.inOut(Easing.ease), useNativeDriver: true }),
      ])
    );
    loop.start();
    return () => loop.stop();
  }, [writing]);
  return (
    <View style={{ width: THUMB.w, height: THUMB.h, direction: 'ltr' }} accessibilityLabel={`سلايد ${number}`}>
      {writing && (
        <Animated.View
          style={{ position: 'absolute', top: -3, left: -3, right: -3, bottom: -3, borderRadius: 11, borderWidth: 2, borderColor: C.accent, opacity: pulse.interpolate({ inputRange: [0, 1], outputRange: [0.35, 1] }) }}
        />
      )}
      <View
        style={{
          flex: 1,
          borderRadius: 8,
          overflow: 'hidden',
          backgroundColor: waiting ? C.raised : '#FFFFFF',
          borderWidth: waiting ? 1 : StyleSheet.hairlineWidth,
          borderColor: waiting ? C.lineStrong : C.lineStrong,
          borderStyle: waiting ? 'dashed' : 'solid',
        }}
      >
        {!waiting && (
          <>
            <View style={{ padding: 8 }}>
              <View style={{ width: lineA, height: 4, borderRadius: 2, backgroundColor: 'rgba(28,61,110,0.55)' }} />
              <View style={{ width: lineB, height: 3, borderRadius: 2, backgroundColor: C.slideRule, marginTop: 5 }} />
              <View style={{ width: lineA - 8, height: 3, borderRadius: 2, backgroundColor: C.slideRule, marginTop: 5 }} />
            </View>
            <Svg width={THUMB.w} height={THUMB.h} style={{ position: 'absolute', top: 0, left: 0 }}>
              <G scale={s}>
                <DrawnPath geo={markGeometry(THUMB_MARKS[number % THUMB_MARKS.length])} progress={state === 'ready' ? 1 : 0.55} color={C.pen} width={1.8 / s} />
              </G>
            </Svg>
          </>
        )}
        <S size={9.5} w="600" color={waiting ? C.text3 : '#8C8579'} lh={12} style={{ position: 'absolute', bottom: 3, right: 5 }}>
          {String(number)}
        </S>
      </View>
    </View>
  );
}
