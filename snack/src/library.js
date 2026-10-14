// Home: a greeting and a message box like any assistant, then where you stopped,
// your lectures, and what needs another look.
import React, { useState } from 'react';
import { Pressable, ScrollView, StyleSheet, View } from 'react-native';
import { C, R, S, T, ltr } from './theme';
import { course, resume, sinePage } from './data';
import { Button, Chip, Composer, FORWARD, Icon, IconButton } from './controls';
import { Card, Column, Divider, Pill, ProgressBar, SectionTitle, slideFrame } from './ui';
import { LogoMark } from './logo';
import { SlideStage } from './slide';

const pct = (v) => `${Math.round(v * 100)}%`;

export function LibraryScreen({ wide, go, reviewCount }) {
  const [draft, setDraft] = useState('');
  return (
    <ScrollView style={{ flex: 1 }} contentContainerStyle={{ paddingHorizontal: wide ? 40 : 16, paddingTop: wide ? 56 : 18, paddingBottom: 40 }}>
      <Column>
        <Greeting wide={wide} />
        <Composer
          value={draft}
          onChangeText={setDraft}
          onSend={() => go('player')}
          placeholder="اسأل معيد عن أي سلايد، أو ارفع محاضرة جديدة…"
          style={{ marginTop: wide ? 26 : 18 }}
          tools={
            <>
              <IconButton name="paperclip" label="أرفق PDF" onPress={() => go('import')} size={34} iconSize={17} />
              <View style={{ flexDirection: 'row', alignItems: 'center', height: 28, paddingHorizontal: 10, borderRadius: R.pill, backgroundColor: C.raised, marginHorizontal: 4 }}>
                <Icon name="book" size={12} color={C.text2} />
                <S size={12.5} w="600" color={C.text2} style={{ marginHorizontal: 5 }} lh={16}>
                  {course.code}
                </S>
              </View>
            </>
          }
        />
        <View style={{ flexDirection: 'row', flexWrap: 'wrap', marginTop: 12, justifyContent: 'center' }}>
          <Chip icon="play" label={`كمّل المحاضرة ${resume.lecture.number}`} onPress={() => go('player')} style={{ margin: 4 }} />
          <Chip icon="rotate-ccw" label={`راجع ${reviewCount} توقّعات`} onPress={() => go('review')} style={{ margin: 4 }} />
          <Chip icon="zap" label="وش يعني f = 1/T؟" onPress={() => go('player')} style={{ margin: 4 }} />
        </View>

        <ContinueCard wide={wide} go={go} />
        <Lectures go={go} />
        <ReviewCard count={reviewCount} onPress={() => go('review')} />
      </Column>
    </ScrollView>
  );
}

function Greeting({ wide }) {
  return (
    <View style={{ alignItems: 'center' }}>
      <LogoMark size={wide ? 44 : 36} />
      <T size={wide ? 32 : 26} w="600" align="center" style={{ marginTop: 14 }} lh={wide ? 44 : 36}>
        وش نذاكر اليوم؟
      </T>
      <T size={15} color={C.text2} align="center" style={{ marginTop: 4 }}>
        {`${course.name} · الأسبوع 7`}
      </T>
    </View>
  );
}

function ContinueCard({ wide, go }) {
  const l = resume.lecture;
  const slideW = wide ? 240 : 0;
  const text = (
    <View style={{ flex: 1 }}>
      <View style={{ flexDirection: 'row', alignItems: 'center' }}>
        <View style={{ width: 7, height: 7, borderRadius: 4, backgroundColor: C.accent }} />
        <T size={13} w="600" color={C.accent} style={{ marginHorizontal: 7 }} lh={18}>
          كمّل من حيث وقفت
        </T>
      </View>
      <S size={wide ? 24 : 21} w="700" style={{ marginTop: 8 }} lh={wide ? 30 : 27} numberOfLines={2}>
        {l.title}
      </S>
      <T size={13.5} color={C.text2} style={{ marginTop: 4 }}>
        {`${ltr(`Lecture ${l.number}`)} · سلايد ${resume.page} · الخطوة ${resume.step} من ${resume.stepCount}`}
      </T>
      <View style={{ flexDirection: 'row', alignItems: 'center', marginTop: 12 }}>
        <ProgressBar value={l.progress} />
        <S size={13} w="600" color={C.text2} style={{ marginHorizontal: 10 }} lh={18}>
          {pct(l.progress)}
        </S>
      </View>
      <View style={{ flexDirection: 'row', alignItems: 'center', marginTop: 14, flexWrap: 'wrap' }}>
        <Button label="كمّل الشرح" trailIcon={FORWARD} onPress={() => go('player')} />
        <T size={12.5} color={C.text3} style={{ marginHorizontal: 12 }}>
          {`${resume.askCount} أسئلة توقّع في الطريق`}
        </T>
      </View>
    </View>
  );
  return (
    <Pressable onPress={() => go('player')} style={{ marginTop: wide ? 36 : 26 }}>
      <Card style={{ padding: wide ? 18 : 14, flexDirection: wide ? 'row' : 'column' }}>
        {wide ? (
          <View style={[slideFrame(), { width: slideW, alignSelf: 'center' }]}>
            <SlideStage page={sinePage} width={slideW} marks={[{ t: 'circle', c: [430, 510], rx: 30, ry: 26 }]} />
          </View>
        ) : null}
        <View style={{ flex: 1, marginHorizontal: wide ? 20 : 2, marginTop: wide ? 0 : 2 }}>{text}</View>
      </Card>
    </Pressable>
  );
}

