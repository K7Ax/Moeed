// The predictions you got wrong, each on an index card with its slide clipped to it.
import React, { useState } from 'react';
import { LayoutAnimation, Platform, ScrollView, UIManager, View } from 'react-native';
import { C, Rich, S, T, ltr, ms, me } from './theme';
import { reviewItems, sinePage } from './data';
import { DoubleRule, Grain, Sheet, paperShadow, slideFrame } from './paper';
import { Ringed, Stamp } from './pen';
import { Chip, InkButton, OutlineButton, StampButton, haptic } from './controls';
import { SlideCrop } from './slide';

if (Platform.OS === 'android' && UIManager.setLayoutAnimationEnabledExperimental) {
  UIManager.setLayoutAnimationEnabledExperimental(true);
}

export function ReviewScreen({ wide, go, items, setItems }) {
  const [lecture, setLecture] = useState(null);
  const visible = items.filter((x) => lecture === null || x.lecture === lecture);

  const understood = (id) => {
    haptic('success');
    LayoutAnimation.configureNext(LayoutAnimation.Presets.easeInEaseOut);
    setItems(items.filter((x) => x.id !== id));
  };

  const header = (
    <View>
      <View style={{ flexDirection: wide ? 'row' : 'column', alignItems: wide ? 'flex-end' : 'stretch' }}>
        <View style={{ flex: wide ? 1 : undefined }}>
          <T size={wide ? 42 : 32} w="900" lh={wide ? 58 : 44}>
            المراجعة
          </T>
          <T size={15} color={C.inkSoft} style={{ marginTop: 4 }}>
            التوقّعات اللي غلطت فيها، كل وحدة مثبّتة على مكانها بالضبط في السلايد.
          </T>
        </View>
        <InkButton
          label="ابدأ المراجعة"
          icon="play"
          height={46}
          disabled={!items.length}
          onPress={() => go('player')}
          style={wide ? { ...ms(16) } : { marginTop: 14 }}
        />
      </View>
      <DoubleRule style={{ marginTop: 14 }} />
      <View style={{ flexDirection: 'row', flexWrap: 'wrap', marginTop: 10 }}>
        <Chip label={`الكل ${items.length}`} selected={lecture === null} onPress={() => setLecture(null)} style={{ ...me(8) }} />
        {[5, 4].map((n) => (
          <Chip key={n} selected={lecture === n} onPress={() => setLecture(n)} style={{ ...me(8) }}>
            <S size={14} w={lecture === n ? '700' : '500'} color={lecture === n ? C.paper : C.inkSoft} align="center" lh={20}>
              {`Lecture ${n}`}
            </S>
          </Chip>
        ))}
      </View>
    </View>
  );

  const list = visible.length ? (
    visible.map((item) => <ReviewCard key={item.id} item={item} wide={wide} onReplay={() => go('player')} onUnderstood={() => understood(item.id)} />)
  ) : (
    <View style={{ alignItems: 'center', paddingVertical: 80 }}>
      <Stamp text="خلصت المراجعة" size={26} angle={-8} style={{ alignSelf: 'center' }} />
      <T size={15} color={C.inkSoft} align="center" style={{ marginTop: 18 }}>
        كل التوقّعات اللي غلطت فيها صارت واضحة.
      </T>
    </View>
  );

  if (!wide) {
    return (
      <ScrollView style={{ flex: 1 }} contentContainerStyle={{ padding: 12, paddingBottom: 24 }}>
        <Sheet style={{ paddingHorizontal: 16, paddingTop: 18, paddingBottom: 20 }}>
          {header}
          <View style={{ marginTop: 18 }}>{list}</View>
        </Sheet>
      </ScrollView>
    );
  }
  return (
    <Sheet style={{ flex: 1 }}>
      <View style={{ paddingHorizontal: 34, paddingTop: 24 }}>{header}</View>
      <ScrollView style={{ flex: 1, marginTop: 18 }} contentContainerStyle={{ paddingHorizontal: 38, paddingBottom: 24 }}>
        {list}
      </ScrollView>
    </Sheet>
  );
}

