import { IsoRoom } from "@/components/IsoRoom";
import { Logo } from "@/components/Logo";
import { deskRoom, editRoom, feedRooms, heroRoom, rebuiltRoom, scanRoom } from "@/components/rooms";

function DemoBadge({ dark }: { dark?: boolean }) {
  return (
    <span
      className={`inline-flex items-center gap-2.5 rounded-full px-4 py-2.5 text-sm font-semibold ${
        dark ? "bg-ink text-white" : "bg-white text-ink ring-1 ring-ink/15"
      }`}
    >
      <span className="relative flex h-2.5 w-2.5">
        <span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-brand opacity-60 motion-reduce:hidden" />
        <span className="relative inline-flex h-2.5 w-2.5 rounded-full bg-brand" />
      </span>
      Demo on iPhone
    </span>
  );
}

function Eyebrow({ children, light }: { children: React.ReactNode; light?: boolean }) {
  return (
    <p
      className={`text-xs font-bold uppercase tracking-[0.18em] ${light ? "text-white/80" : "text-brand"}`}
    >
      {children}
    </p>
  );
}

function Step({
  n,
  title,
  children,
  art,
  wide,
  className = "",
}: {
  n: string;
  title: string;
  children: React.ReactNode;
  art: React.ReactNode;
  wide?: boolean;
  className?: string;
}) {
  return (
    <li
      className={`flex flex-col overflow-hidden rounded-[28px] bg-cream ${wide ? "lg:flex-row" : ""} ${className}`}
    >
      <div className={`p-6 sm:p-8 ${wide ? "lg:w-[36%] lg:shrink-0 lg:p-10" : ""}`}>
        <div className="flex items-baseline gap-3">
          <span className="font-display text-sm font-extrabold text-brand">{n}</span>
          <h3 className="font-display text-2xl font-extrabold tracking-tight sm:text-3xl">{title}</h3>
        </div>
        <p className="mt-3 max-w-xl text-[15px] leading-relaxed text-ink/70 sm:text-base">{children}</p>
      </div>
      <div className={`mt-auto ${wide ? "lg:flex-1" : ""}`}>{art}</div>
    </li>
  );
}

function Receipt() {
  return (
    <div className="mx-auto w-full max-w-sm rotate-[-2deg] rounded-[24px] bg-white p-6 text-ink shadow-[0_30px_60px_-20px_rgba(27,22,18,0.45)] sm:p-7">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          <Logo size={24} />
          <span className="font-display text-sm font-extrabold">Receipt</span>
        </div>
        <span className="rounded-full bg-cream px-2.5 py-1 text-[11px] font-bold uppercase tracking-wider text-brand">
          Paid with Whop
        </span>
      </div>
      <p className="mt-6 text-sm text-ink/60">Linnea 3-Seat Sofa</p>
      <p className="font-display text-5xl font-extrabold tracking-tight">$649.00</p>
      <div className="mt-6 flex h-3 overflow-hidden rounded-full">
        <span className="w-[95%] bg-ink" />
        <span className="w-[5%] bg-brand" />
      </div>
      <dl className="mt-5 space-y-3 text-sm">
        <div className="flex items-center justify-between">
          <dt className="flex items-center gap-2">
            <span className="h-2.5 w-2.5 rounded-full bg-ink" />
            Nordhem, the seller · 95%
          </dt>
          <dd className="font-bold tabular-nums">$616.55</dd>
        </div>
        <div className="flex items-center justify-between">
          <dt className="flex items-center gap-2">
            <span className="h-2.5 w-2.5 rounded-full bg-brand" />
            3nterest · 5%
          </dt>
          <dd className="font-bold tabular-nums">$32.45</dd>
        </div>
      </dl>
    </div>
  );
}

