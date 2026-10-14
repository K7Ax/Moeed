// The review harness, not part of any design: a list of the directions to open one at a time,
// a thin bar above whichever is open to come back or flip light and dark, and the previous design
// kept reachable for comparison.
import React, { useState } from 'react';
import { Pressable, ScrollView, View } from 'react-native';
import { C, T, isDark } from '../theme';
import { BACK, FORWARD, Icon } from '../controls';
import { LogoMark } from '../logo';
import { hashiya } from './hashiya';
import { misbaha } from './misbaha';
import { stairs } from './stairs';
import { instrument } from './instrument';
import { native } from './native';

export const DIRECTIONS = [native, hashiya, misbaha, stairs, instrument];
const LETTERS = ['جديد', 'أ', 'ب', 'ج', 'د'];

function Bar({ title, onBack, mode, setMode }) {
  const dark = isDark();
  return (
    <View style={{ height: 38, backgroundColor: '#111214', flexDirection: 'row', alignItems: 'center', paddingHorizontal: 12 }}>
      <Pressable onPress={onBack} hitSlop={8} style={{ flexDirection: 'row', alignItems: 'center' }}>
        <Icon name={BACK} size={15} color="#FFFFFF" />
        <T size={13} color="#FFFFFF" style={{ marginHorizontal: 4 }}>
          كل الاتجاهات
        </T>
      </Pressable>
      <View style={{ flex: 1, alignItems: 'center' }}>
        <T size={13} w="700" color="rgba(255,255,255,0.7)">
          {title}
        </T>
      </View>
      <Pressable onPress={() => setMode(dark ? 'light' : 'dark')} hitSlop={8} style={{ flexDirection: 'row', alignItems: 'center' }}>
        <Icon name={dark ? 'sun' : 'moon'} size={14} color="#FFFFFF" />
        <T size={13} color="#FFFFFF" style={{ marginHorizontal: 5 }}>
          {dark ? 'فاتح' : 'داكن'}
        </T>
      </Pressable>
    </View>
  );
}

function Card({ d, letter, onOpen, wide }) {
  return (
    <Pressable onPress={onOpen} style={{ width: wide ? '48%' : '100%', marginBottom: 16 }}>
      {({ pressed }) => (
        <View style={{ borderRadius: 20, backgroundColor: C.surface, borderWidth: 1, borderColor: C.line, overflow: 'hidden', opacity: pressed ? 0.85 : 1 }}>
          <View style={{ flexDirection: 'row', height: 74, direction: 'ltr' }}>
            {d.swatches.map((s, k) => (
              <View key={k} style={{ flex: k === 0 ? 2.2 : 1, backgroundColor: s }} />
            ))}
          </View>
          <View style={{ padding: 18 }}>
            <View style={{ flexDirection: 'row', alignItems: 'center' }}>
              <T size={13} w="800" color={C.text3}>
                {letter}
              </T>
              <T size={24} w="800" color={C.text} style={{ marginHorizontal: 10 }}>
                {d.name}
              </T>
              <View style={{ flex: 1 }} />
              <Icon name={FORWARD} size={18} color={C.text2} />
            </View>
            <T size={15} color={C.text2} lh={25} style={{ marginTop: 6 }}>
              {d.line}
            </T>
            <T size={12} color={C.text3} style={{ marginTop: 10 }}>
              {'مراجع: ' + d.refs}
            </T>
          </View>
        </View>
      )}
    </Pressable>
  );
}

export function ConceptsRoot({ wide, mode, setMode, legacy }) {
  // The newest direction opens first; the others stay one tap away for comparison.
  const [open, setOpen] = useState('native');
  const d = DIRECTIONS.find((x) => x.key === open);
  if (open === 'legacy') {
    return (
      <View style={{ flex: 1 }}>
        <Bar title="الواجهة السابقة" onBack={() => setOpen(null)} mode={mode} setMode={setMode} />
        <View style={{ flex: 1 }}>{legacy}</View>
      </View>
    );
  }
  if (d) {
    const App = d.App;
    return (
      <View style={{ flex: 1 }}>
        <Bar title={d.name} onBack={() => setOpen(null)} mode={mode} setMode={setMode} />
        <View style={{ flex: 1 }}>
          <App key={d.key} wide={wide} />
        </View>
      </View>
    );
  }
  return (
    <ScrollView style={{ flex: 1, backgroundColor: C.bg }} contentContainerStyle={{ padding: wide ? 40 : 18, paddingBottom: 48, maxWidth: 1100, width: '100%', alignSelf: 'center' }}>
      <View style={{ flexDirection: 'row', alignItems: 'center' }}>
        <LogoMark size={34} />
        <View style={{ flex: 1, marginHorizontal: 12 }}>
          <T size={wide ? 28 : 22} w="800" color={C.text}>
            اختر اتجاه مُعيد
          </T>
          <T size={14} color={C.text2}>
            «الأصلي» مبني على أنماط تطبيقات أبل الكبيرة، والأربعة بعده تجارب سابقة. كل واحد فيه الرئيسية والمشغّل، فاتح وداكن.
          </T>
        </View>
        <Pressable onPress={() => setMode(isDark() ? 'light' : 'dark')} hitSlop={8} style={{ padding: 8 }}>
          <Icon name={isDark() ? 'sun' : 'moon'} size={20} color={C.text2} />
        </Pressable>
      </View>
      <View style={{ flexDirection: 'row', flexWrap: 'wrap', justifyContent: 'space-between', marginTop: 24 }}>
        {DIRECTIONS.map((x, k) => (
          <Card key={x.key} d={x} letter={LETTERS[k]} wide={wide} onOpen={() => setOpen(x.key)} />
        ))}
      </View>
      <T size={13} color={C.text3} lh={22} style={{ marginTop: 8 }}>
        في كل اتجاه: افتح المحاضرة الخامسة، وجرّب الخطوة الرابعة (سؤال قبل الكشف)، والمس حبر خطوة سابقة على السلايد يرجعك لها.
      </T>
      <Pressable onPress={() => setOpen('legacy')} style={{ marginTop: 18, alignSelf: 'flex-start' }}>
        <T size={14} w="600" color={C.text2} style={{ textDecorationLine: 'underline' }}>
          قارن بالواجهة السابقة
        </T>
      </Pressable>
    </ScrollView>
  );
}
