export function split(amountCents: number): { platformFeeCents: number; sellerCents: number } {
  const platformFeeCents = Math.round(amountCents * 0.05);
  return { platformFeeCents, sellerCents: amountCents - platformFeeCents };
}
