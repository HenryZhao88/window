# Window MVP — Design Spec
**Date:** 2026-03-15
**Status:** Approved
**Target:** TestFlight-ready build on iOS 18+

---

## 1. Overview

Window is an AI-powered iOS app for student life that dynamically recommends what to work on throughout the day. It learns from the user's stated goals, productivity profile, and passive Screen Time usage to surface GPT-4o-generated recommendations grounded in the user's own dream life and long-term goals.

**Core value proposition:** Window doesn't just manage tasks — it connects daily actions to the user's 10-year vision, making every recommendation feel personally meaningful.

---

## 2. Tech Stack

| Layer | Technology |
|---|---|
| Platform | iOS 18+, iPhone |
| UI | SwiftUI |
| Storage | SwiftData (on-device, App Group shared) |
| AI | OpenAI GPT-4o (REST API) |
| Screen Time | FamilyControls + DeviceActivity frameworks |
| Distribution | TestFlight |
| Background data | DeviceActivityMonitor App Extension |

---

## 3. Architecture

Two Xcode targets share an App Group container (`group.com.yourname.window`):

### Target 1: Window (main app)

```
Window/
├── WindowApp.swift
├── Onboarding/
│   ├── OnboardingFlow.swift          — multi-step coordinator
│   ├── GoalConversationView.swift    — GPT-4o chat UI
│   └── ProductivityProfileView.swift — chronotype/focus questionnaire
├── Tasks/
│   ├── TaskListView.swift
│   └── AddTaskView.swift
├── Recommendations/
│   ├── RecommendationView.swift      — today's recommendation card
│   └── RecommendationEngine.swift    — context builder + GPT-4o caller
├── Insights/
│   └── UsageInsightsView.swift       — screen time charts
├── Models/
│   ├── UserProfile.swift             — SwiftData model
│   ├── Task.swift                    — SwiftData model
│   ├── UsageSnapshot.swift           — SwiftData model
│   └── RecommendationEvent.swift     — SwiftData model (learning loop)
├── Services/
│   ├── OpenAIService.swift           — GPT-4o API client
│   └── ScreenTimeService.swift       — FamilyControls authorization
└── Debug/
    └── DebugPanelView.swift          — #if DEBUG only
```

### Target 2: WindowActivityMonitor (DeviceActivity extension)

```
WindowActivityMonitor/
└── ActivityMonitor.swift   — writes UsageSnapshot to shared SwiftData store
```

---

## 4. Data Models (SwiftData)

### UserProfile
Single record, created at onboarding, updated over time.

```swift
var dreamLife: String               // raw GPT-4o conversation transcript
var tenYearGoal: String             // extracted goal summary
var weeklyFocus: String             // current week's focus area
var keyHabits: [String]             // extracted habits array
var chronotype: Chronotype          // .morning / .evening / .flexible
var focusDuration: Int              // minutes before break (e.g. 45)
var morningEnergy: Double           // 0.0–1.0, adaptive
var eveningEnergy: Double           // 0.0–1.0, adaptive
var taskSwitchTolerance: Double     // 0.0–1.0
var procrastinationTendency: Double // 0.0–1.0
var onboardingComplete: Bool
```

### Task
User-defined tasks.

```swift
var name: String
var difficulty: Double              // 0.0–1.0
var deadline: Date
var estimatedMinutes: Int
var isCompleted: Bool
var completedAt: Date?
var actualMinutes: Int?             // filled on completion, for calibration
```

### UsageSnapshot
Written by the DeviceActivity extension, one record per app per hour.

```swift
var timestamp: Date
var appBundleID: String             // e.g. "com.burbn.instagram"
var category: String               // e.g. "SocialNetworking"
var durationSeconds: Double
```

### RecommendationEvent
Ground truth log for the learning loop.

```swift
var timestamp: Date
var recommendedTaskName: String
var recommendationText: String
var productivityScore: Double
var outcome: Outcome                // .accepted / .skipped / .breakTaken
var timeOfDay: Double               // 0.0–1.0 normalized hour
```

---

## 5. Onboarding Flow

Runs once on first launch. Three sequential stages.

### Stage 1 — Permissions
- Request `FamilyControls` authorization
- Explain why Screen Time access improves recommendations
- If denied: app continues without usage signals (graceful degradation)

