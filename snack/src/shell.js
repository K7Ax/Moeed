// The packet's binding: the index page down the side on iPad, index tabs along the bottom on a phone.
import React from 'react';
import { Pressable, View } from 'react-native';
import { C, S, T } from './theme';
import { course } from './data';
import { Coil, DoubleRule, Grain, Hairline, Highlight, Leader, useSize } from './paper';
import { PenRing } from './pen';
import { Icon } from './controls';

/** The app's mark until the real logo is in: a toner block with the tutor's ring on it. */
export function LogoSlot({ size = 34 }) {
  return (
    <View style={{ width: size, height: size, backgroundColor: C.ink, alignItems: 'center', justifyContent: 'center' }}>
      <T size={size * 0.55} w="900" color={C.paper} align="center" lh={size * 0.8}>
        م
      </T>
      <PenRing w={size * 0.5} h={size * 0.42} lw={1.6} style={{ top: size * 0.3, left: size * 0.22 }} />
    </View>
  );
}

function IndexRow({ title, page, active, count, quiet, onPress }) {
  return (
    <Pressable onPress={onPress} accessibilityState={{ selected: active }} style={{ minHeight: 44, flexDirection: 'row', alignItems: 'center' }}>
      <Highlight on={active} seed={page}>
        <T size={16} w={active ? '800' : '500'} color={active ? C.ink : C.inkSoft} lh={22}>
          {title}
        </T>
      </Highlight>
      {count !== undefined && (
        <View style={{ width: 22, height: 22, alignItems: 'center', justifyContent: 'center', marginStart: 8 }}>
          <S size={13} w="700" color={quiet ? C.mark : C.red} align="center" lh={16}>
            {String(count)}
          </S>
          {!quiet && <PenRing w={22} h={22} lw={1.6} />}
        </View>
      )}
      <Leader style={{ marginHorizontal: 8 }} />
      <S size={13} color={C.mark} lh={18}>
        {`ص ${page}`}
      </S>
    </Pressable>
  );
}

/** The index page, bound to the rest of the packet by a wire coil. */
export function Sidebar({ route, go, reviewCount }) {
  const [size, onLayout] = useSize();
  return (
    <View
      onLayout={onLayout}
      style={{
        width: 260,
        backgroundColor: C.paperShade,
        paddingStart: 24,
        paddingEnd: 34,
        paddingVertical: 28,
        zIndex: 1,
        shadowColor: C.ink,
        shadowOpacity: 0.14,
        shadowRadius: 6,
        shadowOffset: { width: 0, height: 0 },
        elevation: 4,
      }}
    >
      <Grain density={0.7} />
      <View style={{ flexDirection: 'row', alignItems: 'center' }}>
        <LogoSlot />
        <T size={30} w="900" style={{ marginStart: 10 }} lh={40}>
          مُعيد
        </T>
      </View>
      <T size={12.5} w="500" color={C.inkSoft} style={{ marginTop: 6 }}>
        ملزمة الشرح
      </T>
      <DoubleRule style={{ marginTop: 14 }} />

      <T size={12} w="700" color={C.mark} style={{ marginTop: 22, marginBottom: 6 }}>
        الفهرس
      </T>
      <IndexRow title="المكتبة" page={1} active={route === 'library'} onPress={() => go('library')} />
      <IndexRow title="المراجعة" page={5} active={route === 'review'} count={reviewCount} onPress={() => go('review')} />
      <IndexRow title="أسئلتي" page={9} count={3} quiet onPress={() => {}} />

      <T size={12} w="700" color={C.mark} style={{ marginTop: 26, marginBottom: 8 }}>
        موادي
      </T>
      <View style={{ flexDirection: 'row', alignItems: 'baseline', minHeight: 36 }}>
        <S size={15} w="700" lh={20}>
          {course.code}
        </S>
        <T size={14.5} w="600" style={{ marginStart: 8 }} lh={20}>
          {course.name}
        </T>
      </View>
      <Hairline color={C.rule} />
      <Pressable onPress={() => go('import')} style={{ minHeight: 44, flexDirection: 'row', alignItems: 'center' }}>
        <Icon name="plus" size={13} color={C.inkSoft} />
        <T size={14.5} w="500" color={C.inkSoft} style={{ marginStart: 8 }} lh={20}>
          أضف مادة
        </T>
      </Pressable>

      <View style={{ flex: 1 }} />
      <Hairline color={C.rule} />
      <T size={12} color={C.mark} style={{ marginTop: 10 }}>
        ملفاتك تبقى على جهازك. الشرح يتجهّز مرة وحدة لكل محاضرة.
      </T>

      {size && (
        <View pointerEvents="none" style={{ position: 'absolute', top: 0, bottom: 0, left: -14 }}>
          <Coil height={size.h} />
        </View>
      )}
    </View>
  );
}

/** On a phone the index becomes tabs cut into the bottom edge of the packet. */
export function IndexTabs({ route, go, reviewCount }) {
  const tabs = [
    { key: 'library', title: 'المكتبة', icon: 'book-open' },
    { key: 'review', title: 'المراجعة', icon: 'rotate-ccw', count: reviewCount },
    { key: 'import', title: 'أضف محاضرة', icon: 'scissors' },
  ];
  return (
    <View style={{ backgroundColor: C.paperShade, borderTopWidth: 0.75, borderColor: C.ink, flexDirection: 'row' }}>
      <Grain density={0.7} />
      {tabs.map((t) => {
        const active = route === t.key;
        return (
          <Pressable
            key={t.key}
            onPress={() => go(t.key)}
            accessibilityState={{ selected: active }}
            style={{ flex: 1, alignItems: 'center', paddingTop: 8, paddingBottom: 6, minHeight: 52 }}
          >
            <View style={{ flexDirection: 'row', alignItems: 'center' }}>
              <Icon name={t.icon} size={16} color={active ? C.ink : C.mark} />
              {t.count !== undefined && (
                <S size={11.5} w="700" color={C.red} lh={14} style={{ marginStart: 5 }}>
                  {String(t.count)}
                </S>
              )}
            </View>
            <Highlight on={active} seed={t.title.length} style={{ alignSelf: 'center', marginTop: 3 }}>
              <T size={12.5} w={active ? '800' : '500'} color={active ? C.ink : C.inkSoft} align="center" lh={17}>
                {t.title}
              </T>
            </Highlight>
          </Pressable>
        );
      })}
    </View>
  );
}
