import { BrowserProvider } from "ethers";
import type {
  EIP6963ProviderDetail,
} from "mipd";

export interface ConnectedWallet {
  detail: EIP6963ProviderDetail;
  provider: any;
  browserProvider: BrowserProvider;
  accounts: string[];
  chainId: number;
}
