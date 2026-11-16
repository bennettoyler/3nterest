export type Box = {
  x: number;
  z: number;
  w: number;
  d: number;
  h: number;
  y?: number;
  c: string;
};

export type Item = {
  boxes: Box[];
  ghost?: boolean;
  selected?: boolean;
  drift?: boolean;
  tag?: { title: string; sub: string };
};

export type Room = {
  w: number;
  d: number;
  h: number;
  wallL: string;
  wallR: string;
  floor: string;
  rug?: { x: number; z: number; w: number; d: number; c: string };
  window?: { x: number; w: number; y: number; h: number };
  items: Item[];
};

const S = 100;
const COS = 0.866;

function pt(x: number, y: number, z: number) {
  return `${((x - z) * COS * S).toFixed(1)},${(((x + z) * 0.5 - y) * S).toFixed(1)}`;
}

function shade(hex: string, f: number) {
  const n = parseInt(hex.slice(1), 16);
  const ch = (s: number) =>
    Math.round(((n >> s) & 255) * f)
      .toString(16)
      .padStart(2, "0");
  return `#${ch(16)}${ch(8)}${ch(0)}`;
}

function Face({ points, fill, ghost }: { points: string[]; fill: string; ghost?: boolean }) {
  return ghost ? (
    <polygon
      points={points.join(" ")}
      fill="#FF6600"
      fillOpacity={0.07}
      stroke="#FF6600"
      strokeWidth={2}
      strokeDasharray="7 6"
      strokeLinejoin="round"
    />
  ) : (
    <polygon points={points.join(" ")} fill={fill} stroke={fill} strokeWidth={1} strokeLinejoin="round" />
  );
}

function BoxShape({ b, ghost }: { b: Box; ghost?: boolean }) {
  const y0 = b.y ?? 0;
  const y1 = y0 + b.h;
  const x1 = b.x + b.w;
  const z1 = b.z + b.d;
  return (
    <>
      <Face
        ghost={ghost}
        fill={shade(b.c, 0.74)}
        points={[pt(x1, y0, b.z), pt(x1, y0, z1), pt(x1, y1, z1), pt(x1, y1, b.z)]}
      />
      <Face
        ghost={ghost}
        fill={shade(b.c, 0.87)}
        points={[pt(b.x, y0, z1), pt(x1, y0, z1), pt(x1, y1, z1), pt(b.x, y1, z1)]}
      />
      <Face
        ghost={ghost}
        fill={b.c}
        points={[pt(b.x, y1, b.z), pt(x1, y1, b.z), pt(x1, y1, z1), pt(b.x, y1, z1)]}
      />
    </>
  );
}

function bounds(item: Item) {
  const x0 = Math.min(...item.boxes.map((b) => b.x));
  const z0 = Math.min(...item.boxes.map((b) => b.z));
  const x1 = Math.max(...item.boxes.map((b) => b.x + b.w));
  const z1 = Math.max(...item.boxes.map((b) => b.z + b.d));
  const top = Math.max(...item.boxes.map((b) => (b.y ?? 0) + b.h));
  return { x0, z0, x1, z1, top };
}

