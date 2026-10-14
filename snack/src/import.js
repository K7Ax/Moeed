// A lecture being prepared, like a packet coming off the copier. No spinner: a checklist ticked
// in red pen, and each page gets inked as its explanation is written.
import React, { useState } from 'react';
import { ScrollView, View } from 'react-native';
import Svg, { G, Polygon } from 'react-native-svg';
import { C, S, T } from './theme';
import { STAGES, importJob as job, slideState, stageText } from './data';
import { DoubleRule, Hairline, Highlight, Sheet, swipePoints, useSize } from './paper';
import { DrawnPath, PenCheckbox } from './pen';
import { Chip, FORWARD, InkButton, ProgressTrack, UnderLink } from './controls';
import { markGeometry } from './slide';

export function ImportScreen({ wide, go }) {
  const [onlyReady, setOnlyReady] = useState(false);

  const top = (
    <View style={{ paddingHorizontal: wide ? 28 : 16 }}>
      <View style={{ flexDirection: 'row', alignItems: 'center', paddingTop: wide ? 16 : 6, paddingBottom: 12 }}>
        <UnderLink label="المكتبة" onPress={() => go('library')} />
        <View style={{ marginStart: 20, flexShrink: 1 }}>
          <T size={20} w="800" lh={28}>
            تجهيز المحاضرة
          </T>
          <S size={13.5} italic color={C.inkSoft} lh={18} numberOfLines={1}>
            {`${job.courseCode} · ${job.fileName}`}
          </S>
        </View>
      </View>
      <Hairline color="rgba(23,21,19,0.35)" />
    </View>
  );

  const checklist = (
    <Sheet style={{ padding: 24 }}>
      <S size={22} w="700" lh={28}>
        {job.fileName}
      </S>
      <T size={13} color={C.inkSoft} style={{ marginTop: 2 }}>
        {`${job.slideCount} سلايد · ${job.courseCode}`}
      </T>
      <DoubleRule style={{ marginTop: 12 }} />
      <View style={{ marginTop: 6 }}>
        {STAGES.map((stage) => (
          <View key={stage}>
            <StageRow stage={stage} />
            <Hairline color={C.rule} />
          </View>
        ))}
      </View>
      <View style={{ flexDirection: 'row', marginTop: 22, marginBottom: 16 }}>
        <View style={{ width: 2, backgroundColor: C.red }} />
        <T size={14.5} w="500" style={{ flex: 1, marginStart: 12 }}>
          تقدر تبدأ من السلايدات الجاهزة، والباقي يتجهّز وانت تذاكر.
        </T>
      </View>
      <InkButton label="ابدأ من السلايد 1" trailIcon={FORWARD} onPress={() => go('player')} />
    </Sheet>
  );

  const pages = (
    <View style={{ flex: wide ? 1 : undefined }}>
      <View style={{ flexDirection: 'row', alignItems: 'center', flexWrap: 'wrap' }}>
        <T size={18} w="800" lh={26}>
          الصفحات
        </T>
        <T size={14} color={C.inkSoft} style={{ marginStart: 10 }} lh={26}>
          {`${job.scripted} جاهزة من ${job.slideCount}`}
        </T>
        <View style={{ flex: 1 }} />
        <View style={{ flexDirection: 'row' }}>
          <Chip label="الكل" selected={!onlyReady} onPress={() => setOnlyReady(false)} />
          <Chip label="الجاهزة" selected={onlyReady} onPress={() => setOnlyReady(true)} />
        </View>
      </View>
      <PageGrid onlyReady={onlyReady} />
    </View>
  );

  if (!wide) {
    return (
      <View style={{ flex: 1 }}>
        {top}
        <ScrollView style={{ flex: 1 }} contentContainerStyle={{ padding: 16, paddingBottom: 28 }}>
          {checklist}
          <View style={{ marginTop: 26 }}>{pages}</View>
        </ScrollView>
      </View>
    );
  }
  return (
    <View style={{ flex: 1 }}>
      {top}
      <ScrollView style={{ flex: 1 }} contentContainerStyle={{ flexDirection: 'row', alignItems: 'flex-start', paddingHorizontal: 28, paddingVertical: 22 }}>
        <View style={{ width: 370 }}>{checklist}</View>
        <View style={{ width: 28 }} />
        {pages}
      </ScrollView>
    </View>
  );
}

