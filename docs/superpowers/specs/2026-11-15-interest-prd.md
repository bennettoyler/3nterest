# Interest — PRD (YC Consumer Mobile Hackathon, 2026-11-15)

Status: draft for team approval. Items marked **[call]** are decisions made by the drafter, not agreed by the team. Items marked **[confirm]** need a human to check before work depends on them.

## 1. What it is

Interest is a Pinterest-style social app where every pin is a real 3D room. You scan your room with your iPhone, the app rebuilds it out of movable 3D furniture matched to purchasable products, you rearrange and add things, and you share it. Other people browse rooms for inspiration, save them to collections, remix them into their own room, and buy what they see.

Name: "3nterest" (3D + Pinterest, pronounced "interest"). Logo: a bold white sans-serif 3 on a YC-orange `#FF6600` square. Colors: YC orange `#FF6600` and white. Code identifiers (target, scheme, module, folders, bundle id, the `interest://` URL scheme) keep the name Interest.

## 2. Why, and what winning looks like

- Hackathon theme: "an app people open every day". The daily hook is the feed of other people's rooms, not the scanner.
- It is a consumer app. Brands and solo creators listing products do not change that.
- Sponsor fit: payments run on **Whop**. The pitch is that anyone — a brand, an Etsy-style maker, or a user who designed a desk with the AI builder — can earn money from a listing. Judges for that prize are payments engineers, so the checkout and the "seller gets paid" moment must be clean.
- Success = a live, on-device demo of about 3 minutes that never stalls, ending with a purchase and a shared room.

## 3. Constraints

- Build window: 10:00 AM to 6:00 PM submission. All code is written after 10:00 AM. This PRD contains no code.
- Three developers, each running agents in parallel git worktrees.
- Must use Capy, Revyl and Convex. Must run on a real phone for the demo.
- It is a demo: hardcode freely. Every network-dependent step needs a canned fallback.

## 4. Goals, non-goals, anti-goals

Goals
1. Scan a room and see it rebuilt as separate, movable 3D objects.
2. Each object is linked to a purchasable product with a price, seller and assembly instructions.
3. Add catalog items and AI-designed custom items to the room.
4. Share rooms to a feed; save rooms and items to collections; remix someone else's room.
5. Buy an item through Whop.

Non-goals
- Real IKEA/Amazon integration (sellers and catalog are fake and seeded).
- Real accounts and login (a hardcoded user switcher is enough).
- Android. Gaussian splatting. True physics simulation. Real CAD export or 3D printing.
- In-app DMs (use the iOS share sheet with a link instead) **[call]**.
- Accurate visual product recognition.

Anti-goals
- A demo that depends on a live scan or a live AI call with no fallback.
- An app that reads as a scanning utility rather than a social product.
- The room looking like a static photo with stickers on it. Objects must visibly move.

## 5. Approach to the 3D room **[call]**

Use Apple RoomPlan (LiDAR, iPhone Pro) instead of Gaussian splatting.

