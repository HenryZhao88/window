# Window

AI-powered iOS productivity assistant for students. Learns your goals, tracks your energy, and recommends what to work on — grounded in your 10-year vision.

---

## Prerequisites

| Requirement | Notes |
|---|---|
| Xcode 16+ | Required for iOS 18 SDK |
| iPhone with iOS 18 | Screen Time features require a real device |
| Apple Developer Account | Required for entitlements and TestFlight |
| OpenAI API key | Get one at platform.openai.com |
| XcodeGen | `brew install xcodegen` |

---

## Setup

### 1. Generate the Xcode project

```bash
cd /path/to/Window
brew install xcodegen   # if not already installed
xcodegen generate
open Window.xcodeproj
```

### 2. Set your Team ID

In `project.yml`, replace `XXXXXXXXXX` with your Apple Developer Team ID:
```yaml
DEVELOPMENT_TEAM: "XXXXXXXXXX"
```
Then run `xcodegen generate` again.

### 3. FamilyControls entitlement (for Screen Time)

The `com.apple.developer.family-controls` entitlement **requires Apple approval**.

1. Go to developer.apple.com → Account → Additional Capabilities
2. Request "Screen Time API" access
3. This can take several days — the app works without it (Screen Time features degrade gracefully)

Until approved: remove the `com.apple.developer.family-controls` key from `Window/Window.entitlements` to build and test on device.

### 4. Build and run

Select your iPhone as the run destination in Xcode and press **Cmd+R**.

The app will guide you through:
1. Entering your OpenAI API key
2. Allowing Screen Time access (optional)
3. A goal-setting conversation with GPT-4o
4. A short productivity questionnaire

---

## Project Structure

```
Window/
├── project.yml                        ← XcodeGen config
├── Window/
│   ├── WindowApp.swift                ← App entry point + RootView
│   ├── MainTabView.swift              ← Tab navigation
│   ├── SharedModelContainer.swift     ← SwiftData App Group setup
│   ├── Models/
│   │   ├── UserProfile.swift          ← Adaptive productivity profile
│   │   ├── WindowTask.swift           ← User tasks
│   │   ├── UsageSnapshot.swift        ← Screen Time data
│   │   └── RecommendationEvent.swift  ← Learning loop ground truth
│   ├── Services/
│   │   ├── OpenAIService.swift        ← GPT-4o REST client
│   │   └── ScreenTimeService.swift    ← FamilyControls + App Group import
│   ├── Onboarding/
│   │   ├── OnboardingFlow.swift       ← Stage coordinator
│   │   ├── PermissionsView.swift      ← Screen Time authorization
│   │   ├── GoalConversationView.swift ← GPT-4o life coach chat
│   │   └── ProductivityProfileView.swift
│   ├── Tasks/
│   │   ├── TaskListView.swift
│   │   └── AddTaskView.swift
│   ├── Recommendations/
│   │   ├── ProductivityScorer.swift   ← Scoring algorithm (pure, testable)
│   │   ├── TaskRanker.swift           ← Task ranking (pure, testable)
│   │   ├── ProfileAdapter.swift       ← Adaptive weight updates (EMA)
│   │   ├── RecommendationEngine.swift ← Orchestrator + GPT-4o caller
│   │   └── RecommendationView.swift   ← Today tab UI
│   ├── Insights/
│   │   └── UsageInsightsView.swift
│   ├── Settings/
│   │   ├── APIKeySetupView.swift      ← First-launch key entry
│   │   └── SettingsView.swift
│   └── Debug/
│       └── DebugPanelView.swift       ← #if DEBUG only
├── WindowActivityMonitor/
│   └── ActivityMonitor.swift          ← DeviceActivity extension
└── WindowTests/
    ├── ProductivityScorerTests.swift
    ├── TaskRankerTests.swift
    └── ProfileAdapterTests.swift
```

---

## Debug Panel

In debug builds, tap the version number in Settings **5 times** to open the Debug Panel. You can:

- Inject fake social media usage (to test fatigue penalty)
- Fire a test notification
- Preview productivity scores at different hours
- Reset onboarding
- View raw SwiftData contents

---

## How the Algorithm Works

### Productivity Score
```
score = energyAtHour(currentHour, profile) - fatiguePenalty(recentSnapshots)
```
- `energyAtHour`: Gaussian blend of `morningEnergy` and `eveningEnergy` peaks (9am and 8pm)
- `fatiguePenalty`: Max 0.4, based on social media/entertainment usage in the last 2 hours

### Task Ranking
```
taskScore = productivityScore × importance(task)
importance = deadlineUrgency × 0.5 + difficulty × 0.3 + size × 0.2
```

### Adaptive Learning (EMA, α=0.1)
- Accepted recommendation at 9am → `morningEnergy` nudges up
- Skipped recommendation at 9am → `morningEnergy` nudges down
- Clamped to [0.1, 1.0] — weights never collapse

---

## Running Tests

```bash
xcodebuild test \
  -scheme Window \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.0'
```

Or press **Cmd+U** in Xcode.

---

## TestFlight Checklist

- [ ] Team ID set in `project.yml`
- [ ] FamilyControls entitlement approved (or removed for initial builds)
- [ ] Bundle ID registered in App Store Connect
- [ ] App runs end-to-end on real device
- [ ] OpenAI key stored and working
- [ ] Archive and upload via Xcode → Product → Archive