function StageRow({ stage }) {
  const at = STAGES.indexOf(job.stage);
  const idx = STAGES.indexOf(stage);
  const done = idx < at;
  const current = idx === at;
  const [title, detail] = stageText[stage];
  return (
    <View style={{ flexDirection: 'row', alignItems: 'flex-start', paddingVertical: 13 }}>
      <View style={{ marginTop: 1 }}>
        <PenCheckbox on={done} />
      </View>
      <View style={{ flex: 1, marginStart: 14 }}>
        <Highlight on={current} seed={3}>
          <T size={16} w={current ? '800' : '600'} color={done || current ? C.ink : C.mark} lh={22}>
            {title}
          </T>
        </Highlight>
        <T size={13.5} color={C.inkSoft} style={{ marginTop: 3 }}>
          {detail}
        </T>
        {current && stage === 'scripting' && (
          <View style={{ flexDirection: 'row', alignItems: 'center', marginTop: 6 }}>
            <ProgressTrack value={job.scripted / job.slideCount} height={8} />
            <S size={13} w="700" style={{ marginStart: 10 }} lh={18}>
              {`${job.scripted} من ${job.slideCount}`}
            </S>
          </View>
        )}
      </View>
      {done && (
        <T size={12.5} w="700" color={C.red} style={{ marginStart: 8 }}>
          تم
        </T>
      )}
    </View>
  );
}

const THUMB = { w: 76, h: 57, gap: 10 };

function PageGrid({ onlyReady }) {
  const [size, onLayout] = useSize();
  const numbers = [];
  for (let n = 1; n <= job.slideCount; n++) if (!onlyReady || slideState(job, n) === 'ready') numbers.push(n);
  const cols = size ? Math.max(1, Math.floor((size.w + THUMB.gap) / (THUMB.w + THUMB.gap))) : 1;
  return (
    <View onLayout={onLayout} style={{ flexDirection: 'row', flexWrap: 'wrap', marginTop: 16 }}>
      {size &&
        numbers.map((n, i) => (
          <View key={n} style={{ marginEnd: (i + 1) % cols === 0 ? 0 : THUMB.gap, marginBottom: 12 }}>
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

/**
 * A page of the packet. Ready pages are printed and carry the tutor's ink; the one being written
 * is half-inked under the highlighter; the rest are blank stock waiting in the tray.
 */
function PageThumb({ number, state }) {
  const s = THUMB.w / 800;
  const lineA = [44, 36, 50, 40][number % 4];
  const lineB = [30, 46, 38, 52][(number + 1) % 4];
  const waiting = state === 'waiting';
  return (
    <View style={{ width: THUMB.w, height: THUMB.h, direction: 'ltr' }} accessibilityLabel={`سلايد ${number}`}>
      {state === 'writing' && (
        <Svg width={THUMB.w + 10} height={THUMB.h + 10} style={{ position: 'absolute', top: -5, left: -5 }}>
          <Polygon points={swipePoints(THUMB.w + 8, THUMB.h + 10, number)} fill={C.highlighter} opacity={0.85} />
        </Svg>
      )}
      <View
        style={{
          flex: 1,
          backgroundColor: waiting ? 'rgba(245,239,227,0.55)' : '#FFFFFF',
          borderWidth: waiting ? 0.75 : 0.5,
          borderColor: waiting ? 'rgba(140,133,121,0.7)' : 'rgba(23,21,19,0.15)',
          borderStyle: waiting ? 'dashed' : 'solid',
          shadowColor: C.ink,
          shadowOpacity: waiting ? 0 : 0.16,
          shadowRadius: 1.5,
          shadowOffset: { width: 0, height: 1 },
          elevation: waiting ? 0 : 1,
        }}
      >
        {!waiting && (
          <>
            <View style={{ padding: 8 }}>
              <View style={{ width: lineA, height: 4, backgroundColor: 'rgba(28,61,110,0.6)' }} />
              <View style={{ width: lineB, height: 3, backgroundColor: C.slideRule, marginTop: 5 }} />
              <View style={{ width: lineA - 8, height: 3, backgroundColor: C.slideRule, marginTop: 5 }} />
            </View>
            <Svg width={THUMB.w} height={THUMB.h} style={{ position: 'absolute', top: 0, left: 0 }}>
              <G scale={s}>
                <DrawnPath
                  geo={markGeometry(THUMB_MARKS[number % THUMB_MARKS.length])}
                  progress={state === 'ready' ? 1 : 0.55}
                  color={C.red}
                  width={1.8 / s}
                />
              </G>
            </Svg>
          </>
        )}
        <S size={9.5} w="600" color={C.mark} lh={12} style={{ position: 'absolute', bottom: 3, right: 4 }}>
          {String(number)}
        </S>
      </View>
    </View>
  );
}
