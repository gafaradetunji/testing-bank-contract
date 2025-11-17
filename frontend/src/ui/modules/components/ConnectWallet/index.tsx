"use client";

import { useState } from "react";
import Image from "next/image";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
} from "../dialog";
import { Button } from "../button";
import { useWallet } from "@/src/common";

interface ConnectWalletProps {
  open: boolean;
  onClose: () => void;
}

export const ConnectWalletModal = ({ open, onClose }: ConnectWalletProps) => {
  const { wallets, wallet, connect, disconnect } = useWallet();
  const [isConnecting, setIsConnecting] = useState(false);

  const handleSelect = async (detail: typeof wallets[number]) => {
    try {
      setIsConnecting(true);
      await connect(detail);
    } catch (err) {
      console.error("Error connecting to wallet", err);
    } finally {
      setIsConnecting(false);
      onClose();
    }
  };

  return (
    <Dialog open={open} onOpenChange={onClose}>
      <DialogContent className="max-w-md">
        <DialogHeader>
          <DialogTitle>Connect Wallet</DialogTitle>
        </DialogHeader>

        <div className="mt-4 space-y-3">
          {!wallets.length && (
            <p className="text-sm text-gray-500">
              No wallets found.
            </p>
          )}

          {wallets.map((detail) => (
            <Button
              key={detail.info.uuid}
              variant="outline"
              className="flex items-center gap-3"
              onClick={() => handleSelect(detail)}
              disabled={isConnecting || !!wallet}
            >
              <img
                src={detail.info.icon}
                alt={detail.info.name}
                // width={28}
                // height={28}
                className="rounded w-7 h-7"
              />
              <span>{detail.info.name}</span>
            </Button>
          ))}

          {wallet && (
            <div className="mt-3 flex flex-col gap-2">
              <p>
                Connected: <strong>{wallet.detail.info.name}</strong>
              </p>
              <p>Account: {wallet.accounts[0]}</p>
              <Button
                variant="destructive"
                onClick={() => {
                  disconnect();
                  onClose();
                }}
              >
                Disconnect
              </Button>
            </div>
          )}
        </div>
      </DialogContent>
    </Dialog>
  );
};
