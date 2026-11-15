import type { DesignBody } from "./designSchema";

const walnut = "#5C3A21";
const oak = "#C8A165";
const pine = "#E3C590";

const desk: DesignBody = {
  title: "Walnut Desk with Two Drawers",
  parts: [
    { name: "top", shape: "box", sizeCm: [120, 3, 60], positionCm: [0, 73.5, 0], rotationDeg: [0, 0, 0], material: "walnut", colorHex: walnut },
    { name: "leg front left", shape: "box", sizeCm: [5, 72, 5], positionCm: [-55, 36, 25], rotationDeg: [0, 0, 0], material: "walnut", colorHex: walnut },
    { name: "leg front right", shape: "box", sizeCm: [5, 72, 5], positionCm: [55, 36, 25], rotationDeg: [0, 0, 0], material: "walnut", colorHex: walnut },
    { name: "leg back left", shape: "box", sizeCm: [5, 72, 5], positionCm: [-55, 36, -25], rotationDeg: [0, 0, 0], material: "walnut", colorHex: walnut },
    { name: "leg back right", shape: "box", sizeCm: [5, 72, 5], positionCm: [55, 36, -25], rotationDeg: [0, 0, 0], material: "walnut", colorHex: walnut },
    { name: "drawer left", shape: "box", sizeCm: [45, 12, 50], positionCm: [-25, 66, 0], rotationDeg: [0, 0, 0], material: "walnut", colorHex: walnut },
    { name: "drawer right", shape: "box", sizeCm: [45, 12, 50], positionCm: [25, 66, 0], rotationDeg: [0, 0, 0], material: "walnut", colorHex: walnut },
    { name: "drawer pull left", shape: "cylinder", sizeCm: [2, 1.5, 2], positionCm: [-25, 66, 25.75], rotationDeg: [90, 0, 0], material: "brass", colorHex: "#C9A227" },
    { name: "drawer pull right", shape: "cylinder", sizeCm: [2, 1.5, 2], positionCm: [25, 66, 25.75], rotationDeg: [90, 0, 0], material: "brass", colorHex: "#C9A227" },
  ],
  cutList: [
    { part: "top", material: "walnut", lengthCm: 120, widthCm: 60, thicknessCm: 3, quantity: 1 },
    { part: "leg", material: "walnut", lengthCm: 72, widthCm: 5, thicknessCm: 5, quantity: 4 },
    { part: "drawer front and back", material: "walnut", lengthCm: 45, widthCm: 12, thicknessCm: 1.8, quantity: 4 },
    { part: "drawer side", material: "walnut", lengthCm: 50, widthCm: 12, thicknessCm: 1.8, quantity: 4 },
    { part: "drawer bottom", material: "plywood", lengthCm: 50, widthCm: 43, thicknessCm: 0.6, quantity: 2 },
  ],
  hardware: ["2 pairs of 45 cm drawer slides", "2 brass knobs", "16 x 4x40 mm wood screws", "8 table-top fasteners", "wood glue"],
  steps: [
    "Cut every piece from the cut list and sand to 180 grit.",
    "Glue and screw the drawer boxes; fit the plywood bottoms.",
    "Mount the drawer slides under the top, 2 cm in from each side.",
    "Fix the legs to the corners of the top with the fasteners.",
    "Slide in the drawers, fit the knobs, and finish with oil.",
  ],
};

const shelf: DesignBody = {
  title: "Oak Bookshelf, Five Shelves",
  parts: [
    { name: "side left", shape: "box", sizeCm: [2, 180, 30], positionCm: [-39, 90, 0], rotationDeg: [0, 0, 0], material: "oak", colorHex: oak },
    { name: "side right", shape: "box", sizeCm: [2, 180, 30], positionCm: [39, 90, 0], rotationDeg: [0, 0, 0], material: "oak", colorHex: oak },
    ...[1, 45, 90, 135, 179].map((y, i) => ({
      name: `shelf ${i + 1}`,
      shape: "box" as const,
      sizeCm: [76, 2, 30],
      positionCm: [0, y, 0],
      rotationDeg: [0, 0, 0],
      material: "oak",
      colorHex: oak,
    })),
  ],
  cutList: [
    { part: "side", material: "oak", lengthCm: 180, widthCm: 30, thicknessCm: 2, quantity: 2 },
    { part: "shelf", material: "oak", lengthCm: 76, widthCm: 30, thicknessCm: 2, quantity: 5 },
  ],
  hardware: ["20 x 8 mm dowels", "2 wall anchors with L-brackets", "wood glue"],
  steps: [
    "Cut the sides and shelves; sand all faces.",
    "Mark shelf heights at 0, 44, 89, 134 and 178 cm on both sides.",
    "Drill dowel holes, glue, and assemble the shelves between the sides.",
    "Clamp square and let the glue cure.",
    "Anchor the top to the wall with the brackets.",
  ],
};

const stool: DesignBody = {
  title: "Pine Step Stool",
  parts: [
    { name: "seat", shape: "box", sizeCm: [40, 3, 35], positionCm: [0, 43.5, 0], rotationDeg: [0, 0, 0], material: "pine", colorHex: pine },
    ...[
      [-16, -13.5],
      [16, -13.5],
      [-16, 13.5],
      [16, 13.5],
    ].map(([x, z], i) => ({
      name: `leg ${i + 1}`,
      shape: "cylinder" as const,
      sizeCm: [4, 42, 4],
      positionCm: [x, 21, z],
      rotationDeg: [0, 0, 0],
      material: "pine",
      colorHex: pine,
    })),
    { name: "stretcher", shape: "box", sizeCm: [32, 4, 2], positionCm: [0, 12, 0], rotationDeg: [0, 0, 0], material: "pine", colorHex: pine },
  ],
  cutList: [
    { part: "seat", material: "pine", lengthCm: 40, widthCm: 35, thicknessCm: 3, quantity: 1 },
    { part: "leg (4 cm dowel)", material: "pine", lengthCm: 42, widthCm: 4, thicknessCm: 4, quantity: 4 },
    { part: "stretcher", material: "pine", lengthCm: 32, widthCm: 4, thicknessCm: 2, quantity: 1 },
  ],
  hardware: ["4 x 6x60 mm hanger bolts", "2 x 4x40 mm wood screws", "wood glue"],
  steps: [
    "Cut the seat, legs and stretcher; round over the seat edges.",
    "Drill the leg holes into the underside of the seat, 2 cm from the edges.",
    "Glue the legs into the seat.",
    "Fit the stretcher between two legs, 12 cm above the floor.",
    "Sand and finish with oil.",
  ],
};

export function cannedFor(prompt: string): DesignBody {
  const p = prompt.toLowerCase();
  if (p.includes("shelf") || p.includes("bookcase")) return shelf;
  if (p.includes("stool") || p.includes("bench")) return stool;
  return desk;
}