export default function Home() {
  return (
    <>
      <header className="mx-auto flex max-w-7xl items-center justify-between px-5 py-5 sm:px-8">
        <a href="#top" className="flex items-center gap-3">
          <Logo size={40} />
          <span className="font-display text-2xl font-extrabold tracking-tight">3nterest</span>
        </a>
        <nav className="hidden items-center gap-8 text-sm font-semibold text-ink/70 md:flex">
          <a className="hover:text-brand" href="#how">How it works</a>
          <a className="hover:text-brand" href="#feed">The feed</a>
          <a className="hover:text-brand" href="#sellers">For sellers</a>
        </nav>
        <DemoBadge />
      </header>

      <main id="top">
        <section className="mx-auto grid max-w-7xl items-center gap-10 px-5 pb-16 pt-8 sm:px-8 lg:grid-cols-[1.05fr_1fr] lg:gap-6 lg:pb-24 lg:pt-14">
          <div>
            <Eyebrow>3D + Pinterest, pronounced &ldquo;interest&rdquo;</Eyebrow>
            <h1 className="mt-5 font-display text-[clamp(2.9rem,9vw,6.25rem)] font-extrabold leading-[0.92] tracking-[-0.04em]">
              Every pin is a room you can <span className="text-brand">walk into.</span>
            </h1>
            <p className="mt-7 max-w-xl text-lg leading-relaxed text-ink/70 sm:text-xl">
              Scan your room with your iPhone. 3nterest rebuilds it out of movable 3D furniture
              matched to products you can buy. Rearrange it, add to it, share it, and buy what you
              see in other people&rsquo;s rooms.
            </p>
            <div className="mt-9 flex flex-wrap items-center gap-x-6 gap-y-4">
              <DemoBadge dark />
              <a href="#how" className="text-sm font-bold underline decoration-brand decoration-2 underline-offset-4 hover:text-brand">
                See how it works
              </a>
            </div>
            <p className="mt-4 text-sm text-ink/50">
              A hackathon demo that runs on an iPhone Pro with LiDAR. It is not on the App Store.
            </p>
          </div>

          <div className="relative">
            <div className="rounded-[36px] bg-cream p-3 sm:p-6">
              <IsoRoom
                room={heroRoom}
                className="h-auto w-full"
                label="Illustration of a living room rebuilt in 3D. The sofa is selected and tagged Linnea 3-Seat Sofa, Nordhem, $649."
              />
            </div>
            <div className="absolute -bottom-4 left-4 flex gap-2 sm:left-8">
              {["Drag", "Rotate", "Swap", "Delete"].map((a, i) => (
                <span
                  key={a}
                  className={`rounded-full px-3.5 py-2 text-xs font-bold shadow-sm sm:text-sm ${
                    i === 0 ? "bg-brand text-white" : "bg-white text-ink ring-1 ring-ink/10"
                  }`}
                >
                  {a}
                </span>
              ))}
            </div>
          </div>
        </section>

        <section id="how" className="mx-auto max-w-7xl scroll-mt-6 px-5 py-16 sm:px-8 lg:py-24">
          <Eyebrow>How it works</Eyebrow>
          <h2 className="mt-4 max-w-4xl font-display text-4xl font-extrabold leading-[0.98] tracking-[-0.03em] sm:text-6xl">
            From a 60-second scan to a room you can shop.
          </h2>

          <ol className="mt-12 grid gap-4 sm:gap-5 lg:grid-cols-12">
            <Step
              n="01"
              title="Scan"
              className="lg:col-span-6"
              art={
                <div className="relative px-4 pb-4">
                  <div className="scan-sweep pointer-events-none absolute inset-x-6 top-4 h-10 rounded-full bg-gradient-to-b from-brand/0 via-brand/25 to-brand/0" />
                  <IsoRoom
                    room={scanRoom}
                    className="h-auto w-full"
                    label="Illustration of a scanned room: walls and floor, with each piece of furniture as an outlined box."
                  />
                </div>
              }
            >
              Walk your room with an iPhone Pro. A scan of about a minute captures the walls, doors
              and windows, and every piece of furniture as a labelled box with its size and
              position.
            </Step>

            <Step
              n="02"
              title="Rebuilt as real products"
              className="lg:col-span-6"
              art={
                <div className="px-4 pb-4">
                  <IsoRoom
                    room={rebuiltRoom}
                    className="h-auto w-full"
                    label="Illustration of the same room with each box replaced by furniture. The coffee table is tagged Birk Coffee Table, Nordhem, $129."
                  />
                </div>
              }
            >
              Each box becomes the catalog product in the same category with the closest dimensions,
              placed where yours stands. Every object is tied to its vendor, with a price, a seller
              and assembly instructions.
            </Step>

            <Step
              n="03"
              title="Rearrange it, then add to it"
              wide
              className="lg:col-span-12"
              art={
                <div className="grid items-center gap-4 px-4 pb-4 sm:grid-cols-[1.6fr_1fr] sm:px-6 sm:pb-6 lg:pt-6">
                  <IsoRoom
                    room={editRoom}
                    className="h-auto w-full"
                    label="Illustration of the room being edited: a chair being dragged, and a step stool and a custom desk added."
                  />
                  <div className="rounded-3xl bg-white p-5 shadow-[0_20px_40px_-24px_rgba(27,22,18,0.4)]">
                    <p className="text-[11px] font-bold uppercase tracking-[0.16em] text-brand">AI builder</p>
                    <p className="mt-3 ml-auto w-fit max-w-[15rem] rounded-2xl rounded-br-md bg-ink px-4 py-2.5 text-sm font-medium text-white">
                      a 120 cm walnut desk with two drawers
                    </p>
                    <IsoRoom
                      room={deskRoom}
                      className="mx-auto mt-1 h-auto w-4/5"
                      label="Illustration of a walnut desk designed by the AI builder."
                    />
                    <div className="flex flex-wrap gap-1.5">
                      {["Parts", "Cut list", "Hardware", "Build steps"].map((c) => (
                        <span key={c} className="rounded-full bg-cream px-2.5 py-1 text-xs font-semibold text-ink/80">
                          {c}
                        </span>
                      ))}
                    </div>
                  </div>
                </div>
              }
            >
              Drag objects along the floor, rotate them, delete them, or swap one for another
              product in the same category. They stop at the walls. Add more from the catalog, or
              describe a piece to the AI builder: it returns a design with a cut list, hardware and
              build steps that you can place in the room and list for sale.
            </Step>

            <Step
              n="04"
              title="Share it to the feed"
              className="lg:col-span-7"
              art={
                <div className="grid grid-cols-3 items-end gap-3 px-6 pb-6 sm:px-8 sm:pb-8">
                  {[feedRooms[1], feedRooms[0], feedRooms[3]].map((r, i) => (
                    <div
                      key={r.title}
                      className={`overflow-hidden rounded-2xl ${r.tone} ${
                        i === 1 ? "ring-4 ring-brand" : "opacity-80"
                      }`}
                    >
                      <IsoRoom room={r.room} className="h-auto w-full" label={`Illustration of a room titled ${r.title}.`} />
                    </div>
                  ))}
                </div>
              }
            >
              Publish with a title and your room lands at the top of the feed. Anyone can open it in
              3D, see its item list, and tap an object for the product behind it.
            </Step>

            <Step
              n="05"
              title="Buy through Whop"
              className="lg:col-span-5"
              art={
                <div className="px-6 pb-6 sm:px-8 sm:pb-8">
                  <div className="rounded-3xl bg-white p-5 shadow-[0_20px_40px_-24px_rgba(27,22,18,0.4)]">
                    <div className="flex items-start justify-between gap-4">
                      <div>
                        <p className="font-display text-lg font-extrabold leading-tight">Oak Step Stool</p>
                        <p className="mt-0.5 text-sm text-ink/60">Maya Chen Woodworks</p>
                      </div>
                      <p className="font-display text-lg font-extrabold">$59</p>
                    </div>
                    <div className="mt-4 flex flex-wrap gap-2 text-xs font-bold">
                      <span className="rounded-full bg-brand px-3.5 py-2 text-white">Buy</span>
                      <span className="rounded-full bg-cream px-3.5 py-2">Save</span>
                      <span className="rounded-full bg-cream px-3.5 py-2">Assembly instructions</span>
                      <span className="rounded-full bg-cream px-3.5 py-2">View at vendor</span>
                    </div>
                  </div>
                </div>
              }
            >
              Every object opens a product sheet. Buy opens a Whop checkout, and the receipt shows
              how the payment is split between the seller and 3nterest.
            </Step>
          </ol>
        </section>

        <section id="feed" className="scroll-mt-6 bg-brand text-white">
          <div className="mx-auto max-w-7xl px-5 py-16 sm:px-8 lg:py-24">
            <div className="grid gap-8 lg:grid-cols-[1.2fr_1fr] lg:items-end">
              <div>
                <Eyebrow light>The feed</Eyebrow>
                <h2 className="mt-4 font-display text-4xl font-extrabold leading-[0.98] tracking-[-0.03em] sm:text-6xl">
                  The scanner gets you in. The feed brings you back.
                </h2>
              </div>
              <p className="text-lg leading-relaxed text-white/90">
                3nterest is a social app, not a scanning utility. Home is a masonry feed of other
                people&rsquo;s rooms, and every one of them is a real 3D space you can open, spin
                around and buy from.
              </p>
            </div>

            <div className="mt-12 columns-2 gap-3 sm:gap-4 md:columns-3 lg:columns-4">
              {feedRooms.map((r) => (
                <figure key={r.title} className="mb-3 break-inside-avoid overflow-hidden rounded-3xl bg-white text-ink sm:mb-4">
                  <div className={r.tone}>
                    <IsoRoom room={r.room} className="h-auto w-full" label={`Illustration of a room titled ${r.title}.`} />
                  </div>
                  <figcaption className="px-3.5 py-3 sm:px-4">
                    <p className="font-display text-[15px] font-extrabold leading-tight sm:text-base">{r.title}</p>
                    <p className="mt-0.5 text-xs text-ink/60">
                      {r.by} · {r.items} items
                    </p>
                  </figcaption>
                </figure>
              ))}
            </div>

            <ul className="mt-12 grid gap-8 border-t border-white/30 pt-10 md:grid-cols-3">
              {[
                ["Browse", "Open any room in 3D, look around it, and tap a piece to see the product, its seller and its price."],
                ["Save", "Keep rooms and products in named collections that live on your profile."],
                ["Remix", "Remix this room copies someone else's room into your own editor, ready to rearrange."],
              ].map(([t, d]) => (
                <li key={t}>
                  <h3 className="font-display text-2xl font-extrabold">{t}</h3>
                  <p className="mt-2 leading-relaxed text-white/90">{d}</p>
                </li>
              ))}
            </ul>
          </div>
        </section>

        <section id="sellers" className="scroll-mt-6 bg-ink text-white">
          <div className="mx-auto grid max-w-7xl gap-14 px-5 py-16 sm:px-8 lg:grid-cols-[1.15fr_1fr] lg:items-center lg:py-28">
            <div>
              <Eyebrow>For sellers</Eyebrow>
              <h2 className="mt-4 font-display text-4xl font-extrabold leading-[0.98] tracking-[-0.03em] sm:text-6xl">
                Brands, makers and you all get paid.
              </h2>
              <p className="mt-6 max-w-xl text-lg leading-relaxed text-white/75">
                Anyone can earn from a listing. Payments run on Whop: the buyer pays through
                3nterest, the money goes to the seller, and 3nterest keeps a 5% platform fee on each
                sale.
              </p>
              <ul className="mt-10 grid gap-3 sm:grid-cols-3">
                {[
                  ["A brand", "Its catalog becomes furniture people place in their own rooms."],
                  ["A maker", "An independent workshop lists its pieces next to the big names."],
                  ["You", "Design a desk with the AI builder, set a price, and list it."],
                ].map(([t, d]) => (
                  <li key={t} className="rounded-3xl bg-white/[0.07] p-5 ring-1 ring-white/10">
                    <h3 className="font-display text-xl font-extrabold text-brand">{t}</h3>
                    <p className="mt-2 text-sm leading-relaxed text-white/75">{d}</p>
                  </li>
                ))}
              </ul>
              <p className="mt-8 max-w-xl text-sm leading-relaxed text-white/55">
                Each seller has an earnings view that lists its sales, what it received, and
                3nterest&rsquo;s 5%.
              </p>
            </div>
            <Receipt />
          </div>
        </section>
      </main>

      <footer className="bg-white">
        <div className="mx-auto flex max-w-7xl flex-col gap-8 px-5 py-12 sm:px-8 md:flex-row md:items-end md:justify-between">
          <div>
            <div className="flex items-center gap-3">
              <Logo size={36} />
              <span className="font-display text-xl font-extrabold tracking-tight">3nterest</span>
            </div>
            <p className="mt-4 max-w-md text-sm leading-relaxed text-ink/60">
              Built in one day at the YC Consumer Mobile Hackathon, November 15, 2026, with Capy,
              Revyl, Convex and Whop.
            </p>
          </div>
          <div className="flex flex-col items-start gap-3 md:items-end">
            <DemoBadge />
            <p className="text-xs text-ink/45">The rooms on this page are illustrations, not app screenshots.</p>
          </div>
        </div>
      </footer>
    </>
  );
}
