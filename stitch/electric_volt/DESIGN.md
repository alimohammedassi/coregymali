# Design System Strategy: Kinetic Obsidian

## 1. Overview & Creative North Star
The Creative North Star for this design system is **"The Kinetic Engine."** 

This is not a passive fitness tracker; it is a high-performance interface designed to mimic the intensity of a pre-workout surge. We move away from the "standard" safe UI by embracing **Aggressive Glassmorphism**—a style characterized by deep tonal layering, high-contrast neon accents, and a sense of physical velocity. 

To break the "template" look, the layout relies on intentional asymmetry. Large, slanted display type should bleed off the edges of the container, and cards should feel like precision-cut smoked glass hovering over a dark, infinite void. The goal is a digital environment that feels as premium and high-energy as a top-tier boutique HIIT studio.

---

## 2. Colors & Surface Architecture
The palette is rooted in `surface_container_lowest` (#000000) to ensure the `primary` (#f4ffc6) and `secondary` (#00eefc) accents achieve maximum luminosity.

### The "No-Line" Rule
Traditional 1px solid dividers are strictly prohibited. Separation of concerns must be achieved through:
- **Tonal Shifting:** Transitioning from `surface_dim` (#0e0e0e) to `surface_container_low` (#131313).
- **Glass Refraction:** Using `rgba(255, 255, 255, 0.04)` with a `backdrop-filter: blur(20px)` to define card boundaries.

### Surface Hierarchy & Nesting
Treat the UI as a stack of smoked glass panels. 
- **Base Layer:** `surface` (#0e0e0e) for the main application background.
- **Mid Layer:** `surface_container` (#1a1919) for persistent elements like navigation bars.
- **Top Layer:** `surface_container_highest` (#262626) for interactive cards and modals.

### The "Glass & Gradient" Rule
To add "soul," never use flat fills for large surfaces. Apply a subtle radial gradient from `primary` (#f4ffc6) to `primary_container` (#d1fc00) at 15% opacity behind glass layers to create a "neon bleed" effect.

---

## 3. Typography: The Pulse of Motion
The typographic system is built on a high-contrast pairing: **Epilogue** for high-impact displays and **Inter** for technical precision.

- **Display & Headline (Epilogue):** These must be set with a `-10°` oblique shear (italicized) and tight letter-spacing (-0.05em). This conveys speed and aggressive forward momentum. Use `display-lg` for workout "Big Numbers" (e.g., Heart Rate, Rep Counts).
- **Title & Body (Inter):** Used for instructional content and data labels. Inter provides a clean, "instrument-panel" aesthetic that balances the raw energy of the display face.
- **Hierarchy through Scale:** Use extreme size differentials. A `display-lg` (3.5rem) metric should sit immediately adjacent to a `label-sm` (0.6875rem) unit to create an editorial, high-end feel.

---

## 4. Elevation & Depth
In this system, elevation is a product of light and transparency, not shadows.

- **The Layering Principle:** Instead of shadows, use `surface_bright` (#2c2c2c) for the innermost nested elements to make them appear closer to the user.
- **Ambient Glows:** Traditional black drop shadows are replaced with "Ambient Glows." Use the `primary` color at 5-8% opacity with a 40px blur to make active cards appear as if they are self-illuminated.
- **The "Ghost Border" Fallback:** For inactive card states, use a 1px border with `outline_variant` (#494847) at **15% opacity**. This creates a "precision machined" edge without cluttering the visual field.
- **Active State Border:** Active or "Live" elements (like a running timer) utilize a 1px border of `rgba(212, 255, 0, 0.3)` to signify high energy.

---

## 5. Components

### Buttons
- **Primary (Action):** Full `primary_fixed` (#d1fc00) fill. Typography: `title-sm` Inter, Bold, All-Caps. Corner radius: `sm` (0.125rem) for a sharp, aggressive look.
- **Secondary (Glass):** Smoked glass background `rgba(255, 255, 255, 0.08)` with a `secondary` (#00eefc) 1px ghost border.

### Performance Cards
- No dividers. Content is separated by `spacing-8` (1.75rem) vertical gaps.
- Background: `rgba(255, 255, 255, 0.04)` with heavy backdrop blur.
- For active workout cards, apply a 2px left-accent-border in `primary` (#f4ffc6).

### Input Fields
- **Base:** `surface_container_highest` (#262626) with a bottom-only border in `outline`.
- **Focus:** The bottom border transforms into a `primary` neon glow. Label text shifts to `on_surface_variant` (#adaaaa).

### Progress Rings & Metrics
- Use `secondary` (#00eefc) for secondary metrics (e.g., recovery time) and `primary` for main goals (e.g., calorie burn).
- Apply a "Neon Path": the empty track of a progress bar should be `surface_container_highest` with 10% opacity.

---

## 6. Do’s and Don’ts

### Do:
- **Use "Bleed" Layouts:** Let large imagery or typography break the container margins to create a sense of scale.
- **Embrace the Dark:** Keep 90% of the UI in the `surface_dim` to `surface_container_lowest` range. The high-energy lime only works if it has a void to live in.
- **Stagger Elements:** Use the Spacing Scale to create asymmetrical compositions (e.g., a left-aligned headline with a right-aligned metric lower down the Y-axis).

### Don’t:
- **Don't use Rounded Corners > 12px:** Stay within the `sm` to `xl` range (0.125rem - 0.75rem). This system is "Aggressive"; excessively round corners soften the energy too much.
- **Don't use Pure White for Body Text:** Use `on_surface_variant` (#adaaaa) for secondary text to maintain the "Smoked" aesthetic and reduce eye strain in low-light gym environments.
- **Don't use Standard Dividers:** If you feel the need for a line, use a spacing increase or a subtle background color shift instead. Lines kill the "Glass" illusion.