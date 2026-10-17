import SwiftUI

struct TemperatureSheet: View {
    @ObservedObject var service: PrinterService
    @Environment(\.dismiss) private var dismiss

    @State private var nozzleTarget: Double = 0
    @State private var bedTarget: Double = 0
    @State private var fanPercent: Double = 0

    init(service: PrinterService) {
        self.service = service
        _nozzleTarget = State(initialValue: service.status.nozzleTarget)
        _bedTarget = State(initialValue: service.status.bedTarget)
        _fanPercent = State(initialValue: Double(service.status.coolingFan))
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "thermometer.medium")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.orange)
                Text("温度与风扇")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Button("关闭") { dismiss() }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 12)

            VStack(spacing: 14) {
                controlRow(
                    icon: "flame.fill",
                    title: "喷嘴温度",
                    current: service.status.nozzleTemp,
                    tint: Theme.orange,
                    value: $nozzleTarget,
                    range: 0...300,
                    suffix: "°C"
                )
                controlRow(
                    icon: "rectangle.compress.vertical",
                    title: "热床温度",
                    current: service.status.bedTemp,
                    tint: Theme.red,
                    value: $bedTarget,
                    range: 0...120,
                    suffix: "°C"
                )
                controlRow(
                    icon: "wind",
                    title: "模型风扇",
                    current: Double(service.status.coolingFan),
                    tint: Theme.cyan,
                    value: $fanPercent,
                    range: 0...100,
                    suffix: "%"
                )
            }
            .padding(.horizontal, 18)

            Text("打印过程中修改会立即生效，请谨慎调整。")
                .font(.system(size: 9.5, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 18)
                .padding(.top, 12)

            Button {
                service.setNozzleTarget(Int(nozzleTarget.rounded()))
                service.setBedTarget(Int(bedTarget.rounded()))
                service.setPartFan(Int(fanPercent.rounded()))
                dismiss()
            } label: {
                Text("应用设置")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(red: 0.02, green: 0.10, blue: 0.06))
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Theme.green)
                    )
            }
            .buttonStyle(.plain)
            .padding(18)
        }
        .frame(width: 340)
        .background(PanelBackground())
        .environment(\.colorScheme, .dark)
    }

    private func controlRow(icon: String, title: String, current: Double, tint: Color,
                            value: Binding<Double>, range: ClosedRange<Double>, suffix: String) -> some View {
        VStack(spacing: 7) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 16)
                Text(title)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                Text("当前 \(Int(current.rounded()))\(suffix)")
                    .font(.system(size: 9.5, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textTertiary)
                Text("\(Int(value.wrappedValue.rounded()))\(suffix)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                    .monospacedDigit()
                    .frame(minWidth: 44, alignment: .trailing)
            }
            Slider(value: value, in: range, step: 1)
                .tint(tint)
                .controlSize(.small)
        }
        .padding(11)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Color.white.opacity(0.045))
                .overlay(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }
}
