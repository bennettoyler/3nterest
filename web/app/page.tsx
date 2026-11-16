import { IsoRoom } from "@/components/IsoRoom";
import { Logo } from "@/components/Logo";
import { feedRooms, heroRoom } from "@/components/rooms";

function DemoBadge() {
  return (
    <span className="inline-flex items-center gap-2 rounded-full bg-brand px-4 py-2.5 text-sm font-semibold text-white">
      <svg width="12" height="16" viewBox="0 0 12 16" fill="none" aria-hidden="true">
        <rect x="1" y="1" width="10" height="14" rx="2.5" stroke="currentColor" strokeWidth="1.6" />
      </svg>
      Demo on iPhone
    </span>
  );
}

const points = [
  ["Scan", "A LiDAR scan of about a minute rebuilds your room as separate 3D pieces, each matched to a product with a price and a seller."],
  ["Make it yours", "Drag, rotate and swap what's there. Add from the catalog, or describe a piece and the AI builder designs it."],
  ["Share and shop", "Publish to the feed, save and remix other rooms, and buy what you see through Whop. Sellers keep 95%."],
];

export default function Home() {
  return (
    <div className="mx-auto flex min-h-screen max-w-5xl flex-col px-5 sm:px-8">
      <header className="flex items-center gap-2.5 py-5">
        <Logo size={32} />
        <span className="text-[22px] font-bold text-brand">3nterest</span>
      </header>

      <main className="flex-1">
        <section className="grid items-center gap-8 py-8 md:grid-cols-2 md:gap-12 md:py-14">
          <div>
            <h1 className="text-[clamp(2.25rem,6vw,3.5rem)] font-bold leading-[1.05] tracking-tight">
              Every pin is a room you can <span className="text-brand">walk into.</span>
            </h1>
            <p className="mt-5 max-w-md text-lg leading-relaxed text-secondary">
              Scan your room with your iPhone. 3nterest rebuilds it out of movable 3D furniture
              matched to products you can buy, ready to rearrange, share and shop.
            </p>
            <div className="mt-7 flex flex-wrap items-center gap-x-4 gap-y-3">
              <DemoBadge />
              <span className="text-sm text-secondary">Hackathon demo, not on the App Store</span>
            </div>
          </div>
          <div className="rounded-2xl bg-brand/15 p-3 sm:p-5">
            <IsoRoom
              room={heroRoom}
              className="h-auto w-full"
              label="Illustration of a living room rebuilt in 3D. The sofa is selected and tagged Linnea 3-Seat Sofa, Nordhem, $649."
            />
          </div>
        </section>

        <section className="grid grid-cols-2 gap-x-3 gap-y-5 py-6 sm:grid-cols-4 sm:gap-x-4">
          {feedRooms.map((r) => (
            <figure key={r.title}>
              <div className="flex aspect-square items-center overflow-hidden rounded-2xl bg-brand/15">
                <IsoRoom room={r.room} className="h-auto w-full" label={`Illustration of a room titled ${r.title}.`} />
              </div>
              <figcaption className="mt-1.5">
                <p className="text-[15px] font-semibold leading-snug">{r.title}</p>
                <p className="text-xs text-secondary">{r.by}</p>
              </figcaption>
            </figure>
          ))}
        </section>

        <section className="grid gap-3 py-8 md:grid-cols-3 md:gap-4 md:py-12">
          {points.map(([t, d]) => (
            <div key={t} className="rounded-2xl bg-gray6 p-5">
              <h2 className="text-[17px] font-semibold">{t}</h2>
              <p className="mt-1.5 text-[15px] leading-relaxed text-secondary">{d}</p>
            </div>
          ))}
        </section>
      </main>

      <footer className="border-t border-black/10 py-6 text-[13px] leading-relaxed text-secondary">
        Built at the YC Consumer Mobile Hackathon with Capy, Revyl, Convex and Whop. The rooms on
        this page are illustrations, not app screenshots.
      </footer>
    </div>
  );
}
