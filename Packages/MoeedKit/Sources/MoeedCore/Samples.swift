import Foundation

/// Sample content for design work and tests. The slide is our own drawing
/// (a sine-wave reading exercise), not taken from any course material.
public enum Samples {
    private static let floatingCard = SlideRect(470, 110, 310, 100)
    private static let lowerCard = SlideRect(40, 446, 280, 104)

    public static let readAtTimeAsk = Ask(
        question: "كم قيمة الموجة عند `t = 0.3 s`؟",
        options: [AskOption("pos", "8 V"), AskOption("zero", "0 V"), AskOption("neg", "−8 V")],
        answerID: "neg",
        hint: "الخط المتقطع عند `0.3 s` يقطع الموجة وين؟ فوق المحور ولا تحته؟",
        why: "القاع عند ثلاثة أرباع الدورة، يعني `v = −Vp = −8 V`."
    )

    public static let sinePage = SlidePage(
        id: 16,
        width: 800,
        height: 600,
        title: "قراءة القيمة اللحظية من الرسم",
        deckTitle: "Lecture 5 · Sinusoidal Waveforms",
        deckPageCount: 51,
        steps: [
            Step(
                id: 1,
                marks: [.circle(center: SlidePoint(370, 290), rx: 26, ry: 22)],
                caption: [Phrase("هذي القمة، أعلى نقطة توصلها الموجة"), Phrase("قيمتها `Vp = 8 V`")],
                placement: CaptionPlacement(card: floatingCard, anchor: SlidePoint(392, 272))
            ),
            Step(
                id: 2,
                marks: [.box(SlideRect(48, 148, 210, 34))],
                caption: [Phrase("أول مطلوب: القيمة العظمى"), Phrase("قرأناها من الرسم: `8 V`")],
                placement: CaptionPlacement(card: floatingCard, anchor: SlidePoint(258, 160))
            ),
            Step(
                id: 3,
                marks: [.underline(from: SlidePoint(54, 214), to: SlidePoint(266, 214))],
                caption: [Phrase("الحين نقرأ القيمة اللحظية"), Phrase("يعني قيمة الموجة عند زمن معيّن")],
                placement: CaptionPlacement(card: floatingCard, anchor: SlidePoint(266, 212))
            ),
            Step(
                id: 4,
                marks: [
                    .guide(from: SlidePoint(430, 396), to: SlidePoint(430, 560)),
                    .label("0.3 s ?", at: SlidePoint(484, 578)),
                ],
                ask: readAtTimeAsk
            ),
            Step(
                id: 5,
                marks: [
                    .arrow(from: SlidePoint(262, 200), to: SlidePoint(420, 494), bend: -0.2),
                    .dot(SlidePoint(430, 510)),
                    .dot(SlidePoint(520, 400)),
                ],
                caption: [Phrase("عند `0.3 s` احنا في القاع"), Phrase("وعند `0.6 s` الموجة تقطع الصفر")],
                placement: CaptionPlacement(card: SlideRect(470, 96, 320, 110), anchor: SlidePoint(430, 510))
            ),
            Step(
                id: 6,
                marks: [
                    .guide(from: SlidePoint(340, 290), to: SlidePoint(780, 290)),
                    .guide(from: SlidePoint(340, 510), to: SlidePoint(780, 510)),
                    .arrow(from: SlidePoint(715, 296), to: SlidePoint(715, 504), bend: 0),
                    .label("16 V", at: SlidePoint(762, 470)),
                ],
                caption: [Phrase("من القمة للقاع"), Phrase("`Vp-p = 2 × 8 = 16 V`")],
                placement: CaptionPlacement(card: lowerCard)
            ),
            Step(
                id: 7,
                marks: [
                    .arrow(from: SlidePoint(340, 575), to: SlidePoint(460, 575), bend: 0),
                    .label("T = 0.4 s", at: SlidePoint(400, 548)),
                ],
                caption: [Phrase("دورة كاملة وحدة"), Phrase("تاخذ `T = 0.4 s`")],
                placement: CaptionPlacement(card: lowerCard)
            ),
            Step(
                id: 8,
                marks: [.box(SlideRect(46, 384, 128, 42))],
                caption: [Phrase("التردد مقلوب الزمن الدوري"), Phrase("`f = 1 / 0.4 = 2.5 Hz`")],
                placement: CaptionPlacement(card: lowerCard, anchor: SlidePoint(110, 426))
            ),
            Step(
                id: 9,
                marks: [.spot(SlideRect(330, 270, 452, 290))],
                caption: [Phrase("القمة `8 V` ومن القمة للقمة `16 V`"), Phrase("الدورة `0.4 s` والتردد `2.5 Hz`")],
                placement: CaptionPlacement(card: SlideRect(40, 446, 280, 110))
            ),
        ]
    )

    /// The region a student selected in the "explain this" sample.
    public static let explainSelection = SlideRect(44, 388, 150, 44)

    public static let lecture5 = Lecture(
        id: "EE207-L5", number: 5, title: "Sinusoidal Waveforms",
        slideCount: 51, explainedCount: 38, status: .ready, progress: 0.31
    )

    public static let lecture6 = Lecture(
        id: "EE207-L6", number: 6, title: "Phasors",
        slideCount: 48, explainedCount: 21, status: .preparing(progress: 0.44), progress: 0
    )

    public static let course = Course(code: "EE207", name: "الدوائر الكهربائية", lectures: [lecture5, lecture6])

    public static let resume = ResumePoint(
        lecture: lecture5, page: 16, step: 5, stepCount: 9,
        stepTitle: "قراءة القيمة اللحظية من الرسم", askCount: 6
    )

    public static let reviewItems: [ReviewItem] = [
        ReviewItem(id: 1, lectureNumber: 5, page: 16, question: "كم قيمة الموجة عند `t = 0.3 s`؟",
                   yourAnswer: "0 V", correctAnswer: "−8 V", focus: SlidePoint(430, 510)),
        ReviewItem(id: 2, lectureNumber: 5, page: 16, question: "كم الزمن الدوري `T` من الرسم؟",
                   yourAnswer: "0.2 s", correctAnswer: "0.4 s", focus: SlidePoint(460, 400)),
        ReviewItem(id: 3, lectureNumber: 5, page: 16, question: "إذا `T` قلّ للنص، وش يصير للتردد؟",
                   yourAnswer: "يقل للنص", correctAnswer: "يتضاعف", focus: SlidePoint(110, 404)),
        ReviewItem(id: 4, lectureNumber: 4, page: 22, question: "كم القيمة من القمة للقمة `Vp-p`؟",
                   yourAnswer: "8 V", correctAnswer: "16 V", focus: SlidePoint(370, 290)),
        ReviewItem(id: 5, lectureNumber: 4, page: 9, question: "متى تقطع الموجة الصفر أول مرة بعد البداية؟",
                   yourAnswer: "0.4 s", correctAnswer: "0.2 s", focus: SlidePoint(400, 400)),
    ]

    public static let importJob = ImportJob(
        fileName: "EE207 Lect6.pdf", courseCode: "EE207",
        slideCount: 48, stage: .scripting, scripted: 21
    )
}
