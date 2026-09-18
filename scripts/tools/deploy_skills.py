import os

def write_file(path, content):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)
    print('Wrote:', path)

omni_content = '''---
name: omni-scientist
description: Omni-Modal & Omni-Discipline AI Scientist Framework based on omni-scientist.github.io. Automates scientific discovery, multi-modal hypothesis generation, mathematical modeling, empirical code experimentation, validation, and peer-review grade reporting across engineering, urban sciences, hydrology, computer vision, and AI systems.
---

# OmniScientist: Omni-Modal Omni-Discipline AI Scientist

OmniScientist provides an end-to-end framework for autonomous, multi-modal, cross-disciplinary scientific discovery, empirical modeling, and evidence-backed problem solving.

Based on the [OmniScientist Architecture](https://omni-scientist.github.io/):
1. **Omni-Modal Ingestion:** Unifies text, telemetry time-series, GIS/satellite rasters, CCTV feeds, acoustic sensors, and codebases.
2. **Omni-Discipline Synthesis:** Bridges urban computing, hydrology, applied physics, computer vision, machine learning, and municipal operations.
3. **Autonomous Empirical Loop:** Iterates through Hypothesis -> Simulation/Experiment Code -> Statistical Verification -> Report Synthesis.

---

## Core Workflow Stages

### Stage 1: Scientific Ideation and Hypothesis Formulation
* Define explicit falsifiable hypotheses (H0 vs H1).
* Frame mathematical equations and boundary conditions.
* Identify confounding variables and required control baselines.

### Stage 2: Empirical Experimentation and Code Execution
* Write self-contained, reproducible Python code using standard scientific libraries.
* Execute simulations or data analyses against real project data.
* Perform sensitivity analysis, parameter sweeps, and convergence checks.

### Stage 3: Statistical Verification and Error Bounds
* Provide standard deviations, sample counts (N), or confidence intervals (95% CI).
* Run hypothesis testing and effect size computations.

### Stage 4: Peer-Review Grade Scientific Reporting
* Generate structured reports with Abstract, Mathematical Formulation, Methodology, Empirical Results, and Limitations.

## Application Domains in City Pulse / Municipal Systems
1. **Hydrological River & Flood Dynamics (Ob River):** Water level forecasting (500-1100 cm), floodplain inundation risk.
2. **Computer Vision & Urban Telemetry (City Cameras / Viseron):** Traffic density, snow piles, camera FOV frustum geometry.
3. **Municipal Energy & Heating (Microclimate):** Heat loss modeling, pipe network pressure drops.
4. **Geospatial & 3D Digital Twin Analysis:** Solar shadow casting at 60.9 deg N, terrain elevation slope mapping.
'''

ramp_cro = '''---
name: rampstack-cro
description: High-conversion rate optimization (CRO), UX clarity audit, cognitive friction reduction, and landing page / mobile flow polish by RampStack.
---

# RampStack CRO & UX Polish Skill

Evaluates interfaces for clarity, friction points, value proposition articulation, and conversion paths:
1. **Value Proposition Clarity:** Above-the-fold headline answers: What is this? Why should I care? What do I do next?
2. **Cognitive Load Reduction:** Strip unnecessary fields, reduce visual noise, enforce strict typographic hierarchy.
3. **CTA Optimization:** High-contrast primary action with micro-copy managing user expectations.
4. **Social Proof & Trust Signals:** Live activity tickers, transparent municipal metrics, verified badges.
'''

ramp_aso = '''---
name: rampstack-aso
description: App Store & Google Play / RuStore optimization (ASO) for mobile applications, metadata structuring, and localized user engagement by RampStack.
---

# RampStack ASO & Mobile Distribution Skill

Optimizes mobile app store presence, metadata, screenshots, and first-launch retention:
1. **Title & Subtitle Keywords:** Clear search intent (e.g. City Pulse Nizhnevartovsk - ЖКХ, Камеры, Паводок).
2. **Visual Asset Staging:** High-contrast feature screenshots with bold captions highlighting key benefits.
3. **Changelog Polish:** Clear, user-centric release notes explaining new features and fixes.
4. **First 60-Second Onboarding:** Zero-barrier initial view with immediate value preview.
'''

ramp_perf = '''---
name: rampstack-perf
description: Full-stack performance optimization, mobile bundle trimming, asset optimization, and rendering efficiency by RampStack.
---

# RampStack Performance & Efficiency Skill

Enforces high-performance standards across frontend and backend:
1. **Mobile Bundle Budget:** Tree-shaking unused dependencies, asset compression (WebP/SVG), font subsetting.
2. **Rendering Performance:** 60 FPS scrolling, RepaintBoundary isolation, lazy loading of off-screen lists and images.
3. **Backend Latency:** In-memory caching, indexing query filters, connection pooling.
4. **Network Resilience:** Offline-first caching with background sync.
'''

skills = {
    'omni-scientist': omni_content,
    'rampstack-cro': ramp_cro,
    'rampstack-aso': ramp_aso,
    'rampstack-perf': ramp_perf
}

destinations = [
    'c:/Soobshio_project/.agents/skills',
    'C:/Users/рс/.gemini/antigravity/builtin/skills',
    'C:/Users/рс/.agents/skills'
]

for base in destinations:
    for name, text in skills.items():
        target = os.path.join(base, name, 'SKILL.md')
        write_file(target, text)

print('ALL SKILLS SUCCESSFULLY DEPLOYED!')
