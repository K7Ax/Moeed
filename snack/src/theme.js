// «الملزمة»: the photocopied lecture packet a معيد goes through with you.
// Paper stock, black toner, the tutor's red pen, your blue ballpoint, a yellow highlighter.
// No glow, no glass, no gradients.
import React from 'react';
import { I18nManager, Platform, Text } from 'react-native';

export const C = {
  desk: '#D9CFBD',
  paper: '#F5EFE3',
  paperShade: '#ECE4D4',
  card: '#FBF8F1',
  sticky: '#F6DF6E',
  tape: 'rgba(237,230,211,0.82)',

  ink: '#171513',
  inkSoft: '#56504A',
  mark: '#8C8579',
  rule: '#CBC2B2',
  hole: '#BDB19C',

  // Red is the tutor's pen: it marks what to look at, never "wrong".
  red: '#C23B22',
  // The student's own ballpoint: your picks, your questions.
  blue: '#24418F',
  blueTint: 'rgba(36,65,143,0.08)',
  highlighter: '#F3D13A',
  // Rubber-stamp teal: done, ready, understood.
  stamp: '#0F5B63',
  spotlight: 'rgba(23,21,19,0.5)',

  // The sample slide is a printed page, so it stays dark-on-light.
  slideTitle: '#1C3D6E',
  slideInk: '#1F2328',
  slideLabel: '#3B424A',
  slideRule: '#D5DAE0',
  slideAxis: '#5B636E',
  slideGuide: '#9AA3AE',
  slideWave: '#2F6DB5',
};

export const F = {
  // Latin, codes and figures are set the way a paper sets them: in a serif.
  serif: Platform.select({ ios: 'Georgia', android: 'serif', default: 'Georgia, "Times New Roman", serif' }),
  // The tutor's handwriting for ink labels.
  hand: Platform.select({ ios: 'Noteworthy-Bold', android: 'casual', default: '"Bradley Hand", "Segoe Print", "Comic Sans MS", cursive' }),
};

// The app lays itself out right-to-left with `direction: 'rtl'` on the root view, so it doesn't
// depend on the device language. Text alignment is the one thing React Native still mirrors
// when the host app runs in RTL, so "start" and "end" are resolved here once.
const swapped = I18nManager.isRTL && I18nManager.doLeftAndRightSwapInRTL !== false;
export const START = swapped ? 'left' : 'right';
export const END = swapped ? 'right' : 'left';

const RLM = '‏';
export const ltr = (s) => '⁦' + s + '⁩';

/** Arabic text: one family, hierarchy by weight and size only. */
export function T({ size = 15, w = '400', color = C.ink, serif, italic, align, lh, style, children, ...rest }) {
  return (
    <Text
      {...rest}
      style={[
        {
          fontSize: size,
          fontWeight: w,
          color,
          textAlign: align || START,
          writingDirection: 'rtl',
          fontFamily: serif ? F.serif : undefined,
          fontStyle: italic ? 'italic' : 'normal',
          lineHeight: lh === undefined ? (serif ? undefined : Math.round(size * 1.45)) : lh,
        },
        style,
      ]}
    >
      {typeof children === 'string' && (!serif || /[؀-ۿ]/.test(children)) ? RLM + children : children}
    </Text>
  );
}

/** Latin / figures in the serif. */
export function S(props) {
  return <T serif align={props.align || START} {...props} />;
}

/** Text between backticks is math or Latin: bold, and kept left-to-right inside the Arabic. */
export function Rich({ text, size = 16, w = '400', color = C.ink, style, ...rest }) {
  const parts = text.split('`');
  return (
    <T size={size} w={w} color={color} style={style} {...rest}>
      {RLM}
      {parts.map((p, i) =>
        i % 2 === 1 ? (
          <Text key={i} style={{ fontWeight: '700' }}>
            {ltr(p)}
          </Text>
        ) : (
          p
        )
      )}
    </T>
  );
}

/** How long a caption phrase stays: 400 ms per Arabic word, 450 per Latin word, 600 per math span. */
export function readingMs(text) {
  let arabic = 0;
  let latin = 0;
  let math = 0;
  text.split('`').forEach((part, i) => {
    if (i % 2 === 1) {
      math += 1;
      return;
    }
    part
      .split(/\s+/)
      .filter(Boolean)
      .forEach((word) => {
        if (/[؀-ۿ]/.test(word)) arabic += 1;
        else if (/[A-Za-z]/.test(word)) latin += 1;
      });
  });
  return 400 * arabic + 450 * latin + 600 * math + 300;
}

export const INK = { stroke: 550, gap: 150 };
export const inkDelay = (i) => i * (INK.stroke + INK.gap);
export const inkTotal = (n) => (n === 0 ? 0 : inkDelay(n - 1) + INK.stroke);

export const easeInOut = (x) => (x < 0.5 ? 2 * x * x : 1 - Math.pow(-2 * x + 2, 2) / 2);
export const clamp01 = (x) => Math.min(1, Math.max(0, x));

// Leading/trailing spacing in the right-to-left layout. Native resolves marginStart against the
// root's `direction`; react-native-web resolves it against I18nManager (always LTR there), so on
// the web the reading start is spelled out as the right-hand side.
const web = Platform.OS === 'web';
export const ms = (n) => (web ? { marginRight: n } : { marginStart: n });
export const me = (n) => (web ? { marginLeft: n } : { marginEnd: n });
export const ps = (n) => (web ? { paddingRight: n } : { paddingStart: n });
export const pe = (n) => (web ? { paddingLeft: n } : { paddingEnd: n });
