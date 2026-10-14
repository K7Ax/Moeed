// Surfaces and small pieces shared by every screen.
import React, { useCallback, useEffect, useRef, useState } from 'react';
import { Animated, Easing, StyleSheet, View } from 'react-native';
import Svg, { Circle } from 'react-native-svg';
import { C, R, T, lift, startEdge } from './theme';
import { Icon } from './controls';
import { LogoMark } from './logo';

/** Measures a view: `const [size, onLayout] = useSize()`. */
export function useSize() {
  const [size, setSize] = useState(null);
  const onLayout = useCallback((e) => {
    const { width, height } = e.nativeEvent.layout;
    setSize((s) => (s && Math.abs(s.w - width) < 0.5 && Math.abs(s.h - height) < 0.5 ? s : { w: width, h: height }));
  }, []);
  return [size, onLayout];
}

export function Card({ style, children, level = 1, radius = R.lg, ...rest }) {
  return (
    <View
      {...rest}
      style={[{ backgroundColor: C.surface, borderRadius: radius, borderWidth: StyleSheet.hairlineWidth, borderColor: C.lineStrong }, lift(level), style]}
    >
      {children}
    </View>
  );
}

export function Divider({ style, inset = 0 }) {
  return <View style={[{ height: StyleSheet.hairlineWidth, backgroundColor: C.lineStrong, marginHorizontal: inset }, style]} />;
}

/** The centred reading column the assistants use. */
export function Column({ max = 760, style, children }) {
  return <View style={[{ width: '100%', maxWidth: max, alignSelf: 'center' }, style]}>{children}</View>;
}

const tones = () => ({
  accent: [C.accentSoft, C.accent],
  blue: [C.blueSoft, C.blue],
  green: [C.greenSoft, C.green],
  neutral: [C.raised, C.text2],
});

export function Pill({ label, tone = 'neutral', icon, style }) {
  const [bg, fg] = tones()[tone];
  return (
    <View style={[{ flexDirection: 'row', alignItems: 'center', alignSelf: 'flex-start', backgroundColor: bg, borderRadius: R.pill, paddingHorizontal: 10, height: 26 }, style]}>
      {icon ? <Icon name={icon} size={12} color={fg} style={{ marginHorizontal: 3 }} /> : null}
      <T size={12.5} w="600" color={fg} lh={16}>
        {label}
      </T>
    </View>
  );
}

/** A thin bar filling from the reading start (the right). */
export function ProgressBar({ value, height = 4, color, track, style }) {
  const v = Math.min(1, Math.max(0, value));
  return (
    <View style={[{ height, borderRadius: height, backgroundColor: track || C.raised, overflow: 'hidden', flex: 1 }, style]}>
      <View style={{ position: 'absolute', top: 0, bottom: 0, ...startEdge(0), width: `${v * 100}%`, borderRadius: height, backgroundColor: color || C.accent }} />
    </View>
  );
}

/** A small arc turning: work in progress. */
export function Spinner({ size = 16, color, width = 2 }) {
  const spin = useRef(new Animated.Value(0)).current;
  useEffect(() => {
    const loop = Animated.loop(Animated.timing(spin, { toValue: 1, duration: 900, easing: Easing.linear, useNativeDriver: true }));
    loop.start();
    return () => loop.stop();
  }, []);
  const r = (size - width) / 2;
  const c = 2 * Math.PI * r;
  return (
    <Animated.View style={{ width: size, height: size, transform: [{ rotate: spin.interpolate({ inputRange: [0, 1], outputRange: ['0deg', '360deg'] }) }] }}>
      <Svg width={size} height={size}>
        <Circle cx={size / 2} cy={size / 2} r={r} stroke={C.lineStrong} strokeWidth={width} fill="none" />
        <Circle
          cx={size / 2}
          cy={size / 2}
          r={r}
          stroke={color || C.accent}
          strokeWidth={width}
          fill="none"
          strokeLinecap="round"
          strokeDasharray={`${c * 0.28} ${c}`}
        />
      </Svg>
    </Animated.View>
  );
}

/** Three dots breathing: the tutor is about to speak. */
export function Typing({ color }) {
  const v = useRef(new Animated.Value(0)).current;
  useEffect(() => {
    const loop = Animated.loop(Animated.timing(v, { toValue: 1, duration: 1100, easing: Easing.linear, useNativeDriver: true }));
    loop.start();
    return () => loop.stop();
  }, []);
  return (
    <View style={{ flexDirection: 'row', height: 22, alignItems: 'center' }}>
      {[0, 1, 2].map((i) => (
        <Animated.View
          key={i}
          style={{
            width: 6,
            height: 6,
            borderRadius: 3,
            marginHorizontal: 2.5,
            backgroundColor: color || C.text3,
            opacity: v.interpolate({
              inputRange: [0, 0.2 + i * 0.15, 0.45 + i * 0.15, 1],
              outputRange: [0.3, 1, 0.3, 0.3],
              extrapolate: 'clamp',
            }),
          }}
        />
      ))}
    </View>
  );
}

/** The tutor's avatar beside its messages. */
export function TutorAvatar({ size = 28 }) {
  return (
    <View
      style={{
        width: size,
        height: size,
        borderRadius: size / 2,
        backgroundColor: C.raised,
        borderWidth: StyleSheet.hairlineWidth,
        borderColor: C.lineStrong,
        alignItems: 'center',
        justifyContent: 'center',
      }}
    >
      <LogoMark size={size * 0.62} />
    </View>
  );
}

/** A message from the tutor: avatar at the reading start, words beside it. */
export function TutorMessage({ children, style, avatar = 28 }) {
  return (
    <View style={[{ flexDirection: 'row', alignItems: 'flex-start' }, style]}>
      <TutorAvatar size={avatar} />
      <View style={{ flex: 1, marginHorizontal: 12, paddingTop: 2 }}>{children}</View>
    </View>
  );
}

export function SectionTitle({ title, detail, right, style }) {
  return (
    <View style={[{ flexDirection: 'row', alignItems: 'center', marginBottom: 10 }, style]}>
      <T size={15} w="700" lh={22}>
        {title}
      </T>
      {detail ? (
        <T size={13} color={C.text3} lh={22} style={{ marginHorizontal: 8 }}>
          {detail}
        </T>
      ) : null}
      <View style={{ flex: 1 }} />
      {right}
    </View>
  );
}

/** A printed slide sitting in the interface: white page, rounded, one hairline. */
export const slideFrame = () => ({
  borderRadius: R.md,
  overflow: 'hidden',
  backgroundColor: '#FFFFFF',
  borderWidth: StyleSheet.hairlineWidth,
  borderColor: C.lineStrong,
});
