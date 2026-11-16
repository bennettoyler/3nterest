import type { Metadata, Viewport } from "next";
import "./globals.css";

const title = "3nterest — every pin is a 3D room";
const description =
  "Scan your room with your iPhone. 3nterest rebuilds it out of movable 3D furniture matched to products you can buy, then lets you rearrange it, add to it and share it to a feed of other people's rooms.";

export const metadata: Metadata = {
  title,
  description,
  applicationName: "3nterest",
  openGraph: {
    title,
    description,
    siteName: "3nterest",
    type: "website",
  },
  twitter: {
    card: "summary_large_image",
    title,
    description,
  },
};

export const viewport: Viewport = {
  themeColor: "#FF6600",
};

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html lang="en" className="antialiased">
      <body className="font-sans">{children}</body>
    </html>
  );
}
