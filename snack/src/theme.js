// مُعيد: a quiet study app in the manner of the AI assistants, with the warmth of paper kept.
// Light is cream stock, dark is warm charcoal; the tutor's red pen is the one accent.
// The slide itself is always a printed white page, in both modes.
import React from 'react';
import { I18nManager, Platform, Text } from 'react-native';

const light = {
  bg: '#FAF8F3',
  side: '#F3F0E8',
  surface: '#FFFFFF',
  raised: '#F2EEE6',
  line: 'rgba(40,33,24,0.10)',
  lineStrong: 'rgba(40,33,24,0.18)',
  scrim: 'rgba(20,17,13,0.32)',

  text: '#1F1C18',
  text2: '#6B655C',
  text3: '#9C968C',
  inverse: '#FAF8F3',

  // The tutor's pen.
  accent: '#C2492E',
  accentSoft: 'rgba(194,73,46,0.10)',
  // The student's own pen: your picks, your questions.
  blue: '#2F56B0',
  blueSoft: 'rgba(47,86,176,0.09)',
  // Understood, ready, done.
  green: '#1E7A6C',
  greenSoft: 'rgba(30,122,108,0.10)',

  shadow: 'rgba(40,30,15,1)',
  shadowOpacity: 0.07,
};

const dark = {
  bg: '#1E1D1B',
  side: '#191817',
  surface: '#272623',
  raised: '#32302C',
  line: 'rgba(255,246,230,0.08)',
  lineStrong: 'rgba(255,246,230,0.15)',
  scrim: 'rgba(0,0,0,0.5)',

  text: '#EEEAE3',
  text2: '#A8A297',
  text3: '#76716A',
  inverse: '#1E1D1B',

  accent: '#E5704F',
  accentSoft: 'rgba(229,112,79,0.14)',
  blue: '#8EA7EE',
  blueSoft: 'rgba(142,167,238,0.13)',
  green: '#5BBDA9',
  greenSoft: 'rgba(91,189,169,0.13)',

  shadow: '#000000',
  shadowOpacity: 0.3,
};

// The printed slide and the ink on it never change with the theme.
const page = {
  pen: '#C23B22',
  studentPen: '#24418F',
  studentTint: 'rgba(36,65,143,0.08)',
  spotlight: 'rgba(23,21,19,0.5)',
  slideTitle: '#1C3D6E',
  slideInk: '#1F2328',
  slideLabel: '#3B424A',
  slideRule: '#D5DAE0',
  slideAxis: '#5B636E',
  slideGuide: '#9AA3AE',
  slideWave: '#2F6DB5',
};

/** The live palette. `applyScheme` swaps it in place, and the app re-renders from the root. */
export const C = { ...light, ...page };
let current = 'light';
export function applyScheme(name) {
  if (name === current) return;
  current = name;
  Object.assign(C, name === 'dark' ? dark : light);
}
export const isDark = () => current === 'dark';

/** A soft lift for cards; none in dark, where borders carry the edges. */
export const lift = (level = 1) => ({
  shadowColor: C.shadow,
  shadowOpacity: isDark() ? 0 : C.shadowOpacity * level,
  shadowRadius: 14 * level,
  shadowOffset: { width: 0, height: 4 * level },
  elevation: isDark() ? 0 : 2 * level,
});

export const R = { sm: 10, md: 14, lg: 20, xl: 26, pill: 999 };

export const F = {
  // Latin titles and figures are set in a serif, the way the slides set them.
  serif: Platform.select({ ios: 'Georgia', android: 'serif', default: 'Georgia, "Times New Roman", serif' }),
  // The tutor's handwriting for ink labels on the slide.
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

// MARK: Faces and figures

// IBM Plex Sans Arabic for every Arabic word, Brygada 1918 for the English titles the slides
// carry. They're loaded once at launch (App.js); until they arrive, the system face stands in.
let faces = false;
export const setFacesLoaded = (on) => {
  faces = on;
};
const PLEX = { 100: 300, 200: 300, 300: 300, 400: 400, normal: 400, 500: 500, 600: 600, 700: 700, bold: 700, 800: 700, 900: 700 };

/** The style for a weight: a named face once loaded (custom faces don't synthesise weights). */
export function face(w = '400', serif = false, italic = false) {
  if (!faces) return { fontWeight: String(w), fontFamily: serif ? F.serif : undefined, fontStyle: italic ? 'italic' : 'normal' };
  if (serif) return { fontFamily: italic ? 'Brygada-500i' : Number(w) >= 600 ? 'Brygada-700' : 'Brygada-500', fontWeight: 'normal', fontStyle: 'normal' };
  return { fontFamily: 'Plex-' + (PLEX[w] || 400), fontWeight: 'normal', fontStyle: 'normal' };
}

// Every figure the app writes is an Eastern Arabic one: ١٦ not 16, ٠٫٣ not 0.3. The slide itself
// is the lecturer's page and keeps its own figures.
const EASTERN = '٠١٢٣٤٥٦٧٨٩';
export const digits = (s) => s.replace(/(\d)\.(\d)/g, '$1٫$2').replace(/[0-9]/g, (d) => EASTERN[d]);

function easternize(node) {
  if (typeof node === 'string') return digits(node);
  if (typeof node === 'number') return digits(String(node));
  if (Array.isArray(node)) return node.map(easternize);
  if (React.isValidElement(node) && node.props && node.props.children !== undefined) {
    return React.cloneElement(node, undefined, easternize(node.props.children));
  }
  return node;
}

/** Arabic text: one family, hierarchy by weight and size only. */
export function T({ size = 15, w = '400', color, serif, italic, align, lh, style, children, ...rest }) {
  const body = typeof children === 'string' && (!serif || /[؀-ۿ]/.test(children)) ? RLM + children : children;
  return (
    <Text
      {...rest}
      style={[
        {
          fontSize: size,
          color: color || C.text,
          textAlign: align || START,
          writingDirection: 'rtl',
          lineHeight: lh === undefined ? (serif ? undefined : Math.round(size * 1.55)) : lh,
        },
        face(w, serif, italic),
        style,
      ]}
    >
      {serif ? body : easternize(body)}
    </Text>
  );
}

/** Latin / figures in the serif. */
export function S(props) {
  return <T serif align={props.align || START} {...props} />;
}

/** Text between backticks is math or Latin: bold, and kept left-to-right inside the Arabic. */
export function Rich({ text, size = 16, w = '400', color, style, ...rest }) {
  const parts = text.split('`');
  return (
    <T size={size} w={w} color={color} style={style} {...rest}>
      {RLM}
      {parts.map((p, i) =>
        i % 2 === 1 ? (
          <Text key={i} style={face('700')}>
            {ltr(p.replace(/ /g, ' '))}
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
export const easeOut = (x) => 1 - Math.pow(1 - x, 3);
export const clamp01 = (x) => Math.min(1, Math.max(0, x));

// Leading/trailing spacing in the right-to-left layout. Native resolves marginStart against the
// root's `direction`; react-native-web resolves it against I18nManager (always LTR there), so on
// the web the reading start is spelled out as the right-hand side.
const web = Platform.OS === 'web';
export const ms = (n) => (web ? { marginRight: n } : { marginStart: n });
export const me = (n) => (web ? { marginLeft: n } : { marginEnd: n });
export const ps = (n) => (web ? { paddingRight: n } : { paddingStart: n });
export const pe = (n) => (web ? { paddingLeft: n } : { paddingEnd: n });
/** The physical side where reading starts, for absolutely positioned things. */
export const startEdge = (n) => (swapped ? { left: n } : { right: n });
