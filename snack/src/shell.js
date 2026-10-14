// The frame around every screen: a sidebar on iPad (folding to a rail), a drawer on a phone.
import React, { useEffect, useRef } from 'react';
import { Animated, Pressable, ScrollView, StyleSheet, View } from 'react-native';
import { C, R, S, T, ltr, startEdge } from './theme';
import { course } from './data';
import { Icon, IconButton, Segmented } from './controls';
import { Divider } from './ui';
import { LogoMark } from './logo';

const THEMES = [
  { key: 'light', icon: 'sun', label: 'فاتح', iconOnly: true },
  { key: 'dark', icon: 'moon', label: 'داكن', iconOnly: true },
  { key: 'system', icon: 'monitor', label: 'حسب الجهاز', iconOnly: true },
];

function NavRow({ icon, title, active, count, onPress }) {
  return (
    <Pressable onPress={onPress} accessibilityState={{ selected: active }}>
      {({ pressed }) => (
        <View
          style={{
            height: 40,
            borderRadius: R.sm,
            paddingHorizontal: 10,
            flexDirection: 'row',
            alignItems: 'center',
            backgroundColor: active ? C.raised : pressed ? C.raised : 'transparent',
          }}
        >
          <Icon name={icon} size={16} color={active ? C.text : C.text2} />
          <T size={14.5} w={active ? '600' : '500'} color={active ? C.text : C.text2} style={{ flex: 1, marginHorizontal: 10 }} lh={20}>
            {title}
          </T>
          {count !== undefined && (
            <View style={{ minWidth: 22, height: 20, borderRadius: 10, paddingHorizontal: 6, backgroundColor: C.accentSoft, alignItems: 'center', justifyContent: 'center' }}>
              <T size={11.5} w="700" color={C.accent} align="center" lh={14}>
                {String(count)}
              </T>
            </View>
          )}
        </View>
      )}
    </Pressable>
  );
}

function LectureRow({ lecture, active, onPress }) {
  return (
    <Pressable onPress={onPress}>
      {({ pressed }) => (
        <View
          style={{
            minHeight: 38,
            borderRadius: R.sm,
            paddingHorizontal: 10,
            paddingVertical: 6,
            flexDirection: 'row',
            alignItems: 'center',
            backgroundColor: active || pressed ? C.raised : 'transparent',
          }}
        >
          <T size={14} color={active ? C.text : C.text2} w={active ? '600' : '400'} numberOfLines={1} style={{ flex: 1 }} lh={20}>
            {`${ltr(`L${lecture.number}`)} · ${ltr(lecture.title)}`}
          </T>
          {!lecture.ready && <View style={{ width: 6, height: 6, borderRadius: 3, backgroundColor: C.accent, marginHorizontal: 4 }} />}
        </View>
      )}
    </Pressable>
  );
}

/** The full sidebar: new lecture, the three places, recent lectures, course and theme. */
export function Sidebar({ route, go, reviewCount, mode, setMode, onCollapse, onClose, width = 272 }) {
  return (
    <View style={{ width, backgroundColor: C.side, borderLeftWidth: StyleSheet.hairlineWidth, borderColor: C.lineStrong, paddingHorizontal: 12, paddingTop: 14, paddingBottom: 12 }}>
      <View style={{ flexDirection: 'row', alignItems: 'center', paddingHorizontal: 6, height: 40 }}>
        <LogoMark size={26} />
        <T size={19} w="700" style={{ marginHorizontal: 8 }} lh={26}>
          مُعيد
        </T>
        <View style={{ flex: 1 }} />
        {onCollapse && <IconButton name="sidebar" label="طي الشريط الجانبي" onPress={onCollapse} size={36} />}
        {onClose && <IconButton name="x" label="إغلاق" onPress={onClose} size={36} />}
      </View>

      <Pressable onPress={() => go('import')} style={{ marginTop: 14 }}>
        {({ pressed }) => (
          <View
            style={{
              height: 42,
              borderRadius: R.md,
              paddingHorizontal: 12,
              flexDirection: 'row',
              alignItems: 'center',
              backgroundColor: pressed ? C.raised : C.surface,
              borderWidth: StyleSheet.hairlineWidth * 2,
              borderColor: C.lineStrong,
            }}
          >
            <Icon name="plus" size={16} color={C.accent} />
            <T size={14.5} w="600" style={{ marginHorizontal: 10 }} lh={20}>
              محاضرة جديدة
            </T>
          </View>
        )}
      </Pressable>

      <View style={{ marginTop: 14 }}>
        <NavRow icon="home" title="الرئيسية" active={route === 'library'} onPress={() => go('library')} />
        <NavRow icon="rotate-ccw" title="المراجعة" count={reviewCount} active={route === 'review'} onPress={() => go('review')} />
        <NavRow icon="message-circle" title="أسئلتي" count={3} onPress={() => {}} />
      </View>

      <T size={12} w="600" color={C.text3} style={{ marginTop: 20, marginBottom: 4, paddingHorizontal: 10 }} lh={18}>
        الأخيرة
      </T>
      <ScrollView style={{ flex: 1 }}>
        {course.lectures.map((l) => (
          <LectureRow key={l.id} lecture={l} active={route === 'player' && l.ready} onPress={() => go(l.ready ? 'player' : 'import')} />
        ))}
      </ScrollView>

      <Divider style={{ marginBottom: 10 }} />
      <View style={{ flexDirection: 'row', alignItems: 'center', paddingHorizontal: 6 }}>
        <View style={{ width: 32, height: 32, borderRadius: 16, backgroundColor: C.accentSoft, alignItems: 'center', justifyContent: 'center' }}>
          <S size={11} w="700" color={C.accent} align="center" lh={14}>
            {course.code.slice(0, 2)}
          </S>
        </View>
        <View style={{ flex: 1, marginHorizontal: 10 }}>
          <T size={13.5} w="600" numberOfLines={1} lh={18}>
            {course.name}
          </T>
          <S size={12} color={C.text3} lh={16}>
            {course.code}
          </S>
        </View>
        <Segmented options={THEMES} value={mode} onChange={setMode} height={32} style={{ width: 108 }} />
      </View>
    </View>
  );
}

