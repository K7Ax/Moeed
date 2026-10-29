import Foundation

public extension Samples {
    /// The regions of the sample sine slide, measured from its drawing (800 × 600).
    /// F1's grid: a column is 50 units across and a row 30 down, from (300, 250).
    static let sineRegions = RegionMap(width: 800, height: 600, regions: [
        Region(id: "T1", kind: .text, box: SlideRect(170, 30, 460, 40), text: "Sine Wave · Reading the Graph", isTitle: true),
        Region(id: "T2", kind: .text, box: SlideRect(56, 115, 56, 25), text: "Find:"),
        Region(id: "T3", kind: .text, box: SlideRect(56, 153, 196, 25), text: "a) the peak value Vp"),
        Region(id: "T4", kind: .text, box: SlideRect(56, 187, 208, 25), text: "b) v at 0.3 s and 0.6 s"),
        Region(id: "T5", kind: .text, box: SlideRect(56, 221, 244, 25), text: "c) the peak-to-peak value"),
        Region(id: "T6", kind: .text, box: SlideRect(56, 255, 140, 25), text: "d) the period T"),
        Region(id: "T7", kind: .text, box: SlideRect(56, 289, 160, 25), text: "e) the frequency"),
        Region(id: "T8", kind: .text, box: SlideRect(56, 353, 126, 25), text: "Key relation"),
        Region(id: "T9", kind: .text, box: SlideRect(300, 281, 32, 18), text: "8 V", host: "F1"),
        Region(id: "T10", kind: .text, box: SlideRect(292, 501, 40, 18), text: "−8 V", host: "F1"),
        Region(id: "E1", kind: .equation, box: SlideRect(56, 390, 104, 31), text: "f = 1 / T"),
        Region(id: "F1", kind: .figure, box: SlideRect(300, 250, 500, 300)),
    ])

    /// The sample lesson as a model would write it. Compiling it against `sineRegions`
    /// should give back what `sinePage` spells out by hand.
    static let sineScript = """
    @v1.2 title="قراءة القيمة اللحظية من الرسم"
    @1 circle F1@1.4,1.33 | cap "هذي القمة، أعلى نقطة توصلها الموجة" / "قيمتها `Vp = 8 V`"
    @2 box T3 | cap "أول مطلوب: القيمة العظمى" / "قرأناها من الرسم: `8 V`"
    @3 underline T4 | cap "الحين نقرأ القيمة اللحظية" / "يعني قيمة الموجة عند زمن معيّن"
    @4 guide F1@2.6,5.0 -> F1@2.6,9.9 ; label F1@3.6,9.6 "0.3 s ?" | ask "كم قيمة الموجة عند `t = 0.3 s`؟" | opts "8 V" / "0 V" / *"−8 V" | hint "الخط المتقطع عند `0.3 s` يقطع الموجة وين؟ فوق المحور ولا تحته؟" | why "القاع عند ثلاثة أرباع الدورة، يعني `v = −Vp = −8 V`."
    @5 arrow T4 -> F1@2.4,8.1 ; dot F1@2.6,8.67 ; dot F1@4.4,5.0 | cap "عند `0.3 s` احنا في القاع" / "وعند `0.6 s` الموجة تقطع الصفر"
    @6 guide F1@0.8,1.33 -> F1@9.6,1.33 ; guide F1@0.8,8.67 -> F1@9.6,8.67 ; arrow F1@8.3,1.5 -> F1@8.3,8.5 | cap "من القمة للقاع" / "`Vp-p = 2 × 8 = 16 V`"
    @7 arrow F1@0.8,9.9 -> F1@3.2,9.9 ; label F1@2.0,9.9 "T = 0.4 s" below | cap "دورة كاملة وحدة" / "تاخذ `T = 0.4 s`"
    @8 box E1 | cap "التردد مقلوب الزمن الدوري" / "`f = 1 / 0.4 = 2.5 Hz`"
    @9 spot F1 | cap "القمة `8 V` ومن القمة للقمة `16 V`" / "الدورة `0.4 s` والتردد `2.5 Hz`"
    """
}
