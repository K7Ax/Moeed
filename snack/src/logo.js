// The mark: a stair that winds up into an arch, with play waiting in the doorway.
// You climb a lecture step by step. The intro cuts this same image into its pieces, so
// everything here is in the image's own 900×900 space.
import React from 'react';
import { Image } from 'react-native';
import { LOGO_URI } from './logoData';

export { LOGO_URI };

export const LOGO = {
  box: 900,
  // Where the climber's feet land: the door's threshold, then each tread from the bottom
  // step up, ending on the block where the stair turns into the arch.
  spots: [
    [712, 886],
    [565, 762],
    [285, 682],
    [115, 553],
    [262, 368],
  ],
  // The play mark's middle; the climber leaps in here at the end.
  playCenter: [588, 500],
  // The image split into parts that can move on their own. Together they cover the mark.
  pieces: {
    bottom: '0,919 480,727 705,637 705,900 0,900',
    middle: '0,703 480,559 480,727 0,919',
    top: '0,481 480,481 480,559 0,703',
    block: '0,0 355,0 355,481 0,481',
    arch: '355,0 900,0 900,900 705,900 705,380 355,380',
    play: '480,380 705,380 705,720 480,720',
  },
};

export function LogoMark({ size = 28, style }) {
  return (
    <Image
      source={{ uri: LOGO_URI }}
      style={[{ width: size, height: size }, style]}
      resizeMode="contain"
      accessibilityLabel="شعار مُعيد"
    />
  );
}