/** The printing on an index card: a red header line and faint blue rules. */
function IndexCardLines() {
  const lines = [];
  for (let y = 40; y < 400; y += 24) lines.push(y);
  return (
    <View pointerEvents="none" style={{ position: 'absolute', top: 0, left: 0, right: 0, bottom: 4, overflow: 'hidden' }}>
      <View style={{ position: 'absolute', top: 14, left: 0, right: 0, height: 1, backgroundColor: 'rgba(194,59,34,0.55)' }} />
      {lines.map((y) => (
        <View key={y} style={{ position: 'absolute', top: y, left: 0, right: 0, height: 0.75, backgroundColor: 'rgba(36,65,143,0.1)' }} />
      ))}
    </View>
  );
}

/** A ruled index card with the slide clipped on. */
function ReviewCard({ item, wide, onReplay, onUnderstood }) {
  const crop = (
    <View style={[slideFrame, { transform: [{ rotate: item.id % 2 === 0 ? '1.5deg' : '-1.2deg' }] }]}>
      <SlideCrop page={sinePage} focus={item.focus} w={wide ? 120 : 96} h={wide ? 90 : 72} />
    </View>
  );
  const text = (
    <View style={{ flex: 1, marginHorizontal: wide ? 20 : 14 }}>
      <T size={12.5} w="600" color={C.red}>
        {`${ltr(`Lecture ${item.lecture}`)} · سلايد ${item.page}`}
      </T>
      <Rich text={item.question} size={wide ? 18 : 16.5} w="700" numberOfLines={2} style={{ marginTop: 6 }} />
      <View style={{ flexDirection: 'row', alignItems: 'center', flexWrap: 'wrap', marginTop: 8 }}>
        <View style={{ flexDirection: 'row', alignItems: 'center', ...me(18) }}>
          <T size={12.5} color={C.mark} lh={18}>
            جوابك
          </T>
          <S
            size={16}
            w="600"
            color={C.blue}
            lh={22}
            style={{ ...ms(6), textDecorationLine: 'line-through', textDecorationColor: 'rgba(36,65,143,0.7)' }}
          >
            {ltr(item.yours)}
          </S>
        </View>
        <View style={{ flexDirection: 'row', alignItems: 'center' }}>
          <T size={12.5} color={C.mark} lh={18}>
            الصحيح
          </T>
          <Ringed padX={2} padY={4} lw={1.6} style={{ ...ms(6), paddingHorizontal: 6 }}>
            <S size={16} w="700" color={C.red} lh={22}>
              {ltr(item.correct)}
            </S>
          </Ringed>
        </View>
      </View>
    </View>
  );
  const replay = <OutlineButton label="أعد الخطوة" icon="rotate-ccw" height={44} onPress={onReplay} style={wide ? null : { flex: 1 }} />;
  const done = <StampButton label="فهمتها" icon="check" height={44} size={15} onPress={onUnderstood} style={wide ? { marginTop: 8 } : { flex: 1, ...ms(8) }} />;

  return (
    <View style={[{ backgroundColor: C.card, paddingHorizontal: wide ? 18 : 14, paddingTop: 22, paddingBottom: 16, marginBottom: 16 }, paperShadow(0.8)]}>
      <IndexCardLines />
      <Grain density={0.5} />
      {wide ? (
        <View style={{ flexDirection: 'row', alignItems: 'center' }}>
          {crop}
          {text}
          <View style={{ width: 150 }}>
            {replay}
            {done}
          </View>
        </View>
      ) : (
        <>
          <View style={{ flexDirection: 'row', alignItems: 'flex-start' }}>
            {crop}
            {text}
          </View>
          <View style={{ flexDirection: 'row', marginTop: 14 }}>
            {replay}
            {done}
          </View>
        </>
      )}
    </View>
  );
}

export const initialReview = reviewItems;
