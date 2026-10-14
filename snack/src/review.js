// The predictions you got wrong, each with the spot on the slide it came from.
import React, { useState } from 'react';
import { LayoutAnimation, Platform, ScrollView, UIManager, View } from 'react-native';
import { C, R, Rich, S, T, ltr } from './theme';
import { reviewItems, sinePage } from './data';
import { Button, Chip, Icon } from './controls';
import { Card, Column, slideFrame } from './ui';
import { SlideCrop } from './slide';
import { haptic } from './controls';

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

  return (
    <ScrollView style={{ flex: 1 }} contentContainerStyle={{ paddingHorizontal: wide ? 40 : 16, paddingTop: wide ? 40 : 14, paddingBottom: 40 }}>
      <Column>
        <View style={{ flexDirection: wide ? 'row' : 'column', alignItems: wide ? 'flex-end' : 'stretch' }}>
          <View style={{ flex: wide ? 1 : undefined }}>
            <T size={wide ? 30 : 26} w="700" lh={wide ? 42 : 36}>
              المراجعة
            </T>
            <T size={15} color={C.text2} style={{ marginTop: 2 }}>
              التوقّعات اللي غلطت فيها، كل وحدة بمكانها بالضبط في السلايد.
            </T>
          </View>
          <Button label="ابدأ المراجعة" icon="play" disabled={!items.length} onPress={() => go('player')} style={wide ? null : { marginTop: 14 }} />
        </View>

        <View style={{ flexDirection: 'row', flexWrap: 'wrap', marginTop: 18, marginBottom: 6 }}>
          <Chip label={`الكل · ${items.length}`} selected={lecture === null} onPress={() => setLecture(null)} style={{ marginLeft: 8, marginBottom: 8 }} />
          {[5, 4].map((n) => (
            <Chip key={n} selected={lecture === n} onPress={() => setLecture(n)} style={{ marginLeft: 8, marginBottom: 8 }}>
              <S size={14} w={lecture === n ? '600' : '500'} color={lecture === n ? C.inverse : C.text} align="center" lh={20}>
                {`Lecture ${n}`}
              </S>
            </Chip>
          ))}
        </View>

        {visible.length ? (
          visible.map((item) => <ReviewCard key={item.id} item={item} wide={wide} onReplay={() => go('player')} onUnderstood={() => understood(item.id)} />)
        ) : (
          <View style={{ alignItems: 'center', paddingVertical: 80 }}>
            <View style={{ width: 64, height: 64, borderRadius: 32, backgroundColor: C.greenSoft, alignItems: 'center', justifyContent: 'center' }}>
              <Icon name="check" size={28} color={C.green} />
            </View>
            <T size={19} w="700" align="center" style={{ marginTop: 16 }}>
              خلصت المراجعة
            </T>
            <T size={15} color={C.text2} align="center" style={{ marginTop: 4 }}>
              كل التوقّعات اللي غلطت فيها صارت واضحة.
            </T>
          </View>
        )}
      </Column>
    </ScrollView>
  );
}

function ReviewCard({ item, wide, onReplay, onUnderstood }) {
  const crop = (
    <View style={slideFrame()}>
      <SlideCrop page={sinePage} focus={item.focus} w={wide ? 132 : 96} h={wide ? 99 : 72} />
    </View>
  );
  const text = (
    <View style={{ flex: 1, marginHorizontal: wide ? 18 : 12 }}>
      <T size={12.5} w="500" color={C.text3} lh={18}>
        {`${ltr(`Lecture ${item.lecture}`)} · سلايد ${item.page}`}
      </T>
      <Rich text={item.question} size={wide ? 17 : 16} w="600" numberOfLines={2} style={{ marginTop: 4 }} />
      <View style={{ flexDirection: 'row', alignItems: 'center', flexWrap: 'wrap', marginTop: 8 }}>
        <Answer label="جوابك" value={item.yours} color={C.blue} bg={C.blueSoft} struck />
        <View style={{ width: 8 }} />
        <Answer label="الصحيح" value={item.correct} color={C.green} bg={C.greenSoft} />
      </View>
    </View>
  );
  const replay = <Button label="أعد الخطوة" icon="rotate-ccw" kind="secondary" height={38} size={14} onPress={onReplay} style={wide ? null : { flex: 1 }} />;
  const done = <Button label="فهمتها" icon="check" kind="green" height={38} size={14} onPress={onUnderstood} style={wide ? { marginTop: 8 } : { flex: 1, marginRight: 8 }} />;

  return (
    <Card level={0.8} style={{ padding: wide ? 16 : 14, marginTop: 12 }}>
      {wide ? (
        <View style={{ flexDirection: 'row', alignItems: 'center' }}>
          {crop}
          {text}
          <View style={{ width: 140 }}>
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
          <View style={{ flexDirection: 'row', marginTop: 12 }}>
            {replay}
            {done}
          </View>
        </>
      )}
    </Card>
  );
}

function Answer({ label, value, color, bg, struck }) {
  return (
    <View style={{ flexDirection: 'row', alignItems: 'center', height: 30, paddingHorizontal: 10, borderRadius: R.pill, backgroundColor: bg, marginTop: 4 }}>
      <T size={12} color={C.text2} lh={16}>
        {label}
      </T>
      <S size={14.5} w="700" color={color} lh={20} style={{ marginHorizontal: 6, textDecorationLine: struck ? 'line-through' : 'none' }}>
        {ltr(value)}
      </S>
    </View>
  );
}

export const initialReview = reviewItems;
