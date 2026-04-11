# Mobile Viewport Verification

The app is a PWA used on mobile devices. Buttons and links that work on desktop may fail on mobile due to touch targets, overflow, or viewport issues. **Test at mobile width for every interactive element.**

## Mobile Setup

```bash
# Set mobile viewport (iPhone 14 Pro dimensions)
agent-browser eval "
  Object.defineProperty(navigator, 'userAgent', {value: 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)'});
"
agent-browser viewport 393 852
```

## Mobile Page Tests

Test every page at mobile width. Look for:
- **Buttons/links cut off or overlapping** -- tap targets must be >= 44x44px
- **Horizontal scrolling** -- no content should overflow the viewport
- **Sidebar behavior** -- must collapse to hamburger/overlay, not push content off-screen
- **Forms** -- inputs must be full-width, labels visible, submit buttons reachable
- **Cards** -- must stack vertically, not overlap

```bash
# Home page (logged out)
agent-browser open https://catalyst.workeverywhere.docker/ && agent-browser wait --load networkidle
agent-browser screenshot /tmp/rt-mobile-home.png

# Login page
agent-browser open https://catalyst.workeverywhere.docker/login && agent-browser wait --load networkidle
agent-browser screenshot /tmp/rt-mobile-login.png

# After login -- trips index
agent-browser screenshot /tmp/rt-mobile-trips.png

# Trip show
agent-browser screenshot /tmp/rt-mobile-trip-show.png

# Journal entry (images, comments, reactions)
agent-browser screenshot /tmp/rt-mobile-entry.png

# Scroll to comments and reaction buttons
agent-browser eval "window.scrollTo(0, document.body.scrollHeight)" && sleep 1
agent-browser screenshot /tmp/rt-mobile-entry-bottom.png
```

## Mobile Button Tests (Critical)

Every button must be tappable at mobile width. Test these explicitly:

```bash
# 1. Sidebar toggle (hamburger menu)
agent-browser snapshot -i  # Find hamburger/menu button
agent-browser click @eN  # Tap hamburger
agent-browser screenshot /tmp/rt-mobile-sidebar.png

# 2. Navigation links in mobile sidebar
# Tap each nav item and verify navigation works

# 3. Sign in button on home page
# Must be visible and tappable without scrolling

# 4. Reaction emoji buttons
# Must be tappable (not too small, not overlapping)

# 5. Comment form submit
# Textarea and Post button must be usable

# 6. Checklist toggle checkboxes
# Must be tappable at mobile width

# 7. Dark mode toggle
# Must be accessible in mobile sidebar/header
```

## Mobile-Specific Defects to Watch For

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| Button doesn't respond to tap | Touch target too small (< 44px), or overlapping element intercepts tap | Add `min-h-[44px] min-w-[44px]` or fix z-index |
| Link works on desktop, not mobile | `hover:` styles hiding the clickable area, or `pointer-events-none` on a parent | Use `@media (hover: hover)` for hover effects |
| Horizontal scroll on mobile | Fixed-width element or `whitespace-nowrap` without `overflow-hidden` | Add `overflow-hidden` or `max-w-full` |
| Sidebar pushes content off-screen | Sidebar not using `fixed`/`absolute` positioning on mobile | Use responsive `lg:` breakpoint for sidebar layout |
| Form input zooms on iOS | Font size < 16px on input | Set `text-base` (16px) on form inputs |

## Viewport Overflow Check

After loading each page at mobile width, run:

```bash
# Check for horizontal overflow
agent-browser eval "document.documentElement.scrollWidth > document.documentElement.clientWidth ? 'OVERFLOW: ' + document.documentElement.scrollWidth + ' > ' + document.documentElement.clientWidth : 'OK: no overflow'"
```

**Any overflow is a defect.**
