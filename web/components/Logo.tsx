export function Logo({ size = 40, className }: { size?: number; className?: string }) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 100 100"
      role="img"
      aria-label="3nterest logo"
      className={className}
    >
      <rect width="100" height="100" rx="22" fill="#FF6600" />
      <path
        d="M35.5 30.5A15.5 13.5 0 1 1 50 49.5H44M50 49.5A17 15 0 1 1 33.5 70"
        fill="none"
        stroke="#FFFFFF"
        strokeWidth="13"
      />
    </svg>
  );
}
