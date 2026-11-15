/* eslint-disable */
/**
 * Generated `api` utility.
 *
 * THIS CODE IS AUTOMATICALLY GENERATED.
 *
 * To regenerate, run `npx convex dev`.
 * @module
 */

import type * as collections from "../collections.js";
import type * as designs from "../designs.js";
import type * as files from "../files.js";
import type * as lib_cannedDesigns from "../lib/cannedDesigns.js";
import type * as lib_designSchema from "../lib/designSchema.js";
import type * as lib_match from "../lib/match.js";
import type * as lib_shape from "../lib/shape.js";
import type * as lib_split from "../lib/split.js";
import type * as orders from "../orders.js";
import type * as payments from "../payments.js";
import type * as products from "../products.js";
import type * as rooms from "../rooms.js";
import type * as seed from "../seed.js";
import type * as seedData from "../seedData.js";
import type * as sellers from "../sellers.js";
import type * as users from "../users.js";

import type {
  ApiFromModules,
  FilterApi,
  FunctionReference,
} from "convex/server";

declare const fullApi: ApiFromModules<{
  collections: typeof collections;
  designs: typeof designs;
  files: typeof files;
  "lib/cannedDesigns": typeof lib_cannedDesigns;
  "lib/designSchema": typeof lib_designSchema;
  "lib/match": typeof lib_match;
  "lib/shape": typeof lib_shape;
  "lib/split": typeof lib_split;
  orders: typeof orders;
  payments: typeof payments;
  products: typeof products;
  rooms: typeof rooms;
  seed: typeof seed;
  seedData: typeof seedData;
  sellers: typeof sellers;
  users: typeof users;
}>;

/**
 * A utility for referencing Convex functions in your app's public API.
 *
 * Usage:
 * ```js
 * const myFunctionReference = api.myModule.myFunction;
 * ```
 */
export declare const api: FilterApi<
  typeof fullApi,
  FunctionReference<any, "public">
>;

/**
 * A utility for referencing Convex functions in your app's internal API.
 *
 * Usage:
 * ```js
 * const myFunctionReference = internal.myModule.myFunction;
 * ```
 */
export declare const internal: FilterApi<
  typeof fullApi,
  FunctionReference<any, "internal">
>;

export declare const components: {};
