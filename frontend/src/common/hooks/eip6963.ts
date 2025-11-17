import { useSyncExternalStore } from "react";
import { createStore, type EIP6963ProviderDetail } from "mipd";

const store = createStore();

export function useEip6963Providers(): readonly EIP6963ProviderDetail[] {
  return useSyncExternalStore(
    store.subscribe,
    store.getProviders,
    store.getProviders
  );
}
