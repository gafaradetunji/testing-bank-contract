import { chunk } from "stunk";
import { createStore, type EIP6963ProviderDetail } from "mipd";
import { ConnectedWallet } from "../types";

export const eip6963Store = createStore();
export const walletsChunk = chunk<readonly EIP6963ProviderDetail<any>[]>([]);

export const connectedWalletChunk = chunk<ConnectedWallet | undefined>(undefined);
