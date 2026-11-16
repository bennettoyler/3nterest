export function Logo({ size = 28 }: { size?: number }) {
  return (
    <span
      role="img"
      aria-label="3nterest"
      className="inline-flex shrink-0 items-center justify-center bg-brand font-normal leading-none text-white"
      style={{ width: size, height: size, fontSize: size * 0.72, borderRadius: size * 0.22 }}
    >
      3
    </span>
  );
}
