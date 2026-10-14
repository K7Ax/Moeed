// The course as the directions show it. Lectures 5 and 6 are the app's samples (data.js); the
// earlier ones are filled in so the overview has a past.
import { lecture5, lecture6 } from '../data';

export const LECTURES = [
  { n: 1, ar: 'مدخل إلى الدوائر', en: 'Circuit Basics', pages: 34, done: 1 },
  { n: 2, ar: 'قانون أوم والقدرة', en: "Ohm's Law & Power", pages: 41, done: 1 },
  { n: 3, ar: 'قانونا كيرشوف', en: "Kirchhoff's Laws", pages: 46, done: 1 },
  { n: 4, ar: 'المكثّفات والملفّات', en: 'Capacitors & Inductors', pages: 39, done: 1 },
  { n: lecture5.number, ar: 'الموجات الجيبية', en: lecture5.title, pages: lecture5.slideCount, done: lecture5.progress, current: true, page: 16 },
  { n: lecture6.number, ar: 'الطور والمتّجهات', en: lecture6.title, pages: lecture6.slideCount, done: 0, preparing: lecture6.preparing },
];

export const ORDINAL = ['الأولى', 'الثانية', 'الثالثة', 'الرابعة', 'الخامسة', 'السادسة'];
