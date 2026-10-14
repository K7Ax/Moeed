// مُعيد: an Expo Snack preview of the iPad app's screens.
// The real app is SwiftUI (K7Ax/Moeed); this mirrors its design so it can be tried in Expo Go.
import React, { useState } from 'react';
import { StatusBar, View, useColorScheme, useWindowDimensions } from 'react-native';
import { SafeAreaProvider, SafeAreaView } from 'react-native-safe-area-context';
import { C, applyScheme } from './src/theme';
import { sinePage } from './src/data';
import { Drawer, MobileHeader, Rail, Sidebar } from './src/shell';
import { LibraryScreen } from './src/library';
import { PlayerScreen } from './src/player';
import { ReviewScreen, initialReview } from './src/review';
import { ImportScreen } from './src/import';
import { Intro } from './src/intro';
import { ConceptsRoot } from './src/concepts/gallery';

const TITLES = { library: 'مُعيد', review: 'المراجعة', import: 'محاضرة جديدة', player: 'الشرح' };

export default function App() {
  const { width } = useWindowDimensions();
  const system = useColorScheme();
  const [mode, setMode] = useState('system');
  const scheme = mode === 'system' ? (system === 'dark' ? 'dark' : 'light') : mode;
  // The palette is swapped before anything below reads it.
  applyScheme(scheme);

  const wide = width >= 900;
  const [intro, setIntro] = useState(true);
  const [route, setRoute] = useState('library');
  const [collapsed, setCollapsed] = useState(false);
  const [drawer, setDrawer] = useState(false);
  const [items, setItems] = useState(initialReview);
  const reviewCount = items.length + 2;

  const go = (r) => {
    setRoute(r);
    setDrawer(false);
    // The player wants the whole width; the sidebar folds to a rail there and opens again after.
    setCollapsed(r === 'player' || r === 'import');
  };
  const nav = { route, go, reviewCount, mode, setMode };

  let screen;
  if (route === 'player') screen = <PlayerScreen page={sinePage} wide={wide} onBack={() => go('library')} />;
  else if (route === 'import') screen = <ImportScreen wide={wide} go={go} />;
  else if (route === 'review') screen = <ReviewScreen wide={wide} go={go} items={items} setItems={setItems} />;
  else screen = <LibraryScreen wide={wide} go={go} reviewCount={reviewCount} />;

  let body;
  if (wide) {
    body = (
      <View style={{ flex: 1, flexDirection: 'row' }}>
        {collapsed ? <Rail {...nav} onExpand={() => setCollapsed(false)} /> : <Sidebar {...nav} onCollapse={() => setCollapsed(true)} />}
        <View style={{ flex: 1 }}>{screen}</View>
      </View>
    );
  } else {
    const bare = route === 'player' || route === 'import';
    body = (
      <View style={{ flex: 1 }}>
        {!bare && <MobileHeader title={TITLES[route]} onMenu={() => setDrawer(true)} onNew={() => go('import')} />}
        <View style={{ flex: 1 }}>{screen}</View>
        <Drawer open={drawer} onClose={() => setDrawer(false)}>
          <Sidebar {...nav} width={300} onClose={() => setDrawer(false)} />
        </Drawer>
      </View>
    );
  }

  return (
    <SafeAreaProvider>
      <StatusBar barStyle={scheme === 'dark' ? 'light-content' : 'dark-content'} />
      <SafeAreaView style={{ flex: 1, backgroundColor: C.bg }} edges={['top', 'bottom', 'left', 'right']}>
        <View style={{ flex: 1, direction: 'rtl', backgroundColor: C.bg }}>
          {/* For now the app opens on the design directions; the previous design is one of the entries. */}
          <ConceptsRoot wide={wide} mode={mode} setMode={setMode} legacy={body} />
          {intro && <Intro onDone={() => setIntro(false)} />}
        </View>
      </SafeAreaView>
    </SafeAreaProvider>
  );
}
