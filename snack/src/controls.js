// Buttons and small instruments: quiet, rounded, one solid key per screen.
import React from 'react';
import { Platform, Pressable, StyleSheet, TextInput, View } from 'react-native';
import { Feather } from '@expo/vector-icons';
import * as Haptics from 'expo-haptics';
import { C, R, START, T } from './theme';

export function haptic(kind) {
  if (Platform.OS === 'web') return;
  try {
    if (kind === 'success') Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
    else if (kind === 'error') Haptics.notificationAsync(Haptics.NotificationFeedbackType.Error);
    else Haptics.selectionAsync();
  } catch (e) {}
}

// In right-to-left, "forward" points left.
export const FORWARD = 'arrow-left';
export const BACK = 'chevron-right';

export function Icon({ name, size = 16, color, style }) {
  return <Feather name={name} size={size} color={color || C.text} style={style} />;
}

const kinds = () => ({
  primary: { bg: C.text, fg: C.inverse, border: 'transparent', pressed: 0.82 },
  accent: { bg: C.accent, fg: '#FFFFFF', border: 'transparent', pressed: 0.85 },
  green: { bg: C.green, fg: '#FFFFFF', border: 'transparent', pressed: 0.85 },
  secondary: { bg: C.surface, fg: C.text, border: C.lineStrong, pressed: 0.7 },
  ghost: { bg: 'transparent', fg: C.text2, border: 'transparent', pressed: 0.55 },
});

export function Button({ label, icon, trailIcon, onPress, kind = 'primary', height = 44, size = 15, disabled, style }) {
  const k = kinds()[kind];
  return (
    <Pressable onPress={onPress} disabled={disabled} style={[{ opacity: disabled ? 0.38 : 1 }, style]}>
      {({ pressed }) => (
        <View
          style={{
            minHeight: height,
            paddingHorizontal: kind === 'ghost' ? 10 : 18,
            borderRadius: R.pill,
            flexDirection: 'row',
            alignItems: 'center',
            justifyContent: 'center',
            backgroundColor: k.bg,
            borderWidth: k.border === 'transparent' ? 0 : StyleSheet.hairlineWidth * 2,
            borderColor: k.border,
            opacity: pressed ? k.pressed : 1,
          }}
        >
          {icon ? <Icon name={icon} size={size} color={k.fg} style={{ marginHorizontal: 4 }} /> : null}
          {label ? (
            <T size={size} w="600" color={k.fg} align="center" lh={size * 1.4}>
              {label}
            </T>
          ) : null}
          {trailIcon ? <Icon name={trailIcon} size={size} color={k.fg} style={{ marginHorizontal: 4 }} /> : null}
        </View>
      )}
    </Pressable>
  );
}

export function IconButton({ name, onPress, label, size = 40, iconSize = 18, color, filled, disabled, style }) {
  return (
    <Pressable onPress={onPress} disabled={disabled} accessibilityLabel={label} hitSlop={4} style={[{ opacity: disabled ? 0.3 : 1 }, style]}>
      {({ pressed }) => (
        <View
          style={{
            width: size,
            height: size,
            borderRadius: size / 2,
            alignItems: 'center',
            justifyContent: 'center',
            backgroundColor: filled ? C.text : pressed ? C.raised : 'transparent',
          }}
        >
          <Icon name={name} size={iconSize} color={filled ? C.inverse : color || C.text2} />
        </View>
      )}
    </Pressable>
  );
}

/** A rounded suggestion or filter. */
export function Chip({ label, icon, selected, onPress, style, children }) {
  return (
    <Pressable onPress={onPress} style={style}>
      {({ pressed }) => (
        <View
          style={{
            minHeight: 36,
            paddingHorizontal: 14,
            borderRadius: R.pill,
            flexDirection: 'row',
            alignItems: 'center',
            justifyContent: 'center',
            backgroundColor: selected ? C.text : pressed ? C.raised : C.surface,
            borderWidth: StyleSheet.hairlineWidth * 2,
            borderColor: selected ? C.text : C.lineStrong,
          }}
        >
          {icon ? <Icon name={icon} size={14} color={selected ? C.inverse : C.text2} style={{ marginHorizontal: 3 }} /> : null}
          {children ||
            (label ? (
              <T size={14} w={selected ? '600' : '500'} color={selected ? C.inverse : C.text} lh={20}>
                {label}
              </T>
            ) : null)}
        </View>
      )}
    </Pressable>
  );
}

