import PaywallKit
import SwiftUI

/// Lumina's editor: a photo, a strip of looks (most of them Pro) and a Pro-only retouch panel.
struct ContentView: View {
    let controller: PaywallController

    @State private var selectedFilter = DemoContent.filters[0]
    @State private var showsPaywall = false
    @State private var template: PaywallTemplate = .hero

    init(controller: PaywallController) {
        self.controller = controller
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    PhotoCanvas(filter: selectedFilter)

                    FilterStrip(
                        selection: selectedFilter,
                        isEntitled: controller.isEntitled
                    ) { filter in
                        if filter.isPro && !controller.isEntitled {
                            template = .minimal
                            showsPaywall = true
                        } else {
                            selectedFilter = filter
                        }
                    }

                    EntitlementGate(controller: controller) {
                        RetouchPanel()
                    } locked: {
                        LockedRetouchCard {
                            template = .comparison
                            showsPaywall = true
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("Lumina")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Picker("Paywall", selection: $template) {
                            Text("Hero").tag(PaywallTemplate.hero)
                            Text("Comparison").tag(PaywallTemplate.comparison)
                            Text("Minimal").tag(PaywallTemplate.minimal)
                        }
                        Button("Show Paywall", systemImage: "crown") {
                            showsPaywall = true
                        }
                    } label: {
                        Label(controller.isEntitled ? "Pro" : "Go Pro", systemImage: "crown.fill")
                            .labelStyle(.titleAndIcon)
                    }
                }
            }
        }
        .tint(DemoContent.violet)
        .paywall(
            isPresented: $showsPaywall,
            controller: controller,
            content: DemoContent.content(for: template),
            template: template
        )
        .task { await controller.start() }
    }
}

/// The photo being edited, with the selected look applied.
struct PhotoCanvas: View {
    let filter: LuminaFilter

    var body: some View {
        Color.clear
            .aspectRatio(4 / 3, contentMode: .fit)
            .overlay {
                Image("LuminaHero")
                    .resizable()
                    .scaledToFill()
                    .luminaFilter(filter)
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(alignment: .bottomLeading) {
                Text(filter.name)
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(14)
            }
            .shadow(color: .black.opacity(0.15), radius: 16, y: 8)
            .animation(.smooth, value: filter)
            .accessibilityLabel(Text("Photo with the \(filter.name) look"))
    }
}

/// Thumbnails of every look. Pro looks show a crown until the user has Pro.
struct FilterStrip: View {
    let selection: LuminaFilter
    let isEntitled: Bool
    let onSelect: (LuminaFilter) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(DemoContent.filters) { filter in
                    Button {
                        onSelect(filter)
                    } label: {
                        VStack(spacing: 6) {
                            Color.clear
                                .frame(width: 72, height: 72)
                                .overlay {
                                    Image("LuminaHero")
                                        .resizable()
                                        .scaledToFill()
                                        .luminaFilter(filter)
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .strokeBorder(filter == selection ? DemoContent.violet : .clear, lineWidth: 3)
                                }
                                .overlay(alignment: .topTrailing) {
                                    if filter.isPro && !isEntitled {
                                        Image(systemName: "crown.fill")
                                            .font(.caption2)
                                            .foregroundStyle(.white)
                                            .padding(5)
                                            .background(DemoContent.violet, in: Circle())
                                            .padding(4)
                                    }
                                }
                            Text(filter.name)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(filter == selection ? DemoContent.violet : .secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(filter.isPro && !isEntitled ? "\(filter.name), Pro" : filter.name))
                }
            }
            .padding(.vertical, 4)
        }
    }
}

/// The Pro-only retouch tools.
struct RetouchPanel: View {
    @State private var smoothing = 0.4
    @State private var glow = 0.25

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("AI Retouch", systemImage: "wand.and.stars")
                .font(.headline)
            LabeledContent("Smoothing") {
                Slider(value: $smoothing)
            }
            LabeledContent("Glow") {
                Slider(value: $glow)
            }
        }
        .padding(18)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

/// What free users see instead of the retouch tools.
struct LockedRetouchCard: View {
    let onUnlock: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "wand.and.stars")
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(DemoContent.violet.gradient, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text("AI Retouch")
                    .font(.headline)
                Text("Remove people, wires and blemishes.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Button("Unlock") {
                onUnlock()
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
        }
        .padding(18)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
