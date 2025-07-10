# Shape Tracer – Reflection & Reporting

## 1. Summary

Shape Tracer is an accessibility-first iOS app built with SwiftUI that enables users to practice tracing basic shapes—specifically squares and circles—using multimodal feedback systems. Users trace the shape outlines on a canvas using their finger, receiving immediate audio, haptic, and visual feedback to guide and reinforce their progress. The app is designed to support spatial learning and motor skill engagement, particularly for users with visual impairments or other accessibility needs.

### Demo Link
[View Demo Video](https://drive.google.com/file/d/1DQsdEm-c9sbZxJwjUEr51Fdm_p6_-PO4/view?usp=drive_link)

<img width="1170" height="2532" alt="Circle" src="https://github.com/user-attachments/assets/6558e341-3764-4715-8e2b-6601bbeb3edf" />
<img width="1170" height="2532" alt="Square" src="https://github.com/user-attachments/assets/2d35fe9f-fbdc-4a7b-a2b8-8878786b70e1" />

### Key Features

- Shape selection menu with large, accessible buttons
- Real-time tracing with touch input visualization
- Multimodal feedback (audio tone, haptic vibration, and spatial voice cues)
- VoiceOver compatibility and support for Dynamic Type
- Tracing validation requiring 98% path coverage for task completion

---

## 2. Focus Areas

**What specific areas of the project did you prioritize? Why did you choose to focus on these areas?**

I prioritized three core areas: multimodal feedback, accessibility integration, and shape path validation. These aspects are foundational for creating a learning experience that is inclusive, responsive, and meaningful. 

- **Multimodal feedback** ensures users receive confirmation through various senses, which is especially helpful for users with visual impairments
- **Accessibility integration** was prioritized to meet standards like VoiceOver support and Dynamic Type, ensuring usability for a broad audience
- **Path validation** was important to encourage full-shape tracing and support meaningful spatial learning, rather than allowing users to skip through or "game" the system

---

## 3. Time Allocation

**Roughly how many hours did you spend? How did you allocate your time?**

**Total Time:** 7.5–8 hours

### Breakdown

**Planning and Research (~1 hour)**
- Reviewed accessibility APIs and SwiftUI feedback mechanisms
- Sketched out logic for tracing validation and guidance flows

**Core Development (~3.5 hours)**
- Implemented UI, gesture tracking, and shape rendering in SwiftUI
- Integrated feedback system with tone, haptic, and speech
- Wrote initial path validation logic and feedback triggers

**Accessibility Features (~2 hours)**
- Added VoiceOver labels, hints, and feedback routing
- Tuned layout for Dynamic Type and high-contrast themes

**Testing and Polish (~1 hour)**
- Manual testing of edge cases, cooldown logic, and guidance timing
- Added unit tests for feedback logic and validation correctness
- README documentation and UI polish

---

## 4. Decisions & Trade-offs

**What design or implementation choices did you make, and why?**

Throughout the development process, I made intentional design choices to prioritize a balance between accessibility and user experience. Key decisions included:

- **Multimodal feedback integration:** Audio, haptic, and visual cues to support non-visual navigation, especially for VoiceOver users
- **Real-time feedback over batch validation:** Provides immediate guidance and maintains user engagement
- **Cooldown logic implementation:** Reduces repetitive and overwhelming prompts like "corner" or "off track," creating a more respectful experience for blind users
- **Tolerance buffer in tracing logic:** Avoids penalizing minor motor inaccuracies
- **Encouraging feedback design:** Feedback designed to be supportive rather than discouraging
- **Intuitive starting point placement:** Progress reset logic adjusted based on testing frustrations to ensure natural and forgiving app flow

These choices stemmed from direct testing experience and my desire to create an empowering, educational experience aligned with accessibility best practices.

---

## 5. Least Complete Area

**What would you improve or extend if you had more time?**

### Circle Feedback Enhancement
The most incomplete area is the circle feedback system. While square corners have strong haptic cues to mark turns, the circle lacks similar spatial anchors. I had intended to mark 12, 3, 6, and 9 o'clock positions with unique haptic feedback but ran out of time to calibrate the angles and tune the response pattern.

### Progress Visualization
Additionally, progress visualization is minimal. While the app tracks point count and completion status, it doesn't visually show tracing progress in a meaningful way (e.g., color gradients or heatmaps). Given more time, I would add:
- Dynamic visual feedback
- Confidence heatmap of covered zones
- Progressive visual indicators

---

## 6. Research Relevance

**How could your implementation support a research study—e.g., studying motor skills, evaluating accessibility features, or exploring user interaction behavior?**

### Motor Skills Research
The app's point-by-point tracking and path validation logic can help quantify fine motor precision, especially in children or users with impairments.

### Accessibility Research
The layered feedback system and VoiceOver compatibility create a controlled environment to study how different feedback modes affect non-visual shape recognition.

### Educational Research
Researchers can use the app to examine how users learn geometric shapes over time and whether spatial cues (haptics vs. audio vs. speech) influence retention.

### HCI Research
Shape Tracer provides a unique opportunity to observe exploration behavior, learning strategies, and user adaptation in real time based on multimodal guidance.
