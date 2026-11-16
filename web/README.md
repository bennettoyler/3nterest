# 3nterest landing site

A single static page for 3nterest, built with Next.js (App Router) and Tailwind. It has no environment variables and makes no backend calls. It is independent of the root `package.json`.

## Develop

```bash
cd web
npm install
npm run dev
```

## Check

```bash
npm run lint
npm run build
```

## Deploy on Vercel

Import the repository in Vercel and set:

- Root Directory: `web`
- Framework Preset: Next.js
- Build Command: `npm run build` (the default)
- Install Command: `npm install` (the default)
- Output Directory: leave as the default
- Environment variables: none

## Where things are

- `app/page.tsx`: the page and all of its copy.
- `components/IsoRoom.tsx`: the isometric room illustration, drawn as SVG from boxes.
- `components/rooms.ts`: the rooms shown in the illustrations.
- `components/Logo.tsx`, `app/icon.png`, `app/opengraph-image.png`: the logo, favicon and Open Graph image. They follow `PinLogo` and the app icon in `Interest/App/`.
- `app/globals.css`: the theme, taken from the app: the system sans-serif font, orange `#FF6600` on white, and iOS system grays.

The rooms on the page are illustrations, not screenshots of the app.