/** Two or three options in a rounded track, one of them raised. */
export function Segmented({ options, value, onChange, height = 34, style }) {
  return (
    <View style={[{ flexDirection: 'row', backgroundColor: C.raised, borderRadius: R.pill, padding: 3 }, style]}>
      {options.map((o) => {
        const on = o.key === value;
        return (
          <Pressable
            key={o.key}
            onPress={() => onChange(o.key)}
            accessibilityLabel={o.label}
            accessibilityState={{ selected: on }}
            style={{
              flex: o.label && !o.iconOnly ? undefined : 1,
              height: height - 6,
              paddingHorizontal: 12,
              borderRadius: R.pill,
              flexDirection: 'row',
              alignItems: 'center',
              justifyContent: 'center',
              backgroundColor: on ? C.surface : 'transparent',
              borderWidth: on ? StyleSheet.hairlineWidth : 0,
              borderColor: C.lineStrong,
            }}
          >
            {o.icon ? <Icon name={o.icon} size={14} color={on ? C.text : C.text3} style={{ marginHorizontal: 3 }} /> : null}
            {o.label && !o.iconOnly ? (
              <T size={13.5} w={on ? '600' : '500'} color={on ? C.text : C.text2} lh={18}>
                {o.label}
              </T>
            ) : null}
          </Pressable>
        );
      })}
    </View>
  );
}

/** A toggle shown as a pill that fills when on. */
export function Toggle({ label, icon, on, onPress }) {
  return (
    <Pressable onPress={onPress} accessibilityState={{ checked: on }}>
      {({ pressed }) => (
        <View
          style={{
            height: 34,
            paddingHorizontal: 12,
            borderRadius: R.pill,
            flexDirection: 'row',
            alignItems: 'center',
            backgroundColor: on ? C.accentSoft : pressed ? C.raised : 'transparent',
            borderWidth: StyleSheet.hairlineWidth * 2,
            borderColor: on ? 'transparent' : C.lineStrong,
          }}
        >
          <Icon name={icon} size={14} color={on ? C.accent : C.text3} style={{ marginHorizontal: 3 }} />
          <T size={13.5} w="600" color={on ? C.accent : C.text2} lh={18}>
            {label}
          </T>
        </View>
      )}
    </Pressable>
  );
}

/** The round send key. */
export function SendButton({ onPress, active = true, size = 36 }) {
  return (
    <Pressable onPress={onPress} accessibilityLabel="أرسل" hitSlop={4}>
      {({ pressed }) => (
        <View
          style={{
            width: size,
            height: size,
            borderRadius: size / 2,
            alignItems: 'center',
            justifyContent: 'center',
            backgroundColor: active ? C.accent : C.raised,
            opacity: pressed ? 0.8 : 1,
          }}
        >
          <Icon name="arrow-up" size={18} color={active ? '#FFFFFF' : C.text3} />
        </View>
      )}
    </Pressable>
  );
}

/** The message box every assistant has: words in, a row of tools, the send key. */
export function Composer({ value, onChangeText, placeholder, onSend, tools, minHeight = 52, style }) {
  return (
    <View
      style={[
        {
          backgroundColor: C.surface,
          borderRadius: R.xl,
          borderWidth: StyleSheet.hairlineWidth * 2,
          borderColor: C.lineStrong,
          paddingHorizontal: 14,
          paddingTop: 10,
          paddingBottom: 8,
        },
        style,
      ]}
    >
      <TextInput
        value={value}
        onChangeText={onChangeText}
        placeholder={placeholder}
        placeholderTextColor={C.text3}
        multiline
        style={{
          minHeight,
          fontSize: 16,
          lineHeight: 24,
          color: C.text,
          textAlign: START,
          writingDirection: 'rtl',
          textAlignVertical: 'top',
          paddingHorizontal: 4,
          paddingVertical: 4,
          outlineStyle: 'none',
        }}
      />
      <View style={{ flexDirection: 'row', alignItems: 'center', marginTop: 4 }}>
        {tools}
        <View style={{ flex: 1 }} />
        <SendButton onPress={onSend} active={!!(value && value.trim())} />
      </View>
    </View>
  );
}
