---
name: cadam
description: Generates parametric 3D CAD models using OpenSCAD syntax based on natural language prompts.
triggers:
  - "cadam"
  - "generate cad"
  - "text to cad"
  - "openscad modeling"
---

# CADAM: Text-to-CAD Parametric Modeling Skill

This skill allows the agent to generate parametric 3D CAD models in OpenSCAD syntax (`.scad`), which can be converted to STL files.

## OpenSCAD Parametric Basics

OpenSCAD uses a functional, declarative syntax. Models are built using CSG (Constructive Solid Geometry) primitives.

### Standard Primitives
- **Cube**: `cube([width, depth, height], center=true/false);`
- **Cylinder**: `cylinder(h=height, r=radius, center=true/false, $fn=100);`
- **Sphere**: `sphere(r=radius, $fn=100);`

### Transformations
- **Translate**: `translate([x, y, z]) { ... }`
- **Rotate**: `rotate([deg_x, deg_y, deg_z]) { ... }`
- **Scale**: `scale([x, y, z]) { ... }`

### Boolean Operations
- **Union**: Combine objects: `union() { obj1(); obj2(); }`
- **Difference**: Subtract second from first: `difference() { main_obj(); cutout_obj(); }`
- **Intersection**: Keep overlapping parts: `intersection() { obj1(); obj2(); }`

---

## 🛠️ Usage Example

To model a city park bench:

```openscad
// Parametric Bench
length = 150;
width = 50;
height = 40;
thickness = 4;

module seat() {
    translate([-length/2, -width/2, height])
        cube([length, width, thickness]);
}

module leg(x_pos) {
    translate([x_pos, -width/2, 0])
        cube([thickness, width, height]);
}

union() {
    seat();
    leg(-length/2 + 10);
    leg(length/2 - 10 - thickness);
}
```

---

## 🚀 Execution Guide

1. **Create code**: Write the OpenSCAD code to a file: `output.scad`.
2. **Compile to STL**: Run the OpenSCAD CLI command to render:
   ```bash
   openscad -o output.stl output.scad
   ```
3. **Generate Preview**: Render STL to PNG image (useful for map visualizers):
   ```bash
   python stl2img.py --input output.stl --output output.png
   ```