/** The sidebar folded away: just the mark and the places. */
export function Rail({ route, go, reviewCount, onExpand }) {
  return (
    <View style={{ width: 60, backgroundColor: C.side, borderLeftWidth: StyleSheet.hairlineWidth, borderColor: C.lineStrong, alignItems: 'center', paddingTop: 14, paddingBottom: 12 }}>
      <View style={{ height: 40, justifyContent: 'center' }}>
        <LogoMark size={26} />
      </View>
      <IconButton name="sidebar" label="افتح الشريط الجانبي" onPress={onExpand} style={{ marginTop: 10 }} />
      <IconButton name="plus" label="محاضرة جديدة" color={C.accent} onPress={() => go('import')} />
      <IconButton name="home" label="الرئيسية" color={route === 'library' ? C.text : undefined} onPress={() => go('library')} />
      <View>
        <IconButton name="rotate-ccw" label="المراجعة" color={route === 'review' ? C.text : undefined} onPress={() => go('review')} />
        <View style={{ position: 'absolute', top: 6, left: 6, width: 8, height: 8, borderRadius: 4, backgroundColor: reviewCount ? C.accent : 'transparent' }} />
      </View>
    </View>
  );
}

/** On a phone: a slim header, and the sidebar slides in from the reading start. */
export function MobileHeader({ title, onMenu, onNew }) {
  return (
    <View style={{ height: 52, flexDirection: 'row', alignItems: 'center', paddingHorizontal: 6 }}>
      <IconButton name="menu" label="القائمة" onPress={onMenu} />
      <View style={{ flex: 1, flexDirection: 'row', alignItems: 'center', justifyContent: 'center' }}>
        <LogoMark size={20} />
        <T size={16} w="700" style={{ marginHorizontal: 6 }} lh={22}>
          {title}
        </T>
      </View>
      <IconButton name="edit" label="محاضرة جديدة" onPress={onNew} />
    </View>
  );
}

export function Drawer({ open, onClose, children, width = 300 }) {
  const v = useRef(new Animated.Value(open ? 1 : 0)).current;
  useEffect(() => {
    Animated.timing(v, { toValue: open ? 1 : 0, duration: 240, useNativeDriver: true }).start();
  }, [open]);
  const shift = startEdge(0).right !== undefined ? width : -width;
  return (
    <View pointerEvents={open ? 'auto' : 'none'} style={StyleSheet.absoluteFill}>
      <Animated.View style={[StyleSheet.absoluteFill, { backgroundColor: C.scrim, opacity: v }]}>
        <Pressable style={{ flex: 1 }} onPress={onClose} accessibilityLabel="إغلاق" />
      </Animated.View>
      <Animated.View
        style={{
          position: 'absolute',
          top: 0,
          bottom: 0,
          ...startEdge(0),
          width,
          transform: [{ translateX: v.interpolate({ inputRange: [0, 1], outputRange: [shift, 0] }) }],
        }}
      >
        {children}
      </Animated.View>
    </View>
  );
}
