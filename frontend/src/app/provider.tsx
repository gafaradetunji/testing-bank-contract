'use client';
import { ReactNode } from 'react';
import { WalletProvider } from '../common';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { Toaster } from 'sonner';


type ProviderProps = {
  children: ReactNode;
}

export function Provider({
  children
}: ProviderProps) {
  const queryClient = new QueryClient();
  return (
    <WalletProvider>
        <QueryClientProvider client={queryClient}>
            {children}
            <Toaster
            position="top-right"
            richColors
            toastOptions={{
                duration: 3000,
                className: 'custom-toast',
                style: {
                padding: '12px 16px',
                borderRadius: '8px',
                boxShadow: '0px 4px 10px rgba(0, 0, 0, 0.2)',
                },
            }}
            />
        </QueryClientProvider>
    </WalletProvider>
  )
}