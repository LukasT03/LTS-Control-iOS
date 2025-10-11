import WidgetKit
import SwiftUI
import AppIntents

struct SimpleButtonWidget: Widget {
    let kind: String = "SimpleButtonWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            SimpleButtonWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Steuerung")
        .description("Steuert den LTS Respooler.")
        .supportedFamilies([.systemSmall])
    }
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> Void) {
        completion(SimpleEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> Void) {
        let entry = SimpleEntry(date: Date())
        completion(Timeline(entries: [entry], policy: .never))
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
}

struct SimpleButtonWidgetEntryView: View {
    let entry: SimpleEntry

    var body: some View {
            VStack(spacing: 8) {
                HStack{
                    Image("AppLogo")
                        .resizable()
                        .frame(maxWidth: 30, maxHeight: 30)
                    Spacer()
                }
                Button(intent: StartMotorIntent()) {
                    Text("Start").bold()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.roundedRectangle(radius: 10))
                .tint(.accentColor)

                Button(intent: PauseMotorIntent()) {
                    Text("Pause").bold()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.roundedRectangle(radius: 10))
                .tint(.orange)
            }
           .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct SimpleButtonWidget_Previews: PreviewProvider {
    static var previews: some View {
        SimpleButtonWidgetEntryView(entry: SimpleEntry(date: Date()))
            .previewContext(WidgetPreviewContext(family: .systemSmall))
    }
}