export function IsoRoom({
  room,
  className,
  label,
}: {
  room: Room;
  className?: string;
  label: string;
}) {
  const { w, d, h } = room;
  const hasTag = room.items.some((i) => i.tag);
  const pad = 14;
  const minX = -d * COS * S - pad;
  const minY = -h * S - pad - (hasTag ? 30 : 0);
  const width = (w + d) * COS * S + pad * 2;
  const height = (h + (w + d) * 0.5) * S + pad * 2 + (hasTag ? 30 : 0);
  const items = [...room.items].sort((a, b) => {
    const A = bounds(a);
    const B = bounds(b);
    return A.x0 + A.x1 + A.z0 + A.z1 - (B.x0 + B.x1 + B.z0 + B.z1);
  });

  return (
    <svg
      viewBox={`${minX.toFixed(0)} ${minY.toFixed(0)} ${width.toFixed(0)} ${height.toFixed(0)}`}
      className={className}
      role="img"
      aria-label={label}
    >
      <polygon points={[pt(0, 0, 0), pt(0, 0, d), pt(0, h, d), pt(0, h, 0)].join(" ")} fill={room.wallL} />
      <polygon points={[pt(0, 0, 0), pt(w, 0, 0), pt(w, h, 0), pt(0, h, 0)].join(" ")} fill={room.wallR} />
      <polygon points={[pt(0, 0, 0), pt(w, 0, 0), pt(w, 0, d), pt(0, 0, d)].join(" ")} fill={room.floor} />
      {room.window && (
        <polygon
          points={[
            pt(room.window.x, room.window.y, 0),
            pt(room.window.x + room.window.w, room.window.y, 0),
            pt(room.window.x + room.window.w, room.window.y + room.window.h, 0),
            pt(room.window.x, room.window.y + room.window.h, 0),
          ].join(" ")}
          fill="#FFFFFF"
          fillOpacity={0.85}
          stroke={shade(room.wallR, 0.9)}
          strokeWidth={5}
          strokeLinejoin="round"
        />
      )}
      {room.rug && (
        <polygon
          points={[
            pt(room.rug.x, 0, room.rug.z),
            pt(room.rug.x + room.rug.w, 0, room.rug.z),
            pt(room.rug.x + room.rug.w, 0, room.rug.z + room.rug.d),
            pt(room.rug.x, 0, room.rug.z + room.rug.d),
          ].join(" ")}
          fill={room.rug.c}
        />
      )}
      {items.map((item, i) => {
        const b = bounds(item);
        const title = item.tag?.title ?? "";
        const sub = item.tag?.sub ?? "";
        const tagW = Math.max(title.length * 9.2, sub.length * 8) + 34;
        const [ax, ay] = pt((b.x0 + b.x1) / 2, b.top, (b.z0 + b.z1) / 2)
          .split(",")
          .map(Number);
        return (
          <g key={i} className={item.drift ? "iso-drift" : undefined}>
            {item.selected && (
              <polygon
                points={[
                  pt(b.x0 - 0.1, 0, b.z0 - 0.1),
                  pt(b.x1 + 0.1, 0, b.z0 - 0.1),
                  pt(b.x1 + 0.1, 0, b.z1 + 0.1),
                  pt(b.x0 - 0.1, 0, b.z1 + 0.1),
                ].join(" ")}
                fill="#FF6600"
                fillOpacity={0.14}
                stroke="#FF6600"
                strokeWidth={2.5}
                strokeLinejoin="round"
              />
            )}
            {item.boxes.map((box, j) => (
              <BoxShape key={j} b={box} ghost={item.ghost} />
            ))}
            {item.tag && (
              <g>
                <line x1={ax} y1={ay - 4} x2={ax} y2={ay - 30} stroke="#1B1612" strokeWidth={2} />
                <circle cx={ax} cy={ay - 4} r={5} fill="#FF6600" stroke="#FFFFFF" strokeWidth={2} />
                <rect x={ax - tagW / 2} y={ay - 86} width={tagW} height={58} rx={14} fill="#1B1612" />
                <text
                  x={ax}
                  y={ay - 62}
                  textAnchor="middle"
                  fill="#FFFFFF"
                  fontSize={16}
                  fontWeight={700}
                  fontFamily="var(--font-body), system-ui, sans-serif"
                >
                  {title}
                </text>
                <text
                  x={ax}
                  y={ay - 41}
                  textAnchor="middle"
                  fill="#FFB27A"
                  fontSize={14}
                  fontWeight={600}
                  fontFamily="var(--font-body), system-ui, sans-serif"
                >
                  {sub}
                </text>
              </g>
            )}
          </g>
        );
      })}
    </svg>
  );
}
