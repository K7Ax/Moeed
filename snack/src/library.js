// The packet's front page: a masthead for the course, the lecture you were in as the lead story,
// the lectures as a table of contents, and a sticky note for what needs another look.
import React from 'react';
import { Pressable, ScrollView, View } from 'react-native';
import Svg, { Line } from 'react-native-svg';
import { C, S, T, ltr } from './theme';
import { course, resume, sinePage } from './data';
import { ColumnRule, DoubleRule, Grain, Hairline, Leader, Sheet, Tape, paperShadow, slideFrame } from './paper';
import { Stamp } from './pen';
import { FORWARD, Icon, InkButton, ProgressTrack } from './controls';
import { SlideStage } from './slide';

const pct = (v) => `${Math.round(v * 100)}%`;

export function LibraryScreen({ wide, go, reviewCount }) {
  const body = (
    <>
      <Masthead wide={wide} reviewCount={reviewCount} />
      <Lead wide={wide} go={go} />
      <Contents wide={wide} go={go} reviewCount={reviewCount} />
    </>
  );
  if (!wide) {
    return (
      <ScrollView style={{ flex: 1 }} contentContainerStyle={{ padding: 12, paddingBottom: 24 }}>
        <Sheet style={{ paddingHorizontal: 18, paddingTop: 18, paddingBottom: 24 }}>{body}</Sheet>
      </ScrollView>
    );
  }
  return (
    <Sheet style={{ flex: 1 }}>
      <ScrollView style={{ flex: 1 }} contentContainerStyle={{ paddingHorizontal: 34, paddingTop: 24, paddingBottom: 22 }}>
        {body}
      </ScrollView>
    </Sheet>
  );
}

// MARK: Masthead

function Masthead({ wide, reviewCount }) {
  const ears = (
    <View style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'flex-start' }}>
      <View>
        <S size={15} w="700" lh={20}>
          {course.code}
        </S>
        <T size={12} color={C.inkSoft} lh={17}>
          الأسبوع 7 · الفصل الأول
        </T>
      </View>
      <View style={{ alignItems: 'flex-end' }}>
        <T size={12.5} w="600" lh={17}>
          الثلاثاء
        </T>
        <T size={12} color={C.inkSoft} lh={17}>
          13 أكتوبر 2026
        </T>
      </View>
    </View>
  );
  return (
    <View>
      {wide ? (
        <View style={{ justifyContent: 'center', minHeight: 66 }}>
          {ears}
          <View style={{ position: 'absolute', left: 0, right: 0, top: 0, bottom: 0, alignItems: 'center', justifyContent: 'center' }} pointerEvents="none">
            <T size={46} w="900" align="center" lh={62}>
              {course.name}
            </T>
          </View>
        </View>
      ) : (
        <>
          <T size={32} w="900" align="center" lh={44}>
            {course.name}
          </T>
          <View style={{ marginTop: 6 }}>{ears}</View>
        </>
      )}
      <Hairline style={{ marginTop: 10 }} />
      <View style={{ flexDirection: 'row', flexWrap: 'wrap', justifyContent: 'center', paddingVertical: 6 }}>
        {[`${course.lectures.length} محاضرات`, '•', `${reviewCount} للمراجعة`, '•', '3 أسئلة مفتوحة'].map((s, i) => (
          <T key={i} size={12.5} w="500" color={C.inkSoft} style={{ marginHorizontal: 5 }} lh={18}>
            {s}
          </T>
        ))}
      </View>
      <DoubleRule />
    </View>
  );
}

// MARK: Lead story

function Lead({ wide, go }) {
  const l = resume.lecture;
  const slideW = wide ? 290 : 260;
  const slide = (
    <View style={{ width: slideW, alignSelf: wide ? 'flex-start' : 'center' }}>
      <View style={[slideFrame, { transform: [{ rotate: '1.2deg' }] }]}>
        <SlideStage page={sinePage} width={slideW} marks={[{ t: 'circle', c: [430, 510], rx: 30, ry: 26 }]} />
        <Tape angle={-3} />
      </View>
      <T size={12} italic color={C.inkSoft} style={{ marginTop: 12 }}>
        {`سلايد ${resume.page}: وين وقف المعيد آخر مرة`}
      </T>
    </View>
  );
  const text = (
    <View style={{ flex: wide ? 1 : undefined }}>
      <T size={13.5} w="700" color={C.red}>
        كمّل من حيث وقفت
      </T>
      <S size={17} italic color={C.inkSoft} style={{ marginTop: 8 }} lh={22}>
        {`Lecture ${l.number}`}
      </S>
      <S size={wide ? 34 : 28} w="700" numberOfLines={1} adjustsFontSizeToFit lh={wide ? 42 : 36}>
        {l.title}
      </S>
      <T size={15} color={C.inkSoft} style={{ marginTop: 10 }}>
        {`السلايد ${resume.page} من ${l.slideCount} · الخطوة ${resume.step} من ${resume.stepCount}: ${resume.stepTitle}`}
      </T>
      <View style={{ flexDirection: 'row', alignItems: 'center', marginTop: 12 }}>
        <ProgressTrack value={l.progress} />
        <S size={15} w="700" style={{ marginStart: 12 }} lh={20}>
          {pct(l.progress)}
        </S>
      </View>
      <View style={{ flexDirection: 'row', alignItems: 'center', flexWrap: 'wrap', marginTop: 16 }}>
        <InkButton label="كمّل الشرح" trailIcon={FORWARD} onPress={() => go('player')} style={{ marginEnd: 16 }} />
        <T size={13} color={C.mark} style={{ marginTop: wide ? 0 : 8 }}>
          {`${resume.askCount} أسئلة توقّع في الطريق`}
        </T>
      </View>
    </View>
  );
  if (!wide) {
    return (
      <View style={{ marginTop: 22 }}>
        {slide}
        <View style={{ marginTop: 22 }}>{text}</View>
      </View>
    );
  }
  return (
    <View style={{ flexDirection: 'row', marginTop: 22 }}>
      {text}
      <View style={{ marginHorizontal: 26, flexDirection: 'row' }}>
        <ColumnRule />
      </View>
      {slide}
    </View>
  );
}

