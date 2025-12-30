import SwiftUI

struct AddHabitFlowSheet: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.colorScheme) private var scheme
  @Bindable var store: AppStore

  @State private var tab: Tab = .recommended

  // Custom builder fields
  @State private var customName: String = ""
  @State private var customDescription: String = ""
  @State private var customVisibility: HabitVisibility = .private
  @State private var customBehavior: HabitBehavior = .build
  @State private var customGoalType: CustomGoalType = .streak
  @State private var customPeriod: HabitPeriod = .day
  @State private var customMetric: HabitMetric = .custom
  @State private var customUnit: String = "units"
  @State private var customTarget: Double = 10

  @State private var showCustomLimitAlert: Bool = false

  enum Tab: String, CaseIterable, Identifiable {
    case recommended
    case custom
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
  }

  enum CustomGoalType: String, CaseIterable, Identifiable {
    case streak
    case target
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: DS.Spacing.l) {
          Text("Add a habit")
            .font(DS.Typography.title)
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.top, DS.Spacing.l)

          Picker("Type", selection: $tab) {
            ForEach(Tab.allCases) { t in
              Text(t.title).tag(t)
            }
          }
          .pickerStyle(.segmented)
          .tint(DS.Palette.accent)
          .padding(.horizontal, DS.Spacing.xl)

          switch tab {
          case .recommended:
            recommendedSection
          case .custom:
            customSection
          }

          Spacer(minLength: DS.Spacing.xxl)
        }
        .padding(.bottom, DS.Spacing.xxl)
      }
      .dsScreenBackground()
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Close") { dismiss() }
            .foregroundStyle(DS.Palette.subtext(scheme))
        }
      }
      .alert("Custom habit limit reached", isPresented: $showCustomLimitAlert) {
        Button("OK", role: .cancel) {}
      } message: {
        Text("You can have up to 3 custom habits.")
      }
    }
    .onAppear {
      if customName.isEmpty { customName = "" }
      customUnit = customMetric.defaultUnit
    }
  }

  private var recommendedSection: some View {
    VStack(alignment: .leading, spacing: DS.Spacing.m) {
      DSSectionHeaderRow(title: "Recommended", systemImage: "sparkles")

      VStack(spacing: DS.Spacing.m) {
        ForEach(HabitTemplateID.allCases) { template in
          TemplateCard(template: template) {
            store.addTemplateHabit(template)
            dismiss()
          }
        }
      }
      .padding(.horizontal, DS.Spacing.xl)
    }
  }

  private var customSection: some View {
    VStack(alignment: .leading, spacing: DS.Spacing.m) {
      DSSectionHeaderRow(title: "Custom", systemImage: "pencil.and.outline")

      VStack(alignment: .leading, spacing: DS.Spacing.s) {
        Text("Name")
          .font(DS.Typography.section)
        TextField("Habit name", text: $customName)
          .textInputAutocapitalization(.words)
          .padding(DS.Spacing.l)
          .background(
            RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
              .fill(DS.Palette.surface(scheme))
          )
          .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
              .stroke(DS.Palette.separator(scheme), lineWidth: 1)
          )

        Text("Description")
          .font(DS.Typography.section)
          .padding(.top, DS.Spacing.s)
        TextField("Optional description", text: $customDescription, axis: .vertical)
          .lineLimit(2...4)
          .padding(DS.Spacing.l)
          .background(
            RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
              .fill(DS.Palette.surface(scheme))
          )
          .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
              .stroke(DS.Palette.separator(scheme), lineWidth: 1)
          )
      }
      .dsCard()
      .padding(.horizontal, DS.Spacing.xl)

      VStack(alignment: .leading, spacing: DS.Spacing.s) {
        Text("Goal")
          .font(DS.Typography.section)

        Picker("Type", selection: $customBehavior) {
          Text("Build a habit").tag(HabitBehavior.build)
          Text("Break a habit").tag(HabitBehavior.breakHabit)
        }

        Picker("Goal type", selection: $customGoalType) {
          ForEach(CustomGoalType.allCases) { g in
            Text(g.title).tag(g)
          }
        }

        Picker("Period", selection: $customPeriod) {
          ForEach(HabitPeriod.allCases) { p in
            Text(p.rawValue.capitalized).tag(p)
          }
        }

        if customGoalType == .target {
          Picker("Metric", selection: $customMetric) {
            ForEach(HabitMetric.allCases) { m in
              Text(m.title).tag(m)
            }
          }
          .onChange(of: customMetric) { _, newValue in
            if newValue != .custom { customUnit = newValue.defaultUnit }
          }

          HStack(spacing: DS.Spacing.m) {
            VStack(alignment: .leading, spacing: 6) {
              Text("Target")
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Palette.subtext(scheme))
              TextField("Target", value: $customTarget, format: .number)
                .keyboardType(.decimalPad)
                .padding(DS.Spacing.m)
                .background(
                  RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .fill(DS.Palette.surface(scheme))
                )
                .overlay(
                  RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .stroke(DS.Palette.separator(scheme), lineWidth: 1)
                )
            }
            VStack(alignment: .leading, spacing: 6) {
              Text("Unit")
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Palette.subtext(scheme))
              TextField("Unit", text: $customUnit)
                .textInputAutocapitalization(.never)
                .padding(DS.Spacing.m)
                .background(
                  RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .fill(DS.Palette.surface(scheme))
                )
                .overlay(
                  RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .stroke(DS.Palette.separator(scheme), lineWidth: 1)
                )
            }
            .frame(width: 110)
          }
        }
      }
      .dsCard()
      .padding(.horizontal, DS.Spacing.xl)

      VStack(alignment: .leading, spacing: DS.Spacing.s) {
        Text("Visibility")
          .font(DS.Typography.section)
        Picker("Visibility", selection: $customVisibility) {
          ForEach(HabitVisibility.allCases) { v in
            Text(v.title).tag(v)
          }
        }
        .pickerStyle(.segmented)
        .tint(DS.Palette.accent)

        if customVisibility == .secret {
          Text("Secret habits are hidden from others and labeled “Secret habit”.")
            .font(DS.Typography.caption)
            .foregroundStyle(DS.Palette.subtext(scheme))
        }
      }
      .dsCard()
      .padding(.horizontal, DS.Spacing.xl)

      Button {
        let goal: HabitGoal
        switch customGoalType {
        case .streak:
          goal = .streak(period: customPeriod)
        case .target:
          goal = .target(metric: customMetric, unit: customUnit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "units" : customUnit, period: customPeriod, target: max(0, customTarget))
        }

        let ok = store.addCustomHabit(
          name: customName,
          description: customDescription,
          behavior: customBehavior,
          goal: goal,
          visibility: customVisibility
        )
        if ok {
          dismiss()
        } else {
          showCustomLimitAlert = true
        }
      } label: {
        Text("Create custom habit")
          .frame(maxWidth: .infinity)
          .padding(.vertical, DS.Spacing.m)
      }
      .buttonStyle(.borderedProminent)
      .tint(DS.Palette.accent)
      .disabled(customName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      .padding(.horizontal, DS.Spacing.xl)
      .padding(.top, DS.Spacing.s)
    }
  }
}

private struct TemplateCard: View {
  @Environment(\.colorScheme) private var scheme
  let template: HabitTemplateID
  let addTapped: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: DS.Spacing.s) {
      HStack {
        Text(template.defaultName)
          .font(DS.Typography.section)
        Spacer()
        Button("Add", action: addTapped)
          .buttonStyle(.borderedProminent)
          .tint(DS.Palette.accent)
      }

      Text(template.defaultDescription)
        .font(DS.Typography.body)
        .foregroundStyle(DS.Palette.subtext(scheme))

      Text("Adjust targets after adding.")
        .font(DS.Typography.caption)
        .foregroundStyle(DS.Palette.subtext(scheme))
    }
    .dsCard()
  }
}

