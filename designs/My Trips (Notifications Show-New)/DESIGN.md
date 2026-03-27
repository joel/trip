```markdown
# Design System Specification: High-End Editorial & Glassmorphism

## 1. Overview & Creative North Star: "The Digital Curator"
This design system is built on the philosophy of **"The Digital Curator."** It rejects the cluttered, boxy layouts of legacy SaaS in favor of an airy, editorial experience that feels more like a premium digital gallery than a database. 

The aesthetic is defined by **intentional asymmetry, breathability, and optical depth.** We move away from rigid 1-pixel borders and instead use "Tonal Sculpting"—defining space through subtle shifts in surface luminosity and backdrop-blur effects. The goal is a UI that feels "soft to the touch" yet mathematically precise.

---

## 2. Colors & Tonal Sculpting
Our palette avoids harsh contrasts to maintain a sophisticated, glassy atmosphere.

### The "No-Line" Rule
**Explicit Instruction:** Do not use `1px solid` borders to define sections.
*   **Correct:** Place a `surface_container_lowest` card on top of a `surface_container_low` background. 
*   **Correct:** Use a `2.75rem` (8) gap to separate content blocks.
*   **Incorrect:** Using a grey line to separate a sidebar from a main content area.

### Surface Hierarchy & Nesting
Treat the interface as a physical stack of frosted glass layers.
*   **Base Layer:** `background` (#faf8ff)
*   **Content Sections:** `surface_container_low` (#f2f3ff)
*   **Primary Cards:** `surface_container_lowest` (#ffffff)
*   **Elevated Overlays:** `surface_bright` with `backdrop-blur: 12px` and 80% opacity.

### Signature Textures: The "Aura" Gradient
To inject soul into the UI, main CTAs and Hero sections should utilize a **linear-gradient(135deg, var(--ha-primary), var(--ha-primary_container))**. This creates a soft internal glow that flat colors cannot replicate.

---

## 3. Typography: The Editorial Scale
We pair the geometric tension of **Space Grotesk** with the utilitarian precision of **Inter** and **JetBrains Mono**.

*   **Display (Space Grotesk):** Use `display-lg` (3.5rem) for hero statements. Apply a slight negative letter-spacing (-0.02em) to create a high-fashion, "tight" editorial look.
*   **Headlines (Space Grotesk):** Use for all semantic headers. These are the anchors of your layout.
*   **Body (Inter):** All long-form reading and UI metadata uses Inter. It provides the necessary neutral ground to let the display type shine.
*   **Mono (JetBrains Mono):** Reserved strictly for code snippets, IDs, or data-heavy labels (`label-sm`).

---

## 4. Elevation & Depth: The Layering Principle

### Ambient Shadows
Forget "Drop Shadows." We use **Ambient Auras**.
*   **Token:** `0 20px 40px -12px rgba(19, 27, 46, 0.08)`
*   **Rule:** Shadows should be tinted with the `on_surface` color, never pure black. They must feel like light being absorbed by the surface below, not a floating cutout.

### The "Ghost Border" Fallback
If contrast is legally required for accessibility, use a **Ghost Border**:
*   `border: 1px solid var(--ha-outline_variant)` at **15% opacity**. It should be felt, not seen.

### Glassmorphism
For floating sidebars or navigation bars:
*   **Background:** `rgba(255, 255, 255, 0.7)`
*   **Blur:** `backdrop-filter: blur(20px) saturate(180%)`
*   **Border:** `1px solid rgba(255, 255, 255, 0.3)`

---

## 5. Components & Primitive Styles

### Buttons (The Pill)
*   **Primary:** Pill-shaped (`full`), uses the Primary-to-PrimaryContainer gradient.
*   **States:** On hover, apply `translateY(-1px)` and increase shadow diffusion.
*   **Padding:** `1rem` (3) vertical, `2rem` (6) horizontal.

### Input Fields
*   **Shape:** `1.5rem` (md) radius.
*   **Background:** `surface_container_highest`. 
*   **Interaction:** On focus, the background shifts to `surface_lowest` with a subtle `primary` ghost-border.

### Cards & Lists
*   **The Card:** `2rem` (lg) radius. No borders. Use `surface_container_lowest` on a `surface_container_low` background.
*   **List Separation:** Strictly forbid divider lines. Use `0.7rem` (2) of vertical padding and background-color hover states (`surface_variant` at 30% opacity) to denote individual items.

### Interactive Chips
*   **Style:** `label-md` typography. Pill-shaped.
*   **Unselected:** `surface_container_high` with `on_surface_variant` text.
*   **Selected:** `secondary_container` with `on_secondary_container` text.

---

## 6. Do’s and Don’ts

### Do:
*   **Embrace Negative Space:** If a layout feels "empty," add more padding, don't add more lines.
*   **Use Asymmetric Grids:** Align text to the left but allow images or cards to bleed off-center or overlap slightly to create depth.
*   **Animate Transitions:** Use a `cubic-bezier(0.4, 0, 0.2, 1)` for all hover states to mimic a "premium" weighted feel.

### Don't:
*   **Don't use pure black (#000):** It kills the "glassy" vibe. Use `on_background` (#131b2e) for maximum darkness.
*   **Don't use 100% opacity backgrounds:** Especially for sidebars or modals; you lose the "frosted" connectivity to the layers underneath.
*   **Don't over-shadow:** If three layers are stacked, only the top-most layer should have a shadow. The others should rely on tonal shifts.

---

## 7. Dark Mode Strategy
All variables use the `--ha-` prefix. In Dark Mode, the `surface_container` tokens flip their luminosity, but the **Glassmorphism** effect remains key. Increase the `backdrop-blur` to `30px` in dark mode to ensure readability against glowing background gradient blobs.