// MARK: Contents

function Contents({ wide, go, reviewCount }) {
  const list = (
    <View style={{ flex: wide ? 1 : undefined }}>
      <View style={{ flexDirection: 'row', alignItems: 'baseline', paddingBottom: 6 }}>
        <T size={18} w="800">
          المحاضرات
        </T>
        <View style={{ flex: 1 }} />
        <T size={12} w="500" color={C.mark}>
          المحتويات
        </T>
      </View>
      <Hairline weight={1.5} />
      {course.lectures.map((lecture) => (
        <View key={lecture.id}>
          <ContentsRow lecture={lecture} wide={wide} onPress={() => go(lecture.ready ? 'player' : 'import')} />
          <Hairline color={C.rule} />
        </View>
      ))}
      <CutHere onPress={() => go('import')} />
    </View>
  );
  const note = <ReviewNote count={reviewCount} onPress={() => go('review')} />;
  if (!wide) {
    return (
      <View style={{ marginTop: 26 }}>
        {list}
        <View style={{ marginTop: 22, paddingHorizontal: 8 }}>{note}</View>
      </View>
    );
  }
  return (
    <View style={{ flexDirection: 'row', alignItems: 'flex-start', marginTop: 22 }}>
      {list}
      <View style={{ width: 236, marginStart: 30, marginTop: 14 }}>{note}</View>
    </View>
  );
}

/** One line of the table of contents: number, title, leader, and where it stands. */
function ContentsRow({ lecture, wide, onPress }) {
  const status = lecture.ready ? (
    <View style={{ flexDirection: 'row', alignItems: 'center' }}>
      <S size={15} w="700" lh={20} style={{ marginEnd: 12 }}>
        {pct(lecture.progress)}
      </S>
      <Stamp text="جاهزة" size={12} angle={-6} />
    </View>
  ) : (
    <View style={{ alignItems: 'flex-end' }}>
      <T size={12.5} w="700" color={C.inkSoft} lh={18}>
        {'يتجهّز ' + ltr(pct(lecture.preparing))}
      </T>
      <ProgressTrack value={lecture.preparing} height={7} style={{ width: 84, flex: 0, marginTop: 5 }} />
    </View>
  );
  return (
    <Pressable onPress={onPress} style={({ pressed }) => ({ flexDirection: 'row', alignItems: 'center', paddingVertical: 12, opacity: pressed ? 0.7 : 1 })}>
      <S size={30} w="700" style={{ width: wide ? 44 : 40 }} lh={36}>
        {String(lecture.number).padStart(2, '0')}
      </S>
      <View style={{ marginStart: 14, flexShrink: 1 }}>
        <S size={18} w="600" lh={24}>
          {lecture.title}
        </S>
        <T size={13} color={C.inkSoft} lh={19}>
          {lecture.ready ? `${lecture.slideCount} سلايد · ${lecture.explainedCount} مشروحة` : 'تقدر تبدأ من السلايدات الجاهزة'}
        </T>
      </View>
      {wide ? <Leader style={{ marginHorizontal: 14 }} /> : <View style={{ flex: 1, minWidth: 10 }} />}
      {status}
    </Pressable>
  );
}

/** «قص هنا»: the dashed line where a new lecture goes in. */
function CutHere({ onPress }) {
  return (
    <Pressable onPress={onPress} style={{ flexDirection: 'row', alignItems: 'center', minHeight: 52 }}>
      <Icon name="scissors" size={15} color={C.inkSoft} />
      <T size={14} w="600" color={C.inkSoft} style={{ marginHorizontal: 10 }} lh={20}>
        أضف محاضرة: استورد PDF
      </T>
      <View style={{ flex: 1, height: 2 }}>
        <Svg width="100%" height={2}>
          <Line x1="0" y1="1" x2="100%" y2="1" stroke={C.inkSoft} strokeWidth={1} strokeDasharray="6 5" />
        </Svg>
      </View>
    </Pressable>
  );
}

/** A sticky note left on the page: what you got wrong, and five minutes to fix it. */
function ReviewNote({ count, onPress }) {
  return (
    <Pressable onPress={onPress} style={({ pressed }) => ({ opacity: pressed ? 0.85 : 1 })}>
      <View style={[{ backgroundColor: C.sticky, padding: 18, transform: [{ rotate: '-2deg' }] }, paperShadow(1.2)]}>
        <Grain density={0.8} />
        <T size={19} w="800">
          {`${count} توقّعات غلطت فيها`}
        </T>
        <T size={14} color="rgba(23,21,19,0.75)" style={{ marginTop: 8 }}>
          مراجعة سريعة قبل الكويز، 5 دقايق تقريبًا.
        </T>
        <View style={{ flexDirection: 'row', alignItems: 'center', alignSelf: 'flex-start', marginTop: 8, paddingBottom: 3, borderBottomWidth: 1.5, borderColor: C.red }}>
          <T size={15} w="700" color={C.red} lh={20}>
            ابدأ المراجعة
          </T>
          <Icon name={FORWARD} size={14} color={C.red} style={{ marginStart: 4 }} />
        </View>
        <Tape angle={3} />
      </View>
    </Pressable>
  );
}
