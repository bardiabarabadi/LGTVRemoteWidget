//
//  remotePanelLiveActivity.swift
//  remotePanel
//
//  Created by Bardia Barabadi on 2025-10-24.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct remotePanelAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct remotePanelLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: remotePanelAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension remotePanelAttributes {
    fileprivate static var preview: remotePanelAttributes {
        remotePanelAttributes(name: "World")
    }
}

extension remotePanelAttributes.ContentState {
    fileprivate static var smiley: remotePanelAttributes.ContentState {
        remotePanelAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: remotePanelAttributes.ContentState {
         remotePanelAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: remotePanelAttributes.preview) {
   remotePanelLiveActivity()
} contentStates: {
    remotePanelAttributes.ContentState.smiley
    remotePanelAttributes.ContentState.starEyes
}