- A roughly 60-second scan returns walls, doors, windows and openings as clean surfaces, plus each piece of furniture as a labelled box with category, dimensions and position (categories include chair, table, sofa, bed, storage, television).
- The app draws the room shell from those surfaces and, for each detected furniture box, picks the seeded catalog product with the same category and the closest dimensions, then places that product's 3D model at the box's position and rotation. This is the "search the scan and place similar products" step; it is a lookup, not machine vision.
- Every placed object can be dragged along the floor, rotated, deleted, or swapped for another product in the same category. Objects stop at walls. No further physics.
- The app is native iOS in Swift (SwiftUI, RoomPlan, RealityKit or SceneKit — builder's choice), with Convex's Swift client. Confirmed by the team.
- Demo safety: once a good scan exists, save its captured room data and bundle it as a "sample room" so the flow works without scanning on stage. A "Use sample room" button sits on the scan screen.

## 6. Features

P0 — must be in the demo
- **Scan → rebuilt room.** Scan screen, then a short "matching your furniture" animation, then the editable room.
- **Room editor.** Orbit/zoom camera, tap to select, drag, rotate, delete, swap. Tap an object to open its product sheet.
- **Product sheet.** Name, seller, price, dimensions, "Assembly instructions" (opens a PDF or step list), "Buy", "Save", and "View at vendor".
- **Vendor links.** Every movable object in a room is tied to its vendor. Selecting an object shows a small tag above it with the vendor name and price; "View at vendor" on the product sheet opens that product's vendor page in an in-app browser. The links are seeded per product and may be fake: either a real vendor product page for a similar item or a placeholder page. The link stays with the object when it is moved, swapped in, remixed or viewed in someone else's room. AI-built designs link to their creator's listing instead.
- **Add from catalog.** Browse seeded products by category and drop one into the room.
- **Publish and feed.** Publish a room with a title and an auto-captured thumbnail. Home is a two-column masonry feed of rooms. Opening a room shows it in 3D, read-only, with its item list.
- **Buy with Whop.** "Buy" opens a Whop checkout for that product; on return, show a receipt with the seller/Interest split and record an order. See "Payments model" below.
- **Seller earnings.** A simple view per seller listing its sales, what it received and Interest's 5%.

P1 — strongly wanted
- **AI builder.** A chat screen: the user describes something to build ("a 120 cm walnut desk with two drawers"). A Convex action calls the OpenAI API and returns a structured design: a list of parts (box or cylinder, size in cm, position, rotation, material, colour), a cut list, hardware, and build steps. The app renders the parts as one 3D object that can be placed in the room, and shows the cut list and steps. Two or three scripted prompts have canned responses stored in Convex and are served if the live call fails or takes more than about 8 seconds.
- **Sell your design.** A design can be listed in the marketplace with a price; it then appears in the catalog under the creator's name. This is the "anyone can make money" moment.
- **Collections.** Save rooms and products into named collections; a profile tab shows them.
- **Remix.** "Remix this room" copies someone's room into your own editor.

Cut order if time runs short **[call]** — drop from the top:
1. Remix, share link, seller pages (not in the demo script).
2. Collections beyond a single "Save" that shows on the profile.
3. List-for-sale as a real catalog entry (fake it: show a "Listed" confirmation only).
4. Live scanning (use the bundled sample room; the rebuilt, movable room still shows).
5. Live AI call (serve the canned design for the scripted prompt).

The AI builder outranks live scanning: a canned builder and a sample room together still tell the whole story, so both stay in the demo in some form. Never cut: feed, movable 3D room, product sheet, checkout.

Payments model (decided by the team): Interest is a marketplace on Whop.
- Interest holds one main Whop account. Every seller — a brand such as the IKEA-like, or a solo maker — gets its own Whop sub-account under it.
- A buyer pays through Interest. The money goes to the seller's sub-account, and Interest keeps a 5% cut of every sale in the main account.
- Onboarding a large brand means connecting to its existing catalog/API and creating its sub-account; for the hackathon this is represented by seeded sellers with sub-accounts already created.

What the demo must show: a checkout for a seeded product, then a receipt that splits the payment — amount paid, 95% to the named seller, 5% to Interest — and the same sale appearing on that seller's earnings view.

How it is built, in order of preference **[call]**:
1. Real split: each seeded seller has a Whop sub-account id; a Convex action creates the checkout against that sub-account with a 5% platform fee, in test mode. **[confirm]** with the Whop team on the floor, before 11:00, that Whop supports sub-accounts with a platform fee and how quickly it can be set up.
2. Fallback, decided by 2:00 if option 1 is not working: one hosted Whop checkout link in test mode on the main account, with the 95/5 split calculated and recorded in Convex and shown on the receipt and earnings view.

Either way the item bought in the demo is a seeded product, not the AI design. A design listed at runtime gets a "Listed" confirmation and an earnings view at zero; it does not need its own sub-account in the demo.

Sample room **[call]**: scan a furnished corner of the venue (sofa or chairs plus a table) as soon as the scan screen works, target 12:30. The seed catalog must cover chair, table, sofa, storage and television. If only one LiDAR phone is available, Dev 1 holds it until the sample room is captured, then it becomes the shared demo phone.

P2 — only if ahead
- Share sheet with a deep link to a room.
- Seller profile pages. Likes and comment counts (seeded numbers are fine).

## 7. Seed data

- Sellers: three or four fake brands (an IKEA-like, an Amazon-like) and two or three solo makers.
- Products: about 15–20, covering every category RoomPlan can detect that is likely in the demo room, with at least two per common category so "swap" works. Each has name, seller, price, dimensions, category, a 3D model file (USDZ), a thumbnail, and assembly instructions. One product should be a step stool with a real-style assembly PDF, per the team's example.
- 3D models: free, permissively licensed furniture models, relabelled. Where no model is found in time, a coloured box at the right dimensions is acceptable.
- Rooms: 8–12 pre-made published rooms from fake users so the feed is full at launch. These can be hand-authored variations of the sample room.

## 8. Shared contracts — freeze by 10:30 AM

These are what let three people work without blocking each other. Dev 3 owns the Convex schema; all three agree the shapes before anyone builds on them.

Data (Convex tables)
- `users`: name, avatar.
- `sellers`: name, kind (brand or creator), logo, optional linked user, Whop sub-account id.
- `products`: seller, name, category, price, dimensions (w/d/h in metres), model file, thumbnail, instructions, vendor link, checkout link, optional source design.
- `rooms`: owner, title, thumbnail, published flag, shell, placements, optional remixed-from room.
- `designs`: owner, prompt, parts, cut list, steps.
- `collections` and `collectionItems`: owner, name; item is a room or a product.
- `orders`: buyer, product, seller, status, amount paid, platform fee (5%), seller amount.

Room format (stored on the room, used by both editor and viewer)
- `shell`: lists of walls, doors, windows, each with a 4×4 transform and width/height.
- `placements`: each has an id, a 4×4 transform, and either a product id or a design id, plus the category originally detected.

Design part format (returned by the AI builder, rendered by Dev 1)
- name, shape (box or cylinder), size in cm, position in cm, rotation in degrees, material, colour.

App boundaries
- Dev 1 exposes two views to the rest of the app: a room editor that takes a room and reports changes, and a read-only room viewer; plus a small view that renders a design from its parts.
- Dev 2 owns navigation and every non-3D screen and embeds Dev 1's views.
- Dev 3 exposes named Convex queries/mutations/actions; Dev 2 works against seeded data from the first hour.

## 9. Workstreams

One repo, one worktree per developer, one folder per owner so agents do not edit the same files **[call]**.

Dev 1 — 3D
1. Sample room rendered from the room format (hardcoded data first).
2. Editing gestures: select, drag, rotate, delete, wall stop.
3. RoomPlan scan → room format; category/dimension matching to products.
4. Swap and add-from-catalog placement.
5. Design renderer from parts; thumbnail capture.

Dev 2 — app and payments
1. App shell, tabs (Home, Create, Builder, Profile), orange/white theme, pin logo.
2. Feed and room detail (embedding the viewer).
3. Product sheet, instructions view, catalog browser.
4. Whop checkout and confirmation.
5. Builder chat UI, cut list view, "list for sale"; collections; share.

Dev 3 — backend
1. Convex project, schema, seed script (sellers, products, rooms, users).
2. Queries and mutations for feed, room save/publish/remix, catalog, collections, orders.
3. File storage for models and thumbnails.
4. OpenAI action with structured output and canned fallbacks.
5. Whop: talk to the Whop team first thing, create the main account and seller sub-accounts, build the checkout action with the 5% fee, record orders with the split, and serve seller earnings. This is Dev 3's main job after the seed data is in; Dev 2 builds the checkout, receipt and earnings screens against it.

Dependency graph

```
Contracts frozen (all, 10:30)
 ├─ D3.1 schema + seed ──┬─ D2.2 feed ── D2.3 product sheet ── D2.4 Whop
 │                       ├─ D3.2 functions ── publish / remix / collections
 │                       └─ D3.4 OpenAI action ── D2.5 builder UI
 ├─ D1.1 render sample room ── D1.2 editing ──┬─ D1.4 swap / add
 │                                            └─ D2.2 room detail embeds viewer
 ├─ D1.3 scan → room (needs D3.1 products for matching)
 └─ D1.5 design renderer (needs part format only) ── D2.5 place design in room
```

Nothing in the first two hours needs another person's finished work: Dev 1 renders hardcoded data, Dev 2 builds against seed data or local stubs, Dev 3 seeds.

Milestones
- 10:30 contracts frozen, repo and Convex project up, app runs on a phone.
- 1:00 first integration: feed from Convex, a room opens in 3D, objects move.
- 3:30 scan works end to end; Whop checkout works; AI builder returns a design.
- 4:30 feature freeze. Only fixes, seed polish and fallbacks after this.
- 5:00 full demo rehearsal on the demo phone, twice. 6:00 submit.

## 10. Demo script (about 3 minutes)

1. Open Interest to a feed of beautiful rooms. "Pinterest, but every pin is a room you can walk into and buy from."
2. Tap a room, spin it in 3D, tap a chair, see the product and price. Save it to a collection.
3. Create: scan the room (or tap "Use sample room"). The room rebuilds itself with matched products.
4. Drag the sofa, swap the chair, add a step stool from the catalog and open its assembly instructions.
5. Builder: type the scripted prompt. A custom desk appears with a cut list. Place it in the room, then list it for sale.
6. Buy an item with Whop. Confirmation.
7. Publish. The room appears at the top of the feed. Close on: brands, makers and you all get paid.

Typed inputs in the demo are scripted and have guaranteed responses.

## 11. Sponsor tools

All three required tools must be visibly and genuinely used, and each developer should be able to say how in one sentence.

- **Convex** (reactive backend): the storage backend. At minimum it holds the 3D model files (file storage) and the catalog, sellers and published rooms, and the feed reads from it live so a newly published room appears without a refresh. It may stay thin: anything that is not needed for the demo can be hardcoded in the app rather than built as a Convex function **[call]**. The OpenAI and Whop calls run as Convex actions so the keys stay off the phone.
- **Capy** (AI software engineer): used as a coding agent on real tasks from this PRD. Each developer hands Capy at least one self-contained task from their workstream (good candidates: the seed script, the catalog browser, the cut list view) and merges the result, so its work is in the commit history **[call]**.
- **Revyl** (mobile build, test and debug platform): used to build and run the app on the device, and to hold one automated run-through of the demo flow (feed → room → product → checkout) that is re-run after each integration milestone **[call]**.
- **Whop**: checkout, seller sub-accounts and the 5% cut.

Dev 2 owns getting Capy and Revyl set up for the team by 10:30 and asks each sponsor's staff at kickoff what counts as qualifying use **[confirm]**.

## 12. Risks

- Scan fails or looks bad on stage → bundled sample room.
- AI call slow or malformed → canned designs, 8-second cutoff.
- Whop sub-accounts or platform fee unavailable or slow to set up → single hosted checkout link with the split recorded in Convex (decide by 2:00).
- 3D models missing or heavy → dimension-correct coloured boxes; keep models small.
- Merge conflicts across agents → folder ownership and frozen contracts.

## 13. Left to the builders

Choice of RealityKit versus SceneKit, gesture details, visual design beyond the brand colours, exact Convex function names, where 3D models are sourced, and how the fake user switcher looks.