function Lectures({ go }) {
  return (
    <View style={{ marginTop: 30 }}>
      <SectionTitle title="محاضراتك" detail={`${course.lectures.length} محاضرات`} />
      <Card level={0.6} style={{ overflow: 'hidden' }}>
        {course.lectures.map((lecture, i) => (
          <View key={lecture.id}>
            {i > 0 && <Divider inset={16} />}
            <LectureRow lecture={lecture} onPress={() => go(lecture.ready ? 'player' : 'import')} />
          </View>
        ))}
        <Divider inset={16} />
        <Pressable onPress={() => go('import')}>
          {({ pressed }) => (
            <View style={{ flexDirection: 'row', alignItems: 'center', minHeight: 54, paddingHorizontal: 16, backgroundColor: pressed ? C.raised : 'transparent' }}>
              <View style={{ width: 40, height: 40, borderRadius: R.sm, borderWidth: 1, borderStyle: 'dashed', borderColor: C.lineStrong, alignItems: 'center', justifyContent: 'center' }}>
                <Icon name="plus" size={16} color={C.text2} />
              </View>
              <T size={14.5} w="500" color={C.text2} style={{ marginHorizontal: 12 }} lh={20}>
                أضف محاضرة: ارفع ملف PDF
              </T>
            </View>
          )}
        </Pressable>
      </Card>
    </View>
  );
}

function LectureRow({ lecture, onPress }) {
  return (
    <Pressable onPress={onPress}>
      {({ pressed }) => (
        <View style={{ flexDirection: 'row', alignItems: 'center', minHeight: 68, paddingHorizontal: 16, paddingVertical: 10, backgroundColor: pressed ? C.raised : 'transparent' }}>
          <View style={{ width: 40, height: 40, borderRadius: R.sm, backgroundColor: C.raised, alignItems: 'center', justifyContent: 'center' }}>
            <S size={16} w="700" color={C.text2} align="center" lh={20}>
              {String(lecture.number).padStart(2, '0')}
            </S>
          </View>
          <View style={{ flex: 1, marginHorizontal: 12 }}>
            <S size={16.5} w="600" numberOfLines={1} lh={22}>
              {lecture.title}
            </S>
            <T size={12.5} color={C.text2} lh={18}>
              {lecture.ready ? `${lecture.slideCount} سلايد · ${lecture.explainedCount} مشروحة · ${pct(lecture.progress)}` : 'تقدر تبدأ من السلايدات الجاهزة'}
            </T>
          </View>
          {lecture.ready ? (
            <Pill label="جاهزة" tone="green" icon="check" />
          ) : (
            <View style={{ alignItems: 'flex-end', width: 92 }}>
              <Pill label={'يتجهّز ' + ltr(pct(lecture.preparing))} tone="accent" />
              <ProgressBar value={lecture.preparing} height={3} style={{ width: 80, flex: 0, marginTop: 6 }} />
            </View>
          )}
          <Icon name="chevron-left" size={16} color={C.text3} style={{ marginHorizontal: 6 }} />
        </View>
      )}
    </Pressable>
  );
}

function ReviewCard({ count, onPress }) {
  return (
    <Pressable onPress={onPress} style={{ marginTop: 18 }}>
      {({ pressed }) => (
        <View
          style={{
            flexDirection: 'row',
            alignItems: 'center',
            padding: 16,
            borderRadius: R.lg,
            backgroundColor: C.accentSoft,
            opacity: pressed ? 0.85 : 1,
          }}
        >
          <View style={{ width: 40, height: 40, borderRadius: 20, backgroundColor: C.surface, alignItems: 'center', justifyContent: 'center', borderWidth: StyleSheet.hairlineWidth, borderColor: C.lineStrong }}>
            <Icon name="rotate-ccw" size={17} color={C.accent} />
          </View>
          <View style={{ flex: 1, marginHorizontal: 12 }}>
            <T size={15.5} w="700" lh={22}>
              {`${count} توقّعات غلطت فيها`}
            </T>
            <T size={13.5} color={C.text2} lh={20}>
              مراجعة سريعة قبل الكويز، 5 دقايق تقريبًا.
            </T>
          </View>
          <View style={{ flexDirection: 'row', alignItems: 'center' }}>
            <T size={14} w="600" color={C.accent} lh={20}>
              ابدأ
            </T>
            <Icon name={FORWARD} size={15} color={C.accent} style={{ marginHorizontal: 4 }} />
          </View>
        </View>
      )}
    </Pressable>
  );
}
