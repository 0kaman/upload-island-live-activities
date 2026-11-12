import ActivityKit
import SwiftUI
import WidgetKit

struct UploadLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: UploadActivityAttributes.self) { context in
            LockScreenView(attributes: context.attributes, state: context.state)
                .activityBackgroundTint(Color.black.opacity(0.85))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let attributes = context.attributes
            let state = context.state

            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    ExpandedLeadingView(attributes: attributes, state: state)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ExpandedTrailingView(state: state)
                }
                DynamicIslandExpandedRegion(.center) {
                    ExpandedCenterView(attributes: attributes, state: state)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ExpandedBottomView(attributes: attributes, state: state)
                }
            } compactLeading: {
                CompactLeadingView(attributes: attributes, state: state)
            } compactTrailing: {
                CompactTrailingView(state: state)
            } minimal: {
                MinimalView(state: state)
            }
            // Let the boundary strokes reach the island's edge instead of the default inset.
            .contentMargins(.all, 0, for: .compactLeading)
            .contentMargins(.all, 0, for: .compactTrailing)
            .contentMargins(.all, 0, for: .minimal)
            .keylineTint(state.phase.tint)
        }
    }
}
