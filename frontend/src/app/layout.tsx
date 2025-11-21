import type { Metadata } from "next";
import "./globals.css";
import { Provider } from "./provider";

export const metadata: Metadata = {
  title: "My safe",
  description: "A simple bank dApp built on base",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body
        className={``}
      >
        <Provider>
          {children}
        </Provider>
      </body>
    </html>
  );
}
