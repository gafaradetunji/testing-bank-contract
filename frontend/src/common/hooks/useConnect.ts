import { useChunk } from "stunk/react";
import { BrowserProvider } from "ethers";
import type { EIP6963ProviderDetail } from "mipd";
import { connectedWalletChunk, walletsChunk } from "../state";
import { ConnectedWallet } from "../types";

export function useWallet() {
  const [wallets] = useChunk(walletsChunk);
  const [connected, setConnected] = useChunk(connectedWalletChunk);

  async function connect(detail: EIP6963ProviderDetail<any>) {
    const provider = detail.provider;
    const browserProvider = new BrowserProvider(provider);

    // Try multiple strategies to obtain accounts because different
    // providers may expose different methods (or return different shapes).
    let accounts: string[] = [];

    try {
      const res = await provider.request({ method: "eth_requestAccounts" });
      if (Array.isArray(res)) accounts = res as string[];
      else if (res && typeof res === "object" && Array.isArray((res as any).accounts))
        accounts = (res as any).accounts;
    } catch (err) {
      // continue to fallbacks
      console.warn("eth_requestAccounts failed:", err);
    }

    // Fallback: try ethers' BrowserProvider signer to get an address
    if (!accounts.length) {
      try {
        const addr = await browserProvider.getSigner().getAddress();
        if (addr) accounts = [addr];
      } catch (err) {
        // ignore and try next fallback
        console.warn("browserProvider.getSigner().getAddress() failed:", err);
      }
    }

    // Fallback: eth_accounts (non-interactive)
    if (!accounts.length) {
      try {
        const res = await provider.request({ method: "eth_accounts" });
        if (Array.isArray(res)) accounts = res as string[];
      } catch (err) {
        console.warn("eth_accounts failed:", err);
      }
    }

    // Read chain id (handle string hex or numeric)
    let chainId = 0;
    try {
      const chainHex = await provider.request({ method: "eth_chainId" });
      if (typeof chainHex === "string") chainId = parseInt(chainHex, 16);
      else if (typeof chainHex === "number") chainId = chainHex;
    } catch (err) {
      console.warn("eth_chainId failed:", err);
    }

    const wallet: ConnectedWallet = {
      detail,
      provider,
      browserProvider,
      accounts,
      chainId,
    };

    setConnected(wallet);
  }

    console.log("connected wallet", connected, 'wallets', wallets);
  function disconnect() {
    if (connected?.provider?.removeListener) {
      connected.provider.removeListener("accountsChanged", () => {});
      connected.provider.removeListener("chainChanged", () => {});
    }
    setConnected(undefined);
  }

  async function switchChain(chainId: number) {
    if (!connected) return;
    const hexId = "0x" + chainId.toString(16);
    await connected.provider.request({
      method: "wallet_switchEthereumChain",
      params: [{ chainId: hexId }],
    });
    setConnected(prev => (prev ? { ...prev, chainId } : prev));
  }

  return {
    wallets,
    wallet: connected,
    connect,
    disconnect,
    switchChain,
    isConnected: connected != null,
  };
}
