// مُعيد · «الملزمة» — an Expo Snack preview of the iPad app's screens.
// The real app is SwiftUI (K7Ax/Moeed); this mirrors its design so it can be tried in Expo Go.
import React, { useState } from 'react';
import { StatusBar, View, useWindowDimensions } from 'react-native';
import { SafeAreaProvider, SafeAreaView } from 'react-native-safe-area-context';
import { C } from './src/theme';
import { sinePage } from './src/data';
import { Desk } from './src/paper';
import { IndexTabs, Sidebar } from './src/shell';
import { LibraryScreen } from './src/library';
import { PlayerScreen } from './src/player';
import { ReviewScreen, initialReview } from './src/review';
import { ImportScreen } from './src/import';

export default function App() {
  const { width } = useWindowDimensions();
  const wide = width >= 900;
  const [route, setRoute] = useState('library');
  const [items, setItems] = useState(initialReview);
  const reviewCount = items.length + 2;
  const nav = { route, go: setRoute, reviewCount };

  let screen;
  if (route === 'player') screen = <PlayerScreen page={sinePage} wide={wide} onBack={() => setRoute('library')} />;
  else if (route === 'import') screen = <ImportScreen wide={wide} go={setRoute} />;
  else if (route === 'review') screen = <ReviewScreen wide={wide} go={setRoute} items={items} setItems={setItems} />;
  else screen = <LibraryScreen wide={wide} go={setRoute} reviewCount={reviewCount} />;

  // On iPad the library and review sit beside the bound index page; on a phone the index is tabs.
  const bound = route === 'library' || route === 'review';
  let body;
  if (route === 'player') body = screen;
  else if (wide && bound) {
    body = (
      <Desk style={{ flexDirection: 'row', padding: 16 }}>
        <Sidebar {...nav} />
        {screen}
      </Desk>
    );
  } else if (wide) body = <Desk>{screen}</Desk>;
  else {
    body = (
      <Desk>
        <View style={{ flex: 1 }}>{screen}</View>
        <IndexTabs {...nav} />
      </Desk>
    );
  }

  return (
    <SafeAreaProvider>
      <StatusBar barStyle="dark-content" />
      <SafeAreaView style={{ flex: 1, backgroundColor: C.desk }} edges={['top', 'bottom', 'left', 'right']}>
        <View style={{ flex: 1, direction: 'rtl' }}>{body}</View>
      </SafeAreaView>
    </SafeAreaProvider>
  );
}
