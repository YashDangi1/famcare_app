# Debug Session: notification-action-alarm

Status: OPEN

## Symptom
- Notification-only mode me `I Took It` aur `Snooze` press karne ke baad bhi alarm bajta rehta hai.
- Expected: button click par alarm turant stop ho, selected action perform ho, aur app state/log update ho.

## Hypotheses
1. Notification action callback trigger hi nahi ho raha.
2. Callback trigger hota hai, but `Alarm.stop()` runtime me ringing alarm ko stop nahi kar raha.
3. Multiple IDs / duplicate alarm artifacts ke wajah se ek source stop hota hai, doosra ring karta rehta hai.
4. Action execute hota hai, but cleanup incomplete hai, isliye alarm/notification reappear hota hai.
5. Native Android alarm playback service Flutter-side stop ke baad bhi alive reh rahi hai.

## Plan
1. Existing action callback path me runtime instrumentation add karna.
2. Reproduce karke logs collect karna.
3. Evidence ke basis par minimal fix lagana.
4. Post-fix logs se compare karke verify karna.
