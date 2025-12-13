# Gmail "+" Addressing Trick Explained

## What It Is:

Gmail treats these as **the SAME inbox**:
- `nyeinthunaing322@gmail.com`
- `nyeinthunaing322+anything@gmail.com`
- `nyeinthunaing322+feedback@gmail.com`
- `nyeinthunaing322+aws@gmail.com`

**All emails go to:** `nyeinthunaing322@gmail.com` inbox

## How AWS SNS Sees It:

AWS SNS treats these as **DIFFERENT email addresses**:
- `nyeinthunaing322@gmail.com` (marked as bounced)
- `nyeinthunaing322+feedback@gmail.com` (fresh, no bounce history)

## Why This Helps:

1. **Gmail's bounce tracking** is per-email-address
2. If `nyeinthunaing322@gmail.com` bounced before, Gmail "remembers" it
3. `nyeinthunaing322+feedback@gmail.com` is "new" to Gmail's spam filter
4. Gmail's spam filter treats it as a fresh start

## Technical Flow:

```
AWS SNS Topic: codedetect-prod-user-feedback
    ↓
Subscription: nyeinthunaing322+feedback@gmail.com
    ↓
Gmail Server: "This is a new address, not bounced before"
    ↓
Accepts email ✅
    ↓
Delivers to: nyeinthunaing322@gmail.com inbox
```

## What I Did:

### Before:
```
Topic: codedetect-prod-user-feedback
  └─ nyeinthunaing322@gmail.com → Deleted (bounced)
```

### After:
```
Topic: codedetect-prod-user-feedback
  ├─ nyeinthunaing322@gmail.com → Deleted (old, ignore)
  └─ nyeinthunaing322+feedback@gmail.com → Pending Confirmation (NEW)
```

### Once You Confirm:
```
Topic: codedetect-prod-user-feedback
  ├─ nyeinthunaing322@gmail.com → Deleted (old, ignore)
  └─ nyeinthunaing322+feedback@gmail.com → Confirmed ✅
```

## Example:

**When user submits feedback:**
```
User clicks "Report Bug" in app
    ↓
App sends to SNS: codedetect-prod-user-feedback
    ↓
SNS sends email TO: nyeinthunaing322+feedback@gmail.com
    ↓
Gmail delivers TO: nyeinthunaing322@gmail.com (your inbox)
    ↓
You see email in your regular Gmail inbox ✅
```

## Other Uses of "+" Trick:

- `yourname+shopping@gmail.com` for shopping sites
- `yourname+newsletter@gmail.com` for newsletters
- `yourname+spam@gmail.com` for suspicious sites

All go to the same inbox, but you can:
- Filter them differently
- Track who leaked your email
- Bypass subscription limits
