// Sample content, mirroring MoeedCore/Samples.swift. The slide is our own drawing
// (a sine-wave reading exercise), not taken from any course material.

const floatingCard = [470, 110, 310, 100];
const lowerCard = [40, 446, 280, 104];

export const readAtTimeAsk = {
  question: 'كم قيمة الموجة عند `t = 0.3 s`؟',
  options: [
    { id: 'pos', label: '8 V' },
    { id: 'zero', label: '0 V' },
    { id: 'neg', label: '−8 V' },
  ],
  answerID: 'neg',
  hint: 'الخط المتقطع عند `0.3 s` يقطع الموجة وين؟ فوق المحور ولا تحته؟',
  why: 'القاع عند ثلاثة أرباع الدورة، يعني `v = −Vp = −8 V`.',
};

// Ink marks live in slide space (800 × 600).
export const sinePage = {
  id: 16,
  width: 800,
  height: 600,
  title: 'قراءة القيمة اللحظية من الرسم',
  deckTitle: 'Lecture 5 · Sinusoidal Waveforms',
  deckPageCount: 51,
  steps: [
    {
      id: 1,
      marks: [{ t: 'circle', c: [370, 290], rx: 26, ry: 22 }],
      caption: ['هذي القمة، أعلى نقطة توصلها الموجة', 'قيمتها `Vp = 8 V`'],
      placement: { card: floatingCard, anchor: [392, 272] },
    },
    {
      id: 2,
      marks: [{ t: 'box', r: [48, 148, 210, 34] }],
      caption: ['أول مطلوب: القيمة العظمى', 'قرأناها من الرسم: `8 V`'],
      placement: { card: floatingCard, anchor: [258, 160] },
    },
    {
      id: 3,
      marks: [{ t: 'underline', a: [54, 214], b: [266, 214] }],
      caption: ['الحين نقرأ القيمة اللحظية', 'يعني قيمة الموجة عند زمن معيّن'],
      placement: { card: floatingCard, anchor: [266, 212] },
    },
    {
      id: 4,
      marks: [
        { t: 'guide', a: [430, 396], b: [430, 560] },
        { t: 'label', text: '0.3 s ?', at: [484, 578] },
      ],
      caption: [],
      ask: readAtTimeAsk,
    },
    {
      id: 5,
      marks: [
        { t: 'arrow', a: [262, 200], b: [420, 494], bend: -0.2 },
        { t: 'dot', p: [430, 510] },
        { t: 'dot', p: [520, 400] },
      ],
      caption: ['عند `0.3 s` احنا في القاع', 'وعند `0.6 s` الموجة تقطع الصفر'],
      placement: { card: [470, 96, 320, 110], anchor: [430, 510] },
    },
    {
      id: 6,
      marks: [
        { t: 'guide', a: [340, 290], b: [780, 290] },
        { t: 'guide', a: [340, 510], b: [780, 510] },
        { t: 'arrow', a: [715, 296], b: [715, 504], bend: 0 },
        { t: 'label', text: '16 V', at: [762, 470] },
      ],
      caption: ['من القمة للقاع', '`Vp-p = 2 × 8 = 16 V`'],
      placement: { card: lowerCard },
    },
    {
      id: 7,
      marks: [
        { t: 'arrow', a: [340, 575], b: [460, 575], bend: 0 },
        { t: 'label', text: 'T = 0.4 s', at: [400, 548] },
      ],
      caption: ['دورة كاملة وحدة', 'تاخذ `T = 0.4 s`'],
      placement: { card: lowerCard },
    },
    {
      id: 8,
      marks: [{ t: 'box', r: [46, 384, 128, 42] }],
      caption: ['التردد مقلوب الزمن الدوري', '`f = 1 / 0.4 = 2.5 Hz`'],
      placement: { card: lowerCard, anchor: [110, 426] },
    },
    {
      id: 9,
      marks: [{ t: 'spot', r: [330, 270, 452, 290] }],
      caption: ['القمة `8 V` ومن القمة للقمة `16 V`', 'الدورة `0.4 s` والتردد `2.5 Hz`'],
      placement: { card: [40, 446, 280, 110] },
    },
  ],
};

/** The region a student selected in the "explain this" sample. */
export const explainSelection = [44, 388, 150, 44];

export const explainAnswer = [
  '`f` هو التردد: كم دورة كاملة تتكرر في الثانية الوحدة.',
  'و`T` زمن الدورة الوحدة. لو الدورة تاخذ `0.4 s` فهي تتكرر `2.5` مرة كل ثانية.',
  'وحدته الهيرتز `Hz`.',
];

export const lecture5 = {
  id: 'EE207-L5',
  number: 5,
  title: 'Sinusoidal Waveforms',
  slideCount: 51,
  explainedCount: 38,
  ready: true,
  progress: 0.31,
};

export const lecture6 = {
  id: 'EE207-L6',
  number: 6,
  title: 'Phasors',
  slideCount: 48,
  explainedCount: 21,
  ready: false,
  preparing: 0.44,
  progress: 0,
};

export const course = { code: 'EE207', name: 'الدوائر الكهربائية', lectures: [lecture5, lecture6] };

export const resume = {
  lecture: lecture5,
  page: 16,
  step: 5,
  stepCount: 9,
  stepTitle: 'قراءة القيمة اللحظية من الرسم',
  askCount: 6,
};

export const reviewItems = [
  { id: 1, lecture: 5, page: 16, question: 'كم قيمة الموجة عند `t = 0.3 s`؟', yours: '0 V', correct: '−8 V', focus: [430, 510] },
  { id: 2, lecture: 5, page: 16, question: 'كم الزمن الدوري `T` من الرسم؟', yours: '0.2 s', correct: '0.4 s', focus: [460, 400] },
  { id: 3, lecture: 5, page: 16, question: 'إذا `T` قلّ للنص، وش يصير للتردد؟', yours: 'يقل للنص', correct: 'يتضاعف', focus: [110, 404] },
  { id: 4, lecture: 4, page: 22, question: 'كم القيمة من القمة للقمة `Vp-p`؟', yours: '8 V', correct: '16 V', focus: [370, 290] },
  { id: 5, lecture: 4, page: 9, question: 'متى تقطع الموجة الصفر أول مرة بعد البداية؟', yours: '0.4 s', correct: '0.2 s', focus: [400, 400] },
];

export const reviewCount = reviewItems.length + 2;

export const STAGES = ['reading', 'regions', 'scripting', 'verifying'];
export const stageText = {
  reading: ['قراءة الملف', 'النص والمعادلات والرسومات'],
  regions: ['تحديد المناطق', 'وين كل عنوان ومعادلة ورسم'],
  scripting: ['كتابة الشرح', 'حبر وكلام لكل سلايد'],
  verifying: ['مراجعة الشرح', 'نتأكد إن كل علامة في مكانها'],
};

export const importJob = { fileName: 'EE207 Lect6.pdf', courseCode: 'EE207', slideCount: 48, stage: 'scripting', scripted: 21 };

/** Slides are scripted in order; one is in progress while scripting. */
export function slideState(job, n) {
  if (n <= job.scripted) return 'ready';
  if (n === job.scripted + 1 && job.stage === 'scripting') return 'writing';
  return 'waiting';
}
