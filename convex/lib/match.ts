type Size = { width: number; depth: number; height: number };

export function sizeDistance(a: Size, b: Size): number {
  return Math.abs(a.width - b.width) + Math.abs(a.depth - b.depth) + Math.abs(a.height - b.height);
}

// Products of the category, closest to the scanned size first (seed order when there is no size).
export function rankByFit<T extends { category: string; dimensions: Size }>(products: T[], category: string, size?: Size): T[] {
  const candidates = products.filter((p) => p.category === category);
  return size ? [...candidates].sort((a, b) => sizeDistance(a.dimensions, size) - sizeDistance(b.dimensions, size)) : candidates;
}
