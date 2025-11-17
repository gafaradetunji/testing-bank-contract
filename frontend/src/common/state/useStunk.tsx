"use client";

import React, { useEffect } from "react";
import { connectedWalletChunk, eip6963Store, walletsChunk } from "./walletStore";

interface WalletProviderProps {
  children: React.ReactNode;
}

export function WalletProvider({ children }: WalletProviderProps) {
  // Update wallets as mipd discovers them
  useEffect(() => {
    // Initialize immediately in case providers were already discovered
    walletsChunk.set(eip6963Store.getProviders());

    const unsub = eip6963Store.subscribe(() => {
      walletsChunk.set(eip6963Store.getProviders());
    });

    return () => unsub();
  }, []);

  // Reactively attach listeners whenever a wallet is connected
  useEffect(() => {
    const unsub = connectedWalletChunk.subscribe((connected) => {
      if (!connected) return;

      const { provider } = connected;
      const handleAccounts = (accs: string[]) => {
        connectedWalletChunk.set(prev =>
          prev ? { ...prev, accounts: accs } : prev
        );
      };
      const handleChain = (chain: string) => {
        connectedWalletChunk.set(prev =>
          prev ? { ...prev, chainId: parseInt(chain, 16) } : prev
        );
      };

      provider.on("accountsChanged", handleAccounts);
      provider.on("chainChanged", handleChain);

      // Cleanup when wallet disconnects or changes
      return () => {
        provider.removeListener("accountsChanged", handleAccounts);
        provider.removeListener("chainChanged", handleChain);
      };
    });

    return () => unsub();
  }, []);

  return <>{children}</>;
}
