"use client";

import { useState } from "react";
import { ConnectWalletModal } from ".";
import { Button } from "../button";

export function WalletConnect() {
  const [open, setOpen] = useState(false);

  return (
    <>
        <Button onClick={() => setOpen(true)}>Connect Wallet</Button>
        <ConnectWalletModal open={open} onClose={() => setOpen(false)} />
    </>
  );
}