### Stage 2 — Dream Life Conversation (GPT-4o)
- Chat-style UI, GPT-4o plays life coach
- System prompt instructs GPT-4o to ask 3–5 open-ended questions one at a time:
  - "Describe your dream life in 10 years — what does a typical day look like?"
  - "What's standing between you and that life right now?"
  - "What's one thing you want to make consistent progress on this week?"
- After gathering responses, GPT-4o returns a structured JSON summary:
  ```json
  {
    "tenYearGoal": "...",
    "weeklyFocus": "...",
    "keyHabits": ["...", "..."]
  }
  ```
- This JSON is parsed and saved to `UserProfile`

### Stage 3 — Productivity Profile
Short native SwiftUI questionnaire (no AI):
- Morning or evening person? → `chronotype`
- Focus duration before needing a break? → `focusDuration`
- How far in advance do you start assignments? → `procrastinationTendency`
- Sets initial energy weights (`morningEnergy`, `eveningEnergy`)

---

## 6. Recommendation Engine

Triggered when the user opens the app. Later: on background refresh.

### Step 1 — Score the Moment
```
productivity_score = energy_weight(time_of_day) - fatigue_penalty(recent_usage)
```
- `energy_weight`: interpolates `morningEnergy`/`eveningEnergy` based on current hour
- `fatigue_penalty`: derived from `UsageSnapshot` records in the past 2 hours — high social media duration increases penalty

### Step 2 — Rank Tasks
```
task_score = productivity_score × task_importance
task_importance = f(deadline_proximity, difficulty, estimated_minutes)
```

### Step 3 — Build GPT-4o Prompt
Context package sent to GPT-4o:
- Current productivity score and what's driving it
- Top-ranked task (name, difficulty, deadline, estimated time)
- User's `tenYearGoal` and `weeklyFocus`
- Recent distraction patterns (e.g., "40 minutes on Instagram in the last 2 hours")
- User's `focusDuration`

### Step 4 — Surface Recommendation
A card in the main app showing:
- 2–3 sentence GPT-4o recommendation grounded in the user's goals
- Top task name + estimated time
- Actions: **Start** / **Skip** / **Take a break**

Each action is logged to `RecommendationEvent`.

**Example output:**
> "You've been on Instagram for 40 minutes — your focus window is closing. To get closer to your goal of becoming a product designer, now is a good time to spend 45 minutes on your portfolio. You've got this."

---

## 7. Learning Loop

Window adapts over time using outcome data from `RecommendationEvent`.

### Adaptive Weight Updates
- If the user consistently skips morning recommendations → `morningEnergy` drifts down
- If actual task completion time > estimated → `difficulty` calibration adjusts upward
- Acceptance rate tracked per time-of-day band

### Weekly Reflection (GPT-4o)
Once per week, GPT-4o receives a summary of the week's `RecommendationEvent` records and returns one actionable adjustment to the user's schedule, displayed as a weekly insight card.

---

## 8. Debug Panel

Available in `#if DEBUG` builds only. Accessible via a hidden gesture (e.g., 5-tap on the app logo) or a Settings toggle.

Capabilities:
- Manually trigger a recommendation refresh
- Fire a test local notification immediately
- Inject a fake `UsageSnapshot` (simulate Screen Time data)
- Reset onboarding (wipe `UserProfile`, restart flow)
- Override current time-of-day for productivity scoring
- View raw SwiftData contents (profile, tasks, snapshots, events)

---

## 9. Error Handling & Graceful Degradation

| Failure | Behavior |
|---|---|
| Screen Time permission denied | App runs without usage signals; fatigue penalty defaults to 0 |
| OpenAI API error | Show cached last recommendation; surface retry option |
| No tasks added yet | Prompt user to add their first task |
| DeviceActivity extension not running | Main app proceeds with last known snapshots |

---

## 10. MVP Success Criteria

- [ ] Onboarding completes end-to-end: permissions → goal conversation → productivity profile
- [ ] User can add tasks with name, difficulty, deadline, estimated time
- [ ] Recommendation card appears with GPT-4o-generated text grounded in user's goals
- [ ] Screen Time usage data passively collected by extension and visible in Insights tab
- [ ] Recommendation outcomes logged and adaptive weights update
- [ ] Debug panel functional for TestFlight testing
- [ ] App runs on a real device without crashes
- [ ] Builds and distributes via TestFlight
