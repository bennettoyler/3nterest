import { expect, test } from "vitest";
import { parseDesign } from "./designSchema";
import { cannedFor } from "./cannedDesigns";

test("malformed model output is rejected", () => {
  expect(parseDesign({ title: "x", parts: [{ name: "top", shape: "sphere", sizeCm: [1,2,3], positionCm: [0,0,0], rotationDeg: [0,0,0] }] })).toBeNull();
  expect(parseDesign({ title: "x", parts: [{ name: "top", shape: "box", sizeCm: [1,2], positionCm: [0,0,0], rotationDeg: [0,0,0] }] })).toBeNull();
  expect(parseDesign("not json")).toBeNull();
});

test("canned design always parses and defaults to the desk", () => {
  expect(parseDesign(cannedFor("a 120 cm walnut desk with two drawers"))).not.toBeNull();
  expect(cannedFor("something unexpected").title).toMatch(/desk/i);
});

test("canned designs match their keywords and all parse", () => {
  expect(cannedFor("a tall bookcase").title).toMatch(/shel/i);
  expect(cannedFor("a pine bench").title).toMatch(/stool/i);
  for (const prompt of ["shelf", "stool", "desk"]) expect(parseDesign(cannedFor(prompt))).not.toBeNull();
});
