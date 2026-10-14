// Buttons and small instruments, all printed: toner keys, ruled boxes, index tabs.
import React from 'react';
import { Platform, Pressable, View } from 'react-native';
import Svg, { G, Line, Polygon } from 'react-native-svg';
import { Feather } from '@expo/vector-icons';
import * as Haptics from 'expo-haptics';
import { C, T } from './theme';
import { swipePoints, useSize } from './paper';

export function haptic(kind) {
  if (Platform.OS === 'web') return;
  try {
    if (kind === 'success') Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
    else if (kind === 'error') Haptics.notificationAsync(Haptics.NotificationFeedbackType.Error);
    else Haptics.selectionAsync();
  } catch (e) {}
}

// In right-to-left, "forward" points left.
export const FORWARD = 'chevron-left';
export const BACK = 'chevron-right';

export function Icon({ name, size = 15, color = C.ink, style }) {
  return <Feather name={name} size={size} color={color} style={style} />;
}

function Content({ label, icon, trailIcon, color, size, w }) {
  return (
    <View style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'center' }}>
      {icon ? <Icon name={icon} size={size - 1} color={color} style={{ marginHorizontal: 4 }} /> : null}
      {label ? (
        <T size={size} w={w} color={color} align="center" lh={size * 1.35}>
          {label}
        </T>
      ) : null}
      {trailIcon ? <Icon name={trailIcon} size={size - 1} color={color} style={{ marginHorizontal: 4 }} /> : null}
    </View>
  );
}

/**
 * A solid printed key: toner black (or the tutor's red), paper-coloured letters, square corners.
 * Pressing it sinks it into the page instead of dimming it.
 */
export function InkButton({ label, icon, trailIcon, onPress, fill = C.ink, fg = C.paper, height = 48, disabled, style, size = 16 }) {
  return (
    <Pressable onPress={onPress} disabled={disabled} style={[{ opacity: disabled ? 0.35 : 1 }, style]}>
      {({ pressed }) => (
        <View style={{ paddingBottom: 3 }}>
          <View style={{ position: 'absolute', top: 3, left: 0, right: 0, bottom: 0, backgroundColor: 'rgba(23,21,19,0.85)' }} />
          <View
            style={{
              minHeight: height,
              paddingHorizontal: 22,
              justifyContent: 'center',
              backgroundColor: fill,
              transform: [{ translateY: pressed ? 3 : 0 }],
            }}
          >
            <Content label={label} icon={icon} trailIcon={trailIcon} color={fg} size={size} w="700" />
          </View>
        </View>
      )}
    </Pressable>
  );
}

export const RedPenButton = (p) => <InkButton fill={C.red} {...p} />;
export const StampButton = (p) => <InkButton fill={C.stamp} {...p} />;

/** A ruled box: a hairline of ink around the words, nothing behind them. */
export function OutlineButton({ label, icon, trailIcon, onPress, height = 48, style, disabled }) {
  return (
    <Pressable onPress={onPress} disabled={disabled} style={style}>
      {({ pressed }) => (
        <View
          style={{
            minHeight: height,
            paddingHorizontal: 16,
            justifyContent: 'center',
            borderWidth: 1,
            borderColor: C.ink,
            backgroundColor: pressed ? 'rgba(23,21,19,0.08)' : 'transparent',
            opacity: disabled ? 0.35 : 1,
          }}
        >
          <Content label={label} icon={icon} trailIcon={trailIcon} color={C.ink} size={15} w="600" />
        </View>
      )}
    </Pressable>
  );
}

/** A tab in an index: the selected one is printed solid. */
export function Chip({ label, icon, selected, onPress, style, children }) {
  return (
    <Pressable onPress={onPress} style={[{ minHeight: 44, justifyContent: 'center' }, style]}>
      {({ pressed }) => (
        <View
          style={{
            minHeight: 40,
            paddingHorizontal: 14,
            justifyContent: 'center',
            backgroundColor: selected ? C.ink : 'transparent',
            borderWidth: 1,
            borderColor: selected ? C.ink : C.rule,
            opacity: pressed ? 0.75 : 1,
          }}
        >
          {children || <Content label={label} icon={icon} color={selected ? C.paper : C.inkSoft} size={14} w={selected ? '700' : '500'} />}
        </View>
      )}
    </Pressable>
  );
}

/** Words with a pen underline, for quiet navigation like «المكتبة ›». */
export function UnderLink({ label, onPress, icon = BACK }) {
  return (
    <Pressable onPress={onPress} hitSlop={8} style={{ minHeight: 44, justifyContent: 'center', alignSelf: 'flex-start' }}>
      {({ pressed }) => (
        <View style={{ flexDirection: 'row', alignItems: 'center', paddingVertical: 4, borderBottomWidth: 1, borderColor: C.ink, opacity: pressed ? 0.6 : 1 }}>
          <Icon name={icon} size={14} style={{ marginHorizontal: 3 }} />
          <T size={15} w="600" lh={20}>
            {label}
          </T>
        </View>
      )}
    </Pressable>
  );
}

export function SquareIcon({ name, onPress, disabled, label, size = 44 }) {
  return (
    <Pressable
      onPress={onPress}
      disabled={disabled}
      accessibilityLabel={label}
      style={{ width: size, height: size, borderWidth: 1, borderColor: C.ink, alignItems: 'center', justifyContent: 'center', opacity: disabled ? 0.3 : 1 }}
    >
      <Icon name={name} size={17} />
    </Pressable>
  );
}

/** Progress as a highlighter run along a dotted rule, filling from the reading start (the right). */
export function ProgressTrack({ value, height = 10, style }) {
  const [size, onLayout] = useSize();
  const v = Math.min(1, Math.max(0, value));
  return (
    <View onLayout={onLayout} style={[{ height, flex: 1 }, style]}>
      {size && (
        <Svg width={size.w} height={height}>
          <Line x1={2} y1={height / 2} x2={size.w} y2={height / 2} stroke={C.mark} strokeWidth={1.3} strokeLinecap="round" strokeDasharray="0.1 5" />
          {v > 0 && (
            <G transform={`translate(${(size.w * (1 - v)).toFixed(1)},0)`}>
              <Polygon points={swipePoints(size.w * v - 2, height, 2)} fill={C.highlighter} opacity={0.75} />
            </G>
          )}
        </Svg>
      )}
    </View>
  );
}